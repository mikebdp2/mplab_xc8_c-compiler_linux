/*
 * Find the highest PORTC value read, storing this into the object max
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

GLOBAL  max                 ;make this global so it is watchable when debugging
	
skipnc  MACRO
	btfsc      CARRY
	ENDM

;objects in bank 0 memory
PSECT udata_bank0
max:
	DS         1                   ;reserve 1 byte for max
tmp:
	DS         1                   ;reserve 1 byte for tmp

PSECT resetVec,class=CODE,delta=2
resetVec:
	PAGESEL    main                ;jump to the main routine
	goto       main

/* find the highest PORTC value read, storing this into
   the object max */
PSECT code
main:
        ;set up the oscillator
        movlw	   0x62
        movlb	   17
        movwf	   OSCCON1
        movlw	   2
        movwf	   OSCFRQ
        PAGESEL    loop                ;ensure subsequent jumps are correct
	BANKSEL    max                 ;starting point
	clrf       BANKMASK(max)
	BANKSEL    ANSELC
	clrf       BANKMASK(ANSELC)    ;select digital input for port C
loop:
	BANKSEL    PORTC               ;read and store port value
	movf       BANKMASK(PORTC),w
	BANKSEL    tmp
	movwf      BANKMASK(tmp)
	subwf      max^(tmp&0ff80h),w  ;is this value larger than max?
	skipnc
	goto       loop                ;no - read again
	movf       BANKMASK(tmp),w     ;yes - record this new high value
	movwf      BANKMASK(max)
	goto       loop                ;read again

	END        resetVec	