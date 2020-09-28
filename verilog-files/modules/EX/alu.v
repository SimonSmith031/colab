`include "../tools/def.v"

module alu(clk, A, B, ALUOp, C, zero);
	input  clk;
    input  signed [31:0] A, B;
    input  [4:0]  ALUOp;
    output [31:0] C;     // C只负责输出，D存放答案
    output zero;
   
    reg [32:0] D;        // 多了一位，可同时用于unsigned计算和signed运算
    initial D <= 32'd0;

    assign C = D[31:0];
    assign zero = (C == 32'b0);
    integer i;
    
    always @(posedge clk) begin
        case (ALUOp)
            `ALU_NOP:  D <= 33'd0;                            // NOP

            `ALU_ADD:  D[31:0] <= A + B;                      // ADD
            `ALU_SUB:  D[31:0] <= A - B;                      // SUB

            `ALU_ADDU: D <= ({1'b0, A} + {1'b0, B});          // ADDU
            `ALU_SUBU: D <= ({1'b0, A} - {1'b0, B});          // SUBU

            `ALU_AND:  D[31:0] <= A & B;                      // AND/ANDI
            `ALU_OR:   D[31:0] <= A | B;                      // OR/ORI
            `ALU_XOR:  D[31:0] <= A ^ B;                      // XOR
            `ALU_NOR:  D[31:0] <= ~(A | B);                   // NOR

            `ALU_SLT:  D[31:0] <= (A < B) ? 32'd1 : 32'd0;    // SLT/SLTI
            `ALU_SLTU: D[31:0] <= ({1'b0, A} < {1'b0, B}) ? 32'd1 : 32'd0;

            `ALU_SLL:  D[31:0] <= (B << A[4:0]);
            `ALU_SRL:  D[31:0] <= (B >> A[4:0]);
            `ALU_SRA:  D[31:0] <= (B >>> A[4:0]);

            `ALU_LUI:  D[31:0] <= {B[15:0], 16'd0};           // LUI，直接用IMM填充高位

            // 分支系列运算，没有u符号，全都是有符号比较
            // 因为流水线的提前计算，这些功能其实只是残留而无效的
            `ALU_BEQ:  D[31:0] <= (A == B) ? 32'd1 : 32'd0;
            `ALU_BNE:  D[31:0] <= (A != B) ? 32'd1 : 32'd0;
            `ALU_BLEZ: D[31:0] <= (A <= 0) ? 32'd1 : 32'd0;
            `ALU_BGEZ: D[31:0] <= (A >= 0) ? 32'd1 : 32'd0;
            `ALU_BGTZ: D[31:0] <= (A > 0)  ? 32'd1 : 32'd0;
            `ALU_BLTZ: D[31:0] <= (A < 0)  ? 32'd1 : 32'd0;
			
			// 其他情况转发A的值，反正ALU不具备写功能，不危险
            default:   D[31:0] <= A;
        endcase
    end // end always
   
endmodule
    
