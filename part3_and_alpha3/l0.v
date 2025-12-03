// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module l0 (clk, in, out, rd, wr, o_full, reset, o_ready);

  parameter row  = 8;
  parameter bw = 4;

  input  clk;
  input  wr;
  input  rd;
  input  reset;
  input  [row*bw-1:0] in;
  output [row*bw-1:0] out;
  output o_full;
  output o_ready;

  wire [row-1:0] empty;
  wire [row-1:0] full;
  reg [row-1:0] rd_en;
  
  genvar i;

  // o_full is high if ANY of the row FIFOs are full
  assign o_full  = |full; 
  
  // o_ready is high only if there is room in ALL rows (none are full)
  assign o_ready = !o_full; 

  generate
  for (i=0; i<row ; i=i+1) begin : row_num
      fifo_depth64 #(.bw(bw)) fifo_instance (
        .rd_clk(clk),
        .wr_clk(clk),
        .rd(rd_en[i]),
        .wr(wr),                       // Write signal broadcasts to all rows
        .o_empty(empty[i]),            // Wired to internal bus
        .o_full(full[i]),              // Wired to internal bus
        .in(in[(i+1)*bw-1 : i*bw]),    // Input Bit Slicing
        .out(out[(i+1)*bw-1 : i*bw]),  // Output Bit Slicing
        .reset(reset)
      );
  end
  endgenerate

  always @ (posedge clk) begin
   if (reset) begin
      rd_en <= 8'b00000000;
   end
   else begin
      // read all rows at a time 
      // rd_en <= {row{rd}}; 

      // read 1 row at a time
       rd_en <= {rd_en[row-2:0], rd};
    end
  end

endmodule