// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
`timescale 1ns/1ps

module core_tb;

parameter bw = 4;
parameter psum_bw = 16;
parameter len_kij = 9; // Kernel ij loop length
parameter len_onij = 36;
parameter col = 8;
parameter row = 8;
parameter len_nij = 64;

reg clk = 0;
reg reset = 1;

wire [34:0] inst_q; // Updated to 35 bits

reg mode = 0;
reg mode_q = 0; 

reg CEN_xmem = 1; // Activation SRAM chip enable
reg WEN_xmem = 1; // Activation SRAM write enable
reg [10:0] A_xmem = 0; // Activation SRAM address
reg CEN_xmem_q = 1; // Activation SRAM chip enable pipeline reg
reg WEN_xmem_q = 1; // Activation SRAM write enable pipeline reg
reg [10:0] A_xmem_q = 0; // Activation SRAM address pipeline reg

reg CEN_pmem = 1; // Psum SRAM chip enable
reg WEN_pmem = 1; // Psum SRAM write enable
reg [10:0] A_pmem = 0; // Psum SRAM address
reg CEN_pmem_q = 1; // Psum SRAM chip enable pipeline reg
reg WEN_pmem_q = 1; // Psum SRAM write enable pipeline reg
reg [10:0] A_pmem_q = 0; // Psum SRAM address pipeline reg

reg acc = 0; // accumulation enable (Used as Flush trigger in OS mode)
reg acc_q = 0; // accumulation enable pipeline reg

reg [bw*row-1:0] D_xmem; // Activation SRAM data input
reg [bw*row-1:0] D_xmem_q = 0; // Activation SRAM data input pipeline reg

reg [col*psum_bw-1:0] D_pmem; // Psum SRAM data input
reg [col*psum_bw-1:0] D_pmem_q = 0; // Psum SRAM data input pipeline reg

reg [psum_bw*col-1:0] answer; // expected output data for verification

reg ofifo_rd; // OFIFO read enable
reg ofifo_rd_q = 0; // OFIFO read enable pipeline reg

reg ififo_wr; // IFIFO write enable
reg ififo_rd; // IFIFO read enable
reg ififo_wr_q = 0; // IFIFO write enable pipeline reg
reg ififo_rd_q = 0; // IFIFO read enable pipeline reg

reg l0_rd; // L0 FIFO read enable
reg l0_wr; // L0 FIFO write enable
reg l0_rd_q = 0; // L0 FIFO read enable pipeline reg
reg l0_wr_q = 0; // L0 FIFO write enable pipeline reg

reg [1:0] inst_w; // Mac instruction
reg [1:0] inst_w_q = 0; // Mac instruction pipeline reg

reg execute; // execute instruction 
reg load; // load instruction
reg execute_q = 0; // execute instruction pipeline reg
reg load_q = 0; // load instruction pipeline reg
reg [31:0] temp_data;
reg [31:0] temp_act;

reg [8*256:1] stringvar;
reg [8*30:1] w_file_name;
wire ofifo_valid;
wire [col*psum_bw-1:0] sfp_out;

integer x_file, x_scan_file ; // file_handler
integer w_file, w_scan_file ; // file_handler
integer acc_file, acc_scan_file ; // file_handler
integer out_file, out_scan_file ; // file_handler
integer captured_data; 
integer t, i, j, k, kij;
integer error;

// Variables for Step 2 Logic
reg [3:0] act_array [0:63][0:7]; // Buffer to hold activation data
integer base, c, ic;
integer target_pixel, delta, source_nij,iter,step;


reg [31:0] weight_cache [0:8][0:7]; // [KIJ][Input Channel]
reg [31:0] raw_data;
reg [31:0] packed_data;
integer oc;

// Updated Assignment for new instruction width
assign inst_q[34] = mode_q; 
assign inst_q[33] = acc_q; 
assign inst_q[32] = CEN_pmem_q;
assign inst_q[31] = WEN_pmem_q;
assign inst_q[30:20] = A_pmem_q;
assign inst_q[19]   = CEN_xmem_q;
assign inst_q[18]   = WEN_xmem_q;
assign inst_q[17:7] = A_xmem_q;
assign inst_q[6]   = ofifo_rd_q;
assign inst_q[5]   = ififo_wr_q;
assign inst_q[4]   = ififo_rd_q;
assign inst_q[3]   = l0_rd_q;
assign inst_q[2]   = l0_wr_q;
assign inst_q[1]   = execute_q; 
assign inst_q[0]   = load_q; 

// Core Instantiation
core  #(.bw(bw), .col(col), .row(row)) core_instance (
	.clk(clk), 
	.inst(inst_q),
	.ofifo_valid(ofifo_valid),
    .D_xmem(D_xmem_q), 
    .D_pmem(D_pmem_q), 
    .sfp_out(sfp_out), 
	.reset(reset)
); 


initial begin 
  // --- Initialization ---
  mode     = 1; // Set to Output Stationary Mode
  inst_w   = 0; 
  D_xmem   = 0;
  D_pmem   = 0;
  CEN_xmem = 1; 
  WEN_xmem = 1; 
  A_xmem   = 0;
  CEN_pmem = 1; 
  WEN_pmem = 1; 
  A_pmem   = 0;
  ofifo_rd = 0;
  ififo_wr = 0;
  ififo_rd = 0;
  l0_rd    = 0;
  l0_wr    = 0;
  execute  = 0;
  load     = 0;

  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb);

  // --- Reset Sequence ---
  #0.5 clk = 1'b0;   reset = 1;
  #0.5 clk = 1'b1; 

  for (i=0; i<10 ; i=i+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;   reset = 0;
  #0.5 clk = 1'b1; 

  #0.5 clk = 1'b0;   
  #0.5 clk = 1'b1;   


  // ====================================================================
  // STEP 1: LOAD PMEM (Data for North Inputs)
  // ====================================================================
   $display("Step 1: Loading PMEM with Weights (IC-major order, Rotated)...");
  
  // 1. Load all weight files into local cache
  // This avoids re-opening files repeatedly inside the loop
  for (kij = 0; kij < 9; kij = kij + 1) begin
      $sformat(w_file_name, "weight_%0d.txt", kij);
      w_file = $fopen(w_file_name, "r");
      if (w_file == 0) begin
          $display("Error: Failed to open %s", w_file_name);
          $finish;
      end
      // Skip comments
      w_scan_file = $fgets(stringvar, w_file);
      w_scan_file = $fgets(stringvar, w_file);
      w_scan_file = $fgets(stringvar, w_file);
      
      // Read 8 lines (Input Channels) into cache
      for (ic = 0; ic < 8; ic = ic + 1) begin
          w_scan_file = $fscanf(w_file, "%32b", weight_cache[kij][ic]);
      end
      $fclose(w_file);
  end

  A_pmem = 0;
  #0.5 clk = 1'b0;
  #0.5 clk = 1'b1;

  // 2. Iterate and Write to PMEM
  // Outer Loop: Input Channels (Rows in the file)
  for (ic = 0; ic < 8; ic = ic + 1) begin
      
      // Inner Loop: KIJ 0-8
      for (kij = 0; kij < 9; kij = kij + 1) begin
          
          raw_data = weight_cache[kij][ic];
          

          #0.5 clk = 1'b0;
          D_pmem = {96'b0, raw_data}; // Pad with zeros
          WEN_pmem = 0; 
          CEN_pmem = 0;
          #0.5 clk = 1'b1;
          
          A_pmem = A_pmem + 1;
      end
  end

  #0.5 clk = 1'b0; WEN_pmem = 1; CEN_pmem = 1; A_pmem = 0;
  #0.5 clk = 1'b1;


  // ====================================================================
  // STEP 2: LOAD XMEM (Data for West Inputs) - UPDATED LOGIC
  // ====================================================================
  $display("Step 2: Loading XMEM with West Input Data (Unrolled Window)...");
  
  // 1. READ ACTIVATION FILE into 2D Array
  x_file = $fopen("activation.txt", "r");
  x_scan_file = $fgets(stringvar, x_file); // Skip comments
  x_scan_file = $fgets(stringvar, x_file);
  x_scan_file = $fgets(stringvar, x_file);

  for (t=0; t<len_nij; t=t+1) begin  
    #0.5 clk = 1'b0;  
    x_scan_file = $fscanf(x_file,"%32b", temp_data);
    
    for (k=0; k<8; k=k+1) begin
        // Split 32-bit data into 8 x 4-bit channels
        act_array[t][k] = temp_data[4*k +: 4];
    end
    #0.5 clk = 1'b1;   
  end
  $fclose(x_file);

  // 2. SPATIAL MAPPING / WRITE TO XMEM
  A_xmem = 0;
  #0.5 clk = 1'b0;
  #0.5 clk = 1'b1;

  // Iterate through Tile Passes (0, 8, 16...)    
 for (ic = 0; ic < 8; ic = ic + 1) begin
      
      // Middle Loop: Iter (Replacing kij with explicit iter 0-8 logic)
      for (iter = 0; iter < 9; iter = iter + 1) begin
          
          // Calculate Delta based on user specification (h=8)
          case (iter)
            0: delta = 0;         // 0
            1: delta = 1;         // 1
            2: delta = 2;         // 2
            3: delta = 8;         // 0 + h
            4: delta = 9;         // 1 + h
            5: delta = 10;        // 2 + h
            6: delta = 16;        // 0 + 2h
            7: delta = 17;        // 1 + 2h
            8: delta = 18;        // 2 + 2h
          endcase

          // Inner Loop: Step (nij 0-7)
          for (step = 0; step < 8; step = step + 1) begin
              
              source_nij = step + delta;
              
              // Set Data and Write Control
              #0.5 clk = 1'b0; 
              
              // Only write to the specific 4-bit slice corresponding to the current channel 'ic'
              
              temp_act[step*4 +: 4] = act_array[source_nij][ic]; 
                   
              end
            D_xmem = temp_act;
            WEN_xmem = 0; 
            CEN_xmem = 0; 
            source_nij = delta;
            #0.5 clk = 1'b1;     
                  // Increment Address
            A_xmem = A_xmem + 1;
          end
      end
  

  // Reset Control Signals
  #0.5 clk = 1'b0; WEN_xmem = 1; CEN_xmem = 1; A_xmem = 0;
  #0.5 clk = 1'b1; 



  // ====================================================================
  // STEP 3: TRANSFER PMEM -> IFIFO
  // ====================================================================
  $display("Step 3: Transferring Data from PMEM to IFIFO...");
  #0.5 clk = 1'b0; A_pmem = 0; 
  #0.5 clk = 1'b1;

  for(t=0; t<col; t=t+1) begin  
      #0.5 clk = 1'b0; CEN_pmem = 0; 
      if (t>0) A_pmem = A_pmem + 1; 
      ififo_wr = 1;      
      #0.5 clk = 1'b1;  
  end
  #0.5 clk = 1'b0; ififo_wr = 0; CEN_pmem = 1; A_pmem = 0;
  #0.5 clk = 1'b1;


  // ====================================================================
  // STEP 4: TRANSFER XMEM -> L0
  // ====================================================================
  $display("Step 4: Transferring Data from XMEM to L0...");
  #0.5 clk = 1'b0; A_xmem = 0;
  #0.5 clk = 1'b1;

  // Note: We need to transfer enough data to cover the unrolled execution
  // Approximate length based on loop structure: 6 * 6 * 9 = 324 writes
  for(t=0; t<324; t=t+1) begin  
      #0.5 clk = 1'b0; CEN_xmem = 0; 
      if (t>0) begin
        A_xmem = A_xmem + 1;
        l0_wr = 1;      
      end      
      #0.5 clk = 1'b1;  
  end
  #0.5 clk = 1'b0; l0_wr = 0; CEN_xmem = 1; A_xmem = 0;
  #0.5 clk = 1'b1; 


  // ====================================================================
  // STEP 5: EXECUTION (Output Stationary)
  // ====================================================================
  $display("Step 5: Executing in Output Stationary Mode...");
  #0.5 clk = 1'b0; 
  l0_rd = 1; 
  ififo_rd = 1;
  load =1; 
  execute = 1;
  #0.5 clk = 1'b1;

  for(t=0; t< 324; t=t+1) begin // Run for full unrolled length
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
  end

  // Stop Execution
  #0.5 clk = 1'b0; execute = 0; l0_rd = 0; ififo_rd = 0;
  #0.5 clk = 1'b1;

  // Wait for pipeline to settle
  for (t=0; t<5; t=t+1) begin
     #0.5 clk = 1'b0; 
     #0.5 clk = 1'b1;
  end


  // ====================================================================
  // STEP 6: FLUSH RESULTS TO PMEM
  // ====================================================================
  $display("Step 6: Flushing OS Results to PMEM...");
  // Trigger flush (mode=1 && acc=1) and enable PMEM Write
  A_pmem = 0; 
  #0.5 clk = 1'b0; acc = 1; 
  #0.5 clk = 1'b1;

  // Flush takes time proportional to array size (row + col delay)
  // We capture data into PMEM as it arrives on the bus
  for(t=0; t<row+col+10; t=t+1) begin
      #0.5 clk = 1'b0; 
      WEN_pmem = 0; CEN_pmem = 0; // Enable PMEM Write
      if (t>0) A_pmem = A_pmem + 1;
      #0.5 clk = 1'b1;
  end

  #0.5 clk = 1'b0; acc = 0; WEN_pmem = 1; CEN_pmem = 1;
  #0.5 clk = 1'b1;

  $display("########### Output Stationary Run Completed !! ############"); 

  for (t=0; t<10; t=t+1) begin  
    #0.5 clk = 1'b0;  
    #0.5 clk = 1'b1;  
  end

  #10 $finish;

end

always @ (posedge clk) begin
   mode_q     <= mode;
   inst_w_q   <= inst_w; 
   D_xmem_q   <= D_xmem;
   D_pmem_q   <= D_pmem;
   CEN_xmem_q <= CEN_xmem;
   WEN_xmem_q <= WEN_xmem;
   A_pmem_q   <= A_pmem;
   CEN_pmem_q <= CEN_pmem;
   WEN_pmem_q <= WEN_pmem;
   A_xmem_q   <= A_xmem;
   ofifo_rd_q <= ofifo_rd;
   acc_q      <= acc;
   ififo_wr_q <= ififo_wr;
   ififo_rd_q <= ififo_rd;
   l0_rd_q    <= l0_rd;
   l0_wr_q    <= l0_wr ;
   execute_q  <= execute;
   load_q     <= load;
end


endmodule