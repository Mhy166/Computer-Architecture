`timescale 1ns / 1ps

module regfile(
    input             clk,
    input             wen,
    input      [4 :0] raddr1,
    input      [4 :0] raddr2,
    input      [4 :0] waddr,
    input      [31:0] wdata,
    output     [31:0] rdata1,
    output     [31:0] rdata2
    );
    reg [31:0] rf[31:0];
    always @(posedge clk)
    begin
        rf[0] <= 32'b0;
    end
    always @(posedge clk)
    begin
        if (wen && (waddr!=5'b0)) 
        begin
            rf[waddr] <= wdata;
        end
    end
     
    //¶Á¶Ë¿Ú1
    assign rdata1 = rf[raddr1];
    assign rdata2 = rf[raddr2];
    
endmodule
