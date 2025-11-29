module controller (
    clk, reset, start, mode,
    
    // Memory Controls
    sram_addr, sram_wr,
    
    // Corelet Controls
    l0_wr, l0_rd, l0_full, l0_ready,
    ififo_wr, ififo_rd, ififo_full, ififo_ready,
    inst_w,
    sfp_acc_en, sfp_relu_en,
    ofifo_rd,
    
    // Status
    done
);

  parameter row = 8;
  parameter col = 8; 

  input clk, reset, start, mode; // mode 0: WS, 1: OS
  
  // Memory Output
  output reg [10:0] sram_addr;
  output sram_wr; 

  // Corelet Outputs
  output reg l0_wr;
  output reg l0_rd;
  input l0_full;
  input l0_ready;

  output reg ififo_wr;
  output reg ififo_rd;
  input ififo_full;
  input ififo_ready;
  
  output reg [1:0] inst_w; // [1]: Execute, [0]: Load Weight
  output reg sfp_acc_en;
  output reg sfp_relu_en;
  output reg ofifo_rd;
  
  output reg done;

  // Internal State
  reg [3:0] state;
  reg [4:0] count; 
  
  // State Encodings
  localparam S_IDLE         = 4'd0;
  
  // WS Modes
  localparam S_WS_LOAD_W    = 4'd1; 
  localparam S_WS_FEED_W    = 4'd2; 
  localparam S_WS_LOAD_X    = 4'd3; 
  localparam S_WS_EXECUTE   = 4'd4; 
  
  // OS Modes
  localparam S_OS_LOAD_X    = 4'd6;
  localparam S_OS_LOAD_W    = 4'd7;
  localparam S_OS_EXECUTE   = 4'd8;
  
  localparam S_DONE         = 4'd5;

  assign sram_wr = 1'b0; 

  always @(posedge clk or posedge reset) begin
    if (reset) begin
        state       <= S_IDLE;
        count       <= 0;
        sram_addr   <= 0;
        l0_wr       <= 0;
        l0_rd       <= 0;
        ififo_wr    <= 0;
        ififo_rd    <= 0;
        inst_w      <= 2'b00;
        sfp_acc_en  <= 0;
        sfp_relu_en <= 0;
        done        <= 0;
    end else begin
        
        // Pulse defaults
        l0_wr    <= 0; 
        ififo_wr <= 0;
        
        case (state)
            // ------------------------------------------------------------
            // IDLE
            // ------------------------------------------------------------
            S_IDLE: begin
                done <= 0;
                if (start) begin
                    count <= 0;
                    sram_addr <= 0;
                    // Branch based on Mode
                    if (mode == 1'b0) state <= S_WS_LOAD_W;
                    else              state <= S_OS_LOAD_X; 
                end
            end

            // ============================================================
            // WEIGHT STATIONARY PATH (Mode 0)
            // ============================================================
            
            // 1. Load Weights from SRAM -> L0
            S_WS_LOAD_W: begin
                if (!l0_full) begin
                    l0_wr <= 1;        
                    sram_addr <= sram_addr + 1;
                    count <= count + 1;
                    
                    if (count == row - 1) begin
                        state <= S_WS_FEED_W;
                        count <= 0;
                        l0_wr <= 0; 
                    end
                end
            end

            // 2. Feed Weights L0 -> Array (Latch into PE)
            S_WS_FEED_W: begin
                inst_w <= 2'b01; // Load Weight Inst
                l0_rd  <= 1;     
                
                count <= count + 1;
                
                if (count == row + 2) begin 
                    state <= S_WS_LOAD_X;
                    count <= 0;
                    l0_rd <= 0;
                    inst_w <= 2'b00;
                    // Reset SRAM address for Inputs
                    sram_addr <= row; 
                end
            end

            // 3. Load Inputs from SRAM -> L0
            S_WS_LOAD_X: begin
               if (!l0_full) begin
                    l0_wr <= 1;
                    sram_addr <= sram_addr + 1;
                    count <= count + 1;
                    
                    if (count == row - 1) begin
                        state <= S_WS_EXECUTE;
                        count <= 0;
                        l0_wr <= 0;
                    end
                end
            end

            // 4. Execute WS
            S_WS_EXECUTE: begin
                inst_w <= 2'b10; // Execute
                l0_rd  <= 1;
                
                sfp_relu_en <= 1; 
                sfp_acc_en  <= 1; 
                
                count <= count + 1;
                
                if (count == row + 4) begin
                    state <= S_DONE;
                    l0_rd <= 0;
                    inst_w <= 2'b00;
                    sfp_relu_en <= 0;
                    sfp_acc_en <= 0;
                end
            end

            // ============================================================
            // OUTPUT STATIONARY PATH (Mode 1)
            // ============================================================

            // 1. Load Inputs from SRAM -> L0 (Horizontal Activations)
            S_OS_LOAD_X: begin
                if (!l0_full) begin
                    l0_wr <= 1;
                    sram_addr <= sram_addr + 1;
                    count <= count + 1;

                    if (count == row - 1) begin
                        state <= S_OS_LOAD_W;
                        count <= 0;
                        l0_wr <= 0;
                        // Keep sram_addr incrementing (activations then weights)
                    end
                end
            end

            // 2. Load Weights from SRAM -> IFIFO (Vertical Weights)
            S_OS_LOAD_W: begin
                if (!ififo_full) begin
                    ififo_wr <= 1;
                    sram_addr <= sram_addr + 1;
                    count <= count + 1;

                    if (count == col - 1) begin
                        state <= S_OS_EXECUTE;
                        count <= 0;
                        ififo_wr <= 0;
                    end
                end
            end

            // 3. Execute OS (Stream L0 West->East, IFIFO North->South)
            S_OS_EXECUTE: begin
                inst_w <= 2'b10; // Execute (Calculates + Shifts Weights down)
                l0_rd  <= 1;
                ififo_rd <= 1;   // Enable Vertical Weight Feed

                // In OS mode provided, Psum stays in PE. 
                // We assume SFP logic might be idle or handling pass-through if needed.
                // Keeping signals safe:
                sfp_relu_en <= 0; 
                sfp_acc_en  <= 0;

                count <= count + 1;

                // Wait for pipeline to drain
                if (count == row + col + 2) begin
                    state <= S_DONE;
                    l0_rd <= 0;
                    ififo_rd <= 0;
                    inst_w <= 2'b00;
                end
            end

            // ============================================================
            // DONE
            // ============================================================
            S_DONE: begin
                done <= 1;
                state <= S_IDLE;
            end
            
            default: state <= S_IDLE;
        endcase
    end
  end

endmodule