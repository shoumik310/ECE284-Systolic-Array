// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset);

parameter bw = 4;
parameter psum_bw = 16; // Restored to 16 to match system, change to 18 if desired

output [psum_bw-1:0] out_s;
input  [bw-1:0] in_w;
output [bw-1:0] out_e; 
input  [2:0] inst_w; // [2]=Mode, [1]=Execute, [0]=Load
output [2:0] inst_e;
input  [psum_bw-1:0] in_n;
input  clk;
input  reset;

reg [2:0] inst_q;
reg signed [bw-1:0] a_q; // Activation
reg signed [bw-1:0] b_q; // Weight
reg signed [psum_bw-1:0] c_q; // Shared Accumulator
reg load_ready_q;

wire signed [psum_bw-1:0] mac_out;

// Pass Activation East (Registered)
assign out_e = a_q;
assign inst_e = inst_q;

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
        .a(a_q), 
        .b(b_q),
        .c(c_q),
        .out(mac_out)
);

// Output Logic
// Mode 1 (OS): Output the REGISTERED weight (b_q) to maintain systolic timing.
// Mode 0 (WS): Output the MAC result (mac_out) for vertical accumulation.
assign out_s = (inst_q[2] == 1'b1) ? {{(psum_bw-bw){b_q[bw-1]}}, b_q} : mac_out;

always @ (posedge clk) begin
    if (reset == 1) begin
        inst_q <= 3'b000;
        load_ready_q <= 1'b1;
        a_q <= 0;
        b_q <= 0;
        c_q <= 0;
    end else begin
        inst_q <= inst_w;

        // Latch Activation (Common)
        if (inst_w[0] | inst_w[1]) begin
            a_q <= in_w;
        end
        
        // -------------------------------------------------------
        // OUTPUT STATIONARY MODE (Mode = 1)
        // -------------------------------------------------------
        if (inst_w[2] == 1'b1) begin
             // 1. Accumulate Locally
             // Reuse c_q. Feedback mac_out into c_q.
             if (inst_w[1]) begin
                 c_q <= mac_out;
             end

             // 2. Stream Weights (Systolic Flow)
             // Load b_q every cycle from North.
             if (inst_w[0]) begin
                 b_q <= in_n[bw-1:0]; 
             end
        end 
        
        // -------------------------------------------------------
        // WEIGHT STATIONARY MODE (Mode = 0)
        // -------------------------------------------------------
        else begin
             // 1. Vertical Accumulation Chain
             // Load c_q from North Psum.
             if (inst_w[1]) begin
                 c_q <= in_n;
             end

             // 2. Static Weight Loading
             // Load once, then lock (load_ready logic).
             if (inst_w[0] == 1'b1 && load_ready_q == 1'b1) begin
                 b_q <= in_w;
                 load_ready_q <= 1'b0;
             end
        end

        // Reset load ready if we switch modes or reset instruction
        if (inst_w == 0) load_ready_q <= 1'b1;
    end
end

endmodule