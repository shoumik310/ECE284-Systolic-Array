// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_d_gated (out, a, b, c);

// ALPHA:
// POWER OPTIM #2:
// USES DATA GATING TECHNIQUE TO BYPASS THE MAC UNIT WHEN WEIGHTS OR ACTIVATIONS ARE ZERO
// DYNAMIC POWER REDUCTION BY PREVENTING UNNECESSARY SWITCHING INSIDE THE COMPLEX MAC UNIT
//

parameter bw = 4;
parameter psum_bw = 16;

output signed [psum_bw-1:0] out;
input signed  [bw-1:0] a;  // activation
input signed  [bw-1:0] b;  // weight
input signed  [psum_bw-1:0] c;


wire signed [2*bw:0] product;
wire signed [psum_bw-1:0] mac_out;
wire signed [psum_bw-1:0] psum;
wire signed [bw:0]   a_pad;

wire mac_bypass;
wire signed [bw:0] d_gated_pad_a;
wire signed [bw-1:0] d_gated_b;
wire signed [psum_bw-1:0] d_gated_c;

// set when we're bypassing the mac unit:
assign mac_bypass = ( (a == {bw{1'b0}}) 
				   || (b == {bw{1'b0}}) );

// replicate this bit and and the operands to force MAC's inputs to '0 when MAC's result is not necessary (ie out = c since weight or activation is 0)
wire data_gate_bit = ~mac_bypass;

assign a_pad = {1'b0, a}; // force to be unsigned number

assign d_gated_pad_a = (a_pad) & ({bw+1{data_gate_bit}});
assign d_gated_b	 = (b)     & ({bw{data_gate_bit}});
assign d_gated_c	 = (c)     & ({psum_bw{data_gate_bit}});

// no data gating:
// assign product = a_pad * b;
// assign psum = product + c;
// assign out = psum;

// with data gating:
assign product = d_gated_pad_a * d_gated_b;
assign mac_out = product + d_gated_c;
assign out = (mac_bypass) ? (c) : (mac_out);

endmodule
