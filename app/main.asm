;-------------------------------------------------------------------------------
; Include files
            .cdecls C,LIST,"msp430.h"  ; Include device header file
;-------------------------------------------------------------------------------

            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.

            .global __STACK_END
            .sect   .stack                  ; Make stack linker segment ?known?

            .text                           ; Assemble to Flash memory
            .retain                         ; Ensure current section gets linked
            .retainrefs

RESET       mov.w   #__STACK_END,SP         ; Initialize stack pointer


init:
            ; stop watchdog timer
            mov.w   #WDTPW+WDTHOLD,&WDTCTL

            ; Setup LED2
            bic.b   #BIT6,&P6OUT            ; Clear P6.6 output
            bis.b   #BIT6,&P6DIR            ; P6.6 output

            bic.w   #LOCKLPM5,&PM5CTL0      ; Unlock I/O pins

            ; Setup Clock
            bis.w	#TBCLR, &TB0CTL				; Clear timer & dividers
			bis.w	#TBSSEL__ACLK, &TB0CTL		; Select ACLK as timer source
			bis.w	#MC__CONTINUOUS, &TB0CTL	; Choose continuous counting
			bis.w	#CNTL_1, &TB0CTL        ; 2^12 
			bis.w	#ID__8, &TB0CTL         ; Divide clock by 8
			bis.w	#TBIE, &TB0CTL			; Enable overflow interrupt
			bic.w	#TBIFG, &TB0CTL			; Clear interrupt flag
            NOP
			bis.w	#GIE, SR				; Enable maskable interrupts
            NOP

main:
<<<<<<< Updated upstream

            nop 
            jmp main
=======
; ------------------------------------
;       TX bytes main loop code
; ------------------------------------
            mov.w   #00, R4
            mov.w   #068h, Adress
            mov.w   #04h, R7
            mov.w   #Tx, R5
            mov.w   R7, Data_Count
            mov.w   R4,0(R5)                 ; setting subaddress to write to

            inc.w   R5
            inc.w   R5
            mov.w   #000h,R4
            mov.w   R4,0(R5)                ; setting seconds

            inc.w   R5
            inc.w   R5
            mov.w   #015h,R4
            mov.w   R4,0(R5)                ; setting minutes

            inc.w   R5
            inc.w   R5
            mov.w   #010h,R4
            mov.w   R4,0(R5)                ; setting hours
            call    #i2c_write
            call    #i2c_stop
; -----------End TX bytes-------------


read
; ------------------------------------
;       RX bytes main loop code
; ------------------------------------
            mov.w   #00, R4
            mov.w   #068h, Adress
            mov.w   #01h, R7
            mov.w   #00h, Tx
            mov.w   R7, Data_Count

            call    #i2c_write
            call    #i2c_read
            bis.b   #BIT0,&P3OUT
            bic.b   #BIT2,&P3OUT
            call    #i2c_stop
; -----------End RX bytes-------------


; ------------------------------------
;       RX temperature bytes
; ------------------------------------
            mov.w   #011, R4
            mov.w   #068h, Adress
            mov.w   #01h, R7
            mov.w   #00h, Tx
            mov.w   R7, Data_Count
            mov.w   #Tx, R5
            mov.w   R4,0(R5)                 ; setting subaddress to read from

            call    #i2c_write
            call    #i2c_read
            bis.b   #BIT0,&P3OUT
            bic.b   #BIT2,&P3OUT
            call    #i2c_stop
            mov.w   #Rx, R6
            mov.w   0(R6), R4
            mov.w   1(R6), R5

; -----------End RX bytes-------------

            jmp     read
>>>>>>> Stashed changes
            nop

;------------------------------------------------------------------------------
;           Interrupt Service Routines
;------------------------------------------------------------------------------

;TB0 Overflow
ISR_TB0_Overflow                            ; Triggers every 1.0s 
            xor.b   #BIT6,&P6OUT
            bic.w   #TBIFG,&TB0CTL
            reti
;-------------- END ISR_TB0_Overflow --------------

;------------------------------------------------------------------------------
;           Interrupt Vectors
;------------------------------------------------------------------------------
            .sect   RESET_VECTOR            ; MSP430 RESET Vector
            .short  RESET                   ;

            .sect	".int42"                ; TB0 interrupt vector
            .short	ISR_TB0_Overflow        ;
            .end