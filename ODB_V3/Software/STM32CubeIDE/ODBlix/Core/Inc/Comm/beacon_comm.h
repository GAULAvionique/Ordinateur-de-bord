/*
 * beacon_comm.h
 *
 *  Created on: 14 juin 2026
 *      Author: SamLol12
 */

#ifndef INC_COMM_BEACON_COMM_H_
#define INC_COMM_BEACON_COMM_H_

#include "Drivers/idefix.h"


void Beacon_SendCoordinates(idefix_t *idefix_dev, const int32_t lat_e7, const int32_t lon_e7);
void Beacon_SetFrequency(idefix_t *idefix_dev);

#endif /* INC_COMM_BEACON_COMM_H_ */
