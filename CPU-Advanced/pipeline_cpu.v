`timescale 1ns / 1ps
`include "CPU.vh"

module pipeline_cpu(  // 多周期cpu
    input clk,           // 时钟
    input resetn,        // 复位信号，低电平有效
    
    output        inst_req,    
    output        inst_wr,    
    output [ 1:0] inst_size,   
    output [ 3:0] inst_wstrb,  
    output [31:0] inst_addr,
    input         inst_addr_ok,
    output [31:0] inst_wdata,
    input  [31:0] inst_rdata,
    input         inst_data_ok,

    output        data_req,    
    output        data_wr,     
    output [ 1:0] data_size,   
    output [ 3:0] data_wstrb, 
    output [31:0] data_addr,
    input         data_addr_ok,
    output [31:0] data_wdata,
    input  [31:0] data_rdata,
    input         data_data_ok,
    //display data
    output [31:0] IF_pc,
    output [31:0] IF_inst,
    output [31:0] ID_pc,
    output [31:0] EXE_pc,
    output [31:0] MEM_pc,
    output [31:0] WB_pc,
    
    //5级流水新增
    output [31:0] cpu_5_valid,
    output [31:0] HI_data,
    output [31:0] LO_data
    );
//------------------------{5级流水控制信号}begin-------------------------//
    reg IF_valid;
    reg ID_valid;
    reg EXE_valid;
    reg MEM_valid;
    reg WB_valid;
    //5模块执行完成信号,等价于xx to xx valid
    wire IF_over;
    wire ID_over;
    wire EXE_over;
    wire MEM_over;
    wire WB_over;

    wire IF_allow_in;
    wire ID_allow_in;
    wire EXE_allow_in;
    wire MEM_allow_in;
    wire WB_allow_in;
    
    // syscall和eret到达写回级时会发出cancel信号，
    wire cancel;    // 取消已经取出的正在其他流水级执行的指令
    
    //各级允许进入信号:本级无效，或本级执行完成且下级允许进入
    assign IF_allow_in  = (IF_over & ID_allow_in) | cancel;
    assign ID_allow_in  = ~ID_valid  | (ID_over  & EXE_allow_in);
    assign EXE_allow_in = ~EXE_valid | (EXE_over & MEM_allow_in);
    assign MEM_allow_in = ~MEM_valid | (MEM_over & WB_allow_in );
    assign WB_allow_in  = ~WB_valid  | WB_over;
   
    //IF_valid，在复位后，一直有效
   always @(posedge clk)
    begin
        if (!resetn)
        begin
            IF_valid <= 1'b0;
        end
        else
        begin
            IF_valid <= 1'b1;
        end
    end
    
    //ID_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            ID_valid <= 1'b0;
        end
        else if (ID_allow_in)
        begin
               ID_valid <=IF_over;
        end
    end
    
    //EXE_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            EXE_valid <= 1'b0;
        end
        else if (EXE_allow_in)
        begin
            EXE_valid <= ID_over;
        end
    end
    
    //MEM_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            MEM_valid <= 1'b0;
        end
        else if (MEM_allow_in)
        begin
            MEM_valid <= EXE_over;
        end
    end
    
    //WB_valid
    always @(posedge clk)
    begin
        if (!resetn || cancel)
        begin
            WB_valid <= 1'b0;
        end
        else if (WB_allow_in)
        begin
            WB_valid <= MEM_over;
        end
    end
    
    //展示5级的valid信号
    assign cpu_5_valid = {12'd0         ,{4{IF_valid }},{4{ID_valid}},
                          {4{EXE_valid}},{4{MEM_valid}},{4{WB_valid}}};
//-------------------------{5级流水控制信号}end--------------------------//

//--------------------------{5级间的总线}begin---------------------------//
    wire [`IF_TO_ID_BUS_WD-1:0] IF_ID_bus;   // IF->ID级总线
    wire [`ID_TO_EXE_BUS_WD-1:0] ID_EXE_bus;  // ID->EXE级总线
    wire [`EXE_TO_MEM_BUS_WD-1:0] EXE_MEM_bus; // EXE->MEM级总线
    wire [`MEM_TO_WB_BUS_WD-1:0] MEM_WB_bus;  // MEM->WB级总线
    
    //锁存以上总线信号
    reg [`IF_TO_ID_BUS_WD-1:0] IF_ID_bus_r;
    reg [`ID_TO_EXE_BUS_WD-1:0] ID_EXE_bus_r;
    reg [`EXE_TO_MEM_BUS_WD-1:0] EXE_MEM_bus_r;
    reg [`MEM_TO_WB_BUS_WD-1:0] MEM_WB_bus_r;
    
    //IF到ID的锁存信号
    always @(posedge clk)
    begin
        if(IF_over && ID_allow_in)
        begin
            IF_ID_bus_r <= IF_ID_bus;
        end
    end
    //ID到EXE的锁存信号
    always @(posedge clk)
    begin
        if(ID_over && EXE_allow_in)
        begin
            ID_EXE_bus_r <= ID_EXE_bus;
        end
    end
    //EXE到MEM的锁存信号
    always @(posedge clk)
    begin
        if(EXE_over && MEM_allow_in)
        begin
            EXE_MEM_bus_r <= EXE_MEM_bus;
        end
    end    
    //MEM到WB的锁存信号
    always @(posedge clk)
    begin
        if(MEM_over && WB_allow_in)
        begin
            MEM_WB_bus_r <= MEM_WB_bus;
        end
    end
//---------------------------{5级间的总线}end----------------------------//

//--------------------------{其他交互信号}begin--------------------------//
    //跳转总线,包含新增的分支延迟槽判断统一指令
    wire [`JBR_BUS_WD-1:0] jbr_bus;    

    //ID与EXE、MEM、WB交互
    wire [ `BYPASS_BUS_WD-1:0] EXE_wdest_wdata;
    wire [ `BYPASS_BUS_WD-1:0]  MEM_wdest_wdata;
    wire [ `BYPASS_BUS_WD-1:0]  WB_wdest_wdata;
    
    //ID与regfile交互
    wire [ 4:0] rs;
    wire [ 4:0] rt;   
    wire [31:0] rs_value;
    wire [31:0] rt_value;
    
    //WB与regfile交互
    wire        rf_wen;
    wire [ 4:0] rf_wdest;
    wire [31:0] rf_wdata;    
    
    //WB与IF间的交互信号
    wire [`EXC_BUS_WD-1:0] exc_bus;
    //WB送往ID的cp0
    wire [63:0] cp0_bus;
    
//---------------------------{其他交互信号}end---------------------------//
//    reg first_fetch;
//-------------------------{各模块实例化}begin---------------------------//
//    always @(posedge clk)
//    begin   
//         first_fetch <= ~resetn;
//    end
    wire next_fetch; //即将运行取指模块，需要先锁存PC值
    //IF允许进入时，即锁存PC值，取下一条指令
    assign next_fetch =IF_allow_in;
    
    //指令inst不写！
    //还剩下req，rdata，addr，data_ok,addr_ok
    assign inst_wr = 1'b0;
    assign inst_size = 2'b10;
    assign inst_wstrb = 4'b0;
    assign inst_wdata = 32'b0;

    fetch IF_module(             // 取指级
        .clk       (clk       ),  // I, 1
        .resetn    (resetn    ),  // I, 1
        .IF_valid  (IF_valid  ),  // I, 1
        .ID_allow_in(ID_allow_in),
        .next_fetch(next_fetch),  // I, 1
        .jbr_bus   (jbr_bus   ),  // I, 33
        .IF_over   (IF_over   ),  // O, 1
        .IF_ID_bus (IF_ID_bus ),  // O, 64
        
        //5级流水新增接口
        .exc_bus   (exc_bus   ),  // I, 32
        
        //展示PC和取出的指令
        .IF_pc     (IF_pc     ),  // O, 32
        .IF_inst   (IF_inst   ),   // O, 32
        
        //IF取指令总线
        .inst_req       (inst_req),
        .inst_addr      (inst_addr      ),
        .inst_addr_ok      (inst_addr_ok),
        .inst_rdata     (inst_rdata     ),
        .inst_data_ok   (inst_data_ok)
    );

    decode ID_module(               // 译码级
        .clk        (clk),
        .cp0r_bus   (cp0_bus),
        .ID_valid   (ID_valid   ),  // I, 1
        .IF_ID_bus_r(IF_ID_bus_r),  // I, 64
        .o_rs_value   (rs_value   ),  // I, 32
        .o_rt_value   (rt_value   ),  // I, 32
        .rs         (rs         ),  // O, 5
        .rt         (rt         ),  // O, 5
        .jbr_bus    (jbr_bus    ),  // O, 33
//        .inst_jbr   (inst_jbr   ),  // O, 1
        .ID_over    (ID_over    ),  // O, 1
        .ID_EXE_bus (ID_EXE_bus ),  // O, 167
        
        //5级流水新增
        .IF_over     (IF_over     ),// I, 1
        .EXE_wdest_wdata   (EXE_wdest_wdata   ),// I, 5
        .MEM_wdest_wdata   (MEM_wdest_wdata   ),// I, 5
        .WB_wdest_wdata    (WB_wdest_wdata    ),// I, 5
        
        //展示PC
        .ID_pc       (ID_pc       ) // O, 32
    ); 

    exe EXE_module(                   // 执行级
        .EXE_valid   (EXE_valid   ),  // I, 1
        .ID_EXE_bus_r(ID_EXE_bus_r),  // I, 167
        .EXE_over    (EXE_over    ),  // O, 1 
        .EXE_MEM_bus (EXE_MEM_bus ),  // O, 154
        
        //5级流水新增
        .clk         (clk         ),  // I, 1
        .EXE_wdest_wdata   (EXE_wdest_wdata   ),  // O, 5
        
        //展示PC
        .EXE_pc      (EXE_pc      )   // O, 32
    );

    mem MEM_module(                     // 访存级
        .clk          (clk          ),  // I, 1 
        .resetn       (resetn       ),
        .WB_allow_in  (WB_allow_in  ), 
        .MEM_valid    (MEM_valid    ),  // I, 1
        .EXE_MEM_bus_r(EXE_MEM_bus_r),  // I, 154
        .MEM_over     (MEM_over     ),  // O, 1
        .MEM_WB_bus   (MEM_WB_bus   ),  // O, 118
        //5级流水新增接口
        .MEM_allow_in (MEM_allow_in ),  // I, 1
        .MEM_wdest_wdata    (MEM_wdest_wdata    ),  // O, 5
        .data_req (data_req),    
        .data_wr(data_wr),     
        .data_size(data_size),   
        .data_wstrb(data_wstrb), 
        .data_addr(data_addr),
        .data_addr_ok(data_addr_ok),
        .data_wdata(data_wdata),
        .data_rdata(data_rdata),
        .data_data_ok(data_data_ok),
        //展示PC
        .MEM_pc       (MEM_pc       )   // O, 32
    );          
 
    wb WB_module(                     // 写回级
        .WB_valid    (WB_valid    ),  // I, 1
        .MEM_WB_bus_r(MEM_WB_bus_r),  // I, 118
        .rf_wen      (rf_wen      ),  // O, 1
        .rf_wdest    (rf_wdest    ),  // O, 5
        .rf_wdata    (rf_wdata    ),  // O, 32
          .WB_over     (WB_over     ),  // O, 1
        
        //5级流水新增接口
        .clk         (clk         ),  // I, 1
        .resetn      (resetn      ),  // I, 1
        .exc_bus     (exc_bus     ),  // O, 32
        .WB_wdest_wdata    (WB_wdest_wdata    ),  // O, 5
        .cancel      (cancel      ),  // O, 1
        
        //展示PC和HI/LO值
        .WB_pc       (WB_pc       ),  // O, 32
        .HI_data     (HI_data     ),  // O, 32
        .LO_data     (LO_data     ),   // O, 32
        .cp0r_bus    (cp0_bus)
    );

    regfile rf_module(        // 寄存器堆模块
        .clk    (clk      ),  // I, 1
        .wen    (rf_wen   ),  // I, 1
        .raddr1 (rs       ),  // I, 5
        .raddr2 (rt       ),  // I, 5
        .waddr  (rf_wdest ),  // I, 5
        .wdata  (rf_wdata ),  // I, 32
        .rdata1 (rs_value ),  // O, 32
        .rdata2 (rt_value )   // O, 32
    );
    
//--------------------------{各模块实例化}end----------------------------//
endmodule
