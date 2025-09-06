CR              equ 0DH
LF              equ 0AH
ESCAPE          equ 1BH

; I/O port addresses
SERIALPORT      equ 00H                 ; Address of the serial port. The least significant bit of port 00 is used for serial output.
LEDPORT         equ 40H                 ; Address of the port used to control the red LEDs. "1" turns the LEDs on.
GPIO            equ 80H                 ; 4265 General Purpose I/O device address

SWITCHPORT      equ 00H

MCS0PORT        equ 0A0H
MCS0PORT_1      equ 0A1H
MCS0PORT_2      equ 0A2H
MCS0PORT_4      equ 0A4H

; 4265 Modes:   WMP                 Port:   W   X   Y   Z
GPIOMODE0       equ 0000B               ;   In  In  In  In (reset)
GPIOMODE4       equ 0100B               ;   Out Out Out Out
GPIOMODE5       equ 0101B               ;   In  Out Out Out
GPIOMODE6       equ 0110B               ;   In  In  Out Out
GPIOMODE7       equ 0111B               ;   In  In  In  Out
GPIOMODE12      equ 1100B               ;   Out Out IO  Ctl

CMRAM0          equ 0000B
CMRAM1          equ 0001B
CMRAM2          equ 0010B
CMRAM3          equ 0100B

; each 4002 RAM chip consists of 4 registers.
; each register consists of 16 main memory characters plus 4 status characters
CHIP0REG0       equ 00H                 ; 4002 data ram chip 0, registers 00-0FH
CHIP0REG1       equ 10H                 ; 4002 data ram chip 0, registers 10-1FH
CHIP0REG2       equ 20H                 ; 4002 data ram chip 0, registers 20-2FH
CHIP0REG3       equ 30H                 ; 4002 data ram chip 0, registers 30-3FH
CHIP1REG0       equ 40H                 ; 4002 data ram chip 1, registers 40-4FH
CHIP1REG1       equ 50H                 ; 4002 data ram chip 1, registers 50-5FH
CHIP1REG2       equ 60H                 ; 4002 data ram chip 1, registers 60-6FH
CHIP1REG3       equ 70H                 ; 4002 data ram chip 1, registers 70-7FH

accumulator     equ CHIP0REG0           ; multi-digit addition demo
addend          equ CHIP0REG1           ; multi-digit addition demo
minuend         equ CHIP0REG1           ; multi-digit subtraction demo
subtrahend      equ CHIP0REG2           ; multi-digit subtraction demo
multiplicand    equ CHIP0REG1           ; multi-digit multiplication demo
multiplier      equ CHIP0REG2           ; multi-digit multiplication demo
product         equ CHIP0REG0           ; multi-digit multiplication demo
dividend        equ CHIP0REG0           ; multi-digit division demo
divisor         equ CHIP0REG2           ; multi-digit division demo
quotient        equ CHIP0REG3           ; multi-digit division demo
remainder       equ CHIP0REG1           ; multi-digit division demo
randomnumber    equ CHIP0REG0           ; number guessing game
increment       equ CHIP0REG1           ; number guessing game
guess           equ CHIP0REG2           ; number guessing game
attempts        equ CHIP0REG3           ; number guessing game
grid            equ CHIP0REG2           ; tic-tac-toe game
calcResults     equ CHIP0REG3           ; tic-tac-toe game

; Scott's front panel

FP_D01          equ 000H
FP_D23          equ 001H
FP_D45          equ 002H
FP_D67          equ 003H
FP_D89          equ 004H
FP_DP           equ 005H
FP_LATB0        equ 006H
FP_LATDB1       equ 007H

;FP_D01          equ 000H
;FP_D23          equ 008H
;FP_D45          equ 010H
;FP_D67          equ 018H
;FP_D89          equ 020H
;FP_DP           equ 028H
;FP_LATB0        equ 030H
;FP_LATDB1       equ 038H

FP_KBD          equ 020H