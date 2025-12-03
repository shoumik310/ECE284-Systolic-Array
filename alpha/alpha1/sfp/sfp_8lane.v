module sfp_8lane (clk, reset, data_in, acc_en, data_out, flush_en);
  
  parameter col = 8;
  parameter psum_bw = 16;

  input clk, reset;
  input [col*psum_bw-1:0] data_in; 
  input acc_en;                    // 1 => accumulation mode
  input [2:0] flush_en; //flush acc psum to SRAM

  output [3*col*psum_bw-1:0] data_out; // 3 windows per lane

  genvar i;
  generate
  for (i = 0; i < col; i = i + 1) begin : per_lane
	reg signed [psum_bw-1:0] d0, d1, d2;
	always @(posedge clk) begin
		if (reset) begin
			d0 <= 0;
			d1 <= 0;
			d2 <= 0;
		end else if (acc_en) begin
			d2 <= d1;
			d1 <= d0;
			d0 <= data_in[psum_bw*(i+1)-1 : psum_bw*i];
		end
	end
	
    sfp_lane #(.psum_bw(psum_bw)) sfp_lane S0(
      .clk(clk),
      .reset(reset),
      .acc_en(acc_en),
      .flush_en(flush_en),
      .data_in(d0),s
      .data_out(data_out[psum_bw*(i+1)-1:psum_bw*i])
    );
    sfp_lane #(.psum_bw(psum_bw)) sfp_lane S1(
      .clk(clk),
      .reset(reset),
      .acc_en(acc_en),
      .flush_en(flush_en),
      .data_in(d1),
      .data_out(data_out[col*psum_bw + psum_bw*(i+1)-1 : col*psum_bw + psum_bw*i])
    );
    sfp_lane #(.psum_bw(psum_bw)) sfp_lane S2(
      .clk(clk),
      .reset(reset),
      .acc_en(acc_en),
      .flush_en(flush_en),
      .data_in(d2),
      .data_out(data_out[2*col*psum_bw + psum_bw*(i+1)-1 : 2*col*psum_bw + psum_bw*i])
    );
  end
  endgenerate

endmodule
