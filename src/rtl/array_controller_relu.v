
`define pretrained
`define BIASFILE  "./BIASFILE.txt"

module array_controller_relu#(
    parameter DW = 8,
    parameter ROW = 2,
    parameter COL = 2,
    parameter ADW = 32

    

)(
    input clk,
    input rstn,
    
    //data interface
    input [DW*ROW*COL-1:0] i_mat_act,
    input [DW*ROW*COL-1:0] i_mat_wei,
    output [ADW*ROW*COL-1:0] o_mat_acc,

    //control interface
    input i_start,
    output o_busy,
    output o_done,

    //bias interface
    input [ADW*ROW*COL-1:0] i_bias    
);
    localparam IDLE = 2'b00;
    localparam RUN = 2'b01;
    localparam DONE = 2'b10;
    localparam CALC_CYCLES = (ROW>COL)?3*ROW+2:3*COL+2; //max size, +2 margin
    localparam M_DIM = (ROW>COL)?ROW:COL; //Major Dimension

    wire array_en;
    wire acc_clear;
    wire [DW*ROW-1:0] i_act;
    wire [DW*COL-1:0] i_wei; 
    wire [ADW*ROW*COL-1:0] o_array;
    wire [ROW*COL-1:0] relu_en;

     
    reg [1:0] c_state; 
    reg [1:0] n_state;
    reg [7:0] cnt;
    reg [DW*ROW*COL-1:0] latched_act;
    reg [DW*ROW*COL-1:0] latched_wei;
    reg [ADW*ROW*COL-1:0] r_relu;

    reg [ADW-1:0] BiasReg [0:ROW*COL-1];
    reg [ADW*ROW*COL-1:0] r_bias;

    integer i,j;
    
         array #(
    .DW(DW),
    .ROW(ROW),
    .COL(COL),
    .ADW(ADW) 
    )a1(  
    .clk(clk),
    .rstn(rstn),
    .act(i_act),  
    .wei(i_wei),  
    .en(array_en),
    .clear(acc_clear),
    
    .o_mul(),//only debug
    .o_psum(o_array)
    );
    

//-------------------------------------------------------
//                      control
//-------------------------------------------------------    

    always@(posedge clk or negedge rstn) begin
        if(!rstn) begin
            c_state <= 0;
            cnt <= 0;
        end
        else begin
            c_state <= n_state;
            if(n_state == RUN) begin
                cnt <= cnt+1;
            end
            else begin
                cnt <=0;
            end
        end
    end


    always@(*) begin
        case(c_state)
            IDLE : begin if(i_start) n_state = RUN; else n_state = IDLE; end
            RUN : begin if(cnt>=CALC_CYCLES) n_state = DONE; else n_state = RUN; end
            DONE : begin if(!i_start) n_state = IDLE; else n_state = DONE; end
            default : n_state = c_state;
        endcase
    end

    assign o_busy = (c_state==RUN);
    assign array_en = (c_state==RUN);
    assign o_done = (c_state==DONE);
    assign acc_clear = (c_state==DONE);

 
//-------------------------------------------------------
//                      data
//-------------------------------------------------------

    

    always@(posedge clk or rstn) begin
        if(!rstn) begin
            
            latched_act <= 0;
            latched_wei <= 0;
        end
        else begin
            latched_act <= i_mat_act;
            latched_wei <= i_mat_wei;
        end
    end

    genvar gi, gj;
    generate
        for(gi=0;gi<ROW;gi=gi+1) begin : act_data_skew
            assign i_act[gi*DW+:DW] = (array_en)?
            (cnt-gi-1>=0&&cnt-gi-1<M_DIM)?
            latched_act[(ROW*gi+(cnt-gi-1))*DW+:DW]:0:0; //cnt offset +1
        end
    endgenerate

    generate
        for(gi=0;gi<COL;gi=gi+1) begin : wei_data_skew
            assign i_wei[gi*DW+:DW] = (array_en)?
            (cnt-gi-1>=0&&cnt-gi-1<M_DIM)?
            latched_wei[(COL*(cnt-gi-1)+gi)*DW+:DW]:0:0;
        end
    endgenerate
//-------------------------------------------------------
//                      ReLU
//-------------------------------------------------------

        `ifdef pretrained
            initial begin
                $readmemb(`BIASFILE,BiasReg);
            end
           always @(posedge clk) begin
                for(i=0;i<ROW;i=i+1) begin
                    for(j=0;j<COL;j=j+1) begin
                    r_bias[(i*ROW+j)*ADW +:ADW] <= BiasReg[i*ROW+j];
                    end
                end    
            end
        `else
        // send bias from AXI BUS
	    `endif
    generate    
        for(gi=0;gi<ROW;gi=gi+1) begin : for_relu1
            for(gj=0;gj<COL;gj=gj+1) begin : for_relu2
                ex_relu #(.ADW(ADW)
                )relu_func(
                    .clk(clk),
                    .rstn(rstn),
                    .i_start(i_start),
                    .i_done(o_done),
                    .i_psum(o_array[(gi*ROW+gj)*ADW +: ADW]),
                    .i_bias(r_bias[(gi*ROW+gj)*ADW +: ADW]),
                    .o_data(o_mat_acc[(gi*ROW+gj)*ADW +: ADW])
                );
            end
        end
    endgenerate


/*        
    //relu function
    always@(posedge clk or negedge rstn) begin
        if(!rstn) begin
            r_relu <= 0;                       
        end
        else if(i_start) begin
                    r_relu <= r_bias; //presum bias 
        end
        else begin
            if(c_state == DONE) begin
                for(i=0;i<ROW;i=i+1) begin
                    for(j=0;j<COL;j=j+1) begin
                        if(relu_en[i*ROW+j]) begin
                            r_relu[(i*ROW+j)*ADW +: ADW] <= $signed(o_array[(i*ROW+j)*ADW +: ADW]) 
                            + $signed(r_bias[(i*ROW+j)*ADW +: ADW]); //presum bias 
                        end
                        else begin
                            r_relu[(i*ROW+j)*ADW +: ADW] <= 0;
                        end
                    end
                end
            end
        end
    end

    //relu_en gen
    generate
        for(gi=0;gi<ROW;gi=gi+1) begin : relu_en_1
            for(gj=0;gj<ROW;gj=gj+1) begin : relu_en_2
                assign relu_en[gi*ROW+gj]=(c_state==DONE)?
                ($signed(o_array[(gi*ROW+gj)*ADW +:ADW])+$signed(r_bias[(gi*ROW+gj)*ADW +:ADW])<0)?
                0:1'b1:0;
            end
        end
    endgenerate

    assign o_mat_acc = r_relu;
    */

    

endmodule