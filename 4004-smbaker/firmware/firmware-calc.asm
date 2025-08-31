    PAGE 0                          ; suppress page headings in ASW listing file

;---------------------------------------------------------------------------------------------------------------------------------
; Copyright 2025 Scott Baker, https://www.smbaker.com/
;---------------------------------------------------------------------------------------------------------------------------------

;---------------------------------------------------------------------------------------------------------------------------------
; This firmware is loaded into bank2 and implements a calculator using scott's "front panel" board
;
; The front panel board implements ten 7-segment displays and a 16-button keypad.
; Keys are mapped as follows:
;
;    0 - 9 ... decimal digits
;      A   ... divide
;      B   ... multiply
;      C   ... subtract
;      D   ... plus
;      E   ... equal
;      F   ... clear
;
; This is strictly an integer calculator. Division will round to an integer. Only positive numbers
; are supported. Negative numbers, overflow, division by zero, etc., may lead to undefined behavior.
;
; This firmware does not use the serial port, but will print a short message on serial to inform that
; the calculator demo is running.  All interaction is through the front panel.
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

CALC_ACCUM      equ CHIP0REG0
CALC_ARG        equ CHIP0REG1
CALC_PROD       equ CHIP0REG2
CALC_QUOTIENT   equ CHIP0REG2
CALC_REMAINDER  equ CHIP0REG3
CALC_TMP        equ CHIP1REG0           ; for saving R12,R13 during divide

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

bankstart:      jms prncalcdemo         ; print banner
reset:          ldm KEY_PLUS            ; pre-load PLUS as the current operation
                xch R12                 ; ... that way when we type our first number, it will get added to the accumulator
                fim P2,CALC_ACCUM       ; P2 points the memory register where the first number (and sum) digits are stored (10H-1FH)
                jms clrram              ; clear RAM 10H-1FH
                fim P2,CALC_ARG         ; P2 points the memory register where the second number digits are stored (20H-2FH)
                jms clrram              ; clear RAM 20H-2FH
                jms displayoff          ; all display digits off
                jun kbd_accum

;-----------------------------------------------------------------------------------------
; keypad processor
;-----------------------------------------------------------------------------------------

; kbd_accum is the entry point where we display the accumulator. If you press any key,
; then we will move to kbd_addend which is the loop where we display the argument

kbd_accum:      fim p2, CALC_ACCUM      ; display the accumulator, until a key is pressed
                jms displayoff          ; turn off display while updating
                jms display
                jms setdispmask         ; turn on the apporpriate digits
kbdloop0:       jms fp_getkey
                jcn cn, kbdloop0        ; repeat until a key is pressed
                ld r1
                xch r13                 ; store the incoming key in r13
kbdloop1:       jms fp_getkey
                jcn c, kbdloop1         ; repeat until a key is released                
                jun kbdgotkey           ; process the key and enter the accumulator loop

; kbd_addend is where we display the argument to the operation. For example, with
; addition, we are performing "accumulator = accumulator + addend". Here is where
; the user types in the right-hand argument to the "+" operation. It's the same for
; the other three operations -- though I still call it "addend" in the code.

kbd_addend:     fim p2, CALC_ARG
                jms displayoff          ; turn off display while updating
                jms display
                jms setdispmask         ; turn on the apporpriate digits
kbdloop2:       jms fp_getkey
                jcn cn, kbdloop2        ; repeat until a key is pressed
                ld r1
                xch r13                 ; store the incoming key in r13
kbdloop3:       jms fp_getkey
                jcn c, kbdloop3         ; repeat until a key is released

kbdgotkey:                              ; we have a key... from our own loop, or from kbd_accum's loop.
                ldm 09H
                clc
                sub r13
                jcn cn, kbd_op          ; if r13 >= 10, then it's an operation, not a number

                ldm KEY_EQUAL           ; Was the last operation EQUAL ?
                clc                     ; ... If so, then they pushed EQUAL and started typing
                sub r12                 ; ... a number, which is a new operation.
                jcn nz, notequal
                ldm KEY_PLUS            ; Mark the last op as a plus
                xch r12
                fim p2, CALC_ACCUM      ; ... and clear the accumulator
                jms clrram
notequal:

shiftdig:       fim P3, CALC_ARG        ; only the MSB matters here
                fim P4, CALC_ARG
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
                fim P2, CALC_ARG
                src P2                  ; P2 now points to the destiation for the character
                wrm                     ; save the least significant nibble of the new digit (the binary value for the number) in RAM
                jun kbd_addend

; kbd_op. This is where we handle operations. R13 has the key, which is greater than or equal to 0x0A. R13 is effectively
; the "next" operation. Because this is an "infix" calculator, when the user presses a key like "+", we don't have the right hand
; argument yet, because the user hasn't typed it. So we're always executing the previous operation, which is in R12.

kbd_op:
;                fim p1, "O"            ; debugging
;                jms showregs
                ldm KEY_CLEAR           ; clear is the only operation that works on the current keypress, because it
                clc                     ; terminates any operation in progress. Therefore we check R13, not R12.
                sub r13
                jcn zn, kbd_ck_plus
                jun reset               ; if clear was pressed, reset the program

kbd_ck_plus:    ldm KEY_PLUS
                clc
                sub r12                 ; R12 is the prior ("infix") operation.
                jcn zn, kbd_ck_sub
kbd_op_plus:    fim p1, CALC_ACCUM      ; setup
                fim p2, CALC_ARG        ; ... and perform
                jms addition            ; ... addition
                jun kbd_op_out

kbd_ck_sub:     ldm KEY_MINUS
                clc
                sub r12
                jcn zn, kbd_ck_mult
                fim p1, CALC_ACCUM      ; setup
                fim p2, CALC_ARG        ; ... and perform
                jms subtract            ; ... subtraction
                jun kbd_op_out

kbd_ck_mult:    ldm KEY_TIMES
                clc
                sub r12
                jcn zn, kbd_ck_div
                fim p3, CALC_ACCUM+07H  ; peculiarities of the multiply code. The left-hand argument to multiply
                fim p4, CALC_ACCUM+0CH  ; starts at offset 5. We copy backwards, from the tail in.
                jms shift8
                fim p3, CALC_ARG+07H    ; and the right-hand argument starts at offset 4.
                fim p4, CALC_ARG+0BH
                jms shift8
                fim p1, CALC_ACCUM      ; setup
                fim p2, CALC_ARG        ; ... and perform
                fim p3, CALC_PROD
                ldm 0
                src p1                  ; these flags seem to be inputs to MLRT                   
                wr0                     ; ... in ways that I don't understand
                wr1                     ; ... so make sure they are zero
                src p2
                wr0
                wr1
                jms MLRT                ; ... multiplication
                fim p1, CALC_PROD
                fim p2, CALC_ACCUM
                jms copyram             ; copy the result from CALC_PROD into CALC_ACCUM
;                fim p1, "M"
;                jms showregs
                jun kbd_op_out

kbd_ck_div:     ldm KEY_DIV
                clc
                sub r12
                jcn zn, kbd_ck_equal

                jms save_r12r13         ; divide uses all the registers, so we must save R12 and R13 to RAM.

                fim p1, CALC_ACCUM      ; setup
                fim p2, CALC_REMAINDER  ; ... and perform
                fim p3, CALC_ARG        
                fim p4, CALC_QUOTIENT
                ldm 0                 
                src p1                  ; these flags seem to be unputs to DVRT
                wr0                     ; ... in ways that I don't understand
                wr1                     ; ... so make sure they are zero
                src p3
                wr0
                wr1
                jms DVRT                ; ... division
                jms shiftquot           ; Move the whole part of quotient and zap remainder
                fim p1, CALC_QUOTIENT
                fim p2, CALC_ACCUM
                jms copyram             ; copy result from CALC_QUOTIENT to CALC_ACCUM
;                fim p1, "D"
;                jms showregs

                jms restore_r12r13

                jun kbd_op_out

kbd_ck_equal:   ldm KEY_EQUAL
                clc
                sub r12
                jcn zn, kbd_op_out

                ; Equal is a do-nothing operation. We just go back to printing the
                ; accumulator. There is some special handling int he kbd processing loop
                ; to handle the case where the user starts typing a new number.

                jun kbd_op_out


kbd_op_out:     ld r13                  ; get current keypress keypress
                xch r12                 ; store it in R12 for the next operation
                fim p2, CALC_ARG        ; clear the addend for next operation
                jms clrram                
                jun kbd_accum           ; go back to printing the accumulator

                org 0A00H

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

                org 0B00H

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

                org 0C00H

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

                org 0D00H

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

                org 0E00H

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
                wr0

                fim p7, FP_LATDB1       ; last 2 digits on
                src p7
                ldm 03H                 ; ended up in D67 ??
                wr1
                ldm 00H
                wr0

                ldm CMRAM0
                dcl
                bbl 0

;-----------------------------------------------------------------------------------------
; turn off all display digits
;-----------------------------------------------------------------------------------------                

displayoff:     ldm CMRAM3
                dcl

                fim p7, FP_LATB0        ; first 8 digits on
                src p7
                ldm 00H
                wr1
                wr0

                fim p7, FP_LATDB1       ; last 2 digits on
                src p7
                ldm 00H                 ; ended up in D67 ??
                wr1
                wr0

                ldm CMRAM0
                dcl                
                bbl 0              

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

                org 0F00H

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

;-------------------------------------------------------------------------------
; clear RAM register from P1 to P2
;-------------------------------------------------------------------------------
copyram:
copyram1:       src P1
                rdm                     ; read from P1
                src p2
                wrm                     ; write to P2
                inc R3                  ; increment P1
                isz R5,copyram1         ; 16 times (copy all 16 characters)
                rd0
                wr0
                rd1
                wr1
                rd2
                wr2
                rd3
                wr3
                bbl 0

;-------------------------------------------------------------------------------
; shift 8 bytes of data from P3 to P4, works backwards
; destroys:
;    R1
;-------------------------------------------------------------------------------                

shift8:         ldm (16-9)
                xch R1                  ; loop counter (9 times thru the loop)
                            
shift8lp:       src P3                  ; use address in P3 for RAM reads
                rdm                     ; read digit from source
                src P4                  ; use address in P4 for RAM writes
                wrm                     ; write digit to destination
                ld  R9
                dac                     ; decrement least significant nibble of destination address
                xch R9
                ld  R7
                dac                     ; decrement least significant nibble of source address
                xch R7
                isz R1,shift8lp         ; do all digits
                bbl 0

;-------------------------------------------------------------------------------
; deal with divide. The quotient is a real number with an implied decimal point.
; we only want the integer part of it, which runs from offset 9 to offset 15.
;-------------------------------------------------------------------------------

shiftquot:      fim P3, CALC_QUOTIENT
                fim P4, CALC_QUOTIENT
                ldm 9
                xch R7                  ; P3 starts at address 9
shiftquotlp:    src P3
                rdm
                src P4
                wrm
                inc R9
                isz R7, shiftquotlp     ; increment R9, until it wraps to 0

                ldm 0
                fim P4, CALC_QUOTIENT+7
zapremlp:       src P4
                wrm
                isz R9, zapremlp        ; increment R9, until it wraps to 0
                bbl 0

;-------------------------------------------------------------------------------
; saves R12 and R13
; destorys: P7 (r14,r15)
;-------------------------------------------------------------------------------                       

save_r12r13:    fim p7, CALC_TMP       ; save R12 and R13
                src p7
                ld r12
                wr0
                ld r13
                wr1
                bbl 0

;-------------------------------------------------------------------------------
; restores R12 and R13
; destorys: P7 (r14,r15)
;-------------------------------------------------------------------------------                     

restore_r12r13: fim p7, CALC_TMP      ; restore R12 and R13
                src p7
                rd0
                xch r12
                rd1
                xch r13
                bbl 0

;-------------------------------------------------------------------------------
; Print the contents of RAM register pointed to by P3 as a 16 digit decimal number. R11
; serves as a leading zero flag (1 means skip leading zeros). The digits are stored
; in RAM from right to left i.e. the most significant digit is at location 0FH,
; therefore it's the first digit printed. The least significant digit is at location
; 00H, so it's the last digit printed.
;-------------------------------------------------------------------------------
prndigits:      ldm 16-16
                xch R10                 ; R10 is the loop counter (0 gives 16 times thru the loop for all 16 digits)
                ldm 0FH
                xch R7                  ; make P3 0FH (point to the most significant digit)
                ldm 1
                xch R11                 ; set the leading zero flag ('1' means do not print digit)
prndigits1:     ld R7
                jcn zn,prndigits2       ; jump if this is not the last digit
                ldm 0
                xch R11                 ; since this is the last digit, clear the leading zero flag
prndigits2:     ld R11                  ; get the leading zero flag
                rar                     ; rotate the flag into carry
                src P3                  ; use P3 address for RAM reads
                rdm                     ; read the digit to be printed from RAM
                jcn zn,prndigits3       ; jump if this digit is not zero
                jcn c,prndigits4        ; this digit is zero, jump if the leading zero flag is set
                
prndigits3:     xch R3                  ; this digit is not zero OR the leading zero flag is not set. put the digit as least significant nibble into R3
                ldm 3
                xch R2                  ; most significant nibble ("3" for ASCII characters 30H-39H)
                jms putchar             ; print the ASCII code for the digit
                ldm 0
                xch R11                 ; reset the leading zero flag
prndigits4:     ld  R7                  ; least significant nibble of the pointer to the digit
                dac                     ; decrement to point to the next digit
                xch R7
                isz R10,prndigits1      ; loop 16 times (print all 16 digits)
                bbl 0                   ; finished with all 16 digits

;-----------------------------------------------------------------------------------------
; position the cursor to the start of the next line
;-----------------------------------------------------------------------------------------
newline:        fim P1,CR
                jms putchar
                fim P1,LF
                jun putchar

showregs:       jms putchar             ; assume a character is in P1 to designate the message
                fim P0,lo(acctext)
                fin P1                  ; fetch the character pointed to by P0 into P1
                jms txtout              ; print the character, increment the pointer to the next character
                jcn zn,$-3              ; go back for the next character

                fim p3, CALC_ACCUM
                jms prndigits

                fim P0,lo(argtext)
                fin P1                  ; fetch the character pointed to by P0 into P1
                jms txtout              ; print the character, increment the pointer to the next character
                jcn zn,$-3              ; go back for the next character

                fim p3, CALC_ARG
                jms prndigits
                jms newline
                bbl 0

prncalcdemo:    fim P0,lo(calcdemotext)
                fin P1                  ; fetch the character pointed to by P0 into P1
                jms txtout              ; print the character, increment the pointer to the next character
                jcn zn,$-3              ; go back for the next character
                bbl 0

acctext:        data CR, LF, "accum: ",0
argtext:        data CR, LF, "arg: ",0
calcdemotext:   data CR, LF, "Calculator Demo - Uses Keypad", CR, LF, 0

                end