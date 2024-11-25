`timescale 1ns / 1ps

module machine(
    input clk,   
    input resetn );
    //实例化cpu
    //CPU的各个信号
    
    //cpu inst ram
    wire        inst_req;
    wire        inst_wr;
    wire [1 :0] inst_size;
    wire [3 :0] inst_wstrb;
    wire [31:0] inst_addr;
    wire [31:0] inst_wdata;
    wire        inst_addr_ok;
    wire        inst_data_ok;
    wire [31:0] inst_rdata;
    //cpu data sram
    wire        data_req;
    wire        data_wr;
    wire [1 :0] data_size;
    wire [3 :0] data_wstrb;
    wire [31:0] data_addr;
    wire [31:0] data_wdata;
    wire        data_addr_ok;
    wire        data_data_ok;
    wire [31:0] data_rdata;
    
   
    wire [31:0] IF_pc;
    wire [31:0] IF_inst;
    wire [31:0] ID_pc;
    wire [31:0] EXE_pc;
    wire [31:0] MEM_pc;
    wire [31:0] WB_pc;
    wire [31:0] cpu_5_valid;
    wire [31:0] HI_data;
    wire [31:0] LO_data;
    
    pipeline_cpu uut (
        .clk(clk), 
        .resetn(resetn), 
       
        .inst_req    (inst_req    ),
        .inst_wr     (inst_wr     ),
        .inst_size   (inst_size   ),
        .inst_wstrb  (inst_wstrb  ),
        .inst_addr   (inst_addr   ),
        .inst_addr_ok(inst_addr_ok),
        .inst_wdata  (inst_wdata  ),
        .inst_rdata  (inst_rdata  ),
        .inst_data_ok(inst_data_ok),
        
        .data_req    (data_req    ),
        .data_wr     (data_wr     ),
        .data_size   (data_size   ),
        .data_wstrb  (data_wstrb  ),
        .data_addr   (data_addr   ),
        .data_addr_ok(data_addr_ok),
        .data_wdata  (data_wdata  ),
        .data_rdata  (data_rdata  ),
        .data_data_ok(data_data_ok),
       
        .IF_pc(IF_pc), 
        .IF_inst(IF_inst), 
        .ID_pc(ID_pc), 
        .EXE_pc(EXE_pc), 
        .MEM_pc(MEM_pc), 
        .WB_pc(WB_pc), 
        .cpu_5_valid(cpu_5_valid),
        .HI_data(HI_data),
        .LO_data(LO_data)
    );
    inst_ram_wrap inst_wrap(   
        .clk(clk), 
        .resetn(resetn), 
        
        .req    (inst_req    ),
        .wr     (inst_wr     ),
        .size   (inst_size   ),
        .wstrb  (inst_wstrb  ),
        .addr   (inst_addr   ),
        .addr_ok(inst_addr_ok),
        .wdata  (inst_wdata  ),
        .rdata  (inst_rdata  ),
        .data_ok(inst_data_ok) 
    );
    data_ram_wrap data_wrap(
        .clk(clk), 
        .resetn(resetn), 
        
        .req    (data_req    ),
        .wr     (data_wr     ),
        .size   (data_size   ),
        .wstrb  (data_wstrb  ),
        .addr   (data_addr   ),
        .addr_ok(data_addr_ok),
        .wdata  (data_wdata  ),
        .rdata  (data_rdata  ),
        .data_ok(data_data_ok)
    );
endmodule
