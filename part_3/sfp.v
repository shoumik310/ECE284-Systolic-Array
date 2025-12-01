module sfp (clk, reset, data_in, acc_in, acc_en, relu_en, data_out);
  
  parameter col = 8;
  parameter psum_bw = 16;

  input clk, reset;
  input [col*psum_bw-1:0] data_in; // From MAC Array
  input [col*psum_bw-1:0] acc_in;  // From Psum SRAM
  input acc_en;                    // Accumulation Enable
  input relu_en;                   // ReLU Enable
  output [col*psum_bw-1:0] data_out;

  genvar i;
  generate
    for (i = 0; i < col; i = i + 1) begin : sfp_col
      wire signed [psum_bw-1:0] psum_curr;
      wire signed [psum_bw-1:0] psum_prev;
      reg signed [psum_bw-1:0] result;
      reg signed [psum_bw-1:0] sum; // FIXED: Moved declaration here, outside the always block

      assign psum_curr = data_in[(i+1)*psum_bw-1 : i*psum_bw];
      assign psum_prev = acc_in[(i+1)*psum_bw-1 : i*psum_bw];

      always @(*) begin
        // 1. Accumulation
        if (acc_en) 
            sum = psum_curr + psum_prev;
        else 
            sum = psum_curr;

        // 2. ReLU (Rectified Linear Unit)
        if (relu_en && sum < 0)
            result = 0;
        else
            result = sum;
      end

      assign data_out[(i+1)*psum_bw-1 : i*psum_bw] = result;
    end
  endgenerate

endmodule