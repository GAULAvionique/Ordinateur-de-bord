/*
 * L76LM33.c
 *
 * Created on: May 12, 2024
 * Author: AudaceLol12
 *
 * Edited on: Jul 04, 2024
 * Autor: mathouqc
 *
 * Edited on: Mar 02, 2026
 * Autor: AudaceLol12
 */

#include "Drivers/l76lm33.h"
#include "Systems/config.h"
#include <string.h>


/*
 * Send array of character to L76LM33 using UART HAL functions.
*/
static l76lm33_state_t L76LM33_SendCommand(l76lm33_t *dev, const char *command, uint8_t size) {
    if(command == NULL) {
        return L76LM33_ERROR;
    }

    if(HAL_UART_Transmit(dev->huart, (uint8_t *)command, size, L76LM33_UART_TIMEOUT) != HAL_OK) {
        return L76LM33_ERROR;
    }

    return L76LM33_OK;
}

/*
 * Read NMEA sentence from UART circular buffer.
*/
static l76lm33_state_t L76LM33_ReadSentence(l76lm33_t *dev, char *out_buffer, uint16_t max_len) {
    if(dev->line_count == 0) return L76LM33_EMPTY_BUFF;

    dev->line_count--;
    memset(out_buffer, 0, max_len);

    uint8_t c;
    bool start_found = false;
    while(RingBuffer_Dequeue(&(dev->UART_Buffer), &c)) {
        if(c == '$') {
            out_buffer[0] = '$';
            start_found = true;
            break;
        }
    }

    if(!start_found) return L76LM33_ERROR; 

    for(uint16_t i = 1; i < max_len - 1; i++) {
        if(!RingBuffer_Dequeue(&(dev->UART_Buffer), &c)) {
            return L76LM33_EMPTY_BUFF;
        }
        
        out_buffer[i] = (char)c;
        if(c == '\n') return L76LM33_OK; // success
    }

    return L76LM33_ERROR;
}

/*
 * Source:
 * LG76 Series GNSS Protocol Specification - Section 2.3. PMTK Messages
*/

/*
 * Initialize L76LM33 sensor.
*/
l76lm33_state_t L76LM33_Init(l76lm33_t *dev) {
    if(!dev) return L76LM33_ERROR_DEV;
    if(!dev->huart) return L76LM33_ERROR_UART;

    HAL_Delay(500);

    dev->profile = current_config.stage_role - STAGE_ROLE_BOOSTER;
    dev->line_count = 0;
    dev->old_pos = 0;

    // Initialize circular buffer
    RingBuffer_Init(&(dev->UART_Buffer), dev->ring_buffer_arr, L76LM33_BUFFER_SIZE);

    // Start Dma
    HAL_UARTEx_ReceiveToIdle_DMA(dev->huart, dev->dma_buffer, L76LM33_BUFFER_SIZE);
    HAL_Delay(2000);

    // Full Cold Start
    const char NMEA_COLD_START[] = "$PMTK104*37\r\n";
    L76LM33_SendCommand(dev, NMEA_COLD_START, strlen(NMEA_COLD_START));
    HAL_Delay(1000);

    /* Baudrate
	 * "$PMTK251,115200*1F<CR><LF>"
	*/
	const char NMEA_BAUD[] = "$PMTK251,115200*1F\r\n";
	if(L76LM33_SendCommand(dev, NMEA_BAUD, strlen(NMEA_BAUD)) != L76LM33_OK) {
		return L76LM33_ERROR;
	}
	HAL_Delay(150);

	// Restart UART DMA Reception
	HAL_UART_AbortReceive(dev->huart);
	dev->huart->Init.BaudRate = 115200;
	if(HAL_UART_Init(dev->huart) != HAL_OK) {
		return L76LM33_ERROR;
	}
	// Clear pending buffers
	__HAL_UART_CLEAR_OREFLAG(dev->huart);
	__HAL_UART_CLEAR_FEFLAG(dev->huart);
	// Start DMA reception
	if(HAL_UARTEx_ReceiveToIdle_DMA(dev->huart, dev->dma_buffer, L76LM33_BUFFER_SIZE) != HAL_OK) {
		return L76LM33_ERROR;
	}

    /*
     * Search GPS + Galileo satellites only (disables BeiDou and GLONASS to allow 10Hz)
     * "$PMTK353,1,0,1,0,0*2A<CR><LF>"
    */
    const char NMEA_CONST[] = "$PMTK353,1,0,1,0,0*2A\r\n";
    if(L76LM33_SendCommand(dev, NMEA_CONST, strlen(NMEA_CONST)) != L76LM33_OK) return L76LM33_ERROR;
    HAL_Delay(150);
    /*
	 * Activate SBAS (Positioning correction) + DPGS Mode
	 * "$PMTK313,1*2E<CR><LF>"
	 * "$PMTK301,2*2E<CR><LF>"
	*/
	const char NMEA_SBAS[] = "$PMTK313,1*2E\r\n";
	const char NMEA_DGPS[] = "$PMTK301,2*2E\r\n";
	if(L76LM33_SendCommand(dev, NMEA_DGPS, strlen(NMEA_DGPS)) != L76LM33_OK) return L76LM33_ERROR;
	HAL_Delay(150);
	if(L76LM33_SendCommand(dev, NMEA_SBAS, strlen(NMEA_SBAS)) != L76LM33_OK) return L76LM33_ERROR;
	HAL_Delay(150);

	/*
	 * Disable EASY
	 * "$PMTK869,1,0*34<CR><LF>"
	*/
	const char NMEA_EASY[] = "$PMTK869,1,0*34\r\n";
	if(L76LM33_SendCommand(dev, NMEA_EASY, strlen(NMEA_EASY)) != L76LM33_OK) return L76LM33_ERROR;
	HAL_Delay(150);

	/*
	 * Activate AIC (active interference canceller)
	 * "$PMTK286,1*23<CR><LF>"
	*/
	const char NMEA_AIC[] = "$PMTK286,1*23\r\n";
	if(L76LM33_SendCommand(dev, NMEA_AIC, strlen(NMEA_AIC)) != L76LM33_OK) return L76LM33_ERROR;
	HAL_Delay(150);

	/*
	 * Set Periodic mode (disable AlwayLocate)
	 * "$PMTK225,0*2B<CR><LF>"
	*/
	const char NMEA_PERIOD[] = "$PMTK225,0*2B\r\n";
	if(L76LM33_SendCommand(dev, NMEA_PERIOD, strlen(NMEA_PERIOD)) != L76LM33_OK) return L76LM33_ERROR;
	HAL_Delay(150);

    /*
     * Output RMC and GGA sentences only (once every one position fix) & altitude is given in WGS84 ellipsoid convention
     * "$PMTK314,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0*28<CR><LF>"
    */
    const char NMEA_OUTPUT[] = "$PMTK314,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0*28\r\n";
    if(L76LM33_SendCommand(dev, NMEA_OUTPUT, strlen(NMEA_OUTPUT)) != L76LM33_OK) return L76LM33_ERROR;
    HAL_Delay(150);

    // Navigation mode
    if(dev->profile == L76_FLIGHT_PROFILE_30K) {
        // Mode Aviation (< 10 000m / 32 800ft)
        // "$PMTK886,2*2B<CR><LF>"
        const char NMEA_NAV_AVIATION[] = "$PMTK886,2*2B\r\n";
        if(L76LM33_SendCommand(dev, NMEA_NAV_AVIATION, strlen(NMEA_NAV_AVIATION)) != L76LM33_OK) return L76LM33_ERROR;
    } else if(dev->profile == L76_FLIGHT_PROFILE_100K) {
        // Balloon mode (< 80 000m / 262 000ft)
        // "$PMTK886,3*2A<CR><LF>"
        const char NMEA_NAV_BALLOON[] = "$PMTK886,3*2A\r\n";
        if(L76LM33_SendCommand(dev, NMEA_NAV_BALLOON, strlen(NMEA_NAV_BALLOON)) != L76LM33_OK) return L76LM33_ERROR;
    } else {
    	return L76LM33_ERROR_DEV;
    }
    HAL_Delay(150);

    /*
	 * Set position fix interval to 100ms (10Hz) -> 5Hz practical, but 10Hz theoretical
	 * "$PMTK220,100*2F<CR><LF>"
	 * "$PMTK220,200*2C<CR><LF>"
	 * "$PMTK220,500*2B<CR><LF>"
	 * "$PMTK220,1000*1F<CR><LF>"
	*/
	const char NMEA_RATE[] = "$PMTK220,200*2C\r\n";
	if(L76LM33_SendCommand(dev, NMEA_RATE, strlen(NMEA_RATE)) != L76LM33_OK) return L76LM33_ERROR;
	HAL_Delay(150);

    return L76LM33_OK;
}

/*
 * Read and parse NMEA sentences into data structure.
*/
l76lm33_state_t L76LM33_Compute(l76lm33_t *dev) {
    char temp_nmea_buffer[L76LM33_BUFFER_SIZE];

    int8_t valid = L76LM33_ReadSentence(dev, temp_nmea_buffer, L76LM33_BUFFER_SIZE);
    if(valid == L76LM33_EMPTY_BUFF) return L76LM33_EMPTY_BUFF;
    if(valid != L76LM33_OK) return L76LM33_ERROR;

    if(NMEA_ValidateRMC(temp_nmea_buffer) == 0) {
        if(NMEA_ParseRMC(&(dev->gps_data), temp_nmea_buffer) != 0) return L76LM33_NO_VALID_FRAME;
    } else if(NMEA_ValidateGGA(temp_nmea_buffer) == 0) {
        if(NMEA_ParseGGA(&(dev->gps_data), temp_nmea_buffer) != 0) return L76LM33_NO_VALID_FRAME;
    }

    return L76LM33_OK;
}

l76lm33_state_t L76LM33_SetStandby(l76lm33_t *dev) {
    /*
     * Set standby mode (power save)
     * "$PMTK161,0*28<CR><LF>"
    */
    const char NMEA_STANDBY[] = "$PMTK161,0*28\r\n";
    if(L76LM33_SendCommand(dev, NMEA_STANDBY, strlen(NMEA_STANDBY)) != L76LM33_OK) return L76LM33_ERROR;
    HAL_Delay(10);

    return L76LM33_OK;
}

// Callback
void L76LM33_UART_RxEventCallback(l76lm33_t *dev, uint16_t size) {
    uint16_t length;
    if(size >= dev->old_pos) {
        length = size - dev->old_pos;
    } else {
        length = L76LM33_BUFFER_SIZE - dev->old_pos + size;
    }

    for(uint16_t i = 0; i < length; i++) {
        uint8_t c = dev->dma_buffer[(dev->old_pos + i) % L76LM33_BUFFER_SIZE];
        RingBuffer_Queue(&(dev->UART_Buffer), c);
        if(c == '\n') {
            dev->line_count++;
        }
    }

    dev->old_pos = size;
}
