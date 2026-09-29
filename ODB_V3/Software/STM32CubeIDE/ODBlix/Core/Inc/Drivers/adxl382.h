/*
 * adxl382.h
 *
 *  Created on: 13 avr. 2026
 *      Author: SamLol12
 */

#ifndef INC_DRIVERS_ADXL382_H_
#define INC_DRIVERS_ADXL382_H_

#include "Protocols/config_protocol.h"
#include "Utils/utils.h"
#include "stm32f4xx_hal.h"
#include <stdint.h>
#include <stdbool.h>


#define ADXL382_I2C_ADDR (0x1D << 1)


typedef enum {
    ADXL382_OK 			= 0,
    ADXL382_ERROR 		= -1,
    ADXL382_I2C_ERROR 	= -2,
    ADXL382_ID_ERROR 	= -3,
    ADXL382_MODE_ERROR 	= -4,
    ADXL382_RANGE_ERROR = -5
} adxl382_error_t;

typedef enum {
    ADXL382_MODE_STANDBY = 0x00,
    ADXL382_MODE_HS      = 0x01, // Heart Sounds
    ADXL382_MODE_ULP     = 0x02, // Ultra Low Power
    ADXL382_MODE_VLP     = 0x03, // Very Low Power
    ADXL382_MODE_LP      = 0x04, // Low Power
    ADXL382_MODE_RBW     = 0x08, // Reduced Bandwidth
    ADXL382_MODE_HP      = 0x0C  // High Performance
} adxl382_mode_t;

typedef enum {
    ADXL382_RANGE_15G = 0x00,
    ADXL382_RANGE_30G = 0x01,
    ADXL382_RANGE_60G = 0x02
} adxl382_range_t;

typedef enum {
    ADXL382_OR_FULL_SCALE = 0x00,
    ADXL382_OR_HOLD_PREV  = 0x01,
    ADXL382_OR_INVALID    = 0x02
} adxl382_or_behavior_t;

typedef enum {
    ADXL382_SINC_32X = 0x00,
    ADXL382_SINC_16X = 0x01
} adxl382_sinc_rate_t;

typedef enum {
    ADXL382_ROUND_TRUNCATE = 0x00,
    ADXL382_ROUND_FLOOR    = 0x01
} adxl382_round_mode_t;

typedef enum {
    ADXL382_LPF_NONE    = 0x00,
    ADXL382_LPF_ODR_4   = 0x01, // 1/4 ODR
    ADXL382_LPF_ODR_8   = 0x02, // 1/8 ODR
    ADXL382_LPF_ODR_16  = 0x03  // 1/16 ODR
} adxl382_lpf_mode_t;

typedef enum {
    ADXL382_HPF_SAR = 0x00,     // HPF SAR (LP)
    ADXL382_HPF_DSM = 0x01      // HPF DSM (HP)
} adxl382_hpf_path_t;

typedef enum {
    ADXL382_HPF_NONE      = 0x00,
    ADXL382_HPF_24_7E_4   = 0x01, // 24.7E-4 * ODR
    ADXL382_HPF_6_2E_4    = 0x02, // 6.2084E-4 * ODR
    ADXL382_HPF_1_5E_4    = 0x03, // 1.5545E-4 * ODR
    ADXL382_HPF_0_38E_4   = 0x04, // 0.3862E-4 * ODR
    ADXL382_HPF_0_09E_4   = 0x05, // 0.0954E-4 * ODR
    ADXL382_HPF_0_02E_4   = 0x06  // 0.0238E-4 * ODR
} adxl382_hpf_corner_t;

typedef struct {
    // TRIG_CFG (0x49)
    bool                    iir7_bypass;   // true = Bypass IIR7
    adxl382_sinc_rate_t     sinc_rate;
    bool                    iir1_enable;   // true = Active IIR first order (low latency)
    adxl382_round_mode_t    round_mode;

    // FILTER (0x50)
    bool                    dcf_bypass;    // true = Bypass Droop compensation
    bool                    eq_bypass;     // true = Bypass EQ (needed in LPF mode)
    adxl382_lpf_mode_t      lpf_mode;
    adxl382_hpf_path_t      hpf_path;
    adxl382_hpf_corner_t    hpf_corner;    // Cutoff HPF

    // OR_CFG (0x48)
    adxl382_or_behavior_t   or_behavior;   // Overrange
} adxl382_filters_t;

typedef struct {
    I2C_HandleTypeDef               *hi2c;
    adxl382_mode_t                  mode;
    adxl382_range_t                 range;
    adxl382_filters_t            	filters_cfg;
    acc_axis_profile_t              axis_profile;
    coeff_poly3_t					x_axis_offset, y_axis_offset, z_axis_offset;
    faces_calibration_t				faces_offset;

    uint8_t                         raw_buffer[8];	// Data stored by registers
    float             				acc_x;	        // m/s2, after thermal compensation and local frame transformation
    float             				acc_y;	        // m/s2, after thermal compensation and local frame transformation
    float             				acc_z;	        // m/s2, after thermal compensation and local frame transformation
    float            				acc_vertical;   // m/s2, vertical acceleration after world frame transformation and gravity compensation (effective acceleration)
    float               			temperature;	// C
} adxl382_t;


adxl382_error_t ADXL382_Init(adxl382_t *dev);

bool ADXL382_IsDataReady(adxl382_t *dev);
int8_t ADXL382_SetMode(adxl382_t *dev, adxl382_mode_t mode);
adxl382_error_t ADXL382_ReadData(adxl382_t *dev);
void ADXL382_Compute(adxl382_t *dev, const float current_quat[4]);

#endif /* INC_DRIVERS_ADXL382_H_ */
