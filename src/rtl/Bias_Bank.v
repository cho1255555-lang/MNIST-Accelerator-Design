//debug point3
`include "include.v"
module Bias_Bank #(
    parameter dataWidth = 8
)(
    input clk,
    input [31:0] layer_idx,     
    input [31:0] neuron_group,  
    output reg [4*2*dataWidth-1:0] b_out_packed 
);

    wire [dataWidth-1:0] w_b_l1 [`numNeuronLayer1-1:0];
    wire [dataWidth-1:0] w_b_l2 [`numNeuronLayer2-1:0];
    wire [dataWidth-1:0] w_b_l3 [`numNeuronLayer3-1:0];
    
    genvar g;
    generate
        for(g=0; g<`numNeuronLayer1; g=g+1) begin : B1_ROM
            reg [dataWidth-1:0] mem [0:0];
            initial begin
                mem[0] = 0; 
                $readmemb($sformatf("./bias_mif/b_1_%0d.mif", g), mem);
            end
            assign w_b_l1[g] = mem[0];
        end
        for(g=0; g<`numNeuronLayer2; g=g+1) begin : B2_ROM
            reg [dataWidth-1:0] mem [0:0];
            initial begin
                mem[0] = 0; 
                $readmemb($sformatf("./bias_mif/b_2_%0d.mif", g), mem);
            end
            assign w_b_l2[g] = mem[0];
        end
        for(g=0; g<`numNeuronLayer3; g=g+1) begin : B3_ROM
            reg [dataWidth-1:0] mem [0:0];
            initial begin
                mem[0] = 0; 
                $readmemb($sformatf("./bias_mif/b_3_%0d.mif", g), mem);
            end
            assign w_b_l3[g] = mem[0];
        end
    endgenerate

    reg [dataWidth-1:0] sel_b [3:0];
    integer k;

    always @(*) begin
        sel_b[0] = 0; sel_b[1] = 0; sel_b[2] = 0; sel_b[3] = 0;
        
        case(layer_idx)
            1: begin
                for(k=0; k<4; k=k+1) begin
                    if ((neuron_group*4 + k) < `numNeuronLayer1) sel_b[k] = w_b_l1[neuron_group*4 + k];
                end
            end
            2: begin
                for(k=0; k<4; k=k+1) begin
                    if ((neuron_group*4 + k) < `numNeuronLayer2) sel_b[k] = w_b_l2[neuron_group*4 + k];
                end
            end
            3: begin
                for(k=0; k<4; k=k+1) begin
                    if ((neuron_group*4 + k) < `numNeuronLayer3) sel_b[k] = w_b_l3[neuron_group*4 + k];
                end
            end
        endcase
    end
    
    always @(posedge clk) begin
        b_out_packed <= { 
            sel_b[3],{dataWidth{1'b0}},
            sel_b[2],{dataWidth{1'b0}},
            sel_b[1],{dataWidth{1'b0}},
            sel_b[0],{dataWidth{1'b0}}
        };
    end

endmodule
