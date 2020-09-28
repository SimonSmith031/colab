`include "../tools/def.v"
// PC模块
// 去掉PCWr信号，PCWr信号由stall信号表示，因为现在每个周期（流水线）都要写
module PC(clk, rst, stall, NPC, PC);
    input  clk, rst, stall;
    input      [31:0] NPC;
    output reg [31:0] PC;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            PC <= 32'h0000_0000;
        end
        else begin  // 只要未知在判断语句中，就算是不等，也会让判断语句失效！
            if (stall); else PC <= NPC; 
        end
        $display("Current PC: 0x%8X", PC);
    end
endmodule
