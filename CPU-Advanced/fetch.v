`timescale 1ns / 1ps
`include "CPU.vh"

`define STARTADDR 32'H00000034   // ������ʼ��ַΪ34H

module fetch(                    // ȡָ��
    input             clk,       // ʱ��
    input             resetn,    // ��λ�źţ��͵�ƽ��Ч
    input             IF_valid,  // ȡָ����Ч�ź�
    input             ID_allow_in,
    input             next_fetch,// ȡ��һ��ָ���������PCֵ
//    input             first_fetch,
    input      [33:0] jbr_bus,   // ��ת����
    output         IF_over,   // IFģ��ִ�����
    output     [97:0] IF_ID_bus, // IF->ID����
    
    //5����ˮ�����ӿ�
    input      [32:0] exc_bus,   // Exception pc����
        
    //չʾPC��ȡ����ָ��
    output     [31:0] IF_pc,
    output     [31:0] IF_inst,
    //SRAM����
    output            inst_req,
    input             inst_addr_ok,
    output     [31:0] inst_addr,
    input      [31:0] inst_rdata,
    input             inst_data_ok
);
    
    wire inst_waiting;


//�쳣���
    wire AdEL_exc_inst;//ȡָ����
    wire inst_exc_bd;//BD��֧�ӳٲ�
    wire [31:0] exc_badvaddr;//�����ַ

//-----{���������PC}begin
    wire [31:0] next_pc;
    wire [31:0] seq_pc;
    reg  [31:0] pc;
    
    //��תpc
    wire        jbr_taken;
    wire [31:0] jbr_target;
    assign {inst_exc_bd,jbr_taken, jbr_target} = jbr_bus;  // ��ת���ߴ��Ƿ���ת��Ŀ���ַ
    
    //Exception PC
    wire        exc_valid;
    wire [31:0] exc_pc;
    assign {exc_valid,exc_pc} = exc_bus;
    
    //pc+4
    assign seq_pc[31:2]    = pc[31:2] + 1'b1;  // ��һָ���ַ��PC=PC+4
    assign seq_pc[1:0]     = pc[1:0];

    // ��ָ�����Exception,��PCΪExceptio��ڵ�ַ
    //         ��ָ����ת����PCΪ��ת��ַ������Ϊpc+4
    assign next_pc = exc_valid ? exc_pc : 
                     jbr_taken ? jbr_target : seq_pc;
    
    assign AdEL_exc_inst=(pc[1:0]!=2'b00)&&IF_valid;
    assign exc_badvaddr=pc;
    
    wire IF_inst_ok;
    
    always @(posedge clk)    // PC���������
    begin
        if (!resetn)
        begin
            pc <= `STARTADDR; // ��λ��ȡ������ʼ��ַ
        end
        else if (next_fetch)
        begin
            pc <= next_pc;    // ����λ��ȡ��ָ��
        end
    end
    
    assign inst_addr = {pc[31:2],2'b00};
    
    assign inst_req = IF_valid && !IF_over;
    assign inst_waiting = IF_valid && !IF_inst_ok ;
    
    assign IF_inst_ok = inst_buff_valid || (IF_valid && inst_data_ok );
    
    assign IF_over = IF_valid && IF_inst_ok;    
    
    reg inst_buff_valid;
    reg [31:0] inst_buff;
    // ����������
    always @(posedge clk) begin
        if (!resetn) begin
            inst_buff_valid <= 1'b0;
            inst_buff       <= 32'h0;
        end
        else if (inst_data_ok && IF_valid && !ID_allow_in) begin
            // ��ָ��������Ч������׶β������������ʱ�����뻺����
            inst_buff_valid <= 1'b1;
            inst_buff       <= inst_rdata;
        end
        else if (ID_allow_in) begin
            // ������׶������������ʱ�����������
            inst_buff_valid <= 1'b0;
            inst_buff       <= 32'h0;
        end
    end
    
    wire [31:0] final_inst;
    assign final_inst = inst_buff_valid ? inst_buff :inst_rdata;
    
//-----{IF->ID����}begin
    assign IF_ID_bus = { AdEL_exc_inst,
                         inst_exc_bd,
                         exc_badvaddr,
                         pc, 
                         final_inst};  
//-----{IF->ID����}end

//-----{չʾIFģ���PCֵ��ָ��}begin
    assign IF_pc   = pc;
    assign IF_inst = inst_rdata;
//-----{չʾIFģ���PCֵ��ָ��}end
endmodule