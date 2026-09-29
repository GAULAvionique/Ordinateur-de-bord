/*
 * odb.c
 *
 *  Created on: 3 mai 2026
 *      Author: SamLol12
 */


// Apogee Detection & Pyros Firing logic: https://www.rocketryforum.com/threads/most-accurate-way-to-measure-velocity-accelerometer-vs-barometer-vs.157866/page-2

#include "odb.h"
#include "Systems/config.h"
#include "Systems/logger.h"
#include "Tools/profiler.h"
#include "Comm/beacon_comm.h"
#include "Utils/utils.h"
#include "stm32f4xx_hal.h"
#include <ctype.h>
#include <math.h>
#include <stdio.h>


extern adxl382_t adxl382;
extern bno055_t bno055;
extern hm11_t hm11;
extern l76lm33_t l76lm33;
extern pyro_t pyros[4];
extern critical_led_t critical_led;
extern ms5611_t ms5611;
extern rfd900x_t rfd900x;
extern buzzer_t buzzer;
extern system_measurements_t system_measurements;
extern w25q_t w25q;
extern idefix_t idefix;
extern mem2067_t mem2067;
static kalman_nav_t kalman_filter;
static altitude_trend_t altitude_trend;

static float ground_elevation_msl_m = 0.0f;


static void ODB_UpdateMetricMax(metric_t *metric, float candidate_value, uint32_t time_ms) {
    if(!metric) {
        return;
    }

    if(!metric->valid || candidate_value > metric->value) {
        metric->valid = STATE_TRUE;
        metric->value = candidate_value;
        metric->time_ms = time_ms;
    }
}

static void ODB_UpdateWindowEvent(window_event_t *event, bool active, uint32_t time_ms) {
    if(!event) {
        return;
    }

    if(active) {
        if(!event->activated) {
            event->activated = STATE_TRUE;
            if(event->start_time_ms == 0) {
                event->start_time_ms = time_ms;
            }
            event->end_time_ms = 0;
        }
    } else if(event->activated) {
        event->activated = STATE_FALSE;
        event->end_time_ms = time_ms;
    }
}


void ODB_Reset(odb_data_t *data, odb_stats_t *stats) {
    if(!data) {
        return;
    }

    data->time_boot_ms = 0;
    data->system_states = 0x0000; // All flags cleared (components not OK)
    data->event_states = 0x00;    // All flags cleared (events not occurred)
    data->battery_mv = 0;
    data->roll = 0.0f;
    data->pitch = 0.0f;
    data->yaw = 0.0f;
    data->imu_acc_x = 0.0f;
    data->imu_acc_y = 0.0f;
    data->imu_acc_z = 0.0f;
    data->imu_gyro_x = 0.0f;
    data->imu_gyro_y = 0.0f;
    data->imu_gyro_z = 0.0f;
    data->imu_mag_x = 0.0f;
    data->imu_mag_y = 0.0f;
    data->imu_mag_z = 0.0f;
    data->altitude_agl_m = 0.0f;
    data->pressure_pa = 0.0f;
    data->temp_celsius = 0.0f;
    data->highg_acc_x = 0.0f;
    data->highg_acc_y = 0.0f;
    data->highg_acc_z = 0.0f;
    data->gps_fix = 0;
    data->lat = 0;
    data->lon = 0;
    data->gps_alt = 0;
    data->vel = 0;
    data->cog = 0;
    data->satellites_nb = 0;
    data->imu_acc_vertical = 0.0f;
    data->highg_acc_vertical = 0.0f;
    data->kalman_z = 0.0f;
    data->kalman_v = 0.0f;
    data->sd_space = 0;

    if(!stats) {
        return;
    }

    stats->flight_id = 0;
    stats->date = 0;
    stats->pyros_arm.activated = STATE_FALSE;
    stats->pyros_arm.start_time_ms = 0;
    stats->pyros_arm.end_time_ms = 0;
    stats->pyro1.fired = STATE_FALSE;
    stats->pyro1.time_ms = 0;
    stats->pyro2.fired = STATE_FALSE;
    stats->pyro2.time_ms = 0;
    stats->pyro3.fired = STATE_FALSE;
    stats->pyro3.time_ms = 0;
    stats->pyro4.fired = STATE_FALSE;
    stats->pyro4.time_ms = 0;
    stats->mach_lock.activated = STATE_FALSE;
    stats->mach_lock.start_time_ms = 0;
    stats->mach_lock.end_time_ms = 0;
    stats->max_altitude_gps.valid = STATE_FALSE;
    stats->max_altitude_gps.value = 0.0f;
    stats->max_altitude_gps.time_ms = 0;
    stats->max_altitude_baro.valid = STATE_FALSE;
    stats->max_altitude_baro.value = 0.0f;
    stats->max_altitude_baro.time_ms = 0;
    stats->max_altitude_kalman.valid = STATE_FALSE;
    stats->max_altitude_kalman.value = 0.0f;
    stats->max_altitude_kalman.time_ms = 0;
    stats->apogee.valid = STATE_FALSE;
    stats->apogee.value = 0.0f;
    stats->apogee.time_ms = 0;
    stats->main_deploy.valid = STATE_FALSE;
    stats->main_deploy.value = 0.0f;
    stats->main_deploy.time_ms = 0;
    stats->drogue_deploy.valid = STATE_FALSE;
    stats->drogue_deploy.value = 0.0f;
    stats->drogue_deploy.time_ms = 0;
    stats->max_ascend_speed.valid = STATE_FALSE;
    stats->max_ascend_speed.value = 0.0f;
    stats->max_ascend_speed.time_ms = 0;
    stats->max_ascend_accel.valid = STATE_FALSE;
    stats->max_ascend_accel.value = 0.0f;
    stats->max_ascend_accel.time_ms = 0;
    stats->max_descend_speed.valid = STATE_FALSE;
    stats->max_descend_speed.value = 0.0f;
    stats->max_descend_speed.time_ms = 0;
    stats->max_descend_accel.valid = STATE_FALSE;
    stats->max_descend_accel.value = 0.0f;
    stats->max_descend_accel.time_ms = 0;
    stats->flight_time_ms = 0;
    stats->flight_start_time_ms = 0;
    stats->missed_frames = 0;
    //stats->fsm_trans.preflight_static_oriented = 0;
	stats->fsm_trans.preflight_waiting_flight = 0;
	stats->fsm_trans.armed = 0;
	stats->fsm_trans.inflight_boost = 0;
	stats->fsm_trans.inflight_fast = 0;
	stats->fsm_trans.inflight_coast = 0;
	stats->fsm_trans.inflight_drogue = 0;
	stats->fsm_trans.inflight_main = 0;
	stats->fsm_trans.inflight_landed = 0;
	stats->fsm_trans.postflight = 0;
}

odb_state_t ODB_Init(odb_data_t *data, odb_stats_t *stats) {
    if(!data) {
        return ODB_ERROR;
    }

    bool alimentation_fault = false;
    uint8_t error = 0;
    uint8_t warning = 0;

    ODB_Reset(data, stats);

    uint16_t system_states = 0x0000;

    if(W25Q_Init(&w25q) == 0) {
        system_states |= FLAG_FLASH_OK;
        Config_Init();
        if(Logger_Init() != LOGGER_SUCCESS) {
        	error++;
        	DEBUG_PRINTF("ERROR : Init Logger\n");
        } else {
        	stats->flight_id = Logger_GetCurrentFlightId();
        }
    } else {
        error++;
        DEBUG_PRINTF("ERROR : Init W25Q\n");
    }

    if(SystemMeasurements_Init(&system_measurements) == 0) {
        SystemMeasurements_ComputePower(&system_measurements);
        if(system_measurements.vin_batt <= VIN_BATT_MIN_MV || system_measurements.vin_batt >= VIN_BATT_MAX_MV || system_measurements.v5_buck <= V5_MIN_MV || system_measurements.v5_buck >= V5_MAX_MV || system_measurements.v3_buck <= V3_MIN_MV || system_measurements.v3_buck >= V3_MAX_MV || system_measurements.pg_v5 == false) {
            alimentation_fault = true;
            DEBUG_PRINTF("ERROR : Battery too weak or faulty battery\n");
        }

		for(int i = 0; i < PYRO_MAX; i++) {
			if(Pyro_Init(&pyros[i]) == PYRO_OK) {
				DEBUG_PRINTF("Pyro %i configured\n", i);
			} else {
				error++;
				DEBUG_PRINTF("Pyro %i configuration failed\n", i);
			}
		}

        SystemMeasurements_ComputeTemperature(&system_measurements);
        if(system_measurements.temperature < MAX6612MXK_MIN_TEMP_C || system_measurements.temperature > MAX6612MXK_MAX_TEMP_C) {
            error++;
            DEBUG_PRINTF("ERROR : Temperature out of range\n");
        } else {
        	system_states |= FLAG_TEMP_OK;
        }
    } else {
        error++;
        DEBUG_PRINTF("ERROR : Init SystemMeasurements\n");
    }

    if(BNO055_Init(&bno055) == BNO055_OK) {
        system_states |= FLAG_IMU_OK;
    } else {
        error++;
        DEBUG_PRINTF("ERROR : Init BNO055\n");
    }

    if(MS5611_Init(&ms5611, OSR1024, OSR1024) == MS5611_OK) {
        system_states |= FLAG_BARO_OK;
    } else {
        error++;
        DEBUG_PRINTF("ERROR : Init MS5611\n");
    }

    if(ADXL382_Init(&adxl382) == ADXL382_OK) {
        system_states |= FLAG_HIGHG_OK;
    } else {
        error++;
        DEBUG_PRINTF("ERROR : Init ADXL382\n");
    }

    if(L76LM33_Init(&l76lm33) == L76LM33_OK) {
        system_states |= FLAG_GPS_OK;
    } else {
        error++;
        DEBUG_PRINTF("ERROR : Init L76LM33\n");
    }

    if(RFD900x_Init(&rfd900x) == RFD_OK) {
        system_states |= FLAG_RADIO_OK;
    } else {
        error++;
        DEBUG_PRINTF("ERROR : Init RFD900x\n");
    }

    if(HM11_Init(&hm11) == HM11_OK) {
    	system_states |= FLAG_BT_OK;
    } else {
    	warning++;
    	DEBUG_PRINTF("WARNING : HM-11 doesn't respond or has an active connection.\n");
    }

    // Kalman filter initialization -> calculate R_static
    if((system_states & FLAG_BARO_OK) && (system_states & FLAG_HIGHG_OK)) {
		float samples[KALMAN_NAV_SAMPLE_NB];
		float sum = 0;
		float temperature, pressure, alt;
		for(int i = 0; i < KALMAN_NAV_SAMPLE_NB; i++) {
			MS5611_Update(&ms5611);
			HAL_Delay(10);
			MS5611_Compute(&ms5611, &temperature, &pressure);
			alt = Math_ComputeAltitudeMSL(pressure);
			samples[i] = alt;
			sum += samples[i];
		}

		// Kalman use AGL instead of MSL
        ground_elevation_msl_m = sum / KALMAN_NAV_SAMPLE_NB;
		for(int i = 0; i < KALMAN_NAV_SAMPLE_NB; i++) {
            samples[i] -= ground_elevation_msl_m;
		}

		KalmanNav_Init(&kalman_filter, 0.0f, samples, KALMAN_NAV_SAMPLE_NB);
	}

    // Barometric option
    if(current_config.apogee_detection_mode == APOGEE_DETECTION_BAROMETRIC) {
    	AltitudeTrend_Init(&altitude_trend);
    }

    if(Idefix_Init(&idefix) == IDEFIX_OK) {
        system_states |= FLAG_IDEFIX_OK;
        Beacon_SetFrequency(&idefix);
    } else {
    	warning++;
        DEBUG_PRINTF("WARNING : Init IdeFIX\n");
    }

    if(MEM2067_Mount() == MEM2067_OK) {
    	char sd_filename[13];
    	snprintf(sd_filename, sizeof(sd_filename), "FLT_%lu.csv", stats->flight_id);
    	if(MEM2067_OpenFile(sd_filename) == MEM2067_OK) {
    		system_states |= FLAG_SD_OK;
			MEM2067_Infos(&mem2067);
			data->sd_space = (uint16_t)(((uint64_t)mem2067.free_space * 100) / 2097152);
			DEBUG_PRINTF("INFOS : Available SD storage: %lu free bytes out of %lu available\n", mem2067.free_space, mem2067.total_space);
    	} else {
    		warning++;
    		DEBUG_PRINTF("WARNING : Open file MEM2067\n");
    	}
	} else {
		warning++;
		DEBUG_PRINTF("WARNING : Mount MEM2067\n");
	}

    if(CriticalLed_Init(&critical_led) != 0) {
    	warning++;
		DEBUG_PRINTF("WARNING : Init Critical LED\n");
	}
    // Sensors Init End

    odb_state_t odb_state = ODB_ERROR;
    if(alimentation_fault) {
        odb_state = ODB_ALIMENTATION_ERROR;
        DEBUG_PRINTF("ERROR : Non-compliant power supply\n");
    } else if(error > 0) {
        odb_state = ODB_ERROR;
        DEBUG_PRINTF("ERROR : %d ERROR(s) detected during system initialization. Some essential features are unavailable\n", error);
        if(current_config.debug_mode == STATE_FALSE) {
        	CriticalLED_SetColor(&critical_led, RED);
        	//while(1) {} // Stop execution
        }
    } else {
    	if(warning > 0) {
			odb_state = ODB_WARNING;
			DEBUG_PRINTF("WARNING : %d WARNING(s) detected during system initialization. Some optional features are unavailable.\n", warning);
		} else {
			odb_state = ODB_OK;
		}
    }

    // Update system infos
    data->system_states = system_states;
    data->version_major = ODB_PROTOCOL_VERSION_MAJOR;
	data->version_minor = ODB_PROTOCOL_VERSION_MINOR;
	data->payload_size  = ODB_DATA_SIZE;

    return odb_state;
}

void ODB_Update(odb_data_t *data, odb_stats_t *stats) {
    if(!data) {
        return;
    }

    const uint32_t now_ms = HAL_GetTick();

    //Profiler_StartTask(PROFILE_TASK_ADC);
    SystemMeasurements_UpdateInternalCalibration(&system_measurements);
    SystemMeasurements_ComputeTemperature(&system_measurements);
    SystemMeasurements_ComputePower(&system_measurements);
    SystemMeasurements_ComputePyros(&system_measurements);

    data->temp_celsius = system_measurements.temperature;
    const bool pyros_arming_enabled = Pyro_IsArmed(&system_measurements);
    bool is_ctn_active = Pyro_IsContinuityActive(&system_measurements);
    if(is_ctn_active) {
    	for(int i = 0; i < PYRO_MAX; i++) {
    		data->pyros_mv[i] = system_measurements.pyro_status[i];
			pyros[i].is_connected = (system_measurements.pyro_status[i] >= PYRO_THRESHOLD_CONN);
		}
    }
    uint16_t new_pyros_states = data->system_states;
    if(pyros[0].is_connected) {
    	new_pyros_states |= FLAG_PYRO1_CONN;
    } else {
    	new_pyros_states &= ~FLAG_PYRO1_CONN;
    }
	if(pyros[1].is_connected) {
		new_pyros_states |= FLAG_PYRO2_CONN;
	} else {
		new_pyros_states &= ~FLAG_PYRO2_CONN;
	}
	if(pyros[2].is_connected) {
		new_pyros_states |= FLAG_PYRO3_CONN;
	} else {
		new_pyros_states &= ~FLAG_PYRO3_CONN;
	}
	if(pyros[3].is_connected) {
		new_pyros_states |= FLAG_PYRO4_CONN;
	} else {
		new_pyros_states &= ~FLAG_PYRO4_CONN;
	}
	data->system_states = new_pyros_states;
    //Profiler_StopTask(PROFILE_TASK_ADC);

    //Profiler_StartTask(PROFILE_TASK_BARO);
    float temperature, pressure;
    MS5611_Update(&ms5611);
    if(MS5611_Compute(&ms5611, &temperature, &pressure) == MS5611_OK) {
    	data->pressure_pa = pressure;
    	data->altitude_agl_m = Math_ComputeAltitudeMSL(pressure) - ground_elevation_msl_m;
		data->system_states |= FLAG_BARO_OK;
    } else {
        data->system_states &= ~FLAG_BARO_OK;
    }
    //Profiler_StopTask(PROFILE_TASK_BARO);

    //Profiler_StartTask(PROFILE_TASK_IMU);
    const bool mach_lock_enabled = (stats != NULL) ? stats->mach_lock.activated : false;
    if(BNO055_ReadAllData(&bno055) == BNO055_OK) {
		data->imu_acc_x = bno055.acc_x;
		data->imu_acc_y = bno055.acc_y;
		data->imu_acc_z = bno055.acc_z;
		data->imu_gyro_x = bno055.gyro_x;
		data->imu_gyro_y = bno055.gyro_y;
		data->imu_gyro_z = bno055.gyro_z;
		data->imu_mag_x = bno055.mag_x;
		data->imu_mag_y = bno055.mag_y;
		data->imu_mag_z = bno055.mag_z;

		BNO055_ComputeEulerAngles(&bno055);
		data->roll = bno055.euler_angles.roll;
		data->pitch = bno055.euler_angles.pitch;
		data->yaw = bno055.euler_angles.yaw;

		BNO055_ComputeVerticalAcc(&bno055);
		data->imu_acc_vertical = bno055.acc_vertical;

		data->system_states |= FLAG_IMU_OK;
	} else {
        data->system_states &= ~FLAG_IMU_OK;
    }
    if(BNO055_ReadTemperature(&bno055) == BNO055_OK) {
    	data->imu_temp = bno055.temperature;
    } else {
    	data->system_states &= ~FLAG_IMU_OK;
    }
    //Profiler_StopTask(PROFILE_TASK_IMU);

    //Profiler_StartTask(PROFILE_TASK_HIGHG);
    float current_quat[4];
	if(mach_lock_enabled) {
		current_quat[0] = 1.0f; // w
		current_quat[1] = 0.0f; // x
		current_quat[2] = 0.0f; // y
		current_quat[3] = 0.0f; // z
	} else {
		current_quat[0] = bno055.quat.w;
		current_quat[1] = bno055.quat.x;
		current_quat[2] = bno055.quat.y;
		current_quat[3] = bno055.quat.z;
	}
    if(ADXL382_ReadData(&adxl382) == ADXL382_OK) {
    	ADXL382_Compute(&adxl382, current_quat);
		data->highg_acc_x = adxl382.acc_x;
		data->highg_acc_y = adxl382.acc_y;
		data->highg_acc_z = adxl382.acc_z;
		data->highg_acc_vertical = adxl382.acc_vertical;
		data->highg_temp = adxl382.temperature;

		data->system_states |= FLAG_HIGHG_OK;
    } else {
    	data->system_states &= ~FLAG_HIGHG_OK;
    }
    //Profiler_StopTask(PROFILE_TASK_HIGHG);

    // Kalman filter update with dynamic R_alt
    //Profiler_StartTask(PROFILE_TASK_KALMAN);
    float raw_accel_z = data->highg_acc_vertical;
    if(fabs(raw_accel_z + GRAVITY_MS2) < current_config.acc_z_launch_threshold) {
        raw_accel_z = data->imu_acc_vertical;
    }
    KalmanNav_Predict(&kalman_filter, raw_accel_z);
    KalmanNav_Update(&kalman_filter, data->altitude_agl_m, mach_lock_enabled);
    data->kalman_z = (float)kalman_filter.z;
    data->kalman_v = (float)kalman_filter.v;
    //Profiler_StopTask(PROFILE_TASK_KALMAN);

    //Profiler_StartTask(PROFILE_TASK_BAROMETRIC);
    if(current_config.apogee_detection_mode == APOGEE_DETECTION_BAROMETRIC) {
    	AltitudeTrend_Update(&altitude_trend, data->altitude_agl_m);
    	data->barometric_trend = (uint8_t)altitude_trend.state;
	}
    //Profiler_StopTask(PROFILE_TASK_BAROMETRIC);

    //Profiler_StartTask(PROFILE_TASK_GPS);
    l76lm33_state_t gps_status = L76LM33_Compute(&l76lm33);
    if(gps_status == L76LM33_OK || gps_status == L76LM33_NO_VALID_FRAME) {
      data->gps_fix         = l76lm33.gps_data.gps_fix;
      data->lat             = l76lm33.gps_data.lat;
      data->lon             = l76lm33.gps_data.lon;
      data->gps_alt         = l76lm33.gps_data.gps_alt;
      data->vel             = l76lm33.gps_data.vel;
      data->cog             = l76lm33.gps_data.cog;
      data->satellites_nb   = l76lm33.gps_data.satellites_nb;

      //data->system_states |= FLAG_GPS_OK;
    } //else {
    	//data->system_states &= ~FLAG_GPS_OK;
    //}
    //Profiler_StopTask(PROFILE_TASK_GPS);

    data->time_boot_ms = now_ms;
    data->battery_mv = (uint16_t)(system_measurements.vin_batt);

    if(stats) {
    	uint32_t current_flight_time_ms = now_ms - stats->flight_start_time_ms;
		stats->pyro1.fired = pyros[0].is_fire;
		stats->pyro2.fired = pyros[1].is_fire;
		stats->pyro3.fired = pyros[2].is_fire;
		stats->pyro4.fired = pyros[3].is_fire;

		ODB_UpdateWindowEvent(&stats->pyros_arm, pyros_arming_enabled, current_flight_time_ms);

		if(stats->pyro1.fired && stats->pyro1.time_ms == 0) {
			stats->pyro1.time_ms = current_flight_time_ms;
		}
		if(stats->pyro2.fired && stats->pyro2.time_ms == 0) {
			stats->pyro2.time_ms = current_flight_time_ms;
		}
		if(stats->pyro3.fired && stats->pyro3.time_ms == 0) {
			stats->pyro3.time_ms = current_flight_time_ms;
		}
		if(stats->pyro4.fired && stats->pyro4.time_ms == 0) {
			stats->pyro4.time_ms = current_flight_time_ms;
		}

		ODB_UpdateMetricMax(&stats->max_altitude_gps, (float)data->gps_alt, current_flight_time_ms);
		ODB_UpdateMetricMax(&stats->max_altitude_baro, data->altitude_agl_m, current_flight_time_ms);
		ODB_UpdateMetricMax(&stats->max_altitude_kalman, data->kalman_z, current_flight_time_ms);
		ODB_UpdateMetricMax(&stats->max_ascend_speed, (data->kalman_v > 0.0f) ? data->kalman_v : 0.0f, current_flight_time_ms);
		ODB_UpdateMetricMax(&stats->max_descend_speed, (data->kalman_v < 0.0f) ? -data->kalman_v : 0.0f, current_flight_time_ms);
		ODB_UpdateMetricMax(&stats->max_ascend_accel, (raw_accel_z > 0.0f) ? raw_accel_z : 0.0f, current_flight_time_ms);
		ODB_UpdateMetricMax(&stats->max_descend_accel, (raw_accel_z < 0.0f) ? -raw_accel_z : 0.0f, current_flight_time_ms);

        if(data->gps_fix >= 1) {
            stats->last_lat = data->lat;
            stats->last_lon = data->lon;
            if(stats->date != l76lm33.gps_data.date_raw) {
            	stats->date = l76lm33.gps_data.date_raw;
            }
        }

        data->event_states = ODB_SetEventStates(stats);
    } else {
        data->event_states = 0x00;
    }
}

int8_t ODB_SetMissionState(odb_data_t *data, uint8_t global_state, uint8_t sub_state) {
    if(!data) {
        return ODB_ERROR;
    }

    data->mission_state = ((global_state & 0x0F) << 4) | (sub_state & 0x0F);

    return ODB_OK;
}

uint16_t ODB_SetEventStates(const odb_stats_t *stats) {
    if(!stats) {
        return 0x00;
    }

    uint16_t packed = 0x00;
    if(stats->pyros_arm.activated) {
    	packed |= FLAG_PYROS_ARMED;
    } else {
    	packed &= ~FLAG_PYROS_ARMED;
    }
    if(stats->pyro1.fired) {
        packed |= FLAG_PYRO1_FIRED;
    }
    if(stats->pyro2.fired) {
        packed |= FLAG_PYRO2_FIRED;
    }
    if(stats->pyro3.fired) {
        packed |= FLAG_PYRO3_FIRED;
    }
    if(stats->pyro4.fired) {
        packed |= FLAG_PYRO4_FIRED;
    }
    if(stats->mach_lock.activated) {
        packed |= FLAG_MACH_LOCK_ENABLED;
    } else {
        packed &= ~FLAG_MACH_LOCK_ENABLED;
    }
    if(stats->apogee.valid) {
        packed |= FLAG_APOGEE_DETECTED;
    }
    if(stats->main_deploy.valid) {
        packed |= FLAG_MAIN_DEPLOYED;
    }
    if(stats->drogue_deploy.valid) {
        packed |= FLAG_DROGUE_DEPLOYED;
    }

    return packed;
}

uint8_t ODB_GetPyroStates(const odb_data_t *data) {
    if(!data) {
        return 0x00;
    }

    uint8_t pyro_continuity = 0;
    if(data->system_states & FLAG_PYRO1_CONN) {
        pyro_continuity++;
    }
    if(data->system_states & FLAG_PYRO2_CONN) {
        pyro_continuity++;
    }
    if(data->system_states & FLAG_PYRO3_CONN) {
        pyro_continuity++;
    }
    if(data->system_states & FLAG_PYRO4_CONN) {
        pyro_continuity++;
    }

    return pyro_continuity;
}
