// ============================================================================
// basic.v - 基础运算模块：加法器、立即数扩展、ALU、寄存器堆
// ============================================================================

// 32位加法器
module adder (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] y
);
    assign y = a + b;
endmodule

// 立即数扩展单元
// ImmSrc: 3'b000=I型, 3'b001=S型, 3'b010=B型, 3'b011=U型, 3'b100=J型
module extend (
    input  wire [31:7] instr,
    input  wire [2:0]  immsrc,
    output reg  [31:0] immext
);
    always @(*) begin
        case (immsrc)
            3'b000: immext = {{20{instr[31]}}, instr[31:20]};                          // I型
            3'b001: immext = {{20{instr[31]}}, instr[31:25], instr[11:7]};             // S型
            3'b010: immext = {{19{instr[31]}}, instr[31], instr[7], instr[30:25],      // B型
                              instr[11:8], 1'b0};
            3'b011: immext = {instr[31:12], 12'b0};                                     // U型
            3'b100: immext = {{11{instr[31]}}, instr[31], instr[19:12], instr[20],      // J型
                              instr[30:21], 1'b0};
            default: immext = 32'bx;
        endcase
    end
endmodule

// ALU
// ALUControl:
//   4'b0000: add     4'b0001: sub     4'b0010: and
//   4'b0011: or      4'b0100: xor     4'b0101: slt (signed)
//   4'b0110: sltu    4'b0111: sll     4'b1000: srl
//   4'b1001: sra
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alucontrol,
    output reg  [31:0] result,
    output wire        zero
);
    always @(*) begin
        case (alucontrol)
            4'b0000: result = a + b;                                      // add
            4'b0001: result = a - b;                                      // sub
            4'b0010: result = a & b;                                      // and
            4'b0011: result = a | b;                                      // or
            4'b0100: result = a ^ b;                                      // xor
            4'b0101: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // slt (signed)
            4'b0110: result = (a < b) ? 32'd1 : 32'd0;                   // sltu
            4'b0111: result = a << b[4:0];                               // sll
            4'b1000: result = a >> b[4:0];                               // srl
            4'b1001: result = $signed(a) >>> b[4:0];                     // sra
            default: result = 32'bx;
        endcase
    end

    assign zero = (result == 32'b0);
endmodule

// 寄存器堆 (32 x 32bit)
module regfile (
    input  wire        clk,
    input  wire        we3,
    input  wire [4:0]  a1,
    input  wire [4:0]  a2,
    input  wire [4:0]  a3,
    input  wire [31:0] wd3,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] rf [0:31];

    // 初始化为0，避免仿真中出现x值
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            rf[i] = 32'b0;
    end

    // 读组合逻辑
    assign rd1 = (a1 != 0) ? rf[a1] : 32'b0;
    assign rd2 = (a2 != 0) ? rf[a2] : 32'b0;

    // 写时序逻辑：在下降沿写入，确保上升沿采样前寄存器已更新
    always @(negedge clk) begin
        if (we3 && a3 != 0)
            rf[a3] <= wd3;
    end
endmodule