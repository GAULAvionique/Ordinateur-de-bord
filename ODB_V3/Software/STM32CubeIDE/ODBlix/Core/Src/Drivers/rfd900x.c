/*
 * RFD900.c
 *
 *  Created on: Feb 19, 2024
 *      Author: SamLol12
 *
 *  Edited on: Mar 02, 2026
 *  	Author: AudaceLol12
 */

#include "Drivers/rfd900x.h"


static bool RFD900x_SendCommand(UART_HandleTypeDef *huart, const char *cmd, uint32_t timeout_ms) {
    uint8_t rx_byte;
    char rx_buf[16] = {0};
    uint8_t idx = 0;

    __HAL_UART_FLUSH_DRREGISTER(huart);

    if(cmd != NULL) {
        HAL_UART_Transmit(huart, (uint8_t*)cmd, strlen(cmd), HAL_MAX_DELAY);
    }

    uint32_t start_tick = HAL_GetTick();
    while((HAL_GetTick() - start_tick) < timeout_ms) {
        if(HAL_UART_Receive(huart, &rx_byte, 1, 10) == HAL_OK) {
            if(idx < (sizeof(rx_buf) - 1)) {
                rx_buf[idx++] = rx_byte;
                rx_buf[idx] = '\0';
            }
            // Check "OK"
            if(strstr(rx_buf, "OK") != NULL) {
                return true; 
            }
        }
    }

    return false; // Timeout
}

void RFD900x_ProcessTX(rfd900x_t *dev) {
    if(dev->is_transmitting || RingBuffer_IsEmpty(&dev->tx_ring)) {
        return;
    }

    size_t to_send = RingBuffer_NumItems(&dev->tx_ring);
    if(to_send > sizeof(dev->dma_busy_buffer)) {
        to_send = sizeof(dev->dma_busy_buffer);
    }

    RingBuffer_Dequeue_Array(&dev->tx_ring, dev->dma_busy_buffer, to_send);

    dev->is_transmitting = true;
    if(HAL_UART_Transmit_DMA(dev->huart, dev->dma_busy_buffer, (uint16_t)to_send) != HAL_OK) {
        dev->is_transmitting = false;
    }
}


rfd900x_state_t RFD900x_Init(rfd900x_t *dev) {
	if (!dev || !dev->huart) return RFD_ERROR;

	RingBuffer_Init(&dev->tx_ring, dev->tx_ring_data, RFD_TX_RING_SIZE);
	dev->is_transmitting = false;

    return RFD_OK; // success
}

rfd900x_state_t RFD900x_Transmit(rfd900x_t *dev, uint8_t *payload, uint16_t length) {
    if(!dev || !payload || length == 0) return RFD_ERROR;

    __disable_irq();

    if(RFD_TX_RING_SIZE - RingBuffer_NumItems(&dev->tx_ring) < length) {
    	__enable_irq();
        return RFD_BUSY;
    }

    RingBuffer_Queue_Array(&dev->tx_ring, payload, length);

    RFD900x_ProcessTX(dev);

    __enable_irq();

    return RFD_OK;
}

rfd900x_state_t RFD900x_Sleep(rfd900x_t *dev) {
    if(!dev || !dev->huart) return RFD_ERROR;
    

    while(dev->is_transmitting) {
        HAL_Delay(10);
    }

    // Stop UART DMA Reception + wait 1s for AT command mode to be available
    HAL_UART_AbortReceive_IT(dev->huart); 
    HAL_Delay(1100); 

    // Send "+++" to enter AT command mode
    if(!RFD900x_SendCommand(dev->huart, "+++", 2000)) {
        return RFD_TIMEOUT;
    }

    // Set TX power + duty cycle
    if (!RFD900x_SendCommand(dev->huart, "ATS4=0\r\n", 1000)) {
        return RFD_TIMEOUT;
    }
    if (!RFD900x_SendCommand(dev->huart, "ATS11=10\r\n", 1000)) {
        return RFD_TIMEOUT;
    }

    // Save in EEPROM + apply settings by Reset
    if (!RFD900x_SendCommand(dev->huart, "AT&W\r\n", 1000)) {
        return RFD_TIMEOUT;
    }
    RFD900x_SendCommand(dev->huart, "ATZ\r\n", 500); 
    HAL_Delay(1500);

    return RFD_OK;
}
