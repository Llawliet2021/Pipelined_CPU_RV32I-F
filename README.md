# 5级流水线 RISC-V CPU 实现RV32I/F


---

## 项目文件结构

```
pipelined_cpu/
├── 📄 top.v                   顶层模块 (CPU核心 + 指令存储器 + 数据存储器)
├── 📄 datapath.v              数据通路 (5级流水线 + 冲突处理 + 浮点寄存器/FPU)
├── 📄 controller.v            控制单元 (主译码 + ALU译码 + FPU译码)
├── 📄 basic.v                 基础模块 (ALU、寄存器堆、立即数扩展、加法器)
├── 📄 muxes.v                 多路选择器 (2选1、3选1、4选1)
├── 📄 flopr.v                 触发器 (基本型、带使能、带清零)
├── 📄 fpu.v                   IEEE 754 单精度浮点运算单元
├── 📄 fregfile.v              浮点寄存器堆 (32×32bit, 3读1写)
│
├── 📄 pipelined_cpu_tb.v      TEST1 测试平台 (基础测试，硬编码校验)
├── 📄 tb_fulltest.v           TEST2 测试平台 (RV32I 综合测试，读文件比对)
├── 📄 tb_fptest.v             TEST3 测试平台 (RV32F 浮点测试，读文件比对)
├── 📄 tb_runner.v             通用测试平台 (可改参数运行任意测试)
│
├── 📄 gen_fulltest.py         生成 RV32I 综合测试文件
├── 📄 gen_fpu_test.py         生成 RV32F 浮点测试文件
│
├── 📄 README.md               
├── 📄 TEST1_REPORT.md         测试1 报告 (基础指令，逐周期解释)
├── 📄 TEST2_REPORT.md         测试2 报告 (全指令，逐条解释)
├── 📄 TEST3_REPORT.md         测试3 报告 (浮点指令)
```

---

## 部署

### 软件要求
- 已安装 **Icarus Verilog** (`iverilog` 和 `vvp`)
- 打开终端，`cd` 到 `pipelined_cpu/` 目录

---

### 📝 TEST1 — 基础指令测试

**测试内容：** 45 条基础指令，验证 ALU 运算、分支、跳转、存储、加载等核心功能。

```bash
iverilog -o sim1 top.v datapath.v controller.v basic.v muxes.v flopr.v fpu.v fregfile.v pipelined_cpu_tb.v

vvp sim1
```


```
PASS @ write_idx=12: addr=00000064, data=00000019
========== SIMULATION PASSED ==========
Final result at address 100 = 25 (expected 25)
```

> 看到 `SIMULATION PASSED` 和 `13 次 PASS` 即表示测试通过。

---

### 📝 TEST2 — RV32I 全指令测试

**测试内容：** 111 条指令，逐一验证 **全部 37 条 RV32I 整数指令**。

```bash
python gen_fulltest.py

iverilog -o sim2 top.v datapath.v controller.v basic.v muxes.v flopr.v fpu.v fregfile.v tb_fulltest.v

vvp sim2
```


```
[W#0 c=16] A=00000000 D=00000011      PASS
[W#1 c=18] A=00000004 D=00000007      PASS
...
========================================
  Cycles:3003  Writes:36  Exp:39  PASS:36  FAIL:0
  RESULT: ALL PASSED
========================================
```

> 看到 `RESULT: ALL PASSED` 和 `FAIL:0` 即表示测试通过。

---

### 📝 TEST3 — RV32F 浮点指令测试

**测试内容：** 76 条指令（含浮点常数加载），验证 **全部 26 条 RV32F 单精度浮点指令**。

```bash
python gen_fpu_test.py

iverilog -o sim3 top.v datapath.v controller.v basic.v muxes.v flopr.v fpu.v fregfile.v tb_fptest.v

vvp sim3
```


```
[W#5 c=27] A=000000dc D=40800000      PASS    ← fadd: 1.0+3.0=4.0 ✓
[W#6 c=29] A=000000e0 D=40000000      PASS    ← fsub: 3.0-1.0=2.0 ✓
...
========================================
  Cycles:3003  Writes:27  Exp:27  PASS:27  FAIL:0
  RESULT: ALL PASSED
========================================
```

> 看到 `RESULT: ALL PASSED`，`FAIL:0` 即表示测试通过。
---


## 各测试结果分析

- **[TEST1_REPORT.md](TEST1_REPORT.md)** 
- **[TEST2_REPORT.md](TEST2_REPORT.md)** 
- **[TEST3_REPORT.md](TEST3_REPORT.md)**
---

## 查看波形


```bash
gtkwave tb_fulltest.vcd    # TEST2 的波形
gtkwave tb_fptest.vcd      # TEST3 的波形
```