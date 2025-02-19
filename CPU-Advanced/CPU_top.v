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
    
    wire        core_inst_req;
    wire        core_inst_wr;
    wire [ 1:0] core_inst_size;
    wire [31:0] core_inst_addr;
    wire [ 3:0] core_inst_wstrb;
    wire [31:0] core_inst_wdata;
    wire        core_inst_uncache;
    wire        core_inst_addr_ok;
    wire        core_inst_data_ok;
    wire [31:0] core_inst_rdata;
 
    wire        core_data_req;
    wire        core_data_wr;
    wire [ 1:0] core_data_size;
    wire [31:0] core_data_addr;
    wire [ 3:0] core_data_wstrb;
    wire [31:0] core_data_wdata;
    wire        core_data_uncache;
    wire        core_data_addr_ok;
    wire        core_data_data_ok;
    wire [31:0] core_data_rdata;
    
    wire [31:0] IF_pc;
    wire [31:0] IF_inst;
    wire [31:0] ID_pc;
    wire [31:0] EXE_pc;
    wire [31:0] MEM_pc;
    wire [31:0] WB_pc;
    wire [31:0] cpu_5_valid;
    wire [31:0] HI_data;
    wire [31:0] LO_data;
    
    wire cancel;
    pipeline_cpu uut(
        .clk(aclk), 
        .resetn(aresetn), 
       
        .inst_req    (core_inst_req    ),
        .inst_wr     (core_inst_wr     ),
        .inst_size   (core_inst_size   ),
        .inst_wstrb  (core_inst_wstrb  ),
        .inst_addr   (core_inst_addr   ),
        .inst_wdata  (core_inst_wdata  ),
        .inst_uncache(core_inst_uncache),
        .inst_addr_ok(core_inst_addr_ok),
        .inst_rdata  (core_inst_rdata  ),
        .inst_data_ok(core_inst_data_ok),
        
        .data_req    (core_data_req    ),
        .data_wr     (core_data_wr     ),
        .data_size   (core_data_size   ),
        .data_wstrb  (core_data_wstrb  ),
        .data_addr   (core_data_addr   ),
        .data_wdata  (core_data_wdata  ),
        .data_uncache(core_data_uncache),
        .data_addr_ok(core_data_addr_ok),
        .data_rdata  (core_data_rdata  ),
        .data_data_ok(core_data_data_ok),
       
        .IF_pc(IF_pc), 
        .IF_inst(IF_inst), 
        .ID_pc(ID_pc), 
        .EXE_pc(EXE_pc), 
        .MEM_pc(MEM_pc), 
        .WB_pc(WB_pc), 
        .cpu_5_valid(cpu_5_valid),
        .HI_data(HI_data),
        .LO_data(LO_data),
        .cache_cancel(cancel)
    );
        wire dcache_rd_req;
        wire [1:0] dcache_rd_type;
        wire [31:0] dcache_rd_addr;
        wire dcache_rd_rdy;
        wire dcache_ret_valid;
        wire dcache_ret_last;
        wire [31:0] dcache_ret_data;
        
        wire dcache_wr_req;
        wire [2:0]dcache_wr_type;
        wire [31:0] dcache_wr_addr;
        wire [3:0] dcache_wr_wstrb;
        wire [127:0] dcache_wr_data;
        wire dcache_uncache_store;
        wire dcache_wr_rdy;
        wire dcache_bvalid;
        
        wire icache_rd_req;
        wire [1:0] icache_rd_type;
        wire [31:0] icache_rd_addr;
        wire icache_rd_rdy;
        wire icache_ret_valid;
        wire icache_ret_last;
        wire [31:0] icache_ret_data;
        
        wire icache_wr_req;
        wire [2:0]icache_wr_type;
        wire [31:0] icache_wr_addr;
        wire [3:0] icache_wr_wstrb;
        wire [127:0] icache_wr_data;
        wire icache_uncache_store;
        wire icache_wr_rdy;
        wire icache_bvalid;
     
     
    Cache ICache(
        .clk(aclk), 
        .resetn(!(!aresetn||cancel)), 
       
        .core_req    (core_inst_req    ),
        .core_wr     (core_inst_wr     ),
        .core_size   (core_inst_size   ),
        .core_wstrb  (core_inst_wstrb  ),
        .core_addr   (core_inst_addr   ),
        .core_wdata  (core_inst_wdata  ),
        .core_uncache(core_inst_uncache),
        .core_addr_ok(core_inst_addr_ok),
        .core_rdata  (core_inst_rdata  ),
        .core_data_ok(core_inst_data_ok),
       
        // axi bridge, rd channel
        .rd_req     (icache_rd_req),
        .rd_type    (icache_rd_type),
        .rd_addr    (icache_rd_addr),
        .rd_rdy     (icache_rd_rdy),
        .ret_valid  (icache_ret_valid),
        .ret_last   (icache_ret_last),
        .ret_data   (icache_ret_data),
    
        // axi bridge, write channel
        .wr_req(icache_wr_req),
        .wr_type(icache_wr_type),
        .wr_addr(icache_wr_addr),
        .wr_wstrb(icache_wr_wstrb),
        .wr_data(icache_wr_data),
        .uncache_store(icache_uncache_store),
        .wr_rdy(icache_wr_rdy),
        .bvalid(icache_bvalid)
    );
    Cache DCache(
        .clk(aclk), 
        .resetn(!(!aresetn||cancel)), 
       
        .core_req    (core_data_req    ),
        .core_wr     (core_data_wr     ),
        .core_size   (core_data_size   ),
        .core_wstrb  (core_data_wstrb  ),
        .core_addr   (core_data_addr   ),
        .core_wdata  (core_data_wdata  ),
        .core_uncache(core_data_uncache),
        .core_addr_ok(core_data_addr_ok),
        .core_rdata  (core_data_rdata  ),
        .core_data_ok(core_data_data_ok),
       
        .rd_req (dcache_rd_req),
        .rd_type(dcache_rd_type),
        .rd_addr(dcache_rd_addr),
        .rd_rdy (dcache_rd_rdy),
        .ret_valid(dcache_ret_valid),
        .ret_last(dcache_ret_last),
        .ret_data(dcache_ret_data),
    
        // axi bridge, write channel
        .wr_req (dcache_wr_req),
        .wr_type(dcache_wr_type),
        .wr_addr(dcache_wr_addr),
        .wr_wstrb(dcache_wr_wstrb),
        .wr_data(dcache_wr_data),
        .uncache_store(dcache_uncache_store),
        .wr_rdy(dcache_wr_rdy),
        .bvalid(dcache_bvalid)
    );
    
    
    
    
    Transfer_bridge uut_Transfer_bridge(
        .aclk               (aclk               ),
        .aresetn            (!(!aresetn||cancel)),
        
        .i_rd_req     (icache_rd_req),
        .i_rd_type    (icache_rd_type),
        .i_rd_addr    (icache_rd_addr),
        .i_rd_rdy     (icache_rd_rdy),
        .i_ret_valid  (icache_ret_valid),
        .i_ret_last   (icache_ret_last),
        .i_ret_data   (icache_ret_data),
    
        // axi bridge, write channel
        .i_wr_req(icache_wr_req),
        .i_wr_type(icache_wr_type),
        .i_wr_addr(icache_wr_addr),
        .i_wr_wstrb(icache_wr_wstrb),
        .i_wr_data(icache_wr_data),
        .i_uncache_store(icache_uncache_store),
        .i_wr_rdy(icache_wr_rdy),
        .i_bvalid(icache_bvalid),
        
        .d_rd_req     (dcache_rd_req),
        .d_rd_type    (dcache_rd_type),
        .d_rd_addr    (dcache_rd_addr),
        .d_rd_rdy     (dcache_rd_rdy),
        .d_ret_valid  (dcache_ret_valid),
        .d_ret_last   (dcache_ret_last),
        .d_ret_data   (dcache_ret_data),
    
        // axi bridge, write channel
        .d_wr_req(dcache_wr_req),
        .d_wr_type(dcache_wr_type),
        .d_wr_addr(dcache_wr_addr),
        .d_wr_wstrb(dcache_wr_wstrb),
        .d_wr_data(dcache_wr_data),
        .d_uncache_store(dcache_uncache_store),
        .d_wr_rdy(dcache_wr_rdy),
        .d_bvalid(dcache_bvalid),
        
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
