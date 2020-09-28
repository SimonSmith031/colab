`timescale 100ps/100ps
// 用2个单位为一个周期
module tb_loop();
    reg clk, rst;

    // 第三个数字是最大指令地址，防止超过指令之后PC还在增加
    PLCPU #(1024, 1024, 32'h48)cpu(clk, rst);
    initial begin
        // 读取loop.dat的值放入指令寄存器
        $readmemh("../dat/loop.dat", cpu.instruction_mem.mem);
        clk = 1'b0;
        rst = 1'b0;
        #2 rst = ~rst;
        #2 rst = ~rst;
    end

    always begin
        #2 clk = ~clk;  
    end
endmodule