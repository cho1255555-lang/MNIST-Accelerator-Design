module ex_relu #(
    parameter ADW = 32
)(
    input   clk,
    input   rstn,
    input   i_start,
    input   i_done,                    
    input   [ADW-1:0] i_psum,   
    input   [ADW-1:0] i_bias,   
    output reg [ADW-1:0]    o_data
);

    wire signed [ADW-1:0] sum_result = i_psum + o_data;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            o_data <= 0;
        end
        else if(i_start) begin
            o_data <= i_bias;
        end
        else if(i_done) begin
            if (sum_result < 0)
                o_data <= 0;
            else
                o_data <= sum_result;
        end

    end
endmodule