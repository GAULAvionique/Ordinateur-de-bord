/*
 * app_comm.h
 *
 *  Created on: 6 juin 2026
 *      Author: SamLol12
 */

#ifndef INC_COMM_APP_COMM_H_
#define INC_COMM_APP_COMM_H_


#include "odb.h"
#include "Drivers/hm11.h"
#include "Systems/config.h"
#include "Systems/logger.h"


#define APP_SYNC_1 0xAB
#define APP_SYNC_2 0xCD

typedef enum {
    MSG_TELEMETRY  		= 0x01,
	MSG_GENERIC_DATA 	= 0x02,
    MSG_CMD        		= 0x03,
	MSG_ACK        		= 0x04,
	MSG_STATS_CHUNK     = 0x05,
	MSG_DATA_CHUNK      = 0x06
} app_msg_type_t;

typedef enum {
    CMD_PING       				= 0x01,
    CMD_ARM_DISARM 				= 0x02,
    CMD_FIRE_PYRO  				= 0x03,
    CMD_APPLY_CFG  				= 0x04,
    CMD_RESET_CFG  				= 0x05,
    CMD_REQ_CFG    				= 0x06,
	CMD_RESET_MEM  				= 0x07,
	CMD_REQ_EVENTS 				= 0x08,
	CMD_RESET_FLIGHTS 			= 0x09,
	CMD_PLAY_MELODY				= 0x0A,
	CMD_SET_READY_FLIGHT 		= 0x0B,

	// Tests FSM
    CMD_TEST_ARMING_MODULE  	= 0x0C,
	CMD_TEST_PYROS				= 0x0D,
	CMD_TEST_ARMED				= 0x0E,
	CMD_TEST_SUBBOOST			= 0x0F,
	CMD_TEST_SUBFAST			= 0x10,
	CMD_TEST_SUBCOAST			= 0x11,
	CMD_TEST_SUBDROGUE			= 0x12,
	CMD_TEST_SUBMAIN			= 0x13,
	CMD_TEST_SUBLANDED			= 0x14,
	CMD_TEST_MACHLOCK			= 0x15,
	CMD_REQ_FLIGHT_DATA   		= 0x16,
	CMD_REQ_CANCEL_FLIGHT_DATA 	= 0x17,
	CMD_TEST_FLIGHT_FLASH		= 0x18,
} app_cmd_id_t;

void AppComm_SendTelemetry(hm11_t *hm11_dev, const odb_data_t *data);
void AppComm_ProcessRx(hm11_t *hm11_dev);

#endif /* INC_COMM_APP_COMM_H_ */
