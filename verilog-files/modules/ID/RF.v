`include "../tools/def.v"
module RF(input         clk, 
          input         rst,
          input         RFWr,
          input  [4:0]  A1, A2, WBSel,      // A1, A2: read; WBSel: write（本身能够告知是否写回，所以减除了RFWr信号）
          input  [31:0] WD, 
          output [31:0] RD1, RD2
          );  

    reg  [31:0]  rf[31:0];
    integer i;

    always @(posedge clk, posedge rst) begin
        if (rst) begin    //  reset
            for (i = 0; i < 32; i = i + 1)
                rf[i] <= 0;
            $display("Register file reset."); 
        end
        
        else begin
            if (RFWr && WBSel != 5'd0) begin
                rf[WBSel] <= WD;
                $display("r[%d] = 0x%8X,", WBSel, WD); 
            end
            else $display("No reg written in this cycle.");
        end
    end

    assign RD1 = (A1 != 0) ? rf[A1] : 0;
    assign RD2 = (A2 != 0) ? rf[A2] : 0;

endmodule 
