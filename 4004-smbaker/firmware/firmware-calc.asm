    PAGE 0                          ; suppress page headings in ASW listing file

;---------------------------------------------------------------------------------------------------------------------------------
; Copyright 2025 Scott Baker
;---------------------------------------------------------------------------------------------------------------------------------

;---------------------------------------------------------------------------------------------------------------------------------
; This firmware is loaded into bank2 and implements a calculator using scott's "front panel" board
;
; The front panel board implements 10 7-segment displays and a 16-button keypad.
;
; This firmware does not use the serial port -- all interaction is through the front panel.
;---------------------------------------------------------------------------------------------------------------------------------

            cpu 4040                    ; Tell the Macro Assembler AS that this source is for the Intel 4040.

                include "bitfuncs.inc"  ; Include bit functions so that FIN can be loaded from a label (upper 4 bits of address are loped off).
                include "reg4004.inc"   ; Include 4004 register definitions.

                include "const.inc"

KEY_DIV         equ 0AH
KEY_TIMES       equ 0BH
KEY_MINUS       equ 0CH
KEY_PLUS        equ 0DH
KEY_EQUAL       equ 0EH
KEY_CLEAR       equ 0FH

                ; register usage
                ;   R12 - holds operation to perform
                ;   R13 - holds input from keypad

                org 0000H               ; beginning of 2732 EPROM
;--------------------------------------------------------------------------------------------------
; Power-on-reset Entry
;--------------------------------------------------------------------------------------------------
                nop                     ; "To avoid problems with power-on reset, the first instruction at
                                        ; program address 0000 should always be an NOP." (dont know why)

pgmstart:       jun gobank0             ; This line is never ever executed, because power-on start always happens in bank0.

                include "pagemap.inc"
                include "printhex.inc"
                include "txtout.inc"
                include "delay.inc"

                ifdef SERUART
                include "uartser.inc"
                endif
                ifdef SERBB
                include "bbser.inc"
                endif

                org 0100H

bankstart:
reset:          ldm KEY_PLUS
                xch R12                 ; set operation to PLUS
                fim P2,accumulator      ; P2 points the memory register where the first number (and sum) digits are stored (10H-1FH)
                jms clrram              ; clear RAM 10H-1FH
                fim P2,addend           ; P2 points the memory register where the second number digits are stored (20H-2FH)
                jms clrram              ; clear RAM 20H-2FH
                jms displayon
                jun kbd_accum

;-----------------------------------------------------------------------------------------
; keypad processor
;-----------------------------------------------------------------------------------------

; idea - on start preload operation with +. That way when we start typing numbers, it will
; add them to the add them to the accumulator (which starts at zero)

; xxx

kbd_accum:      fim p2, accumulator     ; display the accumulator, until a key is pressed
                jms display
                jms setdispmask
kbdloop0:       jms fp_getkey
                jcn cn, kbdloop0        ; repeat until a key is pressed
                ld r1
                xch r13                  ; store it in r13
kbdloop1:       jms fp_getkey
                jcn c, kbdloop1         ; repeat until a key is released                
                jun kbdgotkey           ; process the key and enter the accumulator loop
; xxx

kbd_addend:     fim p2, addend
                jms display
                jms setdispmask
kbdloop2:       jms fp_getkey
                jcn cn, kbdloop2        ; repeat until a key is pressed
                ld r1
                xch r13                 ; store it in r13
kbdloop3:       jms fp_getkey
                jcn c, kbdloop3         ; repeat until a key is released

kbdgotkey:
                ldm 09H
                clc
                sub r13
                jcn cn, kbd_op          ; if r13 >= 10, then it's an operation, not a number

shiftdig:       fim P3, addend          ; only the MSB matters here
                fim P4, addend
                ldm 08H
                xch R7                  ; make the least significant digit of source address in P3 0EH
                ldm 09H
                xch R9                  ; make the least significant digit of destination address in P4 0FH
                ldm (16-9)
                xch R1                  ; loop counter (9 times thru the loop)
                
; Move digits in RAM 0EH-00H to the next higher address 0FH-01H.
; The digit at 0EH is moved to 0FH, the digit at 0DH is moved to 0EH, the digit at 0CH is moved to 0DH, and so on.
; Moving the digits makes room for the new digit from the serial port which is contained in P1 to be stored at 00H
; at the least significant digit. P3 (R6,R7) is used as a pointer to the source register for the move.
; P4 (R8,R9) is used as a pointer to the destination register.                
shiftdiglp:     src P3                  ; use address in P3 for RAM reads
                rdm                     ; read digit from source
                src P4                  ; use address in P4 for RAM writes
                wrm                     ; write digit to destination
                ld  R9
                dac                     ; decrement least significant nibble of destination address
                xch R9
                ld  R7
                dac                     ; decrement least significant nibble of source address
                xch R7
                isz R1,shiftdiglp       ; do all digits

; save the new digit (in R13) from the keypad
                ld R13                  ; R13 holds least significant nibble of the character received from the keypad
                fim P2, addend
                src P2                  ; P2 now points to the destiation for the character
                wrm                     ; save the least significant nibble of the new digit (the binary value for the number) in RAM
                jun kbd_addend

kbd_op:         ldm KEY_CLEAR
                clc
                sub r13                 ; clear checks the current character
                jcn zn, kbd_ck_plus
                jun reset

kbd_ck_plus:    ldm KEY_PLUS
                clc
                sub r12
                jcn zn, kbd_ck_sub
kbd_op_plus:    fim p1, accumulator     ; setup
                fim p2, addend          ; ... and perform
                jms addition            ; ... addition
                jun kbd_op_out

kbd_ck_sub:     ldm KEY_MINUS
                clc
                sub r12
                jcn zn, kbd_ck_equal
                fim p1, accumulator     ; setup
                fim p2, addend          ; ... and perform
                jms subtract            ; ... subtraction
                jun kbd_op_out

kbd_ck_equal:   ldm KEY_EQUAL           ; FIXME FIXME FIXME
                clc
                sub r12
                jcn zn, kbd_op_out
                fim p2, accumulator     ; clear the accumulator
                jms clrram              ; ...  since equal terminated the last op
                jun kbd_op_plus         ; then add the addend to the accumulator


kbd_op_out:     ld r13                  ; get keypress
                xch r12                 ; store in next operation
                fim p2, addend          ; clear the addend for next operation
                jms clrram                
                jun kbd_accum

                org 0B00H

;-------------------------------------------------------------------------------
; this is the function that performs the multi-digit decimal addition
; for the addition demo above
; inputs:
;    P1 - accumulator
;    P2 - addend
; destroys:
;    P1 (r2,r3)
;    P2 (r4,r5)
;    R11
;-------------------------------------------------------------------------------
addition:       ldm 16-16
                xch R11                 ; R6 is the loop counter (0 gives 16 times thru the loop for all 16 digits)
                clc                     ; clear carry in preparation for 'add with carry' instruction
addition1:      src P2                  ; P2 points to the addend digits
                rdm                     ; read the addend digit
                src P1                  ; P1 points to the "accumulator"
                adm                     ; add the digit from the "accumulator" to the addend
                daa                     ; convert the sum from binary to decimal
                wrm                     ; write the sum back to the "accumulator"
                inc R3                  ; point to next "accumlator" digit
                inc R5                  ; point to next addend digit to be added to the accumulator
                isz R11,addition1       ; loop 16 times (do all 16 digits)
                jcn cn,addition2        ; no carry means no overflow from the 16th digit addition
                bbl 1                   ; 16 digit overflow
addition2:      bbl 0                   ; no overflow

;-------------------------------------------------------------------------------
; this is the function that performs the multi-digit decimal subtraction
; for the subtraction demo below
; inputs
;   P1 - accumulator
;   P2 - subtrahend
; destroys:
;   P1 (r2, r3)
;   P2 (r3, r4)
;   R11
;-------------------------------------------------------------------------------
subtract:       ldm 0
                xch R11                 ; R11 is the loop counter (0 gives 16 times thru the loop for 16 digits)
                stc                     ; set carry=1
subtract1:      tcs                     ; accumulator = 9 or 10
                src P2                  ; select the subtrahend
                sbm                     ; produce 9's or l0's complement
                clc                     ; clear carry in preparation for 'add with carry' instruction
                src P1                  ; select the minuend
                adm                     ; add minuend to accumulator
                daa                     ; adjust accumulator
                wrm                     ; write result to replace minuend
                inc R3                  ; address next digit of minuend
                inc R5                  ; address next digit of subtrahend
                isz R11,subtract1       ; loop back for all 16 digits
                jcn c,subtract2         ; carry set means no underflow from the 16th digit
                bbl 1                   ; overflow, the difference is negative
subtract2:      bbl 0                   ; no overflow, the difference is positive

                org 0C00H

;-------------------------------------------------------------------------------
; Multi-digit multiplication function taken from:
; "A Microcomputer Solution to Maneuvering Board Problems" by Kenneth Harper Kerns, June 1973
; Naval Postgraduate School Monterey, California.
; On entry, P1 points to the multiplicand, P2 points to the multiplier, P3 points to the product.
; Sorry about the lack of comments. That's how it was done back in the day of slow teletypes.
; inputs:
;   P1
;   P2
; outputs:
;   P3
; destorys:
;   P1 (r2,r3)
;   P2 (r4,r5)
;   R0
;   R1
;   R6
;   R7
;   R14
;   R15
;-------------------------------------------------------------------------------
MLRT            clb
                xch R7
                ldm 0
                xch R14
                ldm 0
ZLPM            src P3
                wrm
                isz R7,ZLPM
                wr0
                ldm 4
                xch R5
                src P1
                rd0
                rar
                jcn cn,ML4
                ld R2
                xch R0
                ldm 0
                xch R1
                jms CPLRT
                stc
                ldm 0FH
                src P1
                wr3
ML4             ral
                xch R15
                src P2
                rd0
                rar
                jcn cn,ML6
                ld R4
                xch R0
                ldm 0
                xch R1
                jms CPLRT
                stc
                ldm 0FH
                src P2
                wr3
ML6             ral
                clc
                add R15
                src P3
                wr0

ML1             src P2
                rdm
                xch R15

ML2             ld R15
                jcn z,ML3
                dac
                xch R15
                ldm 5
                xch R3
                ld R14
                xch R7
                jms MADRT
                jun ML2

ML3             inc R14
                isz R5,ML1
                src P3
                rd0
                rar
                jcn cn,ML5
                ldm 0
                wr0
                xch R1
                ld R6
                xch R0
                jms CPLRT

ML5             src P1
                rd3
                jcn z,ML8
                ld R2
                xch R0
                ldm 0
                xch R1
                jms CPLRT
                ldm 0
                src P1
                wr3

ML8             src P2
                rd3
                jcn z,ML7
                ld R4
                xch R0
                ldm 0
                xch R1
                jms CPLRT
                ldm 0
                src P2
                wr3
                nop
                nop
ML7             bbl 0

MADRT           clc
STMAD           src P1
                rdm
                src P3
                adm
                daa
                wrm
                isz R3,SKIPML
                bbl 0
SKIPML          isz R7,STMAD
                bbl 0

CPLRT           clc
COMPL           src P0
                ldm 6
                adm
                cma
                wrm
                isz R1,COMPL
                stc
TENS            ldm 0
                src P0
                adm
                daa
                wrm
                inc R1
                jcn c,TENS
                src P0
                rd0
                rar
                cmc
                ral
                wr0
                bbl 0

                org 0D00H

;-------------------------------------------------------------------------------
; Multi-digit division routine taken from:
; "A Microcomputer Solution to Maneuvering Board Problems" by Kenneth Harper Kerns, June 1973
; Naval Postgraduate School Monterey, California.
; inputs:
;   P1 (r2,r3) points to the dividend
;   P3 (r6,r7) points to the divisor
; outputs:
;   P2 (r4,r5) points to the remainder,
;   P4 (r8,r9) points to the quotient
; destroys:
;   R0, R1
;   R16
;-------------------------------------------------------------------------------
; DIVIDE ROUTINE, SETS UP TO USE DECDIV
DVRT            src P1
                rd0
                rar
                jcn cn,DV4
                ld R2
                xch R0
                ldm 0
                xch R1
                jms CPLRT
                stc
                ldm 1
                wr1
DV4             ral
                xch RF
                src P3
                rd0
                rar
                jcn cn,DV6
                ld R6
                xch R0
                ldm 0
                xch R1
                jms CPLRT
                stc
                ldm 1
                wr1
DV6             ral
                clc
                add RF
                src P4
                wr0
                jms DECDIV
CHKPT           src P1
                rd1
                jcn z,DV1
                ld R2
                xch R0
                ldm 0
                wr1
                xch R1
                jms CPLRT
DV1             src P3
                rd1
                jcn z,DV2
                ld R6
                xch R0
                ldm 0
                wr1
                xch R1
                jms CPLRT
DV2             src P4
                rd0
                rar
                jcn cn,ATLAST
                clc
                ral
                wr0
                ld R8
                xch R0
                ldm 0
                xch R1
                jms CPLRT
ATLAST          bbl 0

                org 0E00H

;--------------------------------------------------------------------------------------------------                
; DECIMAL DIVISION ROUTINE
;  WRITTEN  BY
;  G. A. KILDALL
;  ASSISTANT PROFESSOR
;  NAVAL POSTGRADUATE SCHOOL
;  MONTEREY, CALIFORNIA
; destroys:
;  pretty much everything...
;  R9,R10,R11,R12,R13,R14,R15
;--------------------------------------------------------------------------------------------------
DECDIV          ldm 9
                src P1
                wr2
                src P3
                wr2
                src P4
                wr2
                clb
ZEROR           src P4
                wrm
                src P2
                wrm
                inc R5
                isz R9,ZEROR
                clb
                xch RB
LZERO           ld RB
                cma
                xch R3
                src P1
                rdm
                jcn zn,FZERO
                isz RB,LZERO
                jun ENDDIV

FZERO           ld RB
                xch R5
                clb
                xch R3
COPYA           src P1
                rdm
                src P2
                wrm
                inc R3
                isz R5,COPYA
                ld RB
                xch RE
                src P1
                rd2
                add RB
                xch RB
                tcc
                xch RA
                clb
                xch RD
LZERO1          ld RD
                cma
                xch R7
                src P3
                rdm
                jcn zn,FZERO1
                isz RD,LZERO1
                bbl 1

FZERO1          ld RD
                xch RF
                rd2
                add RD
                xch RD
                tcc
                xch RC
                src P4
                rd2
                add RD
                xch RD
                ldm 0
                add RC
                xch RC
                clc
                ld RD
                sub RB
                xch R9
                cmc
                ld RC
                sub RA
                jcn c,NDERF
                bbl 0

NDERF           jcn zn,DOVRFL
                ldm 15
                xch RB
                ld R6
                xch RA
COPYC1          src P3
                rdm
                src P5
                wrm
                ld R7
                jcn z,PCPY1
                dac
                xch R7
                ld RB
                dac
                xch RB
                jun COPYC1

PCPY1           ld RB
                jcn z,DIV
                dac
                xch RB
                src P5
                ldm 0
                wrm
                jun PCPY1

DIV             ldm 10
                xch RC
SUB0            clb
                xch R3
SUB1            clb
                xch R5
                ld RB
                xch R7
                src P2
SUB2            rdm
                src P3
                sbm
                jcn c,COMPL1
                add RC
                clc
COMPL1          cmc
                src P2
                wrm
                inc R5
                src P2
                isz R7,SUB2
                ld R5
                jcn z,CHKCY
                rdm
                sub R7
                wrm
                cmc
CHKCY           jcn c,CYOUT
                inc R3
                jun SUB1
CYOUT           ld RB
                xch R7
                clb
                xch R5
ADD4            src P3
                rdm
                src P2
                adm
                daa
                wrm
                inc R5
                isz R7,ADD4
                ld R5
                jcn z,SKADD
                tcc
                src P2
                adm
                wrm
SKADD           src P4
                ld R3
                wrm
                ld R9
                jcn z,ENDDIV
                dac
                xch R9
                isz RB,SUB0
ENDDIV          clb
                xch RB
                ld RF
                xch R7
COPYC2          src P3
                rdm
                src P5
                wrm
                inc RB
                isz R7,COPYC2
                ld RB
                jcn z,PSTFIL
FILLZ           src P5
                clb
                wrm
                isz RB,FILLZ
PSTFIL          bbl 0
DOVRFL          bbl 1

                org 0F00H

;-----------------------------------------------------------------------------------------
; display all 10 digits, using address in p2
;-----------------------------------------------------------------------------------------

display:        src p2
                rdm
                xch r0
                inc r5                  ; increment P2 to point to digit1
                src p2
                rdm
                xch r1
                fim p1, FP_D01
                jms displaydigit
                inc r5

                src p2
                rdm
                xch r0
                inc r5                  ; increment P2 to point to digit1
                src p2
                rdm
                xch r1
                fim p1, FP_D23
                jms displaydigit
                inc r5                

                src p2
                rdm
                xch r0
                inc r5                  ; increment P2 to point to digit1
                src p2                
                rdm
                xch r1
                fim p1, FP_D45
                jms displaydigit
                inc r5

                src p2
                rdm
                xch r0
                inc r5                  ; increment P2 to point to digit1
                src p2
                rdm
                xch r1
                fim p1, FP_D67
                jms displaydigit
                inc r5

                src p2
                rdm
                xch r0
                inc r5                  ; increment P2 to point to digit1
                src p2
                rdm
                xch r1
                fim p1, FP_D89
                jms displaydigit

                ldm 0                   ; restore R5 back to 0
                xch r5
                bbl 0

;------------------------------------------------------------------------------------------
; set the display mask so that all leading zeros are hidden
; P2 is set to RAM variable
;------------------------------------------------------------------------------------------

setdispmask:    ldm 09H
                xch r5
setdispmasklp:  src p2
                rdm
                jcn zn, setdispnz
                ld r5
                dac
                xch r5
                jcn c, setdispmasklp    ; dac will set carry to 0 on borrow
setdispnz:
                ; at this point, R5 has the index
                ; R5 = 0x0F if no digits were set
                ; R5 = 0x00 if least significant digit is set
                ; ...
                ; R6 = 0x09 if most significant digit is set 

                fim P0,lo(hdispmask)
                ld r5
                iac                     ; increment so that R5=0 on no digit, R5=1 on least significant digit, etc
                clc                     ; clear carry in preparation for 'add with carry' instruction
                add R1
                jcn cn,sdmnocarry1      ; jump if no carry (overflow) from the addition of R1 to the accumulator
                inc R0
sdmnocarry1:    xch R1
                fin P1

                ldm CMRAM3
                dcl
                fim p7, FP_LATDB1
                src p7
                ld r2
                wr1
                ld r3
                wr0
                ldm CMRAM0
                dcl

                fim P0,lo(ldispmask)
                ld r5
                iac
                clc    
                add R1
                jcn cn,sdmnocarry2
                inc R0
sdmnocarry2:    xch R1
                fin p1

                ldm CMRAM3
                dcl
                fim p7, FP_LATB0
                src p7
                ld r2
                wr1
                ld r3
                wr0
                ldm CMRAM0
                dcl
                bbl 0

hdispmask:      data   0,   0,   0,   0,   0,   0,   0,   0,    0,  10H,  30H
ldispmask:      data 01H, 01H, 03H, 07H, 0FH, 1FH, 3FH, 7FH, 0FFH, 0FFH, 0FFH       


;-----------------------------------------------------------------------------------------
; display the two digits in P0 to the display in P1
;-----------------------------------------------------------------------------------------

displaydigit:   ldm CMRAM3
                dcl
                src p1
                ld r1
                wr1
                ld r0
                wr0
                ldm CMRAM0
                dcl
                bbl 0

;-----------------------------------------------------------------------------------------
; turn on all display digits
;-----------------------------------------------------------------------------------------                

displayon:      ldm CMRAM3
                dcl

                fim p7, FP_LATB0        ; first 8 digits on
                src p7
                ldm 0FH
                wr1
                ldm 0FH                 ; ends up in last digit
                wr0

                fim p7, FP_LATDB1       ; last 2 digits on
                src p7
                ldm 03H                 ; ended up in D67 ??
                wr1
                ldm 00H
                wr0

;-----------------------------------------------------------------------------------------
; check the front panel for a keypress
; if key pressed, return with it in R1, and carry set
;-----------------------------------------------------------------------------------------

fp_getkey:      ldm CMRAM3
                dcl
                fim p7, FP_KBD
                src p7
                rd0                     ; read low nibble
                cma                     ; compliment switch bits
                clc
                rar                     ; rotate out the keydown bit
                jcn cn, fp_nolkey

                xch r1                  ; save keypress in r1
                ldm CMRAM0
                dcl                
                stc
                bbl 1

fp_nolkey:      ldm CMRAM3
                dcl
                fim p7, FP_KBD
                src p7
                rd0                     ; re-read the low nibble, because serout may have changed our latch
                rd1                     ; read high nibble
                cma                     ; compliment switch bits
                stc                     ; set the high bit, so it rotates in
                rar                     ; rotate out the keydown bit
                jcn cn, fp_nokey

                xch r1                  ; save keypress in r1
                ldm CMRAM0
                dcl                
                stc
                bbl 1

fp_nokey:       ldm CMRAM0
                dcl
                xch r1
                clc
                bbl 0

;-------------------------------------------------------------------------------
; clear RAM register pointed to by P2.
;-------------------------------------------------------------------------------
clrram:         ldm 0
clrram1:        src P2
                wrm                     ; write zero into RAM
                isz R5,clrram1          ; 16 times (zero all 16 characters)
                wr0                     ; clear all 4 status characters
                wr1
                wr2
                wr3
                bbl 0

                bbl 0

                end