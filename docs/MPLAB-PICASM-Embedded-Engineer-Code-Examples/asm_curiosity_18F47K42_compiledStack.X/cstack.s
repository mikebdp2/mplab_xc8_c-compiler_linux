/* Example code that uses the compiled stack to hold objects local
   to a routine */

CONFIG FEXTOSC = OFF        // External Oscillator Selection->Oscillator not enabled
CONFIG RSTOSC = HFINTOSC_1MHZ    // Reset Oscillator Selection->HFINTOSC, HFFRQ=4MHz, CDIV=4:1
CONFIG CLKOUTEN = OFF       // Clock out Enable bit->CLKOUT function is disabled
CONFIG PR1WAY = ON          // PRLOCKED One-Way Set Enable->PRLOCK cleared/set only once
CONFIG CSWEN = ON           // Clock Switch Enable bit->Writing to NOSC and NDIV is allowed
CONFIG FCMEN = ON           // Fail-Safe Clock Monitor Enable->Clock Monitor enabled

CONFIG MCLRE=EXTMCLR        // If LVP=0, MCLR pin is MCLR; If LVP=1, RE3 pin function is MCLR
CONFIG PWRTS=PWRT_OFF       // PWRT is disabled
CONFIG MVECEN=OFF           // Vector table isn't used to prioritize interrupts
CONFIG IVT1WAY=ON           // IVTLOCK bit can be cleared and set only once
CONFIG LPBOREN=OFF          // ULPBOR disabled
CONFIG BOREN=SBORDIS        // Brown-out Reset enabled, SBOREN bit is ignored
CONFIG BORV=VBOR_2P45       // Brown-out Reset Voltage (VBOR) set to 2.45V
CONFIG ZCD=OFF              // ZCD disabled, enable by setting the ZCDSEN bit of ZCDCON
CONFIG PPS1WAY=ON           // PPSLOCK cleared/set only once; PPS locked after clear/set cycle
CONFIG STVREN=ON            // Stack full/underflow will cause Reset
CONFIG DEBUG=OFF            // Background debugger disabled
CONFIG XINST=OFF            // Extended Instruction Set and Indexed Addressing Mode disabled
 
CONFIG WDTCPS=WDTCPS_31     // Divider ratio 1:65536; software control of WDTPS
CONFIG WDTE=OFF             // WDT Disabled; SWDTEN is ignored
CONFIG WDTCWS=WDTCWS_7      // window open 100%; software control; keyed access not required
CONFIG WDTCCS=SC            // Software Control

CONFIG BBSIZE=BBSIZE_512    // Boot Block size is 512 words
CONFIG BBEN=OFF             // Boot block disabled
CONFIG SAFEN=OFF            // SAF disabled
CONFIG WRTAPP=OFF           // Application Block not incr protected
CONFIG WRTB=OFF             // Configuration registers (300000-30000Bh) not incr-protected
CONFIG WRTC=OFF             // Boot Block (000000-0007FFh) not incr-protected
CONFIG WRTD=OFF             // Data EEPROM not incr-protected
CONFIG WRTSAF=OFF           // SAF not Write Protected
CONFIG LVP=ON               // Low voltage programming enabled, MCLR pin, MCLRE ignored

CONFIG CP=OFF               // PFM and Data EEPROM code protection disabled

#include <xc.inc>

;place the compiled stack in Access bank memory (udata_acs psect)
;use the ?au_  prefix for autos, the ?pa_  prefix for parameters
FNCONF udata_acs,?au_,?pa_

PSECT resetVec,class=CODE,reloc=2
resetVec:
    goto       main

PSECT code
;add needs 4 bytes of parameters, but no autos
FNSIZE add,0,4       ;two 2-byte parameters
GLOBAL ?pa_add
;add the two 'int' parameters, returning the result in the first parameter location
add:
    movf       ?pa_add+2,w,c
    addwf      ?pa_add+0,f,c
    movf       ?pa_add+3,w,c
    addwfc     ?pa_add+1,f,c
    return

;incr needs one 2-byte parameter
FNSIZE incr,0,2
GLOBAL ?pa_incr
;return the additional of the 2-byte parameter with the value in the W register
incr:
    addwf      ?pa_incr+0,c
    movlw      0h
    addwfc     ?pa_incr+1,c
    return

GLOBAL ?au_main
GLOBAL result
result  EQU    ?au_main+0          ;create an alias for this auto location
  
GLOBAL incval
incval EQU     ?au_main+2          ;create an alias for this auto location
  
FNROOT main                        ;this is the root of a call graph
FNSIZE main,4,0                    ;main needs two 2-byte 'autos' (for result and incval)
FNCALL main,add                    ;main calls add
FNCALL main,incr                   ;main calls incr

PSECT code
main:
    clrf       result+0,c
    clrf       result+1,c
    movlw      2                       ;increment amount
    movwf      incval+0,c
    clrf       incval+1,c
loop:
    movff      result+0,?pa_add+0      ;load 1st parameter for add routine
    movff      result+1,?pa_add+1
    movff      incval+0,?pa_add+2      ;load 2nd parameter for add routine
    movff      incval+1,?pa_add+3
    call       add                     ;add result and incval
    movff      ?pa_add+0,result+0      ;store add's return value back to result
    movff      ?pa_add+1,result+1

    movff      incval+0,?pa_incr+0     ;load the parameter for incr routine
    movff      incval+1,?pa_incr+1
    movlw      2
    call       incr                    ;add 2 to incval
    movff      ?pa_incr+0,incval+0     ;store the result of incr back to incval
    movff      ?pa_incr+1,incval+1
    goto       loop

    END        resetVec
