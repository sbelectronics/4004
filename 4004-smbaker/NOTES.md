```
with 4201 board and 11.059Mhz crystal
  baud 8600 to 9250 works
  removing a nop from putchar1 and putchar2, output from 9300 to 10600 works

with 4201 board and 12.288Mhz crystal
  baud 9600 works for output but need 10,050 baud for input to work

v1 board power utilization (w/ onboard 5V DC-DC converters)
  cpu board only - 700ma
  cpu board with front panel, digits off - 1500ma
  cpu board with front panel, all digits on - 2200ma
```
