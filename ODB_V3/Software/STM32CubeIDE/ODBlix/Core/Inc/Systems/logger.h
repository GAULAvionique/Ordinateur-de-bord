/*
 * logger.h
 *
 *  Created on: 8 mai 2026
 *      Author: SamLol12
 */

#ifndef INC_SYSTEMS_LOGGER_H_
#define INC_SYSTEMS_LOGGER_H_


#include "Drivers/w25q512jveim.h"
#include <odb.h>
#include <stdint.h>
#include <stdbool.h>

#define LOG_BUFFER_SIZE				    512 				// 400 ms (max wait erase sector w25q) / TASK_LOGGER_FREQ_MS = 20 frames + security
#define LOGGER_PREBUFFER_SIZE		    LOG_BUFFER_SIZE
#define LOGGER_PREBUFFER_DURATION_MS	5000U
#define LOGGER_MIN_FLIGHT_SPACE  	    (5 * 1024 * 1024) 	// 5Mo
#define LOGGER_DECIMATION_SIZE		    4000U				// samples
#define LOGGER_MAX_ALLOWED_ADDRESS	    FLASH_CONFIG_START_ADDRESS
#define LOGGER_MAGIC_HEADER			    0x48454144U			// HEAD
#define LOGGER_DATA_MAGIC_NUMBER	    0x44415441U			// DATA
#define LOGGER_STATS_MAGIC_NUMBER	    0x53544154U			// STAT


typedef enum {
    LOGGER_SUCCESS = 0,
    LOGGER_ERROR_FLASH_WRITE = -1,
    LOGGER_ERROR_FLASH_ERASE = -2,
} logger_error_t;

typedef struct __attribute__((packed)) {
    uint32_t magic_number;   // To identify the start of a valid header
    uint32_t flight_id;      // Incremented each time
    uint32_t time_date;
    uint32_t metadata_rsv;   // Reserved for future use (new functionality)
} logger_header_t;

typedef struct __attribute__((packed)) {
    uint32_t magic_number;  // To identify the start of a valid data packet
    odb_data_t data;		// The actual ODB data
} logger_data_t;

typedef struct __attribute__((packed)) {
    uint32_t magic_number;  // To identify the start of a valid stats packet
    odb_stats_t stats;      // The actual ODB stats
} logger_stats_t;

typedef struct __attribute__((packed)) {
    uint32_t magic_number; 	// To identify the start of a valid flight config packet
    odb_config_t config; 	// The actual ODB config
} logger_config_t;


int8_t Logger_Init(void);

void Logger_PushData(odb_data_t *new_data);
void Logger_Enable(bool enable);
bool Logger_IsLogging(void);
void Logger_Task(void);
void Logger_SaveStats(const odb_stats_t *stats);
void Logger_FlushRemaining(void);
uint32_t Logger_GetCurrentFlightAddress(void);
uint32_t Logger_GetCurrentFlightId(void);
bool Logger_GetFlightHeaderAddressById(uint32_t flight_id, uint32_t *header_addr);
void Logger_StartReadingFlight(uint32_t header_addr, uint32_t *cursor);
bool Logger_ReadNextData(uint32_t *cursor, odb_data_t *out_data);
bool Logger_StartReadingFlightById(uint32_t flight_id, uint32_t *cursor);
void Logger_StartReadingStats(uint32_t *cursor);
bool Logger_ReadNextStats(uint32_t *cursor, odb_stats_t *out_stats);
const odb_stats_t* Logger_GetLastFlightStats(void);
bool Logger_ReadFlightConfig(uint32_t header_addr, odb_config_t *out_config);
void Logger_ExportToSD(const odb_stats_t *stats);
//void Logger_DumpAllToSD(void);

bool Logger_Erase(void);


#endif /* INC_SYSTEMS_LOGGER_H_ */
