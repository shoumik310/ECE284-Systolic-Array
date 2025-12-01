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

wire [34:0] inst_q; // Updated: 35 bits instruction bus

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

// NEW: Psum SRAM Data Input for Weight Loading
reg [col*psum_bw-1:0] D_pmem; 
reg [col*psum_bw-1:0] D_pmem_q = 0; 

reg [psum_bw*col-1:0] answer; 

reg ofifo_rd; // OFIFO read enable
reg ofifo_rd_q = 0; 

// IFIFO Controls
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

// NEW: Mode Control (0: WS, 1: OS)
// CHANGE THIS TO TEST DIFFERENT MODES
reg mode = 1; 
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

// Updated Instruction Bus Assignment
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
  .D_pmem(D_pmem_q), // Connected new port
  .sfp_out(sfp_out), 
  .reset(reset)
); 


initial begin 
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
      if (x_file == 0) begin
        $display("ERROR: activation.txt not found!");
        $finish;
      end
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

      // KIJ Loop
      for (kij=0; kij<9; kij=kij+1) begin 
        
        w_file_name = "weight.txt"; 
        w_file = $fopen(w_file_name, "r");
        if (w_file == 0) begin
            $display("ERROR: weight.txt not found!");
            $finish;
        end
        w_scan_file = $fscanf(w_file,"%s", captured_data);
        w_scan_file = $fscanf(w_file,"%s", captured_data);
        w_scan_file = $fscanf(w_file,"%s", captured_data);

        // Reset Sequence inside loop
        #0.5 clk = 1'b0;   reset = 1;
        #0.5 clk = 1'b1; 
        for (i=0; i<10 ; i=i+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end
        #0.5 clk = 1'b0;   reset = 0;
        #0.5 clk = 1'b1; 
        #0.5 clk = 1'b0;   
        #0.5 clk = 1'b1;   

        /////// Kernel data writing to memory ///////
        A_xmem = 11'b10000000000;
        for (t=0; t<col; t=t+1) begin  
          #0.5 clk = 1'b0;  w_scan_file = $fscanf(w_file,"%32b", D_xmem); WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1; 
          #0.5 clk = 1'b1;  
        end
        #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
        #0.5 clk = 1'b1; 

        /////// Kernel data writing to L0 ///////
        #0.5 clk = 1'b0; A_xmem = 11'b10000000000;
        #0.5 clk = 1'b1;
        for(t=0; t<col; t=t+1) begin  
          #0.5 clk = 1'b0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1; l0_wr = 1;      
          #0.5 clk = 1'b1;  
        end
        #0.5 clk = 1'b0;  CEN_xmem = 1; A_xmem = 0; l0_wr = 0;
        #0.5 clk = 1'b1; 

        /////// Kernel loading to PEs ///////
        #0.5 clk = 1'b0; l0_rd = 1; load = 1;
        #0.5 clk = 1'b1;
        for(t=0; t< 2*col; t=t+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end
        #0.5 clk = 1'b0;  load = 0; l0_rd = 0;
        #0.5 clk = 1'b1;  
        for (i=0; i<10 ; i=i+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end

        /////// Activation data writing to L0 ///////
        #0.5 clk = 1'b0; A_xmem = 11'b00000000000;
        #0.5 clk = 1'b1;
        for(t=0; t<len_nij; t=t+1) begin  
          #0.5 clk = 1'b0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1; l0_wr = 1;      
          #0.5 clk = 1'b1;  
        end
        #0.5 clk = 1'b0;  CEN_xmem = 1; A_xmem = 0; l0_wr = 0;
        #0.5 clk = 1'b1; 

        /////// Execution ///////
        #0.5 clk = 1'b0; l0_rd = 1; execute = 1;
        #0.5 clk = 1'b1;
        for(t=0; t< len_nij; t=t+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end
        #0.5 clk = 1'b0;  execute = 0; l0_rd = 0; #0.5 clk = 1'b1;  
        for (i=0; i<10 ; i=i+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end

        //////// OFIFO READ ////////
        t=0;
        A_pmem= 11'b00000000000;
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
      end // End KIJ
  end 
  else begin
      // =========================================================================
      // OUTPUT STATIONARY (OS) SEQUENCE
      // =========================================================================
      $display("Starting Output Stationary Test...");

      // 1. Load Activations to XMEM (Same as before)
      x_file = $fopen("activation.txt", "r");
      if (x_file == 0) begin
        $display("ERROR: activation.txt not found!");
        $finish;
      end
      x_scan_file = $fscanf(x_file,"%s", captured_data);
      x_scan_file = $fscanf(x_file,"%s", captured_data);
      x_scan_file = $fscanf(x_file,"%s", captured_data);

      for (t=0; t<row; t=t+1) begin  
          #0.5 clk = 1'b0; x_scan_file = $fscanf(x_file,"%32b", D_xmem); 
          CEN_xmem = 0; WEN_xmem = 0; A_xmem = t;
          #0.5 clk = 1'b1; 
      end
      #0.5 clk = 1'b0; CEN_xmem = 1; WEN_xmem = 1; #0.5 clk = 1'b1;
      $fclose(x_file);

      // Transfer XMEM -> L0
      #0.5 clk = 1'b0; A_xmem = 0; #0.5 clk = 1'b1;
      for(t=0; t<row; t=t+1) begin
         #0.5 clk = 1'b0; CEN_xmem = 0; if(t>0) A_xmem = A_xmem+1; l0_wr = 1;
         #0.5 clk = 1'b1;
      end
      #0.5 clk = 1'b0; CEN_xmem = 1; l0_wr = 0; #0.5 clk = 1'b1;

      // 2. Load Weights to PMEM (NEW REQUIREMENT)
      w_file_name = "weight.txt";
      w_file = $fopen(w_file_name, "r");
      if (w_file == 0) begin
        $display("ERROR: weight.txt not found!");
        $finish;
      end
      w_scan_file = $fscanf(w_file,"%s", captured_data);
      w_scan_file = $fscanf(w_file,"%s", captured_data);
      w_scan_file = $fscanf(w_file,"%s", captured_data);

      // Write to PMEM (128-bit wide). Weights are 32-bit.
      // We zero-pad the MSBs: {96'b0, weight_data}
      for (t=0; t<col; t=t+1) begin  
          #0.5 clk = 1'b0; 
          w_scan_file = $fscanf(w_file,"%32b", D_xmem); // Reuse D_xmem var to read file 32b
          D_pmem = {96'b0, D_xmem}; // Pad to 128 bits
          CEN_pmem = 0; WEN_pmem = 0; A_pmem = t; 
          #0.5 clk = 1'b1; 
      end
      #0.5 clk = 1'b0; CEN_pmem = 1; WEN_pmem = 1; #0.5 clk = 1'b1;
      $fclose(w_file);

      // Transfer PMEM -> IFIFO
      // We read from PMEM. The IFIFO is connected to the LSB 32 bits of i_pmem_data in corelet.
      #0.5 clk = 1'b0; A_pmem = 0; #0.5 clk = 1'b1;
      for(t=0; t<col; t=t+1) begin
         #0.5 clk = 1'b0; 
         CEN_pmem = 0; WEN_pmem = 1; // Read Mode
         if(t>0) A_pmem = A_pmem+1; 
         ififo_wr = 1;
         #0.5 clk = 1'b1;
      end
      #0.5 clk = 1'b0; CEN_pmem = 1; ififo_wr = 0; #0.5 clk = 1'b1;

      // 3. Execute OS Mode
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

  // Common Completion
  #10 $finish;

end

always @ (posedge clk) begin
   inst_w_q   <= inst_w; 
   D_xmem_q   <= D_xmem;
   D_pmem_q   <= D_pmem; // Pipeline D_pmem
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
   mode_q     <= mode; 
end

// MONITOR IFIFO LOADING
always @ (posedge clk) begin
    if (ififo_wr_q) begin
        $display("[Time %0t] IFIFO LOAD: Data=%h (from PMEM[31:0])", $time, D_pmem_q[31:0]);
    end
end

endmodule