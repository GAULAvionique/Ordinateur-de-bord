/*
 * SMTB0927TWR.c
 *
 *  Created on: 2 mars 2026
 *      Author: AudaceLol12
 */


#include "Drivers/smtb0927twr.h"
#include <stdlib.h>


#define TIMER_CLK_HZ 1000000


static const buzzer_parametres_t buzzParams[] = {
    // nbBips, freqStart, freqEnd, delayModulation, delayPause
    { 2,  2000, 1900, 10,   300  }, 	// STOP
    { 10, 2700, 2600, 15,   300  }, 	// START
    { 1,  2700, 2300, 100,  1000 }, 	// PENDING
    { 3,  2700, 2300, 100,  1000 }, 	// ARMED
    { 1,  2700, 2690, 3000, 10   }  	// CRASH
};

// Melody
#define TEMPO_NOTE 200
note_t ram_ranch_solo[] = {
	{NOTE_D4, T_8},
	{NOTE_F4, T_8},
	{NOTE_E4, T_8},
	{NOTE_C4, T_8},
	{NOTE_D4, T_8D},
	{REST,    T_16},
	{NOTE_F4, T_4},

	{NOTE_F4, T_8},
	{NOTE_E4, T_8},
	{NOTE_C4, T_8},
	{NOTE_G4, T_8D},
	{REST,    T_16},
	{NOTE_E4, T_4},

	{NOTE_D4, T_8},
	{NOTE_F4, T_8},
	{NOTE_E4, T_8},
	{NOTE_C4, T_8},
	{NOTE_D4, T_8},
	{NOTE_F4, T_8},
	{NOTE_G4, T_4},

	{NOTE_E4, T_8},
	{NOTE_C4, T_8},
	{NOTE_E4, T_8D},
	{REST,    T_16},
	{NOTE_D4, T_2}
};


static void Buzzer_SetFreq(TIM_HandleTypeDef *htim, uint32_t channel, uint16_t freq) {
    if(freq <= 0) {
        HAL_TIM_PWM_Stop(htim, channel);

        return;
    }

    // <= 2700 Hz
    if(freq > BUZZER_MAX_FREQ) freq = BUZZER_MAX_FREQ;

    uint32_t arr = (TIMER_CLK_HZ / freq) - 1;
    __HAL_TIM_SET_AUTORELOAD(htim, arr);
    // 50% duty cycle
    __HAL_TIM_SET_COMPARE(htim, channel, (arr + 1) / 2);
}

static void Buzzer_PlayTone(buzzer_t *dev, uint16_t freq_hz, uint32_t duration) {
    Buzzer_SetFreq(dev->htim, dev->channel, freq_hz);
    HAL_TIM_PWM_Start(dev->htim, dev->channel);
    HAL_Delay(duration);
}

static void Buzzer_Bip(buzzer_t *dev, uint8_t count, uint32_t on_time, uint32_t off_time, uint16_t freq) {
	if(count == 0) return;

    for(uint8_t i = 0; i < count; i++) {
        Buzzer_PlayTone(dev, freq, on_time);
        HAL_TIM_PWM_Stop(dev->htim, dev->channel);

        if(i < count - 1) {
            HAL_Delay(off_time);
        }
    }
}

static void Buzzer_Pause(uint32_t ms) {
    HAL_Delay(ms);
}

void Buzzer_RunRoutine(buzzer_t *dev, buzzer_routines_t routine) {
    if(routine >= (sizeof(buzzParams)/sizeof(buzzParams[0]))) {
        return;
    }
    const buzzer_parametres_t parameters = buzzParams[routine];
    for(uint8_t bip = 0; bip < parameters.nbBips; bip++) {
        if(parameters.frequencyStart != parameters.frequencyEnd) {
            int step = (parameters.frequencyEnd > parameters.frequencyStart) ? 10 : -10;
            int currentFreq = parameters.frequencyStart;
            int targetFreq = parameters.frequencyEnd;

            int finished = 0;
            while(!finished) {
                Buzzer_PlayTone(dev, currentFreq, parameters.delayModulation);

                if(currentFreq == targetFreq) {
                    finished = 1;
                } else {
                    currentFreq += step;
                    if((step > 0 && currentFreq > targetFreq) || (step < 0 && currentFreq < targetFreq)) {
                        currentFreq = targetFreq;
                    }
                }
            }
        } else {
            Buzzer_PlayTone(dev, parameters.frequencyStart, parameters.delayModulation);
        }

        HAL_TIM_PWM_Stop(dev->htim, dev->channel);

        if(bip < (parameters.nbBips - 1)) {
            HAL_Delay(parameters.delayPause);
        }
    }
}

/*
 * Exemple of status report:
 * Battery: 12.0V (1200mV) -> bip / pause / bip bip / pause / bip bip bip bip bip bip bip bip bip bip x2 (10 bips = 0)
 * Pause 3s
 * Pyros [true, true, false, false] -> bip bip / pause / bip bip / pause / bip / pause / bip
 * Pause 3s
 * Max altitude (4502m): 4 short / pause / 5 short / pause / 1 long / pause / 2 short.
 * Pause 3s
 * Global state [OK]: bip
 * Pause 3s
 * Start Bip -> 5s biiiiip...
*/
void Buzzer_ReportStatus(buzzer_t *dev, uint16_t freq_hz, uint16_t battery_dv, bool pyros_continuity[4], int8_t global_state, const uint32_t flight_time_ms, const float max_altitude, bool valid) {
	if(freq_hz > BUZZER_MAX_FREQ) return;

    // Battery voltage
    uint16_t temp = battery_dv;
    uint8_t digits[5];
    uint8_t len = 0;

    do {
        digits[len++] = temp % 10;
        temp /= 10;
    } while(temp > 0);

    for(int i = len - 1; i >= 0; i--) {
        uint8_t d = digits[i];
        uint8_t bipCount = (d == 0) ? 10 : d;

        Buzzer_Bip(dev, bipCount, 250, 250, freq_hz);
        if(i > 0) Buzzer_Pause(1000);
    }

    Buzzer_Pause(3000);

    // Pyros continuity
    for(int i = 0; i < 4; i++) {
        if(pyros_continuity[i]) {
            Buzzer_Bip(dev, 2, 250, 250, freq_hz);
        } else {
            Buzzer_Bip(dev, 1, 250, 250, freq_hz);
        }
        if(i < 3) Buzzer_Pause(1000);
    }

    Buzzer_Pause(3000);

    // Max altitude last flight
    if(flight_time_ms > 0 && valid) {
		uint32_t alt_m = max_altitude;
		uint8_t thousands = alt_m / 1000;
		uint8_t hundreds  = (alt_m % 1000) / 100;

        if(thousands > 0) {
            Buzzer_Bip(dev, thousands, 800, 300, freq_hz);
            Buzzer_Pause(1000);
        }

        if(hundreds > 0) {
            Buzzer_Bip(dev, hundreds, 250, 250, freq_hz);
        }

        if(thousands == 0 && hundreds == 0) {
            uint8_t tens = (alt_m % 100) / 10;
            if(tens > 0) {
                Buzzer_Bip(dev, tens, 250, 250, freq_hz);
            } else {
                Buzzer_Bip(dev, 1, 1000, 250, freq_hz);
            }
        }
    } else {
        Buzzer_Bip(dev, 3, 100, 100, freq_hz);
    }

    Buzzer_Pause(3000);

    // Global state
    Buzzer_Bip(dev, abs(global_state), 250, 250, freq_hz);

    Buzzer_Pause(3000);

    // Start Bip
    if(global_state > -2) {
        Buzzer_Bip(dev, 1, 5000, 250, freq_hz);
    }
}

void Buzzer_StartPeriodicBip(buzzer_t *dev, uint16_t freq_hz, uint32_t on_time_ms, uint32_t off_time_ms) {
	if(freq_hz > BUZZER_MAX_FREQ) return;

    dev->inf_bip_active = true;
    dev->inf_bip_freq_hz = freq_hz;
    dev->inf_bip_on_time_ms = on_time_ms;
    dev->inf_bip_off_time_ms = off_time_ms;
    dev->inf_bip_state = true;
    dev->inf_bip_last_tick = HAL_GetTick();

    Buzzer_SetFreq(dev->htim, dev->channel, dev->inf_bip_freq_hz);
    HAL_TIM_PWM_Start(dev->htim, dev->channel);
}

void Buzzer_StopPeriodicBip(buzzer_t *dev) {
    dev->inf_bip_active = false;
    HAL_TIM_PWM_Stop(dev->htim, dev->channel);
}

void Buzzer_ProcessPeriodicBip(buzzer_t *dev) {
    if(!dev->inf_bip_active) {
        return;
    }

    uint32_t current_tick = HAL_GetTick();
    uint32_t target_delay = dev->inf_bip_state ? dev->inf_bip_on_time_ms : dev->inf_bip_off_time_ms;

    if((current_tick - dev->inf_bip_last_tick) >= target_delay) {
        dev->inf_bip_last_tick = current_tick;
        dev->inf_bip_state = !dev->inf_bip_state;

        if(dev->inf_bip_state) {
            Buzzer_SetFreq(dev->htim, dev->channel, dev->inf_bip_freq_hz);
            HAL_TIM_PWM_Start(dev->htim, dev->channel);
        } else {
            HAL_TIM_PWM_Stop(dev->htim, dev->channel);
        }
    }
}

// Melody
void Buzzer_PlayMelody(buzzer_t *dev, note_t *melody, uint16_t num_notes, uint8_t loop) {
    for(uint8_t j = 1; j < loop; j++) {
    	for(uint16_t i = 0; i < num_notes; i++) {
			if(melody[i].frequency == REST) {
				HAL_TIM_PWM_Stop(dev->htim, dev->channel);
				HAL_Delay(melody[i].duration);
			} else {
				uint32_t timer_clock = SystemCoreClock / (dev->htim->Init.Prescaler + 1);
				uint32_t arr_value = (timer_clock / melody[i].frequency) - 1;

				__HAL_TIM_SET_AUTORELOAD(dev->htim, arr_value);
				__HAL_TIM_SET_COMPARE(dev->htim, dev->channel, arr_value / 2);

				HAL_TIM_PWM_Start(dev->htim, dev->channel);

				HAL_Delay((melody[i].duration * 85) / 100);

				HAL_TIM_PWM_Stop(dev->htim, dev->channel);
				HAL_Delay((melody[i].duration * 15) / 100);
			}
		}
    	HAL_Delay(100);
    }
}
