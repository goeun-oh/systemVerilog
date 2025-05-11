#include <stdint.h>

#define __IO    volatile

typedef struct {
    __IO uint32_t FCR;
    __IO uint32_t FMR;
    __IO uint32_t FDR;
}FND_TypeDef;




#define APB_BASEADDR  0x10000000
// #define GPOA_BASEADDR (APB_BASEADDR + 0x1000)
// #define GPIB_BASEADDR (APB_BASEADDR + 0x2000)
// #define GPIOC_BASEADDR (APB_BASEADDR + 0x3000)
#define FND_BASEADDR (APB_BASEADDR + 0x4000)

// #define GPIOC           ((GPIO_TypeDef *) GPIOC_BASEADDR)
#define FND           ((FND_TypeDef *) FND_BASEADDR)




void delay(int n);
void fndEn(FND_TypeDef* FNDx, uint32_t n);
void fndCom(FND_TypeDef* FNDx, uint32_t fndComm);
void fndfont(FND_TypeDef* FNDx, uint32_t fndFont);


int main()
{   
    uint32_t temp = 0;
    uint32_t count = 0;
    while(1)
    {   
        fndEn(FND, 0x01);

        for (int i=0; i<16; i++){
            fndCom(FND, temp);
            for (int j=0; j<10; j++){
                fndfont(FND, count);
                count++;
                delay(500);
            }
            count=0;
            temp++;
        }
        temp=0;
        count=0;
        delay(500);
    }
    return 0;
};


void delay(int n){
    uint32_t temp = 0;
    for (int i=0; i<n; i++) {
        for (int j=0; j<1000; j++) {
            temp++;
        }
    }
};

void fndEn(FND_TypeDef* FNDx, uint32_t n){
    if(n == 1) {
        FNDx -> FCR = 0x01;
    } else{
        FNDx -> FCR = 0x00;
    }
}

void fndCom(FND_TypeDef* FNDx, uint32_t fndComm){
    FNDx-> FMR = fndComm;
}
void fndfont(FND_TypeDef* FNDx, uint32_t fndFont){
    FNDx-> FDR = fndFont;
}