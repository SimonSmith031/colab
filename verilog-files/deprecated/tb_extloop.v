`timescale 100ps/100ps
// 用2个单位为一个周期
module tb_extloop();
    reg clk, rst;

    PLCPU #(1024, 1024, 32'h84)cpu(clk, rst);
    initial begin
        // 读取指令的值放入指令寄存器
        $readmemh("../dat/extloop.dat", cpu.instruction_mem.mem);
        clk = 1'b0;
        rst = 1'b0;
        #2 rst = ~rst;
        #2 rst = ~rst;
    end

    always begin
        #2 clk = ~clk;  
    end
endmodule