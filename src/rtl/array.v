module array #(
    parameter DW  = 8,
    parameter ROW = 2,
    parameter COL = 2,
    parameter ADW = 32
)(  
    input clk,
    input rstn,
    input  [DW*ROW-1:0] act,  
    input  [DW*COL-1:0] wei,  
    input en,
    input clear,
    
    output [DW*2*ROW*COL-1:0] o_mul,
    output [ADW*ROW*COL-1:0] o_psum
);


    reg  [DW-1:0]  d_act [0:ROW-1][0:COL-1];
    reg  [DW-1:0]  d_wei [0:ROW-1][0:COL-1];
    reg  [ADW-1:0] d_psum[0:ROW-1][0:COL-1];

    wire  [ADW-1:0]  psum [0:ROW-1][0:COL-1];
    wire  [DW*2-1:0] mul  [0:ROW-1][0:COL-1];
    wire  [ADW:0]    full_sum [0:ROW-1][0:COL-1]; //ovf logic extensible if no ovf logic delete it

    integer i, j;
  
    always@(posedge clk or negedge rstn) begin
        if(!rstn) begin
            for(i=0; i<ROW;i=i+1) begin
                for(j=0; j<COL;j=j+1) begin
                    d_act[i][j] <= 0;                    
                end
            end
        end else begin
            if(en) begin                
                for(i=0;i<ROW;i=i+1) begin
                    d_act[i][0] <= act[DW*i+:DW];
                    for(j=0;j<COL-1;j=j+1) begin
                        d_act[i][j+1] <= d_act[i][j];
                    end
                end
            end 
        end
    end

    always@(posedge clk or negedge rstn) begin
        if(!rstn) begin
            for(i=0; i<ROW;i=i+1) begin
                for(j=0; j<COL;j=j+1) begin                    
                    d_wei[i][j] <= 0;            
                end
            end
        end else begin
            if(en) begin
                for(i=0;i<COL;i=i+1) begin
                    d_wei[0][i]<= wei[DW*i+:DW];
                    for(j=0;j<ROW-1;j=j+1) begin                        
                        d_wei[j+1][i]<= d_wei[j][i];                        
                    end
                end
            end 
        end
    end
    
    always@(posedge clk or negedge rstn) begin
        if(!rstn|clear) begin
            for(i=0; i<ROW;i=i+1) begin
                for(j=0; j<COL;j=j+1) begin
                    d_psum[i][j] <= 0;
                end
            end
        end else begin
            if(en) begin
                for(i=0;i<ROW;i=i+1) begin
                    for(j=0;j<COL;j=j+1) begin
                        d_psum[i][j] <= psum[i][j];
                    end
                end
            end 
        end
    end


   genvar gi, gj;
    generate
        for(gi=0; gi<ROW; gi=gi+1) begin : forigen
            for(gj=0; gj<COL; gj=gj+1) begin : forjgen
                assign mul[gi][gj] = $signed(d_act[gi][gj]) * $signed(d_wei[gi][gj]);        
                assign full_sum[gi][gj] = $signed(mul[gi][gj]) + $signed(d_psum[gi][gj]);
                assign psum[gi][gj] = full_sum[gi][gj];
                assign o_mul[((gi*COL + gj)*(DW*2)) +: (DW*2)] = mul[gi][gj];
                assign o_psum[((gi*COL + gj)*ADW) +: ADW] = d_psum[gi][gj];
            end         
        end
    endgenerate



endmodule