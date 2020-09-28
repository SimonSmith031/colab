`include "def.v"

module decoder(clk, clr, stall, INS, 
               IMM, Op, rs, rt, rd, shamt, funct);

    input  clk, clr, stall;        // clr信号用来把保存的指令清空
    input  [31:0]  INS;            // 32位的指令

    output [15:0]  IMM;            // 16位立即数
    output [5:0]   Op;
    output [4:0]   rs;
    output [4:0]   rt;
    output [4:0]   rd;
    output [4:0]   shamt;
    output [5:0]   funct;

    reg [31:0] savedIns;

    always @(posedge clk) begin
        if (clr) savedIns <= 'b0;  // 如果有clr信号，保存的指令清空（如果只是阻止写入，那么原有的指令会被重复运行下去，是错误的）
        /* 全零是sll的一种指令，相当于nop，所以是安全的 */
        else if (stall) ;          // 如果stall，保存的指令不变
        else savedIns <= INS;      // 两个信号都没有，保存新的指令
    end

    assign  IMM    = savedIns[15:0];
    assign  Op     = savedIns[31:26];
    assign  rs     = savedIns[25:21];
    assign  rt     = savedIns[20:16];
    assign  rd     = savedIns[15:11];
    assign  shamt  = savedIns[10:6];
    assign  funct  = savedIns[5:0];

endmodule