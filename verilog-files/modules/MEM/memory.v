// 转发操作现在无法使用，需要修改
`include "../tools/def.v"

module memory #(parameter MEMSIZE = 1024)  
               (memWrite, clk, loadSignExt, addr, memop, A, B);
    
    input  memWrite, clk, loadSignExt;  // 写信号，时钟，loadSignExt表示有符号数，一直读没有问题的，只要不选用就行了
    input  [31:0] addr;
    input  [1:0]  memop;                // 控制这次操作的范围，一个字节，两个字节，一个word（详细见def，有改动）
    input  [31:0] A;                    // 将要写的数据
    output [31:0] B;                    // 读出来的数据，B之所以可以不寄存，是因为有readData帮助它寄存了

    reg    [31:0] readData;
    assign B = readData;

    reg [31:0] mem[MEMSIZE/4-1:0];         // 指定1024个字节

    always @(*) begin
        // 随时可以读，好像RAM_B就是always enabled的
        /* 现在是只能地址是4的倍数，因为实际上不能够支持读非4的倍数的地址了 */
        case (memop)
            `MEMOP_BYTE:     readData <= {{24{loadSignExt == 1'b1 ? mem[addr/4][7] : 1'b0}}, mem[addr/4][6:0]};
            `MEMOP_HALFWORD: readData <= {{16{loadSignExt == 1'b1 ? mem[addr/4][15] : 1'b0}}, mem[addr/4][14:0]};
            `MEMOP_WORD:     readData <= mem[addr/4];
            default:         readData <= mem[addr/4];
        endcase
        /* $display("mem read, memop = 2'b%2b", memop); */
    end

    always @(posedge clk) begin
        // 有时钟周期才能写
        if (memWrite == 1'b1) begin 
            case (memop) // 注意是小端
                `MEMOP_BYTE:     mem[addr/4][7:0] <= A[7:0];
                `MEMOP_HALFWORD: mem[addr/4][15:0] <= A[15:0];
                `MEMOP_WORD:     mem[addr/4] <= A[31:0];
            endcase
            $display("write to memory: \n\tdata: 0x%8X, addr: 0x%8X, scale: 0b%2b", A, addr, memop);
        end
    end

endmodule