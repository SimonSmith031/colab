        addi $a1, $zero, 0x8
        addi $s2, $zero, 0x8
        add  $s6, $s2, $s2
        add  $s2, $s2, $s6
        and  $t3, $a1, $s2
        beq  $t3, $zero, L00
        beq  $t3, $s2, L11
        addi $s2, $zero, 0x8
        beq  $t3, $s2, L01
        sw   $t1, 0x10($zero)  #10
        j end
L00:    addi $t0, $zero, 0x0
        sw   $t0, 0x0($zero)
        j end
L01:    addi $t0, $zero, 0x1
        sw   $t0, 0x0($zero)
        j end
L11:    addi $t0, $zero, 0x3
        sw   $t0, 0x0($zero)
        j end
        addi $t0, $t0, 0x1
        addi $t0, $t0, 0x1
        addi $t0, $t0, 0x1
end:    add  $zero, $zero, $zero
        