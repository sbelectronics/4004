    PAGE 0                          ; suppress page headings in ASW listing file

;---------------------------------------------------------------------------------------------------------------------------------
; Copyright 2025 Scott Baker
;---------------------------------------------------------------------------------------------------------------------------------

;---------------------------------------------------------------------------------------------------------------------------------
; This firmware is loaded into bank1 and is a set of optional functions, like interfacing with my speech boards.
;
; The main firmware file (firmware.asm) is probably what you're looking for.
;---------------------------------------------------------------------------------------------------------------------------------

            cpu 4040                    ; Tell the Macro Assembler AS that this source is for the Intel 4040.

                include "bitfuncs.inc"  ; Include bit functions so that FIN can be loaded from a label (upper 4 bits of address are loped off).
                include "reg4004.inc"   ; Include 4004 register definitions.

                include "const.inc"

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
reset:          jms newline
reset2:         jms ledsoff             ; all LEDs off
reset3:         jms menu                ; print the menu
reset4:         jms getchar             ; wait for a character from serial input, the character is returned in P1
                jms toupper

testfor0:       fim P2,'0'
                jms compare             ; is the character from the serial port '0'?
                jcn nz,testfor1         ; jump if no match
                jun reset2              ; no menu item assigned to '0' yet

testfor1:       fim P2,'1'
                jms compare             ; is the character from the serial port '0'?
                jcn nz,testfor2         ; jump if no match
                jun sp0256mm_entry

testfor2:       fim P2,'2'
                jms compare             ; is the character from the serial port '0'?
                jcn nz,testfor3         ; jump if no match
                jun digimm_entry

testfor3:       fim P2,'3'
                jms compare             ; is the character from the serial port '0'?
                jcn nz,testforA         ; jump if no match
                jun disptest

testforA:       fim P2,'A'
                jms compare
                jcn nz,testforB
                jun gobank0

testforB:       fim P2,'B'
                jms compare
                jcn nz,testforC
                jun gobank1

testforC:       fim P2,'C'
                jms compare
                jcn nz,testforD
                jun gobank2

testforD:       fim P2,'D'
                jms compare
                jcn nz,nomatch
                jun gobank3

nomatch:        jun reset2              ; display the menu options, go back for the next character

;--------------------------------------------------------------------------------------------------
; turn off all four LEDs
;--------------------------------------------------------------------------------------------------
ledsoff:        fim P0,LEDPORT
                src P0
                ldm 0
                wmp                     ; write data to RAM LED output port, set all 4 outputs low to turn off all four LEDs
                bbl 0

;--------------------------------------------------------------------------------------------------
; Compare the contents of P1 (R2,R3) with the contents of P2 (R4,R5).
; Returns 0 if P1 = P2.
; Returns 1 if P1 < P2.
; Returns 2 if P1 > P2.
; Overwrites the contents of P2.
; Adapted from code in the "MCS-4 Micro Computer Set Users Manual" on page 166:
;--------------------------------------------------------------------------------------------------
compare:        xch R4                  ; contents of R7 (high nibble of P3) into accumulator
                clc                     ; clear carry in preparation for 'subtract with borrow' instruction                
                sub R2                  ; compare the high nibble of P1 (R2) to the high nibble of P3 (R6) by subtraction
                jcn cn,greater          ; no carry means that R2 > R6
                jcn zn,lesser           ; jump if the accumulator is not zero (low nibbles not equal)
                clc                     ; clear carry in preparation for 'subtract with borrow' instruction
                xch R5                  ; contents of R6 (low nibble of P3) into accumulator
                sub R3                  ; compare the low nibble of P1 (R3) to the low nibble of P3 (R7) by subtraction
                jcn cn,greater          ; no carry means R3 > R7
                jcn zn,lesser           ; jump if the accumulator is not zero (high nibbles not equal)
                bbl 0                   ; 0 indicates P1=P3
lesser:         bbl 1                   ; 1 indicates P1<P3
greater:        bbl 2                   ; 2 indicates P1>P3

;-----------------------------------------------------------------------------------------
; position the cursor to the start of the next line
;-----------------------------------------------------------------------------------------
newline:        fim P1,CR
                jms putchar
                fim P1,LF
                jun putchar

                org 0200H               ; next page
            
;-----------------------------------------------------------------------------------------
; print the menu options
; note: this function and the text it references need to be on the same page.
;-----------------------------------------------------------------------------------------
menu:           fim P0,lo(menutxt)
                fin P1                  ; fetch the character pointed to by P0 into P1
                jms txtout              ; print the character, increment the pointer to the next character
                jcn zn,$-3              ; go back for the next character
                bbl 0

menutxt:        data CR,LF,LF
                data "1 - SP0256A-AL2 Speech MM",CR,LF
                data "2 - Digitalker Speech MM",CR,LF
                data "3 - Display MM",CR,LF
                data "A - Go Bank 0",CR,LF
                data "B - Go Bank 1",CR,LF
                data "C - Go Bank 2",CR,LF
                data "D - Go Bank 3",CR,LF,LF
                data "Your choice (1-9): ",0

                org 0300H               ; next page

speechmenu:     fim P0,lo(speechmenutxt)  ; display the menu
                fin P1
                jms txtout
                jcn zn,$-3
                bbl 0

speechmenutxt:  data CR,LF,LF
                data "1 - Scott Was Here",CR,LF
                data "2 - This is a single board computer...",CR,LF
                data "Q - Exit",CR,LF,LF
                data "Your choice (1-9): ",0

digimenu:       fim P0,lo(digimenutxt)  ; display the menu
                fin P1
                jms txtout
                jcn zn,$-3
                bbl 0

digimenutxt:    data CR,LF,LF
                data "1 - Digitalker",CR,LF
                data "2 - Time",CR,LF
                data "3 - System Ready",CR,LF
                data "4 - Temperature",CR,LF
                data "Q - Exit",CR,LF,LF
                data "Your choice (1-9): ",0

                org 0E00H               ;next page     

;-----------------------------------------------------------------------------------------
; digitalker multimodule menu
;-----------------------------------------------------------------------------------------

digimm_entry:   jms digimm_umt
                jms newline
                jms ledsoff             ; all LEDs off
digimm_menu:    jms digimenu
digimm4:        jms getchar             ; get and process input
                jms toupper

digimm_test1:   fim P2,'1'
                jms compare             ; is the character from the serial port '1'?
                jcn nz,digimm_test2     ; jump if no match
                fim p0,lo(digithisis)
                jms digimm_says
                jun digimm_menu

digimm_test2:   fim P2,'2'
                jms compare             ; is the character from the serial port '1'?
                jcn nz,digimm_test3     ; jump if no match
                fim p0,lo(digitime)
                jms digimm_says
                jun digimm_menu

digimm_test3:   fim P2,'3'
                jms compare             ; is the character from the serial port '1'?
                jcn nz,digimm_test4     ; jump if no match
                fim p0,lo(digiready)
                jms digimm_says
                jun digimm_menu

digimm_test4:   fim P2,'4'
                jms compare             ; is the character from the serial port '1'?
                jcn nz,digimm_testQ     ; jump if no match
                fim p0,lo(digisensa)
                jms digimm_says
                jun digimm_menu                

digimm_testQ: fim P2,'Q'
                jms compare             ; is the character from the serial port '0'?
                jcn nz,digimm_menu    ; jump if no match
                jun reset2

;-----------------------------------------------------------------------------------------
; unmute the digitalker multimodule
;-----------------------------------------------------------------------------------------

digimm_umt:     ldm CMRAM3
                dcl
                fim p7, MCS0PORT_1
                src p7
                ldm 00                  ; for my digitalker multimodule, 0 is unmute
                wr0
                ldm CMRAM0
                dcl
                bbl 0

;-----------------------------------------------------------------------------------------
; say string in p0 to the the digi multimodule
;-----------------------------------------------------------------------------------------

digimm_says:    ldm CMRAM3
                dcl
                fim p7, MCS0PORT
                src p7
digisayword:    rd0                     ; read status bit
                rar
                jcn cn, digisayword     ; wait until digi idle

                fin P1                  ; read bank

                ldm 0Fh                 ; check to see if P1 == 0FFh
                clc
                sub r2                  ; check high nibble
                jcn zn, digiworddata    ; nope

                ldm 0Fh
                clc
                sub r3                  ; check low nibble
                jcn z, digidone         ; FF = we are done

                fim p7, MCS0PORT_2      ; F0-FE, select the bank port
                src p7
                ld r3                   ; load low nibble
                wr0
                fim p7, MCS0PORT        ; back to the data port
                src p7
                jun diginext            ; go to next byte

digiworddata:   ld r2
                wr1
                ld r3       
                wr0

diginext:       inc R1                  ; increment least significant nibble of pointer
                ld R1                   ; get the least significant nibble of the pointer into the accumulator
                jcn zn,diginowrap       ; jump if zero (no overflow from the increment)
                inc R0                  ; else, increment most significant nibble of the pointer
diginowrap:     jun digisayword

digidone:       ldm CMRAM0              ; yep - reset DCL to CMRAM0 and return
                dcl
                bbl 0

digithisis:     data 0F0H ; bank 0
                data 0    ; this is digitalker
                data 0FFH

digitime:       data 0F0H ; bank 0
                data 138  ; the
                data 139  ; time
                data 96   ; is
                data 5    ; five
                data 46   ; o
                data 8    ; eight
                data 47   ; p
                data 44   ; m
                data 0FFH

digiready:      data 0F1H ; bank 1
                data 113  ; system
                data 0F0H ; bank 0
                data 127  ; ready
                data 0FFH

digisensa:      data 0F6H ; bank 6
                data 47 ; hello
                data 50 ; the temperature is
                data 25 ; seventy
                data 2 ; two
                data 51 ; degrees
                data 57 ; have a good day
                data 0FFH

                org 0F00H               ;next page

;-----------------------------------------------------------------------------------------
; sp0256A-AL2 multimodule menu
;-----------------------------------------------------------------------------------------

sp0256mm_entry: jms sp0256mm_umt
                jms newline
                jms ledsoff             ; all LEDs off
sp0256mm_menu:  jms speechmenu
sp0256mm4:      jms getchar             ; get and process input
                jms toupper

sp0256mm_test1: fim P2,'1'
                jms compare             ; is the character from the serial port '1'?
                jcn nz,sp0256mm_test2   ; jump if no match
                fim p0,lo(swhphones)
                jms sp0256mm_says
                jun sp0256mm_menu

sp0256mm_test2: fim P2,'2'
                jms compare             ; is the character from the serial port '1'?
                jcn nz,sp0256mm_testQ   ; jump if no match
                fim p0,lo(sbcphones)
                jms sp0256mm_says
                jun sp0256mm_menu

sp0256mm_testQ: fim P2,'Q'
                jms compare             ; is the character from the serial port '0'?
                jcn nz,sp0256mm_menu    ; jump if no match
                jun reset2

;-----------------------------------------------------------------------------------------
; unmute the sp0256 multimodule
;-----------------------------------------------------------------------------------------

sp0256mm_umt:   ldm CMRAM3
                dcl
                fim p7, MCS0PORT_4
                src p7
                ldm 01
                wr0
                ldm CMRAM0
                dcl
                bbl 0

;-----------------------------------------------------------------------------------------
; say string in p0 to the the sp0256 multimodule
;-----------------------------------------------------------------------------------------

sp0256mm_says:  ldm CMRAM3
                dcl
                fim p7, MCS0PORT_2
                src p7
sayphon:        rd0                     ; read status bit
                rar
                jcn cn, sayphon         ; wait until sp0256 idle

                fin P1                  ; read byte of speech data

                ldm 0Fh                 ; check to see if P1 == 0FFh
                clc
                sub r2
                jcn zn, notdoneblock    ; nope
                ldm 0Fh
                clc
                sub r3
                jcn zn, notdoneblock    ; nope

                ldm CMRAM0              ; yep - reset DCL to CMRAM0 and return
                dcl
                bbl 0

notdoneblock:   ld r2                   ; output the speech data in P1
                wr1
                ld r3
                wr0

                inc R1                  ; increment least significant nibble of pointer
                ld R1                   ; get the least significant nibble of the pointer into the accumulator
                jcn zn,talknowrap       ; jump if zero (no overflow from the increment)
                inc R0                  ; else, increment most significant nibble of the pointer
talknowrap:     jun sayphon

                ; Scott Was Here
swhphones:      data    037H,02aH,018H,011H,011H,003H,02eH,018H,02bH,003H,01bH,013H,00eH,003H
                data    0FFH

                ; This is a single board computer that uses the Intel Forty O Four or the Forty Forty My crow Processor
sbcphones:      data    012H,00cH,037H,003H,00cH,02bH,003H,00fH,003H,037H,00cH,02cH,03dH,00fH
                data    02dH,003H,01cH,035H,00eH,015H,003H,02aH,018H,010H,009H,031H,01fH,011H
                data    033H,003H,012H,01aH,011H,003H,031H,01fH,02bH,00cH,02bH,003H,012H,00fH
                data    003H,00cH,00bH,011H,007H,02dH,003H,028H,017H,00eH,011H,013H,003H,035H
                data    003H,028H,017H,00eH,003H,017H,00eH,003H,012H,00fH,003H,028H,017H,00eH
                data    011H,013H,003H,028H,017H,00eH,011H,013H,003H,010H,006H,003H,02aH,00eH
                data    035H,003H,009H,00eH,035H,037H,007H,037H,033H,003H
                data    0FFH

;-----------------------------------------------------------------------------------------
; display multimodule test
;-----------------------------------------------------------------------------------------

disptest:       ldm CMRAM3
                dcl
                fim p7, MCS0PORT
                src p7
                ldm 01
                wr1
                ldm 02
                wr0
                fim p7, MCS0PORT_1
                src p7
                ldm 03
                wr1
                ldm 04
                wr0
                fim p7, MCS0PORT_2
                src p7
                ldm 05
                wr1
                ldm 06
                wr0
                ldm CMRAM0
                dcl
                bbl 0

                include "toupper.inc"

                end
