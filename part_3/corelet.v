module corelet (
    clk, reset, mode,
    
    // Controls
    inst_w,
    l0_rd, l0_wr,
    ififo_wr, ififo_rd, 
    sfp_acc_en,
    ofifo_rd,

    // Data Interfaces
    input  [row*bw-1:0] i_xmem_data,      
    input  [col*psum_bw-1:0] i_pmem_data, 

    output [col*psum_bw-1:0] o_sfp_out,   
    output o_ofifo_valid
);

  parameter row = 8;
  parameter col = 8;
  parameter bw = 4;
  parameter psum_bw = 16;

  input clk, reset, mode;
  input [2:0] inst_w; // Updated: 3-bit Input
  input l0_rd, l0_wr;
  input ififo_wr, ififo_rd;
  input sfp_acc_en;
  input ofifo_rd;

  // Internal Wires
  wire [row*bw-1:0] l0_out;
  wire [col*bw-1:0] ififo_out;          
  wire [col*psum_bw-1:0] array_in_n;    
  wire [col*psum_bw-1:0] array_out_s;
  wire [col-1:0] array_valid;
  wire [col*psum_bw-1:0] fifo_out_wire; 
  wire [col*psum_bw-1:0] sfp_out_wire;
  
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
  // IFIFO (New Component for OS Mode)
  // --------------------------------------------------------
  ififo #(.col(col), .bw(bw)) ififo_inst (
      .clk(clk),
      .reset(reset),
      .in(i_xmem_data), 
      .out(ififo_out),
      .rd(ififo_rd),
      .wr(ififo_wr),
      .o_full(),
      .o_ready()
  );

  // --------------------------------------------------------
  // Array North Input Logic
  // --------------------------------------------------------
  // We keep 'mode' input here for this specific mux logic
  genvar i;
  generate
    for (i=0; i<col; i=i+1) begin : padding
        assign array_in_n[(i+1)*psum_bw-1 : i*psum_bw] = 
            (mode) ? { {(psum_bw-bw){1'b0}}, ififo_out[(i+1)*bw-1 : i*bw] } : 16'b0;
    end
  endgenerate

  // --------------------------------------------------------
  // MAC Array
  // --------------------------------------------------------
  mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array_inst (
      .clk(clk),
      .reset(reset),
      // .mode(mode) is removed because mode is now packed inside inst_w[2]
      .in_w(l0_out),
      .inst_w(inst_w),      // Passing 3-bit instruction
      .in_n(array_in_n),    
      .out_s(array_out_s),  
      .valid(array_valid)
  );

  // --------------------------------------------------------
  // OFIFO
  // --------------------------------------------------------
  ofifo #(.col(col), .bw(psum_bw)) ofifo_inst (
      .clk(clk),
      .reset(reset),
      .in(array_out_s),     
      .out(fifo_out_wire),  
      .rd(ofifo_rd),        
      .wr(array_valid),
      .o_full(),
      .o_ready(),
      .o_valid(o_ofifo_valid)
  );

  // --------------------------------------------------------
  // SFP
  // --------------------------------------------------------
  sfp #(.col(col), .psum_bw(psum_bw)) sfp_inst (
      .clk(clk),
      .reset(reset),
      .data_in(fifo_out_wire), 
      .acc_in(i_pmem_data),    
      .acc_en(sfp_acc_en),
      .relu_en(1'b0),       
      .data_out(sfp_out_wire)  
  );

  assign o_sfp_out = sfp_out_wire;

endmodule