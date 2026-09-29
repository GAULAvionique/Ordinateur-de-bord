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

#define GRAVITY_MS2 			9.80665f	// m/s2
#define G_TO_MS2(g) 			((GRAVITY_MS2) * (g))
#define PRESSURE_SEA_LEVEL_HPA	1013.25f    // hPa

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
    float scale_matrix[3][3];
    float bias[3];
} faces_calibration_t;

float Thermal_ComputeOffset(coeff_poly3_t coeffs, float temp);
float Math_ComputeWorldVerticalAcc(const float accel[3], const float quat[4], bool gravity_compensation);
void Math_6FacesCalibration(float accel[3], const faces_calibration_t *calib);
/* =========== */

/* === Altitude === */
float Math_ComputeAltitudeMSL(float current_pressure);
float Math_ComputeAltitudeAGL(float current_pressure, float ground_elevation_msl);
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
/* =========== */


#endif /* INC_UTILS_UTILS_H_ */
