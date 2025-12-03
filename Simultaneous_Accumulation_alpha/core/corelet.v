module corelet (
    clk, reset,

    // Controls
    inst_w,
    l0_rd, l0_wr,
    sfp_acc_en,
    ofifo_rd,

    i_xmem_data,
    i_pmem_data,

    o_sfp_out,

    o_ofifo_out,
    o_ofifo_valid
);

  parameter row = 8;
  parameter col = 8;
  parameter bw = 4;
  parameter psum_bw = 16;
  parameter WINDOW_SIZE = 3;
  parameter last_kij = 8; //not req
  input clk, reset;

  input [1:0] inst_w;
  input l0_rd, l0_wr;
  input sfp_acc_en; //not req
  input ofifo_rd;

  
  // Data Interfaces
  input  [row*bw-1:0] i_xmem_data;     // 32-bit Input from XMEM
  input  [col*psum_bw-1:0] i_pmem_data; // 128-bit Input from PMEM (for Accumulation)

  output [3*col*psum_bw-1:0] o_sfp_out;   // 128-bit Output from SFP
  output [col*psum_bw-1:0] o_ofifo_out;   // 128-bit Output from OFIFO
  output o_ofifo_valid;

  // Internal Wires
  wire [row*bw-1:0] l0_out;
  wire [col*psum_bw-1:0] array_out_s;
  wire [col-1:0] array_valid;
  reg sfp_flush_en_reg;
  wire auto_acc_en;
  wire sfp_flush_en;

  assign auto_acc_en = o_ofifo_valid; //acc ofifo output
  assign sfp_flush_en = sfp_flush_en_reg;
  // --------------------------------------------------------
  // L0 Buffer
  // --------------------------------------------------------
  l0 #(.row(row), .bw(bw)) l0_inst (
      .clk(clk),
      .reset(reset),
      .in(i_xmem_data),
      .out(l0_out),
      .rd(l0_rd),
      .wr(l0_wr),
      .o_full(),    
      .o_ready()    
  );

  // --------------------------------------------------------
  // MAC Array
  // --------------------------------------------------------
  mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array_inst (
      .clk(clk),
      .reset(reset),
      .in_w(l0_out),
      .inst_w(inst_w),
      .in_n({(col*psum_bw){1'b0}}),        // North input unused
      .out_s(array_out_s),  // Output goes to OFIFO
      .valid(array_valid)
  );

  // --------------------------------------------------------
  // OFIFO (Now between Array and SFP)
  // --------------------------------------------------------
  ofifo #(.col(col), .bw(psum_bw)) ofifo_inst (
      .clk(clk),
      .reset(reset),
      .in(array_out_s),     // Input from MAC Array
      .out(o_ofifo_out),  // Output to SFP
      .rd(ofifo_rd),        // Controlled by TB to feed SFP
      .wr(array_valid),
      .o_full(),
      .o_ready(),
      .o_valid(o_ofifo_valid)
  );

  //Generate flush signal for SFU
  reg [3:0] kij_counter;
  
  always @(posedge clk) begin
      if (reset) begin
        kij_counter <= 0;
        sfp_flush_en_reg <= 0;
      end
      else if(ofifo_rd && o_ofifo_valid) begin
        
        if (kij_counter < 2) begin
          sfp_flush_en_reg <= 1'b0;
          kij_counter <= kij_counter + 1'b1;
        end else begin
          sfp_flush_en_reg <= 1'b1;
          kij_counter <= kij_counter + 1'b1;
      	end 
      end
      else begin
        sfp_flush_en_reg <= 1'b0;
      end
  end
  // --------------------------------------------------------
  // SFP (Accumulation & ReLU)
  // --------------------------------------------------------
  sfp_8lane #(.col(col), .psum_bw(psum_bw)) sfp_inst (
      .clk(clk),
      .reset(reset),
      .data_in(o_ofifo_out),  //taking input from ofifo, not pmem
      //.valid_in(o_ofifo_valid), //acc when ofifo output is valid (none empty)
      .acc_en(auto_acc_en),
      .flush_en(sfp_flush_en), //flush every WINDOW_SIZE inputssf
      .data_out(o_sfp_out)  
      
  );

endmodule
