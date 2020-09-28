`include "def.v"
`define KEEP_SIGN     2'b00
`define INCREASE_SIGN 2'b01
`define DECREASE_SIGN 2'b10

// 尝试将always(*)中的输入输出依赖降低，不要让下一个计算步骤依赖于上一个计算步骤
// 和jump_ctrl3相比，是尝试将stall信号引入干预其运行

// 2020.9.3 猜测是branch不该跳转，但是跳转了，不能够正常恢复到原来的地址（PC）
// 从该跳转，但是没有跳转的情况很可能是正确的，推断出可能不是clr信号出了问题，而是返回地址出了问题

module jump_ctrl4 #(parameter MAX_INSADDR = 32'hffff_fff8)
                   (clk, rst, stall, ID_branch_taken, PC, INS, jr_addr, // 输入，jr的地址其实就是rsv
                    NPC, clr); // 输出

    input clk, rst, stall; 
    input ID_branch_taken;         // ID阶段的结果
    input [31:0] PC, INS, jr_addr; // jr_addr其实是rsv（要提前解决数据冲突）
    
    output reg [31:0] NPC;
    wire [31:0] PCPLUS4;
    assign PCPLUS4 = (PC < MAX_INSADDR) ? PC + 4 : 'bx; // PCPLUS4是已经考虑好了最大地址的+4结果

    output reg clr;
	
    reg [31:0] rtn_addr;        // 暂时存储跳转之后的返回地址，不对外输出
    reg [31:0] branch_to_addr;  // 存储要跳转的地址，以方便预测错误时重新跳转过去

    reg [1:0] prediction_sign;  // 0~3，大于等于2将预测为采取，否则预测为不采取
    reg [1:0] next_sign;

    /** 存储上一次的指令是否为分支指令，当本次不是branch时，修改为0
     *  因为只是简单的赋值，所以能够在无时钟的块中完成
     *  这里ID_branch_ins是每个判断结束之后的最后面才赋值，所以这里拿到的是上一阶段的值
     */
    reg ID_branch_ins;  // 每周期更新一次，这样才能够保证想要的结果
    reg mark_branch;    // 这个mark是为了在ID阶段使用的，现在IF阶段设置标志，才知道ID阶段是不是

    /* 同理，设置判断上一个指令是不是jr指令，如果是，则本次跳转不应该生效 */
    reg ID_jr_ins;      // 每周期更新一次
    reg mark_jr;        // 不停计算

    // 使用之前要声明，否则就是1位的数据
    wire [5:0] Op, funct;
    wire [4:0] shamt, rt, rd;

	// 这些是属于第一周期的数据
    assign Op    = INS[31:26];
    assign rt    = INS[20:16];
    assign shamt = INS[10:6];
    assign funct = INS[5:0];
    assign rd    = INS[15:11];
	
    // 思路是先检查ID有没有阻碍IF的跳转，其次检查IF有没有跳转
    always @(*) begin
        // 计算下一个该更新的标志
        if (ID_branch_ins)
            next_sign <= (ID_branch_taken) ? `INCREASE_SIGN : `DECREASE_SIGN;
        else
			next_sign <= `KEEP_SIGN;
		
		// 该采取但没有采取，撤回指令并置位标记
		if (ID_branch_ins && ID_branch_taken && prediction_sign < 2'b10) begin
			NPC <= branch_to_addr; 
			clr <= 1;
			mark_branch <= 0;
            mark_jr <= 0;
		end
		// ID阶段不应该采取但采取了，撤回指令并置位标记
		else if (ID_branch_ins && ~ID_branch_taken && prediction_sign >= 2'b10) begin
			NPC <= rtn_addr;
			clr <= 1;
			mark_branch <= 0;
            mark_jr <= 0;
		end
		// 是jr类型的指令，应该取寄存器的值来跳转
		else if (ID_jr_ins) begin
			NPC <= jr_addr;
			clr <= 1;
			mark_branch <= 0;
            mark_jr <= 0;
		end
		// 不需要撤回前一条指令时，考虑现在IF是否有跳转
        else begin
			clr <= 0;
            // (1) 当IF为branch类型的时候，打上标记并预测 
            if (Op == `OP_BLTZ_BGEZ && (rt == 5'd1 || rt == 5'd0) ||
                Op == `OP_BGTZ && rt == 5'd0 ||
                Op == `OP_BLEZ && rt == 5'd0 ||
				Op == `OP_BEQ || Op == `OP_BNE) begin
                mark_branch <= 1'b1;
                mark_jr <= 1'b0;
                // 存储一些可能被用到的数据
                // branch_to_addr <= PC + 4 + {{14{INS[15]}}, INS[15:0], 2'b00};
                // rtn_addr <= (PC < MAX_INSADDR) ? (PC + 4) : 'bx;
                NPC <= (prediction_sign < 2'b10) ? PCPLUS4 : (PC + 4 + {{14{INS[15]}}, INS[15:0], 2'b00});
            end
            // (2) 当IF是jr类型的时候，只是打上标记
            else if (Op == 6'd0 && rt == 5'd0 && shamt == 5'd0 && 
                    (funct == `FUNCT_JALR || (funct == `FUNCT_JR && rd == 5'd0))) begin   
                mark_jr <= 1'b1;
                mark_branch <= 1'b0;
				NPC <= PCPLUS4;  // prevent latch, useless
            end
            // (3) 当IF为直接跳转类型的时候，直接跳转
            else if (Op == `OP_JAL || Op == `OP_J) begin  
                mark_jr <= 1'b0;
                mark_branch <= 1'b0;
                NPC <= {PC[31:28], INS[25:0], 2'b00};               
            end
            else begin 
                mark_jr <= 1'b0;
                mark_branch <= 1'b0;
				NPC <= PCPLUS4;  // prevent latch, useless
            end
        end

    end

    // 不能够把一些寄存器在多个always模块中进行操作（这样的程序是不能够综合的），因此去掉了rst，把rst的状态放到initial中来
    initial begin
        prediction_sign <= 2'b01;  // 初始化到中间值，而不是0
        next_sign <= `KEEP_SIGN;
        {ID_branch_ins, mark_branch, ID_jr_ins, mark_jr} <= 4'd0;
    end

    // 每个周期更新一次标志，stall的时候不更新
    always @(posedge clk) begin
		if (stall); else begin
			// 更新二位预测标志
			if (next_sign == `INCREASE_SIGN && prediction_sign != 2'b11)
				prediction_sign <= (prediction_sign + 1);
			else if (next_sign == `DECREASE_SIGN && prediction_sign != 2'b00)
				prediction_sign <= (prediction_sign - 1);

			ID_branch_ins <= mark_branch; // 更新ID_branch_ins标志
			ID_jr_ins     <= mark_jr;     // 更新ID_jr_ins标志
			
			// 这个步骤是更新一下返回地址，保证分支预测出错之后还能够正常返回
			rtn_addr <= (PC < MAX_INSADDR) ? (PC + 4) : 'bx;
            // 更新可能的跳转地址，如果下次要跳转就要用到这里
            branch_to_addr <= PC + 4 + {{14{INS[15]}}, INS[15:0], 2'b00};
		end
    end
	
endmodule