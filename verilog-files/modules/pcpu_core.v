`include "tools/def.v"
// Pipeline CPU Core
// 对于访存指令，只支持lw和sw，关于lh、lb、sh、sb的支持，需要依赖外部的IP核支持
// 因为我们的实验用不到这些信号，所以不用配置这样的支持
// 这里用来仿真的memory模块也只支持lw和sw的操作，且要求输入的地址是4的倍数
module pcpu_core #(parameter MAX_INSADDR = 32'hffff_fff8)
                  (input         clk,			
			       input         reset,
			       input         MIO_ready,     // 
			       input  [31:0] inst_in,
			       input  [31:0] Data_in,	
			       output        mem_w,
			       output [31:0] PC_out,
			       output [31:0] Addr_out,
			       output [31:0] Data_out, 
			       output        CPU_MIO,       // 
			       input         INT);          //

    wire stall, clr;

    wire [31:0] NPC;
    // wire [31:0] PC_out;

    wire [15:0] imm;
    wire [5:0]  Op, funct;
    wire [4:0]  rs, rt, rd;
    wire [4:0]  shamt;

    // 中央控制单元的一些控制信号
    wire       signExt;
    wire [4:0] ALUOp;
    wire       ALU_mux1;
    wire       ALU_mux2;
	wire       MEMWr;
    wire [1:0] MEMOp;         
    wire       loadSignExt;   // load的扩展方式
    wire [4:0] WBSel;
    wire       RFWr;

    // 寄存器组模块相关
    wire [31:0] rf_rsv, rf_rtv;
    wire [1:0]  mux_WBData;   // 写回的选择信号
    wire [31:0] WBData;       // 写回的值，通过多路选择器选择

    // ALU
    wire        zero;         // 这个信号目前没有被实际使用
	
    wire [31:0] ALU_input1, ALU_input2;

    // 向外输出地址，在存储器中去取
    wire [31:0] ALU_output;

    wire [31:0] imm32;              // 被扩展之后的立即数（来源是指令中的16位立即数）
    reg  [31:0] ALU_out_reg;        // for writing back into RF
	
	assign Addr_out = ALU_out_reg;  // 输出访存的地址

	// 数据竞争
    wire [31:0] rtv;
    wire [31:0] rsv;
    wire [2:0]  mux_rsv, mux_rtv;

    // 寄存输出的数据（给memory的数据）
	reg [31:0] rtv_reg_1, rtv_reg_2;
    assign Data_out = rtv_reg_2;    // 用来写内存的数据
	
	// 寄存和MEM有关的信号，也放到第五周期时钟上升沿到来时完成
	reg       MEMWr_reg;         // 控制是否写MEM的信号
    reg [1:0] MEMOp_reg;         // 控制内存操作的范围，只有在访存过程中是有有意义的
    reg       loadSignExt_reg;   // load的扩展方式
	assign    mem_w = MEMWr_reg; // 输出的写信号是寄存了之后的信号

    // 写回的信号要寄存
    reg [4:0]  WBSel_reg;
    reg        RFWr_reg;
    reg [31:0] PCPLUS4_1, PCPLUS4_2, PCPLUS4_3;
	reg [1:0]  mux_WBData_reg;

    // 分支控制
    wire        ID_branch_result;

    // PC
    PC pc(.clk   (clk),    
          .rst   (reset), 
          .stall (stall), 
          .NPC   (NPC),
          .PC    (PC_out));       // the only output
		  
	/* ********************* 裸露的寄存器模块 ********************* */
	// 哪些信号的保存需要由stall来干预？
	// 初步感觉没有必要干预，MEM和WB的信号都是在EX阶段之后的，而其他的并不是信号或者条件，只是单纯的值
	
	initial begin
		// MEM和WB阶段的信号
		MEMWr_reg <= 0;
		MEMOp_reg <= `MEMOP_WORD;
		loadSignExt_reg <= 0;
        WBSel_reg <= 5'd0;
        RFWr_reg <= 1'b0;
        mux_WBData_reg <= 2'b00;
		// PCPLUS4的寄存器
		PCPLUS4_1 <= 32'd0;
        PCPLUS4_2 <= 32'd0;     // 从EX阶段开始后持有一个周期
        PCPLUS4_3 <= 32'd0;     // 从MEM阶段开始后持有一个周期
    end
    always @(posedge clk) begin
		// MEM和WB阶段的信号
		MEMWr_reg <= MEMWr;
		MEMOp_reg <= MEMOp;
		loadSignExt_reg <= loadSignExt;
        WBSel_reg <= WBSel;
        RFWr_reg  <= RFWr;
        mux_WBData_reg <= mux_WBData;
		// ALU结果的寄存器，用来在结果还没有被写回之前被多路选择以提供访问支持
		ALU_out_reg <= ALU_output;
		// PC+4的值，用来实现jal和jalr的写回
		PCPLUS4_1 <= (PC_out + 32'd4);
        PCPLUS4_2 <= PCPLUS4_1;
        PCPLUS4_3 <= PCPLUS4_2;
		// 寄存rtv，用来向内存中写入
		rtv_reg_1 <= rtv;
		rtv_reg_2 <= rtv_reg_1;
    end

    // ID
    decoder distributor(.clk   (clk), 
                        .clr   (clr), 
                        .stall (stall), 
                        .INS   (inst_in),        // 前面四个是输入，后面是输出
                        .IMM   (imm), 
                        .Op    (Op), 
                        .rs    (rs), 
                        .rt    (rt), 
                        .rd    (rd), 
                        .shamt (shamt), 
                        .funct (funct));

    // 现在memop（代表mem的操作范围，一个字节、两个字节或者一个字）还有loadSignExt（控制load出来的数据是不是要符号扩展）
    // 都没有办法传出去，因为外面的简单IP核（需要再研究）中是不能够控制操作范围的，不过稍加修改也就能传出去
    // 也就是说，现在访存指令是只能够使用sw和lw指令的
    ctrl control (.clk         (clk),
                  .stall       (stall),
                  .Op_in       (Op), 
                  .funct_in    (funct), 
                  .rt_in       (rt), 
                  .rd_in       (rd),             
                  .signExt     (signExt), 
                  .ALUOp       (ALUOp), 
                  .ALU_mux1    (ALU_mux1), 
                  .ALU_mux2    (ALU_mux2),        
                  .MEMWr       (MEMWr), 
                  .MEMOp       (MEMOp), 
                  .loadSignExt (loadSignExt),              
                  .WBSel       (WBSel), 
                  .RFWr        (RFWr),
                  .mux_WBData  (mux_WBData));

    // 寄存器组
    RF rf(.clk   (clk), 
          .rst   (reset),
          .RFWr  (RFWr_reg),   // 这个信号要用寄存后的
          .A1    (rs), 
          .A2    (rt), 
          .WBSel (WBSel_reg),  // 这个信号要用寄存后的
          .WD    (WBData), 
          .RD1   (rf_rsv), 
          .RD2   (rf_rtv));

    // EX
    imm_ext imm_extension(.Imm16   (imm),
                          .signExt (signExt), 
                          .Imm32   (imm32));

    // alu两个输入的多路选择器，第三个周期控制单元发出信号之后，alu的两个输入也会发生变化
    // 因此不能在这之前就存好两个输入，而是要存储原始的数据
    mux2 #(32) alu_input1_mux(.d0 (rsv), 
                              .d1 ({27'd0, shamt}),
                              .s  (ALU_mux1),
                              .y  (ALU_input1));

    mux2 #(32) alu_input2_mux(.d0 (rtv),
                              .d1 (imm32),
                              .s  (ALU_mux2), 
                              .y  (ALU_input2));

    // ALU
    alu ALU(.clk   (clk),
			.A     (ALU_input1), 
            .B     (ALU_input2),
            .ALUOp (ALUOp),
            .C     (ALU_output),
            .zero  (zero));

    // 写回的数据选择
    mux3 #(32) WBData_selector(.d0 (ALU_out_reg),
                               .d1 (Data_in),
                               .d2 (PCPLUS4_3),
                               .s  (mux_WBData_reg),
                               .y  (WBData));

    // 数据竞争检查
    data_ctrl data_control (.clk       (clk),
							.Op        (Op), 
							.rs        (rs), 
							.rt        (rt), 
							.funct     (funct), 
							.EX_WBSel  (WBSel), 
							.MEM_WBSel (WBSel_reg), // 用的是接下来要寄存的那个
							.mux_rsv   (mux_rsv), 
							.mux_rtv   (mux_rtv), 
							.stall     (stall));

    // 选择解决了数据竞争的rsv和rtv
    // 一个麻烦问题是mem阶段的输出可能是ALU的，也可能是MEM的，所以还应该添加.d3: ALU_output_reg和.d2通过load指令来区别，选择合适的mux_rsv信号
    // d4和d5表示是jal或者jalr的返回地址，也可能是要写到RF去而发生数据冒险的
    mux8 #(32) rsv_selector(.d0 (rf_rsv),
                            .d1 (ALU_output), 
                            .d2 (Data_in),
                            .d3 (ALU_out_reg),
                            .d4 (PCPLUS4_2),
                            .d5 (PCPLUS4_3),
                            .d6 (32'd0),
                            .d7 (32'd0),
                            .s  (mux_rsv), 
                            .y  (rsv));

    mux8 #(32) rtv_selector(.d0 (rf_rtv), 
                            .d1 (ALU_output),
                            .d2 (Data_in),
                            .d3 (ALU_out_reg),
                            .d4 (PCPLUS4_2),
                            .d5 (PCPLUS4_3),
                            .d6 (32'd0),
                            .d7 (32'd0),
                            .s  (mux_rtv), 
                            .y  (rtv));

    // 跳转控制
    ID_branch_checker branch_checker(.rsv          (rsv), 
                                     .rtv          (rtv), 
                                     .Op           (Op),
                                     .rt           (rt),   
                                     .branch_taken (ID_branch_result));
	
	// 2020.8.31 怀疑生成的NPC和clr没有时间被使用，但没有实验检查出来原因
	// 2020.8.31 发现stall信号没有完全发挥作用，并作出了一些修改
    jump_ctrl4 #(MAX_INSADDR) jump_control (.clk               (clk), 
                                            .rst               (reset),
											.stall             (stall),
                                            .ID_branch_taken   (ID_branch_result), 
                                            .PC                (PC_out), 
                                            .INS               (inst_in), 
                                            .jr_addr           (rsv), 
                                            .NPC               (NPC),
                                            .clr               (clr));

endmodule