`timescale 100ps/100ps
// 用2个单位为一个周期
module tb_predict();
    reg clk, rst;

    // 两类存储器的大小、最大指令地址
    PLCPU #(1024, 1024, 32'h38)cpu(clk, rst);
    initial begin
        // 读取指令放入指令寄存器
        $readmemh("../dat/predict.dat", cpu.instruction_mem.mem);
        clk = 1'b0;
        rst = 1'b0;
        #2 rst = ~rst;
        #2 rst = ~rst;
    end

    always begin
        #2 clk = ~clk;  
    end
endmodule