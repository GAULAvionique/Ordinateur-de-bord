/*
 * config.h
 *
 *  Created on: 24 avr. 2026
 *      Author: SamLol12
 */

#ifndef INC_SYSTEMS_CONFIG_H_
#define INC_SYSTEMS_CONFIG_H_

#include "Drivers/w25q512jveim.h"
#include "Protocols/config_protocol.h"
#include "Utils/utils.h"
#include <stdbool.h>
#include <stdint.h>

/* === Configuration Storage === */
#define FLASH_CONFIG_START_ADDRESS      (W25Q512_FLASH_SIZE_BYTE - FLASH_SECTOR_SIZE_BYTE) // 0x03FFF000
#define CONFIG_MAGIC_NUMBER  			0x434F4E46 // CONF
/* =========== */

typedef enum {
    CONFIG_VALID_OK 					= 0,
    CONFIG_ERR_MAGIC_NUMBER 			= -1,
    CONFIG_ERR_VERSION 					= -2,
	CONFIG_ERR_ODB_NAME 				= -3,
    CONFIG_ERR_STAGE_ROLE 				= -4,
	CONFIG_ERR_PROFILE_AXIS 			= -5,
    CONFIG_ERR_TIMING_CONFLICT 			= -6,
    CONFIG_ERR_PYRO_LIMITS 				= -7,
	CONFIG_ERR_PYRO_ROLE 				= -8,
    CONFIG_ERR_THRESHOLDS 				= -9,
	CONFIG_ERR_ALTITUDE_LIMIT 			= -10,
	CONFIG_ERR_APOGEE_DETECTION_MODE 	= -11,
} config_error_t;
extern odb_config_t current_config;

void Config_Init(void);
int8_t Config_SaveToFlash(void);
void Config_LoadDefaults(void);
const odb_config_t* Config_Get(void);
bool Config_CheckCrc(const odb_config_t *config);
void Config_ResetTransaction(void);

int Config_Erase(void);

#endif /* INC_SYSTEMS_CONFIG_H_ */
