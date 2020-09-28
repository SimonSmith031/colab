/*****************************************************
 * 微指令传送线只提供MEM和WB阶段的微指令，           *
 * EX阶段的微指令由microCoder编好后直接送出。        *
 * 注意microTranfer保存的都是当前正在执行的指令摘要，*
 * 我们释放信号的时候是根据当前正在执行的指令摘要的  *
 *****************************************************/

module microTransfer(clk, stall, micro,        // 输入
                     EX_insType, MEM_insType,  // 当前阶段的输出指令类型，由微译码器译码
                     EX_WBDest, MEM_WBDest);   // 供检查数据冲突问题以及写回的值是哪一个
    input clk, stall;
    input [10:0] micro;

    reg [21:0] microPipeline;  //只需要存放两个完整摘要，正在写回的指令不需要摘要

    // 流水线中每个周期EX和MEM阶段元件的微指令是相同的
    output [5:0] EX_insType, MEM_insType;
    output [4:0] EX_WBDest, MEM_WBDest;

    // 正在执行的指令和正拿到的信号是不一样的，有延迟，先拿到信号，然后才开始执行
    assign EX_insType  = microPipeline[21:16];
    assign EX_WBDest   = microPipeline[15:11];
    assign MEM_insType = microPipeline[10:5];
    assign MEM_WBDest  = microPipeline[4:0];

    initial begin
        microPipeline <= 'bx; // 赋全x的简洁表达方式，前面不加位号
    end

    always @(posedge clk) begin
        // 如果传过来的micro就是全x，那么拼接上的自然就是一块x
        if (stall) begin      // 安全，因为stall信号未知的时候这个分支也会瘫痪
            // 空指令给0是安全的，因为我们的指令编号是从1开始的，0为无效选项
            // 如果stall，相当于新放进来的指令是一个bubble
            microPipeline <= {11'd0, microPipeline[21:11]};
        end
        else microPipeline <= {micro, microPipeline[21:11]};
    end
endmodule
