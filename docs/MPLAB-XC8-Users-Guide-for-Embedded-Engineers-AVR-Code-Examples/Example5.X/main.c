/*
    (c) 2018 Microchip Technology Inc. and its subsidiaries. 
    
    Subject to your compliance with these terms, you may use Microchip software and any 
    derivatives exclusively with Microchip products. It is your responsibility to comply with third party 
    license terms applicable to your use of third party software (including open source software) that 
    may accompany Microchip software.
    
    THIS SOFTWARE IS SUPPLIED BY MICROCHIP "AS IS". NO WARRANTIES, WHETHER 
    EXPRESS, IMPLIED OR STATUTORY, APPLY TO THIS SOFTWARE, INCLUDING ANY 
    IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY, AND FITNESS 
    FOR A PARTICULAR PURPOSE.
    
    IN NO EVENT WILL MICROCHIP BE LIABLE FOR ANY INDIRECT, SPECIAL, PUNITIVE, 
    INCIDENTAL OR CONSEQUENTIAL LOSS, DAMAGE, COST OR EXPENSE OF ANY KIND 
    WHATSOEVER RELATED TO THE SOFTWARE, HOWEVER CAUSED, EVEN IF MICROCHIP 
    HAS BEEN ADVISED OF THE POSSIBILITY OR THE DAMAGES ARE FORESEEABLE. TO 
    THE FULLEST EXTENT ALLOWED BY LAW, MICROCHIP'S TOTAL LIABILITY ON ALL 
    CLAIMS IN ANY WAY RELATED TO THIS SOFTWARE WILL NOT EXCEED THE AMOUNT 
    OF FEES, IF ANY, THAT YOU HAVE PAID DIRECTLY TO MICROCHIP FOR THIS 
    SOFTWARE.
*/

#include "mcc_generated_files/mcc.h"
#include <util/delay.h>

#define LED_ON_OFF_DELAY 500
#define NUM_EE_VALUES 8
#define EE_ADR_START 8

eeprom_adr_t ee_address;
nvmctrl_status_t status;
volatile uint8_t RAMArray[NUM_EE_VALUES];

/*
    Main application
*/
int main(void)
{
    /* Initializes MCU, drivers and middleware */
    SYSTEM_Initialize();
    
    /* Declare loop variable */    
    uint8_t i;

    if (!FLASH_Initialize()) {
        
        ee_address = EE_ADR_START;
    
        // Write EEPROM Data
        for(i=0; i<NUM_EE_VALUES; i++){
            status = FLASH_WriteEepromByte(ee_address, i);
            ee_address++;
        }
        
        ee_address = EE_ADR_START;

        // Read EEPROM Data
        for(i=0; i<NUM_EE_VALUES; i++){
            RAMArray[i] = FLASH_ReadEepromByte(ee_address);
            ee_address++;
        }
        
    }
    
    while (1){
		PORTF.OUTTGL = PIN5_bm; // toggle PF5
		_delay_ms(LED_ON_OFF_DELAY);
    }
}
/**
    End of File
*/