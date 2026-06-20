// ============================================================================
// datapath.v — 5级流水线数据通路 (v3.5: RV32I + RV32F, FP A-port forwarding)
// ============================================================================

module datapath (
    input  wire        clk,
    input  wire        reset,
    input  wire [1:0]  PCSrcD,
    input  wire [3:0]  ALUControlD,
    input  wire        ALUSrcD,
    input  wire        ALUSrcAD,
    input  wire [2:0]  ImmSrcD,
    input  wire        RegWriteD,
    input  wire        MemWriteD,
    input  wire [1:0]  ResultSrcD,
    input  wire [4:0]  FPUOpD,
    input  wire        FPRegWriteD,
    input  wire        FPUActiveD,
    input  wire        FPUWriteIntD,
    input  wire        FPMemSrcD,
    input  wire        FPUSrcIntD,
    output wire        Eq, Lt, Ltu,
    output wire        StallF, StallD, FlushD, FlushE,
    output wire [31:0] InstrD_out,
    output wire [31:0] PC,
    input  wire [31:0] Instr,
    output wire        MemWriteM,
    output wire [2:0]  Funct3M,
    output wire [31:0] ALUResultM,
    output wire [31:0] WriteDataM,
    input  wire [31:0] ReadDataM,
    output wire        RegWriteW,
    output wire [1:0]  ResultSrcW,
    output wire [4:0]  RdW,
    output wire [31:0] ALUResultW,
    output wire [31:0] ReadDataW,
    output wire [31:0] PCPlus4W
);

    reg [31:0] PC_reg = 0;
    reg [31:0] IFID_PC = 0;
    reg [31:0] IFID_Instr = 0;
    reg [31:0] IDEX_PC = 0;
    reg [31:0] IDEX_PCPlus4 = 0;
    reg [31:0] IDEX_SrcA = 0;
    reg [31:0] IDEX_SrcB = 0;
    reg [31:0] IDEX_FSrcA = 0;
    reg [31:0] IDEX_FSrcB = 0;
    reg [31:0] IDEX_FSrcC = 0;
    reg [31:0] IDEX_ImmExt = 0;
    reg [4:0]  IDEX_Rs1 = 0;
    reg [4:0]  IDEX_Rs2 = 0;
    reg [4:0]  IDEX_Rd = 0;
    reg [3:0]  IDEX_ALUCtrl = 4'd0;
    reg        IDEX_ALUSrc = 1'b0;
    reg        IDEX_ALUSrcA = 1'b0;
    reg        IDEX_RegWrite = 1'b0;
    reg        IDEX_MemWrite = 1'b0;
    reg [1:0]  IDEX_ResultSrc = 2'd0;
    reg [2:0]  IDEX_Funct3 = 3'd0;
    reg [4:0]  IDEX_FPUOp = 5'd0;
    reg        IDEX_FPRegWrite = 1'b0;
    reg        IDEX_FPUActive = 1'b0;
    reg        IDEX_FPUWriteInt = 1'b0;
    reg        IDEX_FPMemSrc = 1'b0;
    reg        IDEX_FPUSrcInt = 1'b0;

    reg [31:0] EXMEM_ALUResult = 0;
    reg [31:0] EXMEM_FPUResult = 0;
    reg [31:0] EXMEM_WriteData = 0;
    reg [31:0] EXMEM_PCPlus4 = 0;
    reg [4:0]  EXMEM_Rd = 0;
    reg        EXMEM_RegWrite = 1'b0;
    reg        EXMEM_FPRegWrite = 1'b0;
    reg        EXMEM_MemWrite = 1'b0;
    reg [1:0]  EXMEM_ResultSrc = 2'd0;
    reg [2:0]  EXMEM_Funct3 = 3'd0;
    reg [31:0] EXMEM_ImmExt = 0;
    reg        EXMEM_FPUActive = 1'b0;
    reg        EXMEM_FPUWriteInt = 1'b0;

    reg [31:0] MEMWB_ALUResult = 0;
    reg [31:0] MEMWB_FPUResult = 0;
    reg [31:0] MEMWB_ReadData = 0;
    reg [4:0]  MEMWB_Rd = 0;
    reg        MEMWB_RegWrite = 1'b0;
    reg        MEMWB_FPRegWrite = 1'b0;
    reg [1:0]  MEMWB_ResultSrc = 2'd0;
    reg [2:0]  MEMWB_Funct3 = 3'd0;
    reg [31:0] MEMWB_PCPlus4 = 0;
    reg [31:0] MEMWB_ImmExt = 0;
    reg        MEMWB_FPUActive = 1'b0;
    reg        MEMWB_FPUWriteInt = 1'b0;

    // ---- Comb logic ----
    wire [31:0] PCPlus4F = PC_reg + 32'd4;
    wire [31:0] SrcAD, SrcBD, ImmExtD;
    wire [31:0] FSrcAD, FSrcBD, FSrcCD;

    regfile rf(.clk(clk), .we3(MEMWB_RegWrite),
        .a1(IFID_Instr[19:15]), .a2(IFID_Instr[24:20]),
        .a3(MEMWB_Rd), .wd3(ResultWB), .rd1(SrcAD), .rd2(SrcBD));

    fregfile frf(.clk(clk), .we(MEMWB_FPRegWrite),
        .a1(IFID_Instr[19:15]), .a2(IFID_Instr[24:20]),
        .a3(IFID_Instr[31:27]),
        .waddr(MEMWB_Rd),
        .wd(MEMWB_FPUActive ? MEMWB_FPUResult : MEMWB_ReadData),
        .rd1(FSrcAD), .rd2(FSrcBD), .rd3(FSrcCD));

    extend ext(.instr(IFID_Instr[31:7]), .immsrc(ImmSrcD), .immext(ImmExtD));

    wire [31:0] PCTargetD  = IFID_PC + ImmExtD;
    wire [31:0] JALRTargetD_raw = SrcAD + ImmExtD;
    wire [31:0] JALRTargetD = {JALRTargetD_raw[31:1], 1'b0};
    assign Eq  = (SrcAD == SrcBD);
    assign Lt  = ($signed(SrcAD) < $signed(SrcBD));
    assign Ltu = (SrcAD < SrcBD);

    wire [31:0] NextPC;
    mux4 #(.WIDTH(32)) pcmux(.d0(PCPlus4F), .d1(PCTargetD), .d2(PCTargetD), .d3(JALRTargetD),
        .s(PCSrcD), .y(NextPC));

    // ---- Integer Forwarding ----
    wire [31:0] ResultM;
    mux4 #(.WIDTH(32)) resultM_mux(
        .d0(EXMEM_FPUActive && EXMEM_FPUWriteInt ? EXMEM_FPUResult : EXMEM_ALUResult),
        .d1(32'd0), .d2(EXMEM_PCPlus4), .d3(EXMEM_ImmExt),
        .s(EXMEM_ResultSrc), .y(ResultM));

    wire [1:0] ForwardA, ForwardB;
    assign ForwardA =
        (EXMEM_RegWrite && EXMEM_Rd != 0 && EXMEM_Rd == IDEX_Rs1) ? 2'b01 :
        (MEMWB_RegWrite && MEMWB_Rd != 0 && MEMWB_Rd == IDEX_Rs1) ? 2'b10 : 2'b00;
    assign ForwardB =
        (EXMEM_RegWrite && EXMEM_Rd != 0 && EXMEM_Rd == IDEX_Rs2) ? 2'b01 :
        (MEMWB_RegWrite && MEMWB_Rd != 0 && MEMWB_Rd == IDEX_Rs2) ? 2'b10 : 2'b00;

    wire [31:0] SrcA_fwd, SrcB_fwd;
    mux3 #(.WIDTH(32)) fwdA(.d0(IDEX_SrcA), .d1(ResultM), .d2(ResultWB),
        .s(ForwardA), .y(SrcA_fwd));
    mux3 #(.WIDTH(32)) fwdB(.d0(IDEX_SrcB), .d1(ResultM), .d2(ResultWB),
        .s(ForwardB), .y(SrcB_fwd));

    // ---- FP Forwarding for A port (fmv.x.w, fcvt.w.s, fadd, etc.) ----
    wire [1:0] ForwardFA;
    assign ForwardFA =
        (EXMEM_FPRegWrite && EXMEM_Rd != 0 && EXMEM_Rd == IDEX_Rs1) ? 2'b01 :
        (MEMWB_FPRegWrite && MEMWB_Rd != 0 && MEMWB_Rd == IDEX_Rs1) ? 2'b10 : 2'b00;

    wire [31:0] FSrcA_fwd;
    mux3 #(.WIDTH(32)) fwdFA(.d0(IDEX_FSrcA), .d1(EXMEM_FPUResult), .d2(MEMWB_FPUResult),
        .s(ForwardFA), .y(FSrcA_fwd));

    // ---- FP Forwarding for B port (fsw store data, FP ops) ----
    wire [1:0] ForwardFB;
    assign ForwardFB =
        (EXMEM_FPRegWrite && EXMEM_Rd != 0 && EXMEM_Rd == IDEX_Rs2) ? 2'b01 :
        (MEMWB_FPRegWrite && MEMWB_Rd != 0 && MEMWB_Rd == IDEX_Rs2) ? 2'b10 : 2'b00;

    wire [31:0] FSrcB_fwd;
    mux3 #(.WIDTH(32)) fwdFB(.d0(IDEX_FSrcB), .d1(EXMEM_FPUResult), .d2(MEMWB_FPUResult),
        .s(ForwardFB), .y(FSrcB_fwd));

    wire [31:0] ALU_A = IDEX_ALUSrcA ? IDEX_PC : SrcA_fwd;
    wire [31:0] ALU_B = IDEX_ALUSrc  ? IDEX_ImmExt : SrcB_fwd;
    wire [31:0] ALUResultE;
    alu alu_inst(.a(ALU_A), .b(ALU_B), .alucontrol(IDEX_ALUCtrl), .result(ALUResultE), .zero());

    // FPU A port: integer register (for fcvt.s.w/fmv.w.x) or forwarded float register (default)
    wire [31:0] FPU_A = IDEX_FPUSrcInt ? SrcA_fwd : FSrcA_fwd;

    // FPU
    wire [31:0] FPUResultE;
    wire [4:0]  FPUFlagsE;
    fpu fpu_inst(.a(FPU_A), .b(FSrcB_fwd), .c(IDEX_FSrcC),
        .op(IDEX_FPUOp), .rm(IDEX_Funct3), .result(FPUResultE), .fflags(FPUFlagsE));

    // ---- Hazard ----
    wire LoadUseHazard =
        (IDEX_ResultSrc == 2'b01) &&
        ((IDEX_Rd == IFID_Instr[19:15]) || (IDEX_Rd == IFID_Instr[24:20])) && (IDEX_Rd != 5'd0);
    assign StallF = LoadUseHazard; assign StallD = LoadUseHazard; assign FlushE = LoadUseHazard;
    assign FlushD = (PCSrcD != 2'b00) && !LoadUseHazard;

    // ---- WB ----
    wire [7:0] sel_byte;
    wire [15:0] sel_half;
    assign sel_byte = (MEMWB_ALUResult[1:0]==2'b00)?MEMWB_ReadData[7:0]:
                      (MEMWB_ALUResult[1:0]==2'b01)?MEMWB_ReadData[15:8]:
                      (MEMWB_ALUResult[1:0]==2'b10)?MEMWB_ReadData[23:16]:MEMWB_ReadData[31:24];
    assign sel_half = (MEMWB_ALUResult[1]==1'b0)?MEMWB_ReadData[15:0]:MEMWB_ReadData[31:16];

    reg [31:0] LoadDataW;
    always @(*) begin
        case (MEMWB_Funct3)
            3'b000: LoadDataW = {{24{sel_byte[7]}}, sel_byte};
            3'b100: LoadDataW = {24'b0, sel_byte};
            3'b001: LoadDataW = {{16{sel_half[15]}}, sel_half};
            3'b101: LoadDataW = {16'b0, sel_half};
            default: LoadDataW = MEMWB_ReadData;
        endcase
    end

    wire [31:0] ResultWB;
    mux4 #(.WIDTH(32)) resultmux(
        .d0(MEMWB_FPUActive && MEMWB_FPUWriteInt ? MEMWB_FPUResult : MEMWB_ALUResult),
        .d1(MEMWB_FPUActive ? MEMWB_FPUResult : LoadDataW),
        .d2(MEMWB_PCPlus4), .d3(MEMWB_ImmExt),
        .s(MEMWB_ResultSrc), .y(ResultWB));

    // ---- Sequential ----
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PC_reg<=32'd0; IFID_PC<=32'd0; IFID_Instr<=32'd0;
            IDEX_PC<=32'd0; IDEX_PCPlus4<=32'd0; IDEX_SrcA<=32'd0; IDEX_SrcB<=32'd0;
            IDEX_FSrcA<=32'd0; IDEX_FSrcB<=32'd0; IDEX_FSrcC<=32'd0;
            IDEX_ImmExt<=32'd0; IDEX_Rs1<=5'd0; IDEX_Rs2<=5'd0; IDEX_Rd<=5'd0;
            IDEX_ALUCtrl<=4'd0; IDEX_ALUSrc<=1'b0; IDEX_ALUSrcA<=1'b0;
            IDEX_RegWrite<=1'b0; IDEX_MemWrite<=1'b0; IDEX_ResultSrc<=2'd0; IDEX_Funct3<=3'd0;
            IDEX_FPUOp<=5'd0; IDEX_FPRegWrite<=1'b0; IDEX_FPUActive<=1'b0; IDEX_FPUWriteInt<=1'b0;
            IDEX_FPMemSrc<=1'b0; IDEX_FPUSrcInt<=1'b0;
            EXMEM_ALUResult<=32'd0; EXMEM_FPUResult<=32'd0; EXMEM_WriteData<=32'd0;
            EXMEM_PCPlus4<=32'd0; EXMEM_Rd<=5'd0; EXMEM_RegWrite<=1'b0;
            EXMEM_FPRegWrite<=1'b0; EXMEM_MemWrite<=1'b0; EXMEM_ResultSrc<=2'd0;
            EXMEM_Funct3<=3'd0; EXMEM_ImmExt<=32'd0; EXMEM_FPUActive<=1'b0; EXMEM_FPUWriteInt<=1'b0;
            MEMWB_ALUResult<=32'd0; MEMWB_FPUResult<=32'd0; MEMWB_ReadData<=32'd0;
            MEMWB_Rd<=5'd0; MEMWB_RegWrite<=1'b0; MEMWB_FPRegWrite<=1'b0;
            MEMWB_ResultSrc<=2'd0; MEMWB_Funct3<=3'd0; MEMWB_PCPlus4<=32'd0;
            MEMWB_ImmExt<=32'd0; MEMWB_FPUActive<=1'b0; MEMWB_FPUWriteInt<=1'b0;
        end else begin
            // MEM/WB
            MEMWB_ALUResult<=EXMEM_ALUResult; MEMWB_FPUResult<=EXMEM_FPUResult;
            MEMWB_ReadData<=ReadDataM; MEMWB_Rd<=EXMEM_Rd;
            MEMWB_RegWrite<=EXMEM_RegWrite; MEMWB_FPRegWrite<=EXMEM_FPRegWrite;
            MEMWB_ResultSrc<=EXMEM_ResultSrc; MEMWB_Funct3<=EXMEM_Funct3;
            MEMWB_PCPlus4<=EXMEM_PCPlus4; MEMWB_ImmExt<=EXMEM_ImmExt;
            MEMWB_FPUActive<=EXMEM_FPUActive; MEMWB_FPUWriteInt<=EXMEM_FPUWriteInt;
            // EX/MEM
            EXMEM_ALUResult <= ALUResultE;
            EXMEM_FPUResult <= FPUResultE;
            // WriteData: int sw uses forwarded int rs2; fsw uses forwarded float fs2
            EXMEM_WriteData <= IDEX_FPMemSrc ? FSrcB_fwd : SrcB_fwd;
            EXMEM_PCPlus4<=IDEX_PCPlus4; EXMEM_Rd<=IDEX_Rd;
            EXMEM_RegWrite<=IDEX_RegWrite; EXMEM_FPRegWrite<=IDEX_FPRegWrite;
            EXMEM_MemWrite<=IDEX_MemWrite; EXMEM_ResultSrc<=IDEX_ResultSrc;
            EXMEM_Funct3<=IDEX_Funct3; EXMEM_ImmExt<=IDEX_ImmExt;
            EXMEM_FPUActive<=IDEX_FPUActive; EXMEM_FPUWriteInt<=IDEX_FPUWriteInt;
            // ID/EX (with flush)
            if (FlushE) begin
                IDEX_PC<=32'd0; IDEX_PCPlus4<=32'd0; IDEX_ALUCtrl<=4'd0;
                IDEX_ALUSrc<=1'b0; IDEX_ALUSrcA<=1'b0; IDEX_RegWrite<=1'b0;
                IDEX_MemWrite<=1'b0; IDEX_ResultSrc<=2'd0; IDEX_Funct3<=3'd0; IDEX_Rd<=5'd0;
                IDEX_FPUOp<=5'd0; IDEX_FPRegWrite<=1'b0; IDEX_FPUActive<=1'b0; IDEX_FPUWriteInt<=1'b0;
                IDEX_FPMemSrc<=1'b0; IDEX_FPUSrcInt<=1'b0;
            end else begin
                IDEX_PC <= IFID_PC; IDEX_PCPlus4 <= IFID_PC + 32'd4;
                IDEX_SrcA<=SrcAD; IDEX_SrcB<=SrcBD;
                IDEX_FSrcA<=FSrcAD; IDEX_FSrcB<=FSrcBD; IDEX_FSrcC<=FSrcCD;
                IDEX_ImmExt<=ImmExtD;
                IDEX_Rs1<=IFID_Instr[19:15]; IDEX_Rs2<=IFID_Instr[24:20]; IDEX_Rd<=IFID_Instr[11:7];
                IDEX_ALUCtrl<=ALUControlD; IDEX_ALUSrc<=ALUSrcD; IDEX_ALUSrcA<=ALUSrcAD;
                IDEX_RegWrite<=RegWriteD; IDEX_MemWrite<=MemWriteD; IDEX_ResultSrc<=ResultSrcD;
                IDEX_Funct3<=IFID_Instr[14:12];
                IDEX_FPUOp<=FPUOpD; IDEX_FPRegWrite<=FPRegWriteD;
                IDEX_FPUActive<=FPUActiveD; IDEX_FPUWriteInt<=FPUWriteIntD;
                IDEX_FPMemSrc<=FPMemSrcD;
                IDEX_FPUSrcInt<=FPUSrcIntD;
            end
            // IF/ID
            if (!StallD) begin
                if (FlushD) begin IFID_PC<=32'd0; IFID_Instr<=32'd0; end
                else        begin IFID_PC<=PC_reg; IFID_Instr<=Instr; end
            end
            if (!StallF) PC_reg <= NextPC;
        end
    end

    assign PC = PC_reg; assign InstrD_out = IFID_Instr;
    assign MemWriteM = EXMEM_MemWrite; assign Funct3M = EXMEM_Funct3;
    assign ALUResultM = EXMEM_ALUResult;
    assign WriteDataM = EXMEM_WriteData;
    assign RegWriteW = MEMWB_RegWrite; assign ResultSrcW = MEMWB_ResultSrc;
    assign RdW = MEMWB_Rd; assign ALUResultW = MEMWB_ALUResult;
    assign ReadDataW = MEMWB_ReadData; assign PCPlus4W = MEMWB_PCPlus4;

endmodule