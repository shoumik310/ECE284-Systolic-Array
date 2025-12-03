module sfp_8lane (clk, reset, data_in, acc_en, data_out);
  
  parameter col = 8;
  parameter psum_bw = 16;

  input clk, reset;
  input [col*psum_bw-1:0] data_in; 
  input acc_en;                    // 1 => accumulation mode
  output [col*psum_bw-1:0] data_out;

  genvar i;
  generate
  for (i = 0; i < col; i = i + 1) begin : sfp_col
    sfp_lane #(.psum_bw(psum_bw)) sfp_instance(
      .clk(clk),
      .reset(reset),
      .acc_en(acc_en),
      .data_in(data_in[psum_bw*(i+1)-1:psum_bw*i]),
      .data_out(data_out[psum_bw*(i+1)-1:psum_bw*i])
    );
  end
  endgenerate

endmodule