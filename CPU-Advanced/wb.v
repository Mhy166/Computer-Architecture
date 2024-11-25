`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: wb.v
//   > 描述  :五级流水CPU的写回模块
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
`define EXC_ENTER_ADDR 32'd0     // Excption入口地址，
                                 // 此处实现的Exception只有SYSCALL
module wb(                       // 写回级
    input          WB_valid,     // 写回级有效
    input  [157:0] MEM_WB_bus_r, // MEM->WB总线
    output         rf_wen,       // 寄存器写使能
    output [  4:0] rf_wdest,     // 寄存器写地址
    output [ 31:0] rf_wdata,     // 寄存器写数据
    output         WB_over,      // WB模块执行完成

     //5级流水新增接口
     input             clk,       // 时钟
     input             resetn,    // 复位信号，低电平有效
     output [ 32:0] exc_bus,      // Exception pc总线
     output [  37:0] WB_wdest_wdata,     // WB级要写回寄存器堆的目标地址号
     output         cancel,       // syscall和eret到达写回级时会发出cancel信号，
                                  // 取消已经取出的正在其他流水级执行的指令
 
     //展示PC和HI/LO值
     output [ 31:0] WB_pc,
     output [ 31:0] HI_data,
     output [ 31:0] LO_data,
     output [63:0] cp0r_bus
);
//-----{MEM->WB总线}begin    
    wire AdEL_exc_inst;
    wire inst_exc_bd;
    wire [31:0] exc_badvaddr;
    wire interrupt;
    wire reserve_inst;
    wire overflow_exc;
    wire AdEL_exc_data;
    wire AdES_exc_data;
    
    //MEM传来的result
    wire [31:0] mem_result;
    //HI/LO数据
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    
    //寄存器堆写使能和写地址
    wire wen;
    wire [4:0] wdest;
    
    //写回需要用到的信息
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall和eret在写回级有特殊的操作 
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
//-----{MEM->WB总线}end

//-----{HI/LO寄存器}begin
    //HI用于存放乘法结果的高32位
    //LO用于存放乘法结果的低32位
    reg [31:0] hi;
    reg [31:0] lo;
    
    //要写入HI的数据存放在mem_result里
    always @(posedge clk)
    begin
        if (hi_write)
        begin
            hi <= mem_result;
        end
    end
    //要写入LO的数据存放在lo_result里
    always @(posedge clk)
    begin
        if (lo_write)
        begin
            lo <= lo_result;
        end
    end
//-----{HI/LO寄存器}end

//------------------------------------------------------------{cp0协处理器}begin
// cp0寄存器即是协处理器0寄存器
// 每个CP0寄存器都是使用5位的cp0号,目前只实现6个寄存器

//9：Count
//31-0是count内部计数器
wire [31:0] cp0r_count;

//11：Compare
//与count比较，相等时触发计时器中断
wire [31:0] cp0r_compare;

//12：Status:
//31-23     22        21-16     15-8        7-2       1          0
//只读0   Bev恒为1   只读0  IM中断屏蔽位   只读0  EXL例外级 全局中断en位
//软件除了Bev均可读写，基本不需要硬件做
wire [31:0] cp0r_status;

//13：cause:
//31            30       29-16    15-10              9-8        7       6-2          1-0
//BD延迟槽  TI计时器    只读0   IP硬件中断6根线  软件中断2个  只读0   ExcCode编码   只读0
//只有软件中断2根线软件可写！
//Exccode：
//0：Int中断
//4：AdeL地址错例外-读数据
//5：AdeS地址错例外-写数据
//8：Sys系统调用
//9：Bp断点
//a：RI保留指令
//c：算数溢出
wire [31:0] cp0r_cause;

//14：epc触发例外的PC，当其位于分支延迟槽，那么记录前一条的
//软件可读写
wire [31:0] cp0r_epc;

//8：BadVAddr：
//出错的虚地址（地址错例外的虚地址）软件只读
wire [31:0] cp0r_badvaddr;
   
//编码赋值，优先级！
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
   
   //写使能
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
   
//cp0寄存器读
   wire [31:0] cp0r_rdata;
   assign cp0r_rdata =  (cp0r_addr=={5'd8,3'd0}) ? cp0r_badvaddr: 
                        (cp0r_addr=={5'd9,3'd0}) ? cp0r_count:
                        (cp0r_addr=={5'd11,3'd0}) ? cp0r_compare:
                        (cp0r_addr=={5'd12,3'd0}) ? cp0r_status :
                       (cp0r_addr=={5'd13,3'd0}) ? cp0r_cause  :
                       (cp0r_addr=={5'd14,3'd0}) ? cp0r_epc : 32'd0;
   
//STATUS寄存器   
   reg status_exl_r;
   reg status_ie_r;
   reg[7:0] status_im_r;

   assign cp0r_status = {9'b0,1'b1,6'b0,status_im_r,6'b0,status_exl_r,status_ie_r};
   //status寄存器的硬件操作。
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
   
//CAUSE寄存器
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
   
   reg[7:0] cause_r_ip;//1-0位是软件中断,我们目前认为硬件采样都是0
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
//EPC寄存器begin
   //存放产生例外的地址
   //EPC整个域为软件可读写的，故需要epc_wen
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
//EPC寄存器end

//BadVaddr寄存器begin
    reg[31:0] badvaddr_r;
    assign cp0r_badvaddr = badvaddr_r;
    always @(posedge clk)
    begin
        if(exc && (exc_excode==5'h4||exc_excode==5'h5))
        begin
            badvaddr_r <= exc_badvaddr;
        end
    end
//BadVaddr寄存器end
   
//Count寄存器
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
   
//Compare寄存器begin
    reg[31:0] compare_r;
    assign cp0r_compare = compare_r;
    always @(posedge clk)
    begin
        if(compare_wen)
        begin
            compare_r <= mem_result;
        end
    end
//Compare寄存器end
   
   
//------------------------------------------------------------{cp0协处理器}end

   //eret和例外发出的cancel信号
   assign cancel = (eret||exc)&& WB_over;
//-----{WB执行完成}begin
    //WB模块所有操作都可在一拍内完成
    //故WB_valid即是WB_over信号
    assign WB_over = WB_valid;
//-----{WB执行完成}end

//-----{WB->regfile信号}begin
    assign rf_wen   = wen & WB_over;
    assign rf_wdest = wdest;
    assign rf_wdata = mfhi ? hi :
                      mflo ? lo :
                      mfc0 ? cp0r_rdata : mem_result;
//-----{WB->regfile信号}end

//-----{Exception pc信号}begin
    wire        exc_valid;
    wire [31:0] exc_pc;
    assign exc_valid = (eret||exc)&& WB_valid;
    //eret返回地址为EPC寄存器的值
    //SYSCALL的excPC应该为{EBASE[31:10],10'h180},
    //但作为实验，先设置EXC_ENTER_ADDR为0，方便测试程序的编写
    assign exc_pc = eret ? cp0r_epc:`EXC_ENTER_ADDR;
    assign cp0r_bus={cp0r_status,cp0r_cause};
    assign exc_bus = {exc_valid,exc_pc};
//-----{Exception pc信号}end

//-----{WB模块的dest值}begin
   //只有在WB模块有效时，其写回目的寄存器号才有意义
    assign WB_wdest_wdata = {1'b0,rf_wdest & {5{WB_valid}},rf_wdata};
//-----{WB模块的dest值}end

//-----{展示WB模块的PC值和HI/LO寄存器的值}begin
    assign WB_pc = pc;
    assign HI_data = hi;
    assign LO_data = lo;
//-----{展示WB模块的PC值和HI/LO寄存器的值}end
endmodule

