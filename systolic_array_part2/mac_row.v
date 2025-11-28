// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_row (clk, out_s, in_w, in_n, valid, inst_w, mode, reset);
  parameter act_bw = 2;
  parameter w_bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;

  input  clk, reset;
  output [2*psum_bw*col-1:0] out_s;
  output [col-1:0] valid;
  input  [w_bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [1:0] inst_w;
  input mode; //0: 4-bit act and 4-bit weight;    1: 2-bit act and 4-bit weight

  input  [2*psum_bw*col-1:0] in_n;

  wire  [(col+1)*w_bw-1:0] temp;
  assign temp[w_bw-1:0]   = in_w;
  wire [2*(col+1)-1:0] inst_bus;
  assign inst_bus[1:0] = inst_w; 

  genvar i;

  for (i=1; i < col+1 ; i=i+1) begin : col_num
        mac_tile #(.act_bw(act_bw), .w_bw(w_bw), .psum_bw(psum_bw)) mac_tile_instance (
          .clk(clk),
          .reset(reset),
          .in_w(temp[w_bw*i-1:w_bw*(i-1)]),
          .out_e(temp[w_bw*(i+1)-1:w_bw*i]),
          .inst_w(inst_bus[2*i-1 : 2*(i-1)] ), 
          .inst_e(inst_bus[2*(i+1)-1 : 2*i]), 
          .in_n(in_n[2*psum_bw*i-1 : 2*psum_bw*(i-1)]),
          .mode(mode),
          .out_s(out_s[2*psum_bw*i-1 : 2*psum_bw*(i-1)])
        );
        assign valid[i-1] = inst_bus[2*i+1];
  end

endmodule