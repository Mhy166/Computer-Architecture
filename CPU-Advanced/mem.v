`timescale 1ns / 1ps
//*************************************************************************
//   > �ļ���: mem.v
//   > ����  :�弶��ˮCPU�ķô�ģ��
//   > ����  : LOONGSON
//   > ����  : 2016-04-14
//*************************************************************************
module mem(                          // �ô漶
    input              clk,          // ʱ��
    input              resetn,
    input              WB_allow_in,
    input              MEM_valid,    // �ô漶��Ч�ź�
    input      [191:0] EXE_MEM_bus_r,// EXE->MEM����
    output             MEM_over,     // MEMģ��ִ�����
    output     [157:0] MEM_WB_bus,   // MEM->WB����
    //5����ˮ�����ӿ�
    input              MEM_allow_in, // MEM�������¼�����
    output     [  37:0] MEM_wdest_wdata,    // MEM��Ҫд�ؼĴ����ѵ�Ŀ���ַ��
    output        data_req,    
    output        data_wr,     
    output [ 1:0] data_size,   
    output [ 3:0] data_wstrb, 
    output [31:0] data_addr,
    input         data_addr_ok,
    output [31:0] data_wdata,
    input  [31:0] data_rdata,
    input         data_data_ok,
    //չʾPC
    output     [ 31:0] MEM_pc
);
//-----{EXE->MEM����}begin
    wire AdEL_exc_inst;
    wire inst_exc_bd;
    wire [31:0] exc_badvaddr;
    wire interrupt;
    wire reserve_inst;
    wire overflow_exc;
    
    //�ô���Ҫ�õ���load/store��Ϣ
    wire [3 :0] mem_control;  //MEM��Ҫʹ�õĿ����ź�
    wire [31:0] store_data;   //store�����Ĵ������
    
    //EXE�����HI/LO����
    wire [31:0] exe_result;
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    wire mem_wait;
    //д����Ҫ�õ�����Ϣ
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall��eret��д�ؼ�������Ĳ��� 
    wire       eret;
    wire       break;
    wire       rf_wen;    //д�صļĴ���дʹ��
    wire [4:0] rf_wdest;  //д�ص�Ŀ�ļĴ���
    
    //pc
    wire [31:0] pc;    
    
    assign {
            AdEL_exc_inst,
            inst_exc_bd,
            exc_badvaddr,
            interrupt,
            reserve_inst,
            overflow_exc,
            mem_control,
            store_data,
            exe_result,
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
            rf_wen,
            rf_wdest,
            pc         } = EXE_MEM_bus_r;  
//-----{EXE->MEM����}end

//-----{load/store�ô�}begin
    wire inst_load;  //load����
    wire inst_store; //store����
    wire ls_word;    //load/storeΪ�ֽڻ�����,0:byte;1:word
    wire lb_sign;    //loadһ�ֽ�Ϊ�з���load
    assign {inst_load,inst_store,ls_word,lb_sign} = mem_control;

    
    //������
    reg data_buff_valid;
    reg [31:0] data_buff;
    // ����������
    always @(posedge clk) begin
        if (!resetn) begin
            data_buff_valid <= 1'b0;
            data_buff       <= 32'h0;
        end
        else if (data_data_ok && MEM_valid && !WB_allow_in) begin
            // ��ָ��������Ч������׶β������������ʱ�����뻺����
            data_buff_valid <= 1'b1;
            data_buff       <= data_rdata;
        end
        else if (WB_allow_in) begin
            // ������׶������������ʱ�����������
            data_buff_valid <= 1'b0;
            data_buff       <= 32'h0;
        end
    end
    
    wire data_waiting;
    wire MEM_data_ok;
  
    //�ô��д��ַ
    assign data_wr = inst_store && MEM_valid;
    assign data_addr = exe_result;
    assign data_req   = (MEM_valid && !MEM_over && inst_load) || (inst_store && MEM_valid) ;
    assign data_waiting = MEM_valid && !MEM_data_ok ;
    assign MEM_data_ok = data_buff_valid || (MEM_valid && data_data_ok);
    
    assign data_wstrb = (MEM_valid && inst_store)? (ls_word? 4'b1111:{data_addr[1:0]==2'd3,data_addr[1:0]==2'd2,data_addr[1:0]==2'd1,data_addr[1:0]==2'd0}):4'b0000;
    assign data_wdata = data_addr[1:0]== 2'b00 ?store_data:
                         data_addr[1:0]== 2'b01 ?{16'd0, store_data[7:0], 8'd0}:
                         data_addr[1:0]== 2'b10 ?{8'd0, store_data[7:0], 16'd0}:
                         {store_data[7:0], 24'd0};   
    assign data_size =   ls_word ? 2'b10:2'b00;
     //load���������� 
     wire [31:0] final_load_data;
     assign final_load_data = data_buff_valid ? data_buff :data_rdata;
     
     wire        load_sign;
     wire [31:0] load_result;
     assign load_sign = (data_addr[1:0]==2'd0) ? final_load_data[ 7] :
                       (data_addr[1:0]==2'd1) ? final_load_data[15] :
                       (data_addr[1:0]==2'd2) ? final_load_data[23] : final_load_data[31] ;
     assign load_result[7:0] = (data_addr[1:0]==2'd0) ? final_load_data[ 7:0 ] :
                               (data_addr[1:0]==2'd1) ? final_load_data[15:8 ] :
                               (data_addr[1:0]==2'd2) ? final_load_data[23:16] :
                                                      final_load_data[31:24] ;
     assign load_result[31:8]= ls_word ? final_load_data[31:8] : {24{lb_sign & load_sign}};
     
//-----{load/store�ô�}end
//�ô����⣺��ַ��ֻ�������Ч���У��ֽڵ�load/store�����
    wire AdEL_exc_data;
    wire AdES_exc_data;
    wire exc_badvaddr_new;
    assign AdEL_exc_data = inst_load && ls_word && data_addr[1:0]!=2'b00;
    assign AdES_exc_data = inst_store && ls_word&& data_addr[1:0]!=2'b00;
    assign exc_badvaddr_new=AdEL_exc_inst?exc_badvaddr:data_addr;
    

    wire MEM_valid_load;
    assign MEM_valid_load = MEM_valid && MEM_data_ok;
        
    
    assign MEM_over = inst_load ? MEM_valid_load : MEM_valid;
//-----{MEMִ�����}end

//-----{MEMģ���destֵ}begin
   //ֻ����MEMģ����Чʱ����д��Ŀ�ļĴ����Ų�������
    assign mem_wait=(mfhi|mflo|mfc0|inst_load);
//-----{MEMģ���destֵ}end

//-----{MEM->WB����}begin
    wire [31:0] mem_result; //MEM����WB��resultΪload�����EXE���
    assign mem_result = inst_load ? load_result : exe_result;
    
    assign MEM_wdest_wdata = {mem_wait,rf_wdest & {5{MEM_valid}},mem_result};
    
    assign MEM_WB_bus = {
                        AdEL_exc_inst,inst_exc_bd,exc_badvaddr_new,
                         interrupt,reserve_inst,overflow_exc,
                         AdEL_exc_data,AdES_exc_data,
                         rf_wen,rf_wdest,                   // WB��Ҫʹ�õ��ź�
                         mem_result,                        // ����Ҫд�ؼĴ���������
                         lo_result,                         // �˷���32λ���������
                         hi_write,lo_write,                 // HI/LOдʹ�ܣ�����
                         mfhi,mflo,                         // WB��Ҫʹ�õ��ź�,����
                         mtc0,mfc0,cp0r_addr,syscall,eret,break,  // WB��Ҫʹ�õ��ź�,����
                         pc};                               // PCֵ
//-----{MEM->WB����}begin

//-----{չʾMEMģ���PCֵ}begin
    assign MEM_pc = pc;
//-----{չʾMEMģ���PCֵ}end
endmodule

