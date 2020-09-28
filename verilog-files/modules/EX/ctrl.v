`include "../tools/def.v"

// 中央控制单元
/* 2020.8.30 因为自己里面有寄存器，所以现在EX阶段的是保证了正常的，只需要寄存一下后续阶段的 */
/* 2020.8.30 为了能让ALU的输入被寄存起来，然后把ALU改成非组合单元，保证其输出的稳定，
	需要提前输出mux选择信号，因此，ALU的mux信号是在ID阶段就算好输出了，在EX阶段的clk结束之后就会改变*/
	
module ctrl(clk, stall,                  // stall一定要阻塞ctrl继续分发信号才行
            Op_in, funct_in, rt_in, rd_in,             // 输入
            signExt, ALUOp, ALU_mux1, ALU_mux2,        // EX阶段信号
            MEMWr, MEMOp, loadSignExt,                 // MEM阶段信号
            WBSel, RFWr, mux_WBData                    // WB阶段信号
            );      
    
    input       clk, stall;
    input [5:0] Op_in, funct_in;
    input [4:0] rt_in, rd_in;

    /* 把用来分析的信号寄存下来 */
    reg [5:0] Op, funct;
    reg [4:0] rt, rd;
    always @(posedge clk) begin
        if (stall) begin // stall的时候要把这个信号全部清空，并把前面塞住
                         // 这样ID阶段的指令不会进入EX阶段
            Op    <= 6'd0;
            funct <= 6'd0;
            rt    <= 5'd0;
            rd    <= 5'd0;
        end
        else begin
            Op    <= Op_in;
            funct <= funct_in;
            rt    <= rt_in;
            rd    <= rd_in;
        end
    end

    // EX阶段
    output reg       signExt;       // 立即数的扩展方式，在I型指令中有用，1表示有符号扩展
    output reg [4:0] ALUOp;         // ALU操作信号
    output reg       ALU_mux1;      // 在ALU之前进行选择操作，无转发，只需要一位信号
    output reg       ALU_mux2;    
    // MEM阶段，现在的新结构其实只有写回阶段的信号是需要多寄存一个周期的
    output reg       MEMWr;         // 控制是否写MEM的信号
    output reg [1:0] MEMOp;         // 控制内存操作的范围，只有在访存过程中是有有意义的
    output reg       loadSignExt;   // load的扩展方式 
    // 写回阶段
    output reg [4:0] WBSel;         
    output reg       RFWr;          // 寄存器写信号
    output reg [1:0] mux_WBData;

    always @(*) begin
        case (Op)
            6'd0: begin // R型指令
                MEMWr = 1'b0;
                MEMOp = `MEMOP_WORD; // prevent latch
                loadSignExt = 1'b1;  // prevent latch
                case(funct)
                    // 非移位算术类型
                    `FUNCT_ADD, `FUNCT_ADDU, `FUNCT_SUB, `FUNCT_SUBU, `FUNCT_AND, 
					`FUNCT_OR, `FUNCT_XOR, `FUNCT_NOR, `FUNCT_SLT, `FUNCT_SLTU: begin
                        WBSel  = rd;
                        RFWr = 1'b1;
                        mux_WBData = `WBDATA_ALU;
                    end
                    
                    // 移位类型
                    `FUNCT_SLL, `FUNCT_SLLV, `FUNCT_SRA, `FUNCT_SRAV, `FUNCT_SRL, `FUNCT_SRLV: begin
                        WBSel = rd;
                        RFWr = 1'b1;
                        mux_WBData = `WBDATA_ALU;
                    end

                    `FUNCT_JR: begin 
                        WBSel = `WBSEL_NOP;
                        RFWr = 1'b0;
                        mux_WBData = `WBDATA_ALU;   // prevent latch
                    end

                    `FUNCT_JALR: begin
                        WBSel = rd;
                        RFWr = 1'b1;
                        mux_WBData = `WBDATA_PCPLUS4;
                    end

                    default: begin
                        WBSel = `WBSEL_NOP;
                        RFWr = 1'b0;
                        mux_WBData = `WBDATA_ALU;   // prevent latch
                    end
                endcase
            end

            `OP_J: begin   // j指令，读什么寄存器不重要了，ALU不需要信号
                MEMWr = 1'b0;
                WBSel = `WBSEL_NOP;
                RFWr = 1'b0;
                MEMOp = `MEMOP_WORD;        // prevent latch
                loadSignExt = 1'b1;         // prevent latch
                mux_WBData = `WBDATA_ALU;   // prevent latch
            end

            `OP_JAL: begin // jal指令 
                MEMWr = 1'b0;
                WBSel  = `WBSEL_RA;     // 专用寄存器存放上一个PC地址
                RFWr = 1'b1;
                mux_WBData = `WBDATA_PCPLUS4;
                MEMOp = `MEMOP_WORD;        // prevent latch
                loadSignExt = 1'b1;         // prevent latch
            end

            default: begin // I型指令与无效指令
                case(Op)
                    // 分支，虽然还是在做运算但是其实没有任何作用，因为分支的评估被提前了，ALUOp在这里无效
                    `OP_BNE, `OP_BLEZ, `OP_BGTZ, `OP_BLTZ_BGEZ, `OP_BEQ: begin
                        MEMWr = 1'b0;
                        WBSel = `WBSEL_NOP;
                        RFWr = 1'b0;
                        MEMOp = `MEMOP_WORD;        // prevent latch
                        loadSignExt = 1'b1;         // prevent latch
                        mux_WBData = `WBDATA_ALU;   // prevent latch
                    end
                    // 访存
                    `OP_LW, `OP_SW, `OP_LH, `OP_LB, `OP_LBU, `OP_LHU, `OP_SB, `OP_SH: begin
                        mux_WBData = `WBDATA_MEM;
                        case(Op)
                            `OP_LB, `OP_LH, `OP_LBU, `OP_LHU, `OP_LW: begin // load
                                WBSel = rt;
                                RFWr = 1'b1;
                                MEMWr = 1'b0;
                                case(Op)
                                    `OP_LB:  begin 
                                        MEMOp = `MEMOP_BYTE;
                                        loadSignExt = 1'b1;
                                    end
                                    `OP_LH:  begin 
                                        MEMOp = `MEMOP_HALFWORD;
                                        loadSignExt = 1'b1;
                                    end
                                    `OP_LBU: begin 
                                        MEMOp = `MEMOP_BYTE;
                                        loadSignExt = 1'b0;
                                    end
                                    `OP_LHU: begin 
                                        MEMOp = `MEMOP_HALFWORD;
                                        loadSignExt = 1'b0;
                                    end
                                    // default也就是LW指令
                                    default: begin
                                        MEMOp = `MEMOP_WORD; // 扩展方式对32位load来说不重要
                                        loadSignExt = 1'b0;
                                    end
                                endcase
                            end

                            default: begin     // store
                                loadSignExt = 1'b1;               // prevent latch
                                WBSel = `WBSEL_NOP;
                                RFWr = 1'b0;
                                MEMWr = 1'b1;  // 写内存信号
                                case(Op)
                                    `OP_SW:  MEMOp = `MEMOP_WORD;
                                    `OP_SH:  MEMOp = `MEMOP_HALFWORD;
                                    `OP_SB:  MEMOp = `MEMOP_BYTE;
                                    default: MEMOp = `MEMOP_WORD; // prevent latch
                                endcase
                            end

                        endcase
                    end
                    // I型运算，`OP_ADDI, `OP_ORI, `OP_XORI, `OP_ADDIU, `OP_ANDI, `OP_LUI, `OP_SLTI, `OP_SLTIU
                    default: begin
                        MEMOp = `MEMOP_WORD;        // prevent latch
                        WBSel = rt;
                        RFWr = 1'b1;
                        MEMWr = 1'b0;
                        loadSignExt = 1'b1;         // prevent latch
                        mux_WBData = `WBDATA_ALU;   // prevent latch
                    end
                endcase
            end
        endcase
	
		// 再来一个Op单独选择和EX相关的信号，保证给ALU加上时钟之后结果依然是正确的
		case (Op_in)
			// R型指令
			6'd0: begin
				signExt = 1'b1;      // eliminate latch
				case(funct_in)
					// R型算术类型 
					`FUNCT_ADD, `FUNCT_ADDU, `FUNCT_SUB, `FUNCT_SUBU, `FUNCT_AND, 
					`FUNCT_OR, `FUNCT_XOR, `FUNCT_NOR, `FUNCT_SLT, `FUNCT_SLTU: begin
						ALU_mux1 = `ALU_INPUT1_RSV;       
                        ALU_mux2 = `ALU_INPUT2_RTV;
						case(funct_in)
                            `FUNCT_ADD:  ALUOp = `ALU_ADD;  //add
                            `FUNCT_ADDU: ALUOp = `ALU_ADDU; //addu
                            `FUNCT_SUB:  ALUOp = `ALU_SUB;  //sub
                            `FUNCT_SUBU: ALUOp = `ALU_SUBU; //subu
                            `FUNCT_AND:  ALUOp = `ALU_AND;  //and
                            `FUNCT_OR:   ALUOp = `ALU_OR;   //or
                            `FUNCT_XOR:  ALUOp = `ALU_XOR;  //xor
                            `FUNCT_NOR:  ALUOp = `ALU_NOR;  //nor
                            `FUNCT_SLT:  ALUOp = `ALU_SLT;  //slt
                            `FUNCT_SLTU: ALUOp = `ALU_SLTU; //sltu
                            default:     ALUOp = `ALU_NOP;
                        endcase
					end
					
					// 移位类型
                    `FUNCT_SLL, `FUNCT_SLLV, `FUNCT_SRA, `FUNCT_SRAV, `FUNCT_SRL, `FUNCT_SRLV: begin
						ALU_mux2 = `ALU_INPUT2_RTV;
						// 选择ALU的第一个输入的mux信号
						case(funct_in)
                            `FUNCT_SLL, `FUNCT_SRA, `FUNCT_SRL: ALU_mux1 = `ALU_INPUT1_SHAMT;
                            default: 							ALU_mux1 = `ALU_INPUT1_RSV;
                        endcase
						// 选择ALU的移位运算方式
						case(funct_in) 
                            `FUNCT_SLL, `FUNCT_SLLV: ALUOp = `ALU_SLL;
                            `FUNCT_SRA, `FUNCT_SRAV: ALUOp = `ALU_SRA;
                            default:                 ALUOp = `ALU_SRL;
                        endcase
					end
					
					// 其他没有考虑的类型、JR类型、JALR类型
					default: begin
						ALUOp = `ALU_NOP;           // prevent latch
                        ALU_mux1 = `ALU_INPUT1_RSV; // prevent latch
                        ALU_mux2 = `ALU_INPUT2_RTV; // prevent latch
					end
					
				endcase
			end
			
			`OP_J, `OP_JAL: begin
				signExt = 1'b1;             // prevent latch
                ALUOp = `ALU_NOP;           // prevent latch
                ALU_mux1 = `ALU_INPUT1_RSV; // prevent latch
                ALU_mux2 = `ALU_INPUT2_RTV; // prevent latch
			end
			
			// 无效指令与I型指令
			default: begin
				ALU_mux1 = `ALU_INPUT1_RSV;
				case (Op_in)
					`OP_BNE, `OP_BLEZ, `OP_BGTZ, `OP_BLTZ_BGEZ, `OP_BEQ: begin
						signExt = 1'b0;             // eliminate latch
						ALU_mux2 = `ALU_INPUT2_RTV;
						// 选择ALUOp
						case(Op_in)
                            `OP_BNE:  ALUOp = `ALU_BNE;
                            `OP_BEQ:  ALUOp = `ALU_BEQ;
                            `OP_BLEZ: ALUOp = `ALU_BLEZ;
                            `OP_BGTZ: ALUOp = `ALU_BGTZ;
                            default: begin   // 区分bgez和bltz
                                if (rt_in == 5'd1)       ALUOp = `ALU_BGEZ;
                                else if (rt_in == 5'd0)  ALUOp = `ALU_BLTZ;
                                else                     ALUOp = `ALU_NOP;
                            end
                        endcase
					end
					
					`OP_LW, `OP_SW, `OP_LH, `OP_LB, `OP_LBU, `OP_LHU, `OP_SB, `OP_SH: begin
						ALU_mux2 = `ALU_INPUT2_IMM;
                        ALUOp = `ALU_ADD;             // 访存需要rs+imm
                        signExt = 1'b1;
					end
					
					default: begin
						ALU_mux2 = `ALU_INPUT2_IMM;
						// 选择符号扩展方式
                        case(Op_in)      
                            `OP_ADDI, `OP_SLTI: signExt = 1'b1; // 有符号，按照这里的实现LUI有无符号不重要
                            default:            signExt = 1'b0; // 无符号，逻辑运算也无符号
                        endcase
						// 选择ALUOp
						case(Op_in)               
                            `OP_ADDI:  ALUOp = `ALU_ADD;
                            `OP_ORI:   ALUOp = `ALU_OR;
                            `OP_XORI:  ALUOp = `ALU_XOR;
                            `OP_ADDIU: ALUOp = `ALU_ADDU;
                            `OP_ANDI:  ALUOp = `ALU_AND;
                            `OP_LUI:   ALUOp = `ALU_LUI;
                            `OP_SLTI:  ALUOp = `ALU_SLT;
                            `OP_SLTIU: ALUOp = `ALU_SLTU;
                            default:   ALUOp = `ALU_NOP; // prevent latch
                        endcase
					end
				endcase
			end
		endcase
	end

endmodule
