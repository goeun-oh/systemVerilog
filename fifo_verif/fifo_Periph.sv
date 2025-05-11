`timescale 1ns / 1ps

module fifo_Periph (
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
    output logic        PREADY
);


    logic empty, full;
    logic we, re;
    logic [7:0] wdata, rdata;


    fifo_SlaveIntf U_fifo_Intf (
        .*,
        .FSR({full, empty}),
        .FWD(wdata),
        .FRD(rdata)
        );

    fifo U_fifo (
        .*,
        .clk  (PCLK),
        .reset(PRESET)
    );
endmodule

module fifo_SlaveIntf (
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
    input  logic [ 1:0] FSR,
    output logic [ 7:0] FWD,
    input  logic [ 7:0] FRD,
    output logic        we,
    output logic        re
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2;  //, slv_reg3;
    logic [31:0] slv_reg1_next;

    logic we_reg, we_next;
    logic re_reg, re_next;
    logic [31:0] PRDATA_reg, PRDATA_next;
    logic PREADY_reg, PREADY_next;

    assign we = we_reg;
    assign re = re_reg;

    typedef enum {
        IDLE,
        READ,
        WRITE
    } state_e;

    state_e state_reg, state_next;

    assign slv_reg0[1:0] = FSR;
    assign FWD = slv_reg1[7:0];
    assign slv_reg2[7:0] = FRD; 
    assign PRDATA = PRDATA_reg;
    assign PREADY = PREADY_reg;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0[31:2] <=0;
            slv_reg2[31:8] <=0;
            slv_reg1  <= 0;
            state_reg <= IDLE;
            we_reg    <= 0;
            re_reg    <= 0;
            PRDATA_reg <= 32'bx;
            PREADY_reg <= 1'b0;
        end else begin
            slv_reg1  <= slv_reg1_next;
            state_reg <= state_next;
            we_reg    <= we_next;
            re_reg    <= re_next;
            PRDATA_reg <= PRDATA_next;
            PREADY_reg <= PREADY_next;
        end
    end

    always_comb begin
        state_next = state_reg;
        slv_reg1_next = slv_reg1;
        we_next = we_reg;
        re_next = re_reg;
        PRDATA_next = PRDATA_reg;
        PREADY_next = PREADY_reg;

        case (state_reg)
            IDLE: begin
                PREADY_next = 1'b0;
                if (PSEL && PENABLE) begin
                    if (PWRITE) begin
                        state_next= WRITE;
                        we_next = 1'b1;
                        re_next = 1'b0;
                        PREADY_next = 1'b1;
                        case (PADDR[3:2])
                            2'd0: ;
                            2'd1: begin
                                slv_reg1_next = PWDATA;
                            end
                            2'd2: ;
                        endcase
                    end else begin
                        state_next= READ;
                        PREADY_next = 1'b1;
                        we_next = 1'b0;
                        case (PADDR[3:2])
                            2'd0: begin
                                PRDATA_next = slv_reg0;
                                re_next = 1'b0;
                            end
                            2'd1: begin
                                PRDATA_next = slv_reg1;
                                re_next = 1'b0;
                            end
                            2'd2: begin
                                PRDATA_next = slv_reg2;
                                re_next = 1'b1;
                            end
                        endcase
                    end
                end
            end

            READ: begin
                re_next = 1'b0;
                we_next = 1'b0;
                PREADY_next = 1'b0;
                state_next = IDLE; 
            end
            WRITE: begin
                we_next =1'b0;
                re_next = 1'b0;
                state_next = IDLE;
                PREADY_next = 1'b0;
            end
        endcase
    end
endmodule
