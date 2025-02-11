;-------------------------------------------------------------------------------
; Include files
            .cdecls C,LIST,"msp430.h"  ; Include device header file
            ; .include "i2c.asm"
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

main:
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
            mov.w   #010h,R4
            mov.w   R4,0(R5)                ; setting minutes

            inc.w   R5
            inc.w   R5
            mov.w   #004h,R4
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

            jmp     read
            nop

;------------------------------------------------------------------------------
;           Subroutines
;------------------------------------------------------------------------------

i2c_start:
            call    #i2c_delay
            bic.b   #BIT0,&P3OUT
            call    #i2c_delay
            bic.b   #BIT2,&P3OUT

            ret
            nop
;-------------- END i2c_start --------------

i2c_stop:
            call    #i2c_half_delay
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
            bis.b	#BIT0, &P3REN           ; Setting weak pullup resistor
            push    R4
            push    R5

            ; Doing clock cycle to get ack or nack from device
            call    #i2c_half_delay
            call    #i2c_half_delay
            bis.b   #BIT2,&P3OUT
            call    #i2c_delay
            mov.b   &P3IN, R4
            mov.w   #05h, R5
            cmp.w	R5, R4
            jnz      i2c_ack_delay_end
            mov.w   #01h,Nack_Flag

i2c_ack_delay_end
            call    #i2c_half_delay
            bic.b   #BIT2,&P3OUT
            call    #i2c_half_delay
            bic.b	#BIT0, &P3REN           ; Removing weak pullup resistor
            bis.b	#BIT0, &P3DIR			; Set P3.0 as an output. P3.0 is GPIO
            pop     R5
            pop     R4
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

i2c_nack:
            call    #i2c_half_delay
            ; bic.b   #BIT0,&P3OUT
            call    #i2c_half_delay
            bis.b   #BIT2,&P3OUT
            call    #i2c_delay
            call    #i2c_half_delay
            bic.b   #BIT2,&P3OUT
            call    #i2c_half_delay
            ; bis.b   #BIT0,&P3OUT

            ret
            nop
;-------------- END i2c_nack --------------

i2c_tx_byte:
            push    R4
            push    R7
            mov.w   #8, R4
            mov.w   Data,R7           ; Loading 04h in with 8 trailing 0s 100->100 0000 0000
            clrc

; looping throug the data
bit_loop
            bic.b   #BIT0,&P3OUT
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
            dec     R4
            jnz     bit_loop

            bis.b   #BIT0,&P3OUT
            pop     R7
            pop     R4

            ret
            nop
;-------------- END i2c_tx_byte --------------

i2c_write:
            push    R4
            push    R5
            push    R7

i2c_write_address
            bis.b   #BIT0,&P3OUT
            bis.b   #BIT2,&P3OUT
            mov.w   #00h,Nack_Flag
            call    #i2c_start
            mov.w   Adress,R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            mov.w   R4,Data
            call    #i2c_tx_byte
            call    #i2c_ack_delay
            mov.w   Nack_Flag,R4
            cmp.w   #01h,R4
            jz      i2c_write_address

            mov.w   Data_Count, R7
            mov.w   #Tx, R5
            
i2c_write_data
            mov.w   0(R5), R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            mov.w   R4, Data
            inc.w   R5
            inc.w   R5
            call    #i2c_tx_byte
            call    #i2c_ack_delay
            mov.w   Nack_Flag,R4
            cmp.w   #01h,R4
            jz      i2c_write_address
            dec     R7
            jnz     i2c_write_data


write_end   pop     R7
            pop     R5
            pop     R4
            ret
            nop
;-------------- END i2c_write --------------

i2c_rx_byte:
            bic.b	#BIT0, &P3DIR			; Set P3.0 as an input. P3.0 is GPIO
            bis.b	#BIT0, &P3REN           ; Setting weak pullup resistor
            push    R4
            push    R5
            push    R6
            push    R7
            mov.w   #00h, R7
            mov.w   #08h, R4

; looping throug the data
read_b      call    #i2c_half_delay
            call    #i2c_half_delay
            bis.b   #BIT2,&P3OUT
            call    #i2c_delay

            ; Checking for 1 or 0 in data
            mov.b   &P3IN, R6
            cmp.w	 #05h, R6               ; comparing for a 1 on the input pin
            jnz      i2c_rec_z              ; jumps to rotating right arithmatically (adding a zero)
            setc
            rlc.w   R7
            jmp     i2c_rel                 ; if there was a 1, skip adding a zero
i2c_rec_z   rla.w   R7

i2c_rel     call    #i2c_half_delay
            bic.b   #BIT2,&P3OUT
            call    #i2c_half_delay
            dec.w   R4
            jnz     read_b


            mov.w   Rx_Count, R5
            mov.w   #Rx, R6
i2c_rx_mem_shift
            cmp.w   #00h, R5
            jz      i2c_rx_write
            dec.w   R5
            inc.w   R6
            inc.w   R6
            jmp     i2c_rx_mem_shift

i2c_rx_write
            mov.w   R7, 0(R6)               ; moving data to memory

            bic.b	#BIT0, &P3REN           ; Removing weak pullup resistor
            bis.b	#BIT0, &P3DIR			; Set P3.0 as an output. P3.0 is GPIO
            pop     R7
            pop     R6
            pop     R5
            pop     R4

            ret
            nop
;-------------- END i2c_rx_byte --------------

i2c_read:
            push    R4
            push    R5
            push    R7

i2c_read_address
            bis.b   #BIT0,&P3OUT
            bis.b   #BIT2,&P3OUT
            mov.w   #00h,Nack_Flag
            call    #i2c_start
            mov.w   Adress,R4
            setc
            rlc.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            rla.w   R4
            mov.w   R4,Data
            call    #i2c_tx_byte
            call    #i2c_ack_delay
            mov.w   Nack_Flag,R4
            cmp.w   #01h,R4
            jz      i2c_read_address

            mov.w   #03h, R4
            mov.w   #00h, R7
            mov.w   R7, Rx_Count
i2c_read_data
            call    #i2c_rx_byte
            inc.w   R7
            mov.w   R7, Rx_Count
            dec.w   R4
            jz      i2c_read_nack
            call    #i2c_ack
            jmp     i2c_read_data

i2c_read_nack
            bis.b   #BIT0,&P3OUT
            bis.b   #BIT2,&P3OUT
            call    #i2c_nack

read_end    pop     R7
            pop     R5
            pop     R4
            ret
            nop
;-------------- END i2c_write --------------

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
Adress 	    .short	    000068h         ; 68h is the adress of the ds3231 RTC

SubAdress   .space      2               ; a place to store subaddresses of the rtc registers
Data        .space      2
Tx          .space      18
Rx          .space      18
Nack_Flag   .space      2
SubA_Flag   .space      2
Data_Count  .space      2
Rx_Count    .space      2


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
