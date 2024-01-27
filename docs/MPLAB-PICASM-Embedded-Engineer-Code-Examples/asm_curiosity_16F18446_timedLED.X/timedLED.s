/*
 * Blink the LED on a PIC16F18446 Curiosity Nano Board
 * using the timer and interrupts to control the flash period.
 */
    
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

GLOBAL resetVec,isr
GLOBAL LEDState             ;make this global so it is watchable when debugging

PSECT bitbss,bit,class=BANK1,space=1
LEDState:
    DS          1           ;a single bit used to hold the required LED state
    
PSECT resetVec,class=CODE,delta=2
resetVec:
    ljmp        start

PSECT isrVec,class=CODE,delta=2
isr:
    ;no context save required in software for this device
    PAGESEL     $           ;select this page for the following goto
    BANKSEL     PIE0        ;for TMR0IE and TMR0IF
    ;for timer interrupts, set the required LED state
    btfsc       TMR0IE
    btfss       TMR0IF
    goto        notTimerInt ;not a timer interrupt
    bcf         TMR0IF
    ;toggle the desired bit state
    movlw       1 shl (LEDState&7)
    BANKSEL     LEDState/8
    xorwf       BANKMASK(LEDState/8),f
notTimerInt:
    ;code to handle other interrupts could be added here
exitISR:
    ;no context restore required in software
    retfie

PSECT code
start:
    ;set up the state of the oscillator and peripherals with RA2 as a digital output driving
    ;the LED, assuming that other registers have not changed from their reset state
    movlw       0x33
    BANKSEL     TRISA
    movwf       TRISA
    movlw       2
    BANKSEL     OSCFRQ
    movwf       OSCFRQ
    ;configure and start timer using interrupts
    movlw       0x89
    BANKSEL     T0CON1
    movwf       T0CON1
    movlw       0x1D
    movwf       TMR0H
    clrf        TMR0L
    BANKSEL     PIE0        ;for TMR0IE and TMR0IF
    bcf         TMR0IF
    bsf         TMR0IE
    movlw       0x80
    BANKSEL     T0CON0
    movwf       T0CON0	
    bsf         GIE
    bsf         PEIE
loop:
    ;copy the desired state to the LED port pin
    BANKSEL     LEDState/8
    btfss       BANKMASK(LEDState/8),LEDState&7
    goto        lightLED
    BANKSEL     PORTA
    bsf         RA2         ;turn LED off
    goto        loop
lightLED:
    BANKSEL     PORTA
    bcf         RA2         ;turn LED on
    goto        loop
    
    END         resetVec