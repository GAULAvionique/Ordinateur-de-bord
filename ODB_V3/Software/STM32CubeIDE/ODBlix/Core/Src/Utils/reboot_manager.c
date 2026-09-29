/*
 * reboot_manager.c
 *
 *  Created on: 4 juin 2026
 *      Author: SamLol12
 */


#include "Utils/reboot_manager.h"
#include "stm32f4xx_hal.h"

#define REBOOT_GRACE_PERIOD_MS 500


static bool reboot_pending = false;
static uint32_t reboot_trigger_tick = 0;


void RebootManager_Init(void) {
    reboot_pending = false;
    reboot_trigger_tick = 0;
}

void RebootManager_RequestReboot(void) {
    if(!reboot_pending) {
        reboot_pending = true;
        reboot_trigger_tick = HAL_GetTick();
    }
}

void RebootManager_Update(void) {
    if(!reboot_pending) return;

    // TODO: Disable some tasks here if needed ...

    if((HAL_GetTick() - reboot_trigger_tick) >= REBOOT_GRACE_PERIOD_MS) {
		__disable_irq();
		NVIC_SystemReset();
	}
}
