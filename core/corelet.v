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

  input clk, reset;
  input [1:0] inst_w;
  input l0_rd, l0_wr;
  input sfp_acc_en;
  input ofifo_rd;

  // Data Interfaces
  input  [row*bw-1:0] i_xmem_data;     // 32-bit Input from XMEM
  input  [col*psum_bw-1:0] i_pmem_data; // 128-bit Input from PMEM (for Accumulation)

  output [col*psum_bw-1:0] o_sfp_out;   // 128-bit Output from SFP
  output [col*psum_bw-1:0] o_ofifo_out;   // 128-bit Output from OFIFO
  output o_ofifo_valid;

  // Internal Wires
  wire [row*bw-1:0] l0_out;
  wire [col*psum_bw-1:0] array_out_s;
  wire [col-1:0] array_valid;
  
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
      .in_n(128'b0),        // North input unused
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

  // --------------------------------------------------------
  // SFP (Accumulation & ReLU)
  // --------------------------------------------------------
  sfp_8lane #(.col(col), .psum_bw(psum_bw)) sfp_inst (
      .clk(clk),
      .reset(reset),
      .data_in(i_pmem_data),
      .acc_en(sfp_acc_en),  
      .data_out(o_sfp_out)  
  );


endmodule