ASL=/usr/local/bin/asl
P2BIN=/usr/local/bin/p2bin
P2HEX=/usr/local/bin/p2hex

BBDEFINES=-D serbb -D FAKE4201
UARTDEFINES=-D seruart

all: scott-bb.rom firmware-bb.bin bank1test-bb.bin

scott-bb.rom: firmware-bb.bin firmware-bank1-bb.bin bank2test-bb.bin bank3test-bb.bin
	dd if=/dev/zero of=scott-bb.rom bs=1 count=16384
	dd if=firmware-bb.bin of=scott-bb.rom bs=1 seek=0 conv=notrunc
	dd if=firmware-bank1-bb.bin of=scott-bb.rom bs=1 seek=4096 conv=notrunc
	dd if=bank2test-bb.bin of=scott-bb.rom bs=1 seek=8192 conv=notrunc
	dd if=bank3test-bb.bin of=scott-bb.rom bs=1 seek=12288 conv=notrunc

scott-uart.rom: firmware-uart.bin firmware-bank1-uart.bin bank2test-uart.bin bank3test-uart.bin
	dd if=/dev/zero of=scott-uart.rom bs=1 count=16384
	dd if=firmware-uart.bin of=scott-uart.rom bs=1 seek=0 conv=notrunc
	dd if=firmware-bank1-uart.bin of=scott-uart.rom bs=1 seek=4096 conv=notrunc
	dd if=bank2test-uart.bin of=scott-uart.rom bs=1 seek=8192 conv=notrunc
	dd if=bank3test-uart.bin of=scott-uart.rom bs=1 seek=12288 conv=notrunc	

firmware-jim.bin: firmware-jim.asm
	$(ASL) -cpu 4004 -L firmware-jim.asm -o firmware-jim.p
	$(P2BIN) firmware-jim.p firmware-jim.bin

firmware-bb.bin: firmware.asm
	$(ASL) -cpu 4004 -L firmware.asm -o firmware-bb.p $(BBDEFINES)
	$(P2BIN) firmware-bb.p firmware-bb.bin

firmware-bank1-bb.bin: firmware-bank1.asm
	$(ASL) -cpu 4004 -L firmware-bank1.asm -o firmware-bank1-bb.p $(BBDEFINES)
	$(P2BIN) firmware-bank1-b.p firmware-bank1-bb.bin	

bank1test-bb.bin: bank1test.asm
	$(ASL) -cpu 4004 -L bank1test.asm -o bank1test-bb.p $(BBDEFINES)
	$(P2BIN) bank1test-bb.p bank1test-bb.bin

bank2test-bb.bin: bank2test.asm
	$(ASL) -cpu 4004 -L bank2test.asm -o bank2test-bb.p $(BBDEFINES)
	$(P2BIN) bank2test-bb.p bank2test-bb.bin

bank3test-bb.bin: bank3test.asm
	$(ASL) -cpu 4004 -L bank3test.asm -o bank3test-bb.p $(BBDEFINES)
	$(P2BIN) bank3test-bb.p bank3test-bb.bin

firmware-uart.bin: firmware.asm
	$(ASL) -cpu 4004 -L firmware.asm -o firmware-uart.p $(UARTDEFINES)
	$(P2BIN) firmware-uart.p firmware-uart.bin

firmware-bank1-uart.bin: firmware-bank1.asm
	$(ASL) -cpu 4004 -L firmware-bank1.asm -o firmware-bank1-uart.p $(UARTDEFINES)
	$(P2BIN) firmware-bank1-uart.p firmware-bank1-uart.bin

bank1test-uart.bin: bank1test.asm
	$(ASL) -cpu 4004 -L bank1test.asm -o bank1test-uart.p $(UARTDEFINES)
	$(P2BIN) bank1test-uart.p bank1test-uart.bin

bank2test-uart.bin: bank2test.asm
	$(ASL) -cpu 4004 -L bank2test.asm -o bank2test-uart.p $(UARTDEFINES)
	$(P2BIN) bank2test-uart.p bank2test-uart.bin

bank3test-uart.bin: bank3test.asm
	$(ASL) -cpu 4004 -L bank3test.asm -o bank3test-uart.p $(UARTDEFINES)
	$(P2BIN) bank3test-uart.p bank3test-uart.bin

upload-bb: scott-bb.rom
	picorom upload 4004sbc scott-bb.rom 1mbit

upload-uart: scott-uart.rom
	picorom upload 4004sbc scott-uart.rom 1mbit

upload-jim: firmware-jim.bin
	picorom upload 4004sbc firmware-jim.bin 1mbit

flash:
	picorom commit 4004sbc

clean:
	rm -f *.p *.bin *.rom *.lst
