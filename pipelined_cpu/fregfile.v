// ============================================================================
// fregfile.v — 浮点寄存器堆 (32 x 32bit, 3读1写)
// 写: negedge clk, 读: 组合逻辑
// ============================================================================

module fregfile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  a1,      // read addr fs1
    input  wire [4:0]  a2,      // read addr fs2
    input  wire [4:0]  a3,      // read addr fs3 (for R4 fused ops)
    input  wire [4:0]  waddr,   // write addr fd
    input  wire [31:0] wd,      // write data
    output wire [31:0] rd1,     // fs1
    output wire [31:0] rd2,     // fs2
    output wire [31:0] rd3      // fs3
);
    reg [31:0] rf [0:31];
    integer i;
    initial for (i = 0; i < 32; i = i + 1) rf[i] = 32'd0;

    assign rd1 = rf[a1];
    assign rd2 = rf[a2];
    assign rd3 = rf[a3];   // third read port

    always @(negedge clk) begin
        if (we) rf[waddr] <= wd;
    end
endmodule