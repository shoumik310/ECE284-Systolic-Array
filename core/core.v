module core (clk, inst, ofifo_valid, D_xmem, sfp_out, mode, reset);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input clk;
  input reset;
  input mode; //0: 4-bit act and 4-bit weight;    1: 2-bit act and 4-bit weight
  input [33:0] inst;          
  input [row*bw-1:0] D_xmem;  
  
  output ofifo_valid;
  output [col*psum_bw-1:0] sfp_out; 

  // --------------------------------------------------------
  // 1. Instruction Decoding
  // --------------------------------------------------------
  wire acc_en       = inst[33];
  wire cen_pmem     = inst[32];
  wire wen_pmem     = inst[31];
  wire [10:0] a_pmem= inst[30:20];
  wire cen_xmem     = inst[19];
  wire wen_xmem     = inst[18];
  wire [10:0] a_xmem= inst[17:7];
  wire ofifo_rd     = inst[6];
  wire l0_rd        = inst[3];
  wire l0_wr        = inst[2];
  wire execute      = inst[1];
  wire load         = inst[0];

  wire [1:0] inst_w = {execute, load}; 

  // --------------------------------------------------------
  // 2. Internal Wires
  // --------------------------------------------------------
  wire [row*bw-1:0] xmem_out;         
  wire [col*psum_bw-1:0] pmem_out;    
  wire [col*psum_bw-1:0] pmem_in;     
  
  // The SFP output connects to the PMEM Input
  assign pmem_in = sfp_out;

  // --------------------------------------------------------
  // 3. Activation/Weight SRAM (XMEM)
  // --------------------------------------------------------
  sram_32b_w2048 xmem_inst (
      .CLK(clk),
      .D(D_xmem),       
      .Q(xmem_out),     
      .CEN(cen_xmem),   
      .WEN(wen_xmem),   
      .A(a_xmem)        
  );

  // --------------------------------------------------------
  // 4. Psum SRAM (PMEM)
  // --------------------------------------------------------
  sram_128b_w2048 pmem_inst (
      .CLK(clk),
      .D(pmem_in),      // Data from SFP (128-bit)
      .Q(pmem_out),     // Data to SFP (128-bit)
      .CEN(cen_pmem),
      .WEN(wen_pmem),
      .A(a_pmem)
  );

  // --------------------------------------------------------
  // 5. Corelet Instance
  // --------------------------------------------------------
  corelet #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) corelet_inst (
      .clk(clk),
      .reset(reset),
      .inst_w(inst_w),
      .l0_rd(l0_rd),
      .l0_wr(l0_wr),
      .sfp_acc_en(acc_en),
      .ofifo_rd(ofifo_rd),
      .mode(mode),

      .i_xmem_data(xmem_out),   
      .i_pmem_data(pmem_out),   
      
      .o_sfp_out(sfp_out),      
      .o_ofifo_valid(ofifo_valid)
  );

endmodule