// 将信号延迟一个周期
module delay_reg #(parameter SIZE = 32)
                  (clk, stall, in, out);

    input  clk, stall;     // 不需要使用stall信号的时候把它连在1'b0上面
    input  [SIZE-1:0] in;
    output [SIZE-1:0] out;

    reg [SIZE-1:0] saved;
    assign out = saved;
    integer i;

    initial begin
        saved <= 'bx;
    end

    always @(posedge clk) begin
        if (stall) saved <= 'bx;
        else       saved <= in;
    end

endmodule

// 适用于多个周期的延迟构件（deprecated）
module multicycle_delay_reg #(parameter SIZE = 32, parameter DELAY = 1)
                             (clk, in, out);
    input  clk;
    input  [SIZE-1:0] in;
    output [SIZE-1:0] out;

    parameter NUM = DELAY + 1;
    // 鉴于数组的合法性（语法），NUM最低为2，DELAY最低为1，所以NUM = DELAY + 1
    // 会浪费一个item的空间，但是逻辑正确，最低位我们让它闲置（0位）
    reg [SIZE-1:0] queue[NUM-1:0];
    assign out = queue[NUM-1];       // 最高位分配为输出
    integer i;

    initial begin
        for (i = 0; i < NUM; i = i + 1) begin
            queue[i] <= 'b0;
        end
    end

    always @(posedge clk) begin
        queue[1] <= in;              // 从低位塞入数据，0位被闲置了
        // 移位数据，不从最低位（指的是1，0被闲置）开始，否则刚刚的输入就被清掉了
        for (i = 2; i < NUM; i = i + 1) begin
            queue[i] <= queue[i-1];
        end
    end
endmodule