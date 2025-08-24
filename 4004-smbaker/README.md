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
