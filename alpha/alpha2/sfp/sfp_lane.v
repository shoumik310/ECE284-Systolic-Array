module sfp_lane (clk, reset, data_in, acc_en, data_out);

  parameter psum_bw = 16;

  input clk, reset;
  input acc_en;                    // Accumulation Enable
  input signed [psum_bw-1:0] data_in; 
  output [psum_bw-1:0] data_out;

  reg signed [psum_bw-1:0] psum_q;

  wire signed [psum_bw-1:0] next_psum = acc_en ? psum_q + data_in : psum_q; 
  assign data_out = psum_q > 0 ? psum_q : 0; // Output is always RELU
     

  always @(posedge clk) begin
    if( reset == 1'b1 ) begin
        psum_q <= 0;
    end
    else begin
        psum_q <= next_psum;
    end

  end


endmodule