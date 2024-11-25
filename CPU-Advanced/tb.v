`timescale 1ns / 1ps
module tb;

    // Inputs
    reg clk;
    reg resetn;
   
    machine uut (
        .clk(clk), 
        .resetn(resetn)
    );

    initial begin
        // Initialize Inputs
        clk = 0;
        resetn = 0;

        // Wait 100 ns for global reset to finish
        #100;
      resetn = 1;
        // Add stimulus here
    end
   always #1 clk=~clk;
endmodule

