`include "include.v"
module Weight_Bank #(
    parameter dataWidth = 8
)(
    input clk,
    input [31:0] layer_idx,
    input [31:0] neuron_group,
    input [9:0] w_addr,
    
    output reg [4*dataWidth-1:0] w_out_packed
);

    wire [dataWidth-1:0] w_l1 [`numNeuronLayer1-1:0];
    wire [dataWidth-1:0] w_l2 [`numNeuronLayer2-1:0];
    wire [dataWidth-1:0] w_l3 [`numNeuronLayer3-1:0];

    genvar i,j;
    
    generate
        
        for(i=0; i<`numNeuronLayer1; i=i+1) begin : L1_MEM
            Weight_Memory #(.numWeight(`numWeightLayer1), .dataWidth(dataWidth), .weightFile($sformatf("./weight_mif/w_1_%0d.mif", i))) 
            wm (.clk(clk), .wen(1'b0), .ren(1'b1), .wadd(10'd0), .win({dataWidth{1'b0}}), .radd(w_addr[9:0]), .wout(w_l1[i]));
        end
        

        for(i=0; i<`numNeuronLayer2; i=i+1) begin : L2_MEM
            Weight_Memory #(.numWeight(`numWeightLayer2), .dataWidth(dataWidth), .weightFile($sformatf("./weight_mif/w_2_%0d.mif", i))) 
            wm (.clk(clk), .wen(1'b0), .ren(1'b1), .wadd(10'd0), .win({dataWidth{1'b0}}), .radd(w_addr[9:0]), .wout(w_l2[i]));
        end
        for(i=0; i<`numNeuronLayer3; i=i+1) begin : L3_MEM
            Weight_Memory #(.numWeight(`numWeightLayer3), .dataWidth(dataWidth), .weightFile($sformatf("./weight_mif/w_3_%0d.mif", i))) 
            wm (.clk(clk), .wen(1'b0), .ren(1'b1), .wadd(10'd0), .win({dataWidth{1'b0}}), .radd(w_addr[9:0]), .wout(w_l3[i]));
        end
    endgenerate
    
    reg [dataWidth-1:0] sel_w [0:3];
    reg [dataWidth-1:0] raw_w; 

    localparam L1 = 'd1;
    localparam L2 = 'd2;
    localparam L3 = 'd3;

    integer k;
    
    always @(*) begin
    
        // weight ?„ ?ƒ
        for (k = 0; k < 4; k = k + 1) begin
            int idx;
            //idx = neuron_group*4 + k;
            idx = (neuron_group << 2) + k;   // multiply by 4 ?†’ HW-friendly shift  
            raw_w = '0;
    
            // layer ?„ ?ƒ
            case (layer_idx)
                L1: if (idx < `numNeuronLayer1) raw_w = w_l1[idx];
                L2: if (idx < `numNeuronLayer2) raw_w = w_l2[idx];
                L3: if (idx < `numNeuronLayer3) raw_w = w_l3[idx];
                default: raw_w = '0;
            endcase

            sel_w[k] = raw_w;
        end
    
        // weight 4ê°œë?? ?Œ¨?‚¹
        w_out_packed = {sel_w[3], sel_w[2], sel_w[1], sel_w[0]};
    end

endmodule
