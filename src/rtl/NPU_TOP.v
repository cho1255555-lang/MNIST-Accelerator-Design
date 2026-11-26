`include "include.v"
module NPU_Top #(
    parameter DW = 8,
    parameter ADW = 32,
    parameter ROW = 4,
    parameter COL = 4
)(
    input clk,
    input rst_n,
    
    input start_inference,
    input [ROW*DW-1:0] input_pixels,
    input input_valid,
    output reg done_interrupt,
    //output [DW-1:0] result_class_0, //debug port 0~3
    //output [DW-1:0] result_class_1, 
    //output [DW-1:0] result_class_2,
    //output [DW-1:0] result_class_3,
    output [DW*4-1:0] result
);

    localparam IDLE = 0, CALC_L1 = 1, BUFFER_WR_L1 = 2, 
               CALC_L2 = 3, BUFFER_WR_L2 = 4,
               CALC_L3 = 5, BUFFER_WR_L3 = 6, 
               OUTPUT_SCAN = 7, DONE = 8;
    
    reg [3:0] state;

    reg [31:0] k_cnt;
    reg [31:0] group_cnt;
    reg [4:0]  write_seq_cnt; 
    
    reg [31:0] cur_layer_num;
    reg [31:0] cur_input_len;
    reg [31:0] cur_neuron_total;
     
    
    reg pe_rst, pe_en;
    reg calc_done;
    reg relu_bias_load;
    wire [ROW*COL*ADW-1:0] array_out;
    wire [ROW*DW-1:0] i_sa_act;
    wire [COL*DW-1:0] i_sa_wei;
    
    reg [COL*DW-1:0] sys_col_in;
    reg [ROW*DW-1:0] sys_row_in;
    
    wire [COL*DW-1:0] w_bank_out;
    wire [ROW*2*DW-1:0] b_bank_out; 
    
    reg buf_wen;
    reg [5:0] buf_w_addr;
    reg [ROW*DW-1:0] buf_w_data;
    wire [5:0] buf_r_addr;
    wire [ROW*DW-1:0] buf_r_data;
    wire [9:0] w_r_addr;
    
    

    wire [DW*ROW*COL-1:0] act_out_val;
    wire [2*DW*ROW*COL-1:0] debug_mul_00;

    wire [1:0] in_img_idx;
    wire [1:0] in_neu_idx;
    wire [4:0] delayed_seq_cnt;
    wire [1:0] wr_img_idx;
    wire [1:0] wr_neu_idx;
    wire [31:0] wr_global_neuron_idx; 

    

    assign in_img_idx = write_seq_cnt[3:2];
    assign in_neu_idx = write_seq_cnt[1:0];
    assign delayed_seq_cnt = write_seq_cnt - 1;
    assign wr_img_idx = delayed_seq_cnt[3:2];
    assign wr_neu_idx = delayed_seq_cnt[1:0];
    assign wr_global_neuron_idx = group_cnt * 4 + wr_neu_idx;

   
    

    // Read address logic
    assign buf_r_addr = (state==5)? k_cnt + 30:k_cnt;
    assign w_r_addr = (((state == 1) && (k_cnt < cur_input_len) )  ||
    (state == 3 && k_cnt < cur_input_len) ||
    (state == 5 && k_cnt < cur_input_len))? k_cnt : 0;

    //write address logic

    // --- Modules ---

    Weight_Bank #(.dataWidth(DW)) wb (
        .clk(clk), .layer_idx(cur_layer_num), .neuron_group(group_cnt), .w_addr(w_r_addr), .w_out_packed(w_bank_out)
    );
    
    Bias_Bank #(.dataWidth(DW)) bb ( 
        .clk(clk), .layer_idx(cur_layer_num), .neuron_group(group_cnt), .b_out_packed(b_bank_out)
    );
    
    pipes #(.DW(DW), .ROW(ROW), .COL(COL)) pi (
        .clk(clk),
        .rstn(rst_n),
        .clear(pe_rst),
        .en(pe_en),
        .i_mat_act(sys_row_in),
        .i_mat_wei(sys_col_in),
        .o_act(i_sa_act),
        .o_wei(i_sa_wei)
    );

    array #(.DW(DW), .ROW(ROW), .COL(COL), .ADW(ADW)) sa (  
        .clk(clk),
        .rstn(rst_n),
        .act(i_sa_act),  
        .wei(i_sa_wei),  
        .en(pe_en),
        .clear(pe_rst),
        .o_mul(debug_mul_00),
        .o_psum(array_out)
    );
    genvar i, j;
    generate
            for(i=0;i<ROW*COL;i=i+1) begin : relu_gen
                relu #(.DW(DW), .ADW(ADW)) u_relu ( 
                    .clk(clk),
                    .rstn(rst_n),
                    .clear(pe_rst),
                    .i_load(relu_bias_load),
                    .i_done(calc_done),
                    .i_psum(array_out[ADW*i +: ADW]),
                    .i_bias(b_bank_out[2*DW*(i%4) +: 2*DW]),
                    .o_data(act_out_val[DW*i +: DW]),
                    
                    .testvar1(clk),
                    .testvar2(clk)
                );
            end
    endgenerate

    
    Global_Buffer #(.DW(DW), .ROW(ROW), .COL(COL)) gb (
        .clk(clk), .wen(buf_wen), .w_addr(buf_w_addr), .w_data(buf_w_data),
        .r_addr(buf_r_addr), 
        .r_data(buf_r_data) 
    );
    
    // MaxFinder
    reg [10*DW-1:0] mf_in_data [3:0]; 
    reg mf_valid_pulse;
    wire [DW-1:0] mf_out [3:0];
    wire [3:0] mf_out_valid;
    
    

    

    
    

    genvar img;
    generate
        for(img=0; img<4; img=img+1) begin : MAX_FINDER_GEN
            maxFinder #(.numInput(10), .inputWidth(DW)) mf (
                .i_clk(clk), .i_rstn(rst_n), .i_data(mf_in_data[img]), .i_valid(mf_valid_pulse),
                .o_data(mf_out[img]), .o_data_valid(mf_out_valid[img])
            );
        end
    endgenerate

    assign result_class_0 = mf_out[0];
    assign result_class_1 = mf_out[1];
    assign result_class_2 = mf_out[2];
    assign result_class_3 = mf_out[3];
    assign result = {mf_out[3], mf_out[2],mf_out[1],mf_out[0]};

    // --- Control FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            k_cnt <= 0;
            group_cnt <= 0;
            write_seq_cnt <= 0;
            pe_rst <= 1;
            pe_en <= 0;
            calc_done <= 0;
            buf_wen <= 0;
            done_interrupt <= 0;
            mf_valid_pulse <= 0;
            sys_row_in <= 0;
            sys_col_in <= 0;
            relu_bias_load <= 0;
            cur_layer_num <=0;
            cur_input_len <=0;
            cur_neuron_total <=0;
            buf_w_addr <=0;
            buf_w_data <=0;
            mf_in_data[0] <=0;
            mf_in_data[1] <=0;
            mf_in_data[2] <=0;
            mf_in_data[3] <=0;
    
            
        end else begin
            buf_wen <= 0;
            
            case(state)
                IDLE: begin
                    done_interrupt <= 0;
                    mf_valid_pulse <= 0;
                    if(start_inference) begin
                        state <= CALC_L1;
                        cur_layer_num <= 1;
                        cur_input_len <= `numWeightLayer1; 
                        cur_neuron_total <= `numNeuronLayer1;  
                        k_cnt <= 0;
                        group_cnt <= 0;
                        pe_rst <= 1; 
                        sys_row_in <= 0;
                        sys_col_in <= 0;
                    end
                end
                
                CALC_L1: begin
                    
                    pe_rst <= 0;

                    if(k_cnt == 1) begin
                        relu_bias_load <= 1;
                    end
                    else begin
                        relu_bias_load <= 0;
                    end

                    if (k_cnt == 0) pe_en <= 0;
                    else if (k_cnt <= cur_input_len + ROW + 5) pe_en <= 1;
                    else pe_en <= 0;
                    
                    if(k_cnt >= cur_input_len) begin
                        sys_row_in <= 0;
                        sys_col_in <= 0;
                    end
                    else begin
                        sys_row_in <= input_pixels;
                        sys_col_in <= w_bank_out;
                    end

                    if (k_cnt == cur_input_len + ROW + 5 ) begin
                        pe_en <= 0;
                        calc_done <= 1;
                        state <= BUFFER_WR_L1;
                        write_seq_cnt <= 0;
                    end else begin
                        k_cnt <= k_cnt + 1;
                    end
                end
                
                BUFFER_WR_L1: begin
                    calc_done<=0;
                    if (write_seq_cnt > 0 && write_seq_cnt <= 4) begin
                        if (wr_global_neuron_idx < cur_neuron_total) begin 
                            // WRITE TO BUFFER 1
                            buf_wen <= 1;
                            buf_w_addr <= wr_global_neuron_idx;
                            buf_w_data <= {act_out_val[DW*ROW*3+DW*(write_seq_cnt-1) +:DW],
                            act_out_val[DW*ROW*2+DW*(write_seq_cnt-1) +:DW],
                            act_out_val[DW*ROW+DW*(write_seq_cnt-1) +:DW],
                            act_out_val[DW*(write_seq_cnt-1) +:DW] }; 
                        end
                    end

                    if (write_seq_cnt == 5) begin
                        if ((group_cnt + 1) * 4 >= cur_neuron_total) begin
                            state <= CALC_L2;
                            cur_layer_num <= 2;
                            cur_input_len <= `numNeuronLayer1; 
                            cur_neuron_total <= `numNeuronLayer2; 
                            group_cnt <= 0;
                            k_cnt <= 0;
                            pe_rst <= 1;
                        end else begin
                            state <= CALC_L1;
                            group_cnt <= group_cnt + 1;
                            k_cnt <= 0;
                            pe_rst <= 1;
                        end
                        write_seq_cnt <= 0;
                    end else begin
                        write_seq_cnt <= write_seq_cnt + 1;
                    end
                end
                
                CALC_L2: begin
                    pe_rst <= 0;

                    if(k_cnt == 1) begin
                        relu_bias_load <= 1;
                    end
                    else begin
                        relu_bias_load <= 0;
                    end
                    
                    if (k_cnt == 0) pe_en <= 0;
                    else if (k_cnt <= cur_input_len + ROW + 5) pe_en <= 1;
                    else pe_en <= 0;
                    
                    
                    if(k_cnt >= cur_input_len+1) begin
                        sys_row_in <= 0;
                        sys_col_in <= 0;
                    end
                    else begin
                        sys_row_in <= buf_r_data;
                        sys_col_in <= w_bank_out;
                    end

                    if (k_cnt == cur_input_len + ROW + 5) begin
                         state <= BUFFER_WR_L2;
                         pe_en <= 0;
                         calc_done <= 1;
                         write_seq_cnt <= 0;
                    end else begin
                        k_cnt <= k_cnt + 1;
                    end
                end

                BUFFER_WR_L2: begin
                    calc_done <= 0;
                    if (write_seq_cnt > 0 && write_seq_cnt <= 4) begin
                        if (wr_global_neuron_idx < cur_neuron_total) begin
                            buf_wen <= 1;
                            buf_w_addr <=  30 + wr_global_neuron_idx;  //buffer offset
                            buf_w_data <= {act_out_val[DW*ROW*3+DW*(write_seq_cnt-1) +:DW],
                            act_out_val[DW*ROW*2+DW*(write_seq_cnt-1) +:DW],
                            act_out_val[DW*ROW+DW*(write_seq_cnt-1) +:DW],
                            act_out_val[DW*(write_seq_cnt-1) +:DW] }; 
                        end
                    end

                    if (write_seq_cnt == 5) begin
                        if ((group_cnt + 1) * 4 >= cur_neuron_total) begin
                            state <= CALC_L3;
                            cur_layer_num <= 3;
                            cur_input_len <= `numNeuronLayer2; 
                            cur_neuron_total <= `numNeuronLayer3; 
                            group_cnt <= 0;
                            k_cnt <= 0;
                            pe_rst <= 1;
                        end else begin
                            state <= CALC_L2;
                            group_cnt <= group_cnt + 1;
                            k_cnt <= 0;
                            pe_rst <= 1;
                        end
                        write_seq_cnt <= 0;
                    end else begin
                        write_seq_cnt <= write_seq_cnt + 1;
                    end
                end

                CALC_L3: begin
                    pe_rst <= 0;

                    if(k_cnt == 1) begin
                        relu_bias_load <= 1;
                    end
                    else begin
                        relu_bias_load <= 0;
                    end
                    
                    if (k_cnt == 0) pe_en <= 0;
                    else if (k_cnt <= cur_input_len + ROW + 5) pe_en <= 1;
                    else pe_en <= 0;
                    
                    
                    if(k_cnt >= cur_input_len+1) begin
                        sys_row_in <= 0;
                        sys_col_in <= 0;
                    end
                    else begin
                        sys_row_in <= buf_r_data;
                        sys_col_in <= w_bank_out;
                    end

                    if (k_cnt == cur_input_len + ROW + 5) begin
                         state <= BUFFER_WR_L3;
                         pe_en <= 0;
                         calc_done <= 1;
                         write_seq_cnt <= 0;
                    end else begin
                        k_cnt <= k_cnt + 1;
                    end
                end
                
                BUFFER_WR_L3: begin
                    calc_done <= 0;
                    if (write_seq_cnt > 0 && write_seq_cnt <= 4) begin
                        if (wr_global_neuron_idx < cur_neuron_total) begin
                            buf_wen <= 1;
                            buf_w_addr <= wr_global_neuron_idx;
                            buf_w_data <= {act_out_val[DW*ROW*3+DW*(write_seq_cnt-1) +:DW],
                            act_out_val[DW*ROW*2+DW*(write_seq_cnt-1) +:DW],
                            act_out_val[DW*ROW+DW*(write_seq_cnt-1) +:DW],
                            act_out_val[DW*(write_seq_cnt-1) +:DW] }; 
                        end
                    end
                    
                    if (write_seq_cnt == 5) begin
                        if ((group_cnt + 1) * 4 >= cur_neuron_total) begin
                            state <= OUTPUT_SCAN;
                            k_cnt <= 0;
                        end else begin
                            state <= CALC_L3;
                            group_cnt <= group_cnt + 1;
                            k_cnt <= 0;
                            pe_rst <= 1;
                        end
                        write_seq_cnt <= 0;
                    end else begin
                        write_seq_cnt <= write_seq_cnt + 1;
                    end
                end
                
                //maxfind must change
                OUTPUT_SCAN: begin
                    if (k_cnt>=1 && k_cnt < 11) begin
                        mf_in_data[0][DW*(k_cnt-1) +: DW] <= buf_r_data[DW-1:0];
                        mf_in_data[1][DW*(k_cnt-1) +: DW] <= buf_r_data[2*DW-1:DW];
                        mf_in_data[2][DW*(k_cnt-1) +: DW] <= buf_r_data[3*DW-1:2*DW];
                        mf_in_data[3][DW*(k_cnt-1) +: DW] <= buf_r_data[4*DW-1:3*DW];
                    end
                    
                    if (k_cnt == 11) begin
                        mf_valid_pulse <= 1; // Start MaxFinder                        
                        //done_interrupt <= 1;
                        k_cnt <= k_cnt + 1;
                    end else if(k_cnt == 12) begin
                        mf_valid_pulse <= 0;
                    end                     
                    else begin
                        k_cnt <= k_cnt + 1;                        
                    end

                    if(mf_out_valid[0]) begin //image 1 done
                        state <= DONE;
                    end
                end
                
                DONE: begin
                   // Inference Complete
                   done_interrupt <= 1;
                   state <= IDLE;
                end
            endcase
        end
    end

   

endmodule