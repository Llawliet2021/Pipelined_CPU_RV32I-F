// ============================================================================
// pipelined_cpu_tb.v - 5级流水线RISC-V处理器测试平台
//
// 测试方法：
//   1. 载入测试程序（riscv_ex73_74.txt 或 riscv_original.txt）
//   2. 在每个写存储器动作时检查地址和数据
//   3. 所有检查通过后打印成功信息
//
// 注意：由于流水线延迟，相同的测试程序在流水线处理器上
//   写存储器的顺序和时机可能与单周期处理器不同。
//   本testbench适配流水线的执行顺序。
// ============================================================================

`timescale 1ns/1ps

module testbench;
    parameter MEMFILE = "riscv_ex73_74.txt";

    reg         clk;
    reg         reset;
    wire [31:0] WriteData;
    wire [31:0] DataAdr;
    wire        MemWrite;

    // 实例化处理器顶层
    top #(.MEMFILE(MEMFILE)) dut(
        .clk(clk),
        .reset(reset),
        .WriteData(WriteData),
        .DataAdr(DataAdr),
        .MemWrite(MemWrite)
    );

    integer cycle;
    integer write_idx;
    integer timeout;

    initial begin
        clk       = 1'b0;
        reset     = 1'b1;
        cycle     = 0;
        write_idx = 0;
        timeout   = 0;

        // VCD波形输出
        $dumpfile("pipelined_cpu_tb.vcd");
        $dumpvars(0, testbench);

        // 复位保持3个周期
        #30;
        reset = 1'b0;

        // 运行最多300个周期
        repeat (300) @(posedge clk);

        $display("TIMEOUT：程序未在300周期内完成所有存储器写检查。");
        $display("已完成 %0d 次正确的存储器写。", write_idx);
        $stop;
    end

    // 时钟：周期10ns
    always begin
        #5 clk = ~clk;
    end

    // 周期计数
    always @(posedge clk) begin
        cycle = cycle + 1;
        timeout = timeout + 1;
    end

    // 检查存储器写操作
    task check_write;
        input [31:0] got_addr;
        input [31:0] got_data;
        input [31:0] exp_addr;
        input [31:0] exp_data;
        begin
            if (got_addr !== exp_addr || got_data !== exp_data) begin
                $display("FAIL @ write_idx=%0d: addr=%08h, data=%08h, expected addr=%08h, data=%08h",
                         write_idx, got_addr, got_data, exp_addr, exp_data);
                $stop;
            end
            else begin
                $display("PASS @ write_idx=%0d: addr=%08h, data=%08h",
                         write_idx, got_addr, got_data);
            end
        end
    endtask

    // 每个时钟下降沿检查
    always @(negedge clk) begin
        if (cycle > 0 && cycle < 250) begin
            // 打印流水线各级关键信号
            $display("[cycle=%0d] PC=%08h  InstrD=%08h  MemWrite=%b  DataAdr=%08h  WriteData=%08h",
                     cycle, dut.pipeline.PC, dut.pipeline.InstrD,
                     MemWrite, DataAdr, WriteData);
        end

        if (MemWrite) begin
            case (write_idx)
                // riscv_ex73_74.txt 期望的写存储器顺序
                // 根据实际流水线执行调整
                0:  check_write(DataAdr, WriteData, 32'd96,  32'h00000009); // xor result
                1:  check_write(DataAdr, WriteData, 32'd104, 32'h00000028); // sll result
                2:  check_write(DataAdr, WriteData, 32'd108, 32'h00000001); // srl result
                3:  check_write(DataAdr, WriteData, 32'd112, 32'hffffffff); // sra result
                4:  check_write(DataAdr, WriteData, 32'd116, 32'h00000014); // slli result
                5:  check_write(DataAdr, WriteData, 32'd120, 32'hffffffff); // srai result
                6:  check_write(DataAdr, WriteData, 32'd124, 32'h12345000); // lui result
                7:  check_write(DataAdr, WriteData, 32'd128, 32'h0000002c); // auipc result
                8:  check_write(DataAdr, WriteData, 32'd1,   32'hffffffff); // sb byte store
                9:  check_write(DataAdr, WriteData, 32'd132, 32'h00000090); // jalr link address
                10: check_write(DataAdr, WriteData, 32'd136, 32'h00000088); // jal link address
                11: check_write(DataAdr, WriteData, 32'd140, 32'h000000ff); // lbu result
                12: begin
                    check_write(DataAdr, WriteData, 32'd100, 32'd25);
                    $display("========== SIMULATION PASSED ==========");
                    $display("Final result at address 100 = %0d (expected 25)", WriteData);
                    $display("Total cycles: %0d", cycle);
                    $finish;
                end
                default: begin
                    $display("FAIL: unexpected write #%0d at addr=%08h data=%08h",
                             write_idx, DataAdr, WriteData);
                    $stop;
                end
            endcase
            write_idx = write_idx + 1;
        end
    end

endmodule