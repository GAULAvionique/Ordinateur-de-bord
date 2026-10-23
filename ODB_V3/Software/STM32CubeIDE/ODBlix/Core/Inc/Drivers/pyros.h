/*
 * Pyros.h
 *
 *  Created on: May 15, 2024
 *      Author: AudaceLol12
 *
 *  Edited on: Mar 02, 2026
 *  	Author: AudaceLol12
 */

#ifndef INC_DRIVERS_PYROS_H_
#define INC_DRIVERS_PYROS_H_

#include "Drivers/system_measurements.h"
#include "Systems/config.h"
#include "main.h"
#include "stm32f4xx_hal.h"
#include <stdbool.h>


#define PYRO_THRESHOLD_CONN 	300
#define PYRO_THRESHOLD_ARMED 	1000
#define PYRO_RISING_TIME_MS		50		// DO NOT RAISE THIS VALUE, Q2 CAN OVERHEATING OTHERWISE


typedef enum {
	PYRO_OK = 0,
	PYRO_INIT_ERROR = -1,
	PYRO_ARMING_ERROR = -2,
	PYRO_FIRE_ERROR = -3
} pyros_state_t;

typedef enum {
	PYRO_1 		= 0,
	PYRO_2 		= 1,
	PYRO_3 		= 2,
	PYRO_4 		= 3,
	PYRO_MAX 	= 4
} pyro_channel_t;

typedef struct {
	GPIO_TypeDef 	*fire_port;
	uint16_t		fire_pin;

	pyro_channel_t  channel;
	bool			is_connected;
	bool			is_fire;
	uint8_t			fire_attempts;
} pyro_t;


pyros_state_t Pyro_Init(pyro_t *dev);

void Pyro_SetContinuity(bool enable);
bool Pyro_IsContinuityActive(system_measurements_t *measures);
pyros_state_t Pyro_Arming(system_measurements_t *measures, bool arming, bool is_test);
bool Pyro_IsArmed(system_measurements_t *measures);
pyros_state_t Pyro_StartFire(pyro_t *dev);
void Pyro_StopFire(pyro_t *dev);

pyro_t* Pyro_GetByRole(pyro_role_t role);

#endif /* INC_DRIVERS_PYROS_H_ */
