/*
 * scheduler.c
 *
 *  Created on: 24 avr. 2026
 *      Author: SamLol12
 */


#include "Systems/scheduler.h"
#include "stm32f4xx_hal.h"
#include <string.h>



static task_t tasks[MAX_TASKS];
static uint8_t task_count = 0;

void Scheduler_Init(void) {
    task_count = 0;
    for(int i = 0; i < MAX_TASKS; i++) {
        tasks[i].name = NULL;
        tasks[i].task_func = NULL;
        tasks[i].is_active = false;
    }
}

bool Scheduler_SetActive(const char *name, bool active) {
    for(uint8_t i = 0; i < task_count; i++) {
        if(tasks[i].name != NULL && strcmp(tasks[i].name, name) == 0) {
            tasks[i].is_active = active;

            if(active) {
                tasks[i].last_run_ms = HAL_GetTick();
            }

            return true;
        }
    }

    return false;
}

bool Scheduler_AddTask(char *name, void (*func)(void), uint32_t period_ms) {
    if(task_count >= MAX_TASKS || func == NULL || period_ms <= 0) {
        return false;
    }
    
    tasks[task_count].name = name;
    tasks[task_count].task_func = func;
    tasks[task_count].period_ms = period_ms;
    tasks[task_count].last_run_ms = HAL_GetTick();
    tasks[task_count].is_active = false;
    
    task_count++;

    return true;
}

void Scheduler_Run(void) {
    uint32_t current_time = HAL_GetTick();
    for(uint8_t i = 0; i < task_count; i++) {
        if(tasks[i].is_active && tasks[i].task_func != NULL) {
            if((current_time - tasks[i].last_run_ms) >= tasks[i].period_ms) {
                tasks[i].task_func();
                tasks[i].last_run_ms = current_time;
            }
        }
    }
}

bool Scheduler_SetPeriod(const char *name, uint32_t period_ms) {
    for(uint8_t i = 0; i < task_count; i++) {
        if(tasks[i].is_active && tasks[i].name != NULL) {
            if(strcmp(tasks[i].name, name) == 0) {
            	tasks[i].period_ms = period_ms;

                return true;
            }
        }
    }

    return false;
}
