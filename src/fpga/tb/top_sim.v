`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.04.2019 15:57:43
// Design Name: 
// Module Name: top_sim
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 
// 
//////////////////////////////////////////////////////////////////////////////////

`include "../rtl/include.v"

`define MaxTestSamples 10000

module top_sim(

    );
    
    reg reset;
    reg clock;
    reg [`dataWidth-1:0] in;
    reg in_valid;
    reg [`dataWidth-1:0] in_mem [784:0];
    reg [25*7:0] fileName;
    reg s_axi_awvalid;
    reg [31:0] s_axi_awaddr;
    wire s_axi_awready;
    reg [31:0] s_axi_wdata;
    reg s_axi_wvalid;
    wire s_axi_wready;
    wire s_axi_bvalid;
    reg s_axi_bready;
    wire intr;
    reg [31:0] axiRdData;
    reg [31:0] s_axi_araddr;
    wire [31:0] s_axi_rdata;
    reg s_axi_arvalid;
    wire s_axi_arready;
    wire s_axi_rvalid;
    reg s_axi_rready;
    reg [`dataWidth-1:0] expected;

    wire [31:0] numNeurons[31:1];
    wire [31:0] numWeights[31:1];
    
    assign numNeurons[1] = 30;
    assign numNeurons[2] = 20;
    assign numNeurons[3] = 10;
    assign numNeurons[4] = 10;
    
    assign numWeights[1] = 784;
    assign numWeights[2] = 30;
    assign numWeights[3] = 20;
    assign numWeights[4] = 10;
    
    integer right=0;
    integer wrong=0;

    integer fd;
    
    zyNet dut(
    .s_axi_aclk(clock),
    .s_axi_aresetn(reset),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awprot(0),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(4'hF),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arprot(0),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .axis_in_data(in),
    .axis_in_data_valid(in_valid),
    .axis_in_data_ready(),
    .intr(intr)
    );
    
            
    initial
    begin
        clock = 1'b0;
        s_axi_awvalid = 1'b0;
        s_axi_bready = 1'b0;
        s_axi_wvalid = 1'b0;
        s_axi_arvalid = 1'b0;
    end
        
    always
        #5 clock = ~clock;
    
    function [7:0] to_ascii;
      input integer a;
      begin
        to_ascii = a+48;
      end
    endfunction
    
    always @(posedge clock)
    begin
        s_axi_bready <= s_axi_bvalid;
        s_axi_rready <= s_axi_rvalid;
    end
    
    task writeAxi(
    input [31:0] address,
    input [31:0] data
    );
    begin
        @(posedge clock);
        s_axi_awvalid <= 1'b1;
        s_axi_awaddr <= address;
        s_axi_wdata <= data;
        s_axi_wvalid <= 1'b1;
        wait(s_axi_wready);
        @(posedge clock);
        s_axi_awvalid <= 1'b0;
        s_axi_wvalid <= 1'b0;
        @(posedge clock);
    end
    endtask
    
    task readAxi(
    input [31:0] address
    );
    begin
        @(posedge clock);
        s_axi_arvalid <= 1'b1;
        s_axi_araddr <= address;
        wait(s_axi_arready);
        @(posedge clock);
        s_axi_arvalid <= 1'b0;
        wait(s_axi_rvalid);
        @(posedge clock);
        axiRdData <= s_axi_rdata;
        @(posedge clock);
    end
    endtask
    
    task configWeights();
    integer i,j,k,t;
    integer neuronNo_int;
    reg [`dataWidth:0] config_mem [783:0];
    begin
        @(posedge clock);
        for(k=1;k<=`numLayers;k=k+1)
        begin
            writeAxi(12,k);//Write layer number
            for(j=0;j<numNeurons[k];j=j+1)
            begin
                neuronNo_int = j;
                fileName[0] = "f";
                fileName[1] = "i";
                fileName[2] = "m";
                fileName[3] = ".";
                if(j > 9)
                begin
                    fileName[4] = 48;
                    fileName[5] = 48;
                    i=0;
                    while(neuronNo_int != 0)
                    begin
                        fileName[i+4] = to_ascii(neuronNo_int%10);
                        neuronNo_int = neuronNo_int/10;
                        i=i+1;
                    end 
                    fileName[6] = "_";
                    fileName[7] = to_ascii(k);
                    fileName[8] = "_";
                    fileName[9] = "w";
                end
                else
                begin
                    fileName[4] = 48;
                    i=0;
                    while(neuronNo_int != 0)
                    begin
                        fileName[i+4] = to_ascii(neuronNo_int%10);
                        neuronNo_int = neuronNo_int/10;
                        i=i+1;
                    end 
                    fileName[5] = "_";
                    fileName[6] = to_ascii(k);
                    fileName[7] = "_";
                    fileName[8] = "w";
                end
                $readmemb(fileName, config_mem);
                writeAxi(16,j);//Write neuron number
                for (t=0; t<numWeights[k]; t=t+1) begin
                    writeAxi(0,{15'd0,config_mem[t]});
                end 
            end
        end
    end
    endtask
    
    task configBias();
    integer i,j,k,t;
    integer neuronNo_int;
    reg [31:0] bias[0:0];
    begin
        @(posedge clock);
        for(k=1;k<=`numLayers;k=k+1)
        begin
            writeAxi(12,k);//Write layer number
            for(j=0;j<numNeurons[k];j=j+1)
            begin
                neuronNo_int = j;
                fileName[0] = "f";
                fileName[1] = "i";
                fileName[2] = "m";
                fileName[3] = ".";
                if(j>9)
                begin
                    fileName[4] = 48;
                    fileName[5] = 48;
                    i=0;
                    while(neuronNo_int != 0)
                    begin
                        fileName[i+4] = to_ascii(neuronNo_int%10);
                        neuronNo_int = neuronNo_int/10;
                        i=i+1;
                    end 
                    fileName[6] = "_";
                    fileName[7] = to_ascii(k);
                    fileName[8] = "_";
                    fileName[9] = "b";
                end
                else
                begin
                    fileName[4] = 48;
                    i=0;
                    while(neuronNo_int != 0)
                    begin
                        fileName[i+4] = to_ascii(neuronNo_int%10);
                        neuronNo_int = neuronNo_int/10;
                        i=i+1;
                    end 
                    fileName[5] = "_";
                    fileName[6] = to_ascii(k);
                    fileName[7] = "_";
                    fileName[8] = "b";               
                end
                $readmemb(fileName, bias);
                writeAxi(16,j);//Write neuron number
                writeAxi(4,{15'd0,bias[0]});
            end
        end
    end
    endtask
    
    
    task sendData();
    //input [25*7:0] fileName;
    integer t;
    begin
        $readmemb(fileName, in_mem);
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);
        for (t=0; t <784; t=t+1) begin
            @(posedge clock);
            in <= in_mem[t];
            in_valid <= 1;
            //@(posedge clock);
            //in_valid <= 0;
        end 
        @(posedge clock);
        in_valid <= 0;
        expected = in_mem[t];
    end
    endtask
   
    integer i,j,layerNo=1,k;
    integer start;
    integer end_time;
    integer testDataCount;
    integer testDataCount_int;
    reg[7:0] fileNum [3:0];
    initial
    begin
        fd = $fopen("./golden_pass_fail.csv","w"); //file stream open
        $fdisplay(fd,"%s,%s,%s,%s","test_idx","golden","result","check"); 

        reset = 0;
        in_valid = 0;
        #100;
        reset = 1;
        #100
        writeAxi(28,0);//clear soft reset
        start = $time;
        `ifndef pretrained
            configWeights();
            configBias();
        `endif
        $display("Configuration completed",,,,$time-start,,"ns");
        start = $time;
        for(testDataCount=0;testDataCount<`MaxTestSamples;testDataCount=testDataCount+1)
        begin
            l1_printed = 0; 
            l2_printed = 0; 
            l3_printed = 0;
            testDataCount_int = testDataCount;
            fileName = "test_data_";
            
            for (i = 0; i < 4; i = i + 1) 
            begin
                fileNum[i] = 8'b0; // Initialize each register to 0
            end

            i=0;
            while(testDataCount_int != 0)
            begin
                fileNum[i] = (testDataCount_int%10);
                testDataCount_int = testDataCount_int/10;
                i=i+1;
            end
            
            for (i = 4; i > 0; i = i-1)
            begin
                if (fileNum[i - 1] == 0)
                begin
                    fileName = {fileName, "0"};
                end
                else
                begin
                    fileName = {fileName, to_ascii(fileNum[i - 1])};
                end
            end
            
            fileName = {fileName, ".txt"};
            
            $display("Filename: %s",fileName);
            sendData();
            @(posedge intr);
            //readAxi(24);
            //$display("Status: %0x",axiRdData);
            readAxi(8);
            if(axiRdData==expected)
                right = right+1;
            $display("%0d. Accuracy: %f, Detected number: %0x, Expected: %x",testDataCount+1,right*100.0/(testDataCount+1),axiRdData,expected);
            $fdisplay(fd,"%d,%d,%d,%s",testDataCount,expected,axiRdData,(axiRdData==expected)?"Pass":"Fail");
            
            /*$display("Total execution time",,,,$time-start,,"ns");
            j=0;
            repeat(10)
            begin
                readAxi(20);
                $display("Output of Neuron %d: %0x",j,axiRdData);
                j=j+1;
            end*/
        end
        
        
        $display("Accuracy: %f",right*100.0/testDataCount);
        end_time = $time;
        $display("inference time %d ns",end_time-start);
        $stop;
        
    end
    
    integer m, n, p;
    reg [`dataWidth-1:0] l1_unpacked [29:0];
    reg [`dataWidth-1:0] l2_unpacked [19:0];
    reg [`dataWidth-1:0] l3_unpacked [9:0];
    reg l1_printed = 0, l2_printed = 0, l3_printed = 0;

    always @(posedge clock) begin
        if (dut.o1_valid[0] == 1 && l1_printed == 0) begin
            $display("\n============================================================");
            $display("[Ref] Layer 1 Calculation Complete! (Img 0 Output Matrix [1x30])");
            $display("============================================================");
            $write("[ ");
            for (m=0; m<30; m=m+1) begin
                l1_unpacked[m] = dut.x1_out[m*`dataWidth +: `dataWidth];
                $write("%d ", $signed(l1_unpacked[m]));
                if ((m+1)%10 == 0 && m != 29) $write("\n  ");
            end
            $write(" ]\n");
            $display("============================================================\n");
            l1_printed <= 1; 
        end

        if (dut.o2_valid[0] == 1 && l2_printed == 0) begin
            $display("\n============================================================");
            $display("[Ref] Layer 2 Calculation Complete! (Img 0 Output Matrix [1x20])");
            $display("============================================================");
            $write("[ ");
            for (n=0; n<20; n=n+1) begin
                l2_unpacked[n] = dut.x2_out[n*`dataWidth +: `dataWidth];
                $write("%d ", $signed(l2_unpacked[n]));
                if ((n+1)%10 == 0 && n != 19) $write("\n  ");
            end
            $write(" ]\n");
            $display("============================================================\n");
            l2_printed <= 1; 
        end

        if (dut.o3_valid[0] == 1 && l3_printed == 0) begin
            $display("\n============================================================");
            $display("[Ref] Layer 3 Calculation Complete! (Img 0 Output Matrix [1x10])");
            $display("============================================================");
            $write("[ ");
            for (n=0; n<10; n=n+1) begin
                l3_unpacked[n] = dut.x3_out[n*`dataWidth +: `dataWidth];
                $write("%d ", $signed(l3_unpacked[n]));
                if ((n+1)%10 == 0 && n != 9) $write("\n  ");
            end
            $write(" ]\n");
            $display("============================================================\n");
            l3_printed <= 1; 
        end
    end
    //`endif

    // --- [Added] Debug Monitor for Neuron 0 & 4 (L1 & L2) ---
    //`ifdef DEBUG_PIXEL
    always @(posedge clock) begin
    /*
        // Layer 1 Monitor (Neuron 0)
        if (dut.l1.n_0.myinputValid || dut.l1.n_0.mult_valid) begin
            $display("[Ref_DEBUG_L1_N0] Time=%0t | k=%d | Input=%d | Weight=%d | Mul=%d | Sum=%d, %d, %d, %d", 
                     $time, 
                     dut.l1.n_0.r_addr, 
                     $signed(dut.l1.n_0.myinputd), 
                     $signed(dut.l1.n_0.w_out), 
                     $signed(dut.l1.n_0.mul), 
                     $signed(dut.l1.n_0.sum),
                     $signed(dut.l1.n_1.sum),
                     $signed(dut.l1.n_2.sum),
                     $signed(dut.l1.n_3.sum)
                     );
        end
        */
        
        
/*        
        if (dut.l1.n_1.myinputValid || dut.l1.n_1.mult_valid) begin
            $display("[Ref_DEBUG_L1_N1] Time=%0t | k=%d | Input=%d | Weight=%d | Mul=%d | Sum=%d", 
                     $time, 
                     dut.l1.n_1.r_addr, 
                     $signed(dut.l1.n_1.myinputd), 
                     $signed(dut.l1.n_1.w_out), 
                     $signed(dut.l1.n_1.mul), 
                     $signed(dut.l1.n_1.sum));
        end
*/
  
        // Layer 2 Monitor (Neuron 0)
        if (dut.l2.n_0.myinputValid || dut.l2.n_0.mult_valid) begin
            $display("[Ref_DEBUG_L2_N0] Time=%0t | k=%d | Input=%d | Weight=%d | Mul=%d | Sum=%d, %d, %d, %d", 
                     $time, 
                     dut.l2.n_0.r_addr, 
                     $signed(dut.l2.n_0.myinputd), 
                     $signed(dut.l2.n_0.w_out), 
                     $signed(dut.l2.n_0.mul), 
                     $signed(dut.l2.n_0.sum),
                     $signed(dut.l2.n_1.sum),
                     $signed(dut.l2.n_2.sum),
                     $signed(dut.l2.n_3.sum)
                     );
        end

        //// Layer 2 Monitor (Neuron 4)
        //if (dut.l2.n_4.myinputValid || dut.l2.n_4.mult_valid) begin
        //    $display("[Ref_DEBUG_L2_N4] Time=%0t | k=%d | Input=%d | Weight=%d | Mul=%d | Sum=%d", 
        //             $time, 
        //             dut.l2.n_4.r_addr, 
        //             $signed(dut.l2.n_4.myinputd), 
        //             $signed(dut.l2.n_4.w_out), 
        //             $signed(dut.l2.n_4.mul), 
        //             $signed(dut.l2.n_4.sum));
        //end
        
        // Layer 2 Monitor (Neuron 0)
        if (dut.l3.n_0.myinputValid || dut.l3.n_0.mult_valid) begin
            $display("[Ref_DEBUG_L2_N0] Time=%0t | k=%d | Input=%d | Weight=%d | Mul=%d | Sum=%d, %d, %d, %d", 
                     $time, 
                     dut.l3.n_0.r_addr, 
                     $signed(dut.l3.n_0.myinputd), 
                     $signed(dut.l3.n_0.w_out), 
                     $signed(dut.l3.n_0.mul), 
                     $signed(dut.l3.n_0.sum),
                     $signed(dut.l3.n_1.sum),
                     $signed(dut.l3.n_2.sum),
                     $signed(dut.l3.n_3.sum)
                     );
        end
    end
    //`endif
    
    


endmodule
