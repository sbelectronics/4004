;---------------------------------------------------------------------------------------------------------------------------------
; Copyright 2025 Scott Baker
;---------------------------------------------------------------------------------------------------------------------------------

;---------------------------------------------------------------------------------------------------------------------------------
; UART Serial IO Functions.
;
; Use this instead of bbser.inc.
;
; Assumes an 8251 UART on address E0/E1 on the P4265. The lower nibbles use rd0/wr0 and the upper nibbles use rd1/wr1.
;---------------------------------------------------------------------------------------------------------------------------------

UARTDATA        equ     0E0H
UARTSTAT        equ     0E1H


;--------------------------------------------------------------------------------------------------
; Put character to UART
; in addition to P1 (R2,R3) also uses P7 (R14,R15)
; preserves the character in P1.
;--------------------------------------------------------------------------------------------------
putchar:        ldm CMRAM3
                dcl                     ; switch to RAM3

                fim p7, UARTSTAT
                src p7
pcwait:         rd0
                rar                     ; rotate TXRDY to CY
                jcn nc, pcwait          ; loop if CY == 0

                fim p7, UARTDATA
                src p7

                ld r2                   ; load high nibble
                wr1
                ld r3                   ; load low nibble
                wr0                     ; write to device

                ldm CMRAM0
                dcl                     ; restore RAM0
                bbl 0

;-----------------------------------------------------------------------------------------
; Get character from uart
; returns the 8 bit received character in P1 (R2,R3). also uses P7 (R14,R15).
;-----------------------------------------------------------------------------------------          

getchar:        ldm CMRAM3
                dcl                     ; switch to RAM3

                fim p7, UARTSTAT
                src p7
gcwait:         rd0
                rar
                rar                     ; rotate RXRDY to CY
                jcn nc, gcwait          ; loop if CY == 0

getchar1:       fim p7, UARTDATA
                src p7
                rd0                     ; read from device and load low nibble
                xch r3
                rd1                     ; read high nibble
                xch r2

                ldm CMRAM0
                dcl
                bbl 0

; getchar0 does not wait for the start bit

getchar0:       ldm CMRAM3
                dcl
                jun getchar1

;-----------------------------------------------------------------------------------------
; Return 1 if character is ready
; destroys P7
;-----------------------------------------------------------------------------------------     

readychar:      ldm CMRAM3
                dcl

                fim p7, UARTSTAT
                src p7
                rd0
                rar
                rar                     ; rotate RXREADY to CY
                jcn nc, nocharready

                ldm CMRAM0
                dcl
                bbl 1

nocharready:    ldm CMRAM0
                dcl
                bbl 0

;-----------------------------------------------------------------------------------------
; Return 1 if character is ready, then eat it
; destroys P7
;-----------------------------------------------------------------------------------------     

readychareat:   ldm CMRAM3
                dcl

                fim p7, UARTSTAT
                src p7
                rd0
                rar
                rar                     ; rotate RXREADY to CY
                jcn nc, nocharready2

                fim p7, UARTDATA        ; point to UART data reg
                src p7
                rd0                     ; eat the character

                ldm CMRAM0
                dcl
                bbl 1

nocharready2:   ldm CMRAM0
                dcl
                bbl 0

;-----------------------------------------------------------------------------------------
; Initialize serial port
;-----------------------------------------------------------------------------------------    

serinit:        ldm CMRAM3
                dcl                     ; switch to RAM3

                fim p7, UARTSTAT
                src p7

                ldm 00H                 ; write 0x00 three times
                wr1
                wr0
                wr1
                wr0
                wr1
                wr0

                ldm 04H                 ; write 0x40 once to force reset
                wr1
                ldm 00H
                wr0

                ldm 04H                 ; write 0x4E for 8N1, x16
                wr1
                ldm 0EH
                wr0

                ldm 03H                 ; write 0x35 for TXEN, RXEN, error reset, rts high
                wr1
                ldm 05H
                wr0

;                fim p7, UARTDATA
;                src p7
;                nop
;                nop
;                nop
;                nop
;                ldm 04H
;                wr1
;                ldm 01H
;                wr0

                ldm CMRAM0              ; back to RAM0
                dcl

                bbl 0

;--------------------------------------------------------------------------------------------------
; ten millisecond delay.  polls the serial port during the delay. 
; returns immediately with accumulator=1 is the start bit is detected.
; 907 cycles * 11.05 microseconds/cycle = 10,022 microseconds delay
;--------------------------------------------------------------------------------------------------
tenmsec:        fim P6,067H
                fim P7,0EFH
delayloop:      isz R12,delayloop
                nop
                isz R13,delayloop
                nop
                isz R14,delayloop
                nop
                isz R15,delayloop
                nop
                jun readychar           ; readychar will return 1 if char detected