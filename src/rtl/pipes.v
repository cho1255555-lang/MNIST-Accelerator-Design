module pipes#(
    parameter DW = 8,
    parameter ROW = 4,
    parameter COL = 4
)(
    input clk,
    input rstn,
    input clear,
    input en, 
    
    //data interface
    input [DW*ROW-1:0] i_mat_act,
    input [DW*COL-1:0] i_mat_wei,
    output [DW*ROW-1:0] o_act,
    output [DW*COL-1:0] o_wei
);
    reg [DW-1:0] act_pipe1;
    reg [DW*2-1:0] act_pipe2;
    reg [DW*3-1:0] act_pipe3;
    reg [DW*4-1:0] act_pipe4;

    reg [DW-1:0] wei_pipe1;
    reg [DW*2-1:0] wei_pipe2;
    reg [DW*3-1:0] wei_pipe3;
    reg [DW*4-1:0] wei_pipe4;
    
//-------------------------------------------------------
//                      data
//-------------------------------------------------------

    
    always@(posedge clk or negedge rstn) begin
            if(!rstn|clear) begin        
                act_pipe1 <= 0;
                act_pipe2 <= 0;
                act_pipe3 <= 0;
                act_pipe4 <= 0;
            end
            else begin
                if(en) begin
                    act_pipe1 <= i_mat_act[DW*0+:DW];
                    act_pipe2 <= {i_mat_act[DW*1+:DW],act_pipe2[DW*2-1 -:DW]};
                    act_pipe3 <= {i_mat_act[DW*2+:DW],act_pipe3[DW*3-1 -:2*DW]};
                    act_pipe4 <= {i_mat_act[DW*3+:DW],act_pipe4[DW*4-1 -:3*DW]};
                end
            end
        end

        always@(posedge clk or negedge  rstn) begin
            if(!rstn|clear) begin        
                wei_pipe1 <= 0;
                wei_pipe2 <= 0;
                wei_pipe3 <= 0;
                wei_pipe4 <= 0;
            end
            else begin
                if(en) begin
                    wei_pipe1 <= i_mat_wei[DW*0+:DW];
                    wei_pipe2 <= {i_mat_wei[DW*1+:DW],wei_pipe2[DW*2-1 -:DW]};
                    wei_pipe3 <= {i_mat_wei[DW*2+:DW],wei_pipe3[DW*3-1 -:2*DW]};
                    wei_pipe4 <= {i_mat_wei[DW*3+:DW],wei_pipe4[DW*4-1 -:3*DW]};
                end
            end
        end
        
        assign o_act = {act_pipe4[DW-1:0],act_pipe3[DW-1:0],act_pipe2[DW-1:0],act_pipe1[DW-1:0]};
        assign o_wei = {wei_pipe4[DW-1:0],wei_pipe3[DW-1:0],wei_pipe2[DW-1:0],wei_pipe1[DW-1:0]};
    

endmodule
