/*
 * Pyros.h
 *
 *  Created on: May 15, 2024
 *      Author: AudaceLol12
 *
 *  Edited on: Mar 02, 2026
 *  	Author: AudaceLol12
 */

#include "Drivers/pyros.h"
#include <stddef.h>


extern pyro_t pyros[PYRO_MAX];


pyros_state_t Pyro_Init(pyro_t *dev) {
	if(!dev || dev->channel >= PYRO_MAX || !dev->fire_port || !dev->fire_pin) {
		return PYRO_INIT_ERROR;
	}

	dev->is_connected = false;
	dev->is_fire = false;
	dev->fire_attempts = 0;

	HAL_GPIO_WritePin(Pyros_Arm_GPIO_Port, Pyros_Arm_Pin, GPIO_PIN_RESET);
	Pyro_SetContinuity(false);


	return PYRO_OK;
}

void Pyro_SetContinuity(bool enable) {
	if(enable) {
		HAL_GPIO_WritePin(Pyros_CTN_GPIO_Port, Pyros_CTN_Pin, GPIO_PIN_SET);
	} else {
		HAL_GPIO_WritePin(Pyros_CTN_GPIO_Port, Pyros_CTN_Pin, GPIO_PIN_RESET);
	}
}

bool Pyro_IsContinuityActive(system_measurements_t *measures) {
	if(!measures) {
		return false;
	}

	SystemMeasurements_ComputePyros(measures);
	bool is_pyros_ctn = (measures->pyros_arming >= PYRO_THRESHOLD_CONN);

	return is_pyros_ctn;
}

bool Pyro_IsArmed(system_measurements_t *measures) {
	if(!measures) {
		return false;
	}

	SystemMeasurements_ComputePyros(measures);
	bool is_pyros_armed = (measures->pyros_arming >= PYRO_THRESHOLD_ARMED);

	return is_pyros_armed;
}

pyros_state_t Pyro_Arming(system_measurements_t *measures, bool arming, bool is_test) {
	if(!measures) return PYRO_ARMING_ERROR;

	if(arming) {
		Pyro_SetContinuity(false);
		HAL_GPIO_WritePin(Pyros_Arm_GPIO_Port, Pyros_Arm_Pin, GPIO_PIN_SET);
	} else {
		HAL_GPIO_WritePin(Pyros_Arm_GPIO_Port, Pyros_Arm_Pin, GPIO_PIN_RESET);
		Pyro_SetContinuity(true);
	}

	if(is_test) HAL_Delay(PYRO_RISING_TIME_MS * 5);

	bool is_pyros_armed = Pyro_IsArmed(measures);
	return (is_pyros_armed == arming) ? PYRO_OK : PYRO_ARMING_ERROR;
}

pyros_state_t Pyro_StartFire(pyro_t *dev) {
    if(!dev || !dev->fire_port || !dev->fire_pin) return PYRO_FIRE_ERROR;

    HAL_GPIO_WritePin(dev->fire_port, dev->fire_pin, GPIO_PIN_SET);
    dev->is_fire = true;
    dev->fire_attempts++;

    return PYRO_OK;
}

void Pyro_StopFire(pyro_t *dev) {
    if(!dev || !dev->fire_port || !dev->fire_pin) return;

    HAL_GPIO_WritePin(dev->fire_port, dev->fire_pin, GPIO_PIN_RESET);
}

pyro_t* Pyro_GetByRole(pyro_role_t role) {
	if(role >= PYROS_ROLE_MAX) return NULL;

	for(int i = 0; i < PYRO_MAX; i++) {
		if(current_config.pyro_roles[i] == role) {
			return &pyros[i];
		}
	}
	return NULL;
}
