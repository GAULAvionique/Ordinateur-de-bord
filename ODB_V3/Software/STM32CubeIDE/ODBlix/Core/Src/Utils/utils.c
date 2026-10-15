/*
 * utils.c
 *
 *  Created on: 2 mars 2026
 *      Author: SamLol12
 */

#include "Utils/utils.h"
#include "Utils/dwt.h"
#include "stm32f4xx_hal.h"
#include <stdlib.h>
#include <stdarg.h>
#include <math.h>

#define TROPOSPHERE_PRESSURE_HPA 	226.32f     // ZONE 0
#define TROPOPAUSE_PRESSURE_HPA 	54.74f	    // ZONE 1
											    // ZONE 2 STRATOSPHERE (< Tropopause)

#define MAX_OPTIMIZE_ITERATION		15000
#define MIN_OPTIMIZE_ITERATION		50
#define LEARNING_RATE				0.001f
#define H							1e-5f


/* === Offset === */
float Thermal_ComputeOffset(coeff_poly3_t coeffs, float temp) {
    // Horner's method for polynomial evaluation
    return coeffs.c0 + temp * (coeffs.c1 + temp * (coeffs.c2 + temp * coeffs.c3));
}

static float Math_ComputeCost(const float measurements[6][3], const float params[6], float target_gravity) {
    float total_error = 0.0f;
    for(int i = 0; i < 6; i++) {
        // acc_corr = scale * (acc - bias)
        float acc_corr_x = params[0] * (measurements[i][0] - params[3]);
        float acc_corr_y = params[1] * (measurements[i][1] - params[4]);
        float acc_corr_z = params[2] * (measurements[i][2] - params[5]);

        // Cumulative error on all six faces
        float norm = sqrtf(acc_corr_x * acc_corr_x + acc_corr_y * acc_corr_y + acc_corr_z * acc_corr_z);
        float err = norm - target_gravity;
        total_error += err * err;
    }

    return total_error;
}

bool Math_Optimize6FacesCalibration(const float faces[6][3], float target_gravity, faces_calibration_t *out_calib) {
    // faces -> 0=+Z, 1=-Z, 2=+Y, 3=-Y, 4=+X, 5=-X
    if(!out_calib) return false;

    float span_x = fabsf(faces[2][0] - faces[3][0]); // Faces 3-4 (X)
	float span_y = fabsf(faces[4][1] - faces[5][1]); // Faces 5-6 (Y)
	float span_z = fabsf(faces[0][2] - faces[1][2]); // Faces 1-2 (Z)

	// params[0..2] = scale_x, scale_y, scale_z
	// params[3..5] = bias_x,  bias_y,  bias_z
	float params[6];
	params[0] = (span_x > 1.0f) ? (2.0f * target_gravity / span_x) : 1.0f;
	params[1] = (span_y > 1.0f) ? (2.0f * target_gravity / span_y) : 1.0f;
	params[2] = (span_z > 1.0f) ? (2.0f * target_gravity / span_z) : 1.0f;

	params[3] = (faces[2][0] + faces[3][0]) * 0.5f; // Biais X
	params[4] = (faces[4][1] + faces[5][1]) * 0.5f; // Biais Y
	params[5] = (faces[0][2] + faces[1][2]) * 0.5f; // Biais Z

	float prev_cost = Math_ComputeCost(faces, params, target_gravity);
	float current_cost = prev_cost;

	// Gradient
	for(int iter = 0; iter < MAX_OPTIMIZE_ITERATION; iter++) {
		float grad[6];
		for(int p = 0; p < 6; p++) {
			float original_val = params[p];

			params[p] = original_val + H;
			float cost_plus = Math_ComputeCost(faces, params, target_gravity);

			params[p] = original_val - H;
			float cost_minus = Math_ComputeCost(faces, params, target_gravity);

			params[p] = original_val;

			grad[p] = (cost_plus - cost_minus) / (2.0f * H);
		}

		for(int p = 0; p < 6; p++) {
			params[p] -= LEARNING_RATE * grad[p];
		}


		// Convergence threshold
		current_cost = Math_ComputeCost(faces, params, target_gravity);
		if(iter > MIN_OPTIMIZE_ITERATION && fabsf(current_cost - prev_cost) < 1e-6f) {
			break;
		}
		prev_cost = current_cost;
	}

	// Sanity check
	if(isnan(current_cost) || isinf(current_cost) || current_cost > 5.0f) {
		return false;
	}

	for(int i = 0; i < 3; i++) {
		float scale = params[i];
		float bias = params[i + 3];

		// 15% error
		if(isnan(scale) || isinf(scale) || scale < 0.85f || scale > 1.15f) {
			return false;
		}

		// Max bias tolerance (4m/s2)
		if(isnan(bias) || isinf(bias) || fabsf(bias) > 4.0f) {
			return false;
		}
	}

	out_calib->scale_matrix[0] = params[0];
	out_calib->scale_matrix[1] = params[1];
	out_calib->scale_matrix[2] = params[2];

	out_calib->bias[0] = params[3];
	out_calib->bias[1] = params[4];
	out_calib->bias[2] = params[5];

	return true;
}

void Math_Compute6FacesCalibration(float accel[3], const faces_calibration_t *calib) {
    if(!calib) return;

    accel[0] = calib->scale_matrix[0] * (accel[0] - calib->bias[0]);
    accel[1] = calib->scale_matrix[1] * (accel[1] - calib->bias[1]);
    accel[2] = calib->scale_matrix[2] * (accel[2] - calib->bias[2]);
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

float Math_GetLocalGravity(float current_lat, float current_alt) {
    float lat_rad = current_lat * (M_PI / 180.0f);
    float sin_lat = sinf(lat_rad);
    float sin_2lat = sinf(2.0f * lat_rad);

    float g_lat = 9.780327f * (1.0f + 0.0053024f * (sin_lat * sin_lat) - 0.0000058f * (sin_2lat * sin_2lat));
    float g_local = g_lat - 3.086e-6f * current_alt;

    return g_local;
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

/* === DEBUG === */
void InertialNav_Init(inertial_nav_t *nav, float initial_alt) {
    nav->z = initial_alt;
    nav->v = 0.0f;
    nav->last_cycles = DWT_GetCycles();
}

void InertialNav_Update(inertial_nav_t *nav, float acc_vertical) {
    uint32_t now_cycles = DWT_GetCycles();
    uint32_t diff_cycles = now_cycles - nav->last_cycles;
    float dt = (float)diff_cycles / (float)SystemCoreClock;
    nav->last_cycles = now_cycles;

    if(dt <= 0.0f) return;
    if(dt > 0.5f) dt = 0.5f;

    // v = v0 + a * dt
    nav->v += acc_vertical * dt;

    // z = z0 + v * dt + 0.5 * a * dt^2
    nav->z += nav->v * dt + 0.5f * acc_vertical * dt * dt;
}
/* =========== */
