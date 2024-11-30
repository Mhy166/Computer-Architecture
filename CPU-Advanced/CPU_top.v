`timescale 1ns / 1ps
//对外只有一个AXI接口
module CPU_top(
    input               aclk,
    input               aresetn,
    //read request
    output  [ 3:0]      arid,
    output  [31:0]      araddr,
    output  [ 7:0]      arlen,
    output  [ 2:0]      arsize,
    output  [ 1:0]      arburst,
    output  [ 1:0]      arlock,
    output  [ 3:0]      arcache,
    output  [ 2:0]      arprot,
    output              arvalid,
    input               arready,

    //read response
    input   [ 3:0]      rid,
    input   [31:0]      rdata,
    input   [ 1:0]      rresp,
    input               rlast,
    input               rvalid,
    output              rready,

    //write request
    output  [ 3:0]      awid,
    output  [31:0]      awaddr,
    output  [ 7:0]      awlen,
    output  [ 2:0]      awsize,
    output  [ 1:0]      awburst,
    output  [ 1:0]      awlock,
    output  [ 3:0]      awcache,
    output  [ 2:0]      awprot,
    output              awvalid,
    input               awready,

    //write data
    output  [ 3:0]      wid,
    output  [31:0]      wdata,
    output  [ 3:0]      wstrb,
    output              wlast,
    output              wvalid,
    input               wready,

    //write response
    input   [ 3:0]      bid,
    input   [ 1:0]      bresp,
    input               bvalid,
    output              bready
    );
    
    wire        inst_req;
    wire        inst_wr;
    wire [ 1:0] inst_size;
    wire [31:0] inst_addr;
    wire [ 3:0] inst_wstrb;
    wire [31:0] inst_wdata;
    wire        inst_addr_ok;
    wire        inst_data_ok;
    wire [31:0] inst_rdata;
 
    wire        data_req;
    wire        data_wr;
    wire [ 1:0] data_size;
    wire [31:0] data_addr;
    wire [ 3:0] data_wstrb;
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
    
    pipeline_cpu uut(
        .clk(aclk), 
        .resetn(aresetn), 
       
        .inst_req    (inst_req    ),
        .inst_wr     (inst_wr     ),
        .inst_size   (inst_size   ),
        .inst_wstrb  (inst_wstrb  ),
        .inst_addr   (inst_addr   ),
        .inst_wdata  (inst_wdata  ),
        .inst_addr_ok(inst_addr_ok),
        .inst_rdata  (inst_rdata  ),
        .inst_data_ok(inst_data_ok),
        
        .data_req    (data_req    ),
        .data_wr     (data_wr     ),
        .data_size   (data_size   ),
        .data_wstrb  (data_wstrb  ),
        .data_addr   (data_addr   ),
        .data_wdata  (data_wdata  ),
        .data_addr_ok(data_addr_ok),
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
    Transfer_bridge uut_Transfer_bridge(
        .aclk               (aclk               ),
        .aresetn            (aresetn            ),
        
        .inst_req      (inst_req      ),
        .inst_wr       (inst_wr       ),
        .inst_size     (inst_size     ),
        .inst_addr     (inst_addr     ),
        .inst_wstrb    (inst_wstrb    ),
        .inst_wdata    (inst_wdata    ),
        .inst_addr_ok  (inst_addr_ok  ),
        .inst_data_ok  (inst_data_ok  ),
        .inst_rdata    (inst_rdata    ),
    
        .data_req      (data_req      ),
        .data_wr       (data_wr       ),
        .data_size     (data_size     ),
        .data_addr     (data_addr     ),
        .data_wstrb    (data_wstrb    ),
        .data_wdata    (data_wdata    ),
        .data_addr_ok  (data_addr_ok  ),
        .data_data_ok  (data_data_ok  ),
        .data_rdata    (data_rdata    ),
        
        .arid               (arid               ),
        .araddr             (araddr             ),
        .arlen              (arlen              ),
        .arsize             (arsize             ),
        .arburst            (arburst            ),
        .arlock             (arlock             ),
        .arcache            (arcache            ),
        .arprot             (arprot             ),
        .arvalid            (arvalid            ),
        .arready            (arready            ),
    
        .rid                (rid                ),
        .rdata              (rdata              ),
        .rresp              (rresp              ),
        .rlast              (rlast              ),
        .rvalid             (rvalid             ),
        .rready             (rready             ),
       
    
        .awid               (awid               ),
        .awaddr             (awaddr             ),
        .awlen              (awlen              ),
        .awsize             (awsize             ),
        .awburst            (awburst            ),
        .awlock             (awlock             ),
        .awcache            (awcache            ),
        .awprot             (awprot             ),
        .awvalid            (awvalid            ),
        .awready            (awready            ),
    
        .wid                (wid                ),
        .wdata              (wdata              ),
        .wstrb              (wstrb              ),
        .wlast              (wlast              ),
        .wvalid             (wvalid             ),
        .wready             (wready             ),
        
        .bid                (bid                ),
        .bresp              (bresp              ),
        .bvalid             (bvalid             ),
        .bready             (bready             )
    
    );
    
    
endmodule
