;-----------------------------------------------------------------------------------------
; prints the contents of P0 as two hex digits
;-----------------------------------------------------------------------------------------
print2hex:      ld R0                   ; most significant nibble
                jms print1hex
                ld R1                   ; least significant nibble, fall through to the print1hex subroutine below

;-----------------------------------------------------------------------------------------
; print the accumulator as one hex digit, destroys contents of the accumulator
;-----------------------------------------------------------------------------------------
print1hex:      fim P1,30H              ; R2 = 3, R3 = 0;
                clc
                daa                     ; for values A-F, adds 6 and sets carry
                jcn cn,print1hex1       ; no carry means 0-9
                inc R2                  ; R2 = 4 for ascii 41h (A), 42h (B), 43h (C), etc
                iac                     ; we need one extra for the least significant nibble
print1hex1:     xch R3                  ; put that value in R3, fall through to the putchar subroutine below
                jun putchar
