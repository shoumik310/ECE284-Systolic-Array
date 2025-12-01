// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_array (clk, reset, out_s, in_w, in_n, inst_w, valid, psum_flush, psum_bus);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;
  parameter bus_bw = 32;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  input  [row*bw-1:0] in_w;       // West inputs for all rows
  input  [2:0] inst_w;            // Global Instruction input
  input  [psum_bw*col-1:0] in_n;  // North inputs for top row
  input  psum_flush;              // Global Flush trigger
  output [col-1:0] valid;         // Valid signal from bottom row
  output [bus_bw-1:0] psum_bus;   // Global Shared Bus

  // Internal Wires
  wire   [psum_bw*col*(row+1)-1:0] temp;    // Vertical (North-South) connections
  wire   [row*col-1:0] valid_temp;          // Valid signals from all tiles
  wire   [bus_bw-1:0] row_psum_bus [row-1:0]; // Bus output from each row

  // ===========================================================================
  // 1. INSTRUCTION PIPELINE (Vertical)
  // ===========================================================================
  // Row 0 gets instruction DIRECTLY to match direct Data input.
  // Row 1..7 get delayed versions.
  wire [3*row-1:0] inst_w_distributed;
  reg  [3*(row-1)-1:0] inst_delay_regs; // Registers for rows 1 to 7

  // Map Row 0 direct, others from regs
  assign inst_w_distributed[2:0] = inst_w; 
  assign inst_w_distributed[3*row-1:3] = inst_delay_regs; 

  always @(posedge clk) begin
      if (row > 1) begin
          // Row 1 input <= Row 0 input (inst_w)
          inst_delay_regs[2:0] <= inst_w;
          
          // Row N input <= Row N-1 input
          if (row > 2) begin
             inst_delay_regs[3*(row-1)-1:3] <= inst_delay_regs[3*(row-2)-1:0];
          end
      end
  end

  // ===========================================================================
  // 2. FLUSH CONTROL LOGIC
  // ===========================================================================
  // We need to trigger rows sequentially with a spacing of 'col' cycles.
  // Row 0 starts at T=0. Row 1 starts at T=8. Row 2 at T=16...
  wire [row-1:0] row_flush_sig;
  reg [row*col-1:0] flush_shift_reg; 

  always @(posedge clk or posedge reset) begin
      if (reset) begin
          flush_shift_reg <= 0;
      end else begin
          // Shift the psum_flush signal through the deep register
          flush_shift_reg <= {flush_shift_reg[row*col-2:0], psum_flush};
      end
  end

  // Assign taps:
  // Row 0: Immediate
  // Row 1: Delayed by 'col' cycles (tap index col-1)
  // Row i: Delayed by 'i*col' cycles
  assign row_flush_sig[0] = psum_flush;
  genvar f;
  generate
      for (f=1; f < row; f=f+1) begin : row_flush_assign
          assign row_flush_sig[f] = flush_shift_reg[(f*col) - 1];
      end
  endgenerate

  // ===========================================================================
  // 3. ROW INSTANTIATION
  // ===========================================================================
  genvar i;
 
  // North-South Data Connections
  // Connect Top Input (in_n) to temp[Row 0]
  assign temp[psum_bw*col*1-1:psum_bw*col*0] = in_n;
  // Connect Bottom Output (out_s) to temp[Row 8]
  assign out_s = temp[psum_bw*col*(row+1)-1:psum_bw*col*row];
  
  // Valid Signal (Take from the last row)
  assign valid = valid_temp[row*col-1:row*col-col];

  generate
    for (i=1; i < row+1 ; i=i+1) begin : row_num
        mac_row #(
            .bw(bw), 
            .psum_bw(psum_bw),
            .col(col),
            .bus_bw(bus_bw)
        ) mac_row_instance (
            .clk(clk),
            .reset(reset),
            // Input W: Sliced from the large input array for this specific row
            .in_w(in_w[bw*i-1:bw*(i-1)]),
            // Inst W: Correctly delayed instruction for this row
            .inst_w(inst_w_distributed[3*i-1:3*(i-1)]),
            // Input N: From previous row (or in_n for first row)
            .in_n(temp[psum_bw*col*i-1:psum_bw*col*(i-1)]),
            // Output S: To next row (or out_s for last row)
            .out_s(temp[psum_bw*col*(i+1)-1:psum_bw*col*(i)]),
            // Valid Output
            .valid(valid_temp[col*i-1:col*(i-1)]),
            // Flush Signal
            .psum_flush(row_flush_sig[i-1]),
            // Bus Output
            .psum_bus(row_psum_bus[i-1])
        );
    end
  endgenerate

  // ===========================================================================
  // 4. BUS AGGREGATION
  // ===========================================================================
  // OR-reduce all row buses into the single output bus
  reg [bus_bw-1:0] bus_comb;
  integer j;
  always @(*) begin
    bus_comb = 0;
    for (j=0; j < row; j=j+1) begin
        bus_comb = bus_comb | row_psum_bus[j];
    end
  end
  assign psum_bus = bus_comb;

endmodule