/*
 * power_management.c
 *
 *  Created on: 20 août 2026
 *      Author: SamLol12
 */


#include "Systems/power_management.h"


static power_management_level_t profile = BATT_LEVEL_NORMAL;


void PowerManagement_Init(void) {
	profile = BATT_LEVEL_NORMAL;
}

void PowerManagement_SetProfile(power_management_level_t level) {

}

void PowerManagement_IdleTask(void) {

}
