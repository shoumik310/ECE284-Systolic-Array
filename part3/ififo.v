// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module ififo (clk, in, out, rd, wr, o_full, reset, o_ready);

  parameter col  = 8;
  parameter bw = 4;

  input  clk;
  input  wr;
  input  rd;
  input  reset;
  input  [col*bw-1:0] in;
  output [col*bw-1:0] out;
  output o_full;
  output o_ready;

  wire [col-1:0] empty;
  wire [col-1:0] full;
  reg [col-1:0] rd_en;
  
  genvar i;

  // o_full is high if ANY of the column FIFOs are full
  assign o_full  = |full; 
  
  // o_ready is high only if there is room in ALL columns
  assign o_ready = !o_full; 

  for (i=0; i<col ; i=i+1) begin : col_num
      fifo_depth64 #(.bw(bw)) fifo_instance (
        .rd_clk(clk),
        .wr_clk(clk),
        .rd(rd_en[i]),
        .wr(wr),                       // Write signal broadcasts to all columns
        .o_empty(empty[i]),
        .o_full(full[i]),
        .in(in[(i+1)*bw-1 : i*bw]),    // Input Bit Slicing
        .out(out[(i+1)*bw-1 : i*bw]),  // Output Bit Slicing
        .reset(reset)
      );
  end

  always @ (posedge clk) begin
   if (reset) begin
      rd_en <= 0;
   end
   else begin
       // Staggered read for systolic flow (diagonal wavefront)
       // Activates col 0 first, then col 1, etc.
       rd_en <= {rd_en[col-2:0], rd};
    end
  end

endmodule