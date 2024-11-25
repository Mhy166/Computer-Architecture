`timescale 1ns / 1ps
//缓冲设置
module data_ram_wrap(
      input         clk,
      input         resetn,
        
      input         req    ,
      input         wr     ,
      input [1 :0]  size   ,
      input [3 :0]  wstrb  ,
      input [31:0]  addr   ,
      input [31:0]  wdata  ,
      output        addr_ok,
      output        data_ok,
      output [31:0] rdata  
);
wire [3:0]  ram_ren;
wire [31:0] ram_addr;
wire [3:0] ram_wen;
wire [31:0] ram_wdata;
wire [31:0] ram_rdata;



wire [3:0] size_decode;
assign size_decode = size==2'd0 ? 
    {addr[1:0]==2'd3,addr[1:0]==2'd2,addr[1:0]==2'd1,addr[1:0]==2'd0} :
                      size==2'd1 ? 
    {addr[1],addr[1],~addr[1],~addr[1]} :4'b1111;

assign ram_ren = {4{req && addr_ok}};//都ok才能读！
assign ram_wen = ({4{wr}} & wstrb & size_decode);
//该准备的准备，控制使能就好！
assign ram_addr = addr;
assign ram_wdata = wdata;
reg ram_ren_r;
always @(posedge clk)
begin
    ram_ren_r <= ram_ren;
end
//读写缓冲区
reg [2 :0] buf_wptr;
reg [2 :0] buf_rptr;
reg [31:0] buf_rdata [3:0];//4*32的缓冲区
wire  buf_empty;
wire  buf_full ;
wire  fast_return ;

assign buf_empty = (buf_wptr==buf_rptr);
assign buf_full  = (buf_wptr=={~buf_rptr[2],buf_rptr[1:0]});
assign fast_return = (ram_ren_r && data_ok && buf_empty);
assign addr_ok = !buf_full;
assign data_ok = !buf_empty||ram_ren_r;
assign rdata = buf_empty ? ram_rdata :buf_rdata[buf_rptr[1:0]];
//写指针是通过我RAM读来的数据去写缓冲区，然后可被CPU读走
//读写指针
always @(posedge clk)
begin
    if(!resetn)
    begin
        buf_wptr <= 3'd0;
    end
    else if(ram_ren_r && !fast_return)
    begin
        buf_wptr <= buf_wptr + 1'b1;
    end
end

always @(posedge clk)
begin
    if(ram_ren_r && !fast_return)
    begin
        buf_rdata[buf_wptr[1:0]] <= ram_rdata;
    end
end

always @(posedge clk)
begin
    if(!resetn)
    begin
        buf_rptr <= 3'd0;
    end
    else if(!buf_empty && data_ok)//data_ok一次就读走一次！
    begin
        buf_rptr <= buf_rptr + 1'b1;
    end
end
data_ram data_ram_module(   // 数据存储模块
        .clka   (clk         ),  // I, 1,  时钟
        .ena    (ram_ren     ),  // I, 1,  读使能
        .wea    (ram_wen      ),  // I, 1,  写使能
        .addra  (ram_addr[19:2]),  // I, 8,  读地址
        .dina   (ram_wdata    ),  // I, 32, 写数据
        .douta  (ram_rdata    )  // O, 32, 读数据
);

endmodule