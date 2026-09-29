/*
 * utils.c
 *
 *  Created on: 2 mars 2026
 *      Author: SamLol12
 */

#include "Utils/utils.h"
#include "stm32f4xx_hal.h"
#include <stdlib.h>
#include <stdarg.h>
#include <math.h>

#define TROPOSPHERE_PRESSURE_HPA 	226.32f     // ZONE 0
#define TROPOPAUSE_PRESSURE_HPA 	54.74f	    // ZONE 1
											    // ZONE 2 STRATOSPHERE (< Tropopause)

/* === Offset === */
float Thermal_ComputeOffset(coeff_poly3_t coeffs, float temp) {
    // Horner's method for polynomial evaluation
    return coeffs.c0 + temp * (coeffs.c1 + temp * (coeffs.c2 + temp * coeffs.c3));
}

float Math_ComputeWorldVerticalAcc(const float accel[3], const float quat[4], bool gravity_compensation) {
    float qw = quat[0], qx = quat[1], qy = quat[2], qz = quat[3];
    float ax = accel[0], ay = accel[1], az = accel[2];

    // Check normalization of quaternion to avoid errors in computation (qw^2 + qx^2 + qy^2 + qz^2 = 1)
    float norm_sq = qw * qw + qx * qx + qy * qy + qz * qz;
    if(fabsf(norm_sq - 1.0f) > 0.01f) {
        float inv_norm = 1.0f / sqrtf(norm_sq);
        qw *= inv_norm;
        qx *= inv_norm;
        qy *= inv_norm;
        qz *= inv_norm;
    }

    // Rotate accelerometer vector to world frame and extract vertical component
    float a_world_z = (2.0f * (qx * qz - qw * qy)) * ax + (2.0f * (qy * qz + qw * qx)) * ay + (qw * qw - qx * qx - qy * qy + qz * qz) * az;
    if(gravity_compensation) {
        a_world_z -= GRAVITY_MS2;
    }

    return a_world_z;
}

void Math_6FacesCalibration(float accel[3], const faces_calibration_t *calib) {
	if(!calib) return;

	float temp[3];
	temp[0] = accel[0] - calib->bias[0];
	temp[1] = accel[1] - calib->bias[1];
	temp[2] = accel[2] - calib->bias[2];

	accel[0] = calib->scale_matrix[0][0] * temp[0] + calib->scale_matrix[0][1] * temp[1] + calib->scale_matrix[0][2] * temp[2];
	accel[1] = calib->scale_matrix[1][0] * temp[0] + calib->scale_matrix[1][1] * temp[1] + calib->scale_matrix[1][2] * temp[2];
	accel[2] = calib->scale_matrix[2][0] * temp[0] + calib->scale_matrix[2][1] * temp[1] + calib->scale_matrix[2][2] * temp[2];
}
/* =========== */

/* === Altitude === */
float Math_ComputeAltitudeMSL(float current_pressure) {
    float altitude_msl_m = 0.0f;
    if(current_pressure > TROPOSPHERE_PRESSURE_HPA) { // ZONE 0 : TROPOSPHERE (0 to 11000 m)
    	altitude_msl_m = 44330.0f * (1.0f - powf(current_pressure / PRESSURE_SEA_LEVEL_HPA, 0.190295f));
    } else if(current_pressure <= TROPOSPHERE_PRESSURE_HPA && current_pressure > TROPOPAUSE_PRESSURE_HPA) { // ZONE 1 : TROPOPAUSE (11 000 to 20000 m)
    	altitude_msl_m = 11000.0f - 6341.6f * logf(current_pressure / TROPOSPHERE_PRESSURE_HPA);
    } else { // ZONE 2 : STRATOSPHERE (> 20000 m)
    	altitude_msl_m = 20000.0f + 216650.0f * (powf(current_pressure / TROPOPAUSE_PRESSURE_HPA, -0.02927f) - 1.0f);
    }

    return altitude_msl_m;
}

float Math_ComputeAltitudeAGL(float current_pressure, float ground_elevation_msl) {
    return Math_ComputeAltitudeMSL(current_pressure) - ground_elevation_msl;
}
/* =========== */

/* === HELPERS === */
runTimer_t run_timer;

void RunTimer_Init(runTimer_t* dev) {
	  dev->start_time = HAL_GetTick();
	  dev->elapsed_time_ms = 0;
	  dev->elapsed_time_s = 0;
	  dev->elapsed_time_m = 0;
	  dev->elapsed_time_remaining_ms = 0;
}

void RunTimer_Update(runTimer_t *dev) {
	dev->elapsed_time_ms = HAL_GetTick() - dev->start_time;

	dev->elapsed_time_s = (dev->elapsed_time_ms / 1000) % 60;
	dev->elapsed_time_m = (dev->elapsed_time_ms / 60000);
	dev->elapsed_time_remaining_ms = dev->elapsed_time_ms % 1000;
}

int printt(const char *format, ...) {
    va_list args;
    va_start(args, format);
    RunTimer_Update(&run_timer);
    printf("[%03d:%02d:%03d] ",run_timer.elapsed_time_m, run_timer.elapsed_time_s, run_timer.elapsed_time_remaining_ms);

    int ret = vprintf(format, args);

    va_end(args);

    return ret;
}

uint32_t Utils_Crc32Calculate(const void *data, size_t size) {
    const uint8_t *bytes = (const uint8_t *)data;
    uint32_t crc = 0xFFFFFFFFU;

    if(data == NULL) {
        return 0U;
    }

    for(size_t i = 0; i < size; i++) {
        crc ^= bytes[i];
        for(uint8_t bit = 0; bit < 8U; bit++) {
            crc = (crc >> 1U) ^ (0xEDB88320U & (uint32_t)-(int32_t)(crc & 1U));
        }
    }

    return ~crc;
}

bool Utils_Crc32Validate(const void *data, size_t size, uint32_t expected_crc) {
    return data != NULL && Utils_Crc32Calculate(data, size) == expected_crc;
}

/*
int _write(int le, char *ptr, int len) {
    int DataIdx;
    for (DataIdx = 0; DataIdx < len; DataIdx++) {
        ITM_SendChar(*ptr++);
    }

    return len;
}
*/
/* =========== */
