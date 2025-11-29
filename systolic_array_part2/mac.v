// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
// Perform 2X4 bit MAC operation
module mac (out, a, b, c);

parameter act_bw = 2;
parameter w_bw = 4;
parameter psum_bw = 12;

output signed [psum_bw-1:0] out;
input signed  [act_bw-1:0] a;  // activation
input signed  [w_bw-1:0] b;  // weight
input signed  [psum_bw-1:0] c;


wire signed [2*(act_bw + w_bw):0] product;
wire signed [psum_bw-1:0] psum;
wire signed [act_bw:0]   a_pad;

assign a_pad = {1'b0, a}; // force to be unsigned number
assign product = a_pad * b;

assign psum = product + c;
assign out = psum;

endmodule
