/*
 * w25q512jv.c
 *
 * Created on: 12 avr. 2026
 * Author: SamLol12
 */

#include "Drivers/w25q512jveim.h"
#include <string.h>


#define W25Q_CMD_RESET_ENABLE               0x66
#define W25Q_CMD_RESET_MEMORY               0x99
#define W25Q_CMD_READ_ID                    0x9F      // JEDEC ID
#define W25Q_CMD_WRITE_ENABLE               0x06
#define W25Q_CMD_WRITE_DISABLE              0x04

#define W25Q_CMD_READ_STATUS_REG1           0x05
#define W25Q_CMD_READ_STATUS_REG2           0x35
#define W25Q_CMD_READ_STATUS_REG3           0x15
#define W25Q_CMD_WRITE_STATUS_REG1          0x01
#define W25Q_CMD_WRITE_STATUS_REG2          0x31
#define W25Q_CMD_WRITE_STATUS_REG3          0x11

#define W25Q_CMD_ENTER_4B_MODE              0xB7
#define W25Q_CMD_EXIT_4B_MODE               0xE9

#define W25Q_CMD_FAST_READ_QUAD_IO_4B       0xEC
#define W25Q_CMD_QUAD_PAGE_PROGRAM_4B       0x34
#define W25Q_CMD_SECTOR_ERASE_4B            0x21      // Erase 4Ko
#define W25Q_CMD_BLOCK_ERASE_64K_4B         0xDC      // Erase 64Ko
#define W25Q_CMD_CHIP_ERASE                 0xC7      // Erase all

#define W25Q_CMD_DEEP_POWER_DOWN            0xB9
#define W25Q_CMD_RELEASE_POWER_DOWN         0xAB

#define W25Q_SR1_BUSY                       0x01
#define W25Q_SR1_WEL                        0x02
#define W25Q_SR2_QE                         0x02      // Quad enable (Bit 1, Status Reg 2)

#define W25Q_SELFTEST_ADDR   				(W25Q512_FLASH_SIZE - W25Q512_SECTOR_SIZE)
#define W25Q_SELFTEST_SIZE   				(W25Q512_PAGE_SIZE * 2U)

#define W25Q_TIMEOUT                        5000
#define W25Q_ERASE_ALL_TIMEOUT              1000000


static QSPI_CommandTypeDef W25Q_MakeCommand(uint32_t instruction, uint32_t address_mode, uint32_t address, uint32_t data_mode, uint32_t dummy_cycles, uint32_t data_length) {
    QSPI_CommandTypeDef sCommand = {0};

    sCommand.InstructionMode    = QSPI_INSTRUCTION_1_LINE;
    sCommand.Instruction        = instruction;
    sCommand.AddressMode        = address_mode;
    sCommand.AddressSize        = QSPI_ADDRESS_32_BITS;
    sCommand.Address            = address;
    sCommand.AlternateByteMode  = QSPI_ALTERNATE_BYTES_NONE;
    sCommand.AlternateBytesSize = QSPI_ALTERNATE_BYTES_8_BITS;
    sCommand.AlternateBytes     = 0x00;
    sCommand.DataMode           = data_mode;
    sCommand.DummyCycles        = dummy_cycles;
    sCommand.NbData             = data_length;
    sCommand.DdrMode            = QSPI_DDR_MODE_DISABLE;
    sCommand.DdrHoldHalfCycle   = QSPI_DDR_HHC_ANALOG_DELAY;
    sCommand.SIOOMode           = QSPI_SIOO_INST_EVERY_CMD;

    return sCommand;
}

static int8_t W25Q_WaitForReady(QSPI_HandleTypeDef *hqspi, uint32_t timeout_ms) {
    uint32_t tickstart = HAL_GetTick();
    while (W25Q_IsBusy(hqspi)) {
        if ((HAL_GetTick() - tickstart) > timeout_ms) {
            return -1;
        }
    }
    return 0;
}

static int8_t W25Q_WriteEnable(QSPI_HandleTypeDef *hqspi) {
    QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_WRITE_ENABLE, QSPI_ADDRESS_NONE, 0xFFFFFFFF, QSPI_DATA_NONE, 0, 0);
    if(HAL_QSPI_Command(hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;
    
    return 0; // success
}

static int8_t W25Q_Enter4ByteMode(QSPI_HandleTypeDef *hqspi) {
    QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_ENTER_4B_MODE, QSPI_ADDRESS_NONE, 0xFFFFFFFF, QSPI_DATA_NONE, 0, 0);
    if(HAL_QSPI_Command(hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;

    return W25Q_WaitForReady(hqspi, W25Q_TIMEOUT);
}

static int8_t W25Q_EnableQuadMode(QSPI_HandleTypeDef *hqspi) {
    QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_READ_STATUS_REG2, QSPI_ADDRESS_NONE, 0xFFFFFFFF, QSPI_DATA_1_LINE, 0, 1);
    if(HAL_QSPI_Command(hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;

    uint8_t status = 0;
    if(HAL_QSPI_Receive(hqspi, &status, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;
    
    if((status & W25Q_SR2_QE) != 0) {
        return 0; // Quad mode already enabled
    }

    // Enable Quad mode
    status |= W25Q_SR2_QE;
    if(W25Q_WriteEnable(hqspi) != 0) return -1;

    sCommand.Instruction = W25Q_CMD_WRITE_STATUS_REG2;
    if(HAL_QSPI_Command(hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;
    if(HAL_QSPI_Transmit(hqspi, &status, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;

    return W25Q_WaitForReady(hqspi, W25Q_TIMEOUT);
}

static int8_t W25Q_Reset(QSPI_HandleTypeDef *hqspi) {
    QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_RESET_ENABLE, QSPI_ADDRESS_NONE, 0xFFFFFFFF, QSPI_DATA_NONE, 0, 0);
    if(HAL_QSPI_Command(hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;

    sCommand.Instruction = W25Q_CMD_RESET_MEMORY;
    if(HAL_QSPI_Command(hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;

    HAL_Delay(10);

    return 0; // success
}

static uint32_t W25Q_GetID(QSPI_HandleTypeDef *hqspi) {
    QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_READ_ID, QSPI_ADDRESS_NONE, 0xFFFFFFFF, QSPI_DATA_1_LINE, 0, 3);
    if(HAL_QSPI_Command(hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;

    uint8_t id_buf[3];
    if(HAL_QSPI_Receive(hqspi, id_buf, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;

    return ((id_buf[0] << 16) | (id_buf[1] << 8) | id_buf[2]);
}

bool W25Q_IsBusy(QSPI_HandleTypeDef *hqspi) {
    QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_READ_STATUS_REG1, QSPI_ADDRESS_NONE, 0xFFFFFFFF, QSPI_DATA_1_LINE, 0, 1);
    uint8_t status = 0;

    if(HAL_QSPI_Command(hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return true;
    if(HAL_QSPI_Receive(hqspi, &status, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return true;

    return ((status & W25Q_SR1_BUSY) != 0);
}

int8_t W25Q_Init(w25q_t *dev) {
	// Reset
	if(W25Q_Reset(dev->hqspi) != 0) return -1;
	if(W25Q_WaitForReady(dev->hqspi, 100) != 0) return -1;

	// Check ID
    uint32_t id = W25Q_GetID(dev->hqspi);
	if(id != W25Q512_JEDEC_ID) return -1;

	if(W25Q_EnableQuadMode(dev->hqspi) != 0) return -1;
	if(W25Q_Enter4ByteMode(dev->hqspi) != 0) return -1;

	return 0; // success
}

int8_t W25Q_Read(w25q_t *dev, uint8_t* data, uint32_t read_addr, uint32_t size) {
    QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_FAST_READ_QUAD_IO_4B, QSPI_ADDRESS_4_LINES, read_addr, QSPI_DATA_4_LINES, 4, size);
    sCommand.AlternateByteMode  = QSPI_ALTERNATE_BYTES_4_LINES;
    sCommand.AlternateBytesSize = QSPI_ALTERNATE_BYTES_8_BITS;
    sCommand.AlternateBytes     = 0xFF;

    if(HAL_QSPI_Command(dev->hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;
    if(HAL_QSPI_Receive(dev->hqspi, data, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;

    return 0; // success
}

int8_t W25Q_WritePage(w25q_t *dev, uint8_t* data, uint32_t write_addr, uint32_t size) {
    uint32_t current_addr = write_addr;
    uint32_t current_size;
    while(size > 0) {
        current_size = W25Q512_PAGE_SIZE - (current_addr % W25Q512_PAGE_SIZE);
        if(current_size > size) current_size = size;

        if(W25Q_WriteEnable(dev->hqspi) != 0) return -1;
        
        QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_QUAD_PAGE_PROGRAM_4B, QSPI_ADDRESS_1_LINE, current_addr, QSPI_DATA_4_LINES, 0, current_size);
        if(HAL_QSPI_Command(dev->hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;
        if(HAL_QSPI_Transmit(dev->hqspi, data, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;
        if(W25Q_WaitForReady(dev->hqspi, W25Q_TIMEOUT) != 0) return -1;

        current_addr += current_size;
        data += current_size;
        size -= current_size;
    }

    return 0; // success
}

int8_t W25Q_WritePageNoWait(w25q_t *dev, uint8_t* data, uint32_t write_addr, uint32_t size) {
    if(W25Q_WriteEnable(dev->hqspi) != 0) return -1;

    QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_QUAD_PAGE_PROGRAM_4B, QSPI_ADDRESS_1_LINE, write_addr, QSPI_DATA_4_LINES, 0, size);
    
    if(HAL_QSPI_Command(dev->hqspi, &sCommand, 10) != HAL_OK) return -1;
    if(HAL_QSPI_Transmit(dev->hqspi, data, 10) != HAL_OK) return -1;

    return 0;
}

int8_t W25Q_EraseSector(w25q_t *dev, uint32_t sector_addr) {
    if(W25Q_WriteEnable(dev->hqspi) != 0) return -1;

    QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_SECTOR_ERASE_4B, QSPI_ADDRESS_1_LINE, sector_addr, QSPI_DATA_NONE, 0, 0);
    if(HAL_QSPI_Command(dev->hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;

    return W25Q_WaitForReady(dev->hqspi, W25Q_ERASE_ALL_TIMEOUT);
}

int8_t W25Q_EraseBlock(w25q_t *dev, uint32_t block_addr) {
    if(W25Q_WriteEnable(dev->hqspi) != 0) return -1;

    QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_BLOCK_ERASE_64K_4B, QSPI_ADDRESS_1_LINE, block_addr, QSPI_DATA_NONE, 0, 0);
    if(HAL_QSPI_Command(dev->hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;

    return W25Q_WaitForReady(dev->hqspi, W25Q_ERASE_ALL_TIMEOUT);
}

int8_t W25Q_EraseChip(w25q_t *dev) {
    if(W25Q_WriteEnable(dev->hqspi) != 0) return -1;

    QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_CHIP_ERASE, QSPI_ADDRESS_NONE, 0xFFFFFFFF, QSPI_DATA_NONE, 0, 0);
    if(HAL_QSPI_Command(dev->hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;

    return W25Q_WaitForReady(dev->hqspi, W25Q_ERASE_ALL_TIMEOUT);
}

int8_t W25Q_SetMemoryMappedMode(w25q_t *dev, bool enable) {
    if(enable) {
        QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(W25Q_CMD_FAST_READ_QUAD_IO_4B, QSPI_ADDRESS_4_LINES, 0xFFFFFFFF, QSPI_DATA_4_LINES, 4, 0);
        sCommand.AlternateByteMode  = QSPI_ALTERNATE_BYTES_4_LINES;
        sCommand.AlternateBytesSize = QSPI_ALTERNATE_BYTES_8_BITS;
        sCommand.AlternateBytes     = 0xFF;

        QSPI_MemoryMappedTypeDef sMemMappedCfg = {0};
        sMemMappedCfg.TimeOutActivation = QSPI_TIMEOUT_COUNTER_DISABLE;
        sMemMappedCfg.TimeOutPeriod     = 0;

        if(HAL_QSPI_MemoryMapped(dev->hqspi, &sCommand, &sMemMappedCfg) != HAL_OK) return -1;
    } 
    else {
        if(HAL_QSPI_Abort(dev->hqspi) != HAL_OK) return -1;
    }

    return 0; // success
}

int8_t W25Q_SetDeepPowerDown(w25q_t *dev, bool enable) {
    uint8_t instruction = enable ? W25Q_CMD_DEEP_POWER_DOWN : W25Q_CMD_RELEASE_POWER_DOWN;
    
    QSPI_CommandTypeDef sCommand = W25Q_MakeCommand(instruction, QSPI_ADDRESS_NONE, 0xFFFFFFFF, QSPI_DATA_NONE, 0, 0);
    if(HAL_QSPI_Command(dev->hqspi, &sCommand, HAL_QSPI_TIMEOUT_DEFAULT_VALUE) != HAL_OK) return -1;
    HAL_Delay(1);

    return 0; // success
}
