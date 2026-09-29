/*
 * stm32f4xx_hal.h
 *
 *  Created on: 10 juin 2026
 *      Author: SamLol12
 */


/* Fichier : Core/Src/Tools/Mocks/stm32f4xx_hal.h */
#ifndef MOCK_STM32F4XX_HAL_H
#define MOCK_STM32F4XX_HAL_H

#include <stdint.h>
#include <stdbool.h>

// --- Mocks des Statuts ---
typedef enum {
    HAL_OK = 0,
    HAL_ERROR = 1,
    HAL_BUSY = 2,
    HAL_TIMEOUT = 3
} HAL_StatusTypeDef;

// --- Mocks des GPIOs ---
typedef struct { uint32_t dummy; } GPIO_TypeDef;
#define GPIO_PIN_SET   1
#define GPIO_PIN_RESET 0

// --- Mocks des Timers ---
typedef struct { uint32_t CNT; } TIM_TypeDef;
typedef struct { TIM_TypeDef *Instance; } TIM_HandleTypeDef;

// Fausse adresse mémoire pour simuler la présence de TIM5
#define TIM5 ((TIM_TypeDef *)0x40000C00)

// --- Mocks des Périphériques ---
typedef struct { uint32_t dummy; } ADC_HandleTypeDef;
typedef struct { uint32_t dummy; } I2C_HandleTypeDef;
typedef struct { uint32_t dummy; } SPI_HandleTypeDef;
typedef struct { uint32_t dummy; } UART_HandleTypeDef;
typedef struct { uint32_t dummy; } QSPI_HandleTypeDef;

// --- Mocks des Fonctions ---
uint32_t HAL_GetTick(void);

// Les macros pour manipuler le Timer
#define __HAL_TIM_GET_COUNTER(__HANDLE__)          ((__HANDLE__)->Instance->CNT)
#define __HAL_TIM_SET_COUNTER(__HANDLE__, __VALUE__) ((__HANDLE__)->Instance->CNT = (__VALUE__))
#define HAL_TIM_Base_Start(__HANDLE__)          	/* Désactivé en simulation */

#define HAL_Delay(delay)                           /* Désactivé en simulation */

// --- Mocks Système (Masque les instructions ARM) ---
#define __disable_irq()

#endif
