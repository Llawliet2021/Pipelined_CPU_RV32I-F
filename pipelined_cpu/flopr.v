// ============================================================================
// flopr.v - 带同步复位的参数化宽度触发器
// 用于流水线寄存器、PC寄存器等所有需要时钟边沿触发的存储单元。
// ============================================================================

module flopr #(
    parameter WIDTH = 32
) (
    input  wire                   clk,
    input  wire                   reset,
    input  wire [WIDTH-1:0]       d,
    output reg  [WIDTH-1:0]       q
);
    // 初始化为0，避免x值传播
    initial q = {WIDTH{1'b0}};

    always @(posedge clk or posedge reset) begin
        if (reset)
            q <= {WIDTH{1'b0}};
        else
            q <= d;
    end
endmodule

// ============================================================================
// flopenr - 带使能和同步复位的触发器
// 用于需要停顿(stall)的流水线寄存器（如IF/ID），使能无效时保持原值。
// ============================================================================

module flopenr #(
    parameter WIDTH = 32
) (
    input  wire                   clk,
    input  wire                   reset,
    input  wire                   en,
    input  wire [WIDTH-1:0]       d,
    output reg  [WIDTH-1:0]       q
);
    // 初始化为0，避免x值传播
    initial q = {WIDTH{1'b0}};

    always @(posedge clk or posedge reset) begin
        if (reset)
            q <= {WIDTH{1'b0}};
        else if (en)
            q <= d;
    end
endmodule

// ============================================================================
// floprc - 带同步复位和清零的触发器
// 用于需要刷新(flush)的流水线寄存器（如ID/EX），清零时输出全0。
// ============================================================================

module floprc #(
    parameter WIDTH = 32
) (
    input  wire                   clk,
    input  wire                   reset,
    input  wire                   clear,
    input  wire [WIDTH-1:0]       d,
    output reg  [WIDTH-1:0]       q
);
    // 初始化为0，避免x值传播
    initial q = {WIDTH{1'b0}};

    always @(posedge clk or posedge reset) begin
        if (reset)
            q <= {WIDTH{1'b0}};
        else if (clear)
            q <= {WIDTH{1'b0}};
        else
            q <= d;
    end
endmodule
