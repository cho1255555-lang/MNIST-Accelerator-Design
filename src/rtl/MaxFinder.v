module maxFinder #(parameter numInput=10,parameter inputWidth=16)(
    input           i_clk,
    input           i_rstn,
    input [(numInput*inputWidth)-1:0]   i_data,
    input           i_valid,
    output reg [31:0]o_data,
    output  reg     o_data_valid
);

    reg [inputWidth-1:0] maxValue;
    reg [(numInput*inputWidth)-1:0] inDataBuffer;
    reg [3:0] counter; //integer -> reg 
    reg en;

    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            o_data <= 0;
            o_data_valid <= 0;
            maxValue <= 0;
            inDataBuffer <= 0;
            counter <=0;
            en <=0;
        end
        else begin
                if(i_valid) begin
                    inDataBuffer <= i_data;
                    en <= 1'b1;
                end
                
                if(en) begin
                    if(counter == numInput) begin
                        o_data_valid <= 1'b1;
                        en <=0;
                    end
                    else if(counter != 10) begin
                        counter <= counter + 1;
                        if(inDataBuffer[counter*inputWidth+:inputWidth] > maxValue)
                        begin
                            maxValue <= inDataBuffer[counter*inputWidth+:inputWidth];
                            o_data <= counter;
                        end
                    end
                end
            
        end
    end

endmodule
