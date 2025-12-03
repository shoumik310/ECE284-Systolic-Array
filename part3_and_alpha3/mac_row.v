// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_row (clk, out_s, in_w, in_n, valid, inst_w, reset, psum_flush, psum_bus);
  
  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter bus_bw = 32;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  output [bus_bw-1:0] psum_bus;   // Shared Bus Output
  output [col-1:0] valid;
  
  input  [bw-1:0] in_w; 
  input  [2:0] inst_w;            // 3-bit Instruction {Mode, Exec, Load}
  input  [psum_bw*col-1:0] in_n;
  input  psum_flush;              // Global Flush Input

  // --- Data & Instruction Propagation Wires ---
  wire  [(col+1)*bw-1:0] temp;
  assign temp[bw-1:0]   = in_w;

  wire [3*(col+1)-1:0] inst_bus;  // 3-bit wide instruction bus
  assign inst_bus[2:0] = inst_w; 

  // --- Shared Bus Wires ---
  // Array to collect psum_bus output from each tile before OR-ing
  wire [bus_bw-1:0] tile_psum_bus [col-1:0];

  // --- Flush Delay Chain ---
  // We need to delay the flush signal by 1 cycle per tile so they 
  // dump data to the bus sequentially (Tile 0 -> Tile 1 -> ...).
  reg [col-1:0] flush_chain;
  wire [col-1:0] tile_flush;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      flush_chain <= 0;
    end else begin
      // Shift register to propagate flush signal
      // flush_chain[0] = delayed 1 cycle (for Tile 1)
      // flush_chain[1] = delayed 2 cycles (for Tile 2) ...
      flush_chain <= {flush_chain[col-2:0], psum_flush};
    end
  end

  // Assign flush signals to tiles
  assign tile_flush[0] = psum_flush; // Tile 0 gets flush immediately
  genvar f;
  generate
    for (f=1; f < col; f=f+1) begin : flush_assign
        assign tile_flush[f] = flush_chain[f-1];
    end
  endgenerate


  // --- Tile Instantiation ---
  genvar i;
  generate
    for (i=0; i < col ; i=i+1) begin : col_num
        mac_tile #(
          .bw(bw), 
          .psum_bw(psum_bw),
          .bus_bw(bus_bw)
        ) mac_tile_instance (
          .clk(clk),
          .reset(reset),
          // West-to-East Data Flow
          .in_w(temp[bw*(i+1)-1 : bw*i]),
          .out_e(temp[bw*(i+2)-1 : bw*(i+1)]),
          // West-to-East Instruction Flow
          .inst_w(inst_bus[3*(i+1)-1 : 3*i]), 
          .inst_e(inst_bus[3*(i+2)-1 : 3*(i+1)]), 
          // North Input (Weights for OS Mode)
          .in_n(in_n[psum_bw*(i+1)-1 : psum_bw*i]),
          // South Output
          .out_s(out_s[psum_bw*(i+1)-1 : psum_bw*i]),
          // Flush & Bus
          .psum_flush(tile_flush[i]),
          .psum_bus(tile_psum_bus[i])
        );
        
        // Valid signal: Monitor the Execute bit (bit 1) of the instruction exiting the tile
        assign valid[i] = inst_bus[3*(i+1)+1];
    end
  endgenerate

  // --- Bus OR-Reduction ---
  // Combine all tile outputs onto the shared bus.
  // Inactive tiles output 0, so OR-ing them works correctly.
  reg [bus_bw-1:0] bus_comb;
  integer j;
  always @(*) begin
    bus_comb = 0;
    for (j=0; j < col; j=j+1) begin
        bus_comb = bus_comb | tile_psum_bus[j];
    end
  end
  
  assign psum_bus = bus_comb;

endmodule