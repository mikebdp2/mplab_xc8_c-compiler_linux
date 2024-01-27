PROCESSOR 16F18446

#include <xc.inc>

GLOBAL storeLevel                     ;make this globally accessible
GLOBAL count                          ;link in with global symbol defined elsewhere

PSECT udata_shr
tmp:
	DS	 1                    ;1 byte in common memory

;define NUM_TO_READ bytes of linear memory, at banked address 0x120 
DLABS  1,0x120,NUM_TO_READ,levels

PSECT code
;store byte passed via WREG into the count-th element of the
;linear memory array, levels
storeLevel:
	movwf     tmp                 ;store the parameter
	movf      count,w             ;add the count index to...
	addlw     low(levels)         ;the linear base address of the array...
	movwf     FSR1L               ;storing the result in FSR1
	movlw     high(levels)
	clrf      FSR1H
	addwfc    FSR1H
	movf      tmp,w               ;retrieve the parameter
	movwf     INDF1               ;access levels using linear memory
	return

	END


