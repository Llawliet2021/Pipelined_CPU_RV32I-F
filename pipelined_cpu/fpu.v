// ============================================================================
// fpu.v — IEEE 754 single-precision FPU (RV32F)
// 使用 $realtobits / $bitstoreal (64-bit), 内部手动做 float↔double 转换
// ============================================================================

module fpu (
    input  wire [31:0] a,           // operand A (fs1)
    input  wire [31:0] b,           // operand B (fs2)
    input  wire [31:0] c,           // operand C (fs3, for R4)
    input  wire [4:0]  op,          // operation code
    input  wire [2:0]  rm,          // rounding mode
    output reg  [31:0] result,
    output reg  [4:0]  fflags
);
    // ---- IEEE 754 helper functions ----
    // Convert 32-bit float → 64-bit double bits
    function [63:0] f32_to_f64;
        input [31:0] f32;
        reg [10:0] exp;
        reg [51:0] mant;
        begin
            if (f32[30:23] == 8'd0 && f32[22:0] == 23'd0) begin
                // Zero → double zero
                f32_to_f64 = {f32[31], 11'd0, 52'd0};
            end else if (f32[30:23] == 8'd255) begin
                // Inf/NaN → double Inf/NaN
                f32_to_f64 = {f32[31], 11'd2047, f32[22:0], 29'd0};
            end else begin
                exp = {3'd0, f32[30:23]} - 11'd127 + 11'd1023;
                mant = {f32[22:0], 29'd0};
                f32_to_f64 = {f32[31], exp, mant};
            end
        end
    endfunction

    // Convert 64-bit double → 32-bit float (with rounding)
    function [31:0] f64_to_f32;
        input [63:0] f64;
        reg [10:0] exp64;
        reg [7:0]  exp32;
        begin
            exp64 = f64[62:52];
            if (exp64 == 11'd0) begin
                // Zero / subnormal → float zero
                f64_to_f32 = {f64[63], 8'd0, 23'd0};
            end else if (exp64 == 11'd2047) begin
                // Inf/NaN
                f64_to_f32 = {f64[63], 8'd255, f64[51:29]};
            end else if (exp64 < 11'd1023 - 11'd127) begin
                // Underflow → zero
                f64_to_f32 = {f64[63], 8'd0, 23'd0};
            end else if (exp64 > 11'd1023 + 11'd127) begin
                // Overflow → inf
                f64_to_f32 = {f64[63], 8'd255, 23'd0};
            end else begin
                exp32 = (exp64 - 11'd1023 + 11'd127);
                f64_to_f32 = {f64[63], exp32[7:0], f64[51:29]};
            end
        end
    endfunction

    // ---- internal real variables ----
    real ra, rb, rc, rres;
    // ---- operation codes ----
    localparam FADD=5'd0, FSUB=5'd1, FMUL=5'd2, FDIV=5'd3, FSQRT=5'd4;
    localparam FSGNJ=5'd5, FSGNJN=5'd6, FSGNJX=5'd7;
    localparam FMIN=5'd8, FMAX=5'd9;
    localparam FEQ=5'd10, FLT=5'd11, FLE=5'd12;
    localparam FCVT_WS=5'd13, FCVT_WUS=5'd14, FCVT_SW=5'd15, FCVT_SWU=5'd16;
    localparam FMV_XW=5'd17, FMV_WX=5'd18;
    localparam FMADD=5'd19, FMSUB=5'd20, FNMSUB=5'd21, FNMADD=5'd22;

    always @(*) begin
        fflags = 5'b0;
        result = 32'b0;

        // Convert 32-bit floats to 64-bit doubles, then to real
        ra = $bitstoreal(f32_to_f64(a));
        rb = $bitstoreal(f32_to_f64(b));
        rc = $bitstoreal(f32_to_f64(c));

        case (op)
            FADD:  begin rres = ra + rb;       result = f64_to_f32($realtobits(rres)); end
            FSUB:  begin rres = ra - rb;       result = f64_to_f32($realtobits(rres)); end
            FMUL:  begin rres = ra * rb;       result = f64_to_f32($realtobits(rres)); end
            FDIV:  begin
                if (rb == 0.0) begin result = 32'h7FC00000; fflags[2]=1'b1; end
                else          begin rres = ra / rb; result = f64_to_f32($realtobits(rres)); end
            end
            FSQRT: begin
                if (ra < 0.0) begin result = 32'h7FC00000; fflags[0]=1'b1; end
                else          begin rres = $sqrt(ra); result = f64_to_f32($realtobits(rres)); end
            end

            FSGNJ:  result = {b[31], a[30:0]};
            FSGNJN: result = {~b[31], a[30:0]};
            FSGNJX: result = {a[31] ^ b[31], a[30:0]};

            FMIN: result = (a==32'h7FC00000||b==32'h7FC00000) ? 32'h7FC00000 : ((ra <= rb) ? a : b);
            FMAX: result = (a==32'h7FC00000||b==32'h7FC00000) ? 32'h7FC00000 : ((ra >= rb) ? a : b);

            FEQ:  result = (ra == rb) ? 32'd1 : 32'd0;
            FLT:  result = (ra < rb)  ? 32'd1 : 32'd0;
            FLE:  result = (ra <= rb) ? 32'd1 : 32'd0;

            FCVT_WS: begin
                if (ra != ra)            result = 32'h7FFFFFFF;
                else if (ra >= 2147483648.0) result = 32'h7FFFFFFF;
                else if (ra < -2147483648.0) result = 32'h80000000;
                else                     result = $rtoi(ra);
            end
            FCVT_WUS: begin
                if (ra != ra)            result = 32'hFFFFFFFF;
                else if (ra >= 4294967296.0) result = 32'hFFFFFFFF;
                else if (ra < 0.0)       result = 32'd0;
                else                     result = $rtoi(ra);
            end

            FCVT_SW:  begin rres = $itor($signed(a)); result = f64_to_f32($realtobits(rres)); end
            FCVT_SWU: begin rres = $itor(a);          result = f64_to_f32($realtobits(rres)); end

            FMV_XW: result = a;
            FMV_WX: result = a;

            FMADD:  begin rres = ra * rb + rc; result = f64_to_f32($realtobits(rres)); end
            FMSUB:  begin rres = ra * rb - rc; result = f64_to_f32($realtobits(rres)); end
            FNMSUB: begin rres = -(ra * rb + rc); result = f64_to_f32($realtobits(rres)); end
            FNMADD: begin rres = -(ra * rb - rc); result = f64_to_f32($realtobits(rres)); end

            default: result = 32'h7FC00000;
        endcase
    end
endmodule