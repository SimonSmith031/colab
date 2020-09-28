`timescale 100ps/10ps
`include "modules/tools/def.v"

module cpu_core_tb();
    reg clk, rst;

    initial begin
        // 读取指令的值放入指令寄存器
        $readmemh("dat/lab13.dat", imem.mem);
		// $readmemh("dat/demo31_mem.dat", dmem.mem);
        clk = 1'b0;
        rst = 1'b0;
        #1 rst = ~rst;
        #1 rst = ~rst;
    end

    always begin
        #1 clk = ~clk;  
    end
    
    wire mem_w, INT;
    wire [31:0] addr;
    wire [31:0] PC;
    wire [31:0] Data_in, Data_out;
    wire [31:0] inst;
    
    memory #(1024) dmem(.memWrite    (mem_w), 
                        .clk         (clk), 
                        .loadSignExt (1'b1), 
                        .addr        (addr), 
                        .memop       (`MEMOP_WORD),
                        .A           (Data_out),
                        .B           (Data_in));

    ins_mem #(1024) imem (.PC(PC), .INS(inst));

    pcpu_core #(32'hffff_fff8) U1(.clk      (clk),			
			                      .reset     (rst),
			                      .MIO_ready (),			
			                      .inst_in   (inst),
			                      .Data_in   (Data_in),
			                      .mem_w     (mem_w),
			                      .PC_out    (PC),
		    	                  .Addr_out  (addr),
			                      .Data_out  (Data_out), 
			                      .CPU_MIO   (),
			                      .INT       ());

endmodule