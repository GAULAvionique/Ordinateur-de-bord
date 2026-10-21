/*
 * config.c
 *
 *  Created on: 19 mai 2026
 *      Author: SamLol12
 */


#include "Systems/config.h"
#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

extern w25q_t w25q;
odb_config_t current_config;

static const float min_config_z_launch_acc = 0.0f;
static const float max_config_z_launch_acc = 39.24f;
static const float min_config_main_deploy_alt_m = 50.0f;
static const float max_config_apogee_detect_v = 0.0f;
static const float max_config_early_deployment_v = -100.0f;
static const uint8_t max_config_pyro_attempts_nb = 5;


// Default configuration
const odb_config_t default_config = {
	.magic_number = CONFIG_MAGIC_NUMBER,

	.version_major = CONFIG_PROTOCOL_VERSION_MAJOR,
	.version_minor = CONFIG_PROTOCOL_VERSION_MINOR,
	.payload_size = CONFIG_DATA_SIZE,

    // Profile
    .odb_name = "ODBlix",

    // Stage
	.stage_role = STAGE_ROLE_BOOSTER,
    .debug_mode = STATE_TRUE,
	.flight_test_mode = STATE_FALSE,

	// Sensors
	.axis_profile = ACC_AXIS_PROFILE_P0,
	.highg_calib_6faces = {
		.scale_matrix = {0.0f, 0.0f, 0.0f},
		.bias = {0.0f, 0.0f, 0.0f}
	},
	/*
	.imu_calib_6faces = {
		.scale_matrix = {0.0f, 0.0f, 0.0f},
		.bias = {0.0f, 0.0f, 0.0f}
	},
	*/
	.calib_states = FLAG_CALIB_RESET,

    // Pyros
	.armed_pyros_power_up = STATE_TRUE,
    .fire_attempt_delay_ms = 250,
    .pyros_arming_min_altitude_m = 450,
    .needed_pyro_nb = 2,
    .pyro_roles = {
        PYRO_ROLE_MAIN,          // Pyro 1
        PYRO_ROLE_DROGUE,        // Pyro 2
        PYRO_ROLE_MAIN_BACKUP,   // Pyro 3
        PYRO_ROLE_DROGUE_BACKUP  // Pyro 4
    },

    // Phase
	.apogee_detection_mode = APOGEE_DETECTION_KALMAN,	// Kalman
	.enable_early_deployment = STATE_TRUE,
    .z_launch_threshold_acc = 29.42f, 					// m/s2 (3.0G)
    .boost_phase_threshold_v = 100.0f,					// m/s
    .apogee_detect_threshold_v = -5.0f,					// m/s
	.early_deployment_threshold_v = -65.0f,				// m/s
    .apogee_failsafe_ms = 60000,						// ms

    // Parachute
    .main_deploy_altitude_threshold_m = 450.0f,
    .drogue_fire_attempt_nb = 3,
    .main_fire_attempt_nb = 3,

    // Buzzer
	.enable_buzzer = STATE_FALSE,
    .buzzer_report_tone_hz = 500,

	// IdeFIX
	.idefix_frequency_hz = 444270000,

	.crc32 = 0,
};

static config_error_t Config_ValidateFields(const odb_config_t* new_config) {
    if(new_config == NULL) {
        return CONFIG_ERR_MAGIC_NUMBER;
    }

    if(new_config->magic_number != CONFIG_MAGIC_NUMBER) {
        return CONFIG_ERR_MAGIC_NUMBER;
    }

    if(new_config->version_major != CONFIG_PROTOCOL_VERSION_MAJOR) {
        return CONFIG_ERR_VERSION;
    }

	if(new_config->debug_mode == STATE_FALSE) {
    	/* Validate ODB Name */
    	if(new_config->odb_name[0] == ' ') {
    		return CONFIG_ERR_ODB_NAME;
    	}

    	/* Validate Stage Role */
		if(new_config->stage_role != STAGE_ROLE_BOOSTER && new_config->stage_role != STAGE_ROLE_SUSTAINER) {
			return CONFIG_ERR_STAGE_ROLE;
		}

		/* Validate Profile Axis */
		if(new_config->axis_profile < ACC_AXIS_PROFILE_P0 || new_config->axis_profile >= ACC_AXIS_PROFILE_MAX) {
			return CONFIG_ERR_PROFILE_AXIS;
		}

		/* Validate Timings */
		if(new_config->fire_attempt_delay_ms < 0.0f) {
			return CONFIG_ERR_TIMING_CONFLICT;
		}

		/* Validate Fail-safes Pyros */
		if(new_config->pyros_arming_min_altitude_m <= 0.0f) {
			return CONFIG_ERR_ALTITUDE_LIMIT;
		}

		/* Validate Pyro Configuration */
		if(new_config->needed_pyro_nb < 1 || new_config->needed_pyro_nb > CONFIG_PYRO_COUNT) {
			return CONFIG_ERR_PYRO_LIMITS;
		}

		bool is_drogue = false;
		for(uint8_t i = 0; i < CONFIG_PYRO_COUNT; i++) {
			if(new_config->pyro_roles[i] == PYRO_ROLE_DROGUE) {
				is_drogue = true;
				break;
			}
		}
		if(!is_drogue) {
			return CONFIG_ERR_PYRO_ROLE;
		}

		/* Validate Apogee Detection Mode */
		if(new_config->apogee_detection_mode >= APOGEE_DETECTION_MAX || new_config->apogee_detection_mode < APOGEE_DETECTION_AUTO) {
			return CONFIG_ERR_APOGEE_DETECTION_MODE;
		}

		/* Validate Acceleration Launch Thresholds */
		if(new_config->z_launch_threshold_acc <= min_config_z_launch_acc || new_config->z_launch_threshold_acc >= max_config_z_launch_acc) {
			return CONFIG_ERR_THRESHOLDS;
		}

		/* Validate Boost Velocity Thresholds */
		if(new_config->boost_phase_threshold_v <= 0.0f) {
			return CONFIG_ERR_THRESHOLDS;
		}

		/* Validate Apogee Velocity Thresholds */
		if(new_config->apogee_detect_threshold_v > max_config_apogee_detect_v) {
			return CONFIG_ERR_THRESHOLDS;
		}

		/* Validate Early Deployment Velocity Thresholds */
		if(new_config->early_deployment_threshold_v < max_config_early_deployment_v || new_config->early_deployment_threshold_v >= new_config->apogee_detect_threshold_v) {
			return CONFIG_ERR_THRESHOLDS;
		}

		/* Validate Apogee Altitude Thresholds */
		if(new_config->main_deploy_altitude_threshold_m < min_config_main_deploy_alt_m) {
			return CONFIG_ERR_THRESHOLDS;
		}

		/* Validate Fire Attempt Limits */
		if(new_config->main_fire_attempt_nb < 1 || new_config->drogue_fire_attempt_nb < 1 || new_config->main_fire_attempt_nb > max_config_pyro_attempts_nb || new_config->drogue_fire_attempt_nb > max_config_pyro_attempts_nb) {
			return CONFIG_ERR_PYRO_LIMITS;
		}

		/* Validate Buzzer Landing Output */
		if(new_config->buzzer_landing_output >= BUZZER_OUTPUT_MAX || new_config->buzzer_landing_output < BUZZER_OUTPUT_DISABLED) {
			return CONFIG_ERR_BUZZER_CONFIG;
		}
    }

    return CONFIG_VALID_OK;
}

int8_t Config_Init(void) {
    odb_config_t temp_config;
    int8_t error = CONFIG_VALID_OK;
    if(W25Q_Read(&w25q, (uint8_t*)&temp_config, FLASH_CONFIG_START_ADDRESS, CONFIG_DATA_SIZE) == 0) {
        if(temp_config.magic_number == CONFIG_MAGIC_NUMBER) {
			if(temp_config.version_major == CONFIG_PROTOCOL_VERSION_MAJOR && temp_config.version_minor == CONFIG_PROTOCOL_VERSION_MINOR && temp_config.payload_size == CONFIG_DATA_SIZE && Utils_Crc32Validate(&temp_config, offsetof(odb_config_t, crc32), temp_config.crc32) && Config_ValidateFields(&temp_config) == CONFIG_VALID_OK) {
                memcpy(&current_config, &temp_config, CONFIG_DATA_SIZE);
                return CONFIG_VALID_OK;
            } else {
            	error = CONFIG_ERR_VERSION;
                DEBUG_PRINTF("WARNING : Config version mismatch (Flash V%d.%d, FW V%d.%d). Loading defaults.\n", temp_config.version_major, temp_config.version_minor, CONFIG_PROTOCOL_VERSION_MAJOR, CONFIG_PROTOCOL_VERSION_MINOR);
            }
        } else {
        	error = CONFIG_ERR_MAGIC_NUMBER;
        }
    }

    Config_LoadDefaults();
    Config_SaveToFlash();

    return error;
}

int8_t Config_SaveToFlash(void) {
	config_error_t validation_result = Config_ValidateFields(&current_config);
	if(validation_result != CONFIG_VALID_OK) {
		return (int8_t)validation_result;
	}
	current_config.crc32 = Utils_Crc32Calculate(&current_config, offsetof(odb_config_t, crc32));

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
	current_config.crc32 = Utils_Crc32Calculate(&current_config, offsetof(odb_config_t, crc32));
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
