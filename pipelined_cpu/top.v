// ============================================================================
// top.v — 5级流水线 RISC-V 处理器顶层 (RV32I + RV32F)
// ============================================================================

module top #(
    parameter MEMFILE = "riscv_ex73_74.txt"
) (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] WriteData,
    output wire [31:0] DataAdr,
    output wire        MemWrite
);
    wire [31:0] PC;
    wire [31:0] Instr;
    wire [31:0] ReadData;
    wire [2:0]  Funct3M;

    pipelined_riscv pipeline(
        .clk(clk), .reset(reset), .PC(PC), .Instr(Instr),
        .MemWrite(MemWrite), .ALUResult(DataAdr),
        .WriteData(WriteData), .ReadData(ReadData), .Funct3M(Funct3M)
    );

    imem #(.MEMFILE(MEMFILE)) imem_inst(.a(PC), .rd(Instr));

    dmem dmem_inst(.clk(clk), .we(MemWrite), .funct3(Funct3M),
                   .a(DataAdr), .wd(WriteData), .rd(ReadData));
endmodule

// ============================================================================
// pipelined_riscv — 5级流水线处理器核心
// ============================================================================
module pipelined_riscv (
    input  wire        clk, reset,
    output wire [31:0] PC,
    input  wire [31:0] Instr,
    output wire        MemWrite,
    output wire [31:0] ALUResult, WriteData,
    input  wire [31:0] ReadData,
    output wire [2:0]  Funct3M
);
    wire [31:0] InstrD;
    wire [1:0]  PCSrcD;
    wire [3:0]  ALUControlD;
    wire        ALUSrcD, ALUSrcAD;
    wire [2:0]  ImmSrcD;
    wire        RegWriteD, MemWriteD;
    wire [1:0]  ResultSrcD;
    wire        BranchD, JumpD;
    wire        Eq, Lt, Ltu;
    wire        StallF, StallD, FlushD, FlushE;
    wire        RegWriteW;
    wire [1:0]  ResultSrcW;
    wire [4:0]  RdW;
    wire [31:0] ALUResultW, ReadDataW, PCPlus4W;
    // FPU control
    wire [4:0]  FPUOpD;
    wire        FPRegWriteD, FPUActiveD, FPUWriteIntD, FPMemSrcD, FPUSrcIntD;

    controller ctrl(
        .op(InstrD[6:0]), .funct3(InstrD[14:12]), .funct7b5(InstrD[30]),
        .funct7(InstrD[31:25]), .rs2(InstrD[24:20]),
        .Eq(Eq), .Lt(Lt), .Ltu(Ltu),
        .PCSrcD(PCSrcD), .ALUControlD(ALUControlD),
        .ALUSrcD(ALUSrcD), .ALUSrcAD(ALUSrcAD), .ImmSrcD(ImmSrcD),
        .RegWriteD(RegWriteD), .MemWriteD(MemWriteD), .ResultSrcD(ResultSrcD),
        .BranchD(BranchD), .JumpD(JumpD),
        .FPUOpD(FPUOpD), .FPRegWriteD(FPRegWriteD),
        .FPUActiveD(FPUActiveD), .FPUWriteIntD(FPUWriteIntD),
        .FPMemSrcD(FPMemSrcD),
        .FPUSrcIntD(FPUSrcIntD)
    );

    datapath dp(
        .clk(clk), .reset(reset),
        .PCSrcD(PCSrcD), .ALUControlD(ALUControlD),
        .ALUSrcD(ALUSrcD), .ALUSrcAD(ALUSrcAD), .ImmSrcD(ImmSrcD),
        .RegWriteD(RegWriteD), .MemWriteD(MemWriteD), .ResultSrcD(ResultSrcD),
        .FPUOpD(FPUOpD), .FPRegWriteD(FPRegWriteD),
        .FPUActiveD(FPUActiveD), .FPUWriteIntD(FPUWriteIntD),
        .FPMemSrcD(FPMemSrcD),
        .FPUSrcIntD(FPUSrcIntD),
        .Eq(Eq), .Lt(Lt), .Ltu(Ltu),
        .StallF(StallF), .StallD(StallD), .FlushD(FlushD), .FlushE(FlushE),
        .InstrD_out(InstrD),
        .PC(PC), .Instr(Instr),
        .MemWriteM(MemWrite), .Funct3M(Funct3M),
        .ALUResultM(ALUResult), .WriteDataM(WriteData), .ReadDataM(ReadData),
        .RegWriteW(RegWriteW), .ResultSrcW(ResultSrcW), .RdW(RdW),
        .ALUResultW(ALUResultW), .ReadDataW(ReadDataW), .PCPlus4W(PCPlus4W)
    );
endmodule

module imem #(
    parameter MEMFILE = "riscv_ex73_74.txt"
) (
    input  wire [31:0] a,
    output wire [31:0] rd
);
    reg [31:0] RAM [0:255];
    initial $readmemh(MEMFILE, RAM, 0, 255);
    assign rd = RAM[a[31:2]];
endmodule

module dmem (
    input  wire        clk, we,
    input  wire [2:0]  funct3,
    input  wire [31:0] a, wd,
    output wire [31:0] rd
);
    reg [31:0] RAM [0:255];
    integer i;
    initial for (i=0; i<256; i=i+1) RAM[i] = 32'd0;
    assign rd = RAM[a[31:2]];
    always @(posedge clk) begin
        if (we) begin
            case (funct3)
                3'b000: case (a[1:0])
                    2'b00: RAM[a[31:2]][7:0]   <= wd[7:0];
                    2'b01: RAM[a[31:2]][15:8]  <= wd[7:0];
                    2'b10: RAM[a[31:2]][23:16] <= wd[7:0];
                    2'b11: RAM[a[31:2]][31:24] <= wd[7:0];
                endcase
                3'b001: case (a[1])
                    1'b0: RAM[a[31:2]][15:0]  <= wd[15:0];
                    1'b1: RAM[a[31:2]][31:16] <= wd[15:0];
                endcase
                default: RAM[a[31:2]] <= wd;
            endcase
        end
    end
endmodule