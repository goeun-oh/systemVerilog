`timescale 1ns/1ps


module tb();
    logic clk;
    logic reset;
    logic [7:0] fndFont;
    logic [3:0] fndComm;

    initial begin
        clk =0; reset=0;
        #10
        reset=1;
        @(posedge clk);
        reset=0;

        @(posedge clk);
    end

    always #5 clk= ~clk;
    MCU dut(.*);
endmodule  