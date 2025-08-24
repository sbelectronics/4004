gobank0:        ldm 00h
                jun gobank
gobank1:        ldm 04h
                jun gobank
gobank2:        ldm 08h
                jun gobank
gobank3:        ldm 0Ch
                jun gobank

gobank:         fim P0,00h
                src p0
                wrr
                iac
                fim P0,10h
                src p0
                wrr
                iac
                fim P0,20h
                src p0
                wrr
                iac
                fim P0,30h
                src p0
                wrr
                jun bankstart