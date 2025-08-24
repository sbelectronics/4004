;-----------------------------------------------------------------------------------------
; 9600 bps N-8-1 serial function 'getchar'
; wait for a character from the serial input port (TEST input on the 4004 CPU).
; NOTE: the serial input line is inverted by hardware before it gets to the TEST input;
; i.e. TEST=0 when the serial line is high and TEST=1 when the serial line is low,
; therefore the sense of the bit needs to be inverted in software. 
; returns the 8 bit received character in P1 (R2,R3). also uses P7 (R14,R15).
;-----------------------------------------------------------------------------------------              
getchar:        jcn t,$                 ; wait for the start bit
getchar0:       ldm 16-4                ; 4 bits
                xch R14                 ; R14 is the counter for the first four bits (0-3)
                ldm 16-3
                xch R15
                isz R15,$               ; 12 cycles between start bit and bit 0

; receive bits 0-3
getchar1:       jcn tn,getchar2         ; jump if the test input==1
                stc                     ; if test input==0, then cy=1
                jun getchar3
getchar2:       clc                     ; if test input==1, then cy=0
                jun getchar3
getchar3:       rar                     ; rotate carry into accumulator
                nop                     ; 9 cycles/bit (error=-0.645 cycle/bit)
                isz r14, getchar1       ; repeat until all 4 bits (0-3) received.  phase(here)= 2.355 -0.645*3 = 0.42cycle
                                        
                xch R3                  ; save received bits 0-3 in R3
                ldm 16-4
                xch R14                 ; R14 is the counter for the next 4 bits (bits 4-8)

; receive bits 4-8                                    
getchar4:       jcn tn,getchar5         ; jump if the test input==1
                stc                     ; if test input==0, then cy=1
                jun getchar6
getchar5:       clc                     ; if test input==1, then cy=0
                nop
                nop
getchar6:       rar                     ; rotate received bit into accumulator
                nop                     ; 9 cycles/bit
                isz R14,getchar4        ; repeat until 4 bits (4-8) received.
                xch R2                  ; save received bits 4-7 in R2
; check the stop bit...
                jcn tn, getchar7        ; jump if the stop bit = 1
                bbl 1                   ; else return 1 to indicate stop bit was 0 (timing error)
getchar7:       bbl 0                   ; return 0 to indicate correct timing
