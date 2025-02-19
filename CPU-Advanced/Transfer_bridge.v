`timescale 1ns / 1ps

module Transfer_bridge(
    input               aclk,
    input               aresetn,
    
    input            i_rd_req,
    input [1:0]      i_rd_type,
    input [31:0]     i_rd_addr,
    output           i_rd_rdy,
    output           i_ret_valid,
    output           i_ret_last,
    output [31:0]    i_ret_data,

    // axi bridge, write channel
    input           i_wr_req,
    input [2:0]     i_wr_type,
    input [31:0]    i_wr_addr,
    input [3:0]     i_wr_wstrb,
    input [127:0]   i_wr_data,
    output          i_wr_rdy,
    //额外
    input           i_uncache_store,
    output          i_bvalid,
    
    input            d_rd_req,
    input [1:0]      d_rd_type,
    input [31:0]     d_rd_addr,
    output           d_rd_rdy,
    output           d_ret_valid,
    output           d_ret_last,
    output [31:0]    d_ret_data,

    // axi bridge, write channel
    input           d_wr_req,
    input [2:0]     d_wr_type,
    input [31:0]    d_wr_addr,
    input [3:0]     d_wr_wstrb,
    input [127:0]   d_wr_data,
    output          d_wr_rdy,
    //额外
    input           d_uncache_store,
    output          d_bvalid,
    
    //读请求
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

    //读响应
    input   [ 3:0]      rid,
    input   [31:0]      rdata,
    input   [ 1:0]      rresp,
    input               rlast,
    input               rvalid,
    output              rready,

    //写请求
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

    //写数据
    output  [ 3:0]      wid,
    output  [31:0]      wdata,
    output  [ 3:0]      wstrb,
    output              wlast,
    output              wvalid,
    input               wready,

    //写响应
    input   [ 3:0]      bid,
    input   [ 1:0]      bresp,
    input               bvalid,
    output              bready
);
parameter INST_ID = 4'h0;
parameter DATA_ID = 4'h1;

assign i_bvalid = bvalid;
assign d_bvalid = bvalid;
assign i_wr_rdy = 1'b1;
//AXI方向 
//读请求
assign arlen = 8'd3;//每次读，传输一行cache！
assign arburst = 2'b01;//突发传输，免握手
assign arlock = 2'b00;//固定
assign arcache = 4'd0;//固定
assign arprot = 3'd0;//固定

wire inst_read_req_valid;
wire data_read_req_valid;
wire read_req_valid;
assign inst_read_req_valid = !data_read_req_valid && i_rd_req && i_rd_rdy;
assign data_read_req_valid = d_rd_req && d_rd_rdy;
assign read_req_valid = inst_read_req_valid||data_read_req_valid;
    reg [3:0] arid_r;
    always @(posedge aclk ) begin
        if (~aresetn) 
            arid_r <= 4'b0;
        else if (inst_read_req_valid)
            arid_r <= 4'b0;
        else if (data_read_req_valid)
            arid_r <= 4'b1;
    end
    assign arid = arid_r;
//读请求通道begin
    //读请求的addr和size
    reg [31:0] araddr_r;
    always @(posedge aclk ) begin
        if (~aresetn) 
            araddr_r <= 32'b0;
        else if (inst_read_req_valid)//读请求有效 
            araddr_r <= i_rd_addr;
        else if (data_read_req_valid)
            araddr_r <= d_rd_addr;
    end
    assign araddr = araddr_r;
    
    reg [31:0] arsize_r;
    always @(posedge aclk ) begin
        if (~aresetn) 
            arsize_r <= 32'b0;
        else if (inst_read_req_valid)//读请求有效 
            arsize_r <= {1'b0,i_rd_type};
        else if (data_read_req_valid)
            arsize_r <= {1'b0,d_rd_type};
    end
    assign arsize = arsize_r;
    //读请求的valid
    reg arvalid_r;
    always @(posedge aclk ) begin
        if (~aresetn) begin
            arvalid_r <= 1'b0;
        end
        else if (read_req_valid) begin
            arvalid_r <= 1'b1;
        end
        else if (arvalid && arready) begin//握手成功
            arvalid_r <= 1'b0;
        end
    end
    assign arvalid = arvalid_r && !((araddr_r == awaddr_r) && axi_write_state != 2'd0);
//读请求通道end

//读响应begin
    assign d_ret_last = rlast;
    assign i_ret_last = rlast;
    assign d_rd_rdy = 1'b1;
    assign i_rd_rdy = 1'b1&&!d_rd_req;
    assign d_ret_data = rdata; 
    assign i_ret_data = rdata;
    
    assign d_ret_valid = (rid == 1'b1)? rvalid:1'b0;
    assign i_ret_valid = (rid == 1'b0)? rvalid:1'b0;
    assign rready = 1'b1;//始终准备好传输
//读响应end

assign awid = 4'd1; //写请求，只能取数
assign awlen = uncache_store_r ? 8'd0 : 8'd3; 
assign awburst = 2'b01; 
assign awlock = 2'b0;
assign awcache = 4'b0;
assign awprot = 3'b0;
assign wid = 4'b1;
//写的最后一拍
assign wlast = uncache_store_r ? 1'b1 : (write_buf_counter == 3'd3);

//允许CPU写数据
reg    d_wr_rdy_r;
always @(posedge aclk) begin
    if (!aresetn) begin
        d_wr_rdy_r <= 1'b1;
    end
    else if (d_wr_rdy && d_wr_req) begin//来请求了，就不允许了
        d_wr_rdy_r <= 1'b0;
    end
    else if (write_buf_counter == 3'd3 && wready && wvalid && !uncache_store_r || uncache_store_r && wready && wvalid) begin
        d_wr_rdy_r <= 1'b1;
    end
end
assign d_wr_rdy = d_wr_rdy_r && axi_write_state == 2'd0; 


//写状态机
wire write_request_valid;
assign write_request_valid = d_wr_req && d_wr_rdy;

reg uncache_store_r;
reg [3:0] uncache_wr_wstrb_r;
always @(posedge aclk) 
begin
    if (write_request_valid) 
    begin
        uncache_store_r <= d_uncache_store;//锁存cache属性
        uncache_wr_wstrb_r <= d_wr_wstrb;//锁存字节使能
    end
end

reg [1:0] axi_write_state;
always @(posedge aclk ) begin
    if (~aresetn) begin//初始状态0
        axi_write_state <= 2'b0;
    end
    else if ((axi_write_state == 2'b0) && write_request_valid) begin//0然后来了请求，变为1
        axi_write_state <= 2'd1;
    end
    else if ((axi_write_state == 2'd1) && awvalid && awready && !(wvalid && wready && wlast)) 
    begin//非最后一个
        axi_write_state <= 2'd2;
    end
    else if ((axi_write_state == 2'd1) && awvalid && awready && wvalid && wready && wlast) 
    begin//最后一个写好了
        axi_write_state <= 2'd3;
    end
    else if ((axi_write_state == 2'd2) && wvalid && wready && wlast) begin
        axi_write_state <= 2'd3;
    end
    else if ((axi_write_state == 2'd3) && (bvalid && bready)) begin
        axi_write_state <= 2'd0;
    end
end
//写请求begin
    reg [31:0] awaddr_r;
    always @(posedge aclk ) begin
        if (~aresetn) begin
            awaddr_r <= 32'b0;
        end
        else if (write_request_valid) begin
            awaddr_r <= d_wr_addr;
        end
    end
    assign awaddr = awaddr_r;
    assign awsize = 3'b010;
    
    reg awvalid_r;
    always @(posedge aclk ) begin
        if (~aresetn) begin
            awvalid_r <= 1'b0;
        end
        else if (write_request_valid) begin
            awvalid_r <= 1'b1;
        end
        else if (awvalid && awready) begin
            awvalid_r <= 1'b0;
        end
    end
    assign awvalid = awvalid_r;
//写请求end

//写数据begin
    assign wdata = uncache_store_r ? write_buf[31:0] : 
                   {{32{write_buf_counter == 3'd0}} & write_buf[ 31: 0]} |
                   {{32{write_buf_counter == 3'd1}} & write_buf[ 63:32]} |
                   {{32{write_buf_counter == 3'd2}} & write_buf[ 95:64]} |
                   {{32{write_buf_counter == 3'd3}} & write_buf[127:96]};
    
    assign wstrb = uncache_store_r ? uncache_wr_wstrb_r : 4'b1111;
    
    reg wvalid_r;
    always @(posedge aclk) begin
        if (~aresetn) begin
            wvalid_r <= 4'b0;
        end
        else if (axi_write_state == 2'd2) begin
            wvalid_r <= 1'b1;
        end
        else if (wvalid && wready) begin
            wvalid_r <= 1'b0;
        end
    end
    assign wvalid = wvalid_r;
//写数据end

//写响应begin
    reg bready_r;
    always @(posedge aclk) begin
        if (~aresetn) begin
            bready_r <= 4'b0;
        end
        else if (axi_write_state == 2'd3) begin
            bready_r <= 1'b1;
        end
        else if (bvalid && bready) begin
            bready_r <= 1'b0;
        end
    end
    assign bready = bready_r;
//写响应end

//写缓冲区
reg [127:0] write_buf;
always @(posedge aclk) begin
    if (write_request_valid) 
        write_buf <= d_wr_data;
end

reg [2:0] write_buf_counter;
always @(posedge aclk) begin
    if (!aresetn) begin
        write_buf_counter <= 3'b0;
    end
    else if (uncache_store_r) begin
        write_buf_counter <= 3'b0;
    end
    else if (wready && wvalid) begin 
        write_buf_counter <= write_buf_counter + 3'b1;
    end
    else if (write_buf_counter == 3'd4) begin
        write_buf_counter <= 3'b0;
    end
end

endmodule
