/*
 * utils.h
 *
 *  Created on: 2 mars 2026
 *      Author: AudaceLol12
 */

#ifndef INC_UTILS_UTILS_H_
#define INC_UTILS_UTILS_H_

#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>
#include <stddef.h>

#define M_PI 					3.14159265358979323846f
#define GRAVITY_MS2 			9.80665f	// m/s2
#define G_TO_MS2(g) 			((GRAVITY_MS2) * (g))
#define PRESSURE_SEA_LEVEL_HPA	1013.25f    // hPa
#define ACC_MAX_SWITCH_G		29.42f		// 3.0G

#define DEBUG_PRINTF(...) do { \
    if(current_config.debug_mode == STATE_TRUE) { \
        printf(__VA_ARGS__); \
    } \
} while(0)

/* === Offset === */
typedef struct {
    float c0;
    float c1;
    float c2;
    float c3;
} coeff_poly3_t;

typedef struct {
    float scale_matrix[3]; // Only scale_matrix[0][0], [1][1], [2][2], all others are 0.0f
    float bias[3];
} faces_calibration_t;

float Thermal_ComputeOffset(coeff_poly3_t coeffs, float temp);
bool Math_Optimize6FacesCalibration(const float faces[6][3], float target_gravity, faces_calibration_t *out_calib);
void Math_Compute6FacesCalibration(float accel[3], const faces_calibration_t *calib);
/* =========== */

/* === Altitude & Acceleration === */
float Math_ComputeAltitudeMSL(float current_pressure);
float Math_ComputeAltitudeAGL(float current_pressure, float ground_elevation_msl);
float Math_ComputeWorldVerticalAcc(const float accel[3], const float quat[4], bool gravity_compensation);
float Math_GetLocalGravity(float current_lat, float current_alt);
/* =========== */

/* === CRC === */
uint32_t Utils_Crc32Calculate(const void *data, size_t size);
bool Utils_Crc32Validate(const void *data, size_t size, uint32_t expected_crc);
/* =========== */

/* === HELPERS === */
typedef enum {
    STATE_FALSE = 0U,
    STATE_TRUE = 1U
} state_t;


typedef struct {
	uint32_t  	start_time;
	uint32_t  	elapsed_time_ms;
	uint8_t		elapsed_time_s;
	uint16_t  	elapsed_time_m;
	uint16_t  	elapsed_time_remaining_ms;
} runTimer_t;

void RunTimer_Init(runTimer_t *dev);
void RunTimer_Update(runTimer_t *dev);
int printt(const char *format, ...);

void Utils_MovingAverage(uint32_t *values, uint32_t size, uint8_t window_size, uint32_t *average);
/* =========== */

/* === DEBUG === */
typedef struct {
    float z;
    float v;
    uint32_t last_cycles;
} inertial_nav_t;

void InertialNav_Init(inertial_nav_t *nav, float initial_alt);
void InertialNav_Update(inertial_nav_t *nav, float acc_vertical);
/* =========== */


#endif /* INC_UTILS_UTILS_H_ */
