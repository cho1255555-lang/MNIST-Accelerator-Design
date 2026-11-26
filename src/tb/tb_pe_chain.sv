//[3] systolic_array_2d

`timescale 1ns/1ps

module tb_systolic_array_2d;

  localparam int K_DIM  = 2;       // A,B�� ���� ���� (2x2 ��� ��, ���� �ڵ� ����: ���� �� �߻��� �� �ִ� Overflow ����
//  localparam int DATA_W = 8;
  localparam int DATA_W = 8;
  localparam int ACC_W  = 32;
  localparam int ROWS   = 2;
  localparam int COLS   = 2;
  localparam int TOTAL_CYCLES = 10;

  //==========================================================
  // DUT ��Ʈ
  //==========================================================
  logic                   clk;
  logic                   rst_n;
  logic                   clr; //unused
  logic                   en;

  logic [DATA_W-1:0]      a_in_row [0:ROWS-1];
  logic [DATA_W-1:0]      b_in_col [0:COLS-1];

  logic [DATA_W-1:0]       pe_mul     [0:ROWS-1][0:COLS-1];
  logic [ACC_W-1:0]       pe_acc_sum [0:ROWS-1][0:COLS-1];

  wire [DATA_W*ROWS-1:0] act_flat;
  wire [DATA_W*COLS-1:0] wei_flat;
  wire [DATA_W*2*ROWS*COLS-1:0] o_mul_flat;
  wire [ACC_W*ROWS*COLS-1:0]    o_psum_flat;

  // 2. [�Է� ����] TB�� �迭(a_in_row) -> DUT�� 1���� ��Ʈ(act_flat)
  genvar gr, gc;
  generate
    for (gr = 0; gr < ROWS; gr = gr + 1) begin : input_act_gen
      assign act_flat[gr*DATA_W +: DATA_W] = a_in_row[gr];
    end
    for (gc = 0; gc < COLS; gc = gc + 1) begin : input_wei_gen
      assign wei_flat[gc*DATA_W +: DATA_W] = b_in_col[gc];
    end
  endgenerate

  // 3. [��� ����] DUT�� 1���� ��Ʈ -> TB�� 2���� �迭(pe_acc_sum)
  generate
    for (gr = 0; gr < ROWS; gr = gr + 1) begin : output_row
      for (gc = 0; gc < COLS; gc = gc + 1) begin : output_col
        assign pe_mul[gr][gc]     = o_mul_flat[((gr*COLS + gc)*(DATA_W*2)) +: (DATA_W*2)];
        assign pe_acc_sum[gr][gc] = o_psum_flat[((gr*COLS + gc)*ACC_W) +: ACC_W];
      end
    end
  endgenerate

  array #(
    .DW (DATA_W),
    .ADW  (ACC_W),
    .ROW   (ROWS),
    .COL   (COLS)
  ) dut (
    .clk        (clk),
    .rstn      (rst_n),
    .en         (en),
    .act   (act_flat),
    .wei   (wei_flat),
    .o_mul     (o_mul_flat),
    .o_psum (o_psum_flat)
  );

  //==========================================================
  // Clock / Reset
  //==========================================================
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;  // 100MHz
  end


  int A [0:ROWS-1][0:K_DIM-1];
  int B [0:K_DIM-1][0:COLS-1];
  int C_ref [0:ROWS-1][0:COLS-1];
  int err_cnt;


//==========================================================
// Pilot Test
//==========================================================
// Reference Matrices (2x2)
//   A = [ 1  2 ]
//       [ 3  4 ]
//
//   B = [ 5  6 ]
//       [ 7  8 ]
//
//   C = A * B = [ 1*5+2*7   1*6+2*8 ] = [ 19  22 ]
//               [ 3*5+4*7   3*6+4*8 ]   [ 43  50 ]
//==========================================================  
//
//initial begin
//  // A
//  A[0][0] = 1; A[0][1] = 2;
//  A[1][0] = 3; A[1][1] = 4;
//
//  // B
//  B[0][0] = 5; B[0][1] = 6;
//  B[1][0] = 7; B[1][1] = 8;

  initial begin
      // 1. �ʱ�ȭ
      rst_n = 0; en = 0;
      a_in_row = '{default:0}; b_in_col = '{default:0};

      #20 rst_n = 1;
      #10 en = 1; 

      $display("=== [Step 3.5] Random Verification Start (%0d Iterations) ===",TOTAL_CYCLES);

      // ---------------------------------------------------------
      // 10�� �ݺ� �׽�Ʈ (Random)
      // ---------------------------------------------------------
      for (int iter = 0; iter < TOTAL_CYCLES; iter++) begin

          en = $urandom_range(0, 1); //debugging point

          // (1) �Է� ������ ���� ���� & ���� �̸� ���
          foreach(A[r,c]) A[r][c] = $urandom_range((1 << DATA_W) - 1) - (1 << (DATA_W - 1)); //unsigend - offset -> sigend
          foreach(B[r,c]) B[r][c] = $urandom_range((1 << DATA_W) - 1) - (1 << (DATA_W - 1))3;

          for(int r=0; r<ROWS; r++) begin
              for(int c=0; c<COLS; c++) begin
                  C_ref[r][c] = 0;
                  for(int k=0; k<K_DIM; k++) begin
                      C_ref[r][c] += $signed(A[r][k]) * $signed(B[k][c]);
                  end
              end
          end

          // (2) ������ ���� (Skew ����)
          // Cycle 0
          @(posedge clk); 
          a_in_row[0] <= A[0][0]; b_in_col[0] <= B[0][0];
          a_in_row[1] <= 0;       b_in_col[1] <= 0;

          // Cycle 1
          @(posedge clk);
          a_in_row[0] <= A[0][1]; b_in_col[0] <= B[1][0];
          a_in_row[1] <= A[1][0]; b_in_col[1] <= B[0][1];

          // Cycle 2
          @(posedge clk);
          a_in_row[0] <= 0;       b_in_col[0] <= 0;
          a_in_row[1] <= A[1][1]; b_in_col[1] <= B[1][1];

          // Cycle 3 (Flush)
          @(posedge clk);
          a_in_row[1] <= 0;       b_in_col[1] <= 0;

          // (3) ���� ���
          repeat(5) @(posedge clk);

          // (4) ��� üũ (��û�Ͻ� ���� ����)
          // -------------------------------------------------------
          err_cnt = 0;
          $display("==================================================");
          $display("[TB] Iteration %0d Checking C = A*B result", iter);

          if (en) begin //debugging point
            for (int r = 0; r < ROWS; r++) begin
              for (int c = 0; c < COLS; c++) begin
                if (pe_acc_sum[r][c] !== C_ref[r][c]) begin
                  err_cnt++;
                  $display("ERROR! C[%0d][%0d] mismatch: dut=%0d, ref=%0d, time=%0t",
                           r, c, pe_acc_sum[r][c], C_ref[r][c], $time);
                end else begin
                  $display("PASS!  C[%0d][%0d] match   : dut=%0d, ref=%0d, time=%0t",
                           r, c, pe_acc_sum[r][c], C_ref[r][c], $time);
                end
              end
            end

            if (err_cnt == 0)
              $display("[TB] RESULT: PASS");
            else
              $display("[TB] RESULT: FAIL (err_cnt=%0d)", err_cnt);

            $display("==================================================");
          end
          // -------------------------------------------------------

          // (5) ���� �� ���� ���� �غ�
          rst_n = 0; 
          repeat(2) @(posedge clk);
          rst_n = 1;
          @(posedge clk);

      end // End of Loop

      $display("=== All 10 Random Tests Finished! ===");
      $finish;
  end

endmodule

