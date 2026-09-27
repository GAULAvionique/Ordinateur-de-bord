/*
 * dev.c
 *
 *  Created on: 12 avr. 2026
 *      Author: gagno
 */


#include "Drivers/hm11.h"
#include "Systems/config.h"
#include <stdio.h>


static bool HM11_SendATCommand(hm11_t *dev, const char *cmd, const char *expected_response) {
    HAL_UART_AbortReceive_IT(dev->huart);
    
    dev->at_rx_buffer[0] = '\0'; 

    HAL_UART_Transmit(dev->huart, (uint8_t*)cmd, strlen(cmd), HM11_TIMEOUT);
    if(expected_response == NULL) {
        HAL_UART_Receive_IT(dev->huart, &dev->rx_byte, 1);
        return true;
    }

    uint16_t index = 0;
    uint32_t start_tick = HAL_GetTick();
    bool success = false;
    while((HAL_GetTick() - start_tick) < HM11_TIMEOUT) {
        uint8_t byte = 0;
        if(HAL_UART_Receive(dev->huart, &byte, 1, 10) == HAL_OK) {
            if(index < HM11_RX_BUFFER_SIZE - 1) {
                dev->at_rx_buffer[index++] = byte;
                dev->at_rx_buffer[index] = '\0';

                if(strstr(dev->at_rx_buffer, expected_response) != NULL) {
                    success = true;
                    break;
                }
            }
        }
    }

    HAL_UART_Receive_IT(dev->huart, &dev->rx_byte, 1);
    
    return success;
}

static bool HM11_SetName(hm11_t *dev, const char *name) {
    if(name == NULL) return false;

    char clean_name[13] = {0};
    size_t clean_len = 0;

    for(size_t i = 0; i < strlen(name) && clean_len < 12; i++) {
        if(name[i] >= 32 && name[i] <= 126) {
            clean_name[clean_len++] = name[i];
        }
    }

    while(clean_len > 0 && clean_name[clean_len - 1] == ' ') {
        clean_name[--clean_len] = '\0';
    }
    if(clean_len == 0) return false;

    char cmd[24];
    snprintf(cmd, sizeof(cmd), "AT+NAME%s", clean_name);

    return HM11_SendATCommand(dev, cmd, "OK+Set");
}


static bool HM11_SetBaudRate(hm11_t *dev, hm11_baudrate_t baud) {
    if(baud >= HM11_BAUD_MAX) return false;

    // Check baud
    char cmd[10];
    sprintf(cmd, "AT+BAUD%d", (uint8_t)baud);

    return HM11_SendATCommand(dev, cmd, "OK+Set:");
}

static bool HM11_TestUARTConnection(hm11_t *dev) {
    return HM11_SendATCommand(dev, "AT", "OK");
}

static bool HM11_EnableNotifications(hm11_t *dev) {
    bool success = false;
    if(HM11_SendATCommand(dev, "AT+NOTI1", "OK+Set:")) {
		success = true;
	}

	return success;
}


bool HM11_Reset(hm11_t *dev) {
    return HM11_SendATCommand(dev, "AT+RESET", "OK+RESET");
}

bool HM11_Renew(hm11_t *dev) {
	return HM11_SendATCommand(dev, "AT+RENEW", "OK+RENEW");
}

bool HM11_SetTransmissionPower(hm11_t *dev, hm11_tx_power_t power_idx) {
    if(power_idx > 3) return false;

    char cmd[15];
    sprintf(cmd, "AT+POWE%d", power_idx);

    return HM11_SendATCommand(dev, cmd, "OK+Set:");
}

hm11_state_t HM11_Init(hm11_t *dev) {
    if(!dev || !dev->huart || dev->baudrate > 8 || !dev->tx_power) return HM11_ERROR_INVALID_PARAM;

    // Disconnect
    HM11_Disconnect(dev);

    dev->name = current_config.odb_name;

    hm11_state_t err = HM11_OK;

    // Initialization ring buffer
    RingBuffer_Init(&dev->rx_ring, dev->rx_ring_data, HM11_RX_BUFFER_SIZE);
    memset(dev->at_rx_buffer, 0, HM11_RX_BUFFER_SIZE);

    // Wakeup
    if(HM11_TestUARTConnection(dev) == false) {
		HM11_WakeUp(dev);
		HAL_Delay(100);
		if(HM11_TestUARTConnection(dev) == false) {
			err = HM11_ERROR;
			return err;
		}
	}

    // Configuration
    if(!HM11_SetName(dev, dev->name)) {
        err = HM11_SETNAME_FAILED; // Failed to set name
    }
    /*
    if(!HM11_SetTransmissionPower(dev, dev->tx_power)) {
		err = HM11_SETTXPOWER_FAILED; // Failed to set tx power
	}
	*/
    if(!HM11_EnableNotifications(dev)) {
		err = HM11_SETNOTIF_FAILED; // Failed to set notifications
	}
    if(!HM11_SetBaudRate(dev, dev->baudrate)) {
		err = HM11_SETBAUD_FAILED; // Failed to set baud rate
	}
    if(!HM11_Reset(dev)) {
        err = HM11_ERROR; // Failed to reset
    }
    HAL_Delay(500);

    // Reset states
    memset(dev->at_rx_buffer, 0, HM11_RX_BUFFER_SIZE);

    return err; // success
}

bool HM11_SendData(hm11_t *dev, uint8_t *data, uint16_t length) {
    if(!dev || !dev->huart) return false;

    uint32_t start_tick = HAL_GetTick();
    while(dev->huart->gState != HAL_UART_STATE_READY) {
        if(HAL_GetTick() - start_tick > 100) {
            return false;
        }
    }

    if(HAL_UART_Transmit_DMA(dev->huart, data, length) == HAL_OK) {
        start_tick = HAL_GetTick();
        while(dev->huart->gState != HAL_UART_STATE_READY) {
            if(HAL_GetTick() - start_tick > 1000) {
                return false;
            }
        }
        return true;
    }

    return false;
}

bool HM11_SendString(hm11_t *dev, const char *str) {
    if(!str) return false;

    return HM11_SendData(dev, (uint8_t*)str, strlen(str));
}

bool HM11_GetMessage(hm11_t *dev, char *out_buffer, uint16_t max_length) {
    if(dev == NULL || out_buffer == NULL || max_length <= 1) {
        return false;
    }

    static char local_buffer[HM11_RX_BUFFER_SIZE];
    static uint16_t local_idx = 0;

    uint8_t byte;
    while(RingBuffer_Dequeue(&dev->rx_ring, &byte)) {
        if(local_idx < HM11_RX_BUFFER_SIZE - 1) {
            local_buffer[local_idx++] = byte;
            local_buffer[local_idx] = '\0';
        } else {
            local_idx = 0;
            local_buffer[0] = '\0';
        }

        if(strstr(local_buffer, "OK+CONN") != NULL) {
            dev->is_connected = true;
            local_idx = 0;
            local_buffer[0] = '\0';
            continue;
        }
        if(strstr(local_buffer, "OK+LOST") != NULL) {
            dev->is_connected = false;
            local_idx = 0;
            local_buffer[0] = '\0';
            continue;
        }

        if(byte == '\n' || byte == '\r') {
            if(local_idx > 1) {
                strncpy(out_buffer, local_buffer, max_length - 1);
                out_buffer[max_length - 1] = '\0';

                local_idx = 0;
                local_buffer[0] = '\0';
                return true;
            } else {
                local_idx = 0;
                local_buffer[0] = '\0';
            }
        }
    }

    return false;
}

bool HM11_Disconnect(hm11_t *dev) {
    if(!dev) return false;

    bool success = HM11_SendATCommand(dev, "AT", "OK+LOST");
    if(success) {
        dev->is_connected = false;
    }

    return success;
}

bool HM11_Sleep(hm11_t *dev) {
    return HM11_SendATCommand(dev, "AT+SLEEP", "OK+SLEEP");
}

bool HM11_WakeUp(hm11_t *dev) {
	const char wake_up_string[] = "wake up!, wake up!, wake up!, wake up!, wake up!, wake up!, wake up!, wake up!, wake up!";

	return HM11_SendATCommand(dev, wake_up_string, "OK+WAKE");
}
