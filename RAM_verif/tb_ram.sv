`timescale 1ns / 1ps
//logic: 0,1,z,x
//bit : 0,1

// interface는 선만 구비해놓은 것
// 어디에 끼워넣냐에 따라 input이 될 수도 output이 될 수도 있다.
// interface는 new가 없음
interface ram_intf(input bit clk);
    logic [4:0] addr;
    logic [7:0] wData;
    logic       we;
    logic [7:0] rData;

    //clocking block, timing을 맞춰주는 기능을 한다.
    //testbench 기준으로 생각하기
    clocking cb @(posedge clk);
        default input #1 output #1; //clk edge를 기준으로 default로 delay를 준다.
        output addr, wData, we; //dut의 input
        input rData;
    endclocking

endinterface //ram_intf

class transaction;
    rand logic [4:0] addr;
    rand logic [7:0] wData;
    rand logic       we;
    logic [7:0] rData;

    task display(string name);
        $display("[%S] addr=%h, wData=%h, we=%d, rData=%h", name, addr, wData, we, rData);
    endtask
endclass //transaction

class generator;
    mailbox #(transaction) GenToDriver_mbox;

    function new(mailbox #(transaction) GenToDriver_mbox);
        this.GenToDriver_mbox=GenToDriver_mbox;        
    endfunction //new()

    task run(int repeat_counter);
        transaction ram_tr;
        repeat (repeat_counter) begin
            ram_tr = new();
            if (!ram_tr.randomize()) $error("Randomization failed!");
            ram_tr.display("GEN");
            GenToDriver_mbox.put(ram_tr);
            #20;
        end
    endtask
endclass //generator extends superClass

class driver;
    virtual ram_intf ram_if;
    mailbox #(transaction) GenToDriver_mbox;

    function new(mailbox #(transaction) GenToDriver_mbox, virtual ram_intf ram_if);
        this.GenToDriver_mbox = GenToDriver_mbox;
        this.ram_if = ram_if;
    endfunction //new()

    task run();
        transaction ram_tr;
        forever begin //clocking block에 값 넣을 때 non block 형태로 줘야됨
            @(ram_if.cb);
            GenToDriver_mbox.get(ram_tr); //mailbox에 값이 없으면 여기서 계속 대기, 값이 생기면 다음라인 실행
            ram_if.cb.addr <= ram_tr.addr;
            ram_if.cb.wData <= ram_tr.wData;
            ram_if.cb.we <= ram_tr.we;
            ram_tr.display("DRV");
            @(ram_if.cb);
            ram_if.cb.we<= 1'b0; //clk이 발생한 이후 we를 1'b0으로 바꿔줘서 read값을 interface에 던짐
            //왼쪽 hw, 오른쪽 sw
        end
    endtask
endclass //driver

class monitor;
    virtual ram_intf ram_if;
    mailbox #(transaction) MonToSCB_mbox;
    
    function new(mailbox #(transaction) MonToSCB_mbox, virtual ram_intf ram_if);
        this.MonToSCB_mbox= MonToSCB_mbox;
        this.ram_if=ram_if;
    endfunction //new()

    task run ();
        transaction ram_tr;
        forever begin
            @(ram_if.cb);
            ram_tr = new();
            ram_tr.addr = ram_if.addr;
            ram_tr.wData = ram_if.wData;
            ram_tr.we = ram_if.we;
            ram_tr.rData = ram_if.rData;
            ram_tr.display("MON"); //왼쪽 sw, 오른쪽 hw, sw는 non-blocking이라는 개념이 없다.
            MonToSCB_mbox.put(ram_tr); //hw를 sw로 넘겨줌
        end
    endtask //run

endclass //monitor


class scoreboard;
    mailbox #(transaction) MonToSCB_mbox;
    logic [7:0] ref_model [0:2**5-1];

    function new(mailbox #(transaction) MonToSCB_mbox);
        this.MonToSCB_mbox=MonToSCB_mbox;
        foreach (ref_model[i]) ref_model[i] =0;
    endfunction

    task run();
        transaction ram_tr;
        forever begin
            MonToSCB_mbox.get(ram_tr);
            ram_tr.display("SCB");
            if (ram_tr.we) begin
                ref_model[ram_tr.addr] = ram_tr.rData;
            end else begin
                if(ref_model[ram_tr.addr] === ram_tr.rData) begin
                    $display("PASS! Matched Data! ref_model: %h == rData: %h",
                     ref_model[ram_tr.addr], ram_tr.rData);
                end else begin
                    $display("FAIL! Dismatched Data! ref_model: %h != rData: %h",
                     ref_model[ram_tr.addr], ram_tr.rData);
                end
            end
        end
    endtask //automatic
endclass


class envirnment;
    mailbox #(transaction) GenToDriver_mbox;
    mailbox #(transaction) MonToSCB_mbox;
    generator ram_gen;
    driver ram_drv;
    monitor ram_mon;
    scoreboard ram_scb;

    function new(virtual ram_intf ram_if);
        GenToDriver_mbox = new();
        MonToSCB_mbox = new();
        ram_gen = new(GenToDriver_mbox);
        ram_drv = new(GenToDriver_mbox, ram_if);
        ram_mon = new(MonToSCB_mbox, ram_if);
        ram_scb = new(MonToSCB_mbox);
    endfunction

    task run(int count);
        fork
            ram_gen.run(count);
            ram_drv.run();
            ram_mon.run();
            ram_scb.run();        
        join_any
    endtask
endclass

module tb_ram();
    bit clk;

    envirnment env;
    ram_intf ram_if(clk);

    ram DUT(.intf(ram_if));

    always #5 clk=~clk;

    initial begin
        clk =0;
        env =new(ram_if);
        env.run(10);
        #50;
        $finish;
    end
endmodule
