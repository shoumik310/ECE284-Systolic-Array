// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_array (clk, reset, out_s, in_w, in_n, inst_w, valid);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  input  [row*bw-1:0] in_w; 
  input  [2:0] inst_w; // Updated to 3 bits
  input  [psum_bw*col-1:0] in_n;
  output [col-1:0] valid;

  // Updated width: 3 bits per row
  reg    [3*row-1:0] inst_w_temp; 
  wire   [psum_bw*col*(row+1)-1:0] temp;
  wire   [row*col-1:0] valid_temp;

  genvar i;
 
  assign out_s = temp[psum_bw*col*9-1:psum_bw*col*8];
  
  // Connect North Input to the temp wire for the first row
  // This enables vertical weight streaming in OS mode
  assign temp[psum_bw*col*1-1:psum_bw*col*0] = in_n;
  
  assign valid = valid_temp[row*col-1:row*col-8];

  for (i=1; i < row+1 ; i=i+1) begin : row_num
      mac_row #(.bw(bw), .psum_bw(psum_bw)) mac_row_instance (
         .clk(clk),
         .reset(reset),
         .in_w(in_w[bw*i-1:bw*(i-1)]),
         // Updated slicing for 3-bit instructions
         .inst_w(inst_w_temp[3*i-1:3*(i-1)]),
         .in_n(temp[psum_bw*col*i-1:psum_bw*col*(i-1)]),
         .valid(valid_temp[col*i-1:col*(i-1)]),
         .out_s(temp[psum_bw*col*(i+1)-1:psum_bw*col*(i)])
      );
  end

  always @ (posedge clk) begin
    // Updated shift register logic for 3 bits
    inst_w_temp[2:0]   <= inst_w; 
    inst_w_temp[5:3]   <= inst_w_temp[2:0]; 
    inst_w_temp[8:6]   <= inst_w_temp[5:3]; 
    inst_w_temp[11:9]  <= inst_w_temp[8:6]; 
    inst_w_temp[14:12] <= inst_w_temp[11:9]; 
    inst_w_temp[17:15] <= inst_w_temp[14:12]; 
    inst_w_temp[20:18] <= inst_w_temp[17:15]; 
    inst_w_temp[23:21] <= inst_w_temp[20:18]; 
  end

endmodule