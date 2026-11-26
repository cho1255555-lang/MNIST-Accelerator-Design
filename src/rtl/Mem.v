module Mem #(
    parameter DW  = 8,
    parameter DEPTH = 32,
    parameter ADW = $clog2(DEPTH)  
)(
    input clk,
    input [DW-1:0] i_data,
    input [ADW-1:0] addr,
    input en, 
    input cs,  
    output reg [DW-1:0] o_data
);

   
    reg [DW-1:0] ram [0:DEPTH-1];

  
    always @(posedge clk) begin
        if (cs) begin
            if (en) begin
                ram[addr] <= i_data;
            end
            o_data <= ram[addr];
        end
    end



endmodule