/*
 * app_protocol.h
 *
 *  Created on: 6 juin 2026
 *      Author: SamLol12
 */

#ifndef INC_PROTOCOLS_CONFIG_PROTOCOL_H_
#define INC_PROTOCOLS_CONFIG_PROTOCOL_H_

#include <stdint.h>
#include "Protocols/protocol_constants.h"
#include "Utils/utils.h"

/* === Protocol Versioning === */
#define CONFIG_PROTOCOL_VERSION_MAJOR 2
#define CONFIG_PROTOCOL_VERSION_MINOR 9

/* === CALIBRATION STATES === */
#define FLAG_IMU_TEMP_OK  		(1 << 3)
#define FLAG_IMU_6FACES_OK		(1 << 2)
#define FLAG_HIGHG_TEMP_OK   	(1 << 1)
#define FLAG_HIGHG_6FACES_OK	(1 << 0)
#define FLAG_CALIB_RESET		0x000

enum {
    CONFIG_ODB_NAME_SIZE = 32,
    CONFIG_PYRO_COUNT = PROTOCOL_PYRO_COUNT
};

typedef enum {
	STAGE_ROLE_BOOSTER = 2,
	STAGE_ROLE_SUSTAINER = 3
} stage_role_t;

/* === Pyro Role === */
#define PYRO_ROLES(X)			\
    X(PYRO_ROLE_NONE)    		\
    X(PYRO_ROLE_MAIN)  			\
    X(PYRO_ROLE_DROGUE)    		\
    X(PYRO_ROLE_MAIN_BACKUP)	\
	X(PYRO_ROLE_DROGUE_BACKUP)

#define AS_ENUM(NAME) NAME,
#define AS_STRING(NAME) #NAME,

typedef enum {
	PYRO_ROLES(AS_ENUM)
	PYROS_ROLE_MAX
} pyro_role_t;

static const char* const PYRO_ROLES_LOOKUP[] = {
	PYRO_ROLES(AS_STRING)
};

/* === Sensors === */
typedef enum {
	ACC_AXIS_PROFILE_AUTO = 0, 	// Auto remap axis at startup
    ACC_AXIS_PROFILE_P0, 	 	// Default: X forward, Y left, Z up
    ACC_AXIS_PROFILE_P1,		// Horizontal, rotated 90° clockwise (Z up)
    ACC_AXIS_PROFILE_P2,     	// Horizontal, rotated 180° (Z up)
    ACC_AXIS_PROFILE_P3,     	// Horizontal, rotated 270° clockwise (Z up)
    ACC_AXIS_PROFILE_P4,     	// Vertical, rolled +90° (Right side up)
    ACC_AXIS_PROFILE_P5,     	// Vertical, pitched +90° (Front face forward)
    ACC_AXIS_PROFILE_P6,     	// Vertical, rolled -90° (Left side up)
    ACC_AXIS_PROFILE_P7,     	// Vertical, pitched -90° (Back face forward)
	ACC_AXIS_PROFILE_CALIB,	 	// Original mapping for calibration routine
    ACC_AXIS_PROFILE_MAX
} acc_axis_profile_t;

/* === Apogee Detection Mode === */
typedef enum {
	APOGEE_DETECTION_AUTO 		= 0,
    APOGEE_DETECTION_KALMAN,
    APOGEE_DETECTION_BAROMETRIC,
	APOGEE_DETECTION_MAX
} apogee_detection_mode_t;

/* === Buzzer Landing Output === */
typedef enum {
	BUZZER_OUTPUT_DISABLED = 0,
	BUZZER_OUTPUT_ALTITUDE,
	BUZZER_OUTPUT_BIPS,
	BUZZER_OUTPUT_MUSIC,
	BUZZER_OUTPUT_MAX
} buzzer_landing_output;

/* === Configuration Structure === */
typedef struct __attribute__((packed)) {
	uint32_t 			magic_number;

	uint8_t  			version_major;
	uint8_t  			version_minor;
	uint16_t 			payload_size;

    // Profile
    char 				odb_name[CONFIG_ODB_NAME_SIZE]; // max 12 char

    // Stage
    uint8_t 			stage_role;
    uint8_t 			debug_mode;
    uint8_t				flight_test_mode;

    // Sensors
    uint8_t			    axis_profile;
    faces_calibration_t	highg_calib_6faces;
    //faces_calibration_t imu_calib_6faces;
    //coeff_poly3_t		highg_x_calib_temp, highg_y_calib_temp, highg_z_calib_temp,
	//					imu_x_calib_temp, imu_y_calib_temp, imu_z_calib_temp;
    uint8_t				calib_states;	// Current calibration (6faces/temp) states

    // Pyros
    uint8_t				armed_pyros_power_up;
    uint32_t 			fire_attempt_delay_ms;
    float	 			pyros_arming_min_altitude_m;
    uint8_t 			needed_pyro_nb;
    uint8_t 			pyro_roles[CONFIG_PYRO_COUNT];

    // Phase
    uint8_t 			apogee_detection_mode; // 0 = AUTO, 1 = KALMAN, 2 = BAROMETRIC
    uint8_t				enable_early_deployment;
    float 				z_launch_threshold_acc;
    float 				boost_phase_threshold_v;
    float 				apogee_detect_threshold_v;
    float				early_deployment_threshold_v;
    uint32_t 			apogee_failsafe_ms;

    // Parachute
    float 				main_deploy_altitude_threshold_m;
    uint8_t 			drogue_fire_attempt_nb;
    uint8_t 			main_fire_attempt_nb;

    // Buzzer
    uint8_t 			enable_buzzer;
    uint8_t				buzzer_landing_output; // 0 = DISABLE, 1 = ALTITUDE, 2 = MUSIC
    uint16_t 			buzzer_report_tone_hz;

    // IdeFIX
    uint32_t 			idefix_frequency_hz;

    // Integrity
    uint32_t			crc32;

    // TOTAL 123
    // Empty data to reach ... bytes
	//uint8_t padding[0];
} odb_config_t;
#define CONFIG_DATA_SIZE (sizeof(odb_config_t))

#endif /* INC_PROTOCOLS_CONFIG_PROTOCOL_H_ */
