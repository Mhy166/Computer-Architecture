`timescale 1ns / 1ps

module Transfer_bridge(
    input               aclk,
    input               aresetn,
    
     //CPU ָ��SRAM�ӿ�
    input               inst_req,
    input               inst_wr,
    input   [ 1:0]      inst_size,
    input   [31:0]      inst_addr,
    input   [ 3:0]      inst_wstrb,
    input   [31:0]      inst_wdata,
    output              inst_addr_ok,
    output              inst_data_ok,
    output  [31:0]      inst_rdata,

    //CPU ����SRAM�ӿ�
    input               data_req,
    input               data_wr,
    input   [ 1:0]      data_size,
    input   [31:0]      data_addr,
    input   [31:0]      data_wdata,
    input   [ 3:0]      data_wstrb,
    output              data_addr_ok,
    output              data_data_ok,
    output  [31:0]      data_rdata,
    
    //������
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

    //����Ӧ
    input   [ 3:0]      rid,
    input   [31:0]      rdata,
    input   [ 1:0]      rresp,
    input               rlast,
    input               rvalid,
    output              rready,

    //д����
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

    //д����
    output  [ 3:0]      wid,
    output  [31:0]      wdata,
    output  [ 3:0]      wstrb,
    output              wlast,
    output              wvalid,
    input               wready,

    //д��Ӧ
    input   [ 3:0]      bid,
    input   [ 1:0]      bresp,
    input               bvalid,
    output              bready
);
parameter INST_ID = 4'h0;
parameter DATA_ID = 4'h1;

//�̲��Ͻ����ź�����
assign arlen = 8'b00000000;
assign arburst = 2'b01;
assign arlock  = 2'b00;
assign arcache = 2'b00;
assign arprot  = 2'b00;
//����Ӧ�� rresp rlast �����ź�
assign awid  = DATA_ID;
assign awlen = 8'b00000000;
assign awburst = 2'b01;
assign awlock  = 2'b00;
assign awcache = 2'b00;
assign awprot  = 2'b00; 
assign wid = DATA_ID;
assign wlast = 4'b0001;
//д��Ӧ�� bid bresp �����ź�

//�����߼�--������

//�Ĵ�������״̬��״̬����ת
reg         arvalid_r;
reg  [ 3:0] arid_r;
reg  [31:0] araddr_r;
reg  [ 2:0] arsize_r;

assign arvalid  = arvalid_r;
assign arid     = arid_r;
assign araddr   = araddr_r;
assign arsize   = arsize_r;

//�������Ӧͨ����
wire r_data_ok;//�����ݵ�OK�ź�
wire r_inst_ok;
wire [31:0] r_data;

//д����+д����
reg         awvalid_r;
reg  [31:0] awaddr_r;
reg  [ 2:0] awsize_r;
reg         wvalid_r;
reg  [31:0] wdata_r;
reg  [ 3:0] wstrb_r;

assign awvalid  = awvalid_r;
assign wvalid   = wvalid_r;
assign awaddr   = awaddr_r;
assign awsize   = awsize_r;
assign wdata    = wdata_r;
assign wstrb    = wstrb_r;

//��д��Ӧ��
wire        b_ok;

//ָ����CPU�Ƿ�׼����
wire        cpu_inst_read_ready;
wire        cpu_data_read_ready;
wire        cpu_data_write_ready;

assign cpu_inst_read_ready = 1;
assign cpu_data_read_ready = !data_req_record_empty && !data_req_record_output[32];
assign cpu_data_write_ready= !data_req_record_empty && data_req_record_output[32];
//CPUд���ݣ��������������ʵ�������Ӧ��
    wire        write_req_valid;
    wire [31:0] write_req_addr;
    wire [ 2:0] write_req_size;
    wire [31:0] write_req_data;
    wire [ 3:0] write_req_strb;
    
    wire        write_data_resp_wen;
    wire        write_data_resp_ren;
    wire        write_data_resp_empty;
    wire        write_data_resp_full;
    
    wire        data_write_valid;
    
    assign b_ok = bvalid&&bready;//д��Ӧͨ���Ѿ�Ū��
    assign bready = !write_data_resp_full;
    
    assign write_req_valid      = data_write_valid;
    //����CPU��SRAM�ӿڵ�
    assign write_req_addr       = data_addr;
    assign write_req_size       = data_size;
    assign write_req_data       = data_wdata;
    assign write_req_strb       = data_wstrb;
   
    fifo_only_count #(
        .BUFF_DEPTH     (6),
        .ADDR_WIDTH     (3)
    ) write_data_resp_count (
        .clk            (aclk),
        .resetn         (aresetn),
        .wen            (write_data_resp_wen),
        .ren            (write_data_resp_ren),
        .empty          (write_data_resp_empty),
        .full           (write_data_resp_full)
    );
    assign write_data_resp_ren = cpu_data_write_ready;
    assign write_data_resp_wen = b_ok;



//CPU�����ݣ���Ҫ�Է�д�������У����ٶ���
//����Ӧͨ���Ĵӷ�ʵ���������������棡���ʱ��  ����  ׼���ö��ˣ�
//�����涼�������Ϳ���׼���ã�
    assign rready = !read_inst_resp_full && !read_data_resp_full;
    assign r_data_ok = rvalid && rready && rid == DATA_ID;
    assign r_inst_ok = rvalid && rready && rid == INST_ID;
    assign r_data    = rdata;
//�����ݵĻ���--begin
    wire        read_data_resp_wen;
    wire        read_data_resp_ren;
    wire        read_data_resp_empty;
    wire        read_data_resp_full;
    wire [31:0] read_data_resp_input;
    wire [31:0] read_data_resp_output;
    fifo_buffer #(
        .DATA_WIDTH     (32),
        .BUFF_DEPTH     (6),
        .ADDR_WIDTH     (3)
    ) read_data_resp_buff (
        .clk            (aclk),
        .resetn         (aresetn),
        .wen            (read_data_resp_wen),
        .ren            (read_data_resp_ren),
        .empty          (read_data_resp_empty),
        .full           (read_data_resp_full),
        .input_data     (read_data_resp_input),
        .output_data    (read_data_resp_output)
    );
    //CPU�ӻ�����������ݣ�������ֻ������
    assign read_data_resp_ren = cpu_data_read_ready;
    assign data_rdata = read_data_resp_output; 
    //�����ʾ�����Ƿ���Ч�����治�ܿ�ѽ��
    assign data_data_ok = 
        (cpu_data_read_ready && !read_data_resp_empty) || 
        (cpu_data_write_ready && !write_data_resp_empty);
    //������ⲿ����������
    assign read_data_resp_wen = r_data_ok;//data_ok,дʹ������
    assign read_data_resp_input = r_data;//��������ⲿ�����ݣ�Ȼ��д��
//�����ݵĻ���--end
//��ָ��Ļ���--begin
    wire        read_inst_resp_wen;//I
    wire        read_inst_resp_ren;//I
    wire        read_inst_resp_empty;//O
    wire        read_inst_resp_full;//O
    wire [31:0] read_inst_resp_input;//I
    wire [31:0] read_inst_resp_output;//O
    fifo_buffer #(
        .DATA_WIDTH     (32),
        .BUFF_DEPTH     (6),
        .ADDR_WIDTH     (3)
    ) read_inst_resp_buff (
        .clk            (aclk),
        .resetn         (aresetn),
        .wen            (read_inst_resp_wen),
        .ren            (read_inst_resp_ren),
        .empty          (read_inst_resp_empty),
        .full           (read_inst_resp_full),
        .input_data     (read_inst_resp_input),
        .output_data    (read_inst_resp_output)
    );
    assign read_inst_resp_ren = cpu_inst_read_ready;
    assign inst_rdata = read_inst_resp_output; 
    //�����ʾָ���Ƿ���Ч�����治�ܿ�ѽ��
    assign inst_data_ok = cpu_inst_read_ready && !read_inst_resp_empty;
        
    //������ⲿ����������
    assign read_inst_resp_wen = r_inst_ok;//inst_ok,дʹ������
    assign read_inst_resp_input = r_data;//��������ⲿ�����ݣ�Ȼ��д��
//��ָ��Ļ���--end



//�������ѡ���ź�
wire        read_data_req_ok;
wire        read_inst_req_ok;
wire        read_req_sel_data;
wire        read_req_sel_inst;
wire        write_data_req_ok;


assign read_inst_req_ok = read_req_sel_inst && !arvalid_r;
assign read_data_req_ok = read_req_sel_data && !arvalid_r;
assign write_data_req_ok = data_write_valid && !wvalid_r && !awvalid_r;

assign data_addr_ok = read_data_req_ok || write_data_req_ok;
assign inst_addr_ok = read_inst_req_ok;

//��������ź�
wire        read_req_valid;
wire [ 3:0] read_req_id;
wire [31:0] read_req_addr;
wire [ 2:0] read_req_size;

//��·����Ч�ź�
wire        inst_read_valid;
wire        data_read_valid;
//��������ź�
wire        inst_related;
wire        data_related; 

//��¼���ݶ�д����Ļ���,����ǣ��������Ƕ�����д����ַ��ʲô��
    wire        data_req_record_wen;
    wire        data_req_record_ren;
    wire        data_req_record_empty;
    wire        data_req_record_full;
    wire        data_req_record_related_1;
    wire [32:0] data_req_record_input;      // {wr, addr}
    wire [32:0] data_req_record_output;     // {wr, addr}

//д�û��棬���ⲿȡ��
    assign data_req_record_ren = data_data_ok;
    
    assign data_req_record_wen = data_req && data_addr_ok;
    assign data_req_record_input = {data_wr, data_addr};
    

//AXI����Ĺ���begin
    assign inst_related = 1'b0;
    assign data_related = data_req_record_related_1;
    
    assign inst_read_valid = inst_req && !inst_wr && !inst_related;
    assign data_read_valid = data_req && !data_wr && !data_related;
    assign data_write_valid= data_req &&  data_wr && !data_related;
    
    assign read_req_sel_data = data_read_valid;
    assign read_req_sel_inst = data_read_valid ? 1'b0:inst_read_valid;
    
    assign read_req_valid    = inst_read_valid || data_read_valid;
    assign read_req_id       = read_req_sel_data ? DATA_ID : INST_ID;
    assign read_req_addr     = read_req_sel_data ? data_addr : inst_addr;
    assign read_req_size     = read_req_sel_data ? data_size : inst_size;
//AXI����Ĺ���end

fifo_buffer_valid #(
    .DATA_WIDTH     (33),
    .BUFF_DEPTH     (6),
    .ADDR_WIDTH     (3),
    .RLAT_WIDTH     (32)
) data_req_record (
    .clk            (aclk),
    .resetn         (aresetn),
    .wen            (data_req_record_wen),
    .ren            (data_req_record_ren),
    .empty          (data_req_record_empty),
    .full           (data_req_record_full),
    .related_1      (data_req_record_related_1),
    .input_data     (data_req_record_input),
    .output_data    (data_req_record_output),
    .related_data_1 (data_addr)
);


always @ (posedge aclk) begin
    if (!aresetn) 
    begin
        arvalid_r <= 1'b0;
        arid_r   <= 4'h0;
        araddr_r <= 32'h0;
        arsize_r <= 3'h0;
    end 
    else if (!arvalid_r && read_req_valid) //��������Ч
    begin
        arvalid_r <= read_req_valid;
        arid_r    <= read_req_id;
        araddr_r  <= read_req_addr;
        arsize_r  <= read_req_size;
    end 
    else if (arvalid_r && arvalid && arready) //����ͨ���Ѿ�������
    begin
        arvalid_r <= 1'b0;
        arid_r   <= 4'h0;
        araddr_r <= 32'h0;
        arsize_r <= 3'h0;
    end
end

always @ (posedge aclk) begin
    if (!aresetn) 
    begin
        awvalid_r <= 1'b0;
        awaddr_r <= 32'h0;
        awsize_r <= 3'h0;
    end 
    else if (!awvalid_r && !wvalid_r && write_req_valid) 
    begin
        awvalid_r <= 1'b1;
        awaddr_r <= write_req_addr;
        awsize_r <= write_req_size;
    end 
    else if (awvalid_r && awvalid && awready) begin
        awvalid_r <= 1'b0;
        awaddr_r <= 32'h0;
        awsize_r <= 3'h0;
    end
    
    if (!aresetn) begin
        wvalid_r  <= 1'b0;
        wdata_r  <= 32'h0;
        wstrb_r  <= 4'h0;
    end 
    else if (!awvalid_r && !wvalid_r && write_req_valid) begin
        wvalid_r  <= 1'b1;
        wdata_r  <= write_req_data;
        wstrb_r  <= write_req_strb;
    end else if (wvalid_r && wvalid && wready) begin
        wvalid_r  <= 1'b0;
        wdata_r  <= 32'h0;
        wstrb_r  <= 4'h0;
    end
end

endmodule
