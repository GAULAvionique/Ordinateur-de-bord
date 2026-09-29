/*
 * reboot_manager.h
 *
 *  Created on: 4 juin 2026
 *      Author: SamLol12
 */

#ifndef INC_UTILS_REBOOT_MANAGER_H_
#define INC_UTILS_REBOOT_MANAGER_H_

#include <stdbool.h>
#include <stdint.h>

void RebootManager_Init(void);

void RebootManager_RequestReboot(void);
void RebootManager_Update(void);

#endif /* INC_UTILS_REBOOT_MANAGER_H_ */
