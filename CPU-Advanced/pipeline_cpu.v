`timescale 1ns / 1ps
`include "CPU.vh"

module pipeline_cpu(  // ������cpu
    input clk,           // ʱ��
    input resetn,        // ��λ�źţ��͵�ƽ��Ч
    
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
    
    //5����ˮ����
    output [31:0] cpu_5_valid,
    output [31:0] HI_data,
    output [31:0] LO_data
    );
//------------------------{5����ˮ�����ź�}begin-------------------------//
    reg IF_valid;
    reg ID_valid;
    reg EXE_valid;
    reg MEM_valid;
    reg WB_valid;
    //5ģ��ִ������ź�,�ȼ���xx to xx valid
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
    
    // syscall��eret����д�ؼ�ʱ�ᷢ��cancel�źţ�
    wire cancel;    // ȡ���Ѿ�ȡ��������������ˮ��ִ�е�ָ��
    
    //������������ź�:������Ч���򱾼�ִ��������¼��������
    assign IF_allow_in  = (IF_over & ID_allow_in) | cancel;
    assign ID_allow_in  = ~ID_valid  | (ID_over  & EXE_allow_in);
    assign EXE_allow_in = ~EXE_valid | (EXE_over & MEM_allow_in);
    assign MEM_allow_in = ~MEM_valid | (MEM_over & WB_allow_in );
    assign WB_allow_in  = ~WB_valid  | WB_over;
   
    //IF_valid���ڸ�λ��һֱ��Ч
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
    
    //չʾ5����valid�ź�
    assign cpu_5_valid = {12'd0         ,{4{IF_valid }},{4{ID_valid}},
                          {4{EXE_valid}},{4{MEM_valid}},{4{WB_valid}}};
//-------------------------{5����ˮ�����ź�}end--------------------------//

//--------------------------{5���������}begin---------------------------//
    wire [`IF_TO_ID_BUS_WD-1:0] IF_ID_bus;   // IF->ID������
    wire [`ID_TO_EXE_BUS_WD-1:0] ID_EXE_bus;  // ID->EXE������
    wire [`EXE_TO_MEM_BUS_WD-1:0] EXE_MEM_bus; // EXE->MEM������
    wire [`MEM_TO_WB_BUS_WD-1:0] MEM_WB_bus;  // MEM->WB������
    
    //�������������ź�
    reg [`IF_TO_ID_BUS_WD-1:0] IF_ID_bus_r;
    reg [`ID_TO_EXE_BUS_WD-1:0] ID_EXE_bus_r;
    reg [`EXE_TO_MEM_BUS_WD-1:0] EXE_MEM_bus_r;
    reg [`MEM_TO_WB_BUS_WD-1:0] MEM_WB_bus_r;
    
    //IF��ID�������ź�
    always @(posedge clk)
    begin
        if(IF_over && ID_allow_in)
        begin
            IF_ID_bus_r <= IF_ID_bus;
        end
    end
    //ID��EXE�������ź�
    always @(posedge clk)
    begin
        if(ID_over && EXE_allow_in)
        begin
            ID_EXE_bus_r <= ID_EXE_bus;
        end
    end
    //EXE��MEM�������ź�
    always @(posedge clk)
    begin
        if(EXE_over && MEM_allow_in)
        begin
            EXE_MEM_bus_r <= EXE_MEM_bus;
        end
    end    
    //MEM��WB�������ź�
    always @(posedge clk)
    begin
        if(MEM_over && WB_allow_in)
        begin
            MEM_WB_bus_r <= MEM_WB_bus;
        end
    end
//---------------------------{5���������}end----------------------------//

//--------------------------{���������ź�}begin--------------------------//
    //��ת����,���������ķ�֧�ӳٲ��ж�ͳһָ��
    wire [`JBR_BUS_WD-1:0] jbr_bus;    

    //ID��EXE��MEM��WB����
    wire [ `BYPASS_BUS_WD-1:0] EXE_wdest_wdata;
    wire [ `BYPASS_BUS_WD-1:0]  MEM_wdest_wdata;
    wire [ `BYPASS_BUS_WD-1:0]  WB_wdest_wdata;
    
    //ID��regfile����
    wire [ 4:0] rs;
    wire [ 4:0] rt;   
    wire [31:0] rs_value;
    wire [31:0] rt_value;
    
    //WB��regfile����
    wire        rf_wen;
    wire [ 4:0] rf_wdest;
    wire [31:0] rf_wdata;    
    
    //WB��IF��Ľ����ź�
    wire [`EXC_BUS_WD-1:0] exc_bus;
    //WB����ID��cp0
    wire [63:0] cp0_bus;
    
//---------------------------{���������ź�}end---------------------------//
//    reg first_fetch;
//-------------------------{��ģ��ʵ����}begin---------------------------//
//    always @(posedge clk)
//    begin   
//         first_fetch <= ~resetn;
//    end
    wire next_fetch; //��������ȡָģ�飬��Ҫ������PCֵ
    //IF�������ʱ��������PCֵ��ȡ��һ��ָ��
    assign next_fetch =IF_allow_in;
    
    //ָ��inst��д��
    //��ʣ��req��rdata��addr��data_ok,addr_ok
    assign inst_wr = 1'b0;
    assign inst_size = 2'b10;
    assign inst_wstrb = 4'b0;
    assign inst_wdata = 32'b0;

    fetch IF_module(             // ȡָ��
        .clk       (clk       ),  // I, 1
        .resetn    (resetn    ),  // I, 1
        .IF_valid  (IF_valid  ),  // I, 1
        .ID_allow_in(ID_allow_in),
        .next_fetch(next_fetch),  // I, 1
        .jbr_bus   (jbr_bus   ),  // I, 33
        .IF_over   (IF_over   ),  // O, 1
        .IF_ID_bus (IF_ID_bus ),  // O, 64
        
        //5����ˮ�����ӿ�
        .exc_bus   (exc_bus   ),  // I, 32
        
        //չʾPC��ȡ����ָ��
        .IF_pc     (IF_pc     ),  // O, 32
        .IF_inst   (IF_inst   ),   // O, 32
        
        //IFȡָ������
        .inst_req       (inst_req),
        .inst_addr      (inst_addr      ),
        .inst_addr_ok      (inst_addr_ok),
        .inst_rdata     (inst_rdata     ),
        .inst_data_ok   (inst_data_ok)
    );

    decode ID_module(               // ���뼶
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
        
        //5����ˮ����
        .IF_over     (IF_over     ),// I, 1
        .EXE_wdest_wdata   (EXE_wdest_wdata   ),// I, 5
        .MEM_wdest_wdata   (MEM_wdest_wdata   ),// I, 5
        .WB_wdest_wdata    (WB_wdest_wdata    ),// I, 5
        
        //չʾPC
        .ID_pc       (ID_pc       ) // O, 32
    ); 

    exe EXE_module(                   // ִ�м�
        .EXE_valid   (EXE_valid   ),  // I, 1
        .ID_EXE_bus_r(ID_EXE_bus_r),  // I, 167
        .EXE_over    (EXE_over    ),  // O, 1 
        .EXE_MEM_bus (EXE_MEM_bus ),  // O, 154
        
        //5����ˮ����
        .clk         (clk         ),  // I, 1
        .EXE_wdest_wdata   (EXE_wdest_wdata   ),  // O, 5
        
        //չʾPC
        .EXE_pc      (EXE_pc      )   // O, 32
    );

    mem MEM_module(                     // �ô漶
        .clk          (clk          ),  // I, 1 
        .resetn       (resetn       ),
        .WB_allow_in  (WB_allow_in  ), 
        .MEM_valid    (MEM_valid    ),  // I, 1
        .EXE_MEM_bus_r(EXE_MEM_bus_r),  // I, 154
        .MEM_over     (MEM_over     ),  // O, 1
        .MEM_WB_bus   (MEM_WB_bus   ),  // O, 118
        //5����ˮ�����ӿ�
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
        //չʾPC
        .MEM_pc       (MEM_pc       )   // O, 32
    );          
 
    wb WB_module(                     // д�ؼ�
        .WB_valid    (WB_valid    ),  // I, 1
        .MEM_WB_bus_r(MEM_WB_bus_r),  // I, 118
        .rf_wen      (rf_wen      ),  // O, 1
        .rf_wdest    (rf_wdest    ),  // O, 5
        .rf_wdata    (rf_wdata    ),  // O, 32
          .WB_over     (WB_over     ),  // O, 1
        
        //5����ˮ�����ӿ�
        .clk         (clk         ),  // I, 1
        .resetn      (resetn      ),  // I, 1
        .exc_bus     (exc_bus     ),  // O, 32
        .WB_wdest_wdata    (WB_wdest_wdata    ),  // O, 5
        .cancel      (cancel      ),  // O, 1
        
        //չʾPC��HI/LOֵ
        .WB_pc       (WB_pc       ),  // O, 32
        .HI_data     (HI_data     ),  // O, 32
        .LO_data     (LO_data     ),   // O, 32
        .cp0r_bus    (cp0_bus)
    );

    regfile rf_module(        // �Ĵ�����ģ��
        .clk    (clk      ),  // I, 1
        .wen    (rf_wen   ),  // I, 1
        .raddr1 (rs       ),  // I, 5
        .raddr2 (rt       ),  // I, 5
        .waddr  (rf_wdest ),  // I, 5
        .wdata  (rf_wdata ),  // I, 32
        .rdata1 (rs_value ),  // O, 32
        .rdata2 (rt_value )   // O, 32
    );
    
//--------------------------{��ģ��ʵ����}end----------------------------//
endmodule
