// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_row (clk, out_s, in_w, in_n, valid, inst_w, reset);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  output [col-1:0] valid;
  input  [bw-1:0] in_w; 
  input  [2:0] inst_w; // Updated to 3 bits [2:0]
  input  [psum_bw*col-1:0] in_n;

  wire  [(col+1)*bw-1:0] temp;
  assign temp[bw-1:0]   = in_w;

  // Updated width for 3-bit instructions
  wire [3*(col+1)-1:0] inst_bus; 
  assign inst_bus[2:0] = inst_w; 

  genvar i;
  
  for (i=1; i < col+1 ; i=i+1) begin : col_num
      mac_tile #(.bw(bw), .psum_bw(psum_bw)) mac_tile_instance (
         .clk(clk),
         .reset(reset),
         .in_w( temp[bw*i-1:bw*(i-1)]),
         .out_e(temp[bw*(i+1)-1:bw*i]),
         // Updated slicing for 3-bit instructions
         .inst_w( inst_bus[3*i-1 : 3*(i-1)] ), 
         .inst_e( inst_bus[3*i+2 : 3*i]   ), 
         .in_n( in_n[psum_bw*i-1 : psum_bw*(i-1)] ),
         .out_s( out_s[psum_bw*i-1 : psum_bw*(i-1)] )
      );
      // Valid signal is based on the 'Execute' bit (bit 1)
      assign valid[i-1] = inst_bus[3*i+1];
  end

endmodule