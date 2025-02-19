`timescale 1ns / 1ps
`define STORE 1'b1
`define READ  1'b0
module Cache(
    input               clk,
    input               resetn,
    
    input        core_req,    
    input        core_wr,    
    input [ 1:0] core_size,   
    input [ 3:0] core_wstrb,  
    input [31:0] core_addr,
    input [31:0] core_wdata,
    input        core_uncache,
    output         core_addr_ok,
    output  [31:0] core_rdata,
    output         core_data_ok,
    
    // axi bridge, rd channel
    output          rd_req,
    output [1:0]    rd_type,
    output [31:0]   rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input [31:0]    ret_data,

    // axi bridge, write channel
    output          wr_req,
    output [2:0]    wr_type,
    output [31:0]   wr_addr,
    output [3:0]    wr_wstrb,
    output [127:0]  wr_data,
    input           wr_rdy,
    //����
    output          uncache_store,
    input           bvalid
    );
    
    wire valid;
    wire op;
    wire [1:0] size;
    wire [19:0] tag;
    wire [7:0] index;
    wire [3:0] offset;
    wire [3:0] wstrb;
    wire [31:0] wdata;
    wire uncache;
    
    wire addr_ok;
    wire data_ok;
    wire [31:0] rdata;
    
    assign valid = core_req;
    assign op = core_wr;
    assign size = core_size;
    assign tag = core_addr[31:12];
    assign index = core_addr[11:4];
    assign offset = core_addr[3:0];
    assign wdata = core_wdata;
    assign wstrb = core_wstrb;
    assign uncache = core_uncache;
    
    assign core_addr_ok = addr_ok;
    assign core_data_ok = data_ok;
    assign core_rdata = rdata;
   
      /* ��״̬�� */
      parameter IDLE    = 5'b00001;
      parameter LOOKUP  = 5'b00010;
      parameter MISS    = 5'b00100;
      parameter REPLACE = 5'b01000;
      parameter REFILL  = 5'b10000;
    
      reg  [4:0] main_state;
      wire [4:0] next_state;
      
      always@(posedge clk) 
      begin
            if (!resetn)
              main_state <= IDLE;
            else
              main_state <= next_state;
      end
    
      /* дBuffer״̬��������IDLE */
      parameter WRITE   = 5'b00010;
      
      reg [4:0] write_state;
      wire [4:0] write_next_state;
      
      always@(posedge clk) begin
            if (!resetn) 
              write_state <= IDLE;
            else 
              write_state <= write_next_state;
      end
      
      
      wire write_hit;//cacheд����
      wire cache_hit;//cache����
      wire [31:0] load_res;//����LOAD�ô����͵Ľ��
      wire [31:0] way_load_word [1:0];//����cache·�����Ľ��
      
      genvar way,bank;
      
      wire way_hit [1:0];//���е�·
      wire [127:0] way_data[1:0];//·����
      wire way_v [1:0];//·��Ч
      wire [19:0] way_tag [1:0];//·��ǩ
      
      //�滻·�������Ч�ź�
      wire replace_way_dirty;
      wire replace_way_valid;
      wire [127:0] replace_data;//�滻����
      
      //������cache��д����
      wire [127:0] uncache_write_data;
      
      //дbuffer
      reg        write_buffer_way;//д��һ·
      reg [1:0]  write_buffer_bank;//д��һbank
      reg [7:0]  write_buffer_index;//д������
      reg [3:0]  write_buffer_wstrb;//д���ֽ�ʹ��
      reg [31:0] write_buffer_wdata;//д������
      
      //��λ�Ĵ�����
      wire d_w;
      reg [255:0] D_regfile[1:0];
      wire d_we[1:0];
      wire [7:0] d_addr;
      
      //��ͻ�߼�
      wire conflict;//д���г�ͻ����ѯ״̬     д           ��ǰҪ��    λ�ö�һ����
      assign conflict = (main_state == LOOKUP && op_r == 1 && op == 0 && index == index_r && tag == tag_r && offset == offset_r)
                        ||(write_state == WRITE && op == 0 && offset[3:2] == write_buffer_bank);
      //����buffer
      reg op_r;
      reg [7:0] index_r;
      reg [19:0] tag_r;
      reg [3:0] offset_r;
      reg [3:0] wstrb_r;
      reg [31:0] wdata_r;
      reg uncache_r;
      reg [1:0] size_r;
      //�������ݵ�buffer������Ǵ�AXI����
      reg [31:0] return_data;
      reg return_data_valid;
      //AXI�������ݵļ�������һ��4B����Ҫ����4�Σ�������ʱ��
      reg [2:0] AXI_r_counter;
      always @(posedge clk) 
      begin
          if (!resetn) begin 
              AXI_r_counter <= 3'b0;
          end 
          else if (ret_valid)//������һ��
              AXI_r_counter <= AXI_r_counter + 1'd1;
          else if (main_state == REPLACE && rd_rdy && uncache_r)
              AXI_r_counter <= offset_r[3:2];
          else if (main_state == REPLACE && rd_rdy && !uncache_r)//�����ڶ�����Ҫ��cache��
              AXI_r_counter <= 3'd0;
      end
      
      
      //����buffer״̬ת��
      always @(posedge clk) begin
          if (!resetn) begin
              op_r <= 0;
              index_r <= 0;
              tag_r <= 0;
              offset_r <= 0;
              wstrb_r <= 0;
              wdata_r <= 0;
              uncache_r <= 0;
              size_r <= 0;
          end  //���ֿ��ܣ�IDLE״̬���Ҳ���дHit��ͻ��LOOKUP״̬�������ˣ��Ҳ���ͻ��
          else if ((main_state == IDLE && valid && !conflict) || (main_state == LOOKUP && cache_hit && valid && !conflict)) begin
              op_r <= op;
              index_r <= index;
              tag_r <= tag;
              offset_r <= offset;
              wstrb_r <= wstrb;
              wdata_r <= wdata;
              uncache_r <= uncache;
              size_r <= size;
          end
      end
      //����buffer״̬ת�������buffer���ص���LOAD���صĽ�����Ƕ�
      always@(posedge clk) begin
          if (!resetn) 
              return_data_valid <= 1'b0;
          else 
          begin
              return_data_valid <= (main_state == REFILL && op_r == 1'b0 && ret_valid == 1'b1 && AXI_r_counter == offset_r[3:2]);//4��1��������ĵģ�
          end
          return_data <= ret_data;//����������
      end
      
      reg wr_req_r;
      //α����滻��2·��������
      //LFSR
      reg counter;
      always @(posedge clk) begin
          if (!resetn) 
              counter <= 0;
          else if (counter == 0) 
              counter <= 1;
          else if (counter == 1) 
              counter <= 0;
      end
      //Miss Buffer
      reg replace_way;//�滻��һ·�����ݼ�����������
      always @(posedge clk) 
      begin
          if (!resetn) begin 
              replace_way <= 0;
          end
          else if (main_state == LOOKUP && !cache_hit) begin
              replace_way  <= counter;
          end
      end
      //д����buffer��״̬ת��
      always @(posedge clk) 
      begin
          if (!resetn) begin
              write_buffer_way <= 0;
              write_buffer_bank <= 0;
              write_buffer_index <= 0;
              write_buffer_wstrb <= 0;
              write_buffer_wdata <= 0;
          end
          else if (write_hit) 
          begin//д�����ˣ�
              write_buffer_way <= way_hit[0] ? 0 : 1;
              write_buffer_bank <= offset_r[3:2]; //������һbank
              write_buffer_index <= index_r;   //����
              write_buffer_wstrb <= wstrb_r;   //�ֽ�ʹ��
              write_buffer_wdata <= wdata_r;   //����
          end
      end
      
      
      assign replace_way_dirty = replace_way ? D_regfile[1][index_r] : D_regfile[0][index_r];
      assign replace_way_valid = replace_way ? way_v[1] : way_v[0];
      //��cache��ļ��ؽ��
      assign load_res = (way_hit[0] && main_state == LOOKUP) ? way_load_word[0] :
                        (way_hit[1] && main_state == LOOKUP) ? way_load_word[1] :
                                                                     return_data;//�������У��������߸�������
      assign rdata = load_res;
      //д״̬����״̬ת����
      assign cache_hit = (way_hit[0]||way_hit[1])&&!uncache_r;//��һ·���м��ɣ�ͬʱ����uncache
      assign write_hit = (main_state== LOOKUP && op_r == 1 && cache_hit);
      assign write_next_state[0] = (write_state[0] && !write_hit)//IDLE,û����
                                    ||(write_state[1] && !write_hit);//WRITE��û����  
      assign write_next_state[1] = (write_state[0] && write_hit)
                                    ||(write_state[1] && write_hit);  
      assign write_next_state[4:2] = 3'b0;
      
      //��״̬����״̬ת����
      assign next_state[0] = (main_state[0] && (!valid || valid && conflict))//IDLE->IDLE
                            ||(main_state[1] && (cache_hit && (!valid || valid && conflict)))//LOOKUP->IDLE
                            ||(main_state[4] && ((ret_valid == 1 && ret_last == 1)||(uncache_r && op_r == `STORE)));//REFILL->IDLE,ҪôAXI������Ҫô��uncache��д
      assign next_state[1] = (main_state[0] && (valid && !conflict))//IDLE->LOOKUP
                            ||(main_state[1] && (cache_hit && valid && !conflict));//LOOKUP->LOOKUP
      assign next_state[2] = (main_state[1] && (!cache_hit))//LOOKUP->MISS                                                                               
                            ||(main_state[2] && ((uncache_r && op_r == `STORE && !wr_rdy)|| (!uncache_r && replace_way_dirty && replace_way_valid && !wr_rdy)));//MISS->MISS.uncacheд���ڵȣ�cache�滻���ڵ�
      assign next_state[3] = (main_state[2] && (wr_rdy || (!(replace_way_dirty && replace_way_valid) && !uncache_r) || (uncache_r && op_r == `READ))) //MISS->REPLACE.�����ˣ�����uncache��������cache�����滻
                            ||(main_state[3] && (!rd_rdy && !(uncache_r && op_r == `STORE)));//REPLACE->REPLACE �������ڵȣ�uncacheд����Ҫ��
      assign next_state[4] = (main_state[3] && (rd_rdy || (uncache_r && op_r == `STORE)))//REPLACE->REFILL,�����ˣ�����uncacheд
                            ||(main_state[4] && (!(ret_valid == 1 && ret_last == 1) && !(uncache_r && op_r == `STORE)));//REFILL->REFILL������uncacheд�����ڵ�AXI�������һ��������
      
      //Uncache
      assign uncache_write_data = {96'b0, wdata_r};
      assign uncache_store = uncache_r && (op_r == 1'b1);
      //�滻������
      assign replace_data = uncache_r ? uncache_write_data : 
                            replace_way ? way_data[1] : way_data[0];//·������128λ��
                            
      //8��bank_RAM������ź�
      wire [3:0]  db_wen   [1:0][3:0];//2·4��
      wire [ 7:0] db_addr  [1:0][3:0];
      wire [31:0] db_rdata [1:0][3:0];
      wire [31:0] db_wdata [1:0][3:0];
      wire [31:0] data_w;
      wire [31:0] mask_w;
      
      //TAGV ram
      wire [ 7:0] tv_addr  [1:0];//����
      wire [20:0] tv_rdata [1:0];
      wire [ 3:0] tv_wen   [1:0];
      wire [20:0] tv_wdata [1:0];
       
      generate 
        for(way=0;way<2;way=way+1)
        begin
            for(bank=0;bank<4;bank=bank+1)
            begin                           // дbuffer��·���鶼��Ӧ�ϣ������ֽ�дʹ��   
                assign db_wen[way][bank] = 
                  {4{write_state == WRITE & write_buffer_way == way & write_buffer_bank == bank}} & write_buffer_wstrb | //дbuffer�ṩ
                  {4{main_state == REFILL & replace_way == way & AXI_r_counter == bank & ret_valid}} & {4{!uncache_r}} ; //cache����������������д�룬ָ��Ϳ�д
                assign db_addr[way][bank] =
                  {8{main_state == IDLE && write_state == WRITE && write_buffer_bank != bank}} & index | // cached write dose not write bank0, then use index to lookup
                  {8{main_state == IDLE && write_state != WRITE}} & index | // no cached write, use index to lookup
                  {8{main_state == LOOKUP && cache_hit && !conflict && op == `READ && valid}} & (write_state == WRITE && write_buffer_bank == bank ? write_buffer_index : index) | // cache hit when lookup, use index to lookup next req
                  {8{main_state == MISS}} & index_r | // come to miss, use index_r to get write data
                  {8{write_state == WRITE && write_buffer_bank == bank}} & write_buffer_index | // cached write bank0, use buffered index
                  {8{main_state == REPLACE || main_state == REFILL || main_state == MISS}} & index_r; // wait for handshake after cache miss, no need for lookup
                assign db_wdata[way][bank] = (main_state == REFILL) ? (AXI_r_counter == offset_r[3:2] && op_r == `STORE ? ((wdata_r & mask_w) | (ret_data & ~mask_w)) : ret_data): write_buffer_wdata;//д����Ҫ���ϣ������д��������Ҫ��AXI�������ݽ�������
                Data_Bank_Ram Data_Bank_Ram_Way_Bank(
                  .clka(clk),
                  .addra(db_addr [way][bank]),
                  .dina (db_wdata[way][bank]),
                  .douta(db_rdata[way][bank]),
                  .wea  (db_wen  [way][bank])
                );
            end
            assign way_hit[way] = !uncache_r && way_v[way] && (way_tag[way] == tag_r);//Tag��ȣ�V��Ч
            assign way_load_word[way] = way_data[way][offset_r[3:2]*32 +: 32];
            assign way_tag[way] = tv_rdata[way][20:1];//Tag
            assign way_v[way] = tv_rdata[way][0];
            assign way_data[way] = {db_rdata[way][3], db_rdata[way][2], db_rdata[way][1], db_rdata[way][0]};
            TAGV_Ram TAGV_Ram_Way(
                .clka (clk),
                .addra(tv_addr [way]),
                .dina (tv_wdata[way]),
                .douta(tv_rdata[way]),
                .wea  (tv_wen  [way])
              );
            assign tv_wdata[way] = {tag_r, 1'b1};//��ǩ����Ч
            assign tv_wen[way] = (main_state == REFILL && replace_way == way && !uncache_r);//�����ʱ���д
            assign tv_addr[way] = ((main_state == REFILL) || (main_state == LOOKUP && !cache_hit) || (main_state == MISS)) ? index_r : index;
            // D regfile
              assign d_we[way] = (write_state == WRITE && write_buffer_way == way) |
                                 (main_state == REFILL && op_r == `STORE && !uncache_r && replace_way == way);
              always @(posedge clk) begin
                  if (!resetn) begin
                      D_regfile[way] <= 256'd0;
                  end
                  else if (d_we[way]) begin
                      D_regfile[way][d_addr] = d_w;
                  end
              end
         end
      endgenerate
      
     //d regfile ����״̬�»�дcache�壬һ����дbuffer�ڸ��ģ�һ����REFILL������
        assign d_w = 1'b1;
        assign d_addr = {8{write_state == WRITE}} & write_buffer_index
                    | {8{main_state == REFILL}} & index_r;
        assign mask_w = {{8{wstrb_r[3]}}, {8{wstrb_r[2]}}, {8{wstrb_r[1]}}, {8{wstrb_r[0]}}};
        assign data_w = (main_state == REFILL) ? (AXI_r_counter == offset_r[3:2] && op_r == `STORE ? ((wdata_r & mask_w) | (ret_data & ~mask_w)) : ret_data) : write_buffer_wdata;//TODO
        assign wr_data = replace_data;
     //��ַok
     assign addr_ok = main_state == IDLE && !conflict || main_state == LOOKUP && cache_hit && !conflict; 
     
     assign data_ok = (main_state == LOOKUP && (cache_hit || op_r == `STORE) )//STORE���У�ֱ��dataok�ͺá�����͵õȷ���buffer
                        ||return_data_valid;
     assign rd_req = main_state == REPLACE && !(uncache_r && op_r == `STORE);//��cache����store�Ų����������4
     //д��������cache��ʱ��+�滻·������Ч������cache
     assign wr_req = wr_req_r && (uncache_r && op_r == `STORE || replace_way_dirty && replace_way_valid && !uncache_r);
     always@ (posedge clk) begin
          if (!resetn) begin
              wr_req_r <= 1'b0;
          end
          else if (main_state == MISS && wr_rdy) begin
              wr_req_r <= 1'b1;
          end
          else if (wr_rdy) begin
              wr_req_r <= 1'b0;
          end
     end
      assign rd_type = size;
      assign rd_addr = uncache_r ? {tag_r, index_r, offset_r} : {tag_r, index_r, 4'b0};
      assign wr_type = 3'b100;
      assign wr_addr = uncache_r ? {tag_r, index_r, offset_r} : {(replace_way ? way_tag[1] : way_tag[0]), index_r, 4'b0};
      assign wr_wstrb = wstrb_r;

endmodule
