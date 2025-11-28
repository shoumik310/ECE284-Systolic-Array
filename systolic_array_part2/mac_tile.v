// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, mode, reset);
parameter act_bw = 2;
parameter w_bw = 4;
parameter psum_bw = 16;

output [2*psum_bw-1:0] out_s;
input  [w_bw-1:0] in_w;
output [w_bw-1:0] out_e; 
input  [1:0] inst_w;    // inst[1]:execute, inst[0]: kernel loading
output [1:0] inst_e;
input  [2*psum_bw-1:0] in_n;
input  clk;
input mode; //0: 4-bit act and 4-bit weight;    1: 2-bit act and 4-bit weight
input  reset;

reg [1:0] inst_q;
reg signed [2*act_bw-1:0] a_q; // activation
reg signed [2*w_bw-1:0] b_q; // weight
reg signed [2*psum_bw-1:0] c_q;
reg load_ready_q;
reg cnt;

wire signed [2*psum_bw-1:0] mac_out;

assign out_e = a_q;
assign inst_e = inst_q;

mac #(.act_bw(act_bw), .w_bw(w_bw), .psum_bw(psum_bw)) mac_instance1 (
        .a(a_q[act_bw-1:0]), 
        .b(b_q[w_bw-1:0]),
        .c(c_q[psum_bw-1:0]),
	.out(mac_out[psum_bw-1:0])
);

mac #(.act_bw(act_bw), .w_bw(w_bw), .psum_bw(psum_bw)) mac_instance2 (
        .a(a_q[2*act_bw-1:act_bw]), 
        .b(b_q[2*w_bw-1:w_bw]),
        .c(c_q[2*psum_bw-1:psum_bw]),
	.out(mac_out[2*psum_bw-1:psum_bw])
);

assign out_s = mac_out;

always @ (posedge clk) begin
    if (reset == 1) begin
        inst_q <= 2'b00;
        load_ready_q <= 1'b1;
        cnt <= 1'b0;
        
        a_q <= 0;
        b_q <= 0;
        c_q <= 0;
        
    end
    else begin    
        inst_q[1] <= inst_w[1];

        if (inst_w[0] | inst_w[1]) begin
            a_q <= in_w;
        end
        
        if (inst_w[1]) begin
            c_q <= in_n;
        end

        if (inst_w[0] == 1'b1 && load_ready_q == 1'b1) begin
            if (mode == 0) begin
                b_q <= {in_w, in_w};
                load_ready_q <= 1'b0;
            end
            else begin
                case (cnt)
                    1'b0: b_q[w_bw-1:0] <= in_w;
                    1'b1: b_q[2*w_bw-1:w_bw] <= in_w;
                endcase
                cnt <= cnt + 1'b1;
                if (cnt > 1) begin
                    load_ready_q <= 1'b0;
                end
            end
        end

        if (load_ready_q == 1'b0) begin
            inst_q[0] <= inst_w[0];
        end
    end
end

endmodule