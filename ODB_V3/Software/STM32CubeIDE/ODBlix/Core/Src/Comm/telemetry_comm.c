/*
 * telemetry_comm.c
 *
 *  Created on: 14 juin 2026
 *      Author: SamLol12
 */


#include "Comm/telemetry_comm.h"


static void Telemetry_TransmitMessage(rfd900x_t *rfd_dev, const mavlink_message_t *msg) {
    if(!rfd_dev) return;

    uint8_t local_tx_buffer[MAVLINK_MAX_PACKET_LEN];
    uint16_t len = mavlink_msg_to_send_buffer(local_tx_buffer, msg);

    rfd900x_state_t err = RFD900x_Transmit(rfd_dev, local_tx_buffer, len);
    if(err == RFD_BUSY) {
        // TODO: add missing error counter
    }
}

void Telemetry_SendRocketData(rfd900x_t *rfd_dev, const mavlink_modem_id_t modem_id, odb_data_t *data, const uint32_t current_time_ms) {
    if(!rfd_dev || !data) return;

    mavlink_message_t msg;
    mavlink_msg_rocket_telemetry_pack(
        modem_id,
        MAVLINK_COMPONENT_ID,
        &msg,

        current_time_ms,                                    // time_boot_ms: Timestamp since system boot in ms
        data->system_states,                                // system_states: Current system/component states
        data->event_states,                                 // event_states: Current events states (pyros fired, apogee) -> linked with odb_stats_t
        data->mission_state,                                // mission_state: Mission state (preflight, inflight, postflight) -> Linked with FSM
        data->battery_mv,                                   // battery_mv: Main battery voltage in millivolts (mV)
        (int16_t)(data->roll * 100.0f),                     // roll: Roll angle in degrees (deg -> cdeg) -> Linked with BNO055
        (int16_t)(data->pitch * 100.0f),                    // pitch: Pitch angle in degrees (deg -> cdeg) -> Linked with BNO055
        (int16_t)(data->yaw * 100.0f),                      // yaw: Yaw angle between -180 and 180 (deg -> cdeg) -> Linked with BNO055
        (int16_t)(data->imu_acc_x * 100.0f),                // imu_acc_x: IMU Acceleration X (m/s2 -> cm/s2) -> Linked with BNO055
        (int16_t)(data->imu_acc_y * 100.0f),                // imu_acc_y: IMU Acceleration Y (m/s2 -> cm/s2) -> Linked with BNO055
        (int16_t)(data->imu_acc_z * 100.0f),                // imu_acc_z: IMU Acceleration Z (m/s2 -> cm/s2) -> Linked with BNO055
        (int32_t)(data->imu_gyro_x * 100.0f),               // imu_gyro_x: IMU Angular rate X (deg/s -> cdeg/s) -> Linked with BNO055
        (int32_t)(data->imu_gyro_y * 100.0f),               // imu_gyro_y: IMU Angular rate Y (deg/s -> cdeg/s) -> Linked with BNO055
        (int32_t)(data->imu_gyro_z * 100.0f),               // imu_gyro_z: IMU Angular rate Z (deg/s -> cdeg/s) -> Linked with BNO055
        (int16_t)(data->imu_mag_x * 100.0f),                // imu_mag_x: IMU Magnetometer X (uT -> cuT) -> Linked with BNO055
        (int16_t)(data->imu_mag_y * 100.0f),                // imu_mag_y: IMU Magnetometer Y (uT -> cuT) -> Linked with BNO055
        (int16_t)(data->imu_mag_z * 100.0f),                // imu_mag_z: IMU Magnetometer Z (uT -> cuT) -> Linked with BNO055
        (int32_t)(data->altitude_agl_m * 100.0f),           // altitude_agl_m: Altitude from barometer (m -> cm) -> Linked with MS5611
        (uint32_t)(data->pressure_pa),                      // pressure_pa: Atmospheric pressure (Pa) -> Linked with MS5611
        (int16_t)(data->temp_celsius * 100.0f),             // temp_celsius: Environment temp (°C -> cdegC) -> Linked with MAX6612MXK
        (int32_t)(data->highg_acc_x * 100.0f),              // highg_acc_x: High-G Acceleration X (m/s2 -> cm/s2) -> Linked with ADXL382
        (int32_t)(data->highg_acc_y * 100.0f),              // highg_acc_y: High-G Acceleration Y (m/s2 -> cm/s2) -> Linked with ADXL382
        (int32_t)(data->highg_acc_z * 100.0f),              // highg_acc_z: High-G Acceleration Z (m/s2 -> cm/s2) -> Linked with ADXL382
        data->gps_fix,                                      // gps_fix: 1 = Active fix, 0 = Void/No fix -> Linked with L76LM33
        data->lat,                                          // lat: Latitude in degE7 -> Linked with L76LM33
        data->lon,                                          // lon: Longitude in degE7 -> Linked with L76LM33
        data->gps_alt,                                      // gps_alt: Altitude (MSL) based on GPS in mm -> Linked with L76LM33
        data->vel,                                          // vel: Ground velocity in cm/s -> Linked with L76LM33
        data->cog,                                          // cog: Course Over Ground in centi-degrees -> Linked with L76LM33
        data->satellites_nb,                                // satellites_nb: Number of satellites used for the fix -> Linked with L76LM33
        (int32_t)(data->imu_acc_vertical * 100.0f),         // imu_acc_vertical: Vert acc from IMU (m/s2 -> cm/s2) -> Linked with BNO055
        (int32_t)(data->highg_acc_vertical * 100.0f),       // highg_acc_vertical: Vert acc from High-G (m/s2 -> cm/s2) -> Linked with ADXL382
        (int32_t)(data->kalman_z * 100.0f),                 // kalman_z: Filtered altitude (m -> cm)
        (int32_t)(data->kalman_v * 100.0f)                  // kalman_v: Filtered velocity (m/s -> cm/s)
    );

    Telemetry_TransmitMessage(rfd_dev, &msg);
}
