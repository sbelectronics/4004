;-----------------------------------------------------------------------------------------
; 45250 cycles * 11.05 microseconds/cycle = 500,012 microseconds delay
;-----------------------------------------------------------------------------------------
halfsecond: fim P6,0A2H
            fim P7,0DAH
            nop
            
dly:        isz R12,dly
            isz R13,dly
            isz R14,dly
            isz R15,dly
            bbl 0    
