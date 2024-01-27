/*
 * File:   main.c
 * Author: Microchip Technology Inc.
 *
 * Created on July 28, 2020 10:34 AM
 */

// ATmega4809 Configuration Bit Settings

// 'C' source line config statements

// After any reset, CLR_PER = CLK_MAIN/Prescaler = 20MHz / 6 = 3.3MHz
#define F_CPU (3300000UL)

#include <xc.h>
#include <util/delay.h>

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

    while (1) {
		PORTF.OUTTGL = PIN5_bm; // toggle PF5
		_delay_ms(500);
    }

    return 0;
}
