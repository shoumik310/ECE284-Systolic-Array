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

parameter n = 8; //feature map size
parameter k = 3; //kernel size
parameter s = 1; //stride

reg clk = 0;
reg reset = 1;

wire [33:0] inst_q; // 34 bits instruction bus

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

reg acc = 0; // accumulation enable
reg acc_q = 0; // accumulation enable pipeline reg

reg [bw*row-1:0] D_xmem; // Activation SRAM data input
reg [bw*row-1:0] D_xmem_q = 0; // Activation SRAM data input pipeline reg

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

reg [8*30:1] stringvar;
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

// Randomly generated reference data

reg [bw-1:0] gen_x [len_nij-1:0][row-1:0]; // Activation data randomly generated
reg [bw-1:0] gen_w [col-1:0][row-1:0]; // Weight data randomly generated
reg [psum_bw-1:0] calc_psum [len_kij-1:0][len_nij-1:0][col-1:0]; // Psum calculated values
reg [psum_bw-1:0] calc_output [len_onij-1:0][col-1:0]; // Final accumulated values

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

core  #(.bw(bw), .col(col), .row(row)) core_instance (
	.clk(clk), 
	.inst(inst_q),
	.ofifo_valid(ofifo_valid),
        .D_xmem(D_xmem_q), 
        .sfp_out(sfp_out), 
	.reset(reset)); 

task calculate_kij_psum;
    input kij;
    
    integer r,c,n;
    reg [bw-1:0] act_val;
    reg [bw-1:0] weight_val;
    reg [psum_bw-1:0] psum;
    reg [2*bw:0] prod; 
    
    psum = 0; 
    
    for(n = 0; n < len_nij; n = n + 1 ) begin
      for(c = 0; c < col; c = c + 1 ) begin
        for (r = 0; r < row; r = r + 1) begin
            act_val = act_val[n][r];
            weight_val = weight_block[c][r];
          
            mac_result = $signed({{(bw){1'b0}}, activation_val}) * $signed({{(bw){weight_val[bw-1]}}, weight_val});
            psum = $signed(psum) + $signed({{(psum_bw - 2*bw){mac_result[2*bw-1]}}, mac_result});
        end
        calc_psum[kij][n][c];
      end 
    end 
endtask

task accumulate_output;
    input n; //feature map size
    input k; // kernel size
    input s; //stride

    int o_nij, kij, c;
    int index2;
    int o_dim = (n-k)/s + 1;

    for (o_nij = 0; o_nij < len_onij; o_nij = o_nij + 1) begin
        for (c = 0; c < col; c = c + 1) begin
            calc_output[o_nij][c] = 0; 
        end
    end

    for (o_nij = 0; o_nij < len_onij; o_nij = o_nij + 1) begin
        for (kij = 0; kij < len_kij; kij = kij + 1) begin
            
            // Term 1: (int(o_nij/o_ni_dim)*a_pad_ni_dim + o_nij%o_ni_dim)
            index2 = (o_nij / o_dim) * n + (o_nij % o_dim);
            
            // Term 2: + (int(kij/ki_dim)*a_pad_ni_dim + kij%ki_dim)
            index2 = index2 + (kij / k) * n + (kij % k);
            
            for (c = 0; c < col; c = c + 1) begin
                calc_output[o_nij][c] = calc_output[o_nij][c] + calc_psum[kij][c][index2];
            end
        end 
    end
endtask

initial begin 

  inst_w   = 0; 
  D_xmem   = 0;
  CEN_xmem = 1; // Disable XMEM
  WEN_xmem = 1; // Disable write to XMEM
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

  x_file = $fopen("activation.txt", "r");
  // Following three lines are to remove the first three comment lines of the file
  x_scan_file = $fscanf(x_file,"%s", stringvar);
  x_scan_file = $fscanf(x_file,"%s", stringvar);
  x_scan_file = $fscanf(x_file,"%s", stringvar);

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

  /////// Activation data writing to memory ///////

  $display("--- Starting Random Activation Generation ---");
  for(i = 0; i<len_nij; i++) begin
    for(j=0; j<row; j++) begin
      gen_x[i][j] = $urandom_range((1<<BW)-1, 0);
    end
  end

  for (t=0; t<len_nij; t=t+1) begin  
    #0.5 clk = 1'b0; 
    D_xmem = {gen_x[t][8], gen_x[t][7], gen_x[t][6], gen_x[t][5], gen_x[t][4], gen_x[t][3], gen_x[t][2], gen_x[t][1], gen_x[t][0]};
    WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1;
    #0.5 clk = 1'b1;   
  end

  #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
  #0.5 clk = 1'b1; 

  $fclose(x_file);
  /////////////////////////////////////////////////

  A_pmem= 11'b00000000001;
  for (kij=0; kij<9; kij=kij+1) begin  // kij loop

    case(kij)
     0: w_file_name = "./weights/weight_0.txt";
     1: w_file_name = "./weights/weight_1.txt";
     2: w_file_name = "./weights/weight_2.txt";
     3: w_file_name = "./weights/weight_3.txt";
     4: w_file_name = "./weights/weight_4.txt";
     5: w_file_name = "./weights/weight_5.txt";
     6: w_file_name = "./weights/weight_6.txt";
     7: w_file_name = "./weights/weight_7.txt";
     8: w_file_name = "./weights/weight_7.txt";
    endcase
    
    // w_file_name = "weight.txt";

    w_file = $fopen(w_file_name, "r");
    // Following three lines are to remove the first three comment lines of the file
    w_scan_file = $fscanf(w_file,"%s", stringvar);
    w_scan_file = $fscanf(w_file,"%s", stringvar);
    w_scan_file = $fscanf(w_file,"%s", stringvar);

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


    /////// Kernel data writing to memory ///////

    $display("--- Starting Random Weight Generation for Kij %d ---",kij);
    for(i = 0; i<col; i++) begin
      for(j=0; j<row; j++) begin
        gen_w[i][j] = $random;
      end
    end

    A_xmem = 11'b10000000000;

    for (t=0; t<col; t=t+1) begin  
      #0.5 clk = 1'b0; 
      D_xmem = {gen_w[t][8], gen_w[t][7], gen_w[t][6], gen_w[t][5], gen_w[t][4], gen_w[t][3], gen_w[t][2], gen_w[t][1], gen_w[t][0]};
      WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1; 
      #0.5 clk = 1'b1;  
    end

    // Calculate all psums for current kij
    calculate_kij_psum(kij);

    #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1; 
    /////////////////////////////////////



    /////// Kernel data writing to L0 ///////

    // Assuming the output of the XMEM SRAM is connected directly to the L0 FIFO
    #0.5 clk = 1'b0; A_xmem = 11'b10000000000;
    #0.5 clk = 1'b1;

    for(t=0; t<col; t=t+1) begin  
      #0.5 clk = 1'b0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1; l0_wr = 1;      
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0; // Write from memory to L0 is at T+1 posedge
    #0.5 clk = 1'b1; 

    #0.5 clk = 1'b0;  CEN_xmem = 1; A_xmem = 0; l0_wr = 0;
    #0.5 clk = 1'b1; 

    /////////////////////////////////////



    /////// Kernel loading to PEs ///////
    
    // Assuming l0 direcly pushes into PE
    #0.5 clk = 1'b0; l0_rd = 1; 
    #0.5 clk = 1'b1;

    // Cycles for the FIFO to complete
    for(t=0; t< 2*col; t=t+1) begin
      #0.5 clk = 1'b0; load = 1;
      #0.5 clk = 1'b1;
    end

    /////////////////////////////////////
  

    ////// provide some intermission to clear up the kernel loading ///
    #0.5 clk = 1'b0;  load = 0; l0_rd = 0;
    #0.5 clk = 1'b1;  
  

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end
    /////////////////////////////////////



    /////// Activation data writing to L0 ///////
    
    // Assuming the output of the XMEM SRAM is connected directly to the L0 FIFO
    #0.5 clk = 1'b0; A_xmem = 11'b00000000000;
    #0.5 clk = 1'b1;

    for(t=0; t<len_nij; t=t+1) begin  
      #0.5 clk = 1'b0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1; l0_wr = 1;      
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0; // Write from memory to L0 is at T+1 posedge
    #0.5 clk = 1'b1; 

    #0.5 clk = 1'b0;  CEN_xmem = 1; A_xmem = 0; l0_wr = 0;
    #0.5 clk = 1'b1; 
    /////////////////////////////////////



    /////// Execution ///////
    // Assuming l0 direcly pushes into PE
    #0.5 clk = 1'b0; l0_rd = 1;
    #0.5 clk = 1'b1;

    #0.5 clk = 1'b0; execute = 1;// Cycle for read signal to propogate
    #0.5 clk = 1'b1;

    // Cycles for the FIFO to complete
    for(t=0; t< len_nij; t=t+1) begin
      #0.5 clk = 1'b0;  execute = 1;
      #0.5 clk = 1'b1;
    end
    /////////////////////////////////////

    //// provide some intermission to complete execution ///
    #0.5 clk = 1'b0;  execute = 0; l0_rd = 0;
    #0.5 clk = 1'b1;  
  

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end

    ////////////////////////////////////

    //////// OFIFO READ ////////
    // Ideally, OFIFO should be read while execution, but we have enough ofifo
    // depth so we can fetch out after execution.

    while(!ofifo_valid) begin
      #0.5 clk = 1'b0;  
      #0.5 clk = 1'b1;
    end

    // A_pmem= 11'b00000000000;
    #0.5 clk = 1'b0; ofifo_rd = 1;
    #0.5 clk = 1'b1;

    #0.5 clk = 1'b0; WEN_pmem = 0; CEN_pmem = 0; 
    #0.5 clk = 1'b1;

    for(t=0; t<len_nij; t=t+1) begin
      #0.5 clk = 1'b0; A_pmem = A_pmem + 1; 
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0;  WEN_pmem = 1;  CEN_pmem = 1; A_xmem = 0; ofifo_rd = 0;
    #0.5 clk = 1'b1; 
    /////////////////////////////////////

  end  // end of kij loop


  ////////// Accumulation /////////
  out_file = $fopen("./outputs/output_accumulated.txt", "r");  

  // Following three lines are to remove the first three comment lines of the file
  out_scan_file = $fgets(stringvar, out_file); 
  out_scan_file = $fgets(stringvar, out_file); 
  out_scan_file = $fgets(stringvar, out_file); 

  error = 0;

  $display("############ Verification Start during accumulation #############"); 
  
  // Accumulate outputs for verification
  accumulate_output(n, k, s);
  
  //SECTION - Accumulation
  acc_file = $fopen("acc_add.txt", "r"); 

  for (i=0; i<len_onij+1; i=i+1) begin 

    #0.5 clk = 1'b0; 
    #0.5 clk = 1'b1;  

    if (i>0) begin
      answer = {calc_output[t][8], calc_output[t][7], calc_output[t][6], calc_output[t][5], calc_output[t][4], calc_output[t][3], calc_output[t][2], calc_output[t][1], calc_output[t][0]};
       if (sfp_out == answer)
         $display("%2d-th output featuremap Data matched! :D", i); 
       else begin
         $display("%2d-th output featuremap Data ERROR!!", i); 
         $display("sfpout: %128b", sfp_out);
         $display("answer: %128b", answer);
         error = 1;
       end
    end
   
 
    #0.5 clk = 1'b0; reset = 1;
    #0.5 clk = 1'b1;  
    #0.5 clk = 1'b0; reset = 0; 
    #0.5 clk = 1'b1;  

    for (j=0; j<len_kij+1; j=j+1) begin 

      #0.5 clk = 1'b0;   
        if (j<len_kij) begin CEN_pmem = 0; WEN_pmem = 1; acc_scan_file = $fscanf(acc_file,"%11b", A_pmem); end
                       else  begin CEN_pmem = 1; WEN_pmem = 1; end

        if (j>0)  acc = 1;  
      #0.5 clk = 1'b1;   
    end

    #0.5 clk = 1'b0; acc = 0;
    #0.5 clk = 1'b1; 
  end
  //!SECTION


  if (error == 0) begin
  	$display("############ No error detected ##############"); 
  	$display("########### Project Completed !! ############"); 

  end

  $fclose(acc_file);
  //////////////////////////////////

  for (t=0; t<10; t=t+1) begin  
    #0.5 clk = 1'b0;  
    #0.5 clk = 1'b1;  
  end

  #10 $finish;

end

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
   l0_wr_q    <= l0_wr ;
   execute_q  <= execute;
   load_q     <= load;
end


endmodule