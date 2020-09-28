`include "tools/def.v"

/*****************************************************
 * 提取指令的摘要（指令类型+写回寄存器）形成微指令   *
 *****************************************************/

module microCoder(Op, funct, rt, rd,  // 输入，由译码器的时钟信号保证了稳定
                  microIns);          // 输出
    input [5:0] Op, funct;

    // 可能被写的三个位置
    input [4:0] rt, rd;
    wire  [4:0] ra = 5'd31;

    output reg [10:0] microIns;
    // 空指令（常量），空指令全0或者全x都太危险
    parameter NOP = {`INS_NOP, 5'bxxxxx};

    always @(*) begin
        // 处理微指令，微指令就是指令的种类+写入寄存器号编号
        case (Op)
            6'd0: begin  // R型指令
                case(funct)
                    // REGULAR
                    `FUNCT_ADD: microIns = {`INS_ADD, rd};
                    `FUNCT_ADDU: microIns = {`INS_ADDU, rd};
                    `FUNCT_SUB: microIns = {`INS_SUB, rd};
                    `FUNCT_SUBU: microIns = {`INS_SUBU, rd};
                    `FUNCT_AND: microIns = {`INS_AND, rd};
                    `FUNCT_OR: microIns = {`INS_OR, rd};
                    `FUNCT_XOR: microIns = {`INS_XOR, rd};
                    `FUNCT_NOR: microIns = {`INS_NOR, rd};
                    `FUNCT_SLT: microIns = {`INS_SLT, rd};
                    `FUNCT_SLTU: microIns = {`INS_SLTU, rd};
                    // SHIFT
                    `FUNCT_SLL: microIns = {`INS_SLL, rd};
                    `FUNCT_SLLV: microIns = {`INS_SLLV, rd};
                    `FUNCT_SRA: microIns = {`INS_SRA, rd};
                    `FUNCT_SRAV: microIns = {`INS_SRAV, rd};
                    `FUNCT_SRL: microIns = {`INS_SRL, rd};
                    `FUNCT_SRLV: microIns = {`INS_SRLV, rd};
                    // JUMP
                    `FUNCT_JR: microIns = {`INS_JR, 5'bxxxxx};
                    `FUNCT_JALR: microIns = {`INS_JALR, rd};
                    default: microIns = NOP;
                endcase
            end

            `OP_J: microIns = {`INS_J, 5'bxxxxx};
            `OP_JAL: microIns = {`INS_JAL, ra};

            default: begin // I型指令与无效指令
                case(Op)
                    // branch
                    `OP_BNE:  microIns = {`INS_BNE, 5'bxxxxx};
                    `OP_BLEZ: microIns = {`INS_BLEZ, 5'bxxxxx};
                    `OP_BGTZ: microIns = {`INS_BGTZ, 5'bxxxxx};
                    `OP_BEQ:  microIns = {`INS_BEQ, 5'bxxxxx};
                    `OP_BLTZ_BGEZ: begin
                        if (rt == 5'd1) microIns = {`INS_BGEZ, 5'bxxxxx};
                        else if (rt == 5'd0) microIns = {`INS_BLTZ, 5'bxxxxx};
                        else microIns = NOP; // 不能识别的指令
                    end
                    // 访存
                    `OP_LB:  microIns = {`INS_LB, rt};
                    `OP_LH:  microIns = {`INS_LH, rt};
                    `OP_LBU: microIns = {`INS_LBU, rt};
                    `OP_LHU: microIns = {`INS_LHU, rt};
                    `OP_LW:  microIns = {`INS_LW, rt};
                    `OP_SW:  microIns = {`INS_SW, 5'bxxxxx};
                    `OP_SH:  microIns = {`INS_SH, 5'bxxxxx};
                    `OP_SB:  microIns = {`INS_SB, 5'bxxxxx};
                    // I型运算
                    `OP_ADDI:  microIns = {`INS_ADDI, rt};
                    `OP_ORI:   microIns = {`INS_ORI, rt};
                    `OP_XORI:  microIns = {`INS_XORI, rt};
                    `OP_ADDIU: microIns = {`INS_ADDIU, rt};
                    `OP_ANDI:  microIns = {`INS_ANDI, rt};
                    `OP_LUI:   microIns = {`INS_LUI, rt};
                    `OP_SLTI:  microIns = {`INS_SLTI, rt};
                    `OP_SLTIU: microIns = {`INS_SLTIU, rt};
                    // 不能识别的指令
                    default: microIns = NOP; 
                endcase
            end
        endcase
    end
endmodule
