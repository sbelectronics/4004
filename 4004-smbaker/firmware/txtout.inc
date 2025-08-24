;-----------------------------------------------------------------------------------------
; This function is used by all the text string printing functions. If the character in P1 
; is zero indicating the end of the string, returns 0. Otherwise prints the character and 
; increments P0 to point to the next character in the string then returns 1.
;-----------------------------------------------------------------------------------------
txtout:         ld R2                   ; load the most significant nibble into the accumulator
                jcn nz,txtout1          ; jump if not zero (not end of string)
                ld  R3                  ; load the least significant nibble into the accumulator
                jcn nz,txtout1          ; jump if not zero (not end of string)
                bbl 0                   ; end of text found, branch back with accumulator = 0

txtout1:        jms putchar             ; print the character in P1
                inc R1                  ; increment least significant nibble of pointer
                ld R1                   ; get the least significant nibble of the pointer into the accumulator
                jcn zn,txtout2          ; jump if zero (no overflow from the increment)
                inc R0                  ; else, increment most significant nibble of the pointer
txtout2:        bbl 1                   ; not end of text, branch back with accumulator = 1

