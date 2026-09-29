/*
 * w25q512jv.h
 *
 * Created on: 12 avr. 2026
 * Author: SamLol12
 */

#ifndef INC_DRIVERS_W25Q512JVEIM_H_
#define INC_DRIVERS_W25Q512JVEIM_H_

#include "stm32f4xx_hal.h"
#include <stdbool.h>


#define W25Q512_JEDEC_ID                    0xEF7020

#define W25Q512_FLASH_SIZE                  0x4000000 // 512 MBits => 64 MBytes
#define W25Q512_SECTOR_SIZE                 0x1000    // 4 Ko
#define W25Q512_BLOCK_SIZE                  0x10000   // 64 Ko
#define W25Q512_PAGE_SIZE                   0x100     // 256 octets

#define W25Q512_FLASH_SIZE_BYTE         	((uint32_t)67108864)
#define FLASH_SECTOR_SIZE_BYTE          	((uint32_t)4096)

typedef struct {
	QSPI_HandleTypeDef *hqspi;
} w25q_t;


int8_t W25Q_Init(w25q_t *dev);

int8_t W25Q_Read(w25q_t *dev, uint8_t* pData, uint32_t read_addr, uint32_t size);
int8_t W25Q_WritePage(w25q_t *dev, uint8_t* pData, uint32_t write_addr, uint32_t size);
int8_t W25Q_WritePageNoWait(w25q_t *dev, uint8_t* pData, uint32_t write_addr, uint32_t size);
int8_t W25Q_EraseSector(w25q_t *dev, uint32_t sector_addr);
int8_t W25Q_EraseBlock(w25q_t *dev, uint32_t block_addr);
int8_t W25Q_EraseChip(w25q_t *dev);
bool W25Q_IsBusy(QSPI_HandleTypeDef *hqspi);
int8_t W25Q_SetMemoryMappedMode(w25q_t *dev, bool enable);    // If enable is true, the flash will be mapped to the QSPI memory space, allowing for direct read access. If false, the flash will be in indirect mode, requiring commands to read/write.
int8_t W25Q_SetDeepPowerDown(w25q_t *dev, bool enable);       // If enable is true, the flash will enter deep power down mode, reducing power consumption. In this mode, the flash will not respond to any command except for the release from deep power down command. If false, the flash will exit deep power down mode and be ready for normal operation. Incompatible with memory mapped mode.

#endif /* INC_DRIVERS_W25Q512JVEIM_H_ */
