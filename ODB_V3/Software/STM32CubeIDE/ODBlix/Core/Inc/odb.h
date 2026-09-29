/*
 * odb.h
 *
 *  Created on: 3 mai 2026
 *      Author: SamLol12
 */

#ifndef INC_ODB_H_
#define INC_ODB_H_


#include "Drivers/adxl382.h"
#include "Drivers/bno055.h"
#include "Drivers/hm11.h"
#include "Drivers/idefix.h"
#include "Drivers/l76lm33.h"
#include "Drivers/ltste682krkgwt.h"
#include "Utils/dwt.h"
#include "Drivers/LowLevel/kalman_nav.h"
#include "Drivers/LowLevel/altitude_trend.h"
#include "Drivers/ms5611.h"
#include "Drivers/pyros.h"
#include "Drivers/rfd900x.h"
#include "Drivers/smtb0927twr.h"
#include "Drivers/system_measurements.h"
#include "Drivers/w25q512jveim.h"
#include "Drivers/mem2067.h"
#include "Protocols/odb_protocol.h"
#include "stm32f4xx_hal.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdbool.h>
#include <assert.h>


typedef enum {
    ODB_OK                  =  0,
    ODB_WARNING             = -1,
    ODB_ALIMENTATION_ERROR  = -2,
    ODB_ERROR               = -3,
} odb_state_t;


odb_state_t ODB_Init(odb_data_t *data, odb_stats_t *stats);

void ODB_Reset(odb_data_t *data, odb_stats_t *stats);
void ODB_Update(odb_data_t *data, odb_stats_t *stats);
uint16_t ODB_SetEventStates(const odb_stats_t *stats);
int8_t ODB_SetMissionState(odb_data_t *data, uint8_t global_state, uint8_t sub_state);
uint8_t ODB_GetPyroStates(const odb_data_t *data);


#endif /* INC_ODB_H_ */
