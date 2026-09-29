/*
 * dwt.c
 *
 *  Created on: 6 mai 2026
 *      Author: SamLol12
 */

#include "stm32f4xx_hal.h"

void DWT_Init(void) {
    // Enable DWT_CYCCNT
    CoreDebug->DEMCR |= CoreDebug_DEMCR_TRCENA_Msk;
    // Reset cycle counter
    DWT->CYCCNT = 0;
    // Enable cycle counter
    DWT->CTRL |= DWT_CTRL_CYCCNTENA_Msk;
}

uint32_t DWT_GetCycles(void) {
    return DWT->CYCCNT;
}
