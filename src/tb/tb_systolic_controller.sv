//[4] systolic_array_2d + controller

`timescale 1ns/1ps

module tb_systolic_controller;

  parameter int DATA_W = 8;
  parameter int K_DIM  = 2;
  parameter int ROWS   = 2;
  parameter int COLS   = 2;
  parameter int ACC_W  = 32;

  logic clk, rst_n;

  logic start, done, busy;
  logic signed [DATA_W*ROWS*COLS-1:0] tb_mat_a; 
  logic signed [DATA_W*ROWS*COLS-1:0] tb_mat_b;
  logic signed [ACC_W*ROWS*COLS-1:0]  tb_mat_c;

  // Reference Model
  int C_ref [0:ROWS-1][0:COLS-1];
  int err_cnt;
  int dut_acc [0:ROWS-1][0:COLS-1];


  // DUT Instantiation
  array_controller #(
    .DATA_W(DATA_W),  
    .ROW(ROWS), 
    .COL(COLS)
  ) dut (
    .clk        (clk),
    .rstn      (rst_n),

    // Control Interface
    .i_start    (start),
    .o_done     (done),
    .o_busy     (busy),

    // Data Interface
    .i_mat_act    (tb_mat_a),
    .i_mat_wei    (tb_mat_b),
    .o_mat_acc    (tb_mat_c)
  );

  // Clock Gen
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    start = 0;
    tb_mat_a  = '{default:0};
    tb_mat_b  = '{default:0};

    #20 rst_n = 1;

    $display("=== Controller-based Verification Start ===");

    for (int iter = 0; iter < 5; iter++) begin

      // 1. Data Setup (Random)
      //    TBï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ ï¿½×³ï¿½ ï¿½ï¿½ï¿½ï¿½ï¿????? ï¿½ï¿½ï¿????? ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ï¿????? ï¿½ï¿½ï¿½ï¿½ï¿½ï¿½ ï¿½ï¿½ (Skew ï¿½ï¿½ï¿½Ê¿ï¿½)
      for(int r=0; r<ROWS; r++)
        for(int k=0; k<K_DIM; k++) 
          tb_mat_a[(r*ROWS+k)*DATA_W +:DATA_W] = $urandom_range((1 << DATA_W) - 1); 

      for(int k=0; k<K_DIM; k++)
        for(int c=0; c<COLS; c++) 
          tb_mat_b[(k*K_DIM+c)*DATA_W +:DATA_W] = $urandom_range((1 << DATA_W) - 1); 

        // 2. Calculate Reference
      for(int r=0; r<ROWS; r++) begin
        for(int c=0; c<COLS; c++) begin
          C_ref[r][c] = 0;
          for(int k=0; k<K_DIM; k++) 
            C_ref[r][c] += $signed(tb_mat_a[(r*ROWS+k)*DATA_W +:DATA_W]) * $signed(tb_mat_b[(k*K_DIM+c)* DATA_W +: DATA_W]);
        end
      end

      // 3. Start Operation
      @(posedge clk);
      start = 1;
      @(posedge clk);
      start = 0;

      // 4. Wait for Done
      wait(done == 1);

      for( int i=0;i<ROWS;i=i+1) begin
        for( int j=0;j<COLS;j=j+1) begin 
           dut_acc[i][j]=tb_mat_c[(i*ROWS+j)*ACC_W +: ACC_W];
        end
      end


      // 5. Check Result
      err_cnt = 0;
      $display("--------------------------------------------------");
      $display("[Iter %0d] Checking Result...", iter);
      for(int r=0; r<ROWS; r++) begin
        for(int c=0; c<COLS; c++) begin
          if (dut_acc[r][c] !== C_ref[r][c]) begin
             $display("ERROR! [%0d][%0d]: DUT=%0d, REF=%0d", r, c, dut_acc[r][c], C_ref[r][c]);
             err_cnt++;
          end else begin
             $display("PASS! at [%0d][%0d]: DUT=%0d, REF=%0d", r, c, dut_acc[r][c],C_ref[r][c]);
          end
        end
      end
      
        
      if (err_cnt == 0) $display("[Iter %0d] FINAL RESULT: PASS!", iter);
      else              $display("[Iter %0d] FINAL RESULT: FAIL! (%0d errors)", iter, err_cnt);
      $display("--------------------------------------------------");

      // 6. Wait a bit before next run
      @(posedge clk);
    end

    $display("=== All Tests Finished ===");
    $finish;
  end

endmodule