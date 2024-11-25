`timescale 1ns / 1ps
//��������
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

assign ram_ren = {4{req && addr_ok}};//��ok���ܶ���
assign ram_wen = ({4{wr}} & wstrb & size_decode);
//��׼����׼��������ʹ�ܾͺã�
assign ram_addr = addr;
assign ram_wdata = wdata;
reg ram_ren_r;
always @(posedge clk)
begin
    ram_ren_r <= ram_ren;
end
//��д������
reg [2 :0] buf_wptr;
reg [2 :0] buf_rptr;
reg [31:0] buf_rdata [3:0];//4*32�Ļ�����
wire  buf_empty;
wire  buf_full ;
wire  fast_return ;

assign buf_empty = (buf_wptr==buf_rptr);
assign buf_full  = (buf_wptr=={~buf_rptr[2],buf_rptr[1:0]});
assign fast_return = (ram_ren_r && data_ok && buf_empty);
assign addr_ok = !buf_full;
assign data_ok = !buf_empty||ram_ren_r;
assign rdata = buf_empty ? ram_rdata :buf_rdata[buf_rptr[1:0]];
//дָ����ͨ����RAM����������ȥд��������Ȼ��ɱ�CPU����
//��дָ��
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
    else if(!buf_empty && data_ok)//data_okһ�ξͶ���һ�Σ�
    begin
        buf_rptr <= buf_rptr + 1'b1;
    end
end
data_ram data_ram_module(   // ���ݴ洢ģ��
        .clka   (clk         ),  // I, 1,  ʱ��
        .ena    (ram_ren     ),  // I, 1,  ��ʹ��
        .wea    (ram_wen      ),  // I, 1,  дʹ��
        .addra  (ram_addr[19:2]),  // I, 8,  ����ַ
        .dina   (ram_wdata    ),  // I, 32, д����
        .douta  (ram_rdata    )  // O, 32, ������
);

endmodule