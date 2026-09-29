/*
 * profiler.c
 *
 *  Created on: 18 mai 2026
 *      Author: SamLol12
 */


#include "Tools/profiler.h"

#include "Utils/dwt.h"
#include "stm32f4xx_hal.h"
#include <stdio.h>


static task_metrics_t system_tasks[PROFILE_MAX_TASKS];
static uint32_t last_log_time = 0;
static const char *const task_names[PROFILE_MAX_TASKS] = {
    "BARO",
    "IMU",
    "HIGHG",
    "GPS",
    "KALMAN",
	"BAROMETRIC"
    "TELEMETRY",
    "BLE",
    "ADC",
    "DATAUPDATE",
    "FSM",
    "LOGGER",
    "PROFILE_TELEMETRY",
    "IDEFIX",
    "BTRX",
    "BTTX"
};

void Profiler_Init(void) {
    for(int i = 0; i < PROFILE_MAX_TASKS; i++) {
        system_tasks[i].start_cycles = 0;
        system_tasks[i].current_time_us = 0u;
        system_tasks[i].max_time_us = 0u;
    }

    last_log_time = HAL_GetTick();
}

void Profiler_StartTask(profiler_task_id_t task_id) {
    if(task_id >= PROFILE_MAX_TASKS) return;

    system_tasks[task_id].start_cycles = DWT_GetCycles();
}

void Profiler_StopTask(profiler_task_id_t task_id) {
    if(task_id >= PROFILE_MAX_TASKS) return;

    uint32_t stop_cycles = DWT_GetCycles();
    uint32_t elapsed_cycles = stop_cycles - system_tasks[task_id].start_cycles;
    uint32_t elapsed_us = (uint32_t)(((uint64_t)elapsed_cycles * 1000000ULL) / (uint64_t)SystemCoreClock);

    system_tasks[task_id].current_time_us = elapsed_us;

    if(elapsed_us > system_tasks[task_id].max_time_us) {
        system_tasks[task_id].max_time_us = elapsed_us;
    }
}

void Profiler_LogResults(uint32_t interval_ms) {
	uint32_t current_time = HAL_GetTick();
	if(current_time - last_log_time < interval_ms) return;
	last_log_time = current_time;

    printf("P_LOG: ");
    for(int i = 0; i < PROFILE_MAX_TASKS; i++) {
         unsigned long cur_us = (unsigned long)system_tasks[i].current_time_us;
         unsigned long max_us = (unsigned long)system_tasks[i].max_time_us;
         printf("%s:%luus(%luus) | ",
             task_names[i],
             cur_us,
             max_us);
    }
    printf("\n");
}
