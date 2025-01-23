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
			bis.w	#CNTL_1, &TB0CTL        ; 2^12 
			bis.w	#ID__8, &TB0CTL         ; Divide clock by 8
			bis.w	#TBIE, &TB0CTL			; Enable overflow interrupt
			bic.w	#TBIFG, &TB0CTL			; Clear interrupt flag
            NOP

            ; Disable Low Power Mode
		    bic.w	#LOCKLPM5, &PM5CTL0
			bis.w	#GIE, SR				; Enable maskable interrupts
            NOP

main:
            call    #i2c_start
            nop 
            jmp     main
            nop

;------------------------------------------------------------------------------
;           Subroutines
;------------------------------------------------------------------------------

i2c_start:

            bic.b   #BIT0,&P3OUT
            call    #i2c_start_delay
            bic.b   #BIT2,&P3OUT
            call    #i2c_start_delay

            ret
            nop
;-------------- END i2c_start --------------

i2c_stop:
            bis.b   #BIT0,&P3OUT
            jmp     main
            nop
;-------------- END i2c_start --------------

i2c_start_delay:
			bic.w	#GIE, SR				; Disable maskable interrupts

            push    R4
            mov.w   #60000, R4
start_loop  dec     R4
            jnz     start_loop
            pop     R4

			bis.w	#GIE, SR				; Enable maskable interrupts
            ret
            nop
;-------------- END i2c_start --------------


;------------------------------------------------------------------------------
;           Interrupt Service Routines
;------------------------------------------------------------------------------

;TB0 Overflow
ISR_TB0_Overflow                            ; Triggers every 1.0s 
            xor.b   #BIT6,&P6OUT
            bis.b   #BIT0,&P3OUT
            bis.b   #BIT2,&P3OUT
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