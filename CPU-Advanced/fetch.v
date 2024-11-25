`timescale 1ns / 1ps
`include "CPU.vh"

`define STARTADDR 32'H00000034   // 程序起始地址为34H

module fetch(                    // 取指级
    input             clk,       // 时钟
    input             resetn,    // 复位信号，低电平有效
    input             IF_valid,  // 取指级有效信号
    input             ID_allow_in,
    input             next_fetch,// 取下一条指令，用来锁存PC值
//    input             first_fetch,
    input      [33:0] jbr_bus,   // 跳转总线
    output         IF_over,   // IF模块执行完成
    output     [97:0] IF_ID_bus, // IF->ID总线
    
    //5级流水新增接口
    input      [32:0] exc_bus,   // Exception pc总线
        
    //展示PC和取出的指令
    output     [31:0] IF_pc,
    output     [31:0] IF_inst,
    //SRAM总线
    output            inst_req,
    input             inst_addr_ok,
    output     [31:0] inst_addr,
    input      [31:0] inst_rdata,
    input             inst_data_ok
);
    
    wire inst_waiting;


//异常添加
    wire AdEL_exc_inst;//取指例外
    wire inst_exc_bd;//BD分支延迟槽
    wire [31:0] exc_badvaddr;//出错地址

//-----{程序计数器PC}begin
    wire [31:0] next_pc;
    wire [31:0] seq_pc;
    reg  [31:0] pc;
    
    //跳转pc
    wire        jbr_taken;
    wire [31:0] jbr_target;
    assign {inst_exc_bd,jbr_taken, jbr_target} = jbr_bus;  // 跳转总线传是否跳转和目标地址
    
    //Exception PC
    wire        exc_valid;
    wire [31:0] exc_pc;
    assign {exc_valid,exc_pc} = exc_bus;
    
    //pc+4
    assign seq_pc[31:2]    = pc[31:2] + 1'b1;  // 下一指令地址：PC=PC+4
    assign seq_pc[1:0]     = pc[1:0];

    // 新指令：若有Exception,则PC为Exceptio入口地址
    //         若指令跳转，则PC为跳转地址；否则为pc+4
    assign next_pc = exc_valid ? exc_pc : 
                     jbr_taken ? jbr_target : seq_pc;
    
    assign AdEL_exc_inst=(pc[1:0]!=2'b00)&&IF_valid;
    assign exc_badvaddr=pc;
    
    wire IF_inst_ok;
    
    always @(posedge clk)    // PC程序计数器
    begin
        if (!resetn)
        begin
            pc <= `STARTADDR; // 复位，取程序起始地址
        end
        else if (next_fetch)
        begin
            pc <= next_pc;    // 不复位，取新指令
        end
    end
    
    assign inst_addr = {pc[31:2],2'b00};
    
    assign inst_req = IF_valid && !IF_over;
    assign inst_waiting = IF_valid && !IF_inst_ok ;
    
    assign IF_inst_ok = inst_buff_valid || (IF_valid && inst_data_ok );
    
    assign IF_over = IF_valid && IF_inst_ok;    
    
    reg inst_buff_valid;
    reg [31:0] inst_buff;
    // 缓冲区管理
    always @(posedge clk) begin
        if (!resetn) begin
            inst_buff_valid <= 1'b0;
            inst_buff       <= 32'h0;
        end
        else if (inst_data_ok && IF_valid && !ID_allow_in) begin
            // 当指令数据有效且译码阶段不允许接收数据时，存入缓冲区
            inst_buff_valid <= 1'b1;
            inst_buff       <= inst_rdata;
        end
        else if (ID_allow_in) begin
            // 当译码阶段允许接收数据时，清除缓冲区
            inst_buff_valid <= 1'b0;
            inst_buff       <= 32'h0;
        end
    end
    
    wire [31:0] final_inst;
    assign final_inst = inst_buff_valid ? inst_buff :inst_rdata;
    
//-----{IF->ID总线}begin
    assign IF_ID_bus = { AdEL_exc_inst,
                         inst_exc_bd,
                         exc_badvaddr,
                         pc, 
                         final_inst};  
//-----{IF->ID总线}end

//-----{展示IF模块的PC值和指令}begin
    assign IF_pc   = pc;
    assign IF_inst = inst_rdata;
//-----{展示IF模块的PC值和指令}end
endmodule