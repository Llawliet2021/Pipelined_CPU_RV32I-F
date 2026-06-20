// tb_runner.v — reads .txt, checks every store against .ans
// Dynamic entries: addr=FFFFFFFF → pass if data != 0
`timescale 1ns/1ps
module testbench;
    parameter MEMFILE = "ftest_instructions.txt";
    parameter ANSFILE = "ftest_ans.txt";
    parameter EXP_NUM = 27;

    reg clk, reset;
    wire [31:0] WD, A;
    wire W;
    top #(.MEMFILE(MEMFILE)) dut(.clk(clk),.reset(reset),.WriteData(WD),.DataAdr(A),.MemWrite(W));

    integer cyc, wcnt, fail, pass_;
    reg [31:0] last_pc; integer psame;
    reg [31:0] exp_buf [0:255];

    initial begin
        clk=0; reset=1; cyc=0; wcnt=0; fail=0; pass_=0; last_pc=32'hFFFFFFFF; psame=0;
        $readmemh(ANSFILE, exp_buf, 0, EXP_NUM*2-1);
        $dumpfile("tb_runner.vcd"); $dumpvars(0,testbench);
        #30; reset=0;
        $display("===== PIPELINE CPU TEST =====");
        $display("  MEMFILE: %0s  ANSFILE: %0s  EXP_NUM: %0d", MEMFILE, ANSFILE, EXP_NUM);
        repeat(3000) @(posedge clk);
        finish_test(); $stop;
    end
    always #5 clk=~clk;
    always @(posedge clk) begin
        cyc=cyc+1;
        if(!reset) begin
            if(dut.PC==last_pc) psame=psame+1; else begin psame=0; last_pc=dut.PC; end
            if(psame>=12) begin @(negedge clk); finish_test(); $stop; end
        end
    end

    always @(negedge clk) begin
        if(!reset && W) begin
            $display("[W#%0d c=%0d] A=%08h D=%08h", wcnt, cyc, A, WD);
            if(wcnt < EXP_NUM) begin
                if(exp_buf[wcnt*2]==32'hFFFFFFFF) begin
                    if(WD!=0) begin $display("  PASS (dyn)"); pass_=pass_+1; end
                    else      begin $display("  FAIL dyn=0"); fail=fail+1; end
                end else if(A==exp_buf[wcnt*2] && WD==exp_buf[wcnt*2+1]) begin
                    $display("  PASS"); pass_=pass_+1;
                end else begin
                    $display("  FAIL exp A=%08h D=%08h", exp_buf[wcnt*2], exp_buf[wcnt*2+1]);
                    fail=fail+1;
                end
            end
            wcnt=wcnt+1;
        end
    end

    task finish_test;
        begin
            $display("========================================");
            $display("  Cycles:%0d  Writes:%0d  Exp:%0d  PASS:%0d  FAIL:%0d",
                     cyc, wcnt, EXP_NUM, pass_, fail);
            if(fail==0) $display("  RESULT: ALL PASSED");
            else        $display("  RESULT: %0d FAILURE(S)", fail);
            $display("========================================");
        end
    endtask
endmodule