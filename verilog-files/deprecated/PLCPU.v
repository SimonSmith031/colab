// Pipeline CPU Combination (Top Layer)
module PLCPU #(parameter MEMSIZE = 1024, parameter INS_MEMSIZE = 1024, parameter MAX_INSADDR = 32'hffff_fff8)
              (clk, rst);
    input clk, rst; // 从外部引入最重要的两个控制信号

    wire stall, clr;

    wire [31:0] NPC;
    wire [31:0] PC;
    wire [31:0] INS;

    wire [15:0] imm;
    wire [5:0]  Op, funct;
    wire [4:0]  rs, rt, rd;
    wire [4:0]  shamt;

    // 中央控制单元的一些控制信号
    wire       signExt;
    wire [4:0] ALUOp;
    wire [1:0] ALU_mux1;
    wire       ALU_mux2;
    wire       MEMWr;         // 写MEM的信号
    wire [1:0] MEMOp;         
    wire       loadSignExt;   // load的扩展方式
    wire [4:0] WBSel;      

    // 中央控制单元提供给数据冲突分析模块的信号
    wire use_rs, use_rt, is_load_ins;

    // 寄存器组模块相关
    wire [31:0] rf_rsv, rf_rtv;
    wire [1:0]  mux_WBData;   // 写回的选择信号
    wire [31:0] WBData;       // 写回的值，通过多路选择器选择

    // alu
    reg  [15:0] imm16_reg; // 为了能够让ALU的立即数输入保持稳定，需要寄存

    wire        zero;         // 这个信号目前没有被实际使用
    wire [31:0] ALU_input1, ALU_input2;
    wire [31:0] ALU_output;
    wire [31:0] imm32;        // 被扩展之后的立即数（来源是指令中的16位立即数）
    reg  [31:0] ALU_input_reg, ALU_input2_reg;
    reg  [31:0] ALU_output_reg; // for writing back into RF
    
    // mem模块
    wire [31:0] mem_output;
    reg  [31:0] mem_input; // mem的输入是rtv，但是需要寄存
    // 用来寄存mem的输出，这是因为mem的输出在下一个周期开始之后就会改变了
    reg  [31:0] mem_out_reg;

    // 写回的信号要寄存
    reg [4:0]  WBSel_reg;
    reg        RFWr_reg;
    reg [31:0] PCPLUS4_1, PCPLUS4_2, PCPLUS4_3;
    
    // 数据竞争
    wire [31:0] rtv;
    wire [31:0] rsv;
    wire [1:0]  mux_rsv, mux_rtv;

    // 分支控制
    wire        ID_branch_result;

    // IF
    // PC
    PC pc(.clk   (clk),    
          .rst   (rst), 
          .stall (stall), 
          .NPC   (NPC), 
          .PC    (PC));       // the only output

    // 寄存PC的几级寄存器，最后在jal和jalr的WB阶段有用
    initial begin
        PCPLUS4_1 <= 32'd0;
        PCPLUS4_2 <= 32'd0;
        PCPLUS4_3 <= 32'd0;
    end
    always @(posedge clk) begin
        PCPLUS4_1 <= (PC + 32'd4);
        PCPLUS4_2 <= PCPLUS4_1;
        PCPLUS4_3 <= PCPLUS4_2;
    end

    // 指令寄存器
    ins_mem #(INS_MEMSIZE) imem (.PC(PC), .INS(INS));

    // ID
    decoder distributor(.clk   (clk), 
                        .clr   (clr), 
                        .stall (stall), 
                        .INS   (INS),        // 前面四个是输入，后面是输出
                        .IMM   (imm), 
                        .Op    (Op), 
                        .rs    (rs), 
                        .rt    (rt), 
                        .rd    (rd), 
                        .shamt (shamt), 
                        .funct (funct));

    ctrl control (.clk         (clk),
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

    // 关于信号的寄存：只需要把写回的信号寄存一下
    initial begin
        WBSel_reg <= 5'd0;
        RFWr_reg  <= 1'b0;
    end
    always @(posedge clk) begin
        WBSel_reg <= WBSel;
        RFWr_reg  <= RFWr;
    end

    // 寄存器组
    RF rf(.clk   (clk), 
          .rst   (rst),
          .RFWr  (RFWr_reg),   // 这个信号要用寄存后的
          .A1    (rs), 
          .A2    (rt), 
          .WBSel (WBSel_reg),  // 这个信号要用寄存后的
          .WD    (WBData), 
          .RD1   (rf_rsv), 
          .RD2   (rf_rtv));

    // EX
    // 立即数扩展装置，需要先寄存一下输入
    initial imm16_reg <= 16'd0;
    always @(posedge clk) begin
        imm16_reg <= imm;
    end

    imm_ext imm_extension(.Imm16   (imm16_reg),
                          .signExt (signExt), 
                          .Imm32   (imm32));

    // alu两个输入的多路选择器
    mux2 #(32) alu_input1_mux(.d0 (rsv), 
                              .d1 ({27'd0, shamt}),
                              .s  (ALU_mux1), 
                              .y  (ALU_input1));

    mux2 #(32) alu_input2_mux(.d0 (rtv), 
                              .d1 (imm32),
                              .s  (ALU_mux2), 
                              .y  (ALU_input2));

    // regs before alu
    initial begin
        ALU_input1_reg <= 32'd0;
        ALU_input2_reg <= 32'd0;
    end

    always @(posedge clk) begin
        ALU_input1_reg <= ALU_input1;
        ALU_input2_reg <= ALU_input2;
    end

    // ALU
    alu ALU(.A     (ALU_input1_reg), 
            .B     (ALU_input2_reg),
            .ALUOp (reg_ALUOp),
            .C     (ALU_output),
            .zero  (zero));

    // reg after ALU (save output)
    initial ALU_output_reg <= 32'd0; // for writing back into RF
    always @(posedge clk) begin
        ALU_output_reg <= ALU_output;
    end

    // MEM
    initial mem_input <= 32'd0;
    always @(posedge clk) begin
        mem_input <= rtv;
    end

    memory #(MEMSIZE) dmem (.memWrite    (MEMWr), 
                            .clk         (clk), 
                            .loadSignExt (loadSignExt), 
                            .addr        (ALU_output), 
                            .memop       (MEMOp), 
                            .A           (mem_input),     // 是rtv寄存了一个周期传过来的结果
                            .B           (mem_output));

    // 寄存输出的结果
    /* 关于为什么mem也要寄存输出结果，因为mem是随时可以读的，
       而ALU输出地址之后下一个周期地址会变，那么读出来的数据也会变化 */
    always @(posedge clk) begin
        mem_out_reg <= mem_output;
    end

    // 写回的数据选择
    mux3 #(32) WBData_selector(.d0 (ALU_output_reg),
                               .d1 (mem_output_reg),
                               .d2 (PCPLUS4_3),
                               .s  (mux_WBData), 
                               .y  (WBData));

    // 数据竞争检查
    data_hazard_detector data_hazard_checker(.Op        (Op), 
                                             .rs        (rs), 
                                             .rt        (rt), 
                                             .funct     (funct), 
                                             .EX_WBSel  (WBSel), 
                                             .MEM_WBSel (WBSel_reg), // 用的是接下来要寄存的那个
                                             .mux_rsv   (mux_rsv), 
                                             .mux_rtv   (mux_rtv), 
                                             .stall     (stall));

    // 选择解决了数据竞争的rsv和rtv
    /* 注意一下alu和mem的寄存含义，alu的寄存是为了WB，但是它的真实输出就是ALU_output，
       但是mem的寄存器是因为ALU地址变化导致读取不稳才添加的，相当于算作是mem的真实输出
       不过最后WB时，两者都是用其寄存器 */
    mux3 #(32) rsv_selector(.d0 (rf_rsv),
                            .d1 (ALU_output), 
                            .d2 (mem_out_reg),
                            .s  (mux_rsv), 
                            .y  (rsv));

    mux3 #(32) rtv_selector(.d0 (rf_rtv), 
                            .d1 (ALU_output), 
                            .d2 (mem_out_reg),
                            .s  (mux_rtv), 
                            .y  (rtv));

    // 跳转控制
    ID_branch_checker branch_checker(.rsv          (rsv), 
                                     .rtv          (rtv), 
                                     .Op           (Op),
                                     .rt           (rt),   
                                     .branch_taken (ID_branch_result));

    jump_ctrl #(MAX_INSADDR) branch_hazard_ctrl(.clk               (clk), 
                                                .rst               (rst), 
                                                .ID_branch_taken   (ID_branch_result), 
                                                .PC                (PC), 
                                                .INS               (INS), 
                                                .jr_addr           (rsv), 
                                                .NPC               (NPC), 
                                                .clr               (clr)); 

endmodule