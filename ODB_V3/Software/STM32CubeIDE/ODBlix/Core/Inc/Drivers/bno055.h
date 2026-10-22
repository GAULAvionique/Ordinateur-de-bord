/*
 * bno055.h
 *
 * Created on: 20 avr. 2026
 * Author: AudaceLol12
 */

#ifndef INC_DRIVERS_BNO055_H_
#define INC_DRIVERS_BNO055_H_

#include <Protocols/odb_config_protocol.h>
#include "stm32f4xx_hal.h"
#include <stdint.h>
#include <stdbool.h>

#define BNO055_I2C_ADDR             (0x28 << 1)

typedef enum {
    BNO055_OK            	    = 0,
    BNO055_ERROR         	    = -1,
    BNO055_I2C_ERROR     	    = -2,
    BNO055_ID_ERROR      	    = -3,
    BNO055_CONFIG_ERROR  	    = -4
} bno055_error_t;

typedef enum {
    BNO055_UNIT_ACCEL_MS2       = 0x00,
    BNO055_UNIT_ACCEL_MG        = 0x01,
} bno055_unit_accel_t;

typedef enum {
    BNO055_UNIT_GYRO_DPS        = 0x00,
    BNO055_UNIT_GYRO_RPS        = 0x02,
} bno055_unit_gyro_t;

typedef enum {
    BNO055_UNIT_EULER_DEG       = 0x00,
    BNO055_UNIT_EULER_RAD       = 0x04,
} bno055_unit_euler_t;

typedef enum {
    BNO055_ACC_RANGE_2G         = 0x00,
    BNO055_ACC_RANGE_4G         = 0x01,
    BNO055_ACC_RANGE_8G         = 0x02,
    BNO055_ACC_RANGE_16G        = 0x03,
} bno055_acc_range_t;

typedef enum {
    BNO055_OP_MODE_CONFIG       = 0x00,
    BNO055_OP_MODE_AMG          = 0x07, // Not-Fusion (Raw Accel+Mag+Gyro)
    BNO055_OP_MODE_IMU          = 0x08, // Fusion (Accel+Gyro) (Max 4G)
    BNO055_OP_MODE_NDOF         = 0x0C  // Fusion (Accel+Gyro+Mag) (Max 4G)
} bno055_op_mode_t;

typedef enum {
    BNO055_PWR_MODE_NORMAL      = 0x00, // Default
    BNO055_PWR_MODE_LOW_POWER   = 0x01, // Only accelerometer active, reduced performance and wake-up when motion is detected
    BNO055_PWR_MODE_SUSPEND     = 0x02  // All sensors disabled, lowest power consumption
} bno055_pwr_mode_t;

typedef struct {
    uint8_t data[22];
} bno055_calib_profile_t;

typedef struct {
    float w;
    float x;
    float y;
    float z;
} bno055_quat_t;

typedef struct {
    float x;
    float y;
    float z;
} bno055_linear_acc_t;

typedef struct {
    float roll;
    float pitch;
    float yaw;
} bno055_euler_angles_t;

typedef struct {
    I2C_HandleTypeDef       *hi2c;
    GPIO_TypeDef            *drdy_port;
    uint16_t                drdy_pin;
    GPIO_TypeDef            *rst_port;
    uint16_t                rst_pin;

    bno055_op_mode_t 		op_mode;
    acc_axis_profile_t   	axis_profile;
    bno055_acc_range_t      acc_range;

    bno055_unit_accel_t     acc_unit;
    bno055_unit_gyro_t      gyro_unit;
    bno055_unit_euler_t     euler_unit;

    volatile bool           data_ready_flag;

    float                   scale_acc, scale_gyro;                          // Scale factors for raw data conversion (magnetometer is always 16 LSB/uT)

    uint8_t                 calib_sys, calib_gyro, calib_acc, calib_mag;    // 0-3 (0=not calibrated, 3=perfectly calibrated)

    float                   acc_x, acc_y, acc_z;                            // m/s^2
    float                   gyro_x, gyro_y, gyro_z;                         // Dps
    float                   mag_x, mag_y, mag_z;                            // uT
    float                   temperature;                                    // C

    float            		acc_vertical;                                   // vertical acceleration after gravity/temperature in world frame transformation (effective acceleration)
    bno055_quat_t           quat;                                           // Normalized quaternion (w,x,y,z)
    bno055_linear_acc_t     linear_acc;                                     // Linear Acceleration after gravity/temperature compensation in the sensor frame
    bno055_euler_angles_t   euler_angles;                                   // Euler angles
} bno055_t;

bno055_error_t BNO055_Init(bno055_t *dev);
void BNO055_HardReset(bno055_t *dev);
bno055_error_t BNO055_SetPowerMode(bno055_t *dev, bno055_pwr_mode_t power_mode);

//bool BNO055_IsDataReady(bno055_t *dev);
bno055_error_t BNO055_ReadAllData(bno055_t *dev);
bno055_error_t BNO055_ReadTemperature(bno055_t *dev);
bno055_error_t BNO055_UpdateCalibration(bno055_t *dev);
void BNO055_ComputeEulerAngles(bno055_t *dev);
void BNO055_ComputeVerticalAcc(bno055_t *dev);

bno055_error_t BNO055_GetCalibrationProfile(bno055_t *dev, bno055_calib_profile_t *profile);
bno055_error_t BNO055_SetCalibrationProfile(bno055_t *dev, bno055_calib_profile_t *profile);

bno055_error_t BNO055_GetSwRevision(bno055_t *dev, uint16_t *sw_rev);

#endif // INC_DRIVERS_BNO055_H_
