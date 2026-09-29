/*
 * scheduler.h
 *
 *  Created on: 24 avr. 2026
 *      Author: SamLol12
 */

#ifndef INC_SYSTEMS_SCHEDULER_H_
#define INC_SYSTEMS_SCHEDULER_H_

#include <stdint.h>
#include <stdbool.h>

#define MAX_TASKS 10

typedef struct {
	char		*name;
    void 		(*task_func)(void); // Function pointer to the task
    uint32_t 	period_ms;          // How often the task should run (in milliseconds)
    uint32_t 	last_run_ms;        // Timestamp of the last time the task was run (in milliseconds)
    bool 		is_active;          // Dynamically set enabled/disabled a task
} task_t;


void Scheduler_Init(void);

bool Scheduler_SetActive(const char *name, bool active);
bool Scheduler_AddTask(char *name, void (*func)(void), uint32_t period_ms);
bool Scheduler_SetPeriod(const char *name, uint32_t period_ms);
void Scheduler_Run(void);

#endif /* INC_SYSTEMS_SCHEDULER_H_ */
