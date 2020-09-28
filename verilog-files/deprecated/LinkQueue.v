`include "tools/def.v"

// 链接队列，当写link（jal、jalr）地址的时候，能够从其中获得正确的地址
// 封装了一个延迟器和多路选择器
// linkOp被特殊设计，两位分别代表IF和ID的link请求
module LinkQueue(clk, linkOp, PC, out);
    input  clk;
    input  [1:0] linkOp;
    input  [31:0] PC;
    output [31:0] out;
    
    // IF阶段的要3个delay，ID阶段的要2个delay
    reg [95:0] queue;
    // 因为是连续赋值，所以实际上实现了先写后读
    assign out = queue[95:64];

    always @(posedge clk) begin
        // 移位
        queue[95:64] <= queue[63:32];
        // 检查ID请求位，被IF设置的数据不可能再被ID设置了，因为ID阶段的新指令正是上次的指令
        queue[63:32] <= (linkOp[0] ? PC : queue[31:0]);
        // 检查IF请求位
        queue[31:0]  <= (linkOp[1] ? (PC + 4) : 32'd0);
    end
endmodule