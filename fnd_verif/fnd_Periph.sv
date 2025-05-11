`timescale 1ns / 1ps

module fnd_Periph (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // inport signals
    output logic [ 7:0] fndFont,
    output logic [ 3:0] fndComm
);

    logic FCR;
    logic [7:0] FMR;
    logic [7:0] FDR;

    fnd_SlaveIntf U_fnd_Intf (.*);
    fndController U_fnd (.*);
endmodule

module fnd_SlaveIntf (
    // global signal
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // internal signals
    output logic [ 7:0] FCR,
    output logic [ 7:0] FMR,
    output logic [ 7:0] FDR
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2;  //, slv_reg3;


    assign FCR = slv_reg0[0];
    assign FMR = slv_reg1[3:0];
    assign FDR = slv_reg2[3:0];


    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            slv_reg2 <= 0;
            // slv_reg3 <= 0;
        end else begin
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE) begin
                    case (PADDR[3:2])
                        2'd0: slv_reg0 <= PWDATA;
                        2'd1: slv_reg1 <= PWDATA;
                        2'd2: slv_reg2 <= PWDATA;
                        // 2'd3: slv_reg3 <= PWDATA;
                    endcase
                end else begin
                    PRDATA <= 32'bx;
                    case (PADDR[3:2])
                        2'd0: PRDATA <= slv_reg0;
                        2'd1: PRDATA <= slv_reg1;
                        2'd2: PRDATA <= slv_reg2;
                        // 2'd3: PRDATA <= slv_reg3;
                    endcase
                end
            end else begin
                PREADY <= 1'b0;
            end
        end
    end

endmodule

module fndController (
    input  logic       FCR,
    input  logic [3:0] FMR,
    input  logic [3:0] FDR,
    output logic [3:0] fndComm,
    output logic [7:0] fndFont
);

    assign fndComm = FCR ? ~FMR: 4'b1111;

    BCDtoSEG U_BCD_to_SEG(
        .bcd(FDR),
        .seg(fndFont)
    ); 


endmodule




module BCDtoSEG(
    input logic [3:0] bcd,
    output logic [7:0] seg
    );

    always @(bcd) begin
        case(bcd)
        4'h0: seg= 8'hc0;
        4'h1: seg= 8'hf9;
        4'h2: seg = 8'ha4;
        4'h3: seg=8'hb0;
        4'h4: seg=8'h99;
        4'h5: seg=8'h92;
        4'h6: seg=8'h82;
        4'h7: seg=8'hf8;
        4'h8: seg=8'h80;
        4'h9: seg=8'h90;
        4'ha: seg=8'h88;
        4'hb: seg=8'h83;
        4'hc: seg=8'hc6;
        4'hd: seg=8'ha1;
        4'he: seg=8'h86;
        4'hf: seg=8'h8e;

        default:seg=8'hff;
        endcase
    end
endmodule
