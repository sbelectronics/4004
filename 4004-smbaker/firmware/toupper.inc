;--------------------------------------------------------------------------------------------------
; If the character in P1 is lowercase, then convert it to uppercase
;--------------------------------------------------------------------------------------------------

toupper:        ldm 06H                 ; check for 0x60 - 0x6F
                clc
                sub r2                  ; subtract high nibble
                jcn z, is6x             ; character is 0x60 - 0x6F, maybe lower case
                ldm 07H                 ; check for 0x70 - 0x7F
                clc
                sub r2                  ; subtract high nibble
                jcn z, is7x             ; character is 0x70 - 0x7F, maybe lower case
                bbl 0                   ; not in the range 0x60 - 0x7F, so cannot be lower case. return.
is6x:           ldm 00H
                clc
                sub r3
                jcn zn, islower         ; it's not 0x60, so it must be lower case
                bbl 0                   ; it's 0x60, which is not lower case
is7x:           ldm 0AH
                clc
                sub r3
                jcn c, islower          ; it's less or equal to 0x7A, so it must be lower case. NOTE: C=0 on out indicates no carry
                bbl 0                   ; it's 0x7B or greater, which is not lower case
islower:        xch r2
                dac
                dac
                xch r2
                bbl 0
