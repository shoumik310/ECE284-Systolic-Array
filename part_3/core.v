module core (
    clk, 
    inst, 
    ofifo_valid, 
    D_xmem, 
    D_pmem, 
    sfp_out, 
    reset
);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input clk;
  input reset;
  input [34:0] inst;          
  input [row*bw-1:0] D_xmem;  
  input [col*psum_bw-1:0] D_pmem; 
  
  output ofifo_valid;
  output [col*psum_bw-1:0] sfp_out; 

  // --- Instruction Decoding ---
  wire mode         = inst[34]; 
  wire acc_en       = inst[33];
  wire cen_pmem     = inst[32];
  wire wen_pmem     = inst[31];
  wire [10:0] a_pmem= inst[30:20];
  wire cen_xmem     = inst[19];
  wire wen_xmem     = inst[18];
  wire [10:0] a_xmem= inst[17:7];
  wire ofifo_rd     = inst[6];
  wire ififo_wr     = inst[5];  
  wire ififo_rd     = inst[4];  
  wire l0_rd        = inst[3];
  wire l0_wr        = inst[2];
  wire execute      = inst[1];
  wire load         = inst[0];

  wire [2:0] inst_w = {mode, execute, load}; 

  // --- Internal Wires ---
  wire [row*bw-1:0] xmem_out;         
  wire [col*psum_bw-1:0] pmem_out;    
  wire [col*psum_bw-1:0] pmem_in;     
  
  // Mux for Psum Memory Input
  assign pmem_in = (acc_en) ? sfp_out : D_pmem;

  // 1. Activation/Weight SRAM (XMEM)
  sram_32b_w2048 xmem_inst (
      .CLK(clk),
      .D(D_xmem),       
      .Q(xmem_out),     
      .CEN(cen_xmem),   
      .WEN(wen_xmem),   
      .A(a_xmem)        
  );

  // 2. Psum SRAM (PMEM)
  sram_128b_w2048 pmem_inst (
      .CLK(clk),
      .D(pmem_in),      
      .Q(pmem_out),     
      .CEN(cen_pmem),
      .WEN(wen_pmem),
      .A(a_pmem)
  );

  // 3. Corelet Instance
  corelet #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) corelet_inst (
      .clk(clk),
      .reset(reset),
      .mode(mode),
      .inst_w(inst_w),          
      .l0_rd(l0_rd),
      .l0_wr(l0_wr),
      .ififo_wr(ififo_wr),
      .ififo_rd(ififo_rd),
      .sfp_acc_en(acc_en),
      .ofifo_rd(ofifo_rd),
      
      .i_xmem_data(xmem_out),   
      .i_pmem_data(pmem_out),   
      
      .o_sfp_out(sfp_out),      
      .o_ofifo_valid(ofifo_valid)
  );

endmodule