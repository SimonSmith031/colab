`include "tools/def.v"


// 检查数据冲突（控制冒险由其他的部分来检查）
// 这里是分不同的指令，因为不同指令依赖的寄存器是不同的

// 可以改进：
// 1. 实际上可以不用细分，只要直接确保rs和rt都是正确的就行了
// 2. 然后再加一个load类的判断
// 3. 使用写信号和写目的进行判断可以精简大量无用信号

module dataHazardCtrl(insType, lastInsType, 
                      rs, rt, EX_WBDest, MEM_WBDest, 
                      mux_new_rsv, mux_new_rtv, stall);
    input  [5:0] insType;              // current insType(ID stage) used for resource usage detection
    input  [5:0] lastInsType;          // insType in EX stage (if lastInsType ~= LOAD, 需要stall)
    input  [4:0] EX_WBDest, MEM_WBDest;
    input  [4:0] rs, rt;

    output reg stall;
    output reg [1:0] mux_new_rtv;      // 不用经过ALU选择而单独进行选择的有store命令、需要用到寄存器的跳转命令
    output reg [1:0] mux_new_rsv;

    always @(*) begin
        // default
        stall = 1'b0;                 // 如果stall信号开启了则转发选项失效，不用管是什么值
        mux_new_rsv = `REG_VALUE_RF;
        mux_new_rtv = `REG_VALUE_RF;  // 默认使用寄存器中取出的数据

        // 1. 依赖rs和rt：普通R类型和beq、bne; sllv, srav, srlv，store一族
        if ((insType >= `INS_RCAL_MIN && insType <= `INS_RCAL_MAX) ||
            (insType == `INS_BNE || insType == `INS_BEQ)  ||
            (insType >= `INS_STORE_MIN && insType <= `INS_STORE_MAX) ||
            (insType == `INS_SLLV || insType == `INS_SRAV || insType == `INS_SRLV)) begin
            // (1)当EX有冲突时
            if (rs == EX_WBDest || rt == EX_WBDest) begin
                // 上一条指令是load类时
                if (lastInsType >= `INS_LOAD_MIN && lastInsType <= `INS_LOAD_MAX)
                    stall = 1'b1;
                // 上一条指令不是load类型时
                else begin
                    // 两个阶段的冲突都要判断，EX阶段的冲突优先
                    if (rs == EX_WBDest)        mux_new_rsv = `REG_VALUE_ALU;
                    else if (rs == MEM_WBDest)  mux_new_rsv = `REG_VALUE_MEM;
                    if (rt == EX_WBDest)        mux_new_rtv = `REG_VALUE_ALU;
                    else if (rt == MEM_WBDest)  mux_new_rtv = `REG_VALUE_MEM;
                end
            end
            // (2)当EX阶段没有发生冲突时就只用再判断MEM阶段的冲突
            else begin
                // 两个都是if，因为这两个可能是同一个寄存器
                if (rs == MEM_WBDest)  mux_new_rsv = `REG_VALUE_MEM;
                if (rt == MEM_WBDest)  mux_new_rtv = `REG_VALUE_MEM;
            end
        end

        // 2. 只依赖rt，比如shamt移位
        else if (insType == `INS_SLL || insType == `INS_SRA || insType == `INS_SRL) begin
            if (rt == EX_WBDest) begin
                if (lastInsType >= `INS_LOAD_MIN && lastInsType <= `INS_LOAD_MAX)
                    stall = 1'b1;
                else mux_new_rtv = `REG_VALUE_ALU; // 因为EX优先，这里一定有rt和EX写回相等，所以不用再看MEM了
            end
            else if (rt == MEM_WBDest) mux_new_rtv = `REG_VALUE_MEM;
        end

        // // 依赖rt、rs或者只依赖rt：移位类型，可变移位读rt（input1）和rs（input2），shamt移位只读rt（input1）
        // else if (insType >= `INS_SHIFT_MIN && insType <= `INS_SHIFT_MAX) begin
        //     case (insType)
        //         `INS_SLLV, `INS_SRAV, `INS_SRLV: begin
        //             // 判断EX
        //             if (rt == EX_WBDest || rs == EX_WBDest) begin
        //                 // 上条指令为load
        //                 if (lastInsType >= `INS_LOAD_MIN && lastInsType <= `INS_LOAD_MAX)
        //                     stall = 1'b1;
        //                 // 上条指令不是load
        //                 else begin
        //                     // 注意rt现在才是潜在的第一输入
        //                     if (rt == EX_WBDest)        ALUFOp1 = `ALU_FORWARD_ALU;
        //                     else if (rt == MEM_WBDest)  ALUFOp1 = `ALU_FORWARD_MEM;
        //                     if (rs == EX_WBDest)        ALUFOp2 = `ALU_FORWARD_ALU;
        //                     else if (rs == MEM_WBDest)  ALUFOp2 = `ALU_FORWARD_MEM;
        //                 end
        //             end
        //             // 如果EX没有，则判断MEM
        //             else begin
        //                 // 两个都是if，因为这两个可能是同一个寄存器
        //                 if (rt == MEM_WBDest)  ALUFOp1 = `ALU_FORWARD_MEM;
        //                 if (rs == MEM_WBDest)  ALUFOp2 = `ALU_FORWARD_MEM;
        //             end
        //         end
        //         default: begin // shamt移位
        //             if (rt == EX_WBDest) begin
        //                 if (lastInsType >= `INS_LOAD_MIN && lastInsType <= `INS_LOAD_MAX)
        //                     stall = 1'b1;
        //                 else ALUFOp1 = `ALU_FORWARD_ALU; // 因为EX优先，这里一定有rt和EX写回相等，所以不用再看MEM了
        //             end
        //             else if (rt == MEM_WBDest) ALUFOp1 = `ALU_FORWARD_MEM;
        //         end
        //     endcase
        // end

        // 3. 只依赖rs，jr/jalr, 分支（不包含beq和bne）、load、I型运算
        else if ((insType == `INS_JR || insType == `INS_JALR)               ||    // 需要link的跳转
                 (insType >= `INS_BRANCH_MIN && insType <= `INS_BRANCH_MAX) ||    // 这里不包含beq、bne（在一处分支被过滤掉了）
                 (insType >= `INS_LOAD_MIN && insType <= `INS_LOAD_MAX)     ||    // load族
                 (insType >= `INS_ICAL_MIN && insType <= `INS_ICAL_MAX)) begin    // I型运算
            if (rs == EX_WBDest) begin
                if (lastInsType >= `INS_LOAD_MIN && lastInsType <= `INS_LOAD_MAX)
                    stall = 1'b1;
                else mux_new_rsv = `REG_VALUE_ALU;
            end
            else if (rs == MEM_WBDest) mux_new_rsv = `REG_VALUE_MEM;
        end

    end
endmodule
