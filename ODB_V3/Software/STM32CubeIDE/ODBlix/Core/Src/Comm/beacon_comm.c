/*
 * beacon_comm.c
 *
 *  Created on: 14 juin 2026
 *      Author: SamLol12
 */

#include "Comm/beacon_comm.h"
#include "Systems/config.h"


void Beacon_SendCoordinates(idefix_t *idefix_dev, const int32_t lat_e7, const int32_t lon_e7) {
    if(!idefix_dev) return;

    uint8_t payload[8];
    uint32_t u_lat = (uint32_t)lat_e7;
    uint32_t u_lon = (uint32_t)lon_e7;

    payload[0] = (uint8_t)(u_lat & 0xFF);
    payload[1] = (uint8_t)((u_lat >> 8) & 0xFF);
    payload[2] = (uint8_t)((u_lat >> 16) & 0xFF);
    payload[3] = (uint8_t)((u_lat >> 24) & 0xFF);

    payload[4] = (uint8_t)(u_lon & 0xFF);
    payload[5] = (uint8_t)((u_lon >> 8) & 0xFF);
    payload[6] = (uint8_t)((u_lon >> 16) & 0xFF);
    payload[7] = (uint8_t)((u_lon >> 24) & 0xFF);

    Idefix_TransmitData(idefix_dev, IDEFIX_CMD_COORD, payload, 8);
}

void Beacon_SetFrequency(idefix_t *idefix_dev) {
    if(!idefix_dev) return;

    uint8_t payload[4];
    uint32_t freq = current_config.idefix_frequency_hz;

    payload[0] = (uint8_t)(freq & 0xFF);
    payload[1] = (uint8_t)((freq >> 8) & 0xFF);
    payload[2] = (uint8_t)((freq >> 16) & 0xFF);
    payload[3] = (uint8_t)((freq >> 24) & 0xFF);

    Idefix_TransmitData(idefix_dev, IDEFIX_CMD_FREQ, payload, 4);
}
