module Global_Buffer #(
    parameter DW = 8,
    parameter ROW = 4,
    parameter COL = 4,
    parameter DEPTH = 64,
    parameter ADW = $clog2(DEPTH)
)(
    input clk,
    input wen,
    input [ROW*DW-1:0] w_data,
    output [ROW*DW-1:0] r_data,
    
    input [ADW-1:0] r_addr,
    input [ADW-1:0] w_addr
    
   
    // 4 Read Ports for Systolic Array
);
    wire [DW-1:0] i_data [0:ROW-1];
    wire [DW-1:0] o_data [0:ROW-1];
    wire [ADW-1:0] addr = (wen)? w_addr:r_addr;
    
    genvar i;
    generate
        for(i=0;i<ROW;i=i+1) begin : Global_buf_gen
            Mem #(
                .DW(DW),
                .DEPTH(DEPTH),
                .ADW(ADW)
            )u_global_buf(
                .clk(clk),
                .i_data(i_data[i]),
                .addr(addr),
                .en(wen),
                .cs(1'b1),
                .o_data(o_data[i])
            );
            assign i_data[i] = w_data[DW*i +: DW];
            assign r_data[DW*i +: DW] = o_data[i];
        end
    endgenerate


endmodule