// TEC-8 流水线硬布线控制器

module pipelined_hardwired_controller (
        // 输入
        input wire [2:0] SWC_SWB_SWA,  // 面板模式开关
        input wire [3:0] IR7_IR4,      // 指令操作码 IR[7:4]
        input wire CLR,                // 复位（低有效）
        input wire T3,                 // 节拍 T3
        input wire W1, W2,             // 机器节拍
        input wire C, Z,               // 进位标志 / 零标志

        // 输出
        output SELCTL,                 // 寄存器选择控制
        output ABUS,                   // ALU → 总线
        output SBUS,                   // 数据开关 → 总线
        output MBUS,                   // 存储器 → 总线
        output M, CIN,                 // ALU：逻辑/算术选择，进位入
        output DRW,                    // 写通用寄存器
        output LDZ,                    // 装载 Z 标志
        output LDC,                    // 装载 C 标志
        output MEMW,                   // 写存储器
        output ARINC,                  // AR+1
        output reg PCINC,              // PC+1
        output PCADD,                  // PC 相对跳转
        output LPC,                    // 装载 PC
        output LAR,                    // 装载 AR
        output reg LIR,                // 装载 IR
        output STOP,                   // 停机
        output SHORT,                  // 短周期（仅 W1）
        output [3:0] S, SEL            // ALU 功能 / 寄存器号选择
    );

    reg ST0;           // 阶段位：0=前半段，1=后半段
    wire SST0;         // 置 ST0=1 的条件
    reg [2:0] Q;       // 工作模式锁存

    wire WRITE_REG;    // 写寄存器模式
    wire READ_REG;     // 读寄存器模式
    wire INS_FETCH;    // 取指执行模式
    wire READ_MEM;     // 读存储器模式
    wire WRITE_MEM;    // 写存储器模式

    // 模式锁存
	always @(negedge T3 or negedge CLR)
	begin
		if (!CLR) begin
			Q <= 3'b000;
		end
		else begin
			case  (SWC_SWB_SWA)
				3'b100:  Q<=3'b100;   // 写寄存器
				3'b011:  Q<=3'b011;   // 读寄存器
				3'b000:  Q<=3'b000;   // 取指
				3'b010:  Q<=3'b010;   // 读存储器
				3'b001:  Q<=3'b001;   // 写存储器
			    default:
			             Q<=3'b111;   // 非法
			 endcase
		end
	end

    assign WRITE_REG = (Q == 3'b100) ? 1: 0;
    assign READ_REG  = (Q == 3'b011) ? 1: 0;
    assign INS_FETCH = (Q == 3'b000) ? 1: 0;
    assign READ_MEM  = (Q == 3'b010) ? 1: 0;
    assign WRITE_MEM = (Q == 3'b001) ? 1: 0;

    // ST0 更新
    always @(negedge T3 or negedge CLR) begin
        if (CLR == 0 ) begin
            ST0 <= 1'b0;
        end
        else if (SST0) begin
            ST0 <= 1'b1;
        end
        else if(ST0 && W2 && WRITE_REG)begin
            ST0 <= 1'b0;
        end
    end

    assign SST0 = (ST0 == 1'b0) && (
               (Q == 3'b100 && W2) ||
               (Q == 3'b010 && W1) ||
               (Q == 3'b001 && W1) ||
               (Q == 3'b000 && W1)
           );

    // 取指条件
    wire FETCH;
    assign FETCH = (INS_FETCH && ST0) && (
               (W1 && (
                   (IR7_IR4 == 4'b0000) ||              // NOP
                   (IR7_IR4 == 4'b0001) ||              // ADD
                   (IR7_IR4 == 4'b0010) ||              // SUB
                   (IR7_IR4 == 4'b0011) ||              // AND
                   (IR7_IR4 == 4'b0100) ||              // INC
                   (IR7_IR4 == 4'b0111 && !C) ||        // JC 不跳
                   (IR7_IR4 == 4'b1000 && !Z) ||        // JZ 不跳
                   (IR7_IR4 == 4'b1100) ||              // MOV
                   (IR7_IR4 == 4'b1101) ||              // CMP
                   (IR7_IR4 == 4'b1111) ||              // NOT
                   (IR7_IR4 == 4'b1011)                 // DEC
               )) ||
               (W2 && (
                   (IR7_IR4 == 4'b0101) ||              // LD
                   (IR7_IR4 == 4'b0110) ||              // ST
                   (IR7_IR4 == 4'b0111 && C) ||         // JC 跳转
                   (IR7_IR4 == 4'b1000 && Z) ||         // JZ 跳转
                   (IR7_IR4 == 4'b1001)                 // JMP
               ))
           );

    // PCINC / LIR 锁存
    always @(posedge T3 or negedge CLR) begin
        if (!CLR) begin
            PCINC <= 1'b0;
            LIR   <= 1'b0;
        end
        else begin
            PCINC <= FETCH;
            LIR   <= FETCH;
        end
    end

    // 指令译码
    wire ADD   = (IR7_IR4 == 4'b0001) & INS_FETCH & ST0;  // 加法
    wire SUB   = (IR7_IR4 == 4'b0010) & INS_FETCH & ST0;  // 减法
    wire AND_  = (IR7_IR4 == 4'b0011) & INS_FETCH & ST0;  // 与
    wire INC   = (IR7_IR4 == 4'b0100) & INS_FETCH & ST0;  // 加1
    wire LD    = (IR7_IR4 == 4'b0101) & INS_FETCH & ST0;  // 取数
    wire ST    = (IR7_IR4 == 4'b0110) & INS_FETCH & ST0;  // 存数
    wire JC    = (IR7_IR4 == 4'b0111) & INS_FETCH & ST0;  // C 条件跳转
    wire JZ    = (IR7_IR4 == 4'b1000) & INS_FETCH & ST0;  // Z 条件跳转
    wire JMP   = (IR7_IR4 == 4'b1001) & INS_FETCH & ST0;  // 无条件跳转
    wire MOV   = (IR7_IR4 == 4'b1100) & INS_FETCH & ST0;  // 传送
    wire CMP   = (IR7_IR4 == 4'b1101) & INS_FETCH & ST0;  // 比较
    wire NOT_  = (IR7_IR4 == 4'b1111) & INS_FETCH & ST0;  // 取反
    wire STP   = (IR7_IR4 == 4'b1110) & INS_FETCH & ST0;  // 停机
    wire DEC   = (IR7_IR4 == 4'b1011) & INS_FETCH & ST0;  // 减1
    wire NOP   = (IR7_IR4 == 4'b0000) & INS_FETCH & ST0;  // 空操作

    wire SHORT_INSTR = NOP | ADD | SUB | AND_ | INC | MOV | CMP | NOT_ | DEC
                     | (JC & ~C) | (JZ & ~Z);              // 短指令

    // 控制信号
    assign SELCTL = (WRITE_REG & (W1|W2)) | (READ_REG & (W1|W2))
                  | ((READ_MEM|WRITE_MEM) & W1);
    assign SEL[3] = (WRITE_REG & (W1|W2) & ST0) | (READ_REG & W2);
    assign SEL[2] = (WRITE_REG & W2);
    assign SEL[1] = (WRITE_REG & ((W1 & ~ST0) | (W2 & ST0))) | (READ_REG & W2);
    assign SEL[0] = (WRITE_REG & W1) | (READ_REG & (W1|W2));
    assign DRW    = (WRITE_REG & (W1|W2))
                  | ((ADD|SUB|AND_|INC|MOV|NOT_|DEC) & W1)
                  | (LD & W2);

    assign LPC   = (INS_FETCH & ~ST0 & W1) | (JMP & W1);
    assign PCADD = ((C & JC) | (Z & JZ)) & W1;
    assign LAR   = ((READ_MEM|WRITE_MEM) & W1 & ~ST0) | ((LD|ST) & W1);
    assign ARINC = (READ_MEM|WRITE_MEM) & W1 & ST0;

    assign SBUS = (WRITE_REG & (W1|W2))
                | (READ_MEM & W1 & ~ST0)
                | (WRITE_MEM & W1)
                | (INS_FETCH & ~ST0 & W1);
    assign MBUS = (READ_MEM & W1 & ST0) | (LD & W2);
    assign ABUS = ((ADD|SUB|AND_|INC|LD|ST|JMP|MOV|CMP|NOT_|DEC) & W1) | (ST & W2);

    assign M   = ((AND_|LD|ST|JMP|MOV|NOT_) & W1) | (ST & W2);
    assign CIN = (ADD | DEC) & W1;
    assign S[3] = ((ADD|AND_|LD|JMP|MOV|DEC) & W1) | (ST & (W1|W2));
    assign S[2] = ((SUB|JMP|CMP|DEC) & W1) | (ST & W1);
    assign S[1] = ((SUB|AND_|LD|ST|JMP|MOV|CMP|DEC) & W1) | (ST & W2);
    assign S[0] = ((ADD|AND_|JMP|DEC) & W1) | (ST & W1);

    assign LDZ = (ADD|SUB|AND_|INC|MOV|CMP|NOT_|DEC) & W1;
    assign LDC = (ADD|SUB|INC|CMP|DEC) & W1;

    assign MEMW = (WRITE_MEM & W1 & ST0) | (ST & W2);

    assign SHORT = (READ_MEM & W1) | (WRITE_MEM & W1)
                 | (INS_FETCH & ~ST0 & W1) | (SHORT_INSTR & W1);
    assign STOP  = ((WRITE_REG|READ_REG) & (W1|W2))
                 | ((READ_MEM|WRITE_MEM) & W1)
                 | (INS_FETCH & ~ST0 & W1) | (STP & W1);

endmodule
