module controller (
    clk, reset, start,
    
    // Memory Controls
    sram_addr, sram_wr,
    
    // Corelet Controls
    l0_wr, l0_rd, l0_full, l0_ready,
    inst_w,
    sfp_acc_en, sfp_relu_en,
    ofifo_rd,
    
    // Status
    done
);

parameter row = 8; // Number of rows to load
parameter total_ops = 8; // Example: Processing 8 vectors

input clk, reset, start;

// Memory Output
output reg [10:0] sram_addr;
output sram_wr; // Always 0 (Read only) for this controller

// Corelet Outputs
output reg l0_wr;
output reg l0_rd;
input l0_full;
input l0_ready;

output reg [1:0] inst_w; // [1]: Execute, [0]: Load Weight
output reg sfp_acc_en;
output reg sfp_relu_en;
output reg ofifo_rd;

output reg done;

// Internal State
reg [3:0] state;
reg [4:0] count; // Counter for operations

// State Encodings
localparam S_IDLE           = 4'd0;
localparam S_LOAD_W_SRAM    = 4'd1; // Fetch weights from Mem -> L0
localparam S_FEED_W_ARRAY   = 4'd2; // Push L0 -> Array (Weight Load Mode)
localparam S_LOAD_X_SRAM    = 4'd3; // Fetch inputs from Mem -> L0
localparam S_EXECUTE        = 4'd4; // Push L0 -> Array (Execute Mode)
localparam S_DONE           = 4'd5;

assign sram_wr = 1'b0; // We are only reading from Input SRAM

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state       <= S_IDLE;
        count       <= 0;
        sram_addr   <= 0;
        l0_wr       <= 0;
        l0_rd       <= 0;
        inst_w      <= 2'b00;
        sfp_acc_en  <= 0;
        sfp_relu_en <= 0;
        done        <= 0;
    end else begin
        
        // Defaults
        l0_wr <= 0; 
        
        case (state)
            // IDLE: Wait for start signal
            S_IDLE: begin
                done <= 0;
                if (start) begin
                    state <= S_LOAD_W_SRAM;
                    count <= 0;
                    sram_addr <= 0; // Start of Weights in SRAM
                end
            end

            // LOAD WEIGHTS: SRAM -> L0
            S_LOAD_W_SRAM: begin
                if (!l0_full) begin
                    l0_wr <= 1;        // Write enable to L0
                    sram_addr <= sram_addr + 1;
                    count <= count + 1;
                    
                    // Assuming we load 'row' number of weight words
                    if (count == row - 1) begin
                        state <= S_FEED_W_ARRAY;
                        count <= 0;
                        l0_wr <= 0; // Stop writing
                    end
                end
            end

            // FEED WEIGHTS: L0 -> MAC Array
            S_FEED_W_ARRAY: begin
                // Instruction 01: Load Weights (inst_w[0] is high)
                inst_w <= 2'b01; 
                l0_rd  <= 1;     // Enable L0 read (broadcasts to array)
                
                count <= count + 1;
                
                // Allow enough cycles for L0 to drain and weights to propagate
                if (count == row + 2) begin 
                    state <= S_LOAD_X_SRAM;
                    count <= 0;
                    l0_rd <= 0;
                    inst_w <= 2'b00;
                    // Reset SRAM address for Inputs (Offset by row)
                    sram_addr <= row; 
                end
            end

            // LOAD INPUTS: SRAM -> L0
            S_LOAD_X_SRAM: begin
               if (!l0_full) begin
                    l0_wr <= 1;
                    sram_addr <= sram_addr + 1;
                    count <= count + 1;
                    
                    if (count == row - 1) begin
                        state <= S_EXECUTE;
                        count <= 0;
                        l0_wr <= 0;
                    end
                end
            end

            // EXECUTE: L0 -> MAC Array -> SFP
            S_EXECUTE: begin
                // Instruction 10: Execute (inst_w[1] is high)
                inst_w <= 2'b10;
                l0_rd  <= 1;
                
                // Enable post-processing
                sfp_relu_en <= 1; 
                sfp_acc_en  <= 1; // Example: Enable accumulation
                
                count <= count + 1;
                
                // Wait for L0 to drain and computation to propagate
                if (count == row + 4) begin
                    state <= S_DONE;
                    l0_rd <= 0;
                    inst_w <= 2'b00;
                    sfp_relu_en <= 0;
                    sfp_acc_en <= 0;
                end
            end

            S_DONE: begin
                done <= 1;
                state <= S_IDLE;
            end
            
        endcase
    end
  end

endmodule