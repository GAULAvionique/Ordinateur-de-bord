/*
 * adxl382.c
 *
 *  Created on: 13 avr. 2026
 *      Author: SamLol12
 */


#include "Drivers/adxl382.h"
#include "Systems/config.h"


#define ADXL382_DEVID_AD_VAL      0xAD
#define ADXL382_DEVID_MST_VAL     0x1D
#define ADXL382_PART_ID_VAL       0x17

#define ADXL382_REG_DEVID_AD      0x00
#define ADXL382_REG_DEVID_MST     0x01
#define ADXL382_REG_PART_ID       0x02
#define ADXL382_REG_STATUS3       0x14
#define ADXL382_REG_XDATA_H       0x15
#define ADXL382_REG_XDATA_L       0x16
#define ADXL382_REG_YDATA_H       0x17
#define ADXL382_REG_YDATA_L       0x18
#define ADXL382_REG_ZDATA_H       0x19
#define ADXL382_REG_ZDATA_L       0x1A
#define ADXL382_REG_OP_MODE       0x26
#define ADXL382_REG_DIG_EN        0x27
#define ADXL382_REG_RESET     	  0x2A
#define ADXL382_REG_OR_CFG    	  0x48
#define ADXL382_REG_TRIG_CFG  	  0x49
#define ADXL382_REG_FILTER    	  0x50


static int8_t ADXL382_ReadReg(I2C_HandleTypeDef *hi2c, uint8_t reg, uint8_t *data) {
    if(HAL_I2C_Mem_Read(hi2c, ADXL382_I2C_ADDR, reg, I2C_MEMADD_SIZE_8BIT, data, 1, 25) != HAL_OK) {
        return -1;
    }

    return 0; // success
}

static int8_t ADXL382_WriteReg(I2C_HandleTypeDef *hi2c, uint8_t reg, uint8_t data) {
    if(HAL_I2C_Mem_Write(hi2c, ADXL382_I2C_ADDR, reg, I2C_MEMADD_SIZE_8BIT, &data, 1, 25) != HAL_OK) {
        return -1;
    }

    return 0; // success
}

static int8_t ADXL382_ReadRegs(I2C_HandleTypeDef *hi2c, uint8_t reg, uint8_t *data, uint16_t length) {
    if(HAL_I2C_Mem_Read(hi2c, ADXL382_I2C_ADDR, reg, I2C_MEMADD_SIZE_8BIT, data, length, 25) != HAL_OK) {
        return -1;
    }

    return 0; // success
}

static int8_t ADXL382_Reset(adxl382_t *dev) {
    if(ADXL382_WriteReg(dev->hi2c, ADXL382_REG_RESET, 0x03) != HAL_OK) {
        return -1;
    }
    HAL_Delay(10);

    dev->acc_x = 0;
    dev->acc_y = 0;
    dev->acc_z = 0;

    return 0; // success
}

static int8_t ADXL382_SetRange(adxl382_t *dev, adxl382_range_t range) {
    uint8_t op_mode_reg = 0;
    if(ADXL382_ReadReg(dev->hi2c, ADXL382_REG_OP_MODE, &op_mode_reg) != 0) {
        return -1;
    }

    // Standby mode safe
    uint8_t standby_val = op_mode_reg & 0xF0;
	if(ADXL382_WriteReg(dev->hi2c, ADXL382_REG_OP_MODE, standby_val) != 0) {
		return -1;
	}
	HAL_Delay(2);

    standby_val &= ~(0x03 << 6); 
    standby_val |= ((uint8_t)range << 6);
    uint8_t final_val = standby_val | (op_mode_reg & 0x0F);
    if(ADXL382_WriteReg(dev->hi2c, ADXL382_REG_OP_MODE, final_val) != 0) {
        return -1;
    }

    dev->range = range;

    return 0; // success
}

static void ADXL382_RemapAxes(float *x, float *y, float *z, acc_axis_profile_t profile) {
    float bno_x = -(*y);
    float bno_y = *x;
    float bno_z = *z;

    switch (profile) {
        case ACC_AXIS_PROFILE_P0:
            *x = bno_x;
            *y = bno_y;
            *z = bno_z;
            break;

        case ACC_AXIS_PROFILE_P1:
            *x = -bno_y;
            *y = bno_x;
            *z = bno_z;
            break;

        case ACC_AXIS_PROFILE_P2:
            *x = -bno_x;
            *y = -bno_y;
            *z = bno_z;
            break;

        case ACC_AXIS_PROFILE_P3:
            *x = bno_y;
            *y = -bno_x;
            *z = bno_z;
            break;

        case ACC_AXIS_PROFILE_P4:
            *x = bno_x;
            *y = bno_z;
            *z = bno_y;
            break;

        case ACC_AXIS_PROFILE_P5:
            *x = bno_y;
            *y = bno_z;
            *z = -bno_x;
            break;

        case ACC_AXIS_PROFILE_P6:
        	*x = -bno_x;
			*y = bno_z;
			*z = -bno_y;
            break;

        case ACC_AXIS_PROFILE_P7:
        	*x = bno_y;
			*y = bno_z;
			*z = bno_x;
            break;

        default:
            // Fallback
            *x = bno_x;
            *y = bno_z;
            *z = bno_z;
            break;
    }
}

static int8_t ADXL382_SetOverrangeConfig(adxl382_t *dev, adxl382_or_behavior_t or_mode) {
    uint8_t or_cfg_val = 0;

    if(ADXL382_ReadReg(dev->hi2c, ADXL382_REG_OR_CFG, &or_cfg_val) != 0) {
        return -1;
    }

    or_cfg_val &= ~(0x03);
    or_cfg_val |= ((uint8_t)or_mode & 0x03);

    return ADXL382_WriteReg(dev->hi2c, ADXL382_REG_OR_CFG, or_cfg_val);
}

static int8_t ADXL382_SetFilterConfig(adxl382_t *dev, adxl382_filters_t filters) {
    uint8_t trig_cfg_val = 0;
    uint8_t filter_val = 0;

    if(ADXL382_ReadReg(dev->hi2c, ADXL382_REG_TRIG_CFG, &trig_cfg_val) != 0) {
        return -1;
    }

    trig_cfg_val &= ~(0xE4);
    if(filters.iir7_bypass) {
        trig_cfg_val |= (1 << 7);
    }
    if(filters.sinc_rate == ADXL382_SINC_16X) {
        trig_cfg_val |= (1 << 6);
    }
    if(filters.iir1_enable) {
        trig_cfg_val |= (1 << 5);
    }
    if(filters.round_mode == ADXL382_ROUND_FLOOR) {
        trig_cfg_val |= (1 << 2);
    }

    if(ADXL382_WriteReg(dev->hi2c, ADXL382_REG_TRIG_CFG, trig_cfg_val) != 0) {
        return -1;
    }

    if(filters.dcf_bypass) {
        filter_val |= (1 << 7);
    }
    if(filters.eq_bypass) {
        filter_val |= (1 << 6);
    }

    filter_val |= (((uint8_t)filters.lpf_mode & 0x03) << 4);
    filter_val |= (((uint8_t)filters.hpf_path & 0x01) << 3);
    filter_val |= ((uint8_t)filters.hpf_corner & 0x07);

    return ADXL382_WriteReg(dev->hi2c, ADXL382_REG_FILTER, filter_val);
}


int8_t ADXL382_SetMode(adxl382_t *dev, adxl382_mode_t mode) {
    uint8_t op_mode_reg = 0;
    if(ADXL382_ReadReg(dev->hi2c, ADXL382_REG_OP_MODE, &op_mode_reg) != 0) {
        return -1;
    }

    uint8_t config_bits = op_mode_reg & 0xF0;
    if(ADXL382_WriteReg(dev->hi2c, ADXL382_REG_OP_MODE, config_bits) != HAL_OK) {
        return -1;
    }
    HAL_Delay(2);

    if(ADXL382_WriteReg(dev->hi2c, ADXL382_REG_OP_MODE, config_bits | (uint8_t)mode) != HAL_OK) {
        return -1;
    }
    HAL_Delay(2);

    dev->mode = mode;

    return 0; // success
}

adxl382_error_t ADXL382_Init(adxl382_t *dev) {
    uint8_t id = 0;
    if(ADXL382_ReadReg(dev->hi2c, ADXL382_REG_DEVID_AD, &id) != 0) {
        return ADXL382_I2C_ERROR;
    }
    if(id != ADXL382_DEVID_AD_VAL) {
        return ADXL382_ID_ERROR;
    }

    ADXL382_Reset(dev);
    
    // Enable XYZ & Temp
    if(ADXL382_WriteReg(dev->hi2c, ADXL382_REG_DIG_EN, 0xF0) != 0) {
		return ADXL382_I2C_ERROR;
	}
    
    // Range
    if(ADXL382_SetRange(dev, dev->range) != 0) {
		return ADXL382_RANGE_ERROR;
	}

    // Filters
    if(ADXL382_SetOverrangeConfig(dev, dev->filters_cfg.or_behavior) != 0) {
		return ADXL382_I2C_ERROR;
	}
	if(ADXL382_SetFilterConfig(dev, dev->filters_cfg) != 0) {
		return ADXL382_I2C_ERROR;
	}

    // Set axis profile
    dev->axis_profile = current_config.axis_profile;

    // Mode
	if(ADXL382_SetMode(dev, dev->mode) != 0) {
		return ADXL382_MODE_ERROR;
	}

    return ADXL382_OK; // success
}

bool ADXL382_IsDataReady(adxl382_t *dev) {
    uint8_t ready = 0;
    if(ADXL382_ReadReg(dev->hi2c, ADXL382_REG_STATUS3, &ready) == 0) {
    	return (ready & 0x01) ? true : false;
    }

    return false; // failure
}

adxl382_error_t ADXL382_ReadData(adxl382_t *dev) {
    if(!dev || !dev->hi2c) return ADXL382_ERROR;

    if(ADXL382_ReadRegs(dev->hi2c, ADXL382_REG_XDATA_H, dev->raw_buffer, 8) != 0) {
    	return ADXL382_I2C_ERROR;
    }

    return ADXL382_OK;
}

void ADXL382_Compute(adxl382_t *dev, const float current_quat[4]) {
    if(!dev) return;

    int16_t x = (int16_t)(((uint16_t)dev->raw_buffer[0] << 8) | dev->raw_buffer[1]);
    int16_t y = (int16_t)(((uint16_t)dev->raw_buffer[2] << 8) | dev->raw_buffer[3]);
    int16_t z = (int16_t)(((uint16_t)dev->raw_buffer[4] << 8) | dev->raw_buffer[5]);

    int16_t t_brut = (int16_t)(((uint16_t)dev->raw_buffer[6] << 8) | dev->raw_buffer[7]);
    t_brut >>= 4; // 16 bits -> 12 bits adc

    dev->temperature = 25.0f + ((float)t_brut - 550.0f) * 0.098039215f;

    float t = dev->temperature;
    float delta_t = dev->temperature - 25.0f;

    float scale_factor_25c = 2000.0f;
    if (dev->range == ADXL382_RANGE_30G) {
        scale_factor_25c = 1000.0f;
    } else if (dev->range == ADXL382_RANGE_60G) {
        scale_factor_25c = 500.0f;
    }

    // Datasheet Compensation (+0.02%/C)
    float current_scale_factor =  1.0f / (scale_factor_25c * (1.0f + (0.0002f * delta_t)));
    float acc_x_raw = (float)x * current_scale_factor;
    float acc_y_raw = (float)y * current_scale_factor;
    float acc_z_raw = (float)z * current_scale_factor;

    // Chip Thermal Compensation
    float offset_x = Thermal_ComputeOffset(dev->x_axis_offset, t);
    float offset_y = Thermal_ComputeOffset(dev->y_axis_offset, t);
    float offset_z = Thermal_ComputeOffset(dev->z_axis_offset, t);

    float accel[3];
	accel[0] = (acc_x_raw - offset_x) * GRAVITY_MS2;
	accel[1] = (acc_y_raw - offset_y) * GRAVITY_MS2;
	accel[2] = (acc_z_raw - offset_z) * GRAVITY_MS2;

	Math_6FacesCalibration(accel, &dev->faces_offset);

	ADXL382_RemapAxes(&accel[0], &accel[1], &accel[2], dev->axis_profile);

	dev->acc_x = accel[0];
	dev->acc_y = accel[1];
	dev->acc_z = accel[2];

    dev->acc_vertical = Math_ComputeWorldVerticalAcc(accel, current_quat, true);
}
