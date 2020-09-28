module imm_ext(Imm16, signExt, Imm32);
    
   input  [15:0] Imm16;
   input         signExt;
   output [31:0] Imm32;
   
   assign Imm32 = (signExt) ? {{16{Imm16[15]}}, Imm16} : {16'd0, Imm16}; // signed-extension or zero extension
       
endmodule
