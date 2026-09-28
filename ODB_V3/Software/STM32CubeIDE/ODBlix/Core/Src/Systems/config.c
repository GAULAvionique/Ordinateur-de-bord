/*
 * config.c
 *
 *  Created on: 19 mai 2026
 *      Author: gagno
 */


#include "Systems/config.h"
#include <string.h>
#include <stdio.h>

extern w25q_t w25q;
odb_config_t current_config;

// Default configuration
const odb_config_t default_config = {
	.magic_number = CONFIG_MAGIC_NUMBER,

	.version_major = CONFIG_PROTOCOL_VERSION_MAJOR,
	.version_minor = CONFIG_PROTOCOL_VERSION_MINOR,
	.payload_size = CONFIG_DATA_SIZE,

    // Profile
    .odb_name = "ODBlix",

    // Stage
    .stage_role = 2,
    .debug_mode = 1,
	.flight_test_mode = 0,

	// Sensors
	.axis_profile = 0,

    // Pyros
    .fire_attempt_delay_ms = 250,
    .pyros_arming_min_altitude_m = 450,
    .min_needed_pyro_nb = 2,
    .pyro_roles = {
        PYRO_ROLE_MAIN,          // Pyro 1
        PYRO_ROLE_DROGUE,        // Pyro 2
        PYRO_ROLE_MAIN_BACKUP,   // Pyro 3
        PYRO_ROLE_DROGUE_BACKUP  // Pyro 4
    },

    // Phase
    .acc_z_launch_threshold = 29.42f, 				// m/s2 (3.0G)
    .boost_phase_v_threshold = 100.0f,				// m/s
    .apogee_detect_v_threshold = -5.0f,				// m/s
    .landing_detect_v_threshold = 5.0f,				// m/s
    .landing_detect_threshold_ms = 10000,			// ms
    .apogee_failsafe_ms = 60000,					// ms

    // Parachute
    .main_deploy_altitude_threshold_m = 450.0f,
    .drogue_fire_attempt_max_nb = 3,
    .main_fire_attempt_max_nb = 3,

    // Buzzer
    .enable_buzzer = 0,
    .buzzer_report_tone_hz = 500,

	// IdeFIX
	.idefix_frequency_hz = 444270000,
};

static config_error_t Config_Validate(const odb_config_t* new_config) {
    if(new_config == NULL) {
        return CONFIG_ERR_MAGIC_NUMBER;
    }

    if(new_config->magic_number != CONFIG_MAGIC_NUMBER) {
        return CONFIG_ERR_MAGIC_NUMBER;
    }

    if(new_config->version_major != CONFIG_PROTOCOL_VERSION_MAJOR) {
        return CONFIG_ERR_VERSION;
    }

    if(new_config->debug_mode == 0) {
    	/* Validate ODB Name */
    	if(new_config->odb_name[0] == ' ') {
    		return CONFIG_ERR_ODB_NAME;
    	}
    	/* Validate Stage Role */
		if(new_config->stage_role < CONFIG_STAGE_ROLE_MIN || new_config->stage_role > CONFIG_STAGE_ROLE_MAX) {
			return CONFIG_ERR_STAGE_ROLE;
		}

		/* Validate Profile Axis */
		if(new_config->stage_role < ACC_AXIS_PROFILE_P0 || new_config->stage_role > ACC_AXIS_PROFILE_MAX) {
			return CONFIG_ERR_PROFILE_AXIS;
		}

		/* Validate Timings */
		if(new_config->fire_attempt_delay_ms <= 0.0f) {
			return CONFIG_ERR_TIMING_CONFLICT;
		}

		/* Validate Fail-safes*/
		if(new_config->pyros_arming_min_altitude_m <= 0.0f) {
			return CONFIG_ERR_ALTITUDE_LIMIT;
		}

		/* Validate Pyro Configuration */
		if(new_config->min_needed_pyro_nb < CONFIG_PYRO_NEEDED_MIN || new_config->min_needed_pyro_nb > CONFIG_PYRO_NEEDED_MAX) {
			return CONFIG_ERR_PYRO_LIMITS;
		}

		bool is_drogue = false;
		for(uint8_t i = 0; i < CONFIG_PYRO_NEEDED_MAX; i++) {
			if(new_config->pyro_roles[i] == PYRO_ROLE_DROGUE) {
				is_drogue = true;
				break;
			}
		}
		if(!is_drogue) {
			return CONFIG_ERR_PYRO_ROLE;
		}

		if(new_config->main_fire_attempt_max_nb < CONFIG_PYRO_ATTEMPTS_MIN || new_config->drogue_fire_attempt_max_nb < CONFIG_PYRO_ATTEMPTS_MIN) {
			return CONFIG_ERR_PYRO_LIMITS;
		}

		/* Validate Acceleration Thresholds */
		if(new_config->acc_z_launch_threshold <= CONFIG_ACC_Z_LAUNCH_MIN_MS2 || new_config->acc_z_launch_threshold >= CONFIG_ACC_Z_LAUNCH_MAX_MS2) {
			return CONFIG_ERR_THRESHOLDS;
		}

		/* Validate Altitude Thresholds */
		if(new_config->main_deploy_altitude_threshold_m < CONFIG_MAIN_DEPLOY_ALT_MIN_M) {
			return CONFIG_ERR_THRESHOLDS;
		}

		/* Validate Velocity Thresholds */
		if(new_config->apogee_detect_v_threshold > CONFIG_APOGEE_DETECT_V_MAX_MS) {
			return CONFIG_ERR_THRESHOLDS;
		}
    }

    return CONFIG_VALID_OK;
}

void Config_Init(void) {
    odb_config_t temp_config;
    if(W25Q_Read(&w25q, (uint8_t*)&temp_config, FLASH_CONFIG_START_ADDRESS, CONFIG_DATA_SIZE) == 0) {
        if(temp_config.magic_number == CONFIG_MAGIC_NUMBER) {
            if(temp_config.version_major == CONFIG_PROTOCOL_VERSION_MAJOR && temp_config.version_minor == CONFIG_PROTOCOL_VERSION_MINOR && temp_config.payload_size == CONFIG_DATA_SIZE) {
                memcpy(&current_config, &temp_config, CONFIG_DATA_SIZE);

                return;
            } else {
                DEBUG_PRINTF("WARNING : Config version mismatch (Flash V%d.%d, FW V%d.%d). Loading defaults.\n", temp_config.version_major, temp_config.version_minor, CONFIG_PROTOCOL_VERSION_MAJOR, CONFIG_PROTOCOL_VERSION_MINOR);
            }
        }
    }

    Config_LoadDefaults();
    Config_SaveToFlash();
}

int8_t Config_SaveToFlash(void) {
	config_error_t validation_result = Config_Validate(&current_config);
	if(validation_result != CONFIG_VALID_OK) {
		return (int8_t)validation_result;
	}

	if(W25Q_EraseSector(&w25q, FLASH_CONFIG_START_ADDRESS) != 0) {
    	return -1; // failed
    }

    if(W25Q_WritePage(&w25q, (uint8_t*)&current_config, FLASH_CONFIG_START_ADDRESS, CONFIG_DATA_SIZE) != 0) {
        return -1; // failed
    }

    return 0; // success
}

void Config_LoadDefaults(void) {
    memcpy(&current_config, &default_config, CONFIG_DATA_SIZE);
}

const odb_config_t* Config_Get(void) {
    return &current_config;
}

int Config_Erase(void) {
	if(W25Q_EraseSector(&w25q, FLASH_CONFIG_START_ADDRESS) != 0) {
		return -1;
	}
	Config_LoadDefaults();

	return 0;
}
