/*
 * power_management.h
 *
 *  Created on: 20 août 2026
 *      Author: gagno
 */

#ifndef INC_SYSTEMS_POWER_MANAGEMENT_H_
#define INC_SYSTEMS_POWER_MANAGEMENT_H_


#include <stdint.h>
#include <stdbool.h>

#define BATT_NORMAL_MV	  7200
#define BATT_LOW_MV       6000
#define BATT_CRITICAL_MV  5500

typedef enum {
    BATT_LEVEL_NORMAL,
    BATT_LEVEL_LOW,
    BATT_LEVEL_CRITICAL
} power_management_level_t;

void PowerManagement_Init(void);
void PowerManagement_SetProfile(power_management_level_t level);
void PowerManagement_IdleTask(void);

#endif /* INC_SYSTEMS_POWER_MANAGEMENT_H_ */
