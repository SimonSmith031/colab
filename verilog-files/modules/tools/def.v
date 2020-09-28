// WBSel
// 普通情况：rt或者rd，直接赋值；下面是两种特殊情况
`define WBSEL_NOP 5'd0
`define WBSEL_RA  5'd31

// ALUInput1
// 现在不再承担转发的功能
`define ALU_INPUT1_RSV    1'b0
`define ALU_INPUT1_SHAMT  1'b1

// ALUInput2
`define ALU_INPUT2_RTV   1'b0
`define ALU_INPUT2_IMM   1'b1

// mux_WBData
`define WBDATA_ALU     2'b00
`define WBDATA_MEM     2'b01
`define WBDATA_PCPLUS4 2'b10

// MEMOp
// 现在不提供转发的功能
`define MEMOP_BYTE      2'b01
`define MEMOP_HALFWORD  2'b10
`define MEMOP_WORD      2'b11

// Data Hazard: 选择寄存器的最新值的信号（寄存器组读出、ALU输出、mem输出）
`define REG_VALUE_RF        3'b000 // 正常情况
`define REG_VALUE_ALU       3'b001
`define REG_VALUE_MEM       3'b010 // 表示从mem中取得的数据直接用来作寄存器的值输入
`define REG_VALUE_ALUREG    3'b011
`define REG_VALUE_PCPLUS4_2 3'b100
`define REG_VALUE_PCPLUS4_3 3'b101

/**************************************************
 *                  ALU功能编号                   *
 **************************************************/
// `define ALU_FORWARD 5'd0      // 把第一个输入转发
// 模块设计调整，ALU不再提供转发功能
`define ALU_NOP   5'd0

`define ALU_ADD   5'b00001
`define ALU_SUB   5'b00010 
`define ALU_ADDU  5'b00011
`define ALU_SUBU  5'b00100

`define ALU_AND   5'b00101
`define ALU_OR    5'b00110
`define ALU_XOR   5'b00111
`define ALU_NOR   5'b01000

`define ALU_SLT   5'b01001
`define ALU_SLTU  5'b01010

`define ALU_SLL   5'b01011
`define ALU_SRA   5'b01101
`define ALU_SRL   5'b01111

`define ALU_LUI   5'b10000

`define ALU_BEQ   5'b10001
`define ALU_BNE   5'b10010
`define ALU_BLEZ  5'b10011
`define ALU_BGTZ  5'b10100
`define ALU_BLTZ  5'b10101
`define ALU_BGEZ  5'b10110

/**************************************************
 *                MIPS机器代码编号                *
 **************************************************/
// 定义OP
`define OP_ADDI  6'h8
`define OP_ORI   6'hd
`define OP_XORI  6'he
`define OP_ADDIU 6'h9
`define OP_ANDI  6'hc
`define OP_LUI   6'hf
`define OP_SLTI  6'ha
`define OP_SLTIU 6'hb

`define OP_LW    6'h23
`define OP_LB    6'h20
`define OP_LH    6'h21
`define OP_LBU   6'h24
`define OP_LHU   6'h25
`define OP_SB    6'h28
`define OP_SH    6'h29
`define OP_SW    6'h2b

`define OP_BEQ   6'h4
`define OP_BNE   6'h5
`define OP_BLEZ  6'h6
`define OP_BLTZ_BGEZ 6'h1
`define OP_BGTZ  6'h7

`define OP_J     6'h2
`define OP_JAL   6'h3

// 定义funct
`define FUNCT_JR   6'h8
`define FUNCT_JALR 6'h9

`define FUNCT_ADD  6'h20
`define FUNCT_ADDU 6'h21
`define FUNCT_SUB  6'h22
`define FUNCT_SUBU 6'h23
`define FUNCT_AND  6'h24
`define FUNCT_OR   6'h25
`define FUNCT_XOR  6'h26
`define FUNCT_NOR  6'h27
`define FUNCT_SLT  6'h2a
`define FUNCT_SLTU 6'h2b

`define FUNCT_SLL  6'd0
`define FUNCT_SLLV 6'd4
`define FUNCT_SRA  6'd3
`define FUNCT_SRAV 6'd7
`define FUNCT_SRL  6'd2
`define FUNCT_SRLV 6'd6

