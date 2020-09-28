`include "tools/def.v"

// 写回数据：都来自流水线（MEM）
module WBMicroDecorder(insType, RFWr, mux_WBData);
    input [5:0] insType;
    
    output reg RFWr;
    output reg mux_WBData;
    //output reg [1:0] mux_WBSel;

    always @(*) begin
        // 默认值，会根据下面的判断改动
        mux_WBData = `MUX_WBDATA_MEM;
        RFWr = 1'b0;

        if (insType >= `INS_RCAL_MIN && insType <= `INS_ICAL_MAX) begin
            // 写入值最终从MEM中取的类型
            if ((insType >= `INS_RCAL_MIN && insType <= `INS_SHIFT_MAX) || // R算术逻辑运算 & shift
                (insType >= `INS_LOAD_MIN && insType <= `INS_LOAD_MAX)  || // load
                (insType >= `INS_ICAL_MIN && insType <= `INS_ICAL_MAX))    // I算术逻辑运算
                RFWr = 1'b1;

            // 无条件跳转指令，要借助延迟队列
            else if (insType >= `INS_JUMP_MIN && insType <= `INS_JUMP_MAX) begin
                // jump类除了这两种类型之外，其他都不写寄存器，所以必须把RFWr放在case内部
                case (insType)
                    `INS_JALR: begin
                        RFWr = 1'b1;
                        mux_WBData = `MUX_WBDATA_LINKADDR; // 写入返回地址
                    end
                    `INS_JAL: begin
                        RFWr = 1'b1;
                        mux_WBData = `MUX_WBDATA_LINKADDR;
                    end
                endcase
            end
            
        end

    end
endmodule
