`include "../tools/def.v"

module ins_mem #(parameter INS_MEMSIZE = 1024)
                (PC, INS); 
	parameter INS_NUM = INS_MEMSIZE / 4;
	
	input  [31:0] PC;
	output [31:0] INS;               // INS要保存好
    reg    [31:0] mem[INS_NUM-1:0];  // 指令的存储器
	
    assign INS = mem[PC/4];
endmodule