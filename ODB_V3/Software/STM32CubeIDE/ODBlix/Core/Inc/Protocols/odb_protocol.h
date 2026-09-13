/*
 * telemetry_protocol.h
 *
 *  Created on: 6 juin 2026
 *      Author: gagno
 */

#ifndef INC_PROTOCOLS_ODB_PROTOCOL_H_
#define INC_PROTOCOLS_ODB_PROTOCOL_H_

#include <stdint.h>
#include <stdbool.h>

/* === Protocol Versioning === */
#define ODB_PROTOCOL_VERSION_MAJOR 1
#define ODB_PROTOCOL_VERSION_MINOR 3

/* === ODB === */
// Init system_states
/*
 * [14] : IdeFIX communication OK
 * [13] : Bluetooth module OK
 * [12] : Flash memory OK
 * [11] : SD card OK
 * [10] : Temperature sensor OK
 * [9] : High-G accelerometer OK
 * [8]  : GPS OK
 * [7]  : Barometer OK
 * [6]  : IMU OK
 * [5]  : Radio OK
 * [4]  : Pyro arming module OK
 * [3]  : Pyro 1 connected
 * [2]  : Pyro 2 connected
 * [1]  : Pyro 3 connected
 * [0]  : Pyro 4 connected
*/
#define FLAG_IDEFIX_OK                  (1 << 14)
#define FLAG_BT_OK                      (1 << 13)
#define FLAG_FLASH_OK                   (1 << 12)
#define FLAG_SD_OK                      (1 << 11)
#define FLAG_TEMP_OK                    (1 << 10)
#define FLAG_HIGHG_OK                   (1 << 9)
#define FLAG_GPS_OK                     (1 << 8)
#define FLAG_BARO_OK                    (1 << 7)
#define FLAG_IMU_OK                     (1 << 6)
#define FLAG_RADIO_OK                   (1 << 5)
#define FLAG_PYROS_ARMED_OK             (1 << 4)
#define FLAG_PYRO1_CONN                 (1 << 3)
#define FLAG_PYRO2_CONN                 (1 << 2)
#define FLAG_PYRO3_CONN                 (1 << 1)
#define FLAG_PYRO4_CONN                 (1 << 0)
// Events states
/*
 * [8]  : Mach lock enabled
 * [7]  : Drogue deployed
 * [6]  : Main deployed
 * [5]  : Apogee detected
 * [4]  : Pyro 4 fired
 * [3]  : Pyro 3 fired
 * [2]  : Pyro 2 fired
 * [1]  : Pyro 1 fired
 * [0]	: Pyros armed
*/
#define FLAG_PYROS_ARMED				(1 << 0)
#define FLAG_PYRO1_FIRED                (1 << 1)
#define FLAG_PYRO2_FIRED                (1 << 2)
#define FLAG_PYRO3_FIRED                (1 << 3)
#define FLAG_PYRO4_FIRED                (1 << 4)
#define FLAG_APOGEE_DETECTED            (1 << 5)
#define FLAG_MAIN_DEPLOYED              (1 << 6)
#define FLAG_DROGUE_DEPLOYED            (1 << 7)
#define FLAG_MACH_LOCK_ENABLED          (1 << 8)
///...

// pyro event stucture with time of event and pyro number
typedef struct __attribute__((packed)) {
    bool fired;
    uint32_t time_ms;
} pyro_event_t;

// window event structure with start/end time of event
typedef struct __attribute__((packed)) {
    bool activated;
    uint32_t start_time_ms;
    uint32_t end_time_ms;
} window_event_t;

// metrics structure with value and time of occurrence
typedef struct __attribute__((packed)) {
    bool valid;
    float value;
    uint32_t time_ms;
} metric_t;

typedef struct __attribute__((packed)) {
	//uint32_t preflight_static_oriented;
    uint32_t preflight_pyros_test;
    uint32_t preflight_waiting_flight;
    uint32_t armed;
    uint32_t inflight_boost;
    uint32_t inflight_fast;
    uint32_t inflight_coast;
    uint32_t inflight_drogue;
    uint32_t inflight_main;
    uint32_t inflight_landed;
    uint32_t postflight;
} fsm_transitions_t;

// states of the events for statistics reporting
typedef struct __attribute__((packed)) {
	uint32_t flight_id;				// in event state

    uint32_t date;       			// internal event for POSTFLIGHT reporting (save in FLASH/SD)

    pyro_event_t pyro1;				// in event state
    pyro_event_t pyro2;				// in event state
    pyro_event_t pyro3;				// in event state
    pyro_event_t pyro4;				// in event state
    window_event_t pyros_arm;		// in event state
    window_event_t mach_lock;		// in event state

    metric_t max_altitude_gps;      // internal event for POSTFLIGHT reporting (save in FLASH/SD)
    metric_t max_altitude_baro;     // internal event for POSTFLIGHT reporting (save in FLASH/SD)
    metric_t max_altitude_kalman;   // internal event for POSTFLIGHT reporting (save in FLASH/SD)

    metric_t apogee;				// in event state
    metric_t main_deploy;			// in event state
    metric_t drogue_deploy;			// in event state

    metric_t max_ascend_speed;      // internal event for POSTFLIGHT reporting (save in FLASH/SD)
    metric_t max_ascend_accel;      // internal event for POSTFLIGHT reporting (save in FLASH/SD)
    metric_t max_descend_speed;     // internal event for POSTFLIGHT reporting (save in FLASH/SD)
    metric_t max_descend_accel;     // internal event for POSTFLIGHT reporting (save in FLASH/SD)

    int32_t	 last_lat;              // internal event for POSTFLIGHT reporting (save in FLASH/SD)
    int32_t  last_lon;              // internal event for POSTFLIGHT reporting (save in FLASH/SD)
    uint32_t flight_time_ms;		// internal event for POSTFLIGHT reporting (save in FLASH/SD)
    uint32_t flight_start_time_ms;	// internal event for POSTFLIGHT reporting (save in FLASH/SD)

    fsm_transitions_t fsm_trans;	// internal event for POSTFLIGHT reporting (save in FLASH/SD)

    uint32_t missed_frames;			// internal event for POSTFLIGHT reporting (save in FLASH/SD)

    // TOTAL 152
} odb_stats_t;
#define ODB_STATS_SIZE sizeof(odb_stats_t)

// Main ODB data structure
typedef struct __attribute__((packed)) {
	uint8_t  	version_major;
	uint8_t  	version_minor;
	uint16_t 	payload_size;
    // Status
    uint32_t    time_boot_ms;       // Timestamp since system boot in milliseconds (ms)
    uint16_t    system_states;      // Current system/component states
    uint16_t    event_states;       // Current events states (pyros fired, apogee detected, etc.) -> linked with odb_stats_t
    uint8_t     mission_state;      // Mission state (preflight, inflight, postflight) -> Linked with FSM
    uint16_t    battery_mv;         // Main battery voltage in millivolts (mV)
    uint16_t	pyros_mv[4];		// Each pyros voltage in millivolts (mV)
    // IMU (Attitude & Rates)
    float       roll;               // Roll angle in degrees (converted to cdeg for MAVLink) -> Linked with BNO055
    float       pitch;              // Pitch angle in degrees (converted to cdeg for MAVLink) -> Linked with BNO055
    float       yaw;                // Yaw angle in degrees between -180 and 180 (converted to cdeg for MAVLink) -> Linked with BNO055
    float       imu_acc_x;          // IMU Acceleration X in m/s2 (converted to cm/s2 for MAVLink) -> Linked with BNO055
    float       imu_acc_y;          // IMU Acceleration Y in m/s2 (converted to cm/s2 for MAVLink) -> Linked with BNO055
    float       imu_acc_z;          // IMU Acceleration Z in m/s2 (converted to cm/s2 for MAVLink) -> Linked with BNO055
    float       imu_gyro_x;         // IMU Angular rate X in deg/s (converted to cdeg/s for MAVLink) -> Linked with BNO055
    float       imu_gyro_y;         // IMU Angular rate Y in deg/s (converted to cdeg/s for MAVLink) -> Linked with BNO055
    float       imu_gyro_z;         // IMU Angular rate Z in deg/s (converted to cdeg/s for MAVLink) -> Linked with BNO055
    float		imu_mag_x;			// IMU Magnetometer X in uT (converted to cuT for MAVLink) -> Linked with BNO055
    float		imu_mag_y;			// IMU Magnetometer Y in uT (converted to cuT for MAVLink) -> Linked with BNO055
    float		imu_mag_z;			// IMU Magnetometer Z in uT (converted to cuT for MAVLink) -> Linked with BNO055
    float		imu_temp;			// IMU Temperature in °C (converted to °cC for MAVLink) -> Linked with BNO055
    // Pressure & Temp
    float		altitude_agl_m;		// Altitude in m (converted to cm for MAVLink) from barometer referenced with the sea level (AGL)-> Linked with MS5611
    float       pressure_pa;       	// Atmospheric pressure in Pa (converted to hPa for MAVLink) -> Linked with MS5611
    float       temp_celsius;       // Board or environment temperature in °C (converted to °cC for MAVLink) -> Linked with MAX6612MXK
    // High-G Acclerometer
    float       highg_acc_x;        // High-G Acceleration X in m/s2 (converted to cm/s2 for MAVLink) -> Linked with ADXL382
    float       highg_acc_y;        // High-G Acceleration Y in m/s2 (converted to cm/s2 for MAVLink) -> Linked with ADXL382
    float       highg_acc_z;        // High-G Acceleration Z in m/s2 (converted to cm/s2 for MAVLink) -> Linked with ADXL382
    float		highg_temp;			// High-G Temperature in °C (converted to °cC for MAVLink) -> Linked with ADXL382
    // GPS
    uint8_t     gps_fix;            // 1 = Active fix, 0 = Void/No fix, 2 = ... -> Linked with L76LM33
    int32_t     lat;                // Latitude in degE7 (MAVLink format: deg * 10^7) -> Linked with L76LM33
    int32_t     lon;                // Longitude in degE7 (MAVLink format: deg * 10^7) -> Linked with L76LM33
    int32_t     gps_alt;            // Altitude (MSL) based on GPS in mm -> Linked with L76LM33
    uint16_t    vel;                // Ground velocity in cm/s -> Linked with L76LM33
    uint16_t    cog;                // Course Over Ground in centi-degrees -> Linked with L76LM33
    uint8_t     satellites_nb;      // Number of satellites used for the fix -> Linked with L76LM33
    // SD
    uint16_t	sd_space;			// Available space in current sd card -> Linked with MEM2067

    // Statistics
    float       imu_acc_vertical;   // Vertical acceleration (World frame) from IMU in m/s2 (converted to cm/s2 for MAVLink) -> Linked with BNO055
    float       highg_acc_vertical; // Vertical acceleration (World frame) from High-G Accelerometer in m/s2 (converted to cm/s2 for MAVLink) -> Linked with ADXL382
    float       kalman_z;           // filtered altitude from Kalman filter in m (converted to cm for MAVLink) referenced with the above ground level (AGL) -> altitude_msl_m - initial altitude value
    float       kalman_v;           // filtered velocity from Kalman filter in m/s (converted to cm/s for MAVLink)

    // TOTAL 135 + 4 (header)
    // Empty data to reach 140 bytes
    uint8_t padding[1];
} odb_data_t;
#define ODB_DATA_SIZE sizeof(odb_data_t)
//_Static_assert(sizeof(odb_data_t) == 128, "odb_data_t_size_error");

#endif /* INC_PROTOCOLS_ODB_PROTOCOL_H_ */
