/*
 * idefix.c
 *
 *  Created on: 27 mai 2026
 *      Author: SamLol12
 */


#include "Drivers/idefix.h"
#include <string.h>

#define IDEFIX_SLAVE_ADDRESS (0x69 << 1)

static idefix_status_t Idefix_Ping(idefix_t *dev) {
    if(HAL_I2C_IsDeviceReady(dev->hi2c, IDEFIX_SLAVE_ADDRESS, 3, 100) != HAL_OK) {
        return IDEFIX_I2C_ERROR;
    }
    return IDEFIX_OK;
}

idefix_status_t Idefix_Init(idefix_t *dev) {
    if(!dev) return IDEFIX_ERROR;
    if(!dev->hi2c) return IDEFIX_I2C_ERROR;
    
    if(Idefix_Ping(dev) != IDEFIX_OK) {
        return IDEFIX_I2C_ERROR;
    }

    return IDEFIX_OK;
}

#define IDEFIX_I2C_PACKET_SIZE 16

idefix_status_t Idefix_TransmitData(idefix_t *dev, idefix_command_t cmd, const uint8_t *payload, uint16_t size) {
    if(!dev) return IDEFIX_ERROR;

    uint8_t buffer[IDEFIX_I2C_PACKET_SIZE] = {0};
    if(size + 1 > sizeof(buffer)) return IDEFIX_ERROR;

    buffer[0] = (uint8_t)cmd;
    if(payload != NULL && size > 0) {
        memcpy(&buffer[1], payload, size);
    }

    if(HAL_I2C_Master_Transmit(dev->hi2c, IDEFIX_SLAVE_ADDRESS, buffer, IDEFIX_I2C_PACKET_SIZE, 100) != HAL_OK) {
        return IDEFIX_I2C_ERROR;
    }

    return IDEFIX_OK;
}
