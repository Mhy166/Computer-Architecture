`timescale 1ns / 1ps
//*************************************************************************
//   > �ļ���: wb.v
//   > ����  :�弶��ˮCPU��д��ģ��
//   > ����  : LOONGSON
//   > ����  : 2016-04-14
//*************************************************************************
`define EXC_ENTER_ADDR 32'd0     // Excption��ڵ�ַ��
                                 // �˴�ʵ�ֵ�Exceptionֻ��SYSCALL
module wb(                       // д�ؼ�
    input          WB_valid,     // д�ؼ���Ч
    input  [157:0] MEM_WB_bus_r, // MEM->WB����
    output         rf_wen,       // �Ĵ���дʹ��
    output [  4:0] rf_wdest,     // �Ĵ���д��ַ
    output [ 31:0] rf_wdata,     // �Ĵ���д����
    output         WB_over,      // WBģ��ִ�����

     //5����ˮ�����ӿ�
     input             clk,       // ʱ��
     input             resetn,    // ��λ�źţ��͵�ƽ��Ч
     output [ 32:0] exc_bus,      // Exception pc����
     output [  37:0] WB_wdest_wdata,     // WB��Ҫд�ؼĴ����ѵ�Ŀ���ַ��
     output         cancel,       // syscall��eret����д�ؼ�ʱ�ᷢ��cancel�źţ�
                                  // ȡ���Ѿ�ȡ��������������ˮ��ִ�е�ָ��
 
     //չʾPC��HI/LOֵ
     output [ 31:0] WB_pc,
     output [ 31:0] HI_data,
     output [ 31:0] LO_data,
     output [63:0] cp0r_bus
);
//-----{MEM->WB����}begin    
    wire AdEL_exc_inst;
    wire inst_exc_bd;
    wire [31:0] exc_badvaddr;
    wire interrupt;
    wire reserve_inst;
    wire overflow_exc;
    wire AdEL_exc_data;
    wire AdES_exc_data;
    
    //MEM������result
    wire [31:0] mem_result;
    //HI/LO����
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    
    //�Ĵ�����дʹ�ܺ�д��ַ
    wire wen;
    wire [4:0] wdest;
    
    //д����Ҫ�õ�����Ϣ
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall��eret��д�ؼ�������Ĳ��� 
    wire       eret;
    wire       break;
    
    //pc
    wire [31:0] pc;    
    assign {
            AdEL_exc_inst,
            inst_exc_bd,
            exc_badvaddr,
            interrupt,
            reserve_inst,
            overflow_exc,
            AdEL_exc_data,
            AdES_exc_data,
            wen,
            wdest,
            mem_result,
            lo_result,
            hi_write,
            lo_write,
            mfhi,
            mflo,
            mtc0,
            mfc0,
            cp0r_addr,
            syscall,
            eret,
            break,
            pc} = MEM_WB_bus_r;
//-----{MEM->WB����}end

//-----{HI/LO�Ĵ���}begin
    //HI���ڴ�ų˷�����ĸ�32λ
    //LO���ڴ�ų˷�����ĵ�32λ
    reg [31:0] hi;
    reg [31:0] lo;
    
    //Ҫд��HI�����ݴ����mem_result��
    always @(posedge clk)
    begin
        if (hi_write)
        begin
            hi <= mem_result;
        end
    end
    //Ҫд��LO�����ݴ����lo_result��
    always @(posedge clk)
    begin
        if (lo_write)
        begin
            lo <= lo_result;
        end
    end
//-----{HI/LO�Ĵ���}end

//------------------------------------------------------------{cp0Э������}begin
// cp0�Ĵ�������Э������0�Ĵ���
// ÿ��CP0�Ĵ�������ʹ��5λ��cp0��,Ŀǰֻʵ��6���Ĵ���

//9��Count
//31-0��count�ڲ�������
wire [31:0] cp0r_count;

//11��Compare
//��count�Ƚϣ����ʱ������ʱ���ж�
wire [31:0] cp0r_compare;

//12��Status:
//31-23     22        21-16     15-8        7-2       1          0
//ֻ��0   Bev��Ϊ1   ֻ��0  IM�ж�����λ   ֻ��0  EXL���⼶ ȫ���ж�enλ
//�������Bev���ɶ�д����������ҪӲ����
wire [31:0] cp0r_status;

//13��cause:
//31            30       29-16    15-10              9-8        7       6-2          1-0
//BD�ӳٲ�  TI��ʱ��    ֻ��0   IPӲ���ж�6����  ����ж�2��  ֻ��0   ExcCode����   ֻ��0
//ֻ������ж�2���������д��
//Exccode��
//0��Int�ж�
//4��AdeL��ַ������-������
//5��AdeS��ַ������-д����
//8��Sysϵͳ����
//9��Bp�ϵ�
//a��RI����ָ��
//c���������
wire [31:0] cp0r_cause;

//14��epc���������PC������λ�ڷ�֧�ӳٲۣ���ô��¼ǰһ����
//����ɶ�д
wire [31:0] cp0r_epc;

//8��BadVAddr��
//��������ַ����ַ����������ַ�����ֻ��
wire [31:0] cp0r_badvaddr;
   
//���븳ֵ�����ȼ���
//            AdEL_exc_inst,
//            inst_exc_bd,
//            exc_badvaddr,
//            interrupt,
//            reserve_inst,
//            overflow_exc,
//            AdEL_exc_data,
//            AdES_exc_data,
//            syscall,
//            break,
   wire[4:0] exc_excode;
   assign exc_excode = interrupt? 5'h0:
                       AdEL_exc_inst? 5'h4:
                       reserve_inst? 5'ha:
                       overflow_exc? 5'hc:
                       syscall? 5'h8:
                       break?  5'h9:
                       AdEL_exc_data? 5'h4:
                       AdES_exc_data? 5'h5: 5'b11111;
   wire exc;
   assign exc=(exc_excode!=5'b11111);    
   
   //дʹ��
   wire status_wen;
   wire compare_wen;
   wire cause_wen;
   wire epc_wen;
   wire count_wen;
   wire badvaddr_wen;
   
   assign badvaddr_wen  = mtc0 & (cp0r_addr=={5'd8,3'd0});
   assign count_wen     = mtc0 & (cp0r_addr=={5'd9,3'd0});
   assign compare_wen   = mtc0 & (cp0r_addr=={5'd11,3'd0});
   assign status_wen    = mtc0 & (cp0r_addr=={5'd12,3'd0});
   assign cause_wen     = mtc0 & (cp0r_addr=={5'd13,3'd0});
   assign epc_wen       = mtc0 & (cp0r_addr=={5'd14,3'd0});
   
//cp0�Ĵ�����
   wire [31:0] cp0r_rdata;
   assign cp0r_rdata =  (cp0r_addr=={5'd8,3'd0}) ? cp0r_badvaddr: 
                        (cp0r_addr=={5'd9,3'd0}) ? cp0r_count:
                        (cp0r_addr=={5'd11,3'd0}) ? cp0r_compare:
                        (cp0r_addr=={5'd12,3'd0}) ? cp0r_status :
                       (cp0r_addr=={5'd13,3'd0}) ? cp0r_cause  :
                       (cp0r_addr=={5'd14,3'd0}) ? cp0r_epc : 32'd0;
   
//STATUS�Ĵ���   
   reg status_exl_r;
   reg status_ie_r;
   reg[7:0] status_im_r;

   assign cp0r_status = {9'b0,1'b1,6'b0,status_im_r,6'b0,status_exl_r,status_ie_r};
   //status�Ĵ�����Ӳ��������
   always @(posedge clk)
   begin
       if(!resetn)
            status_ie_r<=1'b0;
       else if(status_wen)
            status_ie_r<=mem_result[0];
   end
   
   always @(posedge clk)
   begin
       if(status_wen)
            status_im_r <= mem_result[15:8];
   end
   
   always @(posedge clk)
   begin
       if(!resetn||eret)
            status_exl_r<=1'b0;
       else if(exc)
            status_exl_r<=1'b1;
       else if(status_wen)
            status_exl_r<=mem_result[1];  
   end
   
//CAUSE�Ĵ���
   reg cause_r_bd;
   
   always @(posedge clk)
   begin
       if (!resetn)
           cause_r_bd <= 1'b0;
       else if (exc && !cp0r_status[1])
           cause_r_bd <= inst_exc_bd;
   end
   
   reg[4:0] cause_r_code;
   always @(posedge clk)
   begin
       if (!resetn)
           cause_r_code <= 5'b11111;
       else if(exc)
           cause_r_code <= exc_excode;
   end
   
   wire count_eq_compare;
   assign count_eq_compare=(cp0r_count==cp0r_compare);
   
   reg cause_r_ti;
   always @(posedge clk)
   begin
       if(!resetn)
            cause_r_ti <=1'b0;
       else if(compare_wen)
            cause_r_ti <=1'b0;
       else if(count_eq_compare)
            cause_r_ti <=1'b1;
   end
   
   reg[7:0] cause_r_ip;//1-0λ������ж�,����Ŀǰ��ΪӲ����������0
   always @(posedge clk)
   begin
       if (!resetn)
           cause_r_ip[7:2] <= 6'b0;
       else begin
           cause_r_ip[7] <= cause_r_ti;
       end
   end
   always @(posedge clk)
   begin
        if (!resetn)
           cause_r_ip[1:0] <= 2'b0;
       else if(cause_wen) 
           cause_r_ip[1:0] <= mem_result[9:8];
   end
   assign cp0r_cause = {cause_r_bd,cause_r_ti,14'b0,cause_r_ip,1'b0,cause_r_code,2'b0};
//EPC�Ĵ���begin
   //��Ų�������ĵ�ַ
   //EPC������Ϊ����ɶ�д�ģ�����Ҫepc_wen
   reg [31:0] epc_r;
   assign cp0r_epc = epc_r;
   always @(posedge clk)
   begin
       if (exc && !cp0r_status[1])
       begin
           epc_r <= inst_exc_bd ? (pc-3'd4):pc;
       end
       else if (epc_wen)
       begin
           epc_r <= mem_result;
       end
   end
//EPC�Ĵ���end

//BadVaddr�Ĵ���begin
    reg[31:0] badvaddr_r;
    assign cp0r_badvaddr = badvaddr_r;
    always @(posedge clk)
    begin
        if(exc && (exc_excode==5'h4||exc_excode==5'h5))
        begin
            badvaddr_r <= exc_badvaddr;
        end
    end
//BadVaddr�Ĵ���end
   
//Count�Ĵ���
    reg[31:0] count_r;
    reg tick;
    assign cp0r_count=count_r;
    always@(posedge clk)
    begin
        if(!resetn)
            tick<=1'b0;
        else 
            tick<=~tick;
    end
    always@(posedge clk)
    begin
        if(!resetn)
            count_r<=32'b0;
        else if(count_wen)
            count_r <= mem_result;
        else if(tick)
            count_r <= count_r+1'b1;
    end
   
//Compare�Ĵ���begin
    reg[31:0] compare_r;
    assign cp0r_compare = compare_r;
    always @(posedge clk)
    begin
        if(compare_wen)
        begin
            compare_r <= mem_result;
        end
    end
//Compare�Ĵ���end
   
   
//------------------------------------------------------------{cp0Э������}end

   //eret�����ⷢ����cancel�ź�
   assign cancel = (eret||exc)&& WB_over;
//-----{WBִ�����}begin
    //WBģ�����в���������һ�������
    //��WB_valid����WB_over�ź�
    assign WB_over = WB_valid;
//-----{WBִ�����}end

//-----{WB->regfile�ź�}begin
    assign rf_wen   = wen & WB_over;
    assign rf_wdest = wdest;
    assign rf_wdata = mfhi ? hi :
                      mflo ? lo :
                      mfc0 ? cp0r_rdata : mem_result;
//-----{WB->regfile�ź�}end

//-----{Exception pc�ź�}begin
    wire        exc_valid;
    wire [31:0] exc_pc;
    assign exc_valid = (eret||exc)&& WB_valid;
    //eret���ص�ַΪEPC�Ĵ�����ֵ
    //SYSCALL��excPCӦ��Ϊ{EBASE[31:10],10'h180},
    //����Ϊʵ�飬������EXC_ENTER_ADDRΪ0��������Գ���ı�д
    assign exc_pc = eret ? cp0r_epc:`EXC_ENTER_ADDR;
    assign cp0r_bus={cp0r_status,cp0r_cause};
    assign exc_bus = {exc_valid,exc_pc};
//-----{Exception pc�ź�}end

//-----{WBģ���destֵ}begin
   //ֻ����WBģ����Чʱ����д��Ŀ�ļĴ����Ų�������
    assign WB_wdest_wdata = {1'b0,rf_wdest & {5{WB_valid}},rf_wdata};
//-----{WBģ���destֵ}end

//-----{չʾWBģ���PCֵ��HI/LO�Ĵ�����ֵ}begin
    assign WB_pc = pc;
    assign HI_data = hi;
    assign LO_data = lo;
//-----{չʾWBģ���PCֵ��HI/LO�Ĵ�����ֵ}end
endmodule

