`include "../tools/def.v"
`define KEEP_SIGN     2'b00
`define INCREASE_SIGN 2'b01
`define DECREASE_SIGN 2'b10

// 将id checker和jump ctrl的功能整合在一起的尝试
// 失败
module jump_ctrl2 #(parameter MAX_INSADDR = 32'hffff_fff8)
                   (clk, rst, PC, INS,          // 输入，jr的地址其实就是rsv
				    rsv, rtv, Op_2, rt_2,       // 原来的ctrl_checker的功能，现在整合在jump_ctrl2中来
                    NPC, clr);                  // 输出

    input clk, rst; 
    reg   ID_branch_taken;         // ID阶段的结果
    input [31:0] PC, INS;     // jr_addr其实是rsv（要提前解决数据冲突）
	input [31:0] rsv, rtv;
	input [5:0]  Op_2;
	input [4:0]  rt_2;
    
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
    wire [5:0] Op_1, funct_1;
    wire [4:0] shamt_1, rt_1, rd_1;

	// 这些是属于第一周期的数据
    assign Op_1    = INS[31:26];
    assign rt_1    = INS[20:16];
    assign shamt_1 = INS[10:6];
    assign funct_1 = INS[5:0];
    assign rd_1    = INS[15:11];
	
    // 思路是先检查ID有没有阻碍IF的跳转，其次检查IF有没有跳转
    always @(*) begin
		// 首先生成ID是否被采取的信号
		case (Op_2) 
            `OP_BNE:  ID_branch_taken = (rsv != rtv) ? 1'b1 : 1'b0;
            `OP_BEQ:  ID_branch_taken = (rsv == rtv) ? 1'b1 : 1'b0;
            `OP_BLEZ: ID_branch_taken = (rsv <= 0)   ? 1'b1 : 1'b0;
            `OP_BGTZ: ID_branch_taken = (rsv > 0)    ? 1'b1 : 1'b0;
            `OP_BLTZ_BGEZ:  begin
                if (rt_2 == 5'd1)
                    ID_branch_taken = (rsv >= 0) ? 1'b1 : 1'b0;
                else if (rt_2 == 5'd0)
                    ID_branch_taken = (rsv < 0) ? 1'b1 : 1'b0;
                else // undefined
                    ID_branch_taken = 1'b0;
            end
            default: ID_branch_taken = 1'b0; // 其他情况未定义
        endcase
		
        // 当ID阶段是branch指令的时候，可能涉及到更新标志
        if (ID_branch_ins == 1'b1) begin
            if (ID_branch_taken == 1'b1) begin      // ID阶段应该采取
                next_sign = `INCREASE_SIGN;
                // 用之前的预测标志就能知道之前是怎么预测的（小的时候表示不采取，大的时候表示采取）
                NPC = (prediction_sign < 2'b10) ? branch_to_addr : PCPLUS4;
				clr = (prediction_sign < 2'b10);
            end
            else begin                              // ID阶段不应该采取
                next_sign = `DECREASE_SIGN;
                NPC = (prediction_sign >= 2'b10) ? rtn_addr : PCPLUS4;
				clr = (prediction_sign >= 2'b10);
            end
        end
        else begin
            next_sign = `KEEP_SIGN;
            NPC = (ID_jr_ins) ? rsv : PCPLUS4;
			clr = ID_jr_ins;
        end
        
		// 决定是否要发出clr信号以撤销前一条指令
		// 2020.8.31 clr信号没有实际上起到作用，是因为没有时间计算？
		// 专门放出来可能太慢
        /* clr = ((ID_branch_ins && ID_branch_taken && prediction_sign < 2'b10)   ||
			   (ID_branch_ins && ~ID_branch_taken && prediction_sign >= 2'b10) ||
			    ID_jr_ins); */
		
        // 这个条件（clr为0）如果成立，说明ID阶段的那条指令采取正确，开始考虑现在IF是否有跳转
        if (clr == 0) begin
            // (1) 当IF为branch类型的时候，打上标记并预测 
            if (Op_1 == `OP_BLTZ_BGEZ && (rt_1 == 5'd1 || rt_1 == 5'd0) ||
                Op_1 == `OP_BGTZ && rt_1 == 5'd0 ||
                Op_1 == `OP_BLEZ && rt_1 == 5'd0 ||
				Op_1 == `OP_BEQ || Op_1 == `OP_BNE) begin
                mark_branch = 1'b1;
                mark_jr = 1'b0;
                // 计算应该跳转到什么位置，并存储起来
                // 接下来马上可能会跳转，也可能不会（如果不会跳转，则这个值存下来备用）
                branch_to_addr = PC + 4 + {{14{INS[15]}}, INS[15:0], 2'b00};
                NPC = (prediction_sign < 2'b10) ? PCPLUS4 : branch_to_addr;
            end
            // (2) 当IF是jr类型的时候，只是打上标记
            else if (Op_1 == 6'd0 && rt_1 == 5'd0 && shamt_1 == 5'd0 && 
                    (funct_1 == `FUNCT_JALR ||(funct_1 == `FUNCT_JR && rd_1 == 5'd0))) begin   
                mark_jr = 1'b1;
                mark_branch = 1'b0;
            end
            // (3) 当IF为直接跳转类型的时候，直接跳转
            else if (Op_1 == `OP_JAL || Op_1 == `OP_J) begin  
                mark_jr = 1'b0;
                mark_branch = 1'b0;
                NPC = {PC[31:28], INS[25:0], 2'b00};               
            end
            else begin 
                mark_jr = 1'b0;
                mark_branch = 1'b0;
            end
        end
        else begin // ID阶段的指令采取错误，需要擦除，所以把两个标记都置位
            mark_branch = 1'b0;
            mark_jr = 1'b0;
        end

    end

    // 因为不能够把一些寄存器在多个always模块中进行操作（这样的程序是不能够综合的）
    // 因此去掉了rst，把rst的状态放到initial中来
    initial begin
        prediction_sign <= 2'b01;  // 初始化到中间值，而不是0
        next_sign <= `KEEP_SIGN;
        {ID_branch_ins, mark_branch, ID_jr_ins, mark_jr} <= 4'd0;
    end

    // 每个周期更新一次标志
    always @(posedge clk) begin
        // 更新二位预测标志
        if (next_sign == `INCREASE_SIGN && prediction_sign != 2'b11)
            prediction_sign <= (prediction_sign + 1);
        else if (next_sign == `DECREASE_SIGN && prediction_sign != 2'b00)
            prediction_sign <= (prediction_sign - 1);

		ID_branch_ins <= mark_branch; // 更新ID_branch_ins标志
        ID_jr_ins     <= mark_jr;     // 更新ID_jr_ins标志
			
		// 这个步骤是更新一下返回地址，保证分支预测出错之后还能够正常返回
		rtn_addr <= (PC < MAX_INSADDR) ? (PC + 4) : 'bx;
		// 全部指令运行完成之后将不再运行，NPC也将变为无效，所以尝试赋值为'bx
    end
	
endmodule