`include "../tools/def.v"
module data_hazard_detector(clk, Op, rs, rt, funct,    // clk只是为了内部寄存MEM阶段是否为load指令，无他用
                            EX_WBSel, MEM_WBSel,
                            mux_rsv, mux_rtv, stall);  // 输出

    // 需要自行计算
    reg     use_rsv, use_rtv;
    reg     ID_is_load, EX_is_load, MEM_is_load;
    reg     ID_has_link, EX_has_link, MEM_has_link;    // has link指的是jal和jalr的指令
    initial {use_rsv, use_rtv, ID_is_load} <= 3'd0;

    input  [4:0] rs, rt;
    input  [5:0] Op, funct;
    input        clk;                 // 时钟信号，对于寄存信号有用
    
    input  [4:0] EX_WBSel, MEM_WBSel; // EX阶段指令待写寄存器，MEM阶段指令待写寄存器
    output reg stall;
    output reg [2:0] mux_rsv, mux_rtv;

    /* 关于信号被存储了两级，本来只用存储一级到MEM阶段的，
       但是因为MEM阶段的mux选择信号是没有时钟的组合单元，
       因此就需要帮助这个单元寄存信息 */
    always @(posedge clk) begin
        EX_is_load <= ID_is_load;
        MEM_is_load <= EX_is_load;
        EX_has_link <= ID_has_link;
        MEM_has_link <= EX_has_link;
    end

    always @(*) begin
        // 判断EX阶段是否为load指令
        case (Op)
            `OP_LB, `OP_LH, `OP_LBU, `OP_LHU, `OP_LW:
                ID_is_load = 1'b1;
            default:
                ID_is_load = 1'b0;
        endcase
        // 判断是否为jal或者jalr指令
        ID_has_link = (Op == 6'd0 && funct == `FUNCT_JALR || Op == `OP_JAL);
        // 判断是否使用了rsv和rtv，方便下面分析
        case (Op)
            6'd0: begin
                case (funct)
                    `FUNCT_ADD, `FUNCT_ADDU, `FUNCT_SUB, `FUNCT_SUBU, `FUNCT_AND, `FUNCT_OR, `FUNCT_XOR, `FUNCT_NOR, `FUNCT_SLT, `FUNCT_SLTU: begin
                        use_rsv = 1'b1;
                        use_rtv = 1'b1;
                    end
                    `FUNCT_SLL, `FUNCT_SLLV, `FUNCT_SRA, `FUNCT_SRAV, `FUNCT_SRL, `FUNCT_SRLV: begin
                        use_rsv = (funct == `FUNCT_SLL || funct == `FUNCT_SRA || funct == `FUNCT_SRL) ? 1'b0 : 1'b1;
                        use_rtv = 1'b1;
                    end
                    `FUNCT_JR, `FUNCT_JALR: begin
                        use_rsv = 1'b1;
                        use_rtv = 1'b0;
                    end
                    default: begin
                        use_rsv = 1'b0;
                        use_rtv = 1'b0;
                    end
                endcase
            end

            `OP_J, `OP_JAL: begin
                use_rsv = 1'b0;
                use_rtv = 1'b1;
            end

            // I型指令与无效指令
            default: begin
                case (Op)
                    `OP_BNE, `OP_BLEZ, `OP_BGTZ, `OP_BLTZ_BGEZ, `OP_BEQ,
                    `OP_LW, `OP_SW, `OP_LH, `OP_LB, `OP_LBU, `OP_LHU, `OP_SB, `OP_SH: begin
                        use_rsv = 1'b1;
                        case (Op)
                            `OP_BNE, `OP_BEQ, `OP_SW, `OP_SH, `OP_SB: 	use_rtv = 1'b1;
                            default: 									use_rtv = 1'b0;
                        endcase
                    end
                    
                    `OP_ADDI, `OP_ORI, `OP_XORI, `OP_ADDIU, `OP_ANDI, `OP_LUI, `OP_SLTI, `OP_SLTIU: begin
                        use_rsv = (Op == `OP_LUI) ? 1'b0 : 1'b1;
                        use_rtv = 1'b0;
                    end

                    /* 无效的指令 */
                    default: begin
                        use_rsv = 1'b0;
                        use_rtv = 1'b0;
                    end
                endcase
            end
        endcase

        // 计算rsv的选择信号
        if (use_rsv == 1'b1 && rs != 5'd0) begin
            if (EX_WBSel == rs)
                mux_rsv = EX_has_link ? `REG_VALUE_PCPLUS4_2 : `REG_VALUE_ALU;
            else if (MEM_WBSel == rs)
            // ALUREG指的是还是取ALU的值，不过是寄存了的结果而已，因为ALU还会出结果，不寄存结果就会被刷掉
                mux_rsv = MEM_is_load  ? `REG_VALUE_MEM : 
                          MEM_has_link ? `REG_VALUE_PCPLUS4_3 : 
                                         `REG_VALUE_ALUREG;
            else mux_rsv = `REG_VALUE_RF;
        end
        else mux_rsv = `REG_VALUE_RF;

        // 计算rtv的选择信号
        if (use_rtv == 1'b1 && rt != 5'd0) begin
            if (EX_WBSel == rt)
                mux_rtv = EX_has_link ? `REG_VALUE_PCPLUS4_2 : `REG_VALUE_ALU;
            else if (MEM_WBSel == rt)
                mux_rtv = MEM_is_load  ? `REG_VALUE_MEM : 
                          MEM_has_link ? `REG_VALUE_PCPLUS4_3 : 
                                         `REG_VALUE_ALUREG; 
            else mux_rtv = `REG_VALUE_RF;
        end
        else mux_rtv = `REG_VALUE_RF;

        // stall放到外面来处理了，如果stall信号发出，那么上面的mux选择信号可以是不对的
        stall = (use_rsv == 1'b1 && rs != 5'd0 && EX_WBSel == rs || 
                    use_rtv == 1'b1 && rt != 5'd0 && EX_WBSel == rt) && 
                (EX_is_load == 1'b1);
    end

endmodule