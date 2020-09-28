`include "tools/def.v"

// 将memScaleOp改成MEMOp
// 用MEMOp最大（2'b11）表示转发操作，这样就能够不引入新的信号位
// mem必定要转发alu的结果，但是alu的转发目前为止还没有用到（2020.5.22）

// 根据stall信号在store块中决定写信号
module MEMMicroDecorder(EX_insType, MEMWr, MEMOp, loadSignExt);
    input [5:0] EX_insType;
    output reg MEMWr, loadSignExt;
    output reg [1:0] MEMOp;

    always @(*) begin
        // 默认值
        loadSignExt = 1'b0; // 默认无符号扩展
        MEMOp = 2'b11;      // 默认开启ALU转发
        MEMWr = 1'b0;       // 默认不写
        // load
        if (EX_insType >= `INS_LOAD_MIN && EX_insType <= `INS_LOAD_MAX) begin
            case (EX_insType)
                `INS_LB: begin
                    MEMOp = 2'b00;
                    loadSignExt = 1'b1;
                end
                `INS_LH: begin
                    MEMOp = 2'b01;
                    loadSignExt = 1'b1;
                end
                `INS_LBU: MEMOp = 2'b00;
                `INS_LHU: MEMOp = 2'b01;
                `INS_LW:  MEMOp = 2'b10;
            endcase
        end
        // store
        else if (EX_insType >= `INS_STORE_MIN && EX_insType <= `INS_STORE_MAX) begin
            MEMWr = 1'b1;
            // loadSignExt default 1'b0
            case (EX_insType)
                `INS_SW: MEMOp = 2'b10;
                `INS_SH: MEMOp = 2'b01;
                `INS_SB: MEMOp = 2'b00;
            endcase
        end
        // 对于不能识别的微指令或者能够识别的、但是不访存的，则使用上面的默认数据
        // 没有else了
    end
endmodule