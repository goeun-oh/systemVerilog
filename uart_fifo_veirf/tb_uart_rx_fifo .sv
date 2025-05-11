`timescale 1ns / 1ps

class transaction;
    //random logic
    rand logic       operator;
    rand logic [7:0] PWDATA;
    rand logic       PWRITE;
    //input sig
    logic      [3:0] PADDR;
    logic            PENABLE;
    logic            PSEL;
    logic            rx;
    //output signal
    logic      [7:0] PRDATA;
    logic            PREADY;
    logic            tx;
    logic            rx_done;

    constraint operator_ctrl {operator == 0;}  // 오직 read만 허용

    task display(string name);
        $display(
            "[%s] PADDR=%h, PWDATA=%h, PWRITE=%h, PENABLE=%h, PSEL=%h, PRDATA=%h, PREADY=%h, rx=%h, tx=%h",
            name, PADDR, PWDATA, PWRITE, PENABLE, PSEL, PRDATA, PREADY, rx, tx);
    endtask

endclass


interface Uart_fifo_Intf (
    input logic clk,
    input logic reset
);
    logic [3:0] PADDR;
    logic [7:0] PWDATA;
    logic       PWRITE;
    logic       PENABLE;
    logic       PSEL;
    logic [7:0] PRDATA;
    logic       PREADY;
    logic       rx;
    logic       tx;
    logic       rx_done;

    clocking drv_cb @(posedge clk);
        default input #1 output #1;
        output PADDR;
        output PWDATA;
        output PWRITE;
        output PENABLE;
        output PSEL;
        output rx;
        input PREADY;
        input PRDATA;
        input tx;
        input rx_done;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1 output #1;
        input PADDR;
        input PWDATA;
        input PWRITE;
        input PENABLE;
        input PSEL;
        input rx;
        input PREADY;
        input PRDATA;
        input tx;
        input rx_done;
    endclocking

    modport drv_mport(clocking drv_cb, input reset);
    modport mon_mport(clocking mon_cb, input reset);
endinterface

class generator;
    mailbox #(transaction) Gen2Drv_mbox;
    event gen_next_event;

    function new(mailbox#(transaction) Gen2Drv_mbox, event gen_next_event);
        this.Gen2Drv_mbox   = Gen2Drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction

    task run(int repeat_counter);
        transaction uart_tr;

        repeat (repeat_counter) begin
            uart_tr = new();
            if (!uart_tr.randomize()) $error("Randomization fail!");
            uart_tr.display("GEN");
            Gen2Drv_mbox.put(uart_tr);
            @(gen_next_event);
        end
    endtask
endclass

class driver;
    virtual Uart_fifo_Intf uart_intf;
    mailbox #(transaction) Gen2Drv_mbox;
    transaction uart_tr;
    event mon_next_event;

    function new(mailbox#(transaction) Gen2Drv_mbox,
                 virtual Uart_fifo_Intf.drv_mport uart_intf,
                 event mon_next_event);
        this.Gen2Drv_mbox = Gen2Drv_mbox;
        this.uart_intf    = uart_intf;
        this.mon_next_event = mon_next_event;
    endfunction


    task read();  //RX fifo 값 read?
        //setup
        repeat (3) @(uart_intf.drv_cb);
        uart_intf.drv_cb.PADDR <= 4'hC;
        uart_intf.drv_cb.PWDATA <= uart_tr.PWDATA;
        uart_intf.drv_cb.PWRITE <= 1'b0;
        uart_intf.drv_cb.PENABLE <= 1'b0;
        uart_intf.drv_cb.PSEL <= 1'b1;

        //access
        @(uart_intf.drv_cb);
//        @(uart_intf.drv_cb);
        uart_intf.drv_cb.PADDR <= 4'hC;
        uart_intf.drv_cb.PWDATA <= uart_tr.PWDATA;
        uart_intf.drv_cb.PWRITE <= 1'b0;
        uart_intf.drv_cb.PENABLE <= 1'b1;
        uart_intf.drv_cb.PSEL <= 1'b1;
        wait (uart_intf.drv_cb.PREADY);
        uart_intf.drv_cb.PENABLE <= 1'b0;
        uart_intf.drv_cb.PSEL <= 1'b0;
    endtask  //read


    task uart_send_byte(input [7:0] rbyte);
        uart_intf.drv_cb.rx <= 0;  // Start bit
        repeat (10417) @(uart_intf.drv_cb);  // 1 baud @ 9600 bps

        for (int i = 0; i < 8; i++) begin
            uart_intf.drv_cb.rx <= rbyte[i];
            repeat (10417) @(uart_intf.drv_cb);
        end

        uart_intf.drv_cb.rx <= 1;  // Stop bit
        repeat (10417) @(uart_intf.drv_cb);
    endtask

    task run();
        forever begin
            Gen2Drv_mbox.get(uart_tr);
            // UART 수신부로 byte 전송 (즉, rx 핀에 전송)
            uart_send_byte(uart_tr.PWDATA);
            // 약간의 delay를 주고
            repeat (10) @(uart_intf.drv_cb);
            // APB read 수행
            read();
            uart_tr.display("DRV");
            -> mon_next_event;
        end
    endtask
endclass

class monitor;
    mailbox #(transaction) Mon2SCB_mbox;
    virtual Uart_fifo_Intf.mon_mport uart_intf;
    event mon_next_event;



    function new(mailbox#(transaction) Mon2SCB_mbox,
                 virtual Uart_fifo_Intf.mon_mport uart_intf,
                 event mon_next_event);
        this.Mon2SCB_mbox = Mon2SCB_mbox;
        this.uart_intf = uart_intf;
        this.mon_next_event = mon_next_event;
    endfunction

    task run();
        transaction uart_tr;
        forever begin
            @(mon_next_event);
            //@(posedge uart_intf.mon_cb.PREADY);
            wait(uart_intf.mon_cb.PREADY == 1'b1 && uart_intf.mon_cb.PENABLE == 1'b1 && uart_intf.mon_cb.PSEL == 1'b1);

            uart_tr         = new();
            uart_tr.PADDR   = uart_intf.mon_cb.PADDR;
            uart_tr.PWDATA  = uart_intf.mon_cb.PWDATA;
            uart_tr.PWRITE  = uart_intf.mon_cb.PWRITE;
            uart_tr.PENABLE = uart_intf.mon_cb.PENABLE;
            uart_tr.PSEL    = uart_intf.mon_cb.PSEL;
            uart_tr.PRDATA  = uart_intf.mon_cb.PRDATA;
            uart_tr.PREADY  = uart_intf.mon_cb.PREADY;
            uart_tr.rx      = uart_intf.mon_cb.rx;
            uart_tr.tx      = uart_intf.mon_cb.tx;
            Mon2SCB_mbox.put(uart_tr);
            uart_tr.display("MON");
        end
    endtask
endclass

class scoreboard;
    mailbox #(transaction) Mon2SCB_mbox;
    transaction uart_tr;
    event gen_next_event;

    logic [7:0] scb_fifo[$];
    logic [7:0] pop_data;

    function new(mailbox#(transaction) Mon2SCB_mbox, event gen_next_event);
        this.Mon2SCB_mbox   = Mon2SCB_mbox;
        this.gen_next_event = gen_next_event;
    endfunction

    task run();
        forever begin
            Mon2SCB_mbox.get(uart_tr);
            uart_tr.display("SCB");




            if (uart_tr.PRDATA == uart_tr.PWDATA) begin
                $display("[SCB] PASS: Expected = %h ==  Received = %h",
                         uart_tr.PWDATA, uart_tr.PRDATA);
            end else begin
                $display("[SCB] FAIL: Expected = %h != Received = %h",
                         uart_tr.PWDATA, uart_tr.PRDATA);
            end
            ->gen_next_event;
        end
    endtask

endclass
class envirnment;
    mailbox #(transaction) Gen2Drv_mbox;
    mailbox #(transaction) Mon2SCB_mbox;
    virtual Uart_fifo_Intf uart_intf;
    generator uart_gen;
    driver uart_drv;
    monitor uart_mon;
    scoreboard uart_scb;

    event gen_next_event;
    event mon_next_event;

    function new(virtual Uart_fifo_Intf uart_intf);
        Gen2Drv_mbox = new();
        Mon2SCB_mbox = new();
        uart_gen = new(Gen2Drv_mbox, gen_next_event);
        uart_drv = new(Gen2Drv_mbox, uart_intf, mon_next_event);
        uart_mon = new(Mon2SCB_mbox, uart_intf, mon_next_event);
        uart_scb = new(Mon2SCB_mbox, gen_next_event);
    endfunction

    task run(int count);
        fork
            uart_gen.run(count);
            uart_drv.run();
            uart_mon.run();
            uart_scb.run();
        join_any
    endtask
endclass

module tb_uart_tx_fifo ();
    logic clk, reset;
    Uart_fifo_Intf uart_intf (
        clk,
        reset
    );

    envirnment uart_env;
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        uart_intf.rx = 1'b1;

        repeat (5) @(posedge clk);
        reset = 0;
        uart_env = new(uart_intf);
        uart_env.run(5);
        #1_000_000_000;  // 1ms 정도는 줘야 RX 한 바이트라도 끝남

        #30 $display("finish!");
        $finish;
    end


    uart_Periph DUT (
        .PCLK   (clk),
        .PRESET (reset),
        .PADDR  (uart_intf.PADDR),
        .PWDATA (uart_intf.PWDATA),
        .PWRITE (uart_intf.PWRITE),
        .PENABLE(uart_intf.PENABLE),
        .PSEL   (uart_intf.PSEL),
        .PRDATA (uart_intf.PRDATA),
        .PREADY (uart_intf.PREADY),
        .rx     (uart_intf.rx),
        .tx     (uart_intf.tx),
        .rx_done (uart_intf.rx_done)
    );
endmodule
