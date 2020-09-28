    lui $v1, 0xf000 		    #r3=0xF0000000
    lui $a0, 0xe000 		    #r4=0xE0000000
    lui $v0, 0x20       #设置v0作为倒数计时器的初始大小
    add $t0, $zero, $zero       #设置初始位置为左上角的位置，这个值在后面的过程中不要改变，只是用来做计算
    lw $a1, 0($v1) 		        #读GPIO端口F0000000:{counter0_out,counter1_out,counter2_out,led_out[12:0], SW}
    sll $a1, $a1, 2             #左移2位将SW与LED对齐，同时计数器通道0
    sw $a1, 0($v1) 			    #r5输出到GPIO端口0xF0000000
    lw $s5, 0($zero)
    sw $s5, 0($a0)              # 刷新数码管（第一次）
    add $t5, $zero, $v0         # 重置倒计时数

start:
    lw $a1, 0($v1) 		        #读GPIO端口F0000000:{counter0_out,counter1_out,counter2_out,led_out[12:0], SW}
    add $a1, $a1, $a1 		    #左移
    add $a1, $a1, $a1 		    #左移2位将SW与LED对齐，计数器通道0
    sw $a1, 0($v1) 			    #r5输出到GPIO端口0xF0000000
    sll $t2, $t0, 2
    lw $s5, 0($t2)
    sw $s5, 0($a0)              #刷新数码管
    addi $t5, $t5, -1			#倒计时
    bne $t5, $zero, check
    jal flush

check: lw $a1, 0($v1)
    addi $s2, $zero, 0x0008 	#r18=0x00000008
    add $s6, $s2, $s2 			#r22=0x00000010
    add $s2, $s2, $s6 			#r18=0x00000018(00011000b)
    and $t3, $a1, $s2 			#取SW[4:3]
    beq $t3, $zero, L00 		#SW[4:3]=00
    beq $t3, $s2, L11 			#SW[4:3]=11
    addi $s2, $zero, 0x0008 	#r18=8
    beq $t3, $s2, L01 			#SW[4:3]=01

L10: # 向上
    add $zero, $zero, $zero
    add $zero, $zero, $zero
    addi $s4, $t0, 4
    andi $s4, $s4, 7            # mod 8
    j start

L00: # 向右
    add $zero, $zero, $zero
    add $zero, $zero, $zero
    addi $s4, $t0, 1
    andi $s4, $s4, 7            # mod 8
    j start

L11: # 向左
    add $zero, $zero, $zero
    add $zero, $zero, $zero
    addi $s4, $t0, 7
    andi $s4, $s4, 7            # mod 8
    j start

L01: # 向下
    add $zero, $zero, $zero
    add $zero, $zero, $zero
    addi $s4, $t0, 4
    andi $s4, $s4, 7            # mod 8
    j start

flush:
    add $t0, $s4, $zero         # 更新当前位置
    add $t5, $zero, $v0         # 重置倒计时数
    jr $ra