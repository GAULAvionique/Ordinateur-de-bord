/*
 * hm11.h
 *
 *  Created on: 12 avr. 2026
 *      Author: SamLol12
 */

#ifndef INC_DRIVERS_HM11_H_
#define INC_DRIVERS_HM11_H_

#include "Utils/ringbuffer.h"
#include "stm32f4xx_hal.h"
#include <stdint.h>
#include <stdbool.h>
#include <string.h>


// MAX 20 byte of payload message

#define HM11_TIMEOUT         500
#define HM11_RX_BUFFER_SIZE  512

typedef enum {
    HM11_OK = 0,
    HM11_ERROR = -1,
    HM11_ERROR_INVALID_PARAM = -2,
    HM11_SETBAUD_FAILED = -3,
    HM11_SETNAME_FAILED = -4,
	HM11_SETNOTIF_FAILED = -5,
	HM11_SETTXPOWER_FAILED = -6,
} hm11_state_t;

typedef enum {
    HM11_BAUD_1200 = 7,
    HM11_BAUD_2400 = 6,
    HM11_BAUD_4800 = 5,
    HM11_BAUD_9600 = 0,
    HM11_BAUD_19200 = 1,
    HM11_BAUD_38400 = 2,
    HM11_BAUD_57600 = 3,
    HM11_BAUD_115200 = 4,
    HM11_BAUD_230400 = 8,
	HM11_BAUD_MAX = 9
} hm11_baudrate_t;

typedef enum {
	HM11_MINIMAL_TX_POWER = 0,
	HM11_LOW_TX_POWER,
	HM11_NORMAL_TX_POWER,
	HM11_MAXIMAL_TX_POWER
} hm11_tx_power_t;

typedef struct {
    UART_HandleTypeDef 	*huart;
    const char			*name;
    hm11_baudrate_t     baudrate;
    hm11_tx_power_t		tx_power;
    bool                is_connected;

    char 				at_rx_buffer[HM11_RX_BUFFER_SIZE];
    uint16_t            at_rx_index;
    uint8_t             rx_byte;
    ring_buffer_t       rx_ring;
    uint8_t             rx_ring_data[HM11_RX_BUFFER_SIZE];
} hm11_t;


hm11_state_t HM11_Init(hm11_t *dev);

bool HM11_SendData(hm11_t *dev, uint8_t *data, uint16_t length);
bool HM11_SendString(hm11_t *dev, const char *str);
bool HM11_GetMessage(hm11_t *dev, char *out_buffer, uint16_t max_lenth);
bool HM11_Disconnect(hm11_t *dev);
bool HM11_SetTransmissionPower(hm11_t *dev, hm11_tx_power_t power_idx);

bool HM11_Sleep(hm11_t *dev);
bool HM11_WakeUp(hm11_t *dev);

#endif /* INC_DRIVERS_HM11_H_ */
