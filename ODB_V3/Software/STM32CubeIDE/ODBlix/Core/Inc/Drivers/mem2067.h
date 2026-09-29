/*
 * mem2067.h
 *
 *  Created on: 19 juin 2026
 *      Author: SamLol12
 */

#ifndef INC_DRIVERS_MEM2067_H_
#define INC_DRIVERS_MEM2067_H_

#include <fatfs.h>
#include "Drivers/LowLevel/fatfs_sd.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

extern FIL active_file;
extern uint8_t file_is_open;

// Timestamp + f_printf on SD card
#define MEM2067_Log(...) \
    (file_is_open ? \
        ((f_printf(&active_file, "%lu\t", HAL_GetTick()) > 0 && f_printf(&active_file, __VA_ARGS__) > 0) \
            ? MEM2067_OK : MEM2067_ERROR) : MEM2067_ERROR)

typedef enum {
	MEM2067_OK,
	MEM2067_ERROR
} mem2067_state_t;

typedef struct {
	uint32_t total_space;
	uint32_t free_space;
} mem2067_t;

mem2067_state_t MEM2067_Mount(void);
void MEM2067_Unmount(void);
void MEM2067_Infos(mem2067_t *dev);

mem2067_state_t MEM2067_OpenFile(const char *filename);
mem2067_state_t MEM2067_Sync(void);
mem2067_state_t MEM2067_CloseFile(void);
char *MEM2067_Read(const char *filename);

// Debug
const char* FATFS_ErrorToString(FRESULT result);

#endif /* INC_DRIVERS_MEM2067_H_ */
