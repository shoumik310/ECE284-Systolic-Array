// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset,psum_flush,psum_bus);
parameter bw = 4;
parameter psum_bw = 16;
parameter bus_bw = 32;

output [psum_bw-1:0] out_s;
output [bus_bw-1:0] psum_bus;
input  [bw-1:0] in_w;
output [bw-1:0] out_e; 
input  [2:0] inst_w;
output [2:0] inst_e;
input  [psum_bw-1:0] in_n;
input  psum_flush;
input  clk;
input  reset;

reg [2:0] inst_q;
reg [bw-1:0] a_q; // activation (Unsigned)
reg signed [bw-1:0] b_q; // weight (Signed)
reg signed [psum_bw-1:0] c_q;
reg signed [psum_bw-1:0] psum_acc;
reg load_ready_q;
reg signed [psum_bw-1:0] temp_out;
reg flush_q; 

// Wires for MAC connectivity
wire signed [psum_bw-1:0] mac_out; 
wire signed [psum_bw-1:0] mac_c_in;
wire [bw-1:0] mac_a_in;        
wire signed [bw-1:0] mac_b_in; 

assign inst_e = {inst_w[2], inst_q[1:0]};

// --- RESTORED STANDARD OUTPUT ---
// Removed the combinational bypass. 
// We now rely on 'inst_q' delay logic to align loading.
assign out_e = a_q;

// --- MASKING LOGIC ---
wire is_ws_load = (!inst_w[2] && inst_w[0] && !inst_w[1]);
wire force_zero = flush_q || (inst_w == 3'b000 && !psum_flush) || is_ws_load;

assign mac_a_in = (force_zero) ? {bw{1'b0}} : a_q;
assign mac_b_in = (force_zero) ? $signed({bw{1'b0}}) : b_q;

// Feedback Mux
assign mac_c_in = (inst_w[2] || psum_flush || flush_q) ? psum_acc : c_q;

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
        .a(mac_a_in), 
        .b(mac_b_in),
        .c(mac_c_in),
	.out(mac_out)
);

assign out_s = temp_out;

// Drive bus when delayed flush is active
assign psum_bus = (flush_q == 1'b1) ? {{(bus_bw-psum_bw){psum_acc[psum_bw-1]}}, psum_acc} : 32'b0;

always @ (posedge clk or posedge reset) begin
    if (reset == 1) begin
        inst_q <= 3'b000;
        load_ready_q <= 1'b1;
        a_q <= 0;
        b_q <= 0;
        c_q <= 0;
        psum_acc <= 0;
        flush_q <= 0;
    end else begin
        flush_q <= psum_flush;
        
        // --- INSTRUCTION FLOW CONTROL ---
        // inst_w[2] (Mode) and inst_w[1] (Execute) propagate normally
        inst_q[2:1] <= inst_w[2:1];

        // inst_w[0] (Load) Logic:
        // Only propagate the LOAD instruction if:
        // 1. We have finished loading our own weight (load_ready_q == 0)
        // 2. OR We are in Output Stationary Mode (inst_w[2] == 1) where this logic doesn't apply
        if (load_ready_q == 1'b0 || inst_w[2] == 1'b1) begin 
            inst_q[0] <= inst_w[0];
        end else begin
            // If we are currently Loading (load_ready_q == 1), 
            // we swallow the Load instruction for 1 cycle (output 0).
            inst_q[0] <= 1'b0;
        end

        // --- PROPAGATION LOGIC ---
        if (inst_w[1] || inst_w[0]) begin
            a_q <= in_w;
        end
        
        if (inst_w[1]) begin
            if(inst_w[2] == 1'b0) begin 
                c_q <= in_n;
            end     
        end
        
        if ((inst_w[1] && inst_w[2]) || psum_flush) begin
            psum_acc <= mac_out; 
        end
        
        if (flush_q) begin
            psum_acc <= 0; 
        end
        
        // --- WEIGHT LOADING LOGIC ---
        if (inst_w[0] == 1'b1) begin
            if (inst_w[2] == 1'b1) begin 
                // OS Mode: Load from North
                b_q <= in_n[bw-1:0]; 
            end 
            else if (load_ready_q == 1'b1) begin 
                // WS Mode: Load from West ONCE
                b_q <= in_w; 
                load_ready_q <= 1'b0; 
            end
        end
    end
    
end

always @(*) begin
    if (psum_flush == 1'b0 && flush_q == 1'b0) begin
        if (inst_w[2] == 1'b1) begin
            temp_out = in_n;
        end else begin
            temp_out = mac_out;
        end
    end else begin
        temp_out = 0;
    end      
end

endmodule