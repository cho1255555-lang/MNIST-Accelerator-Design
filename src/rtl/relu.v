module relu #(
    parameter ADW = 32,
    parameter DW = 8
)(
    input   clk,
    input   rstn,
    input   i_load,
    input   i_done,
    input   clear,                    
    input  signed [ADW-1:0] i_psum,   
    input   [2*DW-1:0] i_bias,   
    
    input testvar1,
    input testvar2,
    
    output  [DW-1:0]  o_data
);

    localparam SHIFT_VAL = 4;
    
    wire [ADW-1:0] bias = (i_bias[2*DW-1]) ? {{(ADW-2*DW){1'b1}}, i_bias} : {{(ADW-2*DW){1'b0}}, i_bias};
    wire signed [ADW-1:0] sum_result = (i_psum==0)?i_psum:i_psum + bias; // i_psum + acc;
    wire signed [ADW-1:0] shifted_result = sum_result >>> SHIFT_VAL;
    reg signed [ADW-1:0] acc;

    always @(posedge clk or negedge rstn) begin
        if (!rstn || clear) begin
            acc <= 0;
        end
        /*
        else if(i_load) begin
            if(i_psum==0) 
                acc<=0;
            else
                acc <= bias;
        end
        */
        else if(i_done) begin
            if (sum_result < 0)
                acc <= 0;
            else if (shifted_result > 127)
                acc <= 127;
            else
                acc <= shifted_result * testvar1 + testvar2;
        end
    end

    assign o_data = acc[DW-1:0];
endmodule