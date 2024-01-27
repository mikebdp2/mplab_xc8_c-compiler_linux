/*
 * Take NUM_TO_READ samples of PORTC, storing this into an array accessed
 * using linear memory. NUM_TO_READ must be defined as a command-line macro.
 */

PROCESSOR 16F18446

CONFIG FEXTOSC = OFF	    // External Oscillator mode selection bits->Oscillator not enabled
CONFIG RSTOSC = HFINT1	    // Power-up default value for COSC bits->HFINTOSC (1MHz)
CONFIG CLKOUTEN = OFF	    // Clock Out Enable bit->CLKOUT function is disabled; i/o or oscillator function on OSC2
CONFIG CSWEN = ON	    // Clock Switch Enable bit->Writing to NOSC and NDIV is allowed
CONFIG FCMEN = ON	    // Fail-Safe Clock Monitor Enable bit->FSCM timer enabled

CONFIG MCLRE = ON	    // Master Clear Enable bit->MCLR pin is Master Clear function
CONFIG PWRTS = OFF	    // Power-up Timer Enable bit->PWRT disabled
CONFIG LPBOREN = OFF	    // Low-Power BOR enable bit->ULPBOR disabled
CONFIG BOREN = ON	    // Brown-out reset enable bits->Brown-out Reset Enabled, SBOREN bit is ignored
CONFIG BORV = LO	    // Brown-out Reset Voltage Selection->Brown-out Reset Voltage (VBOR) set to 2.45V
CONFIG ZCDDIS = OFF	    // Zero-cross detect disable->Zero-cross detect circuit is disabled at POR
CONFIG PPS1WAY = ON	    // Peripheral Pin Select one-way control->The PPSLOCK bit can be cleared and set only once in software
CONFIG STVREN = ON	    // Stack Overflow/Underflow Reset Enable bit->Stack Overflow or Underflow will cause a reset

CONFIG WDTCPS = WDTCPS_31   // WDT Period Select bits->Divider ratio 1:65536; software control of WDTPS
CONFIG WDTE = OFF	    // WDT operating mode->WDT Disabled, SWDTEN is ignored
CONFIG WDTCWS = WDTCWS_7    // WDT Window Select bits->window always open (100%); software control; keyed access not required
CONFIG WDTCCS = SC	    // WDT input clock selector->Software Control

CONFIG BBSIZE = BB512	    // Boot Block Size Selection bits->512 words boot block size
CONFIG BBEN = OFF	    // Boot Block Enable bit->Boot Block disabled
CONFIG SAFEN = OFF	    // SAF Enable bit->SAF disabled
CONFIG WRTAPP = OFF	    // Application Block Write Protection bit->Application Block not write protected
CONFIG WRTB = OFF	    // Boot Block Write Protection bit->Boot Block not write protected
CONFIG WRTC = OFF	    // Configuration Register Write Protection bit->Configuration Register not write protected
CONFIG WRTD = OFF	    // Data EEPROM write protection bit->Data EEPROM NOT write protected
CONFIG WRTSAF = OFF	    // Storage Area Flash Write Protection bit->SAF not write protected
CONFIG LVP = ON		    // Low Voltage Programming Enable bit->Low Voltage programming enabled. MCLR/Vpp pin function is MCLR

CONFIG CP = OFF		    // UserNVM Program memory code protection bit->UserNVM code protection disabled

#include <xc.inc>

PSECT code
;read PORTC, storing the result into WREG
readPort:
	BANKSEL   PORTC
	movf      BANKMASK(PORTC),w
	return

GLOBAL count                          ;make this globally accessible
	
PSECT udata_shr
count:
	DS        1                   ;1 byte in common memory

PSECT resetVec,class=CODE,delta=2
resetVec:
	PAGESEL   main
	goto      main

GLOBAL storeLevel                     ;link in with global symbol defined elsewhere

PSECT code
main:
	BANKSEL   ANSELC
	clrf      BANKMASK(ANSELC)
	clrf      count
loop:
	;a call to a routine in the same psect
	call      readPort             ;value returned in WREG
	;a call to a routine in a different module
	PAGESEL   storeLevel
	call      storeLevel           ;expects argument in WREG
	PAGESEL   $
	;wait for a few cycles
	movlw     0xFF
delay:
	decfsz    WREG,f
	goto      delay
	;increment the array index, count, and stop iterating
	;when the final element is reached 
	movlw     NUM_TO_READ
	incf      count,f
	xorwf     count,w
	btfss     ZERO
	goto      loop
	
	goto      $                    ;loop forever

	END	resetVec


