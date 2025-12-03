// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac(
    input [3:0]a,
    input [3:0]b,
    input signed [15:0]c,
    output reg signed [15:0]out
    );
    reg [3:0]t;
    reg signed[7:0]mul_out;
    always@(*) begin
        if (b[3] == 1'b1) begin
           t = (~b + 1'b1);
           mul_out = (~(a*t)+1'b1);
         end 
         else begin
            mul_out = a*b;
         end  
    assign out = mul_out+ c;
    end
endmodule

