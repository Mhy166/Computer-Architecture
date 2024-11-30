`timescale 1ns / 1ps
`include "CPU.vh"
module cp0(
    input           clk,
    input           resetn,
    input [31:0]    mem_result,
    input [4:0]     exc_excode,//例外编码
    input           exc,
    input           eret,
    input           syscall,
    input           wen,
    input [7:0]    cp0r_addr,
    input           WB_valid,
    output [31:0]   cp0r_rdata,
    
    input           inst_exc_bd,
    input    [31:0] exc_badvaddr,
    input    [31:0]       pc,
    output   [`EXC_BUS_WD-1:0]       exc_bus,
    output   [95:0] cp0r_bus,
    input          tlbr,
    input          tlbwi,
    input          tlbp,
    input          tlb_refill_exc,
     //search-tlbp
    input          tlb_cancel_o,
     
    input         s1_found,
    input [ 3:0]  s1_index,
    //read port
    output [ 3:0]              r_index,
    input [              18:0] r_vpn2,     
    input [               7:0] r_asid,     
    input                      r_g,     
    input [              19:0] r_pfn0,     
    input [               2:0] r_c0,     
    input                      r_d0,     
    input                      r_v0,     
    input [              19:0] r_pfn1,     
    input [               2:0] r_c1,     
    input                      r_d1,     
    input                      r_v1, 
    
        output  [               3:0] w_index,     
        output  [              18:0] w_vpn2,     
        output  [               7:0] w_asid,     
        output                       w_g,     
        output  [              19:0] w_pfn0,     
        output  [               2:0] w_c0,     
        output                       w_d0,
        output                       w_v0,     
        output  [              19:0] w_pfn1,     
        output  [               2:0] w_c1,     
        output                       w_d1,     
        output                       w_v1
    
    );
// cp0寄存器即是协处理器0寄存器
// 每个CP0寄存器都是使用5位的cp0号,目前只实现6个寄存器
wire tlb_cancel;
assign tlb_cancel = !WB_valid ||tlb_cancel_o;//只要WB不valid，或者tlb标记有，就不要更新co0！
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
    
//TLB——————————————————————
//0：Index
//默认16个页表项，4位index
wire [31:0] cp0r_index;
//2: EntryLo0
wire [31:0] cp0r_entrylo0;
//3: EntryLo1
wire [31:0] cp0r_entrylo1;
//10: EntryHi
wire [31:0] cp0r_entryhi;

    assign r_index = cp0r_index[3:0];

    // ENTRYHI
    assign w_index      = cp0r_index[3:0];
    assign w_vpn2       = cp0r_entryhi[31:13];
    assign w_asid       = cp0r_entryhi[7:0];
    assign w_g          = cp0r_entrylo0[0] & cp0r_entrylo1[0];
    // ENTRYLO0
    assign w_pfn0       = cp0r_entrylo0[25:6];
    assign w_c0         = cp0r_entrylo0[5:3];
    assign w_d0         = cp0r_entrylo0[2];
    assign w_v0         = cp0r_entrylo0[1];
    // ENTRYLO1
    assign w_pfn1       = cp0r_entrylo1[25:6];
    assign w_c1         = cp0r_entrylo1[5:3];
    assign w_d1         = cp0r_entrylo1[2];
    assign w_v1         = cp0r_entrylo1[1];  


   assign cp0r_rdata =  (cp0r_addr=={5'd0,3'd0}) ? cp0r_index:
                        (cp0r_addr=={5'd2,3'd0}) ? cp0r_entrylo0:
                        (cp0r_addr=={5'd3,3'd0}) ? cp0r_entrylo1:
                        (cp0r_addr=={5'd8,3'd0}) ? cp0r_badvaddr: 
                        (cp0r_addr=={5'd9,3'd0}) ? cp0r_count:
                        (cp0r_addr=={5'd10,3'd0}) ? cp0r_entryhi:
                        (cp0r_addr=={5'd11,3'd0}) ? cp0r_compare:
                        (cp0r_addr=={5'd12,3'd0}) ? cp0r_status :
                       (cp0r_addr=={5'd13,3'd0}) ? cp0r_cause  :
                       (cp0r_addr=={5'd14,3'd0}) ? cp0r_epc : 32'd0;
   wire status_wen;
   wire compare_wen;
   wire cause_wen;
   wire epc_wen;
   wire count_wen;
   wire badvaddr_wen;
   wire index_wen;
   wire lo0_wen;
   wire lo1_wen;
   wire hi_wen;
   
   assign index_wen     = wen & (cp0r_addr=={5'd0,3'd0});
   assign lo0_wen       = wen & (cp0r_addr=={5'd2,3'd0}); 
   assign lo1_wen       = wen & (cp0r_addr=={5'd3,3'd0});
   assign badvaddr_wen  = wen & (cp0r_addr=={5'd8,3'd0});
   assign count_wen     = wen & (cp0r_addr=={5'd9,3'd0});
   assign hi_wen        = wen & (cp0r_addr=={5'd10,3'd0});
   assign compare_wen   = wen & (cp0r_addr=={5'd11,3'd0});
   assign status_wen    = wen & (cp0r_addr=={5'd12,3'd0});
   assign cause_wen     = wen & (cp0r_addr=={5'd13,3'd0});
   assign epc_wen       = wen & (cp0r_addr=={5'd14,3'd0});
   
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
       if(!resetn||(!tlb_cancel&&eret))
            status_exl_r<=1'b0;
       else if(!tlb_cancel&&exc)
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
       else if (!tlb_cancel&&exc && !cp0r_status[1])
           cause_r_bd <= inst_exc_bd;
   end
   
   reg[4:0] cause_r_code;
   always @(posedge clk)
   begin
       if (!resetn)
           cause_r_code <= 5'b11111;
       else if(!tlb_cancel&&exc)
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
       if (!tlb_cancel&&exc && !cp0r_status[1])
       begin
           epc_r <= inst_exc_bd ? (pc-3'd4):pc;
       end
       else if (epc_wen)
       begin
           epc_r <= mem_result;
       end
   end
//EPC寄存器end
    wire tlb_exc;
    assign tlb_exc = (exc_excode == 5'h01) || (exc_excode == 5'h02) || (exc_excode == 5'h03);
//BadVaddr寄存器begin
    reg[31:0] badvaddr_r;
    assign cp0r_badvaddr = badvaddr_r;
    always @(posedge clk)
    begin
        if(!tlb_cancel&&exc && (exc_excode==5'h4||exc_excode==5'h5||tlb_exc))
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

//Hi寄存器begin
    reg[18:0] hi_r_vpn2;
    reg[7:0]  hi_r_asid;
    assign cp0r_entryhi = {hi_r_vpn2,5'b0,hi_r_asid};
    
    
    
    always @(posedge clk)
    begin
           if (!resetn)
               hi_r_vpn2 <= 19'b0;
           else if(hi_wen)
               hi_r_vpn2 <= mem_result[31:13];
           else if(!tlb_cancel&&tlbr)
               hi_r_vpn2 <= r_vpn2;
           else if(!tlb_cancel&&tlb_exc)
               hi_r_vpn2 <= exc_badvaddr[31:13];
    end
    always @(posedge clk)
    begin
           if (!resetn)
               hi_r_asid <= 8'b0;
           else if(hi_wen)
               hi_r_asid <= mem_result[7:0];
           else if(!tlb_cancel&&tlbr)
               hi_r_asid <= r_asid;
    end
       
//Hi寄存器end
//Index begin
    reg index_r_p;
    reg [3:0]index_r_index;
    assign cp0r_index = {index_r_p,27'b0,index_r_index};
    //index位
    always @(posedge clk)
    begin
        if (!resetn)
               index_r_index <= 4'b0;
        else if(index_wen)
               index_r_index <= mem_result[3:0]; 
        else if(!tlb_cancel&&tlbp)
               index_r_index <= s1_index;
    end
    always @(posedge clk)
    begin
        if (!resetn)
               index_r_p <= 1'b0;
        else if(!tlb_cancel&&tlbp)
               index_r_p <= !s1_found;
    end
//Index end

//Lo0 begin
    reg [19:0] lo0_r_pfn0;
    reg [2:0]  lo0_r_c0;
    reg        lo0_r_d0;
    reg        lo0_r_v0;
    reg        lo0_r_g0;
    assign cp0r_entrylo0 = {6'b0,lo0_r_pfn0,lo0_r_c0,lo0_r_d0,lo0_r_v0,lo0_r_g0};
    
    always @(posedge clk)
    begin
        if(!resetn)
        begin
            lo0_r_pfn0 <= 20'b0;
            lo0_r_c0   <= 3'b0;
            lo0_r_d0   <= 1'b0;
            lo0_r_v0   <= 1'b0;
            lo0_r_g0   <= 1'b0;
        end
        else if(lo0_wen)
        begin
            lo0_r_pfn0 <= mem_result[25:6];
            lo0_r_c0   <= mem_result[5:3];
            lo0_r_d0   <= mem_result[2];
            lo0_r_v0   <= mem_result[1];
            lo0_r_g0   <= mem_result[0];
        end
        else if(!tlb_cancel&&tlbr)
        begin
            lo0_r_pfn0 <= r_pfn0;
            lo0_r_c0   <= r_c0;
            lo0_r_d0   <= r_d0;
            lo0_r_v0   <= r_v0;
            lo0_r_g0   <= r_g;
        end
    end
//Lo0 end
//Lo1 begin
    reg [19:0] lo1_r_pfn1;
    reg [2:0]  lo1_r_c1;
    reg        lo1_r_d1;
    reg        lo1_r_v1;
    reg        lo1_r_g1;
    assign cp0r_entrylo1 = {6'b0,lo1_r_pfn1,lo1_r_c1,lo1_r_d1,lo1_r_v1,lo1_r_g1};
    
    always @(posedge clk)
    begin
        if(!resetn)
        begin
            lo1_r_pfn1 <= 20'b0;
            lo1_r_c1   <= 3'b0;
            lo1_r_d1   <= 1'b0;
            lo1_r_v1   <= 1'b0;
            lo1_r_g1   <= 1'b0;
        end
        else if(lo1_wen)
        begin
            lo1_r_pfn1 <= mem_result[25:6];
            lo1_r_c1   <= mem_result[5:3];
            lo1_r_d1   <= mem_result[2];
            lo1_r_v1   <= mem_result[1];
            lo1_r_g1   <= mem_result[0];
        end
        else if(!tlb_cancel&&tlbr)
        begin
            lo1_r_pfn1 <= r_pfn1;
            lo1_r_c1   <= r_c1;
            lo1_r_d1   <= r_d1;
            lo1_r_v1   <= r_v1;
            lo1_r_g1   <= r_g;
        end
    end
    
//Lo1 end




    wire        exc_valid;
    wire[31:0]  exc_pc;
    assign exc_valid = (eret||exc)&& WB_valid;
    assign exc_bus = {exc_valid,exc_pc};
    assign exc_pc = eret ? cp0r_epc:
                    syscall? `EXC_ENTER_ADDR:
                    (tlb_exc&&tlb_refill_exc)?  `EXC_TLB_RF_ADDR:
                    (tlb_exc&&!tlb_refill_exc)? `EXC_TLB_NRF_ADDR :`EXC_CHECK_ADDR;//这里默认另外两个例外也进入那个地址！但是我们只设计充填的！
    assign cp0r_bus={cp0r_entryhi,cp0r_status,cp0r_cause};
endmodule
