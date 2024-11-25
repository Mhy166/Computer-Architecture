`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: mem.v
//   > 描述  :五级流水CPU的访存模块
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
module mem(                          // 访存级
    input              clk,          // 时钟
    input              resetn,
    input              WB_allow_in,
    input              MEM_valid,    // 访存级有效信号
    input      [191:0] EXE_MEM_bus_r,// EXE->MEM总线
    output             MEM_over,     // MEM模块执行完成
    output     [157:0] MEM_WB_bus,   // MEM->WB总线
    //5级流水新增接口
    input              MEM_allow_in, // MEM级允许下级进入
    output     [  37:0] MEM_wdest_wdata,    // MEM级要写回寄存器堆的目标地址号
    output        data_req,    
    output        data_wr,     
    output [ 1:0] data_size,   
    output [ 3:0] data_wstrb, 
    output [31:0] data_addr,
    input         data_addr_ok,
    output [31:0] data_wdata,
    input  [31:0] data_rdata,
    input         data_data_ok,
    //展示PC
    output     [ 31:0] MEM_pc
);
//-----{EXE->MEM总线}begin
    wire AdEL_exc_inst;
    wire inst_exc_bd;
    wire [31:0] exc_badvaddr;
    wire interrupt;
    wire reserve_inst;
    wire overflow_exc;
    
    //访存需要用到的load/store信息
    wire [3 :0] mem_control;  //MEM需要使用的控制信号
    wire [31:0] store_data;   //store操作的存的数据
    
    //EXE结果和HI/LO数据
    wire [31:0] exe_result;
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    wire mem_wait;
    //写回需要用到的信息
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall和eret在写回级有特殊的操作 
    wire       eret;
    wire       break;
    wire       rf_wen;    //写回的寄存器写使能
    wire [4:0] rf_wdest;  //写回的目的寄存器
    
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
//-----{EXE->MEM总线}end

//-----{load/store访存}begin
    wire inst_load;  //load操作
    wire inst_store; //store操作
    wire ls_word;    //load/store为字节还是字,0:byte;1:word
    wire lb_sign;    //load一字节为有符号load
    assign {inst_load,inst_store,ls_word,lb_sign} = mem_control;

    
    //缓冲区
    reg data_buff_valid;
    reg [31:0] data_buff;
    // 缓冲区管理
    always @(posedge clk) begin
        if (!resetn) begin
            data_buff_valid <= 1'b0;
            data_buff       <= 32'h0;
        end
        else if (data_data_ok && MEM_valid && !WB_allow_in) begin
            // 当指令数据有效且译码阶段不允许接收数据时，存入缓冲区
            data_buff_valid <= 1'b1;
            data_buff       <= data_rdata;
        end
        else if (WB_allow_in) begin
            // 当译码阶段允许接收数据时，清除缓冲区
            data_buff_valid <= 1'b0;
            data_buff       <= 32'h0;
        end
    end
    
    wire data_waiting;
    wire MEM_data_ok;
  
    //访存读写地址
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
     //load读出的数据 
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
     
//-----{load/store访存}end
//访存例外：地址错！只需对字有效就行，字节的load/store不会错。
    wire AdEL_exc_data;
    wire AdES_exc_data;
    wire exc_badvaddr_new;
    assign AdEL_exc_data = inst_load && ls_word && data_addr[1:0]!=2'b00;
    assign AdES_exc_data = inst_store && ls_word&& data_addr[1:0]!=2'b00;
    assign exc_badvaddr_new=AdEL_exc_inst?exc_badvaddr:data_addr;
    

    wire MEM_valid_load;
    assign MEM_valid_load = MEM_valid && MEM_data_ok;
        
    
    assign MEM_over = inst_load ? MEM_valid_load : MEM_valid;
//-----{MEM执行完成}end

//-----{MEM模块的dest值}begin
   //只有在MEM模块有效时，其写回目的寄存器号才有意义
    assign mem_wait=(mfhi|mflo|mfc0|inst_load);
//-----{MEM模块的dest值}end

//-----{MEM->WB总线}begin
    wire [31:0] mem_result; //MEM传到WB的result为load结果或EXE结果
    assign mem_result = inst_load ? load_result : exe_result;
    
    assign MEM_wdest_wdata = {mem_wait,rf_wdest & {5{MEM_valid}},mem_result};
    
    assign MEM_WB_bus = {
                        AdEL_exc_inst,inst_exc_bd,exc_badvaddr_new,
                         interrupt,reserve_inst,overflow_exc,
                         AdEL_exc_data,AdES_exc_data,
                         rf_wen,rf_wdest,                   // WB需要使用的信号
                         mem_result,                        // 最终要写回寄存器的数据
                         lo_result,                         // 乘法低32位结果，新增
                         hi_write,lo_write,                 // HI/LO写使能，新增
                         mfhi,mflo,                         // WB需要使用的信号,新增
                         mtc0,mfc0,cp0r_addr,syscall,eret,break,  // WB需要使用的信号,新增
                         pc};                               // PC值
//-----{MEM->WB总线}begin

//-----{展示MEM模块的PC值}begin
    assign MEM_pc = pc;
//-----{展示MEM模块的PC值}end
endmodule

