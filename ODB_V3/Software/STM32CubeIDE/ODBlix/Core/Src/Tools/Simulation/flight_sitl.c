/*
 * flight_sitl.c
 * Simulateur SITL
 */

#include "Drivers/adxl382.h"
#include "Drivers/bno055.h"
#include "Drivers/hm11.h"
#include "Drivers/idefix.h"
#include "Drivers/l76lm33.h"
#include "Drivers/ltste682krkgwt.h"
#include "Utils/dwt.h"
#include "Drivers/LowLevel/kalman_nav.h"
#include "Drivers/ms5611.h"
#include "Drivers/pyros.h"
#include "Drivers/rfd900x.h"
#include "Drivers/smtb0927twr.h"
#include "Drivers/system_measurements.h"
#include "Drivers/w25q512jv.h"
#include "Drivers/mem2067.h"
#include "mavlink/odb_mavlink_v1/mavlink.h"
#include "Systems/flight_fsm.h"
#include "Protocols/odb_protocol.h"
#include "Systems/config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>
#include <locale.h>

// ==========================================
// VARIABLES GLOBALES (Système & Mocks)
// ==========================================
odb_data_t flight_data;
odb_stats_t flight_stats;

adxl382_t adxl382;
bno055_t bno055;
hm11_t hm11;
l76lm33_t l76lm33;
pyro_t pyros[4];
critical_led_t critical_led;
ms5611_t ms5611;
rfd900x_t rfd900x;
buzzer_t buzzer;
system_measurements_t system_measurements;
w25q_t w25q;
idefix_t idefix;
kalman_nav_t kalman_filter;

// CRITIQUE : Oblige le simulateur à lier la config de la vraie FSM
extern odb_config_t current_config;
char config_file_used[256] = "ÉCHEC : VALEURS PAR DÉFAUT (config.c)";

uint32_t simulated_ms = 0;
TIM_TypeDef dummy_tim5_regs;
TIM_HandleTypeDef htim5;

// Mocks DWT & Mémoire
uint32_t SystemCoreClock = 96000000;
uint32_t DWT_GetCycles(void) { return (uint32_t)(simulated_ms * 96000); }
int8_t W25Q_Read(w25q_t *dev, uint8_t *pData, uint32_t ReadAddr, uint32_t Size) { return -1; }
int8_t W25Q_EraseSector(w25q_t *dev, uint32_t SectorAddr) { return 0; }
int8_t W25Q_WritePage(w25q_t *dev, uint8_t *pData, uint32_t WriteAddr, uint32_t Size) { return 0; }

// ==========================================
// OUTILS D'ANALYSE DE VOL
// ==========================================
typedef struct { uint32_t time_ms; char type[64]; char detail[128]; } sim_event_t;
#define MAX_EVENTS 200
sim_event_t events[MAX_EVENTS];
int event_count = 0;

uint32_t launch_time_ms = 0, apogee_time_ms = 0, main_deploy_time_ms = 0, landing_time_ms = 0;
uint32_t first_drogue_fire_ms = 0, first_main_fire_ms = 0, pyro_arm_start_ms = 0;
float peak_altitude = 0.0f, max_alt_residual = 0.0f, max_vel_residual = 0.0f;
int unstable_kalman_windows = 0;
bool is_pyros_armed = false;
double sum_sq_err_z = 0.0;
uint32_t kalman_sample_count = 0;

const char* Get_GlobalState_Name(global_state_t state) {
    switch(state) { case STATE_PREFLIGHT: return "PREFLIGHT"; case STATE_ARMED: return "ARMED"; case STATE_INFLIGHT: return "INFLIGHT"; case STATE_POSTFLIGHT: return "POSTFLIGHT"; default: return "UNKNOWN"; }
}
const char* Get_SubState_Name(inflight_substate_t state) {
    switch(state) { case SUB_BOOST: return "BOOST"; case SUB_FAST: return "FAST"; case SUB_COAST: return "COAST"; case SUB_DROGUE: return "DROGUE"; case SUB_MAIN: return "MAIN"; case SUB_LANDED: return "LANDED"; default: return "-"; }
}
const char* Get_PyroRole_Name(pyro_role_t role) {
    if (role == PYRO_ROLE_MAIN) return "MAIN";
    if (role == PYRO_ROLE_DROGUE) return "DROGUE";
    if (role == PYRO_ROLE_MAIN_BACKUP) return "MAIN BKP";
    if (role == PYRO_ROLE_DROGUE_BACKUP) return "DROGUE BKP";
    return "NONE";
}

void Add_Event(const char* type, const char* detail) {
    if (event_count < MAX_EVENTS) { events[event_count].time_ms = simulated_ms; strncpy(events[event_count].type, type, 63); strncpy(events[event_count].detail, detail, 127); event_count++; }
}
void FormatTime(uint32_t ms, char* buf) {
    if (ms == 0) { strcpy(buf, "Not reached"); return; }
    snprintf(buf, 16, "%02d:%02d:%03d", ms / 60000, (ms % 60000) / 1000, ms % 1000);
}

// Mocks HAL & Pyros
uint32_t HAL_GetTick(void) { return simulated_ms; }
int8_t ODB_SetMissionState(odb_data_t *data, uint8_t mission_state) { return 0; }
void Logger_SaveStats(odb_stats_t *stats) {}
void Scheduler_RemoveTask(const char* task_name) {}
void Scheduler_SetActive(const char* task_name, bool state) {}
void Buzzer_StartPeriodicBip(buzzer_t *dev, uint16_t freq_hz, uint32_t on_time_ms, uint32_t off_time_ms) {}
void Buzzer_ProcessPeriodicBip(buzzer_t *dev) {}

pyros_state_t Pyro_Arming(system_measurements_t *measures, bool arming, bool is_test) {
    if (arming && !is_pyros_armed) {
    	Add_Event("pyros_arm_on", "pyros arming window opened");
    } else if (!arming && is_pyros_armed) {
    	Add_Event("pyros_arm_off", "pyros arming window closed");
    }
    is_pyros_armed = arming;

    return (pyros_state_t)arming;
}

bool Pyro_IsArmed(system_measurements_t *measures) {
    return is_pyros_armed;
}

void Logger_ExportToSD(odb_stats_t *stats) {}

uint8_t ODB_GetPyroStates(const odb_data_t *data) { return 0x0F; }

pyro_t* Pyro_GetByRole(pyro_role_t role) {
    static pyro_t pyros_mock[4] = {
        { .is_connected = true, .is_fire = false, .channel = PYRO_1 },
        { .is_connected = true, .is_fire = false, .channel = PYRO_2 },
        { .is_connected = true, .is_fire = false, .channel = PYRO_3 },
        { .is_connected = true, .is_fire = false, .channel = PYRO_4 }
    };

    // Recherche dynamique du pyro assigné à ce rôle dans la configuration
    for (int i = 0; i < 4; i++) {
        if (current_config.pyro_roles[i] == role) {
            return &pyros_mock[i];
        }
    }
    return NULL;
}

pyros_state_t Pyro_Fire(pyro_t *dev, system_measurements_t *measures) {
    if(dev && !dev->is_fire) {
        dev->is_fire = true;
        char msg[64], evt_type[64];
        pyro_role_t role = current_config.pyro_roles[dev->channel];

        snprintf(msg, sizeof(msg), "pyro%d fired", dev->channel + 1);
        // Ajout du rôle directement dans l'étiquette de l'événement
        snprintf(evt_type, sizeof(evt_type), "pyro%d (%s)", dev->channel + 1, Get_PyroRole_Name(role));
        Add_Event(evt_type, msg);

        // Validation FSM basée dynamiquement sur les rôles et non plus sur des canaux codés en dur
        if ((role == PYRO_ROLE_DROGUE || role == PYRO_ROLE_DROGUE_BACKUP) && first_drogue_fire_ms == 0) first_drogue_fire_ms = simulated_ms;
        if ((role == PYRO_ROLE_MAIN || role == PYRO_ROLE_MAIN_BACKUP) && first_main_fire_ms == 0) first_main_fire_ms = simulated_ms;
    }

    return PYRO_OK;
}

extern void FSM_Update(void);
extern global_state_t current_global_state;
extern inflight_substate_t current_substate;

// ==========================================
// LECTURE DE LA CONFIGURATION EXTERNE
// ==========================================
void Load_Config_From_File(bool is_sustainer) {
    const char* stage = is_sustainer ? "sustainer" : "booster";
    char paths[4][256];

    // 1er essai : Chemin absolu direct vers le dossier de GAUL
    snprintf(paths[0], 256, "C:/Users/gagno/OneDrive/Documents/ULaval/GAUL/ODB2/Ordinateur-de-bord/ODB_V3/Software/STM32CubeIDE/ODBlix/Core/Src/Tools/Simulation/Config/%s.cfg", stage);

    // Essais de secours (chemins relatifs standards)
    snprintf(paths[1], 256, "Config/%s.cfg", stage);
    snprintf(paths[2], 256, "Core/Src/Tools/Simulation/Config/%s.cfg", stage);
    snprintf(paths[3], 256, "../Core/Src/Tools/Simulation/Config/%s.cfg", stage);

    FILE *f = NULL;
    for(int i = 0; i < 4; i++) {
        f = fopen(paths[i], "r");
        if (f) {
            snprintf(config_file_used, sizeof(config_file_used), "%s", paths[i]);
            break; // Fichier trouvé !
        }
    }

    if (!f) {
        printf("\n[!] Attention: Fichier '%s.cfg' introuvable. Utilisation des defauts.\n", stage);
        return;
    }

    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (line[0] == '#' || line[0] == '\n' || line[0] == '\r') continue;

        char key[64] = {0}, value[64] = {0};
        if (sscanf(line, " %63[^= \t] = %63s", key, value) == 2) {
            if (strcmp(key, "odb_name") == 0) strncpy(current_config.odb_name, value, sizeof(current_config.odb_name)-1);
            else if (strcmp(key, "stage_role") == 0) current_config.stage_role = (uint8_t)atoi(value);
            else if (strcmp(key, "pyros_arming_failsafe_ms") == 0) current_config.pyros_arming_failsafe_ms = atoi(value);
            else if (strcmp(key, "apogee_failsafe_ms") == 0) current_config.apogee_failsafe_ms = atoi(value);
            else if (strcmp(key, "main_deploy_altitude_threshold_m") == 0) current_config.main_deploy_altitude_threshold_m = atof(value);
            else if (strcmp(key, "acc_z_launch_threshold") == 0) current_config.acc_z_launch_threshold = atof(value);
            else if (strcmp(key, "boost_phase_v_threshold") == 0) current_config.boost_phase_v_threshold = atof(value);
            else if (strcmp(key, "apogee_detect_v_threshold") == 0) current_config.apogee_detect_v_threshold = atof(value);
            else if (strcmp(key, "drogue_fire_attempt_max_nb") == 0) current_config.drogue_fire_attempt_max_nb = atoi(value);
            else if (strcmp(key, "main_fire_attempt_max_nb") == 0) current_config.main_fire_attempt_max_nb = atoi(value);
            else if (strcmp(key, "fire_attempt_delay_ms") == 0) current_config.fire_attempt_delay_ms = atoi(value);
            else if (strcmp(key, "landing_detect_v_threshold") == 0) current_config.landing_detect_v_threshold = atof(value);
            else if (strcmp(key, "landing_detect_threshold_ms") == 0) current_config.landing_detect_threshold_ms = atoi(value);
            else if (strcmp(key, "buzzer_report_tone_hz") == 0) current_config.buzzer_report_tone_hz = atoi(value);
            else if (strcmp(key, "min_needed_pyro_nb") == 0) current_config.min_needed_pyro_nb = atoi(value);

            // Décodage des rôles pyros depuis le fichier .cfg
            else if (strcmp(key, "pyro1_role") == 0) {
                if (strstr(value, "MAIN_BKP")) current_config.pyro_roles[0] = PYRO_ROLE_MAIN_BACKUP;
                else if (strstr(value, "DROGUE_BKP")) current_config.pyro_roles[0] = PYRO_ROLE_DROGUE_BACKUP;
                else if (strstr(value, "MAIN")) current_config.pyro_roles[0] = PYRO_ROLE_MAIN;
                else if (strstr(value, "DROGUE")) current_config.pyro_roles[0] = PYRO_ROLE_DROGUE;
            }
            else if (strcmp(key, "pyro2_role") == 0) {
                if (strstr(value, "MAIN_BKP")) current_config.pyro_roles[1] = PYRO_ROLE_MAIN_BACKUP;
                else if (strstr(value, "DROGUE_BKP")) current_config.pyro_roles[1] = PYRO_ROLE_DROGUE_BACKUP;
                else if (strstr(value, "MAIN")) current_config.pyro_roles[1] = PYRO_ROLE_MAIN;
                else if (strstr(value, "DROGUE")) current_config.pyro_roles[1] = PYRO_ROLE_DROGUE;
            }
            else if (strcmp(key, "pyro3_role") == 0) {
                if (strstr(value, "MAIN_BKP")) current_config.pyro_roles[2] = PYRO_ROLE_MAIN_BACKUP;
                else if (strstr(value, "DROGUE_BKP")) current_config.pyro_roles[2] = PYRO_ROLE_DROGUE_BACKUP;
                else if (strstr(value, "MAIN")) current_config.pyro_roles[2] = PYRO_ROLE_MAIN;
                else if (strstr(value, "DROGUE")) current_config.pyro_roles[2] = PYRO_ROLE_DROGUE;
            }
            else if (strcmp(key, "pyro4_role") == 0) {
                if (strstr(value, "MAIN_BKP")) current_config.pyro_roles[3] = PYRO_ROLE_MAIN_BACKUP;
                else if (strstr(value, "DROGUE_BKP")) current_config.pyro_roles[3] = PYRO_ROLE_DROGUE_BACKUP;
                else if (strstr(value, "MAIN")) current_config.pyro_roles[3] = PYRO_ROLE_MAIN;
                else if (strstr(value, "DROGUE")) current_config.pyro_roles[3] = PYRO_ROLE_DROGUE;
            }
        }
    }
    fclose(f);
    printf(">>> Configuration chargee avec succes depuis : %s\n", config_file_used);
}

// ==========================================
// BOUCLE PRINCIPALE SITL
// ==========================================
int main(int argc, char** argv) {
    setlocale(LC_ALL, "C");
    char* filename = (argc > 1) ? argv[1] : "booster_data.csv";

    char config_path[256];
    if (argc > 2) {
        strncpy(config_path, argv[2], sizeof(config_path));
    } else {
        bool is_sustainer = (strstr(filename, "sustainer") != NULL);
        snprintf(config_path, sizeof(config_path), "Config/%s.cfg", is_sustainer ? "sustainer" : "booster");
    }

    char out_path[512] = "rapport_vol.html";
    if (argc > 0) {
        char *last_sep = strrchr(argv[0], '/');
        if (!last_sep) last_sep = strrchr(argv[0], '\\');
        if (last_sep != NULL) snprintf(out_path, sizeof(out_path), "%.*srapport_vol.html", (int)(last_sep - argv[0] + 1), argv[0]);
    }

    FILE *csv = fopen(filename, "r");
    FILE *html = fopen(out_path, "w");
    if (!csv || !html) { printf("Erreur : Impossible d'ouvrir les fichiers.\n"); return -1; }

    Config_LoadDefaults();
    bool is_sustainer = (strstr(filename, "sustainer") != NULL);
	Load_Config_From_File(is_sustainer);

	htim5.Instance = &dummy_tim5_regs;

    KalmanNav_Init(&kalman_filter, 0.0f, (float[]){0.0f}, 1);

    char line[512];
    while (fgets(line, sizeof(line), csv)) { if (line[0] != '#') break; }

    global_state_t prev_global = STATE_PREFLIGHT;
    inflight_substate_t prev_sub = SUB_BOOST;
    bool verdict_pass = true;
    uint32_t previous_tim5 = 0;

    // Variables pour le calcul de la théorie
    float max_raw_alt = -9999.0f;
    uint32_t theo_apogee_ms = 0;
    uint32_t theo_main_ms = 0;

    fprintf(html, "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Diagnostic SITL - ODBlix</title>");
    fprintf(html, "<script src='https://cdn.jsdelivr.net/npm/chart.js'></script>");
    fprintf(html, "<script src='https://cdn.jsdelivr.net/npm/chartjs-plugin-annotation@2.1.0/dist/chartjs-plugin-annotation.min.js'></script>");
    fprintf(html, "<style>body{font-family:Segoe UI,sans-serif;margin:20px;background:#f0f2f5;} .container{max-width:1200px;margin:auto;} .card{background:#fff;padding:20px;border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,0.1);margin-bottom:20px;} h1,h2{color:#2c3e50;margin-top:0;} table{width:100%%;border-collapse:collapse;margin-bottom:15px;} th,td{padding:8px 12px;text-align:left;border-bottom:1px solid #ddd;} th{background:#f8f9fa;width:30%%;} .pass{color:#27ae60;font-weight:bold;} .fail{color:#c0392b;font-weight:bold;} .warn{color:#e67e22;font-weight:bold;}</style></head><body><div class='container'>\n");

    fprintf(html, "<script>\nconst l_time=[], l_alt=[], l_vel=[], l_raw_alt=[], l_raw_vel=[], l_state=[], l_sub=[], l_err=[], l_err_v=[], l_mach_lock=[];\n");

    for (float t_pre = -5.0f; t_pre < 0.0f; t_pre += 0.1f) {
		simulated_ms = 0;
		flight_data.altitude_msl_m = 0.0f;
		flight_data.highg_acc_vertical = 0.0f;
		flight_data.pressure_pa = 101325.0f;

		KalmanNav_Predict(&kalman_filter, 9.81f);
		KalmanNav_Update(&kalman_filter, 0.0f, false);
		flight_data.kalman_z = kalman_filter.z;
		flight_data.kalman_v = kalman_filter.v;

		FSM_Update();

		fprintf(html, "l_time.push(%.3f); l_alt.push(%.2f); l_vel.push(%.2f); l_raw_alt.push(%.2f); l_raw_vel.push(%.2f); l_state.push(%d); l_sub.push(%d); l_err.push(0.0); l_err_v.push(0.0); l_mach_lock.push(0);\n",
				t_pre, flight_data.kalman_z, flight_data.kalman_v, 0.0f, 0.0f, current_global_state, current_substate);
	}

    do {
        float t, raw_z_m, raw_vel, acc_z;
        int parsed = sscanf(line, "%f;%f;%f;%f", &t, &raw_z_m, &raw_vel, &acc_z);
        if (parsed < 4) { parsed = sscanf(line, "%f,%f,%f,%f", &t, &raw_z_m, &raw_vel, &acc_z); }

        if (parsed >= 4) {
            simulated_ms = (uint32_t)(t * 1000.0f);

            // Recherche des temps théoriques dans le CSV
            if (raw_z_m > max_raw_alt) {
                max_raw_alt = raw_z_m;
                if (simulated_ms > 1000) {
                    theo_apogee_ms = simulated_ms;
                }

                if (raw_z_m > current_config.main_deploy_altitude_threshold_m) {
                    theo_main_ms = 0;
                }
            } else if (raw_z_m <= current_config.main_deploy_altitude_threshold_m &&
                       theo_main_ms == 0 &&
                       max_raw_alt > current_config.main_deploy_altitude_threshold_m &&
                       raw_vel < -5.0f) {
                theo_main_ms = simulated_ms;
            }

            uint32_t absolute_tim5 = (uint32_t)(t * 1000000.0f);
            uint32_t delta_tim5 = absolute_tim5 - previous_tim5;
            previous_tim5 = absolute_tim5;
            htim5.Instance->CNT += delta_tim5;

            flight_data.altitude_msl_m = raw_z_m;
            flight_data.highg_acc_vertical = acc_z;
            flight_data.imu_acc_vertical = acc_z;
            flight_data.highg_acc_z = acc_z;
            flight_data.pressure_pa = 101325.0f * powf((1.0f - 0.0000225577f * raw_z_m), 5.25588f);
            ms5611.raw_pressure = (uint32_t)(flight_data.pressure_pa * 100.0f);

            bool mach_lock_active = (flight_data.event_states & FLAG_MACH_LOCK_ENABLED);

            KalmanNav_Predict(&kalman_filter, acc_z);
            KalmanNav_Update(&kalman_filter, raw_z_m, mach_lock_active);
            flight_data.kalman_z = kalman_filter.z;
            flight_data.kalman_v = kalman_filter.v;

            float res_z = fabs(flight_data.kalman_z - raw_z_m);
            float res_v = fabs(flight_data.kalman_v - raw_vel);
            sum_sq_err_z += (res_z * res_z);
            kalman_sample_count++;
            if (res_z > max_alt_residual) max_alt_residual = res_z;
            if (res_v > max_vel_residual) max_vel_residual = res_v;
            if (res_z > 50.0f) unstable_kalman_windows++;
            if (flight_data.kalman_z > peak_altitude) peak_altitude = flight_data.kalman_z;

            FSM_Update();

            if (current_global_state != prev_global) {
                char msg[128]; snprintf(msg, sizeof(msg), "%s \u2192 %s", Get_GlobalState_Name(prev_global), Get_GlobalState_Name(current_global_state));
                Add_Event("transition", msg);
                if (current_global_state == STATE_INFLIGHT) launch_time_ms = simulated_ms;
                if (current_global_state == STATE_POSTFLIGHT) landing_time_ms = simulated_ms;
                prev_global = current_global_state;
            }

            if (current_global_state == STATE_INFLIGHT && current_substate != prev_sub) {
                char msg[128]; snprintf(msg, sizeof(msg), "INFLIGHT/%s \u2192 INFLIGHT/%s", Get_SubState_Name(prev_sub), Get_SubState_Name(current_substate));
                Add_Event("transition", msg);
                if (current_substate == SUB_DROGUE) { apogee_time_ms = simulated_ms; char apo_msg[64]; snprintf(apo_msg, sizeof(apo_msg), "apogee latched at %.2f m", flight_data.kalman_z); Add_Event("apogee", apo_msg); }
                if (current_substate == SUB_MAIN) { main_deploy_time_ms = simulated_ms; char main_msg[64]; snprintf(main_msg, sizeof(main_msg), "main deploy latched at %.2f m", flight_data.kalman_z); Add_Event("main_deploy", main_msg); }
                prev_sub = current_substate;
            }

            fprintf(html, "l_time.push(%.3f); l_alt.push(%.2f); l_vel.push(%.2f); l_raw_alt.push(%.2f); l_raw_vel.push(%.2f); l_state.push(%d); l_sub.push(%d); l_err.push(%.2f); l_err_v.push(%.2f); l_mach_lock.push(%d);\n",
                    t, flight_data.kalman_z, flight_data.kalman_v, raw_z_m, raw_vel, current_global_state, current_substate, res_z, res_v, mach_lock_active ? 1 : 0);
        }
    } while (fgets(line, sizeof(line), csv));

    float last_t = simulated_ms / 1000.0f;
    // Geler l'altitude au sol mesurée à la fin du CSV pour forcer la décélération mathématique
    float landed_altitude = flight_data.kalman_z;

	for (float t_post = last_t + 0.1f; t_post < last_t + 40.0f; t_post += 0.1f) {
		simulated_ms = (uint32_t)(t_post * 1000.0f);

        uint32_t absolute_tim5 = (uint32_t)(t_post * 1000000.0f);
        uint32_t delta_tim5 = absolute_tim5 - previous_tim5;
        previous_tim5 = absolute_tim5;
        htim5.Instance->CNT += delta_tim5;

		flight_data.altitude_msl_m = landed_altitude;
		flight_data.highg_acc_vertical = 9.81f;
        flight_data.imu_acc_vertical = 9.81f;
        flight_data.highg_acc_z = 9.81f;

		KalmanNav_Predict(&kalman_filter, 9.81f);
		KalmanNav_Update(&kalman_filter, landed_altitude, false);
		flight_data.kalman_z = kalman_filter.z;
		flight_data.kalman_v = kalman_filter.v;

		FSM_Update();

		// Tracking des transitions post-vol
		if (current_global_state != prev_global) {
            char msg[128]; snprintf(msg, sizeof(msg), "%s \u2192 %s", Get_GlobalState_Name(prev_global), Get_GlobalState_Name(current_global_state));
            Add_Event("transition", msg);
            if (current_global_state == STATE_POSTFLIGHT) landing_time_ms = simulated_ms;
            prev_global = current_global_state;
        }
		if (current_substate != prev_sub) { prev_sub = current_substate; }

		fprintf(html, "l_time.push(%.3f); l_alt.push(%.2f); l_vel.push(%.2f); l_raw_alt.push(%.2f); l_raw_vel.push(%.2f); l_state.push(%d); l_sub.push(%d); l_err.push(0.0); l_err_v.push(0.0); l_mach_lock.push(0);\n",
				t_post, flight_data.kalman_z, flight_data.kalman_v, landed_altitude, 0.0f, current_global_state, current_substate);
	}

    float rmse_z = kalman_sample_count > 0 ? sqrt(sum_sq_err_z / kalman_sample_count) : 0.0f;
    char findings_html[2048] = "";
    char err[256];

    // Vérification Théorique du Drogue (Apogée)
    if (theo_apogee_ms > 0) {
        int32_t diff_drogue = (int32_t)first_drogue_fire_ms - (int32_t)theo_apogee_ms;
        if (first_drogue_fire_ms == 0) {
            strcat(findings_html, "<tr><td><span class='fail'>FAIL</span></td><td>Drogue NEVER fired.</td></tr>");
            verdict_pass = false;
        } else if (abs(diff_drogue) > 3000) { // Tolérance de 3 secondes
            snprintf(err, sizeof(err), "<tr><td><span class='fail'>FAIL</span></td><td>Drogue fired at %.1fs (Theoretical: %.1fs). Diff: %.1fs</td></tr>", first_drogue_fire_ms/1000.0f, theo_apogee_ms/1000.0f, diff_drogue/1000.0f);
            strcat(findings_html, err);
            verdict_pass = false;
        } else {
            snprintf(err, sizeof(err), "<tr><td><span class='pass'>PASS</span></td><td>Drogue fired correctly at %.1fs (Theo: %.1fs).</td></tr>", first_drogue_fire_ms/1000.0f, theo_apogee_ms/1000.0f);
            strcat(findings_html, err);
        }
    }

    // Vérification Théorique du Main (450m)
    if (max_raw_alt > current_config.main_deploy_altitude_threshold_m) {
        int32_t diff_main = (int32_t)first_main_fire_ms - (int32_t)theo_main_ms;
        if (first_main_fire_ms == 0) {
            strcat(findings_html, "<tr><td><span class='fail'>FAIL</span></td><td>Main NEVER fired.</td></tr>");
            verdict_pass = false;
        } else if (abs(diff_main) > 3000) { // Tolérance de 3 secondes
            snprintf(err, sizeof(err), "<tr><td><span class='fail'>FAIL</span></td><td>Main fired at %.1fs (Theoretical: %.1fs). Diff: %.1fs</td></tr>", first_main_fire_ms/1000.0f, theo_main_ms/1000.0f, diff_main/1000.0f);
            strcat(findings_html, err);
            verdict_pass = false;
        } else {
            snprintf(err, sizeof(err), "<tr><td><span class='pass'>PASS</span></td><td>Main fired correctly at %.1fs (Theo: %.1fs).</td></tr>", first_main_fire_ms/1000.0f, theo_main_ms/1000.0f);
            strcat(findings_html, err);
        }
    }

    // Vérification de l'estimateur de vol
    if (rmse_z > 20.0f || unstable_kalman_windows > 100) {
        snprintf(err, sizeof(err), "<tr><td><span class='fail'>FAIL</span></td><td>Kalman unstable: RMSE %.2f m.</td></tr>", rmse_z);
        strcat(findings_html, err);
        verdict_pass = false;
    }

    if (verdict_pass) {
        strcat(findings_html, "<tr><td><span class='pass'>SUCCESS</span></td><td>All pyros triggered within theoretical limits.</td></tr>");
    }

    char t_launch[16], t_apogee[16], t_main[16], t_landing[16], t_drogue_lat[16], t_main_lat[16];
    FormatTime(launch_time_ms, t_launch); FormatTime(apogee_time_ms, t_apogee); FormatTime(main_deploy_time_ms, t_main); FormatTime(landing_time_ms, t_landing);
    FormatTime(first_drogue_fire_ms > 0 ? (first_drogue_fire_ms - apogee_time_ms) : 0, t_drogue_lat);
    FormatTime(first_main_fire_ms > 0 ? (first_main_fire_ms - main_deploy_time_ms) : 0, t_main_lat);

    fprintf(html, "const annotationsList = {\n");
	int ann_id = 0;
	for(int i = 0; i < event_count; i++) {
		if(strstr(events[i].type, "pyro") || strstr(events[i].type, "apogee") || strstr(events[i].type, "main_deploy")) {
			char time_str[16];
			snprintf(time_str, sizeof(time_str), "%.3f", events[i].time_ms / 1000.0f);
			for(int j=0; j<strlen(time_str); j++) if(time_str[j] == ',') time_str[j] = '.';

			// Échelonnement sur 8 niveaux différents.
			// La valeur négative fait monter l'étiquette le long de la ligne (de -20px à -300px).
			int y_adjust = -((ann_id % 8) * 40 + 20);

			// ÉTIQUETTES VERTES (rgba(46, 204, 113)) POUR LES ÉVÉNEMENTS FSM SIMULÉS
			fprintf(html, "  line%d: { type: 'line', xMin: %s, xMax: %s, borderColor: 'rgba(46, 204, 113, 0.8)', borderWidth: 2, borderDash: [4, 4], label: { content: '%s', display: true, position: 'start', yAdjust: %d, backgroundColor: 'rgba(46, 204, 113, 0.9)', font: {size: 11}, padding: 4 } },\n",
					ann_id, time_str, time_str, events[i].type, y_adjust);
			ann_id++;
		}
	}

    // NOUVEAU: AJOUT DES ÉTIQUETTES THÉORIQUES EN GRIS FONCÉ (Ardoise)
    if (theo_apogee_ms > 0) {
        char time_str[16];
        snprintf(time_str, sizeof(time_str), "%.3f", theo_apogee_ms / 1000.0f);
        for(int j=0; j<strlen(time_str); j++) if(time_str[j] == ',') time_str[j] = '.';
        int y_adjust = -((ann_id % 8) * 40 + 20);

        fprintf(html, "  line%d: { type: 'line', xMin: %s, xMax: %s, borderColor: 'rgba(52, 73, 94, 0.8)', borderWidth: 2, borderDash: [2, 2], label: { content: 'Theo: Apogée', display: true, position: 'start', yAdjust: %d, backgroundColor: 'rgba(52, 73, 94, 0.9)', font: {size: 11}, padding: 4 } },\n",
                ann_id, time_str, time_str, y_adjust);
        ann_id++;
    }

    if (theo_main_ms > 0) {
        char time_str[16];
        snprintf(time_str, sizeof(time_str), "%.3f", theo_main_ms / 1000.0f);
        for(int j=0; j<strlen(time_str); j++) if(time_str[j] == ',') time_str[j] = '.';
        int y_adjust = -((ann_id % 8) * 40 + 20);

        fprintf(html, "  line%d: { type: 'line', xMin: %s, xMax: %s, borderColor: 'rgba(52, 73, 94, 0.8)', borderWidth: 2, borderDash: [2, 2], label: { content: 'Theo: Main', display: true, position: 'start', yAdjust: %d, backgroundColor: 'rgba(52, 73, 94, 0.9)', font: {size: 11}, padding: 4 } },\n",
                ann_id, time_str, time_str, y_adjust);
        ann_id++;
    }

	fprintf(html, "};\n</script>\n");

    // ==========================================
    // GÉNÉRATION DES TABLEAUX HTML
    // ==========================================

    // Tableau 1: Summary
    fprintf(html, "<div class='card'><h1>Flight Data Dashboard</h1><h2>Summary</h2><table><tr><th>Verdict</th><td><span class='%s'>%s</span></td></tr>", verdict_pass ? "pass" : "fail", verdict_pass ? "PASS" : "FAIL");
    fprintf(html, "<tr><th>Profile</th><td>%s</td></tr><tr><th>Launch</th><td>%s</td></tr><tr><th>Apogee</th><td>%s</td></tr><tr><th>Main deploy</th><td>%s</td></tr><tr><th>Landing</th><td>%s</td></tr>", filename, t_launch, t_apogee, t_main, t_landing);
    fprintf(html, "<tr><th>Final state</th><td>%s / %s</td></tr><tr><th>Peak altitude</th><td>%.2f m</td></tr><tr><th>Kalman RMSE (Altitude)</th><td><b>%.3f m</b></td></tr>", Get_GlobalState_Name(current_global_state), Get_SubState_Name(current_substate), peak_altitude, rmse_z);
	fprintf(html, "</table></div>");

	// Tableau 2: ODB Configuration
	fprintf(html, "<div class='card'><h2>ODB Configuration (Simulation)</h2><table>");
	fprintf(html, "<tr><th>Source Config</th><td><b><span class='%s'>%s</span></b></td></tr>", strstr(config_file_used, "ÉCHEC") ? "fail" : "pass", config_file_used);

	fprintf(html, "<tr><th>Nom ODB</th><td>%s</td></tr>", current_config.odb_name);
    fprintf(html, "<tr><th>Rôle Étage</th><td>%s</td></tr>", (current_config.stage_role == STAGE_ROLE_SUSTAINER ? "SUSTAINER" : "BOOSTER"));
	fprintf(html, "<tr><th>Armement Pyro (ms)</th><td>%d</td></tr>", current_config.pyros_arming_failsafe_ms);
	fprintf(html, "<tr><th>Failsafe Apogée (ms)</th><td>%d</td></tr>", current_config.apogee_failsafe_ms);
	fprintf(html, "<tr><th>Altitude Main (m)</th><td>%.1f</td></tr>", current_config.main_deploy_altitude_threshold_m);
	fprintf(html, "<tr><th>Seuil Accel (m/s2)</th><td>%.2f</td></tr>", current_config.acc_z_launch_threshold);

    // Ajout de l'affichage des rôles Pyro configurés
    fprintf(html, "<tr><th>Rôles Pyros</th><td>P1: <b>%s</b> &nbsp;|&nbsp; P2: <b>%s</b> &nbsp;|&nbsp; P3: <b>%s</b> &nbsp;|&nbsp; P4: <b>%s</b></td></tr>",
        Get_PyroRole_Name(current_config.pyro_roles[0]),
        Get_PyroRole_Name(current_config.pyro_roles[1]),
        Get_PyroRole_Name(current_config.pyro_roles[2]),
        Get_PyroRole_Name(current_config.pyro_roles[3]));

	fprintf(html, "</table></div>");

	// Tableau 3: Findings
	fprintf(html, "<div class='card'><h2>Findings</h2><table>%s</table></div>", findings_html);

	// SCRIPT DE SYNCHRONISATION ROBUSTE
	fprintf(html, "<script>\nlet isSyncing = false;\nfunction syncScroll(source) {\n");
	fprintf(html, "  if (isSyncing) return;\n  isSyncing = true;\n");
	fprintf(html, "  let scrollers = document.querySelectorAll('.scroll-sync');\n");
	fprintf(html, "  scrollers.forEach(s => { if(s !== source) s.scrollLeft = source.scrollLeft; });\n");
	fprintf(html, "  setTimeout(() => { isSyncing = false; }, 10);\n"); // Retire le verrou après 10ms
	fprintf(html, "}\n");

    // NOUVEAU SCRIPT : Fonction updateZoom
    fprintf(html, "function updateZoom(width) {\n");
    fprintf(html, "  document.querySelectorAll('.chart-wrapper').forEach(w => w.style.width = width + 'px');\n");
    fprintf(html, "  document.getElementById('zoomVal').innerText = (width/3000).toFixed(1) + 'x';\n");
    fprintf(html, "}\n</script>\n");

    // ==========================================
    // CONTENEURS DES GRAPHIQUES (Modifiés pour le Zoom)
    // ==========================================

	// Télémétrie (Hauteur 500px)
	fprintf(html, "<div class='card'><h2>Télémétrie & Événements</h2>");
    // Barre d'outils avec le Slider de Zoom
    fprintf(html, "<div style='margin-bottom: 15px; display: flex; align-items: center; gap: 15px; flex-wrap: wrap;'>");
	fprintf(html, "  <div><button onclick='toggleUnits(\"metric\")' style='padding: 6px 12px; cursor: pointer;'>Métrique (m, m/s)</button> ");
	fprintf(html, "  <button onclick='toggleUnits(\"imperial\")' style='padding: 6px 12px; cursor: pointer;'>Impérial (ft, ft/s)</button></div>");
    fprintf(html, "  <div style='display: flex; align-items: center; gap: 10px; background: #f8f9fa; padding: 5px 15px; border-radius: 5px; border: 1px solid #ddd;'>");
    fprintf(html, "    <label for='zoomSlider' style='font-weight: bold; font-size: 14px;'>Zoom Horizontal :</label>");
    fprintf(html, "    <input type='range' id='zoomSlider' min='1000' max='15000' value='3000' step='500' oninput='updateZoom(this.value)' style='width: 200px;'>");
    fprintf(html, "    <span id='zoomVal' style='font-weight: bold; font-family: monospace;'>1.0x</span>");
    fprintf(html, "  </div>");
    fprintf(html, "</div>");

	fprintf(html, "<div class='scroll-sync' onscroll='syncScroll(this)' style='width: 100%%; overflow-x: auto;'><div class='chart-wrapper' style='width: 3000px; height: 500px;'><canvas id='chartVol'></canvas></div></div></div>");

	// FSM (Hauteur 150px)
	fprintf(html, "<div class='card'><h2>FSM Timeline (Déroulement des États)</h2>");
	fprintf(html, "<div class='scroll-sync' onscroll='syncScroll(this)' style='width: 100%%; overflow-x: auto;'><div class='chart-wrapper' style='width: 3000px; height: 150px;'><canvas id='chartFSM'></canvas></div></div></div>");

	// Erreur Kalman Alt (Hauteur 250px)
	fprintf(html, "<div class='card'><h2>Erreur Absolue (Kalman) - Altitude</h2>");
	fprintf(html, "<div class='scroll-sync' onscroll='syncScroll(this)' style='width: 100%%; overflow-x: auto;'><div class='chart-wrapper' style='width: 3000px; height: 250px;'><canvas id='chartKalman'></canvas></div></div></div>");

	// Erreur Kalman Vel (Hauteur 250px)
	fprintf(html, "<div class='card'><h2>Erreur Absolue (Kalman) - Vitesse</h2>");
	fprintf(html, "<div class='scroll-sync' onscroll='syncScroll(this)' style='width: 100%%; overflow-x: auto;'><div class='chart-wrapper' style='width: 3000px; height: 250px;'><canvas id='chartKalmanVel'></canvas></div></div></div>");

    // ==========================================
    // SCRIPTS JAVASCRIPT : CHARTS & SYNC
    // ==========================================
	fprintf(html, "<script>\nChart.register(window['chartjs-plugin-annotation']);\n");

	// Instanciation Télémétrie avec les courbes RAW, KALMAN et le fond MACH LOCK
	fprintf(html, "window.chartVol = new Chart(document.getElementById('chartVol').getContext('2d'), { type: 'line', data: { labels: l_time, datasets: ["
                  "{ label: 'Altitude Brute (m)', data: l_raw_alt, borderColor: 'rgba(52, 152, 219, 0.4)', yAxisID: 'y1', pointRadius: 0, borderDash: [5, 5], borderWidth: 1 }, "
                  "{ label: 'Altitude Kalman (m)', data: l_alt, borderColor: '#9b59b6', yAxisID: 'y1', pointRadius: 0, borderWidth: 2 }, " // Mauve
                  "{ label: 'Vitesse Brute (m/s)', data: l_raw_vel, borderColor: 'rgba(230, 126, 34, 0.4)', yAxisID: 'y2', pointRadius: 0, borderDash: [5, 5], borderWidth: 1 }, "
                  "{ label: 'Vitesse Kalman (m/s)', data: l_vel, borderColor: '#e74c3c', yAxisID: 'y2', pointRadius: 0, borderWidth: 2 }, " // Rouge
                  "{ label: 'Mach Lock', data: l_mach_lock.map(v => v ? 100 : 0), borderColor: 'rgba(241, 196, 15, 0.5)', backgroundColor: 'rgba(241, 196, 15, 0.15)', fill: true, yAxisID: 'y3', pointRadius: 0, stepped: true, borderWidth: 1 } "
                  "]}, options: { maintainAspectRatio: false, plugins: { annotation: { annotations: annotationsList } }, scales: { "
                  "x: { type: 'linear', min: l_time[0], max: l_time[l_time.length-1], ticks: { stepSize: 5 } }, "
                  "y1: { type: 'linear', position: 'left', title: {display: true, text: 'Altitude (m)'} }, "
                  "y2: { type: 'linear', position: 'right', grid: { drawOnChartArea: false }, title: {display: true, text: 'Vitesse (m/s)'} }, "
                  "y3: { type: 'linear', position: 'right', display: false, min: 0, max: 100 } "
                  "} } });\n");

	fprintf(html, "const globalNames = ['PREFLIGHT', 'ARMED', 'INFLIGHT', 'POSTFLIGHT'];\nconst subNames = ['BOOST', 'FAST', 'COAST', 'DROGUE', 'MAIN', 'LANDED'];\n");
	fprintf(html, "const globalBg = ['rgba(149, 165, 166, 0.8)', 'rgba(241, 196, 15, 0.8)', 'rgba(46, 204, 113, 0.8)', 'rgba(52, 152, 219, 0.8)'];\nconst globalBd = ['#7f8c8d', '#f39c12', '#27ae60', '#2980b9'];\n");
	fprintf(html, "const subBg = ['rgba(231, 76, 60, 0.8)', 'rgba(230, 126, 34, 0.8)', 'rgba(26, 188, 156, 0.8)', 'rgba(52, 152, 219, 0.8)', 'rgba(155, 89, 182, 0.8)', 'rgba(46, 204, 113, 0.8)'];\nconst subBd = ['#c0392b', '#d35400', '#16a085', '#2980b9', '#8e44ad', '#27ae60'];\n");
	fprintf(html, "function buildBlocks(times, values, names, yLabel) { let blocks = []; if(times.length === 0) return blocks; let startT = times[0]; let currentVal = values[0]; for(let i = 1; i < times.length; i++) { if(values[i] !== currentVal) { blocks.push({ x: [startT, times[i]], y: yLabel, stateName: names[currentVal], v: currentVal }); startT = times[i]; currentVal = values[i]; } } blocks.push({ x: [startT, times[times.length-1]], y: yLabel, stateName: names[currentVal], v: currentVal }); return blocks; }\n");
	fprintf(html, "const globalBlocks = buildBlocks(l_time, l_state, globalNames, 'État Global');\nconst subBlocks = buildBlocks(l_time, l_sub, subNames, 'Sous-État');\n");

	// Instanciation FSM
	fprintf(html, "window.chartFSM = new Chart(document.getElementById('chartFSM').getContext('2d'), { type: 'bar', data: { datasets: [ { label: 'Global State', data: globalBlocks, backgroundColor: (ctx) => ctx.raw ? globalBg[ctx.raw.v] : '#000', borderColor: (ctx) => ctx.raw ? globalBd[ctx.raw.v] : '#000', borderWidth: 2, borderSkipped: false, barPercentage: 0.7 }, { label: 'Sub State', data: subBlocks, backgroundColor: (ctx) => ctx.raw ? subBg[ctx.raw.v] : '#000', borderColor: (ctx) => ctx.raw ? subBd[ctx.raw.v] : '#000', borderWidth: 2, borderSkipped: false, barPercentage: 0.7 } ] }, options: { maintainAspectRatio: false, indexAxis: 'y', responsive: true, scales: { x: { type: 'linear', min: l_time[0], max: l_time[l_time.length-1], ticks: { stepSize: 5 } } }, plugins: { tooltip: { callbacks: { label: function(ctx) { let b = ctx.raw; return b.stateName + ' : ' + b.x[0].toFixed(2) + 's \\u2192 ' + b.x[1].toFixed(2) + 's'; } } } } } });\n");

	// Instanciation Kalman Alt
	fprintf(html, "window.chartKalman = new Chart(document.getElementById('chartKalman').getContext('2d'), { type: 'line', data: { labels: l_time, datasets: [{ label: 'Erreur Altitude (m)', data: l_err, borderColor: '#e74c3c', backgroundColor: 'rgba(231, 76, 60, 0.2)', fill: true, pointRadius: 0, borderWidth: 1 }]}, options: { maintainAspectRatio: false, scales: { x: { type: 'linear', min: l_time[0], max: l_time[l_time.length-1], ticks: { stepSize: 5 } }, y: { title: { display: true, text: 'Erreur (m)' } } } } });\n");

	// Instanciation Kalman Vel
	fprintf(html, "window.chartKalmanVel = new Chart(document.getElementById('chartKalmanVel').getContext('2d'), { type: 'line', data: { labels: l_time, datasets: [{ label: 'Erreur Vitesse (m/s)', data: l_err_v, borderColor: '#8e44ad', backgroundColor: 'rgba(142, 68, 173, 0.2)', fill: true, pointRadius: 0, borderWidth: 1 }]}, options: { maintainAspectRatio: false, scales: { x: { type: 'linear', min: l_time[0], max: l_time[l_time.length-1], ticks: { stepSize: 5 } }, y: { title: { display: true, text: 'Erreur (m/s)' } } } } });\n");

	// Script JS pour la conversion d'unités
	fprintf(html, "let currentUnit = 'metric';\n");
	fprintf(html, "const raw_alt_metric = [...l_raw_alt]; const raw_vel_metric = [...l_raw_vel]; const alt_metric = [...l_alt]; const vel_metric = [...l_vel]; const err_metric = [...l_err]; const err_v_metric = [...l_err_v];\n");
	fprintf(html, "function toggleUnits(unit) {\n");
	fprintf(html, "    if(currentUnit === unit) return;\n");
	fprintf(html, "    currentUnit = unit;\n");
	fprintf(html, "    const multiplier = (unit === 'imperial') ? 3.28084 : 1.0;\n");
	fprintf(html, "    for(let i=0; i<l_alt.length; i++) {\n");
	fprintf(html, "        window.chartVol.data.datasets[0].data[i] = raw_alt_metric[i] * multiplier;\n");
	fprintf(html, "        window.chartVol.data.datasets[1].data[i] = alt_metric[i] * multiplier;\n");
	fprintf(html, "        window.chartVol.data.datasets[2].data[i] = raw_vel_metric[i] * multiplier;\n");
	fprintf(html, "        window.chartVol.data.datasets[3].data[i] = vel_metric[i] * multiplier;\n");
	fprintf(html, "        window.chartKalman.data.datasets[0].data[i] = err_metric[i] * multiplier;\n");
	fprintf(html, "        window.chartKalmanVel.data.datasets[0].data[i] = err_v_metric[i] * multiplier;\n");
	fprintf(html, "    }\n");
	fprintf(html, "    window.chartVol.options.scales.y1.title.text = unit === 'imperial' ? 'Altitude (ft)' : 'Altitude (m)';\n");
	fprintf(html, "    window.chartVol.options.scales.y2.title.text = unit === 'imperial' ? 'Vitesse (ft/s)' : 'Vitesse (m/s)';\n");
	fprintf(html, "    window.chartVol.data.datasets[0].label = unit === 'imperial' ? 'Altitude Brute (ft)' : 'Altitude Brute (m)';\n");
	fprintf(html, "    window.chartVol.data.datasets[1].label = unit === 'imperial' ? 'Altitude Kalman (ft)' : 'Altitude Kalman (m)';\n");
	fprintf(html, "    window.chartVol.data.datasets[2].label = unit === 'imperial' ? 'Vitesse Brute (ft/s)' : 'Vitesse Brute (m/s)';\n");
	fprintf(html, "    window.chartVol.data.datasets[3].label = unit === 'imperial' ? 'Vitesse Kalman (ft/s)' : 'Vitesse Kalman (m/s)';\n");
	fprintf(html, "    window.chartKalman.options.scales.y.title.text = unit === 'imperial' ? 'Erreur (ft)' : 'Erreur (m)';\n");
	fprintf(html, "    window.chartKalman.data.datasets[0].label = unit === 'imperial' ? 'Erreur Altitude (ft)' : 'Erreur Altitude (m)';\n");
	fprintf(html, "    window.chartKalmanVel.options.scales.y.title.text = unit === 'imperial' ? 'Erreur Vitesse (ft/s)' : 'Erreur Vitesse (m/s)';\n");
	fprintf(html, "    window.chartKalmanVel.data.datasets[0].label = unit === 'imperial' ? 'Erreur Vitesse (ft/s)' : 'Erreur Vitesse (m/s)';\n");
	fprintf(html, "    window.chartVol.update(); window.chartKalman.update(); window.chartKalmanVel.update();\n");
	fprintf(html, "}\n");

    // Script JS de Synchronisation de Scroll
    fprintf(html, "const scrollers = document.querySelectorAll('.scroll-sync');\n");
    fprintf(html, "let activeScroller = null;\n");
    fprintf(html, "scrollers.forEach(scroller => {\n");
    fprintf(html, "  scroller.addEventListener('mouseenter', () => { activeScroller = scroller; });\n");
    fprintf(html, "  scroller.addEventListener('touchstart', () => { activeScroller = scroller; }, {passive: true});\n");
    fprintf(html, "  scroller.addEventListener('scroll', () => {\n");
    fprintf(html, "    if (activeScroller !== scroller) return;\n");
    fprintf(html, "    scrollers.forEach(s => {\n");
    fprintf(html, "      if (s !== activeScroller) s.scrollLeft = activeScroller.scrollLeft;\n");
    fprintf(html, "    });\n");
    fprintf(html, "  });\n");
    fprintf(html, "});\n");

	fprintf(html, "</script>\n</div></body></html>\n");

	fclose(csv);
	fclose(html);
    printf("\n>>> Rapport CI genere : %s\n", out_path);
    return 0;
}
