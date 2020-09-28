`include "../tools/def.v"

/* 这个模块只是输出如果是branch指令，那么是否采取branch分支
 * 对该条指令是否为分支指令的严密的判断逻辑放在了jump_ctrl模块当中
 */
module ID_branch_checker(rsv, rtv, Op, rt,     // 输入
                        branch_taken);         // 输出

    input signed [31:0] rsv, rtv;
    input [5:0] Op;
    input [4:0] rt;

    output reg branch_taken;

    always @(*) begin
        case (Op) 
            `OP_BNE:  branch_taken = (rsv != rtv) ? 1'b1 : 1'b0;
            `OP_BEQ:  branch_taken = (rsv == rtv) ? 1'b1 : 1'b0;
            `OP_BLEZ: branch_taken = (rsv <= 0)   ? 1'b1 : 1'b0;
            `OP_BGTZ: branch_taken = (rsv > 0)    ? 1'b1 : 1'b0;
            `OP_BLTZ_BGEZ:  begin
                if (rt == 5'd1)
                    branch_taken = (rsv >= 0) ? 1'b1 : 1'b0;
                else if (rt == 5'd0)
                    branch_taken = (rsv < 0) ? 1'b1 : 1'b0;
                else // undefined
                    branch_taken = 1'b0;
            end
            default: branch_taken = 1'b0; // 其他情况未定义
        endcase
    end

endmodule