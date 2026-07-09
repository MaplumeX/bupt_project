// TEC-8 硬布线控制器
//
// 本模块根据面板模式开关 SWC_SWB_SWA、时序节拍 W1/W2、指令寄存器高 4 位
// IR7_IR4 以及标志位 C/Z，组合产生各类数据通路控制信号。整体逻辑可分为：
// 1. 模式锁存：在 T3 下降沿采样当前工作模式；
// 2. ST0 状态位：区分手动操作或取指流程中的前后阶段；
// 3. 控制信号译码：根据模式、指令和节拍输出具体微操作控制信号。
//
// 描述风格：数据流描述。控制信号译码部分使用连续赋值（assign）表达各输出的
// 布尔函数（与时序行为描述等价），仅 Q 锁存、ST0、PCINC/LIR 三个寄存器
// 保留 always 时序块。
module pipelined_hardwired_controller (
        // 输入端口
        input wire [2:0] SWC_SWB_SWA,      // 模式选择信号
        input wire [3:0] IR7_IR4,          // 指令寄存器高 4 位
        input wire CLR,                    // 复位信号，低电平有效
        input wire T3,                     // 时序信号 T3，用于更新状态
        input wire W1, W2,                 // 微指令节拍信号
        input wire C, Z,                   // 状态标志：进位标志 C、零标志 Z
        // 输出端口（assign 连续赋值的信号为 wire；仅 PCINC/LIR 为时序 reg）
        output SELCTL,                     // 选择控制信号
        output ABUS,                       // 控制 ALU 输出送总线
        output SBUS,                       // 控制开关输入送总线
        output MBUS,                       // 控制存储器输出送总线
        output M,CIN,                      // M 控制 ALU 运算类型，CIN 为进位输入
        output DRW,                        // 寄存器写控制信号
        output LDZ,                        // 零标志写控制信号
        output LDC,                        // 进位标志写控制信号
        output MEMW,                       // 存储器写控制信号
        output ARINC,                      // 地址寄存器 AR 加 1 控制信号
        output reg PCINC,                  // 程序计数器 PC 加 1 控制信号（T3 上升沿锁存）
        output PCADD,                      // PC 相对寻址加法控制信号
        output LPC,                        // PC 装载控制信号
        output LAR,                        // AR 装载控制信号
        output reg LIR,                    // IR 装载控制信号（T3 上升沿锁存）
        output STOP,                       // 停机/暂停控制信号
        output SHORT,                      // 短周期控制信号
        output [3:0] S, SEL                // S 为 ALU 功能选择，SEL 为寄存器选择
    );
    // ST0 是控制器内部阶段标志：
    // ST0=0 表示初始/装载阶段，ST0=1 表示已经进入后续执行阶段。
    reg ST0;
    wire SST0;
    // Q 在 T3 下降沿锁存当前面板工作模式，避免组合开关抖动直接影响控制输出。
    reg [2:0] Q; 
    wire WRITE_REG;
    wire READ_REG;
    wire INS_FETCH;
    wire READ_MEM;
    wire WRITE_MEM;

	// 在每个 T3 下降沿采样模式开关，将有效模式写入 Q。
	// CLR 低电平复位时将 Q 清零，避免复位后模式译码命中错误工作模式。
	// 未定义的开关组合统一归入 3'b111，后续不会命中任何工作模式。
	always @(negedge T3 or negedge CLR)
	begin
		if (!CLR) begin
			Q <= 3'b000;
		end
		else begin
			case  (SWC_SWB_SWA)
				3'b100:  Q<=3'b100;
				3'b011:  Q<=3'b011;
				3'b000:  Q<=3'b000;
				3'b010:  Q<=3'b010;
				3'b001:  Q<=3'b001;
			    default:
			             Q<=3'b111;
			 endcase
		end
	end			
    // 工作模式译码：每个信号对应流程图中的一个入口分支。
    assign WRITE_REG = (Q == 3'b100) ? 1: 0;
    assign READ_REG = (Q == 3'b011) ? 1: 0; // 读寄存器模式
    assign INS_FETCH = (Q == 3'b000) ? 1: 0; // 取指模式
    assign READ_MEM = (Q == 3'b010) ? 1: 0; // 读存储器模式
    assign WRITE_MEM = (Q == 3'b001) ? 1: 0; // 写存储器模式


    // ST0 状态更新逻辑：
    // 1. CLR 低电平复位时回到初始阶段；
    // 2. SST0 有效时从第一阶段进入第二阶段；
    // 3. 写寄存器模式完成第二个节拍后回到第一阶段，便于继续手动写入。
    always @(negedge T3 or negedge CLR) begin
        if (CLR == 0 ) begin
            ST0 <= 1'b0;
        end
        else if (SST0) begin // ST0 为 0 且满足置位条件时置 1
            ST0 <= 1'b1;
        end
        else if(ST0 && W2 && WRITE_REG)begin
            ST0 <= 1'b0;
        end
        // 注意：除写寄存器模式外，ST0 主要由 CLR 复位，由 SST0 置位。
        // 如需在其他模式下从 1 回到 0，需要补充相应逻辑。
        // 当前保留原有状态转换方式。
    end
    // SST0 是 ST0 的置位条件。
    // 不同模式进入第二阶段所需的节拍不同：写寄存器使用 W2，读/写存储器和取指使用 W1。
    // 注意：SST0 与模式译码一致使用锁存后的 Q，而非原始开关 SWC_SWB_SWA，
    // 避免切换开关瞬间 SST0 与当前模式不匹配导致 ST0 在错误模式下被置位。
    assign SST0 = (ST0 == 1'b0) && (
               (Q == 3'b100 && W2) || // 写寄存器模式，W2 有效
               (Q == 3'b010 && W1) || // 读存储器模式，W1 有效
               (Q == 3'b001 && W1) || // 写存储器模式，W1 有效
               (Q == 3'b000 && W1)
           );

    // PCINC / LIR 时序化驱动（解决 TEC-8 吞指令问题）。
    // 原组合逻辑中 LIR 与 PCINC 在同一节拍同时拉高，但二者到 PC 计数器、IR 寄存器的
    // 布线/门延时不一致，在 TEC-8 实验台上出现“PCINC 先于 LIR 生效 → PC 先 +1 →
    // 存储器地址已变 → LIR 锁存到的是下下条指令”的反序触发，从而吞掉一条指令。
    // 这里改为在 T3 上升沿用寄存器同步锁存，且 PCINC、LIR 取完全相同的表达式，
    // 保证两者在 PC/IR 的响应沿（下降沿）之前已稳定且严格同步，消除反序触发。
    // 启动拍（INS_FETCH && !ST0 && W1）只装 PC，不取指；ST0=1 后按指令类型取指：
    //   短指令（含条件跳转不成立）在 W1 取指；
    //   长指令及条件跳转成立/无条件跳转在 W2 取指。
    // 参考 TEC-8 实测可行实现：github.com/xqmmcqs/nobugCPU (nobugCPU-pipe.vhd)。
    wire FETCH;
    assign FETCH = (INS_FETCH && ST0) && (
               (W1 && (
                   (IR7_IR4 == 4'b0000) || // NOP
                   (IR7_IR4 == 4'b0001) || // ADD
                   (IR7_IR4 == 4'b0010) || // SUB
                   (IR7_IR4 == 4'b0011) || // AND
                   (IR7_IR4 == 4'b0100) || // INC
                   (IR7_IR4 == 4'b0111 && !C) || // JC 不跳转
                   (IR7_IR4 == 4'b1000 && !Z) || // JZ 不跳转
                   (IR7_IR4 == 4'b1011) || // MOV
                   (IR7_IR4 == 4'b1100) || // CMP
                   (IR7_IR4 == 4'b1101) || // NOT
                   (IR7_IR4 == 4'b1111)    // DEC
               )) ||
               (W2 && (
                   (IR7_IR4 == 4'b0101) || // LD
                   (IR7_IR4 == 4'b0110) || // ST
                   (IR7_IR4 == 4'b0111 && C) || // JC 跳转成立
                   (IR7_IR4 == 4'b1000 && Z) || // JZ 跳转成立
                   (IR7_IR4 == 4'b1001)    // JMP
               ))
           );
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

    // ----------------------------------------------------------------------
    // 控制信号译码（数据流描述）。
    // 以下各 assign 等价于原先的 case 行为描述：在命中的模式、指令和节拍中拉高
    // 对应控制信号。指令译码信号已内含 INS_FETCH && ST0 条件，故下方表达式直接
    // 使用 ADD/SUB/... 而不再重复乘该条件。
    // ----------------------------------------------------------------------
    // 指令译码：仅在取指执行阶段（INS_FETCH && ST0）有效。
    wire ADD   = (IR7_IR4 == 4'b0001) & INS_FETCH & ST0; // 加法，结果写回并更新 Z/C
    wire SUB   = (IR7_IR4 == 4'b0010) & INS_FETCH & ST0; // 减法
    wire AND_  = (IR7_IR4 == 4'b0011) & INS_FETCH & ST0; // 按位与（AND 为关键字）
    wire INC   = (IR7_IR4 == 4'b0100) & INS_FETCH & ST0; // 自增
    wire LD    = (IR7_IR4 == 4'b0101) & INS_FETCH & ST0; // 取数到寄存器
    wire ST    = (IR7_IR4 == 4'b0110) & INS_FETCH & ST0; // 寄存器存入存储器
    wire JC    = (IR7_IR4 == 4'b0111) & INS_FETCH & ST0; // 进位则跳
    wire JZ    = (IR7_IR4 == 4'b1000) & INS_FETCH & ST0; // 零则跳
    wire JMP   = (IR7_IR4 == 4'b1001) & INS_FETCH & ST0; // 无条件跳转
    wire MOV   = (IR7_IR4 == 4'b1011) & INS_FETCH & ST0; // 寄存器间传送
    wire CMP   = (IR7_IR4 == 4'b1100) & INS_FETCH & ST0; // 比较，只更新 Z/C
    wire NOT_  = (IR7_IR4 == 4'b1101) & INS_FETCH & ST0; // 取反（NOT 为关键字）
    wire STP   = (IR7_IR4 == 4'b1110) & INS_FETCH & ST0; // 停机
    wire DEC   = (IR7_IR4 == 4'b1111) & INS_FETCH & ST0; // 自减
    wire NOP   = (IR7_IR4 == 4'b0000) & INS_FETCH & ST0; // 空操作

    // 短指令集合：单拍完成执行并取下一条指令（条件跳转不成立时也属短指令）。
    wire SHORT_INSTR = NOP | ADD | SUB | AND_ | INC | MOV | CMP | NOT_ | DEC
                     | (JC & ~C) | (JZ & ~Z);

    // 寄存器堆 / 寄存器选择信号
    assign SELCTL = (WRITE_REG & (W1|W2)) | (READ_REG & (W1|W2))
                  | ((READ_MEM|WRITE_MEM) & W1);
    assign SEL[3] = (WRITE_REG & (W1|W2) & ST0) | (READ_REG & W2);
    assign SEL[2] = (WRITE_REG & W2);
    assign SEL[1] = (WRITE_REG & ((W1 & ~ST0) | (W2 & ST0))) | (READ_REG & W2);
    assign SEL[0] = (WRITE_REG & W1) | (READ_REG & (W1|W2));
    assign DRW    = (WRITE_REG & (W1|W2))
                  | ((ADD|SUB|AND_|INC|MOV|NOT_|DEC) & W1)
                  | (LD & W2);

    // PC / AR / IR 装载与递增
    assign LPC   = (INS_FETCH & ~ST0 & W1) | (JMP & W1);
    assign PCADD = ((C & JC) | (Z & JZ)) & W1;
    assign LAR   = ((READ_MEM|WRITE_MEM) & W1 & ~ST0) | ((LD|ST) & W1);
    assign ARINC = (READ_MEM|WRITE_MEM) & W1 & ST0;

    // 总线控制
    assign SBUS = (WRITE_REG & (W1|W2))
                | (READ_MEM & W1 & ~ST0)
                | (WRITE_MEM & W1)
                | (INS_FETCH & ~ST0 & W1);
    assign MBUS = (READ_MEM & W1 & ST0) | (LD & W2);
    assign ABUS = ((ADD|SUB|AND_|INC|LD|ST|JMP|MOV|CMP|NOT_|DEC) & W1) | (ST & W2);

    // ALU 运算控制
    assign M   = ((AND_|LD|ST|JMP|MOV|NOT_) & W1) | (ST & W2);
    assign CIN = (ADD | DEC) & W1;
    assign S[3] = ((ADD|AND_|LD|JMP|MOV|DEC) & W1) | (ST & (W1|W2));
    assign S[2] = ((SUB|JMP|CMP|DEC) & W1) | (ST & W1);
    assign S[1] = ((SUB|AND_|LD|ST|JMP|MOV|CMP|DEC) & W1) | (ST & W2);
    assign S[0] = ((ADD|AND_|JMP|DEC) & W1) | (ST & W1);

    // 标志位写
    assign LDZ = (ADD|SUB|AND_|INC|MOV|CMP|NOT_|DEC) & W1;
    assign LDC = (ADD|SUB|INC|CMP|DEC) & W1;

    // 存储器写
    assign MEMW = (WRITE_MEM & W1 & ST0) | (ST & W2);

    // 拍数 / 停机控制
    assign SHORT = (READ_MEM & W1) | (WRITE_MEM & W1)
                 | (INS_FETCH & ~ST0 & W1) | (SHORT_INSTR & W1);
    assign STOP  = ((WRITE_REG|READ_REG) & (W1|W2))
                 | ((READ_MEM|WRITE_MEM) & W1)
                 | (INS_FETCH & ~ST0 & W1) | (STP & W1);

endmodule
