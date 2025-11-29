// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module ofifo (clk, in, out, rd, wr, o_full, reset, o_ready, o_valid);

  parameter col  = 8;
  parameter bw = 4;

  input  clk;
  input  [col-1:0] wr;    // Vector: 1 bit per column
  input  rd;
  input  reset;
  input  [col*bw-1:0] in;
  output [col*bw-1:0] out;
  output o_full;
  output o_ready;
  output o_valid;

  wire [col-1:0] empty;
  wire [col-1:0] full;
  reg  rd_en;             // Scalar: Reads all columns simultaneously
  
  genvar i;

  // Ready if NOT full (aggregated)
  assign o_ready = !o_full; 
  // Full if ANY column is full
  assign o_full  = |full;   
  // Valid ONLY if ALL columns have data (none are empty)
  assign o_valid = !(|empty); 

  for (i=0; i<col ; i=i+1) begin : col_num
      fifo_depth64 #(.bw(bw)) fifo_instance (
        .rd_clk(clk),
        .wr_clk(clk),
        .rd(rd_en),                   // Global read enable
        .wr(wr[i]),                   // Individual write enable per column
        .o_empty(empty[i]),
        .o_full(full[i]),
        .in(in[(i+1)*bw-1 : i*bw]),   // Slice input
        .out(out[(i+1)*bw-1 : i*bw]), // Slice output
        .reset(reset));
  end


  always @ (posedge clk) begin
   if (reset) begin
      rd_en <= 0;
   end
   else begin
      // Read out all columns at a time
      rd_en <= rd;
   end
 
  end

endmodule