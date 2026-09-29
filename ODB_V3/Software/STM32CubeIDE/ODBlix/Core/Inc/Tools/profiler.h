/*
 * profiler.h
 *
 *  Created on: 18 mai 2026
 *      Author: SamLol12
 */

#ifndef INC_TOOLS_PROFILER_H_
#define INC_TOOLS_PROFILER_H_

#include <stdint.h>


typedef enum {
    PROFILE_TASK_BARO = 0,
    PROFILE_TASK_IMU,
	PROFILE_TASK_HIGHG,
    PROFILE_TASK_GPS,
    PROFILE_TASK_KALMAN,
	PROFILE_TASK_BAROMETRIC,
    PROFILE_TASK_TELEMETRY,
	PROFILE_TASK_BLE,
	PROFILE_TASK_ADC,

	PROFILE_DATAUPDATE,
	PROFILE_FSM,
	PROFILE_LOGGER,
	PROFILE_TELEMETRY,
	PROFILE_IDEFIX,
	PROFILE_BTRX,
	PROFILE_BTTX,
	// ...

    PROFILE_MAX_TASKS
} profiler_task_id_t;

typedef struct {
    uint32_t start_cycles;
	uint32_t current_time_us;
	uint32_t max_time_us;
} task_metrics_t;


void Profiler_Init(void);

void Profiler_StartTask(profiler_task_id_t task_id);
void Profiler_StopTask(profiler_task_id_t task_id);
void Profiler_LogResults(uint32_t interval_ms);

#endif /* INC_TOOLS_PROFILER_H_ */
