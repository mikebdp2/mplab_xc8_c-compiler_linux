/*
 * File:   main.c
 * Author: Microchip Technology Inc.
 *
 * Created on July 28, 2020 9:55 AM
 */

// ATmega4809 Configuration Bit Settings

// 'C' source line config statements

#include <xc.h>

FUSES = {
	.WDTCFG = 0x00, // WDTCFG {PERIOD=OFF, WINDOW=OFF}
	.BODCFG = 0x00, // BODCFG {SLEEP=DIS, ACTIVE=DIS, SAMPFREQ=1KHZ, LVL=BODLEVEL0}
	.OSCCFG = 0x02, // OSCCFG {FREQSEL=20MHZ, OSCLOCK=CLEAR}
	.SYSCFG0 = 0xC0, // SYSCFG0 {EESAVE=CLEAR, RSTPINCFG=GPIO, CRCSRC=NOCRC}
	.SYSCFG1 = 0x07, // SYSCFG1 {SUT=64MS}
	.APPEND = 0x00, // APPEND
	.BOOTEND = 0x00, // BOOTEND
};

LOCKBITS = 0xC5; // {LB=NOLOCK}

int main(void) {

    PORTF.DIRSET = PIN5_bm; // set PF5 to be output

    PORTF.OUTCLR = PIN5_bm; // clear PF5 - LED on

    //PORTF.OUTSET = PIN5_bm; // set PF5 - LED off

    while (1) {
    }

    return 0;
}
