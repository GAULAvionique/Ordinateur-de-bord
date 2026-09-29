/*
 * altitude_trend.h
 *
 *  Created on: 28 septembre 2026
 *      Author: SamLol12
 */

#ifndef INC_DRIVERS_LOWLEVEL_ALTITUDE_TREND_H_
#define INC_DRIVERS_LOWLEVEL_ALTITUDE_TREND_H_

#include <stdint.h>


#define ALTITUDE_TREND_BUFFER_SIZE    16U


typedef enum {
    ALTITUDE_TREND_STABLE,
    ALTITUDE_TREND_ASCENDING,
    ALTITUDE_TREND_DESCENDING
} altitude_trend_state_t;

typedef struct {
    float                   samples[ALTITUDE_TREND_BUFFER_SIZE];
    uint8_t                 sample_index;
    uint8_t                 sample_count;
    uint8_t                 ascent_count;
    uint8_t                 descent_count;
    altitude_trend_state_t  state;
} altitude_trend_t;


void AltitudeTrend_Init(altitude_trend_t *trend);

void AltitudeTrend_Reset(altitude_trend_t *trend);
void AltitudeTrend_Update(altitude_trend_t *trend, float altitude);

#endif /* INC_DRIVERS_LOWLEVEL_ALTITUDE_TREND_H_ */
