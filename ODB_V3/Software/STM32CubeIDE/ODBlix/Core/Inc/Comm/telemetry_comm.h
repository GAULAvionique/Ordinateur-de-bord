/*
 * telemtry_comm.h
 *
 *  Created on: 14 juin 2026
 *      Author: SamLol12
 */

#ifndef INC_COMM_TELEMETRY_COMM_H_
#define INC_COMM_TELEMETRY_COMM_H_

#include "Protocols/odb_protocol.h"
#include "Drivers/rfd900x.h"
#include "mavlink/odb_mavlink_v1/mavlink.h"

#define MAVLINK_COMPONENT_ID 1


void Telemetry_SendRocketData(rfd900x_t *rfd_dev, const mavlink_modem_id_t modem_id, odb_data_t *data, const uint32_t current_time_ms);

#endif /* INC_COMM_TELEMETRY_COMM_H_ */
