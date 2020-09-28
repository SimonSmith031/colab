`include "tools/def.v"

/*************************************************************
 * EX译的摘要必须是coder直接译出的摘要高位，不能是转发来的   *
 * 转发会慢一个周期，已经来不及了                            *
 *************************************************************/

// insType是microCoder（结果的高位）直接摘来的，所以这个生成在第二周期就能够完成
// 如果insType走分发线的话则来不及
module EXMicroDecorder(insType, signExt, ALUOp, ALU_mux1, ALU_mux2);
    input [5:0] insType;

    // 这个元件有时钟周期了，先寄存一下信号
    output reg       signExt;          // 立即数的扩展方式，在I型指令中有用，1表示有符号扩展
    output reg [4:0] ALUOp;            // ALU操作信号
    output reg       ALU_mux1;         
    output reg [1:0] ALU_mux2;

    always @(*) begin
        // 对于能够识别的微指令,按照不同的分支进行信号赋值
        if (insType >= `INS_RCAL_MIN && insType <= `INS_ICAL_MAX) begin
            // 1. 普通的R型,算术逻辑运算的类型
            if (insType >= `INS_RCAL_MIN && insType <= `INS_RCAL_MAX) begin
                ALU_mux1 <= `ALU_INPUT1_RS;
                ALU_mux2 <= `ALU_INPUT2_RT;
                signExt  <= 1'bx;      // 符号扩展方式不重要,不会用到立即数
                case(insType)          // 完备枚举,不需要default
                    `INS_ADD:  ALUOp <= `ALU_ADD;  //add
                    `INS_ADDU: ALUOp <= `ALU_ADDU; //addu
                    `INS_SUB:  ALUOp <= `ALU_SUB;  //sub
                    `INS_SUBU: ALUOp <= `ALU_SUBU; //subu
                    `INS_AND:  ALUOp <= `ALU_AND;  //and
                    `INS_OR:   ALUOp <= `ALU_OR;   //or
                    `INS_XOR:  ALUOp <= `ALU_XOR;  //xor
                    `INS_NOR:  ALUOp <= `ALU_NOR;  //nor
                    `INS_SLT:  ALUOp <= `ALU_SLT;  //slt
                    `INS_SLTU: ALUOp <= `ALU_SLTU; //sltu
                endcase
            end
            // 2. 移位运算类型
            else if (insType >= `INS_SHIFT_MIN && insType <= `INS_SHIFT_MAX) begin
                ALU_mux1 <= `ALU_INPUT1_RT;
                signExt  <= 1'bx;  // 符号扩展方式不重要,不会用到立即数
                case(insType)
                    `INS_SLL: begin 
                        ALUOp    <= `ALU_SLL; //sll
                        ALU_mux2 <= `ALU_INPUT2_SHAMT;
                    end
                    `INS_SLLV: begin 
                        ALUOp    <= `ALU_SLL; //sllv
                        ALU_mux2 <= `ALU_INPUT2_RSV;
                    end
                    `INS_SRA: begin 
                        ALUOp    <= `ALU_SRA; //sra
                        ALU_mux2 <= `ALU_INPUT2_SHAMT;
                    end
                    `INS_SRAV: begin 
                        ALUOp    <= `ALU_SRA; //srav
                        ALU_mux2 <= `ALU_INPUT2_RSV;
                    end
                    `INS_SRL: begin 
                        ALUOp    <= `ALU_SRL; //srl
                        ALU_mux2 <= `ALU_INPUT2_SHAMT;
                    end
                    `INS_SRLV: begin 
                        ALUOp    <= `ALU_SRL; //srlv
                        ALU_mux2 <= `ALU_INPUT2_RSV;
                    end
                endcase
            end
            // 3. 无条件跳转类型,有可能需要写回（link），这个时候需要ALU进行转发（这个功能暂时关闭）
            else if (insType >= `INS_JUMP_MIN && insType <= `INS_JUMP_MAX) begin
                signExt <= 1'bx;
                ALUOp <= `ALU_NOP;
                // ALU_mux1 <= `ALU_INPUT1_PCPLUS4;
                ALU_mux1 <= 'bx;
                ALU_mux2 <= 'bx;
            end
            // 4. 条件跳转指令
            else if (insType >= `INS_BRANCH_MIN && insType <= `INS_BRANCH_MAX)
                {signExt, ALUOp, ALU_mux1, ALU_mux2} <= 'bx;
            // 5. load和store,两种访存
            else if (insType >= `INS_LOAD_MIN && insType <= `INS_STORE_MAX) begin
                ALUOp <= `ALU_ADD;              // 访存需要rs+imm
                signExt <= 1'b1;                // 6.15 更正：改为符号扩展
                ALU_mux1 <= `ALU_INPUT1_RS;     // rs
                ALU_mux2  = `ALU_INPUT2_IMM;    // extIMM
            end
            // 6. I型的算术逻辑运算
            else if (insType >= `INS_ICAL_MIN && insType <= `INS_ICAL_MAX) begin
                ALU_mux1 <= `ALU_INPUT1_RS;     // rs
                ALU_mux2 <= `ALU_INPUT2_IMM;    // extIMM
                signExt  <= (insType == `INS_ADDI || insType == `INS_SLTI) ? 1'b1 : 1'b0;
                case (insType) 
                    `INS_ADDI:  ALUOp <= `ALU_ADD;
                    `INS_ORI:   ALUOp <= `ALU_OR;
                    `INS_XORI:  ALUOp <= `ALU_XOR;
                    `INS_ADDIU: ALUOp <= `ALU_ADDU;
                    `INS_ANDI:  ALUOp <= `ALU_AND;
                    `INS_LUI:   ALUOp <= `ALU_LUI;
                    `INS_SLTI:  ALUOp <= `ALU_SLT;
                    `INS_SLTIU: ALUOp <= `ALU_SLTU;
                endcase
            end
        end
        // 对于不能识别的微指令,只是把全信号全置未知
        else {signExt, ALUOp, ALU_mux1, ALU_mux2} <= 'bx;
    end
endmodule
