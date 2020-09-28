`include "../tools/def.v"

module NPC #(parameter MAX_INSADDR = 32'hffff_fff8)  // 实际代入参数的时候，可以根据当前的指令存储器大小来判断
            (PC, if_IMM, id_IMM,       // 直接将INS的低位传入if_IMM，id_IMM指的是从decoder获得的立即数，本质上是延后了一个周期
             rv, IFJumpOp, IDJumpOp, 
             NPC); 
    
   input [31:0] PC;        // pc
   input [25:0] if_IMM;    // 第一阶段的IMM，是INS的低位
   input [25:0] id_IMM;    // 第二阶段的，由decoder译出来

   input [31:0] rv;        // 用32位寄存器值来跳转，第二个阶段才有

   // NPCOp被拆成了两个部分
   input [1:0]  IFJumpOp;
   input [2:0]  IDJumpOp;
   
   output reg [31:0] NPC;   // next pc
   reg [31:0] branchAddr;   // 上一次发生分支处的地址，先存起来

   wire [31:0] PCPLUS4;
   assign PCPLUS4 = PC + 4;
   
   always @(*) begin
        // 优先检查ID阶段的跳转请求，如果ID阶段跳转了，则IF阶段应该作废
        // 因为是优先检查ID阶段的请求，在此期间PC是没办法按照非+4道路走的，所以如果需要跳转且跳转时依赖PC，PC也是正确的
        if (IDJumpOp == `ID_JR || IDJumpOp == `ID_JALR)
            NPC = rv;
        else if (IDJumpOp == `ID_BRANCH)         
            NPC = PC + {{14{id_IMM[15]}}, id_IMM[15:0], 2'b00}; // 本来是PCPLUS4的，但是ID靠后（已经加了4），所以改成了PC
        else if (IDJumpOp == `ID_BRANCH_RESUME)
            NPC = branchAddr + 4;                               // 有warning，但是我们知道IF和ID的Op在一个周期是稳定的，所以不会出错
        // 说明ID阶段没有跳转请求，检查IF阶段的跳转请求
        // IF阶段的PC都是绝对无误的，立即数要使用传来的if_IMM立即数（第一周期即产生）
        else begin
            if (IFJumpOp == `IF_J || IFJumpOp == `IF_JAL)
                NPC = {PCPLUS4[31:28], if_IMM[25:0], 2'b00};
            else if (IFJumpOp == `IF_BRANCH) begin
                NPC = PCPLUS4 + {{14{if_IMM[15]}}, if_IMM[15:0], 2'b00};
                // 跳转之后还要存储当前的值
                branchAddr = PC;
            end
            else NPC = (PC > MAX_INSADDR) ? 'bx : PCPLUS4;
        end 
   end // end always
   
endmodule
