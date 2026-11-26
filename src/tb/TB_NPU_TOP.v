`timescale 1ns / 1ps
`include "include.v"

module TB_NPU_Top();

    reg clk, rst_n;
    reg start_inference;
    reg [4*`dataWidth-1:0] input_pixels;
    reg input_valid;
    wire done;
    wire [7:0] results [3:0];
    wire [31:0] result;

    reg [`dataWidth-1:0] img_mem_0 [784:0];
    reg [`dataWidth-1:0] img_mem_1 [784:0];
    reg [`dataWidth-1:0] img_mem_2 [784:0];
    reg [`dataWidth-1:0] img_mem_3 [784:0];
    
    reg [`dataWidth-1:0] captured_l1_out [0:29];
    reg [`dataWidth-1:0] captured_l2_out [0:19];
    reg [`dataWidth-1:0] captured_l3_out [0:9];

    reg [255:0] file_path;
    
    reg [255:0] file_path1;
    reg [255:0] file_path2;
    reg [255:0] file_path3;
    reg [255:0] file_path4;

    integer i, j;
    integer fd;
    integer start_time;
    integer end_time;

    localparam testMax = 4;

    NPU_Top #(.DW(`dataWidth)) dut (
        .clk(clk), .rst_n(rst_n), .start_inference(start_inference),
        .input_pixels(input_pixels), .input_valid(input_valid),
        .done_interrupt(done),
        //.result_class_0(results[0]), .result_class_1(results[1]),
        //.result_class_2(results[2]), .result_class_3(results[3]),
        .result(result)
    );

    always #5 clk = ~clk;
//1000data test
/*
    initial begin

        fd = $fopen("./weight_act_check.csv","w"); //file stream open
        $fdisplay(fd,"%s,%s,%s,%s","test_idx","golden","result","check");  
        for(j=0;j<testMax;j=j+1) begin
            clk = 0; rst_n = 0;
            start_inference = 0; input_valid = 0;
            input_pixels = 0;

            
            
            $sformat(file_path, "./test_data/test_data_%04d.txt", j); //file input

            for(i=0; i<=784; i=i+1) begin
                img_mem_0[i] = 0; img_mem_1[i] = 0; img_mem_2[i] = 0; img_mem_3[i] = 0;
            end

            $readmemb(file_path, img_mem_0);
            //$readmemb("./test_data/test_data_0003.txt", img_mem_0);
            //$readmemb("test_data_0001.txt", img_mem_1);
            //$readmemb("test_data_0002.txt", img_mem_2);
            //$readmemb("test_data_0003.txt", img_mem_3);
            
            //$display("============================================================");
            //$display("[TB] Checking Image Memory 0 (test_data_0000.txt)...");
            //for(i=0; i<784; i=i+1) $display("[TB] Index %0d = %0b", i, img_mem_0[i]);
            //$display("============================================================");

            #100 rst_n = 1;
            @(posedge clk);
            #20 start_inference = 1;
            @(posedge clk);
            #10 start_inference = 0;
            //fd = $fopen("./weight_check.csv","w"); //file stream open
            wait(dut.state == 1); 
            @(negedge done);
            #10

            $fdisplay(fd,"%d,%d,%d,%s",j,img_mem_0[784],results[0],(results[0]==img_mem_0[784])?"Pass":"Fail");

            $display("------------------------------------------------------------");
            $display("[TB] [Case %0d] Result: %0d | Expected: %0d", j, results[0], img_mem_0[784]);
            
           
                if (results[0] == img_mem_0[784]) 
                    $display("[TB] >>> PASS <<<"); 
                else 
                    $display("[TB] >>> FAIL <<<");
            $display("------------------------------------------------------------");
            repeat(10) @(posedge clk);

            
        end
        $display("All %0d test cases completed successfully.", testMax);
        $fclose(fd);
        $finish;
    end
    */



    initial begin  



        fd = $fopen("./fxf_pass_fail.csv","w"); //file stream open
        $fdisplay(fd,"%s,%s,%s,%s","test_idx","golden","result","check");  
        for(j=0;j<testMax/4;j=j+1) begin  
            clk = 0; rst_n = 0;
            start_inference = 0; input_valid = 0;
            input_pixels = 0;


            for(i=0; i<=784; i=i+1) begin
                img_mem_0[i] = 0; img_mem_1[i] = 0; img_mem_2[i] = 0; img_mem_3[i] = 0;
            end

            $sformat(file_path1, "./test_data/test_data_%04d.txt", 4*j); 
            $sformat(file_path2, "./test_data/test_data_%04d.txt", 4*j+1); 
            $sformat(file_path3, "./test_data/test_data_%04d.txt", 4*j+2); 
            $sformat(file_path4, "./test_data/test_data_%04d.txt", 4*j+3); 
            
            $readmemb(file_path1, img_mem_0);
            $readmemb(file_path2, img_mem_1);
            $readmemb(file_path3, img_mem_2);
            $readmemb(file_path4, img_mem_3);
            

            #100 rst_n = 1;
            @(posedge clk);
            #20 start_inference = 1;
            start_time = $time;
            @(posedge clk);
            #10 start_inference = 0;
            wait(dut.state == 1); 

            @(negedge done);
            end_time = $time;
            #10

            $fdisplay(fd,"%d,%d,%d,%s",4*j,img_mem_0[784],results[0],(results[0]==img_mem_0[784])?"Pass":"Fail");
            $fdisplay(fd,"%d,%d,%d,%s",4*j+1,img_mem_1[784],results[1],(results[1]==img_mem_1[784])?"Pass":"Fail");
            $fdisplay(fd,"%d,%d,%d,%s",4*j+2,img_mem_2[784],results[2],(results[2]==img_mem_2[784])?"Pass":"Fail");
            $fdisplay(fd,"%d,%d,%d,%s",4*j+3,img_mem_3[784],results[3],(results[3]==img_mem_3[784])?"Pass":"Fail");

            $display("------------------------------------------------------------");
            $display("[TB] [Case %0d] Result: %0d | Expected: %0d", 4*j, results[0], img_mem_0[784]);
            
           
                if (results[0] == img_mem_0[784]) 
                    $display("[TB] >>> PASS <<<"); 
                else 
                    $display("[TB] >>> FAIL <<<");
            $display("------------------------------------------------------------");
            $display("[TB] [Case %0d] Result: %0d | Expected: %0d", 4*j+1, results[1], img_mem_1[784]);
            
           
                if (results[1] == img_mem_1[784]) 
                    $display("[TB] >>> PASS <<<"); 
                else 
                    $display("[TB] >>> FAIL <<<");
            $display("------------------------------------------------------------");
            $display("[TB] [Case %0d] Result: %0d | Expected: %0d", 4*j+2, results[2], img_mem_2[784]);
            
           
                if (results[2] == img_mem_2[784]) 
                    $display("[TB] >>> PASS <<<"); 
                else 
                    $display("[TB] >>> FAIL <<<");
            $display("------------------------------------------------------------");
            $display("[TB] [Case %0d] Result: %0d | Expected: %0d", 4*j+3, results[3], img_mem_3[784]);
        
           
                if (results[3] == img_mem_3[784]) 
                    $display("[TB] >>> PASS <<<"); 
                else 
                    $display("[TB] >>> FAIL <<<");                        
            $display("------------------------------------------------------------");
            
            
            repeat(10) @(posedge clk);
        end
        $display("inference time : %d ns",end_time-start_time);
        $finish;
    end
    


    reg [3:0] prev_state;

   

    
    /*
    
     always @(posedge clk) begin
        // Layer 1 Monitor (Neuron 0)
        if ((dut.state==1) && dut.pe_en && dut.group_cnt==0) begin
            $fwrite(fd,"%0t,",$time);
            $fwrite(fd,"%d,",dut.k_cnt);
            $fwrite(fd,"%d,",dut.sys_row_in[7:0]);
            $fwrite(fd,"%d,",dut.sys_col_in[7:0]);
            $fwrite(fd,"%d,",dut.sa.d_act[0][0]);
            $fdisplay(fd,"%d",dut.sa.d_wei[0][0]);
            $display("[Ref_DEBUG_L1_N0] Time=%0t | Input=%d | Weight0=%d | Weight1=%d | Weight2=%d  | Weight3=%d  | Mul=%d | Sum= %d, %d, %d, %d", 
                     $time,          
                     $signed(dut.sys_row_in), 
                     $signed(dut.sys_col_in[7:0]), 
                     $signed(dut.sys_col_in[15:8]), 
                     $signed(dut.sys_col_in[23:16]), 
                     $signed(dut.sys_col_in[31:24]), 
                     $signed(dut.sa.o_mul[15:0]), 
                     $signed(dut.array_out[31:0]),
                     $signed(dut.array_out[63:32]),
                     $signed(dut.array_out[95:64]),
                     $signed(dut.array_out[127:96]),
                     );
        end
     end
*/     

    /*
     always @(posedge clk) begin
        // Layer 2 Monitor (Neuron 0)
        if ((dut.state==3) && dut.pe_en && dut.group_cnt==0) begin
            $fwrite(fd,"%0t,",$time);
            $fwrite(fd,"%d,",dut.k_cnt);
            $fwrite(fd,"%d,",dut.sys_row_in[7:0]);
            $fwrite(fd,"%d, ,",dut.sys_col_in[7:0]);
            $fwrite(fd,"%d,",dut.sa.d_act[0][0]);
            $fdisplay(fd,"%d",dut.sa.d_wei[0][0]);
            $display("[Ref_DEBUG_L2_N0] Time=%0t | Input=%d | Weight0=%d | Weight1=%d | Weight2=%d  | Weight3=%d  | Mul=%d | Sum= %d, %d, %d, %d", 
                     $time,          
                     $signed(dut.sys_row_in), 
                     $signed(dut.sys_col_in[7:0]), 
                     $signed(dut.sys_col_in[15:8]), 
                     $signed(dut.sys_col_in[23:16]), 
                     $signed(dut.sys_col_in[31:24]), 
                     $signed(dut.sa.o_mul[15:0]), 
                     $signed(dut.array_out[31:0]),
                     $signed(dut.array_out[63:32]),
                     $signed(dut.array_out[95:64]),
                     $signed(dut.array_out[127:96]),
                     );
        end
     end
     */

    /*
     always @(posedge clk) begin
        // Layer 3 Monitor (Neuron 0)
        if ((dut.state==5) && dut.pe_en && dut.group_cnt==0) begin
            $fwrite(fd,"%0t,",$time);
            $fwrite(fd,"%d,",dut.k_cnt);
            $fwrite(fd,"%d,",dut.sys_row_in[7:0]);
            $fwrite(fd,"%d, ,",dut.sys_col_in[7:0]);
            $fwrite(fd,"%d,",dut.sa.d_act[0][0]);
            $fdisplay(fd,"%d",dut.sa.d_wei[0][0]);
            $display("[Ref_DEBUG_L3_N0] Time=%0t | Input=%d | Weight0=%d | Weight1=%d | Weight2=%d  | Weight3=%d  | Mul=%d | Sum= %d, %d, %d, %d", 
                     $time,          
                     $signed(dut.sys_row_in), 
                     $signed(dut.sys_col_in[7:0]), 
                     $signed(dut.sys_col_in[15:8]), 
                     $signed(dut.sys_col_in[23:16]), 
                     $signed(dut.sys_col_in[31:24]), 
                     $signed(dut.sa.o_mul[15:0]), 
                     $signed(dut.array_out[31:0]),
                     $signed(dut.array_out[63:32]),
                     $signed(dut.array_out[95:64]),
                     $signed(dut.array_out[127:96]),
                     );
        end
     end
    */
    always @(posedge clk) begin
        prev_state <= dut.state;

        if (dut.state == 1) begin 
             if (dut.k_cnt < 784) begin
                 input_pixels <= {img_mem_3[dut.k_cnt], img_mem_2[dut.k_cnt], img_mem_1[dut.k_cnt], img_mem_0[dut.k_cnt]};
                 input_valid <= 1;
             end else begin
                 input_valid <= 0;
             end
        end else begin
            input_valid <= 0;
        end
        
        /*
        //arrayout capture
        if(dut.calc_done) begin
            $display(" %0t : array_out value : %h\n", $time, dut.array_out);
        end
        */

        // Capture logic
        // Layer 1 Capture
        if (dut.buf_wen && dut.state ==2) //state 2 check
            if (dut.buf_w_addr < 30) begin
                captured_l1_out[dut.buf_w_addr] = dut.buf_w_data[7:0];
            end
            
        if (prev_state == 2 && dut.state == 3) begin
            $display("\n============================================================");
            $display("[TB] Layer 1 Calculation Complete!");
            $write("[ ");
            for(i=0; i<30; i=i+1) begin
                $write("%d ", $signed(captured_l1_out[i]));
                if ((i+1)%10 == 0 && i != 29) $write("\n  ");
            end
            $write(" ]\n");
            $display("============================================================\n");
        end

        // Layer 2 Capture
        if ( dut.buf_wen && dut.state ==4) begin
            if (dut.buf_w_addr >= 30 && dut.buf_w_addr < 50 ) begin
                captured_l2_out[dut.buf_w_addr-30] = dut.buf_w_data[7:0];
            end
        end

        if (prev_state == 4 && dut.state == 5) begin
            $display("\n============================================================");
            $display("[TB] Layer 2 Calculation Complete!");
            $write("[ ");
            for(i=0; i<20; i=i+1) begin
                $write("%d ", $signed(captured_l2_out[i]));
                if ((i+1)%10 == 0 && i != 19) $write("\n  ");
            end
            $write(" ]\n");
            $display("============================================================\n");
        end

        // Layer 3 Capture
        if (dut.state == 6 && dut.buf_wen) begin
            if (dut.buf_w_addr < 10) begin
                captured_l3_out[dut.buf_w_addr] = dut.buf_w_data;
            end
        end

        if (prev_state == 6 && dut.state == 7) begin
            $display("\n============================================================");
            $display("[TB] Layer 3 Calculation Complete!");
            $write("[ ");
            for(i=0; i<10; i=i+1) begin
                $write("%d ", $signed(captured_l3_out[i]));
                if ((i+1)%10 == 0 && i != 9) $write("\n  ");
            end
            $write(" ]\n");
            $display("============================================================\n");
        end

        /*
        if (done) begin
            $display("============================================================");
            $display("[TB] Inference DONE at time %0t", $time);
            
            repeat(20) @(posedge clk);
            
            $display("------------------------------------------------------------");
            $display("[TB] [Image 0] Result: %0d | Expected: %0d", results[0], img_mem_0[784]);
            if (results[0] == img_mem_0[784]) $display("[TB] >>> PASS <<<"); else $display("[TB] >>> FAIL <<<");

            //$display("------------------------------------------------------------");
            //$display("[TB] [Image 1] Result: %0d | Expected: %0d", results[1], img_mem_1[784]);
            //if (results[1] == img_mem_1[784]) $display("[TB] >>> PASS <<<"); else $display("[TB] >>> FAIL <<<");
            //$display("------------------------------------------------------------");
            //$display("[TB] [Image 2] Result: %0d | Expected: %0d", results[2], img_mem_2[784]);
            //if (results[2] == img_mem_2[784]) $display("[TB] >>> PASS <<<"); else $display("[TB] >>> FAIL <<<");
            //$display("------------------------------------------------------------");
            //$display("[TB] [Image 3] Result: %0d | Expected: %0d", results[3], img_mem_3[784]);
            //if (results[3] == img_mem_3[784]) $display("[TB] >>> PASS <<<"); else $display("[TB] >>> FAIL <<<");
            
            $display("============================================================");
            
            //$fclose(fd);
        end
        */
    end
    

endmodule

