// controller.v — 控制单元 (RV32I + RV32F), v3
module maindec (
    input  wire [6:0]  op,
    output wire        RegWrite,
    output wire        FPRegWrite,
    output wire [2:0]  ImmSrc,
    output wire        ALUSrc,
    output wire        MemWrite,
    output wire [1:0]  ResultSrc,
    output wire        Branch,
    output wire        ALUSrcA,
    output wire [1:0]  ALUOp,
    output wire        Jump,
    output wire        FPUActive,
    output wire        FPMemSrc    // 1=fsw uses float rf for store data
);
    // {FPMemSrc(16),FPUActive(14),RegWrite(13),FPRegWrite(12),ImmSrc(11:9),ALUSrc(8),
    //  MemWrite(7),ResultSrc(6:5),Branch(4),ALUSrcA(3),ALUOp(2:1),Jump(0)}
    reg [16:0] controls;
    assign {FPMemSrc, FPUActive, RegWrite, FPRegWrite, ImmSrc, ALUSrc, MemWrite, ResultSrc, Branch, ALUSrcA, ALUOp, Jump} = controls;
    always @(*) case(op)
        7'b0000011: controls=17'b0_0_1_0_000_1_0_01_0_0_00_0;
        7'b0100011: controls=17'b0_0_0_0_001_1_1_00_0_0_00_0;  // sw: FPMemSrc=0
        7'b0110011: controls=17'b0_0_1_0_000_0_0_00_0_0_10_0;
        7'b1100011: controls=17'b0_0_0_0_010_0_0_00_1_0_01_0;
        7'b0010011: controls=17'b0_0_1_0_000_1_0_00_0_0_10_0;
        7'b0110111: controls=17'b0_0_1_0_011_0_0_11_0_0_00_0;
        7'b0010111: controls=17'b0_0_1_0_011_1_0_00_0_1_00_0;
        7'b1101111: controls=17'b0_0_1_0_100_0_0_10_0_0_00_1;
        7'b1100111: controls=17'b0_0_1_0_000_1_0_10_0_0_00_1;
        7'b0000111: controls=17'b0_0_0_1_000_1_0_01_0_0_00_0;  // flw
        7'b0100111: controls=17'b1_0_0_0_001_1_1_00_0_0_00_0;  // fsw: FPMemSrc=1
        7'b1000011: controls=17'b0_1_0_1_000_0_0_00_0_0_11_0;  // fmadd
        7'b1000111: controls=17'b0_1_0_1_000_0_0_00_0_0_11_0;
        7'b1001011: controls=17'b0_1_0_1_000_0_0_00_0_0_11_0;
        7'b1001111: controls=17'b0_1_0_1_000_0_0_00_0_0_11_0;
        7'b1010011: controls=17'b0_1_0_1_000_0_0_00_0_0_11_0;
        default:    controls=17'b0_0_0_0_000_0_0_00_0_0_00_0;
    endcase
endmodule

module aludec (
    input  wire        opb5,
    input  wire [2:0]  funct3,
    input  wire        funct7b5,
    input  wire [1:0]  ALUOp,
    output reg  [3:0]  ALUControl
);
    always @(*) case(ALUOp)
        2'b00: ALUControl=4'b0000;
        2'b01: ALUControl=4'b0001;
        2'b10: begin case(funct3)
            3'b000: ALUControl=(opb5&funct7b5)?4'b0001:4'b0000;
            3'b001: ALUControl=4'b0111;3'b010: ALUControl=4'b0101;
            3'b011: ALUControl=4'b0110;3'b100: ALUControl=4'b0100;
            3'b101: ALUControl=funct7b5?4'b1001:4'b1000;
            3'b110: ALUControl=4'b0011;3'b111: ALUControl=4'b0010;
            default: ALUControl=4'b0000; endcase end
        default: ALUControl=4'b0000;
    endcase
endmodule

module fpudec (
    input  wire [6:0]  op,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    input  wire [4:0]  rs2,
    output reg  [4:0]  FPUOp,
    output reg         FPUWriteInt
);
    always @(*) begin FPUOp=5'd0; FPUWriteInt=1'b0;
        if(op==7'b1010011) casez({funct7,funct3,rs2})
            {7'b000????,3'b???,5'b?????}: case(funct7[6:2])
                5'b00000:FPUOp=0;5'b00001:FPUOp=1;5'b00010:FPUOp=2;5'b00011:FPUOp=3;default:FPUOp=0; endcase
            {7'b01011??,3'b???,5'b?????}: FPUOp=4;  // fsqrt (funct7=0101100), ignores funct3/rs2
            {7'b00100??,3'b???,5'b?????}: case(funct3) 3'b000:FPUOp=5;3'b001:FPUOp=6;3'b010:FPUOp=7;default:FPUOp=0; endcase
            {7'b00101??,3'b???,5'b?????}: case(funct3) 3'b000:FPUOp=8;3'b001:FPUOp=9;default:FPUOp=0; endcase
            {7'b10100??,3'b???,5'b?????}: begin FPUWriteInt=1; case(funct3)3'b010:FPUOp=10;3'b001:FPUOp=11;3'b000:FPUOp=12;default:FPUOp=0; endcase end
            {7'b1100000,3'b???,5'b?????}: begin FPUWriteInt=1; case(rs2)5'b00000:FPUOp=13;5'b00001:FPUOp=14;default:FPUOp=0; endcase end
            {7'b1101000,3'b???,5'b?????}: case(rs2)5'b00000:FPUOp=15;5'b00001:FPUOp=16;default:FPUOp=0; endcase
            {7'b1110000,3'b000,5'b00000}: begin FPUWriteInt=1;FPUOp=17; end
            {7'b1111000,3'b000,5'b00000}: FPUOp=18;
        endcase
        else if(op==7'b1000011)FPUOp=19;else if(op==7'b1000111)FPUOp=20;
        else if(op==7'b1001011)FPUOp=21;else if(op==7'b1001111)FPUOp=22;
    end
endmodule

module controller (
    input  wire [6:0]  op,
    input  wire [2:0]  funct3,
    input  wire        funct7b5,
    input  wire [6:0]  funct7,
    input  wire [4:0]  rs2,
    input  wire        Eq, Lt, Ltu,
    output wire [1:0]  PCSrcD,
    output wire [3:0]  ALUControlD,
    output wire        ALUSrcD, ALUSrcAD,
    output wire [2:0]  ImmSrcD,
    output wire        RegWriteD, MemWriteD,
    output wire [1:0]  ResultSrcD,
    output wire        BranchD, JumpD,
    output wire [4:0]  FPUOpD,
    output wire        FPRegWriteD, FPUActiveD, FPUWriteIntD,
    output wire        FPMemSrcD, FPUSrcIntD
);
    wire [1:0] ALUOpD;
    wire        RegWriteD_md, FPRegWriteD_md;
    maindec md(.op(op), .RegWrite(RegWriteD_md), .FPRegWrite(FPRegWriteD_md), .ImmSrc(ImmSrcD), .ALUSrc(ALUSrcD), .MemWrite(MemWriteD), .ResultSrc(ResultSrcD), .Branch(BranchD), .ALUSrcA(ALUSrcAD), .ALUOp(ALUOpD), .Jump(JumpD), .FPUActive(FPUActiveD), .FPMemSrc(FPMemSrcD));
    aludec ad(.opb5(op[5]), .funct3(funct3), .funct7b5(funct7b5), .ALUOp(ALUOpD), .ALUControl(ALUControlD));
    fpudec fd(.op(op), .funct3(funct3), .funct7(funct7), .rs2(rs2), .FPUOp(FPUOpD), .FPUWriteInt(FPUWriteIntD));
    // FP compare/convert: result goes to integer register
    assign RegWriteD   = RegWriteD_md | (FPUActiveD & FPUWriteIntD);
    assign FPRegWriteD = FPRegWriteD_md & ~(FPUActiveD & FPUWriteIntD);
    // FPU A port source: 1 = integer register (fcvt.s.w, fcvt.s.wu, fmv.w.x), 0 = float register
    assign FPUSrcIntD = (FPUOpD == 5'd15) || (FPUOpD == 5'd16) || (FPUOpD == 5'd18);
    reg [1:0] tmp;
    always @(*) begin tmp=2'b00;
        if(JumpD) case(op) 7'b1101111:tmp=2'b10;7'b1100111:tmp=2'b11;default:tmp=2'b00; endcase
        else if(BranchD) case(funct3)
            3'b000:tmp=(Eq?2'b01:2'b00);3'b001:tmp=(~Eq?2'b01:2'b00);3'b100:tmp=(Lt?2'b01:2'b00);
            3'b101:tmp=(~Lt?2'b01:2'b00);3'b110:tmp=(Ltu?2'b01:2'b00);3'b111:tmp=(~Ltu?2'b01:2'b00);
            default:tmp=2'b00; endcase
    end
    assign PCSrcD = tmp;
endmodule