/*
 * File:   main.c
 * Author: Microchip Technology Inc.
 *
 * Created on August 3, 2020 10:12 AM
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

// Interrupt function
void __interrupt(PORTF_PORT_vect_num) btnInt(void)
{
    if(PORTF.INTFLAGS == PIN6_bm) // check PF6 interrupt
    {
        PORTF.OUTTGL = PIN5_bm; // toggle LED

        PORTF.INTFLAGS = PIN6_bm; // clear interrupt
    }
}

int main(void)
{
    //LED init
    PORTF.DIRSET = PIN5_bm; // set PF5 to be output
    PORTF.OUTSET = PIN5_bm; // set PF5 - LED off

    //BUTTON init
    //Reset value of all PORTB pins is '0', which is input
    PORTF.PIN6CTRL = PORT_PULLUPEN_bm | PORT_ISC_FALLING_gc; //enable pullups on PF6, IRQ on falling edge

    ei(); //enable global interrupts

    while (1) {
        //wait for button press
    }

    return 0;
}
