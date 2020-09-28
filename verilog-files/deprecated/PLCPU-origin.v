// Pipeline CPU Combination (Top Layer)
module PLCPU #(parameter MEMSIZE = 1024, parameter INS_MEMSIZE = 1024, parameter MAX_INSADDR = 32'hffff_fff8)
              (clk, rst);
    input clk, rst;
    wire clr, stall;

    wire [31:0] PC, MIPS_INS, NPC;
    
    wire [15:0] IMM;
    wire [25:0] j_IMM;
    wire [5:0] Op, funct;
    wire [4:0] rs, rt, rd, shamt;

    wire [10:0] microIns;
    wire [5:0] EX_insType, MEM_insType;
    wire [4:0] EX_WBDest, MEM_WBDest;

    wire signExt;
    wire [4:0] ALUOp;
    wire ALU_mux1;
    wire [1:0] ALUFOp1;          // ALU input1 ForwardOp
    wire [1:0] ALU_mux2;
    wire [1:0] ALUFOp2;          // ALU input2 ForwardOp
    wire [31:0] extImm;  
    wire [31:0] ALU_input1, ALU_input2;
    wire [31:0] ALU_output;
    wire zero;                   // not used temporarily

    wire RFWr;                   // register file write-signal
    wire mux_WBData;             // mux signal to select WBData

    wire [31:0] WBData;          // data to be written back
    wire [31:0] rsv, rtv;        // value of rs/rv

    wire [31:0] mem_output;
    wire MEMWr, loadSignExt;
    wire [1:0] MEMOp;

    wire [31:0] MEMWr_Data;      // delayed copy of latest rtv

    // hazard control
    wire [31:0] linkAddr;
    wire [1:0] linkOp;
    wire [1:0] IFJumpOp;
    wire [2:0] IDJumpOp;
    // useful for many modules
    wire [1:0] mux_new_rtv;      // signal to select latest rtv
    wire [1:0] mux_new_rsv;
    wire [31:0] new_rtv;         // selected new rtv
    wire [31:0] new_rsv;
    // no use
    // wire [1:0] JROp;   

    /************************************* PC *************************************/
    // PC
    PC pc(clk, rst, stall, NPC, PC);

    // next PC
    // MIPS_INS[25:0] is actually imm of instruction at IF stage; j_IMM is from ID stage
    NPC #(MAX_INSADDR)nextPC(PC, MIPS_INS[25:0], j_IMM,        
                             new_rsv, IFJumpOp, IDJumpOp, 
                             NPC);

    /************************************* IF *************************************/
    // fetch instruction
    insMem #(INS_MEMSIZE) instruction_mem(PC, MIPS_INS);

    /************************************* ID *************************************/
    // dispatch instruction fetched earlier; information released in the 2nd cycle
    decoder MIPS_INS_dispatcher(clk, clr, stall, MIPS_INS, 
                                IMM, j_IMM, Op, rs, rt, rd, shamt, funct);

    // code information(from 'decoder') into mirco-instruction(an extract of instruction)
    // information released in the 2nd cycle, right after 'MIPS_INS_dispatcher'
    microCoder micro_coder(Op, funct, rt, rd, microIns);

    // transfer micro-instruction for further usage; information released **from** the 3rd cycle
    microTransfer micro_transfer(clk, stall, microIns, 
                                 EX_insType, MEM_insType, EX_WBDest, MEM_WBDest);

    // register file; rsv & rtv released in the 2nd cycle
    // MEM_WBDest: indicated WBDest of instruction currently at MEM stage
    // ...will be used for next stage(WB)
    RF register_file(clk, rst, RFWr, rs, rt, MEM_WBDest, WBData, rsv, rtv);

    // mux_new_rtv is decided by 'dataHazardCtrl' module
    mux4 #(32)rsv_selector(rsv, ALU_output, mem_output, 32'bx, mux_new_rsv, new_rsv);

    // mux_new_rtv is decided by 'dataHazardCtrl' module
    mux4 #(32)rtv_selector(rtv, ALU_output, mem_output, 32'bx, mux_new_rtv, new_rtv);

    // push possible records into link address queue
    LinkQueue linkAddrQueue(clk, linkOp, PC, linkAddr);

    /************************************* EX *************************************/
    // EX-stage signals; module directly relys on micro-instruction coded
    // information released in the 2nd cycle(right before the 3rd cycle)
    EXMicroDecorder EX_micro_decoder(microIns[10:5], 
                                     signExt, ALUOp, ALU_mux1, ALU_mux2);

    // ALU input 1; specialized selector; ALUFOp1 is decided by 'dataHazardCtrl' module
    // ALUSel1 ALU_selector1(rsv, rtv, ALU_output, mem_output,  // inputs
    //                       ALU_mux1, ALUFOp1,                 // selection control
    //                       ALU_input1);                       // output
    mux2 #(32)ALU_selector1(new_rsv, new_rtv, ALU_mux1, ALU_input1);

    // immediate number extension
    EXT imm_extension(IMM, signExt, extImm);

    // ALU input 2; specialized selector; ALUFOp2 is decided by 'dataHazardCtrl' module
    // ALUSel2 ALU_selector2(rtv, extImm, rsv[4:0], shamt,      // original mux inputs
    //                       ALU_output, mem_output,            // possible forwarding candidates
    //                       ALU_mux2, ALUFOp2,                 // selection control
    //                       ALU_input2);                       // output
    mux4 #(32)ALU_selector2(new_rtv, extImm, {27'd0, new_rsv[4:0]}, {27'd0, shamt}, ALU_mux2, ALU_input2);

    // ALU; information released in the 3nd cycle
    alu ALU(clk, ALU_input1, ALU_input2, ALUOp, ALU_output, zero);

    /************************************* MEM ************************************/
    // MEM-stage signals released in the 3nd cycle
    // EX_insType instands for instruction type of current EX-stage
    // ...which is used to calculate signals in the next MEM-stage
    MEMMicroDecorder MEM_micro_decoder(EX_insType, MEMWr, MEMOp, loadSignExt);

    // delayed queue of data to be stored
    DelayQueue #(32, 1)delay_queue_mem_write(clk, new_rtv, MEMWr_Data);

    // memory
    memory #(MEMSIZE)mem(MEMWr, clk, loadSignExt, ALU_output, MEMOp, MEMWr_Data, mem_output);

    /************************************* WB *************************************/
    // WB-stage signals released in the 4nd cycle
    WBMicroDecorder WB_micro_decoder(MEM_insType, RFWr, mux_WBData);

    // select WBData; No need to select WBSel by mux
    mux2 #(32)WBData_selector(mem_output, linkAddr, mux_WBData, WBData);

    /******************************** Data Hazard *********************************/
    // detect data hazard and release related signals
    // insType: current insType at ID stage(directly fetched from higher bits of microIns)
    // microIns is released in the 2nd cycle
    dataHazardCtrl data_hazard_ctrl(microIns[10:5], EX_insType,
                                    rs, rt, EX_WBDest, MEM_WBDest, 
                                    mux_new_rsv, mux_new_rtv, stall);

    /******************************* Control Hazard *******************************/
    // release signals related to jump
    jumpCtrl jump_ctrl(.IFINSOp  (MIPS_INS[31:26]),  // input
                       .insType  (microIns[10:5]),   // input
                       .rsv      (new_rsv),          // input
                       .rtv      (new_rtv),          // input
                       .IFJumpOp (IFJumpOp),         // output from there on
                       .IDJumpOp (IDJumpOp), 
                       .linkOp   (linkOp), 
                       .clr      (clr));

endmodule