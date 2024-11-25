//定义一些宏 
`ifndef CPU_H
    `define CPU_H

    `define JBR_BUS_WD           34
    `define IF_TO_ID_BUS_WD      98
    `define ID_TO_EXE_BUS_WD     205
    `define EXE_TO_MEM_BUS_WD    192
    `define MEM_TO_WB_BUS_WD     158
    `define BYPASS_BUS_WD        38 
    `define EXC_BUS_WD           33

    `define EX_INT              5'h00
    `define EX_ADEL             5'h04
    `define EX_ADES             5'h05
    `define EX_SYS              5'h08
    `define EX_BP               5'h09
    `define EX_RI               5'h0a
    `define EX_OV               5'h0c
    `define EX_NO               5'h1f

`endif