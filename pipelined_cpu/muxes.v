// ============================================================================
// muxes.v - 参数化多路选择器
// ============================================================================

module mux2 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0]       d0,
    input  wire [WIDTH-1:0]       d1,
    input  wire                   s,
    output wire [WIDTH-1:0]       y
);
    assign y = s ? d1 : d0;
endmodule

module mux3 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0]       d0,
    input  wire [WIDTH-1:0]       d1,
    input  wire [WIDTH-1:0]       d2,
    input  wire [1:0]             s,
    output reg  [WIDTH-1:0]       y
);
    always @(*) begin
        case (s)
            2'b00:   y = d0;
            2'b01:   y = d1;
            2'b10:   y = d2;
            default: y = d0;
        endcase
    end
endmodule

module mux4 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0]       d0,
    input  wire [WIDTH-1:0]       d1,
    input  wire [WIDTH-1:0]       d2,
    input  wire [WIDTH-1:0]       d3,
    input  wire [1:0]             s,
    output wire [WIDTH-1:0]       y
);
    assign y = (s == 2'b00) ? d0 :
               (s == 2'b01) ? d1 :
               (s == 2'b10) ? d2 : d3;
endmodule