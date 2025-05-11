`timescale 1ns / 1ps

class transaction;
    rand logic operator;
    rand logic we;
    rand logic re;
    rand logic [7:0] wdata;
    logic [7:0] rdata;
    logic empty;
    logic full;

    constraint operator_ctrl {operator dist {1:/80, 0:/20};}

    task display(string name);
        $display("[%s] oper=%h, we=%h, re=%h, wdata=%h, rdata=%h, empty=%h, full=%h",
                 name, operator, we, re, wdata, rdata, empty, full);
    endtask  //display
endclass

interface fifo_interface (
    input logic clk,
    input logic reset
);
    logic       we;
    logic       re;
    logic [7:0] wdata;
    logic [7:0] rdata;
    logic       empty;
    logic       full;

    clocking drv_cb @(posedge clk);
        default input #1 output #1;
        output we;
        output re;
        output wdata;
        input empty;
        input full;
        input rdata;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1;
        input we;
        input re;
        input wdata;
        input empty;
        input full;
        input rdata;
    endclocking

    modport drv_mport(clocking drv_cb, input reset);
    modport mon_mport(clocking mon_cb, input reset);
endinterface  //fifo_intf

class generator;
    mailbox #(transaction) Gen2Drv_mbox;
    event gen_next_event;

    function new(mailbox#(transaction) Gen2Drv_mbox, event gen_next_event);
        this.Gen2Drv_mbox   = Gen2Drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction

    task run(int repeat_count);
        transaction fifo_tr;
        repeat (repeat_count) begin
            fifo_tr = new();
            if (!fifo_tr.randomize()) $error("Randomization fail!");
            fifo_tr.display("GEN");
            Gen2Drv_mbox.put(fifo_tr);
            @(gen_next_event);
        end
    endtask  //run

endclass

class driver;
    mailbox #(transaction) Gen2Drv_mbox;
    virtual fifo_interface.drv_mport fifo_intf;
    transaction fifo_tr;

    function new(mailbox#(transaction) Gen2Drv_mbox,
                 virtual fifo_interface.drv_mport fifo_intf);
        this.Gen2Drv_mbox = Gen2Drv_mbox;
        this.fifo_intf    = fifo_intf;
    endfunction

    task write ();
        @(fifo_intf.drv_cb);
        fifo_intf.drv_cb.wdata <= fifo_tr.wdata;
        fifo_intf.drv_cb.re <=1'b0;
        fifo_intf.drv_cb.we <= 1'b1;
        @(fifo_intf.drv_cb);
        fifo_intf.drv_cb.we <=1'b0;
    endtask //write

    task read ();
        @(fifo_intf.drv_cb);
        fifo_intf.drv_cb.re <=1'b1;
        fifo_intf.drv_cb.we <=1'b0;
        @(fifo_intf.drv_cb);
        fifo_intf.drv_cb.re <= 1'b0;
    endtask //read

    task run();
        forever begin
            Gen2Drv_mbox.get(fifo_tr);
            if (fifo_tr.operator) write();
            else read();
            fifo_tr.display("DRV");
        end
    endtask
endclass


class monitor;
    mailbox #(transaction) Mon2SCB_mbox;
    virtual fifo_interface.mon_mport fifo_intf;

    function new(mailbox#(transaction) Mon2SCB_mbox,
                 virtual fifo_interface.mon_mport fifo_intf);
        this.Mon2SCB_mbox = Mon2SCB_mbox;
        this.fifo_intf = fifo_intf;
    endfunction

    task run();
        transaction fifo_tr;
        forever begin
            @(fifo_intf.mon_cb);
            @(fifo_intf.mon_cb);
            fifo_tr       = new();
            fifo_tr.we    = fifo_intf.mon_cb.we;
            fifo_tr.re    = fifo_intf.mon_cb.re;
            fifo_tr.wdata = fifo_intf.mon_cb.wdata;
            fifo_tr.rdata = fifo_intf.mon_cb.rdata;
            fifo_tr.empty = fifo_intf.mon_cb.empty;
            fifo_tr.full  = fifo_intf.mon_cb.full;
            Mon2SCB_mbox.put(fifo_tr);
            fifo_tr.display("MON");
        end
    endtask
endclass

class scoreboard;
    mailbox #(transaction) Mon2SCB_mbox;
    transaction fifo_tr;
    event gen_next_event;

    logic [7:0] scb_fifo[$];  //동적 큐 선언
    logic [7:0] pop_data;

    function new(mailbox#(transaction) Mon2SCB_mbox, event gen_next_event);
        this.Mon2SCB_mbox   = Mon2SCB_mbox;
        this.gen_next_event = gen_next_event;
    endfunction

    task run();
        forever begin
            Mon2SCB_mbox.get(fifo_tr);
            fifo_tr.display("SCB");
            if (fifo_tr.we) begin
                if (!fifo_tr.full) begin
                    scb_fifo.push_back(
                        fifo_tr.wdata);  // 큐 맨 뒤에 값 추가
                    $display("[SCB] : Data Stored in queue : %h\n",
                             fifo_tr.wdata, scb_fifo);
                end else begin
                    $display("[SCB]: FIFO is full, %p\n", scb_fifo);
                end
            end
            if(fifo_tr.re) begin
                if(!fifo_tr.empty) begin
                    pop_data = scb_fifo.pop_front();
                    if(fifo_tr.rdata == pop_data) begin
                        $display("[SCB] data matched %h == %h\n", fifo_tr.rdata, pop_data);
                    end else begin
                        $display("[SCB] data dismatched %h != %h\n", fifo_tr.rdata, pop_data);
                    end
                end else begin
                    $display("[SCB] fifo is empty, %p\n", scb_fifo);
                end
            end
            ->gen_next_event;
        end
    endtask

endclass

class envirnment;
    mailbox #(transaction) Gen2Drv_mbox;
    mailbox #(transaction) Mon2SCB_mbox;
    generator fifo_gen;
    driver fifo_drv;
    event gen_next_event;

    monitor fifo_mon;
    scoreboard fifo_scb;

    function new(virtual fifo_interface fifo_intf);
        Gen2Drv_mbox = new();
        Mon2SCB_mbox = new();
        fifo_gen = new(Gen2Drv_mbox, gen_next_event);
        fifo_drv = new(Gen2Drv_mbox, fifo_intf);
        fifo_mon = new(Mon2SCB_mbox, fifo_intf);
        fifo_scb = new(Mon2SCB_mbox, gen_next_event);
    endfunction

    task run(int count);
        fork
            fifo_gen.run(count);
            fifo_drv.run();
            fifo_mon.run();
            fifo_scb.run();
        join_any
    endtask
endclass

module tb_fifo ();
    logic clk, reset;

    envirnment fifo_env;

    fifo_interface fifo_intf (
        clk,
        reset
    );

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        #10 reset = 0;
        @(posedge clk);
        fifo_env = new(fifo_intf);
        fifo_env.run(20);
        #30 $display("finish!");
        $finish;
    end

    fifo u_fifo (
        .clk  (clk),
        .reset(reset),
        .we   (fifo_intf.we),
        .re   (fifo_intf.re),
        .wdata(fifo_intf.wdata),
        .rdata(fifo_intf.rdata),
        .empty(fifo_intf.empty),
        .full (fifo_intf.full)
    );
endmodule
