/*
 * mem2067.c
 *
 *  Created on: 26 juillet 2026
 *      Author: SamLol12
 */


#include "Drivers/MEM2067.h"

static FATFS fs;
FIL active_file;
uint8_t file_is_open = 0;


mem2067_state_t MEM2067_Mount(void) {
	FRESULT fresult = f_mount(&fs, "", 1);
	if(fresult != FR_OK) {
		return MEM2067_ERROR;
	}

	return MEM2067_OK;
}

mem2067_state_t MEM2067_OpenFile(const char *filename) {
    if(file_is_open) return MEM2067_ERROR;

    FRESULT fresult = f_open(&active_file, filename, FA_OPEN_ALWAYS | FA_WRITE);
    if(fresult != FR_OK) {
        return MEM2067_ERROR;
    }

    f_lseek(&active_file, f_size(&active_file));
    file_is_open = 1;

    return MEM2067_OK;
}

mem2067_state_t MEM2067_Sync(void) {
    if(!file_is_open) return MEM2067_ERROR;

    if(f_sync(&active_file) != FR_OK) {
        return MEM2067_ERROR;
    }

    return MEM2067_OK;
}

mem2067_state_t MEM2067_CloseFile(void) {
    if(!file_is_open) return MEM2067_ERROR;

    f_close(&active_file);
    file_is_open = 0;

    return MEM2067_OK;
}

char *MEM2067_Read(const char *filename) {
    static char buffer[128];
    static FIL read_fil;

    memset(buffer, 0, sizeof(buffer));

    FRESULT fresult = f_open(&read_fil, filename, FA_READ);
    if(fresult == FR_OK) {
        f_gets(buffer, sizeof(buffer), &read_fil);
        f_close(&read_fil);
    }
    return buffer;
}

void MEM2067_Unmount(void) {
    f_mount(NULL, "", 1);
}

void MEM2067_Infos(mem2067_t *dev) {
    FATFS *pfr;
    DWORD fre_clust;
    f_getfree("", &fre_clust, &pfr);
    dev->total_space = (uint32_t)((pfr->n_fatent - 2) * pfr->csize * 0.5);
    dev->free_space = (uint32_t)(fre_clust * pfr->csize * 0.5);
}

const char* FATFS_ErrorToString(FRESULT result) {
    switch(result) {
        case FR_OK: return "Succeeded\r\n";
        case FR_DISK_ERR: return "A hard error occurred in the low level disk I/O layer\r\n";
        case FR_INT_ERR: return "Assertion failed\r\n";
        case FR_NOT_READY: return "The physical drive cannot work\r\n";
        case FR_NO_FILE: return "Could not find the file\r\n";
        case FR_NO_PATH: return "Could not find the path\r\n";
        case FR_INVALID_NAME: return "The path name format is invalid\r\n";
        case FR_DENIED: return "Access denied due to prohibited access or directory full\r\n";
        case FR_EXIST: return "Access denied due to prohibited access\r\n";
        case FR_INVALID_OBJECT: return "The file/directory object is invalid\r\n";
        case FR_WRITE_PROTECTED: return "The physical drive is write protected\r\n";
        case FR_INVALID_DRIVE: return "The logical drive number is invalid\r\n";
        case FR_NOT_ENABLED: return "The volume has no work area\r\n";
        case FR_NO_FILESYSTEM: return "There is no valid FAT volume\r\n";
        case FR_MKFS_ABORTED: return "The f_mkfs() aborted due to any parameter error\r\n";
        case FR_TIMEOUT: return "Could not get a grant to access the volume within defined period\r\n";
        case FR_LOCKED: return "The operation is rejected according to the file sharing policy\r\n";
        case FR_NOT_ENOUGH_CORE: return "LFN working buffer could not be allocated\r\n";
        case FR_TOO_MANY_OPEN_FILES: return "Number of open files > _FS_SHARE\r\n";
        case FR_INVALID_PARAMETER: return "Given parameter is invalid\r\n";
        default: return "Unknown error\r\n";
    }
}
