`include "def.v"
module data_ctrl (clk, Op, rs, rt, funct,    // clk只是为了内部寄存MEM阶段是否为load指令，无他用
                  EX_WBSel, MEM_WBSel,
                  mux_rsv, mux_rtv, stall);  // 输出
	
	// 2020.8.31 修复大量错误，但是还是有后续计算结果对前面的依赖现象

    // 需要自行计算的一些中间标志
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

    always @(posedge clk) begin
		// 如果有stall信号，阻止ID阶段的标志向后传播
		if (stall); else begin
			EX_is_load <= ID_is_load;
			EX_has_link <= ID_has_link;
		end
		// 往后寄存必要的信号
        MEM_is_load <= EX_is_load;
        MEM_has_link <= EX_has_link;
    end

    always @(*) begin
        // 分析一：判断EX阶段是否为load指令
        case (Op)
            `OP_LB, `OP_LH, `OP_LBU, `OP_LHU, `OP_LW: 	ID_is_load = 1'b1;
            default:									ID_is_load = 1'b0;
        endcase

        // 分析二：判断是否为jal或者jalr指令
        ID_has_link = (Op == 6'd0 && funct == `FUNCT_JALR) || Op == `OP_JAL;
		
        // 分析三：判断是否使用了rsv和rtv
		if (Op == 6'd0) begin
			case (funct)
                // rsv和rtv均要使用
                `FUNCT_ADD, `FUNCT_ADDU, `FUNCT_SUB, `FUNCT_SUBU, `FUNCT_AND, `FUNCT_OR, `FUNCT_XOR, 
                `FUNCT_NOR, `FUNCT_SLT, `FUNCT_SLTU, `FUNCT_SLLV, `FUNCT_SRAV, `FUNCT_SRLV: begin
                    use_rsv = 1;
                    use_rtv = 1;
                end
				// 只使用rtv
				`FUNCT_SLL, `FUNCT_SRA, `FUNCT_SRL: begin
                    use_rsv = 0;
                    use_rtv = 1;
				end
				// 只使用rsv
                `FUNCT_JR, `FUNCT_JALR: begin
                    use_rsv = 1;
                    use_rtv = 0;
                end
                default: begin
                    use_rsv = 0;
                    use_rtv = 0;
                end
            endcase
		end
		else begin
            case (Op)
                `OP_BNE, `OP_BEQ, `OP_SW, `OP_SH, `OP_SB: begin
                    use_rsv = 1;
                    use_rtv = 1;
                end
                `OP_BLEZ, `OP_BGTZ, `OP_BLTZ_BGEZ, `OP_LW, `OP_LH, `OP_LB, `OP_LBU, `OP_LHU,
                `OP_ADDI, `OP_ORI, `OP_XORI, `OP_ADDIU, `OP_ANDI, `OP_SLTI, `OP_SLTIU: begin
                    use_rsv = 1;
                    use_rtv = 0;
                end
                default: begin  // 无效指令，不需要用到rsv和rtv的指令
                    use_rsv = 0;
                    use_rtv = 0;
                end
            endcase
		end

        // 计算一：rsv的选择信号
        if (use_rsv && rs != 5'd0) begin
            if (EX_WBSel == rs)
                mux_rsv = EX_has_link ? `REG_VALUE_PCPLUS4_2 : `REG_VALUE_ALU;
            else if (MEM_WBSel == rs) begin
                if      (MEM_is_load)  mux_rsv = `REG_VALUE_MEM;
                else if (MEM_has_link) mux_rsv = `REG_VALUE_PCPLUS4_3;
                else                   mux_rsv = `REG_VALUE_ALUREG;
            end
            else mux_rsv = `REG_VALUE_RF;
        end
        else mux_rsv = `REG_VALUE_RF;

        // 计算二：rtv的选择信号
        if (use_rtv && rt != 5'd0) begin
            if (EX_WBSel == rt)
                mux_rtv = EX_has_link ? `REG_VALUE_PCPLUS4_2 : `REG_VALUE_ALU;
            else if (MEM_WBSel == rt) begin
                if      (MEM_is_load)  mux_rtv = `REG_VALUE_MEM;
                else if (MEM_has_link) mux_rtv = `REG_VALUE_PCPLUS4_3;
                else                   mux_rtv = `REG_VALUE_ALUREG;
            end
            else mux_rtv = `REG_VALUE_RF;
        end
        else mux_rtv = `REG_VALUE_RF;

        // 计算三：如果stall信号发出，那么上面的mux选择信号随意
        stall = EX_is_load && (use_rsv && rs != 5'd0 && EX_WBSel == rs || use_rtv && rt != 5'd0 && EX_WBSel == rt);
    end

endmodule