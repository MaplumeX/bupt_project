module ver1 (
        //����˿�
        input wire [2:0] SWC_SWB_SWA,      // ģʽѡ���ź�
        input wire [3:0] IR7_IR4,          // ָ��Ĵ�����4λ
        input wire CLR,                    // ��λ�ź� (����Ч)
        input wire T3,                     // ʱ���ź� T3 (��ΪST0��ʱ��)
        input wire W1, W2, W3,             // ΢ָ��ʱ���ź�
        input wire C, Z,                   // ״̬��־����λC����Z
        //����˿�
        output wire SELCTL,                 // ѡ������ź�
        output wire ABUS,                   // ����ALU�����Ƿ������������
        output wire SBUS,                   // �����ֶ����������Ƿ������������
        output wire MBUS,                   // ����˫�˿ڴ洢���������͵���������
        output wire M,CIN,                  // M�ǿ���ALU���߼����㻹���������� CIN��������S���M��Ӧ�Ĳ������н�λ���������޽�λ����
        output wire DRW,                    // ���ƼĴ���д���ź�
        output wire LDZ,                    // ��Ϊ1����������Ϊ0ʱ��ZΪ1������Ϊ0����ZΪ0
        output wire LDC,                    // ��Ϊ1����������������λʱ��CΪ1�����޽�λ����CΪ0
        output wire MEMW,                   // ���ƴ洢��˫�˿�RAMд���źţ�Ϊ1ʱ�������е�ֵд�봢����
        output wire ARINC,                  // ���Ƶ�ַ�Ĵ���AR��ֵ��1�ź�
        output wire PCINC,                  // ���Ƶ�ַ�Ĵ���PC��ֵ��1�ź�
        output wire PCADD,                  // ����PC��ָ���ַ�ź�
        output wire LPC,                    // ���ƽ���������������д��PC�Ĵ���
        output wire LAR,                    // ���ƽ���������������д��AR�Ĵ���
        output wire LIR,                    // ���ƽ���������������д��IR�Ĵ���
        output wire STOP,                   // ֹͣ�ź�
        output wire SHORT,                  // ����ʱ�ź�
        output wire LONG,                   // ����ʱ�ź�
        output wire [3:0] S, SEL            // S����ALU������ͬ�ĺ��� SEL���� 2 - 4 ������
    );
    //״̬��ʶ
    reg ST0;
    wire SST0;
    //���ֻ���״̬
    reg [2:0] Q; 
    wire WRITE_REG;
    wire READ_REG;
    wire INS_FETCH;
    wire READ_MEM;
    wire WRITE_MEM;

    //ԭ����ָ������
    wire NOP;
    wire ADD;
    wire SUB;
    wire AND;
    wire INC;
    wire LD;
    wire ST;
    wire JC;
    wire JZ;
    wire JMP;
    wire STP;
    //���ӵ�ָ��
    wire OUT;
    wire MOV;
    wire CMP;
    wire NOT;
    wire DEC;

	always @(negedge T3)
	begin 
			case  (SWC_SWB_SWA)
				3'b100:  Q=100;
				3'b011:  Q=011;
				3'b000:  Q=000;
				3'b010:  Q=010;
				3'b001:  Q=001;
			    default:
			             Q=111; 
			 endcase 
			     
	end			
    assign WRITE_REG = (Q == 3'b100) ? 1: 0;
    assign READ_REG = (Q == 3'b011) ? 1: 0; // ��ȡ�Ĵ���ģʽ
    assign INS_FETCH = (Q == 3'b000) ? 1: 0; // ָ��ȡָģʽ
    assign READ_MEM = (Q == 3'b010) ? 1: 0; // ��ȡ�洢��ģʽ
    assign WRITE_MEM = (Q == 3'b001) ? 1: 0; // д��洢��ģʽ


    assign NOP = (IR7_IR4 == 4'b0000 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign ADD = (IR7_IR4 == 4'b0001 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign SUB = (IR7_IR4 == 4'b0010 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign AND = (IR7_IR4 == 4'b0011 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign INC = (IR7_IR4 == 4'b0100 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign LD = (IR7_IR4 == 4'b0101 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign ST = (IR7_IR4 == 4'b0110 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign JC = (IR7_IR4 == 4'b0111 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign JZ = (IR7_IR4 == 4'b1000 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign JMP = (IR7_IR4 == 4'b1001 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign STP = (IR7_IR4 == 4'b1110 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;

    assign OUT = (IR7_IR4 == 4'b1010 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign MOV = (IR7_IR4 == 4'b1011 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign CMP = (IR7_IR4 == 4'b1100 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign NOT = (IR7_IR4 == 4'b1101 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;
    assign DEC = (IR7_IR4 == 4'b1111 && INS_FETCH == 1 && ST0 == 1) ? 1: 0;


    always @(negedge T3 or negedge CLR) begin
        if (CLR == 0 ) begin
            ST0 <= 1'b0;
        end
        else if (SST0) begin // st0_set_condition �� ST0=0 ���ض���������ʱΪ��
            ST0 <= 1'b1;
        end
        else if(ST0 && W2 && WRITE_REG)begin
    ST0 <=1'b0;
    end
        // ע��: ST0 �����Զ���1��ת��0�����Ǳ�CLR��λ��
        // �����ҪST0��ĳЩ�����´�1�ص�0����Ҫ������߼���
        // ����ԭʼ���룬ST0 ��0��1��ͱ��֡�
    end
    assign SST0 = (ST0 == 1'b0) && (
               (SWC_SWB_SWA == 3'b100 && W2) || // д�Ĵ���ģʽ��W2��Ч
               (SWC_SWB_SWA == 3'b010 && W1) || // ���洢��ģʽ��W1��Ч
               (SWC_SWB_SWA == 3'b001 && W1) || // д�洢��ģʽ��W1��Ч
               (SWC_SWB_SWA == 3'b000 && W2)
           );

    assign SBUS = ((WRITE_REG ||(READ_MEM && !ST0) || WRITE_MEM ) && W1) || (WRITE_REG && W2) ||((INS_FETCH && !ST0) && W2);
    assign SEL[3] = ((WRITE_REG && (W1 || W2)) && ST0) || (READ_REG && W2);
    assign SEL[2] = WRITE_REG && W2;
    assign SEL[1] = (WRITE_REG && ((W1 && !ST0) || (W2 && ST0))) || (READ_REG && W2);
    assign SEL[0] = (WRITE_REG && W1) || (READ_REG && (W1 || W2));
    assign SELCTL = ((WRITE_REG || READ_REG) && (W1 || W2)) || ((READ_MEM || WRITE_MEM) && W1);
    assign DRW = (WRITE_REG && (W1 || W2)) || ((ADD || SUB || AND || INC) && W1) || ((NOT || MOV || DEC) && W2) || (LD && W2);
    assign STOP = ((WRITE_REG || READ_REG) && (W1 || W2)) || ((READ_MEM || WRITE_MEM) && W1) || (STP && W1) || (INS_FETCH && !ST0 && W1);
    assign LAR = ((READ_MEM || WRITE_MEM) && W1 && !ST0)||((ST || LD) && W1);
    assign SHORT = ((READ_MEM || WRITE_MEM) && W1) || ((NOP || ADD || SUB || AND || INC || (JC && !C) || (JZ && !Z)) && W1);
    assign MBUS = (READ_MEM && W1 && ST0) || (LD && W2);
    assign ARINC = (WRITE_MEM || READ_MEM) && W1 && ST0;
    assign MEMW = (WRITE_MEM && W1 && ST0) || (ST && W2);
    assign PCINC = ((NOP || ADD || SUB || AND || INC || (JC && !C) || (JZ && !Z) || OUT || MOV || CMP || NOT || DEC) && W1) || ((LD || ST || JMP || (JC && C) || (JZ && Z)) && W2);
    assign LIR = ((NOP || ADD || SUB || AND || INC || (JC && !C) || (JZ && !Z) || OUT || MOV || CMP || NOT || DEC) && W1) || ((LD || ST || JMP || (JC && C) || (JZ && Z)) && W2);
    assign CIN = (ADD && W1) || (DEC && W2);
    assign ABUS = ((ADD || SUB || AND || INC || LD || ST || JMP) && W1) || (ST && W2) || ((MOV || OUT || CMP || NOT || DEC) && W2);
    assign LDZ = ((ADD || SUB || AND || INC) && W1) || ((CMP || DEC) && W2);
    assign LDC = ((SUB || INC) && W1) || ((CMP || NOT || DEC) && W2);
    assign M = ((AND || LD || ST || JMP) && W1) || (ST && W2) || ((NOT || MOV || OUT) && W2);
    assign S[3] = ((ADD || AND || LD || ST || JMP) && W1) || (ST && W2) || ((OUT || MOV || DEC) && W2) ;
    assign S[2] = ((SUB || ST || JMP) && W1) || ((CMP || DEC) && W2);
    assign S[1] = ((SUB || AND || LD || ST || JMP) && W1) || (ST && W2) || ((OUT || CMP || MOV || DEC) && W2);
    assign S[0] = ((ADD || AND || ST || JMP) && W1) || (DEC && W2);
    assign LPC  = (JMP && W1) || (INS_FETCH && !ST0 && W2);
    assign LONG = (LD || ST || JMP || (JC && C) || (JZ && Z)) && W1;
    assign PCADD = ((C && JC) || (Z && JZ)) && W1;

endmodule

