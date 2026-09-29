/*
 * SMTB0927TWR.h
 *
 *  Created on: 2 mars 2026
 *      Author: AudaceLol12
 */

#ifndef INC_DRIVERS_SMTB0927TWR_H_
#define INC_DRIVERS_SMTB0927TWR_H_

#include "stm32f4xx_hal.h"
#include <stdint.h>
#include <stdbool.h>


#define BUZZER_MAX_FREQ 2700


typedef enum {
    STOP,
    START,
    PENDING,
    ARMED,
    CRASH,
} buzzer_routines_t;

typedef struct {
    uint8_t   nbBips;
    uint16_t  frequencyStart;
    uint16_t  frequencyEnd;
    uint32_t  delayModulation;
    uint32_t  delayPause;
} buzzer_parametres_t;

typedef struct {
    TIM_HandleTypeDef *htim;
    uint32_t channel;

    bool     inf_bip_active;
	bool     inf_bip_state;
	uint16_t inf_bip_freq_hz;
	uint32_t inf_bip_on_time_ms;
	uint32_t inf_bip_off_time_ms;
	uint32_t inf_bip_last_tick;
} buzzer_t;

// Melody frequencies
#define NOTE_F3   175
#define NOTE_G3   196
#define NOTE_A3   220
#define NOTE_BB3  233
#define NOTE_C4   262
#define NOTE_D4   294
#define NOTE_E4   330
#define NOTE_F4   349
#define NOTE_G4   392
#define NOTE_A4   440
#define NOTE_BB4  466
#define NOTE_C5   523
#define NOTE_D5   587
#define NOTE_E5   659
#define NOTE_F5   698
#define NOTE_G5   784
#define NOTE_A5   880
#define NOTE_BB5  932
#define NOTE_C6   1047
#define NOTE_D6   1175
#define NOTE_E6   1319
#define NOTE_F6   1397
#define NOTE_G6   1568
#define NOTE_A6   1760
#define NOTE_BB6  1865
#define NOTE_C7   2093
#define NOTE_D7   2349
#define NOTE_E7   2637
#define REST      0

#define BPM       	169
#define MS_PER_BEAT (60000 / BPM)

#define T_16  (MS_PER_BEAT / 4)
#define T_8   (MS_PER_BEAT / 2)
#define T_8D  (T_8 + T_16)
#define T_4   (MS_PER_BEAT)
#define T_2   (MS_PER_BEAT * 2)

typedef struct {
    uint16_t frequency;
    uint32_t duration;
} note_t;

#define RAM_RANCH_SOLO_NOTE_COUNT 91U
extern note_t ram_ranch_solo[];


void Buzzer_RunRoutine(buzzer_t *dev, buzzer_routines_t routine);
void Buzzer_ReportStatus(buzzer_t *dev, uint16_t freq_hz, uint16_t battery_dv, bool pyros_continuity[4], int8_t global_state, const uint32_t flight_time_ms, const float max_altitude, bool valid);
void Buzzer_StartPeriodicBip(buzzer_t *dev, uint16_t freq_hz, uint32_t on_time_ms, uint32_t off_time_ms);
void Buzzer_StopPeriodicBip(buzzer_t *dev);
void Buzzer_ProcessPeriodicBip(buzzer_t *dev);
void Buzzer_PlayMelody(buzzer_t *dev, note_t *melody, uint16_t num_notes, uint8_t loop);

#endif /* INC_DRIVERS_SMTB0927TWR_H_ */
