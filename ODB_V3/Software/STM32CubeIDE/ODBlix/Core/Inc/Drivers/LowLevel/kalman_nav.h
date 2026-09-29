/*
 * kalman_nav.h
 *
 *  Created on: 24 avr. 2026
 *      Author: SamLol12
 */

#ifndef INC_DRIVERS_LOWLEVEL_KALMAN_NAV_H_
#define INC_DRIVERS_LOWLEVEL_KALMAN_NAV_H_

#include <stdint.h>
#include <stdbool.h>


#define Q_ACCEL 0.5f // Process noise for acceleration (tune based on IMU/HIGHG noise)
#define Q_BIAS 0.001f // Process noise for bias (tune based on IMU/HIGHG noise)

// Altitude thresholds for Dynamic R adjustment
#define ALT_60K_M 	60000.0f
#define ALT_90K_M	90000.0f

#define R_PENALTY   1000.0f

#define KALMAN_NAV_SAMPLE_NB 50


typedef struct {
    // State variables
    float       z;      // Filtered altitude (m)
    float       v;      // Vertical speed estimated (World Frame) (m/s)
    float       a_bias; // Acceleration bias (m/s^2)

    // Covariance matrix of the error
    float       P[3][3];
    // Noise parameters
    float       Q_accel;  // Process noise (acceleration)
    float       Q_bias;   // Bias drift
    float       R_static; // Covariance noise of the measurement on the ground (initialization)
    float       R_alt;    // Dynamic covariance noise of the measurement (in flight)
    uint32_t    last_cycles;
} kalman_nav_t;


void KalmanNav_Init(kalman_nav_t *dev, float mean_alt, float *samples, uint8_t sample_count);

void KalmanNav_Predict(kalman_nav_t *dev, float acc_world_z);
void KalmanNav_Update(kalman_nav_t *dev, float measured_alt, bool is_machlock);

#endif /* INC_DRIVERS_LOWLEVEL_KALMAN_NAV_H_ */
