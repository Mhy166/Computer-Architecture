`timescale 1ns / 1ps
`include "CPU.vh"
module va2pa (
    input   [31:0]  vaddr,
    output  [31:0]  paddr,
    output          tlb_refill,
    output          tlb_invalid,
    output          tlb_modified,
    
    input           inst_tlbp,
    input   [31:0]  cp0_entryhi,

    output  [18:0]  tlb_vpn2,
    output          tlb_odd_page,
    output  [ 7:0]  tlb_asid,
    input           tlb_found,
    input   [19:0]  tlb_pfn,
    input   [ 2:0]  tlb_c,
    input           tlb_d,
    input           tlb_v,
    input           v2p_invalid
);

wire unmapped;
assign unmapped = !vaddr[31];

assign tlb_vpn2 = (inst_tlbp)? cp0_entryhi[31:13] : vaddr[31:13];
assign tlb_odd_page = vaddr[12];
assign tlb_asid = cp0_entryhi[7:0];

assign paddr = (unmapped)? vaddr : {tlb_pfn, vaddr[11:0]};
// assign paddr = vaddr;

assign tlb_refill   = !v2p_invalid&&!unmapped && !tlb_found;//Р§Эт
assign tlb_invalid  = !v2p_invalid&&!unmapped && tlb_found && !tlb_v;
assign tlb_modified = !v2p_invalid&&!unmapped && tlb_found && tlb_v && !tlb_d;

endmodule