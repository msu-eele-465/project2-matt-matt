i2c_start:
            bic.b   #BIT0,&P3OUT
            call    #i2c_delay
            bic.b   #BIT2,&P3OUT

            ret
            nop
;-------------- END i2c_start --------------

i2c_stop:
            call    #i2c_delay
            bic.b   #BIT0,&P3OUT
            call    #i2c_half_delay
            bis.b   #BIT2,&P3OUT
            call    #i2c_delay
            call    #i2c_half_delay
            bis.b   #BIT0,&P3OUT
            call    #i2c_delay

            ret
            nop
;-------------- END i2c_stop --------------