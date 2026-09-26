/*
 * flight_fsm.h
 *
 *  Created on: 24 avr. 2026
 *      Author: gagno
 */

#ifndef INC_SYSTEMS_FLIGHT_FSM_H_
#define INC_SYSTEMS_FLIGHT_FSM_H_


typedef enum {
    STATE_PREFLIGHT,
    STATE_ARMED,
    STATE_INFLIGHT,
    STATE_POSTFLIGHT
} global_state_t;

typedef enum {
	SUB_STATIC_ORIENTED,
	SUB_PYROS_TEST,
	SUB_WAITING_FLIGHT
} preflight_substate_t;

typedef enum {
    SUB_BOOST,
    SUB_FAST,
    SUB_COAST,
    SUB_DROGUE,
    SUB_MAIN,
    SUB_LANDED
} inflight_substate_t;


void FSM_Update(void);

#endif /* INC_SYSTEMS_FLIGHT_FSM_H_ */
