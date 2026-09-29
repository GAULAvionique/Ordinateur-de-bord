/*
 * kalman_nav.c
 *
 *  Created on: 24 avr. 2026
 *      Author: SamLol12
 */


#include "Drivers/LowLevel/kalman_nav.h"
#include "Utils/dwt.h"
#include "Systems/config.h"
#include "stm32f4xx_hal.h"

extern uint32_t SystemCoreClock;


void KalmanNav_Init(kalman_nav_t *dev, float mean_alt, float *samples, uint8_t sample_count) {
	if(!dev | (sample_count == 0)) return;

    dev->z = mean_alt;
    dev->v = 0.0f;
    dev->a_bias = 0.0f;
    // Calculate variance of the altitude measurements for initial noise estimation
    float variance = 0;
    for(int i = 0; i < sample_count; i++) {
        variance += (samples[i] - mean_alt) * (samples[i] - mean_alt);
    }
    variance /= sample_count;
    if(variance < 0.01f) {
		variance = 0.01f;
	}

    // Init covariance matrix P
    for(int i = 0; i < 3; i++) {
        for(int j = 0; j < 3; j++) {
            dev->P[i][j] = 0.0f;
        }
    }
    dev->P[0][0] = variance;    // Initial uncertainty in altitude
    dev->P[1][1] = 10.0f;       // Initial uncertainty in speed
    dev->P[2][2] = 1.0f;        // Initial uncertainty in acceleration bias

    dev->Q_accel    	= Q_ACCEL;
    dev->Q_bias     	= Q_BIAS;
    dev->R_static   	= variance;
    dev->R_alt      	= variance;
    dev->last_cycles  	= DWT_GetCycles();
}

/*
 * acc_world_z should be the vertical acceleration in the world frame (m/s2) (after removing gravity and transforming from body frame using IMU gyro/mag data)
 * > 200Hz
*/
void KalmanNav_Predict(kalman_nav_t *dev, float acc_world_z) {
    uint32_t now_cycles = DWT_GetCycles();
    uint32_t diff_cycles = now_cycles - dev->last_cycles;
    float dt = (float)diff_cycles / (float)SystemCoreClock;
    dev->last_cycles = now_cycles;

    // Overflow security check
	if(dt <= 0.0f) return;
	if(dt > 0.5f) {
		dt = 0.5f;
	}

    // State prediction
    float a = acc_world_z - dev->a_bias;
    dev->z += dev->v * dt + 0.5f * a * dt * dt;
    dev->v += a * dt;

    // Covariance update P = FPF' + Q 
    // [1  dt  -0.5*dt^2]
    // [0  1   -dt      ]
    // [0  0    1       ]
    float p00 = dev->P[0][0], p01 = dev->P[0][1], p02 = dev->P[0][2];
    float p10 = dev->P[1][0], p11 = dev->P[1][1], p12 = dev->P[1][2];
    float p20 = dev->P[2][0], p21 = dev->P[2][1], p22 = dev->P[2][2];

    // Update P
    float dt2 = dt * dt;
    float new_p00 = p00 + dt*(p10 + p01 + dt*p11) - 0.5f*dt2*(p20 + p02 + dt*p21 + dt*p12) + 0.25f*dt2*dt2*p22 + dev->Q_accel * 0.25f * dt2 * dt2;
    float new_p01 = p01 + dt*p11 - 0.5f*dt2*p21 - dt*p02 - dt2*p12 + 0.5f*dt2*dt*p22;
    float new_p02 = p02 + dt*p12 - 0.5f*dt2*p22;
    float new_p11 = p11 - dt*(p21 + p12) + dt2*p22 + dev->Q_accel * dt2;
    float new_p12 = p12 - dt*p22;
    float new_p22 = p22 + dev->Q_bias * dt;

    dev->P[0][0] = new_p00; dev->P[0][1] = new_p01; dev->P[0][2] = new_p02;
    dev->P[1][0] = new_p01; dev->P[1][1] = new_p11; dev->P[1][2] = new_p12;
    dev->P[2][0] = new_p02; dev->P[2][1] = new_p12; dev->P[2][2] = new_p22;
}

/*
 * measured_alt should be the altitude measurement from the barometer
 * > 50Hz
*/
void KalmanNav_Update(kalman_nav_t *dev, float measured_alt, bool is_machlock) {
    // Dynamic Measurement Noise Covariance (R_alt) & Mach Lock Override
    if(is_machlock || dev->z >= ALT_90K_M) {
        // If we're above Mach lock velocity or above 90k m, we consider the altitude measurement by barometer to be unreliable and increase R_alt to reduce its influence on the state update
        dev->R_alt = R_PENALTY;
    } else if(dev->z >= ALT_60K_M) {
        // If we're above 60k m, we consider the altitude measurement by barometer to be less reliable and increase R_alt moderately
        dev->R_alt = dev->R_static * 10.0f;
    } else {
        // Below 60k m, we consider the altitude measurement by barometer to be reliable and use the static R value based on initialization
        dev->R_alt = dev->R_static * 0.1f;
    }

    // Innovation
    float y = measured_alt - dev->z;

    // Kalman scale K = PH' (HPH' + R)^-1
    float S = dev->P[0][0] + dev->R_alt;
    // Spikes protection: 3.0f * sqrtf(S) for respect the 3-sigma rule
    if(y*y > 9.0f * S && y*y > 10000.0f) {
    	dev->P[0][0] += dev->R_alt * 0.1f;
    	dev->P[1][1] += dev->Q_accel * 0.1f;

    	// Clamp
    	if(dev->P[0][0] > 1000.0f) dev->P[0][0] = 1000.0f;
    	if(dev->P[1][1] > 1000.0f) dev->P[1][1] = 1000.0f;
        return;
    }

    float K[3];
    K[0] = dev->P[0][0] / S;
    K[1] = dev->P[1][0] / S;
    K[2] = dev->P[2][0] / S;

    // State update
    dev->z += K[0] * y;
    dev->v += K[1] * y;
    dev->a_bias += K[2] * y;

    // Covariance update P = (I - KH)P
    float p00 = dev->P[0][0], p01 = dev->P[0][1], p02 = dev->P[0][2];
    dev->P[0][0] -= K[0] * p00; dev->P[0][1] -= K[0] * p01; dev->P[0][2] -= K[0] * p02;
    dev->P[1][0] -= K[1] * p00; dev->P[1][1] -= K[1] * p01; dev->P[1][2] -= K[1] * p02;
    dev->P[2][0] -= K[2] * p00; dev->P[2][1] -= K[2] * p01; dev->P[2][2] -= K[2] * p02;

    // Symetrie
    dev->P[0][1] = dev->P[1][0] = (dev->P[0][1] + dev->P[1][0]) * 0.5f;
    dev->P[0][2] = dev->P[2][0] = (dev->P[0][2] + dev->P[2][0]) * 0.5f;
    dev->P[1][2] = dev->P[2][1] = (dev->P[1][2] + dev->P[2][1]) * 0.5f;
}
