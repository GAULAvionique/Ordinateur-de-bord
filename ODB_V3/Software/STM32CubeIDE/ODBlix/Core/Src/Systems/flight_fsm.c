/*
 * flight_fsm.c
 *
 *  Created on: 24 avr. 2026
 *      Author: SamLol12
 */

#include "Systems/flight_fsm.h"
#include "Utils/utils.h"
#include "Systems/config.h"
#include "Systems/scheduler.h"
#include "Systems/tasks.h"
#include "Systems/logger.h"
#include "Protocols/odb_protocol.h"
#include "Drivers/smtb0927twr.h"
#include "Drivers/mem2067.h"
#include "stm32f4xx_hal.h"
#include <math.h>
#include <stdint.h>


#define STATIC_ACC_Z_THRESHOLD 6.0f

extern buzzer_t buzzer;
extern odb_data_t flight_data;
extern odb_stats_t flight_stats;
extern system_measurements_t system_measurements;
extern rfd900x_t rfd900x;
extern TIM_HandleTypeDef htim5;
extern pyro_t pyros[4];

volatile global_state_t current_global_state = STATE_PREFLIGHT;
volatile preflight_substate_t current_preflight_substate = SUB_STATIC_ORIENTED;
volatile inflight_substate_t current_inflight_substate = SUB_BOOST;
volatile bool is_ready_by_app = false;
volatile bool is_force_flight = false;

static uint32_t fire_timer = 0;
static uint32_t flight_duration = 0;
static uint32_t landing_timer = 0;
static uint8_t fire_attempt_count = 0;

static bool sustainer_ignited = false;
static bool backup_active = false;

extern note_t ram_ranch_solo[];

static void FSM_HandleDeployment(pyro_role_t primary_role, pyro_role_t backup_role, metric_t* deploy_stat, uint8_t max_attempts) {
	if(flight_stats.mach_lock.activated) {
		Pyro_SetContinuity(false);
		return;
	}

    pyro_t *primary = Pyro_GetByRole(primary_role);
    pyro_t *backup = Pyro_GetByRole(backup_role);

    uint32_t current_time = HAL_GetTick();
    uint32_t elapsed_time = current_time - fire_timer;

	if(!Pyro_IsArmed(&system_measurements) && current_config.flight_test_mode == STATE_FALSE) {
        Pyro_Arming(&system_measurements, true, false);
    }

    if(elapsed_time >= current_config.fire_attempt_delay_ms) {
        if(!backup_active) {
            // Primary
            if(primary != NULL && fire_attempt_count < max_attempts) {
				if(current_config.flight_test_mode == STATE_FALSE) {
                	Pyro_StartFire(primary);
                }

                if(!deploy_stat->valid) {
					deploy_stat->valid = STATE_TRUE;
                    deploy_stat->value = flight_data.kalman_z;
                    deploy_stat->time_ms = current_time - flight_stats.flight_start_time_ms;
                }

                fire_attempt_count++;
                fire_timer = current_time;
            }
            // Backup switch
            else if(backup != NULL && backup->is_connected) {
                backup_active = true;
                fire_attempt_count = 0;
                fire_timer = current_time;
            }
        } else {
            // Backup
            if(backup != NULL && fire_attempt_count < max_attempts) {
				if(current_config.flight_test_mode == STATE_FALSE) {
                	Pyro_StartFire(backup);
                }

                if(!deploy_stat->valid) {
					deploy_stat->valid = STATE_TRUE;
                    deploy_stat->value = flight_data.kalman_z;
                    deploy_stat->time_ms = current_time - flight_stats.flight_start_time_ms;
                }

                fire_attempt_count++;
                fire_timer = current_time;
            }
        }
    } else if(elapsed_time >= PYRO_RISING_TIME_MS) {
        if(!backup_active && primary != NULL) {
			if(current_config.flight_test_mode == STATE_FALSE) {
            	Pyro_StopFire(primary);
            }
        } else if(backup_active && backup != NULL) {
			if(current_config.flight_test_mode == STATE_FALSE) {
            	Pyro_StopFire(backup);
            }
        }
    }
}

// TODO: check pyro number to adapt target attempt
// TODO: use dedicated timer to failsafe drogue fire
void FSM_Update(void) {
	flight_duration = __HAL_TIM_GET_COUNTER(&htim5) / 1000; // Failsafe apogee timeout (us)
    switch(current_global_state) {
        case STATE_PREFLIGHT:
        	switch(current_preflight_substate) {
        		case SUB_STATIC_ORIENTED:
        			// Security : stability check, orientation
					bool is_static = (fabs(flight_data.kalman_v) < current_config.landing_detect_v_threshold);
					bool is_oriented_up = flight_data.imu_acc_z > STATIC_ACC_Z_THRESHOLD;
					if(is_static && is_oriented_up) {
						if(current_config.flight_test_mode == STATE_TRUE) {
							// Positive false
							flight_data.system_states |= FLAG_PYROS_ARMED_OK;
							// Skip pyros/arm check
							current_preflight_substate = SUB_WAITING_FLIGHT;
							flight_stats.fsm_trans.preflight_waiting_flight = HAL_GetTick();
							ODB_SetMissionState(&flight_data, STATE_PREFLIGHT, SUB_WAITING_FLIGHT);
						} else {
							current_preflight_substate = SUB_PYROS_TEST;
							flight_stats.fsm_trans.preflight_pyros_test = HAL_GetTick();
							ODB_SetMissionState(&flight_data, STATE_PREFLIGHT, SUB_PYROS_TEST);
						}
					}
					break;

    			case SUB_PYROS_TEST:
    				// Security : pyros
					bool pyros_ok = (ODB_GetPyroStates(&flight_data) >= current_config.min_needed_pyro_nb);
					bool arm_ok = (flight_data.system_states & FLAG_PYROS_ARMED_OK) != 0;
    				if(pyros_ok && arm_ok) {
    					current_preflight_substate = SUB_WAITING_FLIGHT;
    					flight_stats.fsm_trans.preflight_waiting_flight = HAL_GetTick();
    					ODB_SetMissionState(&flight_data, STATE_PREFLIGHT, SUB_WAITING_FLIGHT);
    				}
    				break;

    			case SUB_WAITING_FLIGHT:
    				// Security : app unlock
					if(is_ready_by_app || is_force_flight) {
						// Buzzer report (Blocking routine)
						if(current_config.enable_buzzer == STATE_TRUE) {
							const odb_stats_t *last_stats = Logger_GetLastFlightStats();
							if(last_stats != NULL) {
								Buzzer_ReportStatus(&buzzer, current_config.buzzer_report_tone_hz, system_measurements.vin_batt, (bool[]){(flight_data.system_states & FLAG_PYRO1_CONN) != 0U, (flight_data.system_states & FLAG_PYRO2_CONN) != 0U, (flight_data.system_states & FLAG_PYRO3_CONN) != 0U, (flight_data.system_states & FLAG_PYRO4_CONN) != 0U}, 0U, last_stats->flight_time_ms, last_stats->max_altitude_kalman.value, last_stats->max_altitude_kalman.valid);
							} else {
								Buzzer_ReportStatus(&buzzer, current_config.buzzer_report_tone_hz, system_measurements.vin_batt, (bool[]){(flight_data.system_states & FLAG_PYRO1_CONN) != 0U, (flight_data.system_states & FLAG_PYRO2_CONN) != 0U, (flight_data.system_states & FLAG_PYRO3_CONN) != 0U, (flight_data.system_states & FLAG_PYRO4_CONN) != 0U}, 0U, 0, 0.0f, false);
							}
							HAL_Delay(2000);
							Buzzer_PlayMelody(&buzzer, ram_ranch_solo, RAM_RANCH_SOLO_NOTE_COUNT, 3);
						}

						Pyro_SetContinuity(false);
						Pyro_Arming(&system_measurements, false, false);

						current_global_state = STATE_ARMED;
						flight_stats.fsm_trans.armed = HAL_GetTick();
						ODB_SetMissionState(&flight_data, STATE_ARMED, 0);
					}
					break;
        	}
        	break;

        case STATE_ARMED:
            if(flight_data.highg_acc_z > current_config.acc_z_launch_threshold || is_force_flight) {
				if(current_config.flight_test_mode == STATE_FALSE) {
                	Scheduler_SetActive("BTRx", false);
                	Scheduler_SetActive("BTTx", false);
                }

                flight_stats.flight_start_time_ms = HAL_GetTick();
                HAL_TIM_Base_Start(&htim5);      	// Start timer to measure time since launch
                __HAL_TIM_SET_COUNTER(&htim5, 0);   // Reset timer counter
                current_global_state = STATE_INFLIGHT;
                current_inflight_substate = SUB_BOOST;
                flight_stats.fsm_trans.inflight_boost = 0;
                ODB_SetMissionState(&flight_data, STATE_INFLIGHT, SUB_BOOST);

                Logger_Enable(true);

                is_force_flight = false;
            }
            break;

        case STATE_INFLIGHT:
            // Handle substate transitions based on events
            switch(current_inflight_substate) {
                case SUB_BOOST:
                    // Wait for boost phase detection
                	if(flight_data.kalman_v >= current_config.boost_phase_v_threshold) {
						flight_stats.mach_lock.activated = STATE_TRUE;
                	    if(flight_stats.mach_lock.start_time_ms == 0) {
                	        flight_stats.mach_lock.start_time_ms = HAL_GetTick() - flight_stats.flight_start_time_ms;
                	    }
                	    current_inflight_substate = SUB_FAST;
                	    flight_stats.fsm_trans.inflight_fast = HAL_GetTick() - flight_stats.flight_start_time_ms;
                	    ODB_SetMissionState(&flight_data, STATE_INFLIGHT, SUB_FAST);
                	}
                    break;

                case SUB_FAST:
                    // Wait for fast ascent detection
                	// TODO: add pyros_arming_min_altitude_m & pyros_fire_max_tilt_angle_deg
	                if(flight_data.kalman_v < current_config.boost_phase_v_threshold) {
						flight_stats.mach_lock.activated = STATE_FALSE;
						flight_stats.mach_lock.end_time_ms = HAL_GetTick() - flight_stats.flight_start_time_ms;
						current_inflight_substate = SUB_COAST;
						//ODB_ResetAltitudeTrend();
						flight_stats.fsm_trans.inflight_coast = HAL_GetTick() - flight_stats.flight_start_time_ms;
						ODB_SetMissionState(&flight_data, STATE_INFLIGHT, SUB_COAST);
					}
                    break;

                case SUB_COAST:
                    // Wait for apogee detection
                	// TODO: add pyros_arming_min_altitude_m
                	if(current_config.stage_role == STAGE_ROLE_SUSTAINER && !sustainer_ignited && flight_data.highg_acc_z > current_config.acc_z_launch_threshold) {
                		// cyclic inflight substate for sustainer
                		sustainer_ignited = true;
						current_inflight_substate = SUB_BOOST;
						flight_stats.fsm_trans.inflight_drogue = HAL_GetTick() - flight_stats.flight_start_time_ms;
						ODB_SetMissionState(&flight_data, STATE_INFLIGHT, SUB_BOOST);
						break;
					}

	                /* WINDOWED FAILSAFE LOGIC
					 * 1. Nominal apogee detection : velocity below threshold after a reasonable flight duration (to avoid early detection during boost or fast phase)
					 * 2. Failsafe timeout : if apogee not detected after a maximum time
					 */
                	bool nominal_apogee = false;
					switch(current_config.apogee_detection_mode) {
						case APOGEE_DETECTION_AUTO:
							if(current_config.stage_role == STAGE_ROLE_SUSTAINER) {
								nominal_apogee = (flight_data.kalman_v < current_config.apogee_detect_v_threshold);
							} else {
								nominal_apogee = (flight_data.barometric_trend == ALTITUDE_TREND_DESCENDING);
							}
							break;

						case APOGEE_DETECTION_KALMAN:
							nominal_apogee = (flight_data.kalman_v < current_config.apogee_detect_v_threshold);
							break;

						case APOGEE_DETECTION_BAROMETRIC:
							nominal_apogee = (flight_data.barometric_trend == ALTITUDE_TREND_DESCENDING);
							break;

						default:
							nominal_apogee = false;
							break;
					}

                	bool failsafe_timeout = (flight_duration > current_config.apogee_failsafe_ms);
					if(nominal_apogee || failsafe_timeout) {
						if(!flight_stats.apogee.valid) {
							flight_stats.apogee.valid = STATE_TRUE;
							flight_stats.apogee.value = flight_data.kalman_z;
							flight_stats.apogee.time_ms = HAL_GetTick() - flight_stats.flight_start_time_ms;
						}

						current_inflight_substate = SUB_DROGUE;
						flight_stats.fsm_trans.inflight_drogue = HAL_GetTick() - flight_stats.flight_start_time_ms;
						ODB_SetMissionState(&flight_data, STATE_INFLIGHT, SUB_DROGUE);

						fire_timer = 0;
						fire_attempt_count = 0;
						backup_active = false;

						// Arming Drogue
						if(!flight_stats.mach_lock.activated) {
							pyro_t *drogue = Pyro_GetByRole(PYRO_ROLE_DROGUE);
							if(drogue && !Pyro_IsArmed(&system_measurements) && current_config.flight_test_mode == STATE_FALSE) {
								Pyro_Arming(&system_measurements, true, false);
							}

							pyro_t *drogue_backup = Pyro_GetByRole(PYRO_ROLE_DROGUE_BACKUP);
							if(drogue_backup && !Pyro_IsArmed(&system_measurements) && current_config.flight_test_mode == STATE_FALSE) {
								Pyro_Arming(&system_measurements, true, false);
							}
						}
					}
					break;

				case SUB_DROGUE:
					// Wait for drogue deployment detection
					FSM_HandleDeployment(PYRO_ROLE_DROGUE, PYRO_ROLE_DROGUE_BACKUP, &flight_stats.drogue_deploy, current_config.drogue_fire_attempt_max_nb);

					if(flight_data.kalman_z <= current_config.main_deploy_altitude_threshold_m) {
						current_inflight_substate = SUB_MAIN;
						flight_stats.fsm_trans.inflight_main = HAL_GetTick() - flight_stats.flight_start_time_ms;
						ODB_SetMissionState(&flight_data, STATE_INFLIGHT, SUB_MAIN);

						fire_timer = 0;
						fire_attempt_count = 0;
						backup_active = false;

						if(!flight_stats.mach_lock.activated) {
							pyro_t *main = Pyro_GetByRole(PYRO_ROLE_MAIN);
							if(main && !Pyro_IsArmed(&system_measurements) && current_config.flight_test_mode == STATE_FALSE) {
								Pyro_Arming(&system_measurements, true, false);
							}

							pyro_t *main_backup = Pyro_GetByRole(PYRO_ROLE_MAIN_BACKUP);
							if(main_backup && !Pyro_IsArmed(&system_measurements) && current_config.flight_test_mode == STATE_FALSE) {
								Pyro_Arming(&system_measurements, true, false);
							}
						}
					}
					break;

				case SUB_MAIN:
					// Wait for main deployment detection
					FSM_HandleDeployment(PYRO_ROLE_MAIN, PYRO_ROLE_MAIN_BACKUP, &flight_stats.main_deploy, current_config.main_fire_attempt_max_nb);

					if(fabs(flight_data.kalman_v) < current_config.landing_detect_v_threshold) {
						if(landing_timer == 0) landing_timer = HAL_GetTick() - flight_stats.flight_start_time_ms;
						if(HAL_GetTick() - landing_timer > current_config.landing_detect_threshold_ms) {
							Pyro_Arming(&system_measurements, false, false);

							current_inflight_substate = SUB_LANDED;
							flight_stats.fsm_trans.inflight_landed = HAL_GetTick() - flight_stats.flight_start_time_ms;
							ODB_SetMissionState(&flight_data, STATE_INFLIGHT, SUB_LANDED);
						}
					} else {
						landing_timer = 0;
					}
					break;

				case SUB_LANDED:
				    flight_stats.flight_time_ms = flight_duration;

				    Logger_Enable(false);
				    Logger_FlushRemaining();

				    Logger_SaveStats(&flight_stats);

				    Scheduler_SetActive("Data_Update", false);
				    Scheduler_SetActive("Telemetry", false);
				    Scheduler_SetActive("Idefix", true);

				    RFD900x_Sleep(&rfd900x);

				    Logger_ExportToSD(&flight_stats);

				    Buzzer_StartPeriodicBip(&buzzer, current_config.buzzer_report_tone_hz, 500, 500);

				    current_global_state = STATE_POSTFLIGHT;
				    flight_stats.fsm_trans.postflight = HAL_GetTick() - flight_stats.flight_start_time_ms;
				    ODB_SetMissionState(&flight_data, STATE_POSTFLIGHT, 0);
				    break;
			}
			break;

		case STATE_POSTFLIGHT:
			Buzzer_ProcessPeriodicBip(&buzzer);
			break;
	}
}
