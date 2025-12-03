// module corelet definition
module corelet (
    clk, 
    reset, 
    mode,
    inst_w,
    l0_rd, 
    l0_wr,
    ififo_wr, 
    ififo_rd, 
    sfp_acc_en,
    psum_flush, // NEW: Flush signal for OS mode
    ofifo_rd,
    i_xmem_data,      
    i_pmem_data, 
    o_sfp_out,   
    o_ofifo_valid,
    o_psum_bus  // NEW: Bus output for OS mode
);
  parameter row = 8;
  parameter col = 8;
  parameter bw = 4;
  parameter psum_bw = 16;

  // --- Port Declarations ---
  input clk;
  input reset;
  input mode;
  input [2:0] inst_w;
  input l0_rd;
  input l0_wr;
  input ififo_wr;
  input ififo_rd;
  input sfp_acc_en;
  input psum_flush; // NEW
  input ofifo_rd;

  // Data Interfaces
  input  [row*bw-1:0] i_xmem_data;      
  input  [col*psum_bw-1:0] i_pmem_data;
  output [col*psum_bw-1:0] o_sfp_out;   
  output o_ofifo_valid;
  output [col*psum_bw-1:0] o_psum_bus; // NEW

  // --- Internal Logic ---
  wire [row*bw-1:0] l0_out;
  wire [col*bw-1:0] ififo_out;          
  wire [col*psum_bw-1:0] array_in_n;
  wire [col*psum_bw-1:0] array_out_s;
  wire [col-1:0] array_valid;
  wire [col*psum_bw-1:0] fifo_out_wire; 
  wire [col*psum_bw-1:0] sfp_out_wire;

  // 1. L0 Buffer
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

  // 2. IFIFO
  ififo #(.col(col), .bw(bw)) ififo_inst (
      .clk(clk),
      .reset(reset),
      .in(i_pmem_data[col*bw-1:0]), // Input from PMEM LSBs
      .out(ififo_out),
      .rd(ififo_rd),
      .wr(ififo_wr),
      .o_full(),
      .o_ready()
  );

  // 3. Array North Input Logic
  genvar i;
  generate
    for (i=0; i<col; i=i+1) begin : padding
        assign array_in_n[(i+1)*psum_bw-1 : i*psum_bw] = 
            (mode) ? { {(psum_bw-bw){1'b0}}, ififo_out[(i+1)*bw-1 : i*bw] } : 16'b0;
    end
  endgenerate

  // 4. MAC Array
  mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array_inst (
      .clk(clk),
      .reset(reset),
      .in_w(l0_out),
      .inst_w(inst_w),      
      .in_n(array_in_n),    
      .out_s(array_out_s),  
      .valid(array_valid),
      .psum_flush(psum_flush), // NEW: Connect flush signal
      .psum_bus(o_psum_bus)    // NEW: Connect bus output
  );

  // 5. OFIFO
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

  // 6. SFP
 sfp_8lane #(.col(col), .psum_bw(psum_bw)) sfp_inst (
      .clk(clk),
      .reset(reset),
      .data_in(i_pmem_data), 
      .acc_en(sfp_acc_en),
      .data_out(o_sfp_out)  
  );

  assign o_sfp_out = sfp_out_wire;

endmodule