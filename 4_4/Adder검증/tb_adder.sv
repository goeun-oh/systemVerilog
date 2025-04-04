`timescale 1ns / 1ps

//interface: cable 묶음
interface adder_intf;
   // logic: wire, reg type이 합쳐진 데이터 형식
   logic [7:0] a;
   logic [7:0] b;
   logic [7:0] sum;
   logic carry;
endinterface //adder_intf

class transaction;
    // bit: 0과 1 만 가능, unkown, high-impedance가 존재 X
    // 따라서 더 심플하게 compile이 가능

    // rand: random한 값을 만들겠다는 뜻
    rand bit [7:0] a;
    rand bit [7:0] b;
endclass //transaction

// generator: transaction을 생성하는 클래스
// random transaction 을 만든 이후 mail box에 집어 넣음
// -> generator class가 mail box의 요소들도 알아야 한다.
class generator;
    transaction tr; //실체화

    mailbox #(transaction) gen2drv_mbox; //generator -> driver 로 나가는 mailbox
    // #: datatype 정의

    function new(mailbox #(transaction) gen2drv_mbox);
        this.gen2drv_mbox = gen2drv_mbox;
    endfunction //new()

    task run (int run_count);
        //반복하겠다.
        repeat (run_count) begin
            tr = new(); //transaction 생성
            tr.randomize(); //random 화
            gen2drv_mbox.put(tr); //mail box에 넣음
            #10;
        end
    endtask //run
endclass //generator

class driver;
    transaction tr;
    virtual adder_intf adder_if;
    mailbox #(transaction) gen2drv_mbox;

    function new(mailbox#(transaction) gen2drv_mbox, virtual adder_intf adder_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.adder_if = adder_if;
    endfunction

    task reset ();
        adder_if.a=0;
        adder_if.b=0;

    endtask //reset

    task run ();
        forever begin
            gen2drv_mbox.get(tr); //get해서 tr에 넣어라
            adder_if.a=tr.a;
            adder_if.b=tr.b;
            #10;
        end
    endtask //run
endclass

class environment;
    generator gen;
    driver drv;
    mailbox #(transaction) gen2drv_mbox;

    function new(virtual adder_intf adder_if);
        gen2drv_mbox = new();
        gen = new(gen2drv_mbox);
        drv = new(gen2drv_mbox, adder_if);
    endfunction //new()

    task run ();
        fork
            gen.run(100);
            drv.run();
        join_any
        #10 $finish;
        //for~join 안에있는 값들은 thread로 동작한다.
        
    endtask //run
endclass //environment


//제일 밖에 있는 네모칸
module tb_adder();
    environment env; 
    //이때 인스턴스화된 이름(env)를 handler라고 한다.
    //인스턴스화 시켰을 때: 
    // handler는 컴퓨터 메모리 공간 중 stack 영역에 생성됨
    // class는 sw!
    //env: reference 값을 받을 수 있는 공간
    //실체화(instance화): 메모리에 공간이 생긴다. -> heap 메모리 공간에 loading 되는 것
    //이 큰 (heap ) 공간을 작은 handler(stack에 있는) 가 handle한다.


    adder_intf adder_if(); //실제 hw
    //실제로 만들어져있는 hw interface (합성이 된다)


    //hw와 interface간 연결
    //얘도 실제 hw.
    adder dut(
        .a(adder_if.a),
        .b(adder_if.b),
        .sum(adder_if.sum),
        .carry(adder_if.carry)
    );

    initial begin
        //initial 때 env를  실체화 시켜주어야한다.
        env = new(adder_if); 
        //heap 영역에 만들어짐, env(stack)에 environment(heap)의 주소값을 주고있는중
        //reference 값을 넘겨준다.
        //env는 environment의 주소를 갖고 있다. (pointer 값)


        env.run();
    end

endmodule
