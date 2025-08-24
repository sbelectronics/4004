# Scott's 4004 / 4040 Single Board Computer

https://www.smbaker.com/

## Introduction

I designed a 4004 / 4040 single board computer, based loosely on [Jim Loos's project](https://github.com/jim11662418/Intel_4004_Single_Board_Computer). The basic peripherals that my SBC supports are:

* Intel 4004 or 4040 4-bit microprocessor. You'll find the 4040 much cheaper and easier to source than the 4004.

* P4201 or INS4201 clock generator.

* P4289 Standard Memory Interface. Allows standard 8-bit EPROMs to be used with the 4-bit 4004/4040.

* P4265 Programmable General Purpose IO Device. Among other things, allows 256 4-bit IO ports to be used with the 4-bit 4004/4040.

* Up to 2560 bits of RAM (aka 320 bytes).

Add-on functionality includes:

* optional "bit-bang" serial port for console IO.

* optional 8251 serial port for console IO. You'll need to choose either this option or the bit-bang option.

* One "multimodule" socket for interfacing standard 8-bit multimodule add-on boards. I have a number of options available elsewhere on my site, including speech synthesizers, sound cards, display boards, etc.

* RC2014 style bus connector, supporting 8-bit IO. Does not support ROM/RAM.

* Memory mapper capable of extending the ROM range from 4KB to 16KB, capable of mapping in 1KB pages. Uses a 74HCT670 4-bit register file.

* Onboard -10V DC-DC converter, allowing single 5V supply operation for the board.

* 4 bit LED display.

* 4 dip switch input.

## Design Notes

The P4265 is attached to CMRAM3 and will require a DCL instruction to use it. This differ's from Jim's P4265 which is attached to
CMRAM0. The P4265 is used by the firmware in Mode 12, which allows it to address 256 4-bit ports. By using a couple latches and
transceivers, I'm able to extend that to 256 8-bit ports. Which looks more-or-less to the outside world like the IO space of a
typical 8-bit computer.

Because the P4265 is used in Mode-12 it prohibits using RAM in that bank. The 256 addresses supported by Mode 12 occupy the 256
addresses the RAM bank would have used. You can still use RAM in banks CMRAM0, CMRAM1, and CMRAM3.

To read an 8-bit value from PORTNUM into P1:

```
LDM CMRAM3          ; select RAM3
DCL
FIM P7, PORTNUM     ; set the port number
SRC P7
RD0                 ; read low nibble (latches the high nibble as a side-effect)
XCH R3              ; store low nibble in R3
RD1                 ; read the high nibble
XCH R2              ; store the high nibble in R2
LDM CMRAM0          ; back to RAM0, for consistency's sake
DCL
```

To write an 8-bit value from P1 to PORTNUM

```
LDM CMRAM3          ; select RAM3
DCL
FIM P7, PORTNUM     ; set the port number
SRC P7
LD R2               ; load the high nibble
WR1                 ; write the high nibble into a latch
LD R3               ; load the low nibble
WR0                 ; write the low nibble (and the high-nibble that was latched)
LDM CMRAM0          ; back to RAM0, for consistency's sake
DCL
```

Examples of this are preset in uartser.inc, as well as in the 8-bit multimodule code in firmware-bank1.asm
