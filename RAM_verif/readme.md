### single port RAM
> 하나의 port만 사용
![RAM](image.png)
- addr: 5bit(메모리 주소가 2**32-1개 있음) 
- wdata 8bit
- we: 1> write, 0> read
- rdata 8bit


![alt text]({D06C931B-F35F-4728-BA3D-165D68DE3EA8}.png)
> 이게 하나의 interface 구조



- raise condition 발생
`ram_if.we=ram_tr.we`와 `ram_if.we=1'b0` 둘이서 raise condition 발생함
![alt text]({BFCE82C9-E861-4F93-97F1-8E9CA43B10B6}.png)
![alt text]({5FA60DBC-3941-421A-83A5-E817780141CA}.png)
we이 clk posedge 에 동시에 0으로 떨어지는게 아니라 조금의 delay이후에 0으로 떨어져야 한다.(ram에 write 동작을 기다려야한다.)
![alt text]({80E186C9-ECAB-4C38-AEEF-93B7584F5AC1}.png)
delay 추가
![alt text]({F3150049-4FC4-42E1-9F3D-A7B232491C41}.png)

> AMBA APB datasheet을 확인해봐도 clk edge에서 바로 signal 을 change 하지 않음
![alt text]({63B3B78A-6F71-438C-9AD0-83CC103618F9}.png)
clk posedge이후 약간의 delay후에 변화가 생긴다.
raise condition을 방지하기 위함


> 애초에 input output에 default delay 주기
clocking block 이용
input, output이 나중에 나간다.

> clocking block 적용이후
![alt text]({80F5931A-E345-4C23-B425-CE0205E5171C}.png)
