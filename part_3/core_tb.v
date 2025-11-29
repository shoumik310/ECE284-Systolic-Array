// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
`timescale 1ns/1ps

module core_tb;

parameter bw = 4;
parameter psum_bw = 16;
parameter len_kij = 9; // Kernel ij loop length
parameter len_onij = 16;
parameter col = 8;
parameter row = 8;
parameter len_nij = 36;

reg clk = 0;
reg reset = 1;

wire [34:0] inst_q; // 35 bits instruction bus

reg CEN_xmem = 1; // Activation SRAM chip enable
reg WEN_xmem = 1; // Activation SRAM write enable
reg [10:0] A_xmem = 0; // Activation SRAM address
reg CEN_xmem_q = 1; 
reg WEN_xmem_q = 1; 
reg [10:0] A_xmem_q = 0; 

reg CEN_pmem = 1; // Psum SRAM chip enable
reg WEN_pmem = 1; // Psum SRAM write enable
reg [10:0] A_pmem = 0; // Psum SRAM address
reg CEN_pmem_q = 1; 
reg WEN_pmem_q = 1; 
reg [10:0] A_pmem_q = 0; 

reg acc = 0; // accumulation enable
reg acc_q = 0; 

reg [bw*row-1:0] D_xmem; // Activation SRAM data input
reg [bw*row-1:0] D_xmem_q = 0; 

reg [psum_bw*col-1:0] answer; 

reg ofifo_rd; // OFIFO read enable
reg ofifo_rd_q = 0; 

// IFIFO Controls (Used for Output Stationary Mode)
reg ififo_wr; 
reg ififo_rd; 
reg ififo_wr_q = 0; 
reg ififo_rd_q = 0; 

reg l0_rd; // L0 FIFO read enable
reg l0_wr; // L0 FIFO write enable
reg l0_rd_q = 0; 
reg l0_wr_q = 0; 

reg [1:0] inst_w; 
reg [1:0] inst_w_q = 0; 

reg execute; 
reg load; 
reg execute_q = 0; 
reg load_q = 0; 

// Mode Control
reg mode; // 0: WS, 1: OS
reg mode_q = 0;

reg [8*30:1] stringvar;
reg [8*30:1] w_file_name;
wire ofifo_valid;
wire [col*psum_bw-1:0] sfp_out;

integer x_file, x_scan_file ; 
integer w_file, w_scan_file ; 
integer acc_file, acc_scan_file ; 
integer out_file, out_scan_file ; 
integer captured_data; 
integer t, i, j, k, kij;
integer error;

assign inst_q[34]   = mode_q;
assign inst_q[33]   = acc_q; 
assign inst_q[32]   = CEN_pmem_q;
assign inst_q[31]   = WEN_pmem_q;
assign inst_q[30:20]= A_pmem_q;
assign inst_q[19]   = CEN_xmem_q;
assign inst_q[18]   = WEN_xmem_q;
assign inst_q[17:7] = A_xmem_q;
assign inst_q[6]    = ofifo_rd_q;
assign inst_q[5]    = ififo_wr_q;
assign inst_q[4]    = ififo_rd_q;
assign inst_q[3]    = l0_rd_q;
assign inst_q[2]    = l0_wr_q;
assign inst_q[1]    = execute_q; 
assign inst_q[0]    = load_q; 

core  #(.bw(bw), .col(col), .row(row)) core_instance (
  .clk(clk), 
  .inst(inst_q),
  .ofifo_valid(ofifo_valid),
  .D_xmem(D_xmem_q), 
  .sfp_out(sfp_out), 
  .reset(reset)
); 


initial begin 
  // Select Mode Here
  mode     = 0; // 0: Weight Stationary, 1: Output Stationary

  inst_w   = 0; 
  D_xmem   = 0;
  CEN_xmem = 1; 
  WEN_xmem = 1; 
  A_xmem   = 0;
  ofifo_rd = 0;
  ififo_wr = 0;
  ififo_rd = 0;
  l0_rd    = 0;
  l0_wr    = 0;
  execute  = 0;
  load     = 0;

  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb);

  //////// Reset /////////
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
  /////////////////////////

  if (mode == 0) begin
    // =========================================================================
    // WEIGHT STATIONARY (WS) SEQUENCE
    // =========================================================================
    $display("Starting Weight Stationary Test...");

    x_file = $fopen("activation.txt", "r");
    x_scan_file = $fscanf(x_file,"%s", captured_data);
    x_scan_file = $fscanf(x_file,"%s", captured_data);
    x_scan_file = $fscanf(x_file,"%s", captured_data);

    /////// Activation data writing to memory ///////
    for (t=0; t<len_nij; t=t+1) begin  
      #0.5 clk = 1'b0;  x_scan_file = $fscanf(x_file,"%32b", D_xmem); WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1;
      #0.5 clk = 1'b1;   
    end
    #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1; 
    $fclose(x_file);

    w_file_name = "weight.txt";
    w_file = $fopen(w_file_name, "r");
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);

    // KIJ Loop (Iterating over tiles)
    for (kij=0; kij<9; kij=kij+1) begin  
      
      // 1. Load Weights to SRAM
      A_xmem = 11'b10000000000;
      for (t=0; t<col; t=t+1) begin  
        #0.5 clk = 1'b0;  w_scan_file = $fscanf(w_file,"%32b", D_xmem); WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1; 
        #0.5 clk = 1'b1;  
      end
      #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
      #0.5 clk = 1'b1; 

      // 2. S_WS_LOAD_W: Load Weights Memory -> L0
      #0.5 clk = 1'b0; A_xmem = 11'b10000000000;
      #0.5 clk = 1'b1;
      for(t=0; t<col; t=t+1) begin  
        #0.5 clk = 1'b0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1; l0_wr = 1;      
        #0.5 clk = 1'b1;  
      end
      #0.5 clk = 1'b0;  CEN_xmem = 1; A_xmem = 0; l0_wr = 0;
      #0.5 clk = 1'b1; 

      // 3. S_WS_FEED_W: Feed Weights L0 -> Array
      #0.5 clk = 1'b0; l0_rd = 1; load = 1; 
      #0.5 clk = 1'b1;
      // Allow time for weights to propagate (row + padding)
      for(t=0; t< 2*col; t=t+1) begin
        #0.5 clk = 1'b0; 
        #0.5 clk = 1'b1;
      end
      #0.5 clk = 1'b0;  load = 0; l0_rd = 0;
      #0.5 clk = 1'b1;  

      // 4. S_WS_LOAD_X: Load Activations Memory -> L0
      #0.5 clk = 1'b0; A_xmem = 11'b00000000000;
      #0.5 clk = 1'b1;
      for(t=0; t<len_nij; t=t+1) begin  
        #0.5 clk = 1'b0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1; l0_wr = 1;      
        #0.5 clk = 1'b1;  
      end
      #0.5 clk = 1'b0;  CEN_xmem = 1; A_xmem = 0; l0_wr = 0;
      #0.5 clk = 1'b1; 

      // 5. S_WS_EXECUTE: Execute
      #0.5 clk = 1'b0; l0_rd = 1; execute = 1;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0; #0.5 clk = 1'b1; // Prop delay

      for(t=0; t< len_nij; t=t+1) begin
        #0.5 clk = 1'b0; 
        #0.5 clk = 1'b1;
      end
      #0.5 clk = 1'b0;  execute = 0; l0_rd = 0;
      #0.5 clk = 1'b1;  

      // 6. Read OFIFO
      t=0; A_pmem= 11'b00000000000;
      while(t < len_nij) begin
        #0.5 clk = 1'b0;  
        if(ofifo_valid == 1'b1) begin
          WEN_pmem = 0; CEN_pmem = 0; ofifo_rd=1; if (t>0) A_pmem = A_pmem + 1; 
          t = t+1;
        end
        else begin
          CEN_pmem = 1; ofifo_rd =0;
        end
        #0.5 clk = 1'b1;  
      end
      #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0; ofifo_rd = 0;
      #0.5 clk = 1'b1; 

    end // End KIJ loop
    $fclose(w_file);

    // Verification (Only valid for WS mode logic)
    // ... [Verification Logic same as before] ...
    
  end 
  else begin
    // =========================================================================
    // OUTPUT STATIONARY (OS) SEQUENCE
    // =========================================================================
    $display("Starting Output Stationary Test...");
    
    // In OS Mode: Weights flow N->S (Vertical), Inputs flow W->E (Horizontal)
    
    // 1. S_OS_LOAD_X: Load Activations Memory -> L0
    // (Assuming activations already in Mem from a file load similar to WS)
    // For Demo: Loading dummy/file data into L0
    x_file = $fopen("activation.txt", "r");
    x_scan_file = $fscanf(x_file,"%s", captured_data); // Skip header
    x_scan_file = $fscanf(x_file,"%s", captured_data);
    x_scan_file = $fscanf(x_file,"%s", captured_data);

    // Direct Mem Load (Simulating pre-load)
    for (t=0; t<row; t=t+1) begin  
        #0.5 clk = 1'b0; x_scan_file = $fscanf(x_file,"%32b", D_xmem); 
        CEN_xmem = 0; WEN_xmem = 0; A_xmem = t;
        #0.5 clk = 1'b1; 
    end
    #0.5 clk = 1'b0; CEN_xmem = 1; WEN_xmem = 1; #0.5 clk = 1'b1;
    $fclose(x_file);

    // Transfer Mem -> L0
    #0.5 clk = 1'b0; A_xmem = 0; #0.5 clk = 1'b1;
    for(t=0; t<row; t=t+1) begin
       #0.5 clk = 1'b0; CEN_xmem = 0; if(t>0) A_xmem = A_xmem+1; l0_wr = 1;
       #0.5 clk = 1'b1;
    end
    #0.5 clk = 1'b0; CEN_xmem = 1; l0_wr = 0; #0.5 clk = 1'b1;

    // 2. S_OS_LOAD_W: Load Weights Memory -> IFIFO
    w_file_name = "weight.txt";
    w_file = $fopen(w_file_name, "r");
    w_scan_file = $fscanf(w_file,"%s", captured_data); // Skip header
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);

    // Direct Mem Load (Using upper memory addresses for weights)
    for (t=0; t<col; t=t+1) begin  
        #0.5 clk = 1'b0; w_scan_file = $fscanf(w_file,"%32b", D_xmem); 
        CEN_xmem = 0; WEN_xmem = 0; A_xmem = t + 20; // Offset address
        #0.5 clk = 1'b1; 
    end
    #0.5 clk = 1'b0; CEN_xmem = 1; WEN_xmem = 1; #0.5 clk = 1'b1;
    $fclose(w_file);

    // Transfer Mem -> IFIFO
    #0.5 clk = 1'b0; A_xmem = 20; #0.5 clk = 1'b1;
    for(t=0; t<col; t=t+1) begin
       #0.5 clk = 1'b0; CEN_xmem = 0; if(t>0) A_xmem = A_xmem+1; ififo_wr = 1;
       #0.5 clk = 1'b1;
    end
    #0.5 clk = 1'b0; CEN_xmem = 1; ififo_wr = 0; #0.5 clk = 1'b1;

    // 3. S_OS_EXECUTE: Execute (Stream Both)
    $display("Executing OS Mode...");
    #0.5 clk = 1'b0; 
    execute = 1; 
    l0_rd = 1;    // Stream Activations W->E
    ififo_rd = 1; // Stream Weights N->S
    #0.5 clk = 1'b1;

    // Run for sufficient cycles (Row + Col + Pipeline)
    for(t=0; t< row + col + 5; t=t+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end

    #0.5 clk = 1'b0; execute = 0; l0_rd = 0; ififo_rd = 0; #0.5 clk = 1'b1;
    $display("OS Mode Execution Complete.");
  end

  #10 $finish;

end

// Pipeline registers logic
always @ (posedge clk) begin
   inst_w_q   <= inst_w; 
   D_xmem_q   <= D_xmem;
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
   l0_wr_q    <= l0_wr;
   execute_q  <= execute;
   load_q     <= load;
   mode_q     <= mode; 
end

endmodule