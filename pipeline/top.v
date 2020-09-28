`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    16:06:11 08/24/2020 
// Design Name: 
// Module Name:    top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module top(input        RSTN, 
           input  [3:0] BTN_y,
		   input [15:0] SW,
		   input        clk_100mhz,
		   output [4:0] BTN_x,
		   output       seg_clk,
		   output       seg_sout,
		   output       seg_pen,
		   output       seg_clrn,
		   output       led_clk,
		   output       led_sout,
		   output       led_pen,
		   output       led_clrn,
		   output       readn,
		   output       CR,
		   output       RDY);
		   
	wire   N0, V5;     // 一个接地，一个是高电压
	assign N0 = 1'b0;
	assign V5 = 1'b1;
    
    /* wire   clk_main;
    reg [2:0] clkdiv_main;
    initial   clkdiv_main <= 0;
    always @ (posedge clk_100mhz) begin 
		clkdiv_main <= clkdiv_main + 1'b1;
    end
    assign clk_main = clkdiv_main[2]; */
		   
	wire        MIO_ready, mem_w;
	wire        CPU_MIO, INT;
	wire [31:0] INS;
	wire [31:0] PC;
	
	wire        clk_cpu, rst;
    wire        clk_io;
    assign      clk_io = ~clk_cpu;
	wire [31:0] cpu_data_in, cpu_data_out;
	wire [31:0] addr;
	
	wire [9:0]  RAM_addr;
	wire [31:0] RAM_data_in, RAM_data_out;
	wire        RAM_we;  // we = write enable
	
	wire [3:0]  BTN, BTN_ok;
	wire [15:0] SW_ok;
	
	wire [15:0] LED_out;
	wire [31:0] counter_out;
	wire        counter0_out, counter1_out, counter2_out;
	assign INT = counter0_out;
	wire        counter_we;
	wire        SPIO_en;
	wire        Multi_8CH32_en;
	
	wire [31:0] counter_val;
	
	wire [31:0] div;
	wire [7:0]  point_out;
	wire [7:0]  LE_out;
	wire [31:0] disp_num;
	
	wire [1:0]  counter_ch;
	wire [13:0] GPIOf0;
	
	wire [4:0]  key_out;
	wire [7:0]  blink;
	wire [3:0]  pulse;
	
	wire [31:0] M4_Ai, M4_Bi; // 暂时不会被用到，但是要支持数据通路
	
	// 自己的流水线CPU核
	pcpu_core U1(.clk      (clk_cpu),			
			    .reset     (rst),
			    .MIO_ready (MIO_ready),			
			    .inst_in   (INS),
			    .Data_in   (cpu_data_in),
			    .mem_w     (mem_w),
			    .PC_out    (PC),
			    .Addr_out  (addr),
			    .Data_out  (cpu_data_out), 
			    .CPU_MIO   (CPU_MIO),
			    .INT       (INT));
			
	// ROM: 存储指令
	ROM_D U2(.a   (PC[11:2]),
			 .spo (INS)); 
	
	// RAM
	RAM_B U3(.addra (RAM_addr), 
			 .dina  (RAM_data_in), 
			 .wea   (RAM_we), 
			 .clka  (~clk_100mhz),     
			 .douta (RAM_data_out));
			 
	// BUS
	MIO_BUS U4(.clk             (clk_100mhz),
			   .rst             (rst),
			   .BTN             (BTN_ok),
			   .SW              (SW_ok),
			   .mem_w           (mem_w),
			   .Cpu_data2bus    (cpu_data_out),	        // data from CPU
			   .addr_bus        (addr),
			   .ram_data_out    (RAM_data_out),
			   .led_out         (LED_out),
			   .counter_out     (counter_out),
			   .counter0_out    (counter0_out),
			   .counter1_out    (counter1_out),
			   .counter2_out    (counter2_out),
			   .Cpu_data4bus    (cpu_data_in),			// write to CPU
			   .ram_data_in     (RAM_data_in),			// from CPU write to Memory
			   .ram_addr        (RAM_addr),				// Memory Address signals
			   .data_ram_we     (RAM_we),
			   .GPIOf0000000_we (SPIO_en),
			   .GPIOe0000000_we (Multi_8CH32_en),
			   .counter_we      (counter_we),
			   .Peripheral_in   (counter_val)
			   );
	
	// 八数据通路模块
	Multi_8CH32 U5(.clk       (clk_io),
				   .rst       (rst),
			   	   .EN        (Multi_8CH32_en),								// Write EN
				   .Test      (SW_ok[7:5]),						// ALU&Clock,SW[7:5]	
				   .point_in  ({div, div}),					// 针对8位显示输入各8个小数点
				   .LES       (64'd0),					// 针对8位显示输入各8个闪烁位
				   .Data0     (counter_val),					// disp_cpudata
				   .data1     ({N0, N0, PC[31:2]}),
				   .data2     (INS),
				   .data3     (counter_out),
				   .data4     (addr),
				   .data5     (cpu_data_out),
				   .data6     (cpu_data_in),
				   .data7     (PC),
				   .point_out (point_out),
				   .LE_out    (LE_out),
				   .Disp_num  (disp_num)
				   );
	
	SSeg7_Dev U6(.clk     (clk_100mhz),       //时钟 
				.rst      (rst),              //复位 
                .Start    (div[20]),          //串行扫描启动 
                .SW0      (SW_ok[0]),         //文本(16进制)/图型(点阵)切换 
                .flash    (div[25]),          //七段码闪烁频率 
                .Hexs     (disp_num),         //32位待显示输入数据 
                .point    (point_out),        //七段码小数点：8个 
                .LES      (LE_out),           //七段码使能：=1时闪烁 
                .seg_clk  (seg_clk),          //串行移位时钟 
                .seg_sout (seg_sout),         //七段显示数据(串行输出) 
                .SEG_PEN  (seg_pen),          //七段码显示刷新使能 
                .seg_clrn (seg_clrn)          //七段码显示归零 
                ); 

	SPIO U7(.clk         (clk_io),     //io_clk，与CPU反向 
			.rst         (rst), 
			.EN          (SPIO_en),      //来自U4 
			.P_Data      (counter_val),  //来自U4 
			.Start       (div[20]),      //串行输出启动 
			.counter_set (counter_ch),   //来自U7，后继用 
			.LED_out     (LED_out),      //输出到LED,回读到U4 
			.GPIOf0      (GPIOf0),       //备用   
			.led_clk     (led_clk),      //串行时钟 
			.led_sout    (led_sout),     //串行LEDE值 
			.LED_PEN     (led_pen),      //LED使能 
			.led_clrn    (led_clrn)      //LED清零 
			); 
			
	clk_div U8(.clk     (clk_100mhz), 
			   .rst     (rst), 
			   .SW2     (SW_ok[2]), 
			   .clkdiv  (div), 
			   .Clk_CPU (clk_cpu)
			   ); 
			  
	SAnti_jitter U9(.clk       (clk_100mhz), //主板时钟 
					.RSTN      (RSTN),
					.readn     (readn), //阵列式键盘读 
					.Key_y     (BTN_y),//阵列式键盘列输入 
					.Key_x     (BTN_x),  //阵列式键盘行输出 
					.Key_out   (key_out),//阵列式键盘扫描码 
					.Key_ready (RDY),  //阵列式键盘有效 
					.SW        (SW),   //开关输入 
					.BTN_OK    (BTN_ok),//列按键输出 
					.pulse_out (pulse),  //列按键脉冲输出 
					.SW_OK     (SW_ok), //开关输出 
					.CR        (CR),  //RSTN短按输出 
					.rst       (rst)    //复位， RSTN长按输出 
					); 
					
	Counter_x U10(.clk           (clk_io),      //io_clk 
			      .rst           (rst), 
			      .clk0          (div[6]),      //clk_div[7]，来自U8 
			      .clk1          (div[9]),      // clk_div[10]，来自U8 
			      .clk2          (div[11]),      //clk_div[10]，来自U8 
			      .counter_we    (counter_we),    //计数器写控制，来自U4 
			      .counter_val   (counter_val),        //计数器输入数据，来自U4 
			      .counter_ch    (counter_ch),             //计数器通道控制，来自U7
				  .counter0_OUT  (counter0_out),    //输出到U4
				  .counter1_OUT  (counter1_out),     //输出到U4 
				  .counter2_OUT  (counter2_out),     //输出到U4 
				  .counter_out   (counter_out)  //输出到U4 
				); 
	
	SEnter_2_32 M4( .clk     (clk_100mhz),
					.BTN     (BTN_ok[2:0]),				         //对应SAnti_jitter列按键
					.Ctrl    ({SW_ok[7:5], SW_ok[15], SW_ok[0]}),  //{SW[7:5],SW[15],SW[0]}
					.D_ready (RDY),					             //对应SAnti_jitter扫描码有效
					.Din     (key_out),
					.readn   (readn), 			//=0读扫描码
					.Ai      (M4_Ai),	//输出32位数一：Ai
					.Bi      (M4_Bi),	//输出32位数二：Bi
					.blink	 (blink)			//单键输入指示
					);
				
endmodule
