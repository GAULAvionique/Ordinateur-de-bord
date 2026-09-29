/*
 * altitude_trend.c
 *
 * Barometric altitude trend estimator.
 */

#include "Drivers/LowLevel/altitude_trend.h"
#include <math.h>
#include <stddef.h>

#define ALTITUDE_TREND_STEP_THRESHOLD 10U // Minimal variation step
#define ALTITUDE_TREND_MIN_COUNT      2U  // Minimal consecutive evaluation before confirmed trend


// Abstraction
void AltitudeTrend_Init(altitude_trend_t *trend) {
    AltitudeTrend_Reset(trend);
}

void AltitudeTrend_Reset(altitude_trend_t *trend) {
    if(!trend) {
        return;
    }

    trend->sample_index     = 0;
    trend->sample_count     = 0;
    trend->ascent_count     = 0;
    trend->descent_count    = 0;
    trend->state            = ALTITUDE_TREND_STABLE;
}

/*
 * Updates the altitude trend using a circular buffer of ALTITUDE_TREND_BUFFER_SIZE barometric
 * measurements. The (ALTITUDE_TREND_BUFFER_SIZE - 1) differences between consecutive samples are counted
 * to detect a majority of ascending or descending variations. A trend is
 * confirmed after two consecutive evaluations and reset when the altitude
 * is invalid or the signal is unstable.
 */
void AltitudeTrend_Update(altitude_trend_t *trend, float altitude) {
    if(!trend) {
        return;
    }

    if(!isfinite(altitude)) {
        AltitudeTrend_Reset(trend);
        return;
    }

    trend->samples[trend->sample_index] = altitude;
    trend->sample_index = (trend->sample_index + 1U) % ALTITUDE_TREND_BUFFER_SIZE;
    if(trend->sample_count < ALTITUDE_TREND_BUFFER_SIZE) {
        trend->sample_count++;
    }

    if(trend->sample_count < ALTITUDE_TREND_BUFFER_SIZE) {
        trend->state = ALTITUDE_TREND_STABLE;
        return;
    }

    uint8_t ascent_steps = 0;
    uint8_t descent_steps = 0;
    for(uint8_t i = 0; i < ALTITUDE_TREND_BUFFER_SIZE - 1U; i++) {
        uint8_t index_1 = (trend->sample_index + i) % ALTITUDE_TREND_BUFFER_SIZE;
        uint8_t index_2 = (trend->sample_index + i + 1U) % ALTITUDE_TREND_BUFFER_SIZE;

        if(trend->samples[index_1] < trend->samples[index_2]) {
            ascent_steps++;
        } else if(trend->samples[index_1] > trend->samples[index_2]) {
            descent_steps++;
        }
    }

    if(ascent_steps >= ALTITUDE_TREND_STEP_THRESHOLD) {
        if(trend->ascent_count < 2U * ALTITUDE_TREND_MIN_COUNT) {
            trend->ascent_count++;
        }
    } else {
        trend->ascent_count = 0;
    }

    if(descent_steps >= ALTITUDE_TREND_STEP_THRESHOLD) {
        if(trend->descent_count < 2U * ALTITUDE_TREND_MIN_COUNT) {
            trend->descent_count++;
        }
    } else {
        trend->descent_count = 0;
    }

    if(trend->ascent_count >= ALTITUDE_TREND_MIN_COUNT) {
        trend->state = ALTITUDE_TREND_ASCENDING;
    } else if(trend->descent_count >= ALTITUDE_TREND_MIN_COUNT) {
        trend->state = ALTITUDE_TREND_DESCENDING;
    } else {
        trend->state = ALTITUDE_TREND_STABLE;
    }
}
