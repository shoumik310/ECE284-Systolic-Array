// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module sram_128b_w2048 (CLK, D, Q, CEN, WEN, A);

  input  CLK;
  input  WEN;
  input  CEN;
  input  [383:0] D; //3*128b windows
  input  [10:0] A;
  output [127:0] Q;
  parameter num = 2048;

  reg [127:0] memory [num-1:0];
  reg [10:0] add_q;
  assign Q = memory[add_q];
  
  reg [1:0] wr_phase; //0,1,2 -> S0,S1,S2
  reg wr_active;
  reg [10:0] base_addr;
  always @ (posedge CLK) begin

   if (!CEN && WEN) // read 
      add_q <= A;
   if (!CEN && !WEN && !wr_active) begin // write
      wr_active <= 1;
      wr_phase <= 0;
      base_addr <= A;
      //memory[A] <= D;
   end
   if (wr_active) begin
      case (wr_phase)
         0: memory[base_addr] <= D[383:256]; //S0 
         1: memory[base_addr+1] <= D[255:128]; //S1
         2: memory[base_addr+2] <= D[127:0]; //S2
      endcase
      wr_phase <= wr_phase +1;

      if (wr_phase == 2)
         wr_active <= 0; //done after cycle 3
  end
end
endmodule
