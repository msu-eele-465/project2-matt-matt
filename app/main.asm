;-------------------------------------------------------------------------------
; Include files
            .cdecls C,LIST,"msp430.h"  ; Include device header file
            .include "i2c.asm"
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

            ;-----------------------------------------
            ;   Setting up I2C Pins
            ;-----------------------------------------
            ; Adding Pin 3.2 as output SCL
            mov.w		#00h, P3SEL0
            mov.w		#00h, P3SEL1
            bis.b		#BIT2, &P3DIR			; Set P3.2 as an output. P3.2 is GPIO
            bis.b		#BIT2, &P3OUT			; Set out to high

            ; Adding Pin 3.0 as output SDA
            mov.w		#00h, P3SEL0
            mov.w		#00h, P3SEL1
            bis.b		#BIT0, &P3DIR			; Set P3.0 as an output. P3.0 is GPIO
            bis.b		#BIT0, &P3OUT			; Set out to high
            ;-----------------------------------------

            ; Setup Clock
            bis.w	#TBCLR, &TB0CTL				; Clear timer & dividers
			bis.w	#TBSSEL__ACLK, &TB0CTL		; Select ACLK as timer source
			bis.w	#MC__CONTINUOUS, &TB0CTL	; Choose continuous counting
			bis.w	#CNTL_1, &TB0CTL            ; 2^12 
			bis.w	#ID__8, &TB0CTL             ; Divide clock by 8
			bis.w	#TBIE, &TB0CTL			    ; Enable overflow interrupt
			bic.w	#TBIFG, &TB0CTL			    ; Clear interrupt flag
            ;-----------------------------------------

            ; Disable Low Power Mode
		    bic.w	#LOCKLPM5, &PM5CTL0
			bis.w	#GIE, SR				; Enable maskable interrupts
            NOP

main:
            mov.w   #00, R4
            mov.w   #09h, R7

main_loop   mov.w   R4,Tx
            call    #i2c_write
            add.w   #0100h,R4
            dec.w   R7
            jnz     main_loop
            jmp     main
            nop

;------------------------------------------------------------------------------
;           Subroutines
;------------------------------------------------------------------------------

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

i2c_ack_delay:
            bic.b	#BIT0, &P3DIR			; Set P3.0 as an input. P3.0 is GPIO

            ; Doing clock cycle to get ack or nack from device
            call    #i2c_half_delay
            call    #i2c_half_delay
            bis.b   #BIT2,&P3OUT
            call    #i2c_delay
            call    #i2c_half_delay
            bic.b   #BIT2,&P3OUT
            call    #i2c_half_delay

            bis.b		#BIT0, &P3DIR			; Set P3.0 as an output. P3.0 is GPIO
            ret
            nop
;-------------- END i2c_ack_delay --------------

i2c_ack:
            call    #i2c_half_delay
            bic.b   #BIT0,&P3OUT
            call    #i2c_half_delay
            bis.b   #BIT2,&P3OUT
            call    #i2c_delay
            call    #i2c_half_delay
            bic.b   #BIT2,&P3OUT
            call    #i2c_half_delay
            bis.b   #BIT0,&P3OUT

            ret
            nop
;-------------- END i2c_ack --------------

i2c_tx_byte:
            push    R4
            push    R7
            mov.w   #8, R4
            mov.w   Data,R7           ; Loading 04h in with 8 trailing 0s 100->100 0000 0000
            clrc

; looping throug the address
bit_loop
            call    #i2c_half_delay
            clrc
            rlc.w   R7
            JNC     No_carry1
            bis.b   #BIT0,&P3OUT
No_carry1   call    #i2c_half_delay
            bis.b   #BIT2,&P3OUT
            call    #i2c_delay
            call    #i2c_half_delay
            bic.b   #BIT2,&P3OUT
            call    #i2c_half_delay
            bic.b   #BIT0,&P3OUT
            dec     R4
            jnz     bit_loop

            pop     R7
            pop     R4

            ret
            nop
;-------------- END i2c_tx_byte --------------

i2c_write:
            push    R4

            call    #i2c_start
            mov.w   Adress,R4
            setc
            rlc.w   R4
            mov.w   R4,Data
            call    #i2c_tx_byte
            call    #i2c_ack_delay
            mov.w   Tx,Data
            call    #i2c_tx_byte
            call    #i2c_ack_delay
            call    #i2c_stop

            pop     R4
            ret
            nop
;-------------- END i2c_write --------------

i2c_rx_byte:
            bic.b	#BIT0, &P3DIR	    ; Set P3.0 as an input. P3.0 is GPIO

            push    R4
            push    R7
            mov.w   #8, R4
            mov.w   Data,R7             ; Loading 04h in with 8 trailing 0s 100->100 0000 0000
            clrc

; looping throug the address
bit_loop
            call    #i2c_half_delay
            clrc
            rlc.w   R7
            JNC     No_carry1
            bis.b   #BIT0,&P3OUT
No_carry1   call    #i2c_half_delay
            bis.b   #BIT2,&P3OUT
            call    #i2c_delay
            call    #i2c_half_delay
            bic.b   #BIT2,&P3OUT
            call    #i2c_half_delay
            bic.b   #BIT0,&P3OUT
            dec     R4
            jnz     bit_loop

            pop     R7
            pop     R4

            ret
            nop
;-------------- END i2c_rx_byte --------------

i2c_delay:

            push    R4
            mov.w   #1150, R4
start_loop0 dec     R4
            jnz     start_loop0
            pop     R4

            ret
            nop
;-------------- END i2c_delay --------------

i2c_half_delay:

            push    R4
            mov.w   #575, R4
start_loop1 dec     R4
            jnz     start_loop1
            pop     R4

            ret
            nop
;-------------- END i2c_half_delay --------------


;------------------------------------------------------------------------------
;           Interrupt Service Routines
;------------------------------------------------------------------------------

;TB0 Overflow
ISR_TB0_Overflow                            ; Triggers every 1.0s 
            xor.b   #BIT6,&P6OUT
            bic.w   #TBIFG,&TB0CTL
            reti
;-------------- END ISR_TB0_Overflow --------------


;-------------------------------------------------------------------------------
; Memmory Allocation
;-------------------------------------------------------------------------------

		.data							; allocate variables in data memory
		.retain							; keep allocations even if unused

; Lab 6.3 - Step 3; Initialize and Reserve Locations in Data Memory
Adress 	.short	    00000400h           ; 04h is the date on the ds3231 RTC

Data    .space      2
Tx      .space      2


;-------------------------------------------------------------------------------
; Stack Pointer definition
;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect   .stack
            

;------------------------------------------------------------------------------
;           Interrupt Vectors
;------------------------------------------------------------------------------
            .sect   RESET_VECTOR            ; MSP430 RESET Vector
            .short  RESET                   ;

            .sect	".int42"                ; TB0 interrupt vector
            .short	ISR_TB0_Overflow        ;

            .end