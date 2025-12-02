module sfp_lane (clk, reset, data_in, acc_en, data_out,flush_en);

  parameter psum_bw = 16;

  input clk, reset;
  input acc_en;                    // Accumulation Enable
  input signed [psum_bw-1:0] data_in; 
  output reg [psum_bw-1:0] data_out;
  input flush_en;
  reg signed [psum_bw-1:0] psum_q;

  //wire signed [psum_bw-1:0] next_psum = acc_en ? psum_q + data_in : psum_q; 
  //assign data_out = psum_q;
     

  always @(posedge clk) begin
    if( reset == 1'b1 ) begin
        psum_q <= 0;
        data_out <= 0;
    end
    else if (flush_en == 1'b1) begin
        //psum_q <= next_psum;
        data_out <= psum_q; //output acc value
        psum_q <= 0;
    end
    else if (acc_en == 1'b1) begin
	psum_q <= psum_q + data_in;
    end
  end


endmodule
