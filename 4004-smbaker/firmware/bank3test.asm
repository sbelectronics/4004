            cpu 4040                    ; Tell the Macro Assembler AS that this source is for the Intel 4040.

; Conditional jumps syntax for Macro Assembler AS:
; jcn t     jump if test = 0 - positive voltage or +5VDC
; jcn tn    jump if test = 1 - negative voltage or -10VDC
; jcn c     jump if cy = 1
; jcn cn    jump if cy = 0
; jcn z     jump if accumulator = 0
; jcn zn    jump if accumulator != 0

                include "bitfuncs.inc"  ; Include bit functions so that FIN can be loaded from a label (upper 4 bits of address are loped off).
                include "reg4004.inc"   ; Include 4004 register definitions.

                include "const.inc"

                org 0000H               ; beginning of 2732 EPROM
;--------------------------------------------------------------------------------------------------
; Power-on-reset Entry
;--------------------------------------------------------------------------------------------------
                nop                     ; "To avoid problems with power-on reset, the first instruction at
                                        ; program address 0000 should always be an NOP." (dont know why)

pgmstart:       jun gobank3

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

bankstart:      fim P0,lo(banktxt)
                jun pageFprint

pageFprint:     fin P1                  ; fetch the character pointed to by P0 into P1
                jms txtout              ; print the character, increment the pointer to the next character
                jcn zn,pageFprint       ; go back for the next character
                jun gobank0

banktxt:	data    CR,LF,LF,"You are in bank 3",CR,LF,LF,0