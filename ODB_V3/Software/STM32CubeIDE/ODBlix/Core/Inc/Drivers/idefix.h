/*
 * idefix.h
 *
 *  Created on: 27 mai 2026
 *      Author: SamLol12
 */

#ifndef INC_DRIVERS_IDEFIX_H_
#define INC_DRIVERS_IDEFIX_H_

#include "stm32f4xx_hal.h"
#include <stdint.h>

typedef enum {
	IDEFIX_OK = 0,
	IDEFIX_ERROR = -1,
	IDEFIX_I2C_ERROR = -2,
	IDEFIX_PINGPONG_ERROR = -3,
	IDEFIX_CMD_ERROR = -4
} idefix_status_t;

typedef enum {
    IDEFIX_CMD_PING    = 0x01,
    IDEFIX_CMD_COORD   = 0x02,
    IDEFIX_CMD_FREQ    = 0x03,
    IDEFIX_CMD_CHANNEL = 0x04
} idefix_command_t;

typedef struct {
	I2C_HandleTypeDef *hi2c;
} idefix_t;


idefix_status_t Idefix_Init(idefix_t *dev);

idefix_status_t Idefix_TransmitData(idefix_t *dev, idefix_command_t cmd, const uint8_t *payload, uint16_t size);

#endif /* INC_DRIVERS_IDEFIX_H_ */
