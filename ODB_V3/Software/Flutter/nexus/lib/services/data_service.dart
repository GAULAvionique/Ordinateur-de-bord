import 'package:flutter/foundation.dart';
import 'dart:math';
import 'dart:convert';
import 'package:nexus/services/bluetooth_service.dart';
import 'package:nexus/services/console_service.dart';

// ============================================================================
// ========================== OUTILS BINAIRES (DRY) ===========================
// ============================================================================

class ByteCursor {
  final ByteData data;
  int offset = 0;

  ByteCursor(Uint8List bytes) : data = ByteData.sublistView(bytes);

  int readUint8() { final v = data.getUint8(offset); offset += 1; return v; }
  int readUint16() { final v = data.getUint16(offset, Endian.little); offset += 2; return v; }
  int readUint32() { final v = data.getUint32(offset, Endian.little); offset += 4; return v; }
  int readInt32() { final v = data.getInt32(offset, Endian.little); offset += 4; return v; }
  double readFloat32() { final v = data.getFloat32(offset, Endian.little); offset += 4; return v; }

  List<int> readUint8Array(int length) {
    final list = <int>[];
    for (int i = 0; i < length; i++) {
      list.add(readUint8());
    }
    return list;
  }

  String readString(int maxLength) {
    final bytes = readUint8Array(maxLength);
    return utf8.decode(bytes.where((b) => b != 0).toList());
  }
}

class ByteBuilder {
  final ByteData data;
  int offset = 0;

  ByteBuilder(int size) : data = ByteData(size);

  void writeUint8(int v) { data.setUint8(offset, v); offset += 1; }
  void writeUint16(int v) { data.setUint16(offset, v, Endian.little); offset += 2; }
  void writeUint32(int v) { data.setUint32(offset, v, Endian.little); offset += 4; }
  void writeFloat32(double v) { data.setFloat32(offset, v, Endian.little); offset += 4; }

  void writeUint8Array(List<int> v) {
    for (var b in v) {
      writeUint8(b);
    }
  }

  void writeString(String str, int fixedLength) {
    final bytes = utf8.encode(str);
    for (int i = 0; i < fixedLength; i++) {
      writeUint8(i < bytes.length ? bytes[i] : 0);
    }
  }

  Uint8List toBytes() => data.buffer.asUint8List();
}


// ============================================================================
// ========================== CLASSES DE DONNÉES ==============================
// ============================================================================

class PyroEvent {
  final bool fired;
  final int timeMs;
  PyroEvent(this.fired, this.timeMs);
}

class WindowEvent {
  final bool activated;
  final int startTimeMs;
  final int endTimeMs;
  WindowEvent(this.activated, this.startTimeMs, this.endTimeMs);
}

class Metric {
  final bool valid;
  final double value;
  final int timeMs;
  Metric(this.valid, this.value, this.timeMs);
}

class OdbStats {
  final int flightId;
  final int date;
  final List<PyroEvent> pyroEvents;
  final WindowEvent pyrosArm;
  final WindowEvent machLock;
  final Metric maxAltitudeGps;
  final Metric maxAltitudeBaro;
  final Metric maxAltitudeKalman;
  final Metric apogee;
  final Metric mainDeploy;
  final Metric drogueDeploy;
  final Metric maxAscendSpeed;
  final Metric maxAscendAccel;
  final Metric maxDescendSpeed;
  final Metric maxDescendAccel;
  final int lastLat;
  final int lastLon;
  final int flightTimeMs;

  OdbStats({
    required this.flightId,
    required this.date,
    required this.pyroEvents,
    required this.pyrosArm,
    required this.machLock,
    required this.maxAltitudeGps,
    required this.maxAltitudeBaro,
    required this.maxAltitudeKalman,
    required this.apogee,
    required this.mainDeploy,
    required this.drogueDeploy,
    required this.maxAscendSpeed,
    required this.maxAscendAccel,
    required this.maxDescendSpeed,
    required this.maxDescendAccel,
    required this.lastLat,
    required this.lastLon,
    required this.flightTimeMs,
  });

  factory OdbStats.fromBytes(Uint8List bytes) {
    final reader = ByteCursor(bytes);
    
    final flightId = reader.readUint32();
    final date = reader.readUint32();

    final pyros = List.generate(4, (_) => PyroEvent(reader.readUint8() != 0, reader.readUint32()));

    final pyrosArm = WindowEvent(reader.readUint8() != 0, reader.readUint32(), reader.readUint32());
    final machLock = WindowEvent(reader.readUint8() != 0, reader.readUint32(), reader.readUint32());

    Metric readMetric() => Metric(reader.readUint8() != 0, reader.readFloat32(), reader.readUint32());

    return OdbStats(
      flightId: flightId,
      date: date,
      pyroEvents: pyros,
      pyrosArm: pyrosArm,
      machLock: machLock,
      maxAltitudeGps: readMetric(),
      maxAltitudeBaro: readMetric(),
      maxAltitudeKalman: readMetric(),
      apogee: readMetric(),
      mainDeploy: readMetric(),
      drogueDeploy: readMetric(),
      maxAscendSpeed: readMetric(),
      maxAscendAccel: readMetric(),
      maxDescendSpeed: readMetric(),
      maxDescendAccel: readMetric(),
      lastLat: reader.readInt32(),
      lastLon: reader.readInt32(),
      flightTimeMs: reader.readUint32(),
    );
  }
}

class OdbConfig {
  final int magicNumber;
  final int versionMajor;
  final int versionMinor;
  final int payloadSize;
  
  final String odbName;
  final int stageRole;
  final bool debugMode;
  final bool flightTestMode;
  final int axisProfile;
  final int fireAttemptDelayMs;
  final int pyrosArmingFailsafeMs;
  final int minNeededPyroNb;
  final List<int> pyroRoles;
  final double accZLaunchThreshold;
  final double boostPhaseVThreshold;
  final double apogeeDetectVThreshold;
  final double landingDetectVThreshold;
  final int landingDetectThresholdMs;
  final int apogeeFailsafeMs;
  final double mainDeployAltitudeThresholdM;
  final int drogueFireAttemptMaxNb;
  final int mainFireAttemptMaxNb;
  final bool enableBuzzer;
  final int buzzerReportToneHz;
  final int idefixFrequencyHz;

  OdbConfig({
    this.magicNumber = 0x434F4E46,
    this.versionMajor = 1,
    this.versionMinor = 2,
    this.payloadSize = 94,
    required this.odbName,
    required this.stageRole,
    required this.debugMode,
    required this.flightTestMode,
    required this.axisProfile,
    required this.fireAttemptDelayMs,
    required this.pyrosArmingFailsafeMs,
    required this.minNeededPyroNb,
    required this.pyroRoles,
    required this.accZLaunchThreshold,
    required this.boostPhaseVThreshold,
    required this.apogeeDetectVThreshold,
    required this.landingDetectVThreshold,
    required this.landingDetectThresholdMs,
    required this.apogeeFailsafeMs,
    required this.mainDeployAltitudeThresholdM,
    required this.drogueFireAttemptMaxNb,
    required this.mainFireAttemptMaxNb,
    required this.enableBuzzer,
    required this.buzzerReportToneHz,
    required this.idefixFrequencyHz,
  });

  factory OdbConfig.fromBytes(Uint8List bytes) {
    final reader = ByteCursor(bytes);
    return OdbConfig(
      magicNumber: reader.readUint32(),
      versionMajor: reader.readUint8(),
      versionMinor: reader.readUint8(),
      payloadSize: reader.readUint16(),
      odbName: reader.readString(32),
      stageRole: reader.readUint8(),
      debugMode: reader.readUint8() == 1,
      flightTestMode: reader.readUint8() == 1,
      axisProfile: reader.readUint8(),
      fireAttemptDelayMs: reader.readUint32(),
      pyrosArmingFailsafeMs: reader.readUint32(),
      minNeededPyroNb: reader.readUint8(),
      pyroRoles: reader.readUint8Array(4),
      accZLaunchThreshold: reader.readFloat32(),
      boostPhaseVThreshold: reader.readFloat32(),
      apogeeDetectVThreshold: reader.readFloat32(),
      landingDetectVThreshold: reader.readFloat32(),
      landingDetectThresholdMs: reader.readUint32(),
      apogeeFailsafeMs: reader.readUint32(),
      mainDeployAltitudeThresholdM: reader.readFloat32(),
      drogueFireAttemptMaxNb: reader.readUint8(),
      mainFireAttemptMaxNb: reader.readUint8(),
      enableBuzzer: reader.readUint8() == 1,
      buzzerReportToneHz: reader.readUint16(),
      idefixFrequencyHz: reader.readUint32(),
    );
  }

  OdbConfig copyWith({
    String? odbName,
    int? stageRole,
    bool? debugMode,
    bool? flightTestMode,
    int? axisProfile,
    int? fireAttemptDelayMs,
    int? pyrosArmingFailsafeMs,
    int? minNeededPyroNb,
    List<int>? pyroRoles,
    double? accZLaunchThreshold,
    double? boostPhaseVThreshold,
    double? apogeeDetectVThreshold,
    double? landingDetectVThreshold,
    int? landingDetectThresholdMs,
    int? apogeeFailsafeMs,
    double? mainDeployAltitudeThresholdM,
    int? drogueFireAttemptMaxNb,
    int? mainFireAttemptMaxNb,
    bool? enableBuzzer,
    int? buzzerReportToneHz,
    int? idefixFrequencyHz,
  }) {
    return OdbConfig(
      odbName: odbName ?? this.odbName,
      stageRole: stageRole ?? this.stageRole,
      debugMode: debugMode ?? this.debugMode,
      flightTestMode: flightTestMode ?? this.flightTestMode,
      axisProfile: axisProfile ?? this.axisProfile,
      fireAttemptDelayMs: fireAttemptDelayMs ?? this.fireAttemptDelayMs,
      pyrosArmingFailsafeMs: pyrosArmingFailsafeMs ?? this.pyrosArmingFailsafeMs,
      minNeededPyroNb: minNeededPyroNb ?? this.minNeededPyroNb,
      pyroRoles: pyroRoles ?? this.pyroRoles,
      accZLaunchThreshold: accZLaunchThreshold ?? this.accZLaunchThreshold,
      boostPhaseVThreshold: boostPhaseVThreshold ?? this.boostPhaseVThreshold,
      apogeeDetectVThreshold: apogeeDetectVThreshold ?? this.apogeeDetectVThreshold,
      landingDetectVThreshold: landingDetectVThreshold ?? this.landingDetectVThreshold,
      landingDetectThresholdMs: landingDetectThresholdMs ?? this.landingDetectThresholdMs,
      apogeeFailsafeMs: apogeeFailsafeMs ?? this.apogeeFailsafeMs,
      mainDeployAltitudeThresholdM: mainDeployAltitudeThresholdM ?? this.mainDeployAltitudeThresholdM,
      drogueFireAttemptMaxNb: drogueFireAttemptMaxNb ?? this.drogueFireAttemptMaxNb,
      mainFireAttemptMaxNb: mainFireAttemptMaxNb ?? this.mainFireAttemptMaxNb,
      enableBuzzer: enableBuzzer ?? this.enableBuzzer,
      buzzerReportToneHz: buzzerReportToneHz ?? this.buzzerReportToneHz,
      idefixFrequencyHz: idefixFrequencyHz ?? this.idefixFrequencyHz,
    );
  }

  Uint8List toBytes() {
    final writer = ByteBuilder(94);
    writer.writeUint32(magicNumber);
    writer.writeUint8(versionMajor);
    writer.writeUint8(versionMinor);
    writer.writeUint16(payloadSize);
    writer.writeString(odbName, 32);
    writer.writeUint8(stageRole);
    writer.writeUint8(debugMode ? 1 : 0);
    writer.writeUint8(flightTestMode ? 1 : 0);
    writer.writeUint8(axisProfile);
    writer.writeUint32(fireAttemptDelayMs);
    writer.writeUint32(pyrosArmingFailsafeMs);
    writer.writeUint8(minNeededPyroNb);
    writer.writeUint8Array(pyroRoles);
    writer.writeFloat32(accZLaunchThreshold);
    writer.writeFloat32(boostPhaseVThreshold);
    writer.writeFloat32(apogeeDetectVThreshold);
    writer.writeFloat32(landingDetectVThreshold);
    writer.writeUint32(landingDetectThresholdMs);
    writer.writeUint32(apogeeFailsafeMs);
    writer.writeFloat32(mainDeployAltitudeThresholdM);
    writer.writeUint8(drogueFireAttemptMaxNb);
    writer.writeUint8(mainFireAttemptMaxNb);
    writer.writeUint8(enableBuzzer ? 1 : 0);
    writer.writeUint16(buzzerReportToneHz);
    writer.writeUint32(idefixFrequencyHz);
    return writer.toBytes();
  }
}

class OdbTelemetry {
  final int versionMajor;
  final int versionMinor;
  final int payloadSize;
  
  final int timeBootMs;
  final int systemStates;
  final int eventStates;
  final int missionState;
  final int batteryMv;
  final List<int> pyrosMv;
  
  final double roll, pitch, yaw;
  final double imuAccX, imuAccY, imuAccZ;
  final double imuGyroX, imuGyroY, imuGyroZ;
  final double imuMagX, imuMagY, imuMagZ;
  final double imuTemp;
  
  final double altitudeMslM, pressurePa, tempCelsius;
  final double highgAccX, highgAccY, highgAccZ;
  final double highgTemp;
  
  final int gpsFix;
  final double gpsLat, gpsLon, gpsAlt, gpsVelocity, gpsCourse;
  final int satellitesNb;
  
  final int sdSpace;
  final double imuAccVertical, highgAccVertical, kalmanZ, kalmanV;

  OdbTelemetry.fromBytes(Uint8List bytes) : this._internal(ByteCursor(bytes));

  OdbTelemetry._internal(ByteCursor reader)
      : versionMajor = reader.readUint8(),
        versionMinor = reader.readUint8(),
        payloadSize = reader.readUint16(),
        
        timeBootMs = reader.readUint32(),
        systemStates = reader.readUint16(),
        eventStates = reader.readUint16(),
        missionState = reader.readUint8(),
        batteryMv = reader.readUint16(),
        pyrosMv = List.generate(4, (_) => reader.readUint16()),
        
        roll = reader.readFloat32(),
        pitch = reader.readFloat32(),
        yaw = reader.readFloat32(),
        
        imuAccX = reader.readFloat32(),
        imuAccY = reader.readFloat32(),
        imuAccZ = reader.readFloat32(),
        
        imuGyroX = reader.readFloat32(),
        imuGyroY = reader.readFloat32(),
        imuGyroZ = reader.readFloat32(),
        
        imuMagX = reader.readFloat32(),
        imuMagY = reader.readFloat32(),
        imuMagZ = reader.readFloat32(),
        imuTemp = reader.readFloat32(),
        
        altitudeMslM = reader.readFloat32(),
        pressurePa = reader.readFloat32(),
        tempCelsius = reader.readFloat32(),
        
        highgAccX = reader.readFloat32(),
        highgAccY = reader.readFloat32(),
        highgAccZ = reader.readFloat32(),
        highgTemp = reader.readFloat32(),
        
        gpsFix = reader.readUint8(),
        gpsLat = reader.readInt32() / 10000000.0,
        gpsLon = reader.readInt32() / 10000000.0,
        gpsAlt = reader.readInt32() / 1000.0,
        gpsVelocity = reader.readUint16() / 100.0,
        gpsCourse = reader.readUint16() / 100.0,
        satellitesNb = reader.readUint8(),
        
        sdSpace = reader.readUint16(),
        
        imuAccVertical = reader.readFloat32(),
        highgAccVertical = reader.readFloat32(),
        kalmanZ = reader.readFloat32(),
        kalmanV = reader.readFloat32() {
    reader.readUint8(); // End padding
  }
}

enum SensorState { unknown, ok, error }
enum RadioState { disconnected, connecting, connected }


// ============================================================================
// ========================== GESTIONNAIRE PRINCIPAL ==========================
// ============================================================================

class DataServiceManager with ChangeNotifier {
  static const int stageRoleBooster = 2;
  static const int stageRoleSustainer = 3;
  static const int axisProfileP0 = 0;
  static const int axisProfileP1 = 1;
  static const int axisProfileP2 = 2;
  static const int axisProfileP3 = 3;
  static const int axisProfileP4 = 4;
  static const int axisProfileP5 = 5;
  static const int axisProfileP6 = 6;
  static const int axisProfileP7 = 7;
  static const int eventFlagPyrosArmed = 1 << 0;
  static const int eventFlagPyro1Fired = 1 << 1;
  static const int eventFlagPyro2Fired = 1 << 2;
  static const int eventFlagPyro3Fired = 1 << 3;
  static const int eventFlagPyro4Fired = 1 << 4;
  static const int eventFlagApogeeDetected = 1 << 5;
  static const int eventFlagMainDeployed = 1 << 6;
  static const int eventFlagDrogueDeployed = 1 << 7;
  static const int eventFlagMachLockEnabled = 1 << 8;
  static const int expectedConfigMajor = 1;
  static const int expectedConfigMinor = 2;
  static const int expectedTelemetryMajor = 1;
  static const int expectedTelemetryMinor = 3;

  final BluetoothServiceManager btService;
  DataServiceManager(this.btService);
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // Objets de données
  OdbTelemetry? telemetry;
  OdbConfig? config;
  OdbStats? lastFlightStats;

  // Version Handler
  bool hasVersionMismatch = false;
  String versionMismatchMessage = '';

  void clearVersionMismatch() {
    if (hasVersionMismatch) {
      hasVersionMismatch = false;
      versionMismatchMessage = '';
      _safeNotifyListeners();
    }
  }


  // ---------- Getters UI ----------
  
  // Télémétrie / Variables dérivées
  int get timeBootMs => telemetry?.timeBootMs ?? 0;
  int get systemStates => telemetry?.systemStates ?? 0;
  int get eventStates => telemetry?.eventStates ?? 0;
  int get missionState => telemetry?.missionState ?? -1;
  
  String get odbFrameVersion => telemetry != null ? 'v${telemetry!.versionMajor}.${telemetry!.versionMinor}' : '';
  String get odbConfigFrameVersion => config != null ? 'v${config!.versionMajor}.${config!.versionMinor}' : '';
  bool get hasOdbConfig => config != null;
  
  double get batteryVoltageMax => 24.0;
  int get vinMv => telemetry?.batteryMv ?? 0;
  List<int> get pyrosMv => telemetry?.pyrosMv ?? List.filled(4, 0);
  double get batteryVoltage => vinMv / 1000.0;
  double get temperature => telemetry?.tempCelsius ?? 0.0;

  double get roll => telemetry?.roll ?? 0.0;
  double get pitch => telemetry?.pitch ?? 0.0;
  double get yaw => telemetry?.yaw ?? 0.0;
  double get imuAccX => telemetry?.imuAccX ?? 0.0;
  double get imuAccY => telemetry?.imuAccY ?? 0.0;
  double get imuAccZ => telemetry?.imuAccZ ?? 0.0;
  double get imuAccVertical => telemetry?.imuAccVertical ?? 0.0;
  double get imuGyroX => telemetry?.imuGyroX ?? 0.0;
  double get imuGyroY => telemetry?.imuGyroY ?? 0.0;
  double get imuGyroZ => telemetry?.imuGyroZ ?? 0.0;
  double get imuMagX => telemetry?.imuMagX ?? 0.0;
  double get imuMagY => telemetry?.imuMagY ?? 0.0;
  double get imuMagZ => telemetry?.imuMagZ ?? 0.0;
  double get imuTemp => telemetry?.imuTemp ?? 0.0;
  
  double get highGAccX => telemetry?.highgAccX ?? 0.0;
  double get highGAccY => telemetry?.highgAccY ?? 0.0;
  double get highGAccZ => telemetry?.highgAccZ ?? 0.0;
  double get highgTemp => telemetry?.highgTemp ?? 0.0;
  double get highGAccVertical => telemetry?.highgAccVertical ?? 0.0;
  
  double get barometerPressure => telemetry?.pressurePa ?? 0.0;
  double get altitudeMslM => telemetry?.altitudeMslM ?? 0.0;
  double get kalmanAltitudeM => telemetry?.kalmanZ ?? 0.0;
  double get kalmanVelocityMS => telemetry?.kalmanV ?? 0.0;
  
  int get gpsFix => telemetry?.gpsFix ?? 0;
  double get gpsLat => telemetry?.gpsLat ?? 0.0;
  double get gpsLon => telemetry?.gpsLon ?? 0.0;
  double get gpsAlt => telemetry?.gpsAlt ?? 0.0;
  double get gpsVelocity => telemetry?.gpsVelocity ?? 0.0;
  double get gpsCourse => telemetry?.gpsCourse ?? 0.0;
  int get gpsSatellites => telemetry?.satellitesNb ?? 0;
  
  double get sdFree => (telemetry?.sdSpace ?? 0) / 100.0;

  // Configuration Mapping
  String get odbName => config?.odbName ?? '';
  int get stageRole => config?.stageRole ?? stageRoleSustainer;
  bool get debugMode => config?.debugMode ?? false;
  bool get flightTestMode => config?.flightTestMode ?? false;
  int get axisProfile => config?.axisProfile ?? axisProfileP0;
  bool get enableBuzzer => config?.enableBuzzer ?? false;
  int get minNeededPyroNb => config?.minNeededPyroNb ?? 0;
  int get drogueFireAttemptMaxNb => config?.drogueFireAttemptMaxNb ?? 0;
  int get mainFireAttemptMaxNb => config?.mainFireAttemptMaxNb ?? 0;
  double get accZLaunchThreshold => config?.accZLaunchThreshold ?? 0.0;
  double get boostPhaseVThreshold => config?.boostPhaseVThreshold ?? 0.0;
  double get apogeeDetectVThreshold => config?.apogeeDetectVThreshold ?? 0.0;
  double get mainDeployAltitudeThresholdM => config?.mainDeployAltitudeThresholdM ?? 0.0;
  double get landingDetectVThreshold => config?.landingDetectVThreshold ?? 0.0;
  int get buzzerReportToneHz => config?.buzzerReportToneHz ?? 0;
  int get landingDetectThresholdMs => config?.landingDetectThresholdMs ?? 0;
  int get fireAttemptDelayMs => config?.fireAttemptDelayMs ?? 0;
  int get pyrosArmingFailsafeMs => config?.pyrosArmingFailsafeMs ?? 0;
  int get apogeeFailsafeMs => config?.apogeeFailsafeMs ?? 0;
  int get idefixFrequencyHz => config?.idefixFrequencyHz ?? 0;
  List<int> get pyroRoles => config?.pyroRoles ?? List.filled(4, 0);


  // ---------- Setters UI ----------
  
  set odbName(String value) { config = config?.copyWith(odbName: value); _safeNotifyListeners(); }
  set stageRole(int value) { config = config?.copyWith(stageRole: value); _safeNotifyListeners(); }
  set debugMode(bool value) { config = config?.copyWith(debugMode: value); _safeNotifyListeners(); }
  set flightTestMode(bool value) { config = config?.copyWith(flightTestMode: value); _safeNotifyListeners(); }
  set axisProfile(int value) { config = config?.copyWith(axisProfile: value); _safeNotifyListeners(); }
  set enableBuzzer(bool value) { config = config?.copyWith(enableBuzzer: value); _safeNotifyListeners(); }
  set minNeededPyroNb(int value) { config = config?.copyWith(minNeededPyroNb: value); _safeNotifyListeners(); }
  set drogueFireAttemptMaxNb(int value) { config = config?.copyWith(drogueFireAttemptMaxNb: value); _safeNotifyListeners(); }
  set mainFireAttemptMaxNb(int value) { config = config?.copyWith(mainFireAttemptMaxNb: value); _safeNotifyListeners(); }
  set accZLaunchThreshold(double value) { config = config?.copyWith(accZLaunchThreshold: value); _safeNotifyListeners(); }
  set boostPhaseVThreshold(double value) { config = config?.copyWith(boostPhaseVThreshold: value); _safeNotifyListeners(); }
  set apogeeDetectVThreshold(double value) { config = config?.copyWith(apogeeDetectVThreshold: value); _safeNotifyListeners(); }
  set mainDeployAltitudeThresholdM(double value) { config = config?.copyWith(mainDeployAltitudeThresholdM: value); _safeNotifyListeners(); }
  set landingDetectVThreshold(double value) { config = config?.copyWith(landingDetectVThreshold: value); _safeNotifyListeners(); }
  set buzzerReportToneHz(int value) { config = config?.copyWith(buzzerReportToneHz: value); _safeNotifyListeners(); }
  set landingDetectThresholdMs(int value) { config = config?.copyWith(landingDetectThresholdMs: value); _safeNotifyListeners(); }
  set fireAttemptDelayMs(int value) { config = config?.copyWith(fireAttemptDelayMs: value); _safeNotifyListeners(); }
  set pyrosArmingFailsafeMs(int value) { config = config?.copyWith(pyrosArmingFailsafeMs: value); _safeNotifyListeners(); }
  set apogeeFailsafeMs(int value) { config = config?.copyWith(apogeeFailsafeMs: value); _safeNotifyListeners(); }
  set idefixFrequencyHz(int value) { config = config?.copyWith(idefixFrequencyHz: value); _safeNotifyListeners(); }
  set pyroRoles(List<int> value) { config = config?.copyWith(pyroRoles: value); _safeNotifyListeners(); }


  // ---------- États des capteurs dynamiques ----------
  
  RadioState get radioState => (systemStates & (1 << 5)) != 0 ? RadioState.connected : RadioState.disconnected;
  SensorState get gpsSensorState => (systemStates & (1 << 8)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get barometerSensorState => (systemStates & (1 << 7)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get imuSensorState => (systemStates & (1 << 6)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get accHighGSensorState => (systemStates & (1 << 9)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get temperatureSensorState => (systemStates & (1 << 10)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get sdSensorState => (systemStates & (1 << 11)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get flashSensorState => (systemStates & (1 << 12)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get btModuleState => (systemStates & (1 << 13)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get idefixSensorState => (systemStates & (1 << 14)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get batterySensorState => batteryVoltage > 0 ? SensorState.ok : SensorState.error;
  bool get goodPowerState => batteryVoltage >= 5.0;
  SensorState get pyroArmingModuleState => (systemStates & (1 << 4)) != 0 ? SensorState.ok : SensorState.error;
  
  bool get pyrosArmed => eventPyrosArmed;
  List<bool> get pyros {
    return [
      ((systemStates & (1 << 3)) != 0) && !eventPyro1Fired,
      ((systemStates & (1 << 2)) != 0) && !eventPyro2Fired,
      ((systemStates & (1 << 1)) != 0) && !eventPyro3Fired,
      ((systemStates & (1 << 0)) != 0) && !eventPyro4Fired,
    ];
  }


  // ---------- Formatters ----------

  double get batteryPercent => batteryVoltageMax > 0 ? (batteryVoltage / batteryVoltageMax * 100).clamp(0, 100) : 0.0;
  String get batteryVoltageDisplay => batteryVoltage > 0 ? '${batteryVoltage.toStringAsFixed(2)} V' : '—';
  String get batteryVoltageMaxDisplay => batteryVoltageMax > 0 ? '${batteryVoltageMax.toStringAsFixed(2)} V' : '—';
  String get batteryPercentDisplay => batteryVoltageMax > 0 ? '${batteryPercent.toStringAsFixed(1)}%' : '—';
  String get temperatureDisplay => temperature != 0.0 ? '${temperature.toStringAsFixed(2)} °C' : '—';

  String pyroVoltageDisplay(int pyroIndex, {required bool connected}) {
    if (!connected || pyroIndex < 0 || pyroIndex >= pyrosMv.length) return '—';
    return '${(pyrosMv[pyroIndex] / 1000.0).toStringAsFixed(2)} V';
  }
  
  double pressureToAltitude(double pressureHpa, [double seaLevelHpa = 1013.25]) {
    if (pressureHpa <= 0 || seaLevelHpa <= 0) return 0.0;
    final ratio = pressureHpa / seaLevelHpa;
    final alt = 44330.0 * (1 - pow(ratio, 1 / 5.255));
    return alt.isFinite ? alt.toDouble() : 0.0;
  }
  double get barometerAlt => pressureToAltitude(barometerPressure);

  String get altitudeDisplay {
    if (!hasConnection) return '—';
    if (barometerSensorState == SensorState.ok) return '${barometerAlt.toStringAsFixed(0)} m';
    if (hasValidGpsFix) return '${gpsAlt.toStringAsFixed(0)} m';
    return '—';
  }

  int get pyrosActiveCount => pyros.where((p) => p).length;
  String get pyrosSummary => pyros.map((p) => p ? '1' : '0').join(',');
  static const List<String> _pyroRoleNames = ['None', 'Main', 'Drogue', 'Main #2', 'Drogue #1'];

  String pyroRoleLabel(int pyroIndex, {bool connected = true}) {
    if (!connected) return '-';
    final roleIndex = pyroIndex < pyroRoles.length ? pyroRoles[pyroIndex] : 0;
    if (roleIndex < 0 || roleIndex >= _pyroRoleNames.length) return _pyroRoleNames.first;
    return _pyroRoleNames[roleIndex];
  }

  String pyroDisplayLabel(int pyroIndex, {required bool connected}) {
    return connected ? 'Pyro ${pyroIndex + 1} (${pyroRoleLabel(pyroIndex, connected: connected)})' : 'Pyro ${pyroIndex + 1} (-)';
  }

  String get missionStateDisplay {
    if (missionState < 0) return '—';

    final globalState = (missionState >> 4) & 0x0F;
    final subState = missionState & 0x0F;

    switch (globalState) {
      case 0: // PREFLIGHT
        switch (subState) {
          case 0: return 'PREFLIGHT (Static)';
          case 1: return 'PREFLIGHT (Pyros Test)';
          case 2: return 'PREFLIGHT (Ready)';
          default: return 'PREFLIGHT';
        }
      case 1: 
        return 'ARMED';
      case 2: // INFLIGHT
        switch (subState) {
          case 0: return 'INFLIGHT (Boost)';
          case 1: return 'INFLIGHT (Fast)';
          case 2: return 'INFLIGHT (Coast)';
          case 3: return 'INFLIGHT (Drogue)';
          case 4: return 'INFLIGHT (Main)';
          case 5: return 'INFLIGHT (Landed)';
          default: return 'INFLIGHT';
        }
      case 3: 
        return 'POSTFLIGHT';
      default: 
        return '—';
    }
  }

  String get systemStateDisplay => systemStates > 0 ? 'Flags $systemStates' : '—';
  String get eventStateDisplay {
    if (eventStates <= 0) return '—';
    final activeFlags = <String>[];
    if (eventPyrosArmed) activeFlags.add('Pyros armed');
    if (eventPyro1Fired) activeFlags.add('Pyro 1 fired');
    if (eventPyro2Fired) activeFlags.add('Pyro 2 fired');
    if (eventPyro3Fired) activeFlags.add('Pyro 3 fired');
    if (eventPyro4Fired) activeFlags.add('Pyro 4 fired');
    if (eventApogeeDetected) activeFlags.add('Apogee detected');
    if (eventMainDeployed) activeFlags.add('Main deployed');
    if (eventDrogueDeployed) activeFlags.add('Drogue deployed');
    if (eventMachLockEnabled) activeFlags.add('Mach lock enabled');
    return activeFlags.isEmpty ? 'Events $eventStates' : activeFlags.join(', ');
  }

  bool get eventPyrosArmed => (eventStates & eventFlagPyrosArmed) != 0;
  bool get eventPyro1Fired => (eventStates & eventFlagPyro1Fired) != 0;
  bool get eventPyro2Fired => (eventStates & eventFlagPyro2Fired) != 0;
  bool get eventPyro3Fired => (eventStates & eventFlagPyro3Fired) != 0;
  bool get eventPyro4Fired => (eventStates & eventFlagPyro4Fired) != 0;
  bool get eventApogeeDetected => (eventStates & eventFlagApogeeDetected) != 0;
  bool get eventMainDeployed => (eventStates & eventFlagMainDeployed) != 0;
  bool get eventDrogueDeployed => (eventStates & eventFlagDrogueDeployed) != 0;
  bool get eventMachLockEnabled => (eventStates & eventFlagMachLockEnabled) != 0;
  
  String get timeBootFormatted {
    if (timeBootMs <= 0) return '00h:00m:00s:00ms';
    final hours = timeBootMs ~/ 3600000;
    final minutes = (timeBootMs % 3600000) ~/ 60000;
    final seconds = (timeBootMs % 60000) ~/ 1000;
    final milliseconds = timeBootMs % 1000;
    return '${hours.toString().padLeft(2, '0')}h:${minutes.toString().padLeft(2, '0')}m:${seconds.toString().padLeft(2, '0')}s:${milliseconds.toString().padLeft(2, '0')}ms';
  }

  String get gpsVelocityDisplay => hasValidGpsFix ? '${gpsVelocity.toStringAsFixed(1)} m/s' : '—';
  String get gpsCourseDisplay => hasValidGpsFix ? '${gpsCourse.toStringAsFixed(0)}°' : '—';
  
  String get missionStatus {
    if (missionStateDisplay != '—') return missionStateDisplay;
    return systemStateDisplay;
  }

  String get imuTempDisplay => hasConnection && imuSensorState == SensorState.ok
      ? '${imuTemp.toStringAsFixed(2)} °C'
      : '—';
  String get imuAccXDisplay => hasConnection && imuSensorState == SensorState.ok
      ? 'X: ${imuAccX.toStringAsFixed(2)} m/s²'
      : '—';
  String get imuAccYDisplay => hasConnection && imuSensorState == SensorState.ok
      ? 'Y: ${imuAccY.toStringAsFixed(2)} m/s²'
      : '—';
  String get imuAccZDisplay => hasConnection && imuSensorState == SensorState.ok
      ? 'Z: ${imuAccZ.toStringAsFixed(2)} m/s²'
      : '—';
  String get imuGyroXDisplay =>
      hasConnection && imuSensorState == SensorState.ok
          ? 'X: ${imuGyroX.toStringAsFixed(2)} °/s'
          : '—';
  String get imuGyroYDisplay =>
      hasConnection && imuSensorState == SensorState.ok
          ? 'Y: ${imuGyroY.toStringAsFixed(2)} °/s'
          : '—';
  String get imuGyroZDisplay =>
      hasConnection && imuSensorState == SensorState.ok
          ? 'Z: ${imuGyroZ.toStringAsFixed(2)} °/s'
          : '—';
  String get imuMagXDisplay => hasConnection && imuSensorState == SensorState.ok
      ? 'X: ${imuMagX.toStringAsFixed(2)} µT'
      : '—';
  String get imuMagYDisplay => hasConnection && imuSensorState == SensorState.ok
      ? 'Y: ${imuMagY.toStringAsFixed(2)} µT'
      : '—';
  String get imuMagZDisplay => hasConnection && imuSensorState == SensorState.ok
      ? 'Z: ${imuMagZ.toStringAsFixed(2)} µT'
      : '—';
  String get pitchDisplay => hasConnection && imuSensorState == SensorState.ok
      ? '${pitch.toStringAsFixed(1)}°'
      : '—';
  String get rollDisplay => hasConnection && imuSensorState == SensorState.ok
      ? '${roll.toStringAsFixed(1)}°'
      : '—';
  String get yawDisplay => hasConnection && imuSensorState == SensorState.ok
      ? '${yaw.toStringAsFixed(1)}°'
      : '—';

  String get highGAccXDisplay =>
      hasConnection && accHighGSensorState == SensorState.ok
          ? 'X: ${highGAccX.toStringAsFixed(2)} m/s²'
          : '—';
  String get highGAccYDisplay =>
      hasConnection && accHighGSensorState == SensorState.ok
          ? 'Y: ${highGAccY.toStringAsFixed(2)} m/s²'
          : '—';
  String get highGAccZDisplay =>
      hasConnection && accHighGSensorState == SensorState.ok
          ? 'Z: ${highGAccZ.toStringAsFixed(2)} m/s²'
          : '—';
  String get highGTempDisplay =>
      hasConnection && accHighGSensorState == SensorState.ok
          ? '${highgTemp.toStringAsFixed(2)} °C'
          : '—';

  String get sdFreeDisplay => hasConnection && sdSensorState == SensorState.ok
      ? '${sdFree.toStringAsFixed(2)} GB libre'
      : '—';
  String get idefixFrequencyDisplay =>
      hasConnection && idefixSensorState == SensorState.ok
          ? (idefixFrequencyHz / 1000000).toStringAsFixed(3)
          : '—';

  String get imuAccVerticalDisplay => hasConnection && imuSensorState == SensorState.ok ? '${imuAccVertical.toStringAsFixed(2)} m/s²' : '—';
  String get highGAccVerticalDisplay => hasConnection && accHighGSensorState == SensorState.ok ? '${highGAccVertical.toStringAsFixed(2)} m/s²' : '—';

  String get pressureDisplay => hasConnection && barometerSensorState == SensorState.ok ? barometerPressure.toStringAsFixed(2) : '—';
  String get altitudeMslDisplay => hasConnection ? altitudeMslM.toStringAsFixed(2) : '—';
  String get kalmanAltitudeDisplay => hasConnection ? kalmanAltitudeM.toStringAsFixed(2) : '—';
  String get kalmanVelocityDisplay => hasConnection ? kalmanVelocityMS.toStringAsFixed(2) : '—';

  String get gpsLatDisplay => hasValidGpsFix ? '${gpsLat.toStringAsFixed(6)}°' : '—';
  String get gpsLonDisplay => hasValidGpsFix ? '${gpsLon.toStringAsFixed(6)}°' : '—';
  String get gpsAltDisplay => hasValidGpsFix ? '${gpsAlt.toStringAsFixed(1)} m' : '—';
  String get gpsSatellitesDisplay => hasValidGpsFix ? '$gpsSatellites satellites' : '—';
  String get gpsFixDisplay => hasConnection ? (gpsFix > 0 ? 'Actif' : 'Aucun fix') : '—';

  bool get odbSensorState => (
      temperatureSensorState == SensorState.ok &&
      imuSensorState == SensorState.ok &&
      accHighGSensorState == SensorState.ok &&
      flashSensorState == SensorState.ok &&
      gpsSensorState == SensorState.ok &&
      barometerSensorState == SensorState.ok &&
      goodPowerState == true
      //pyroArmingModuleState == SensorState.ok &&
      //pyrosActiveCount >= 0
    );

  bool get missionReady => odbSensorState && radioState == RadioState.connected;
  bool get hasConnection => btService.connectedDevice != null;
  bool get hasValidGpsFix => hasConnection && gpsSensorState == SensorState.ok && gpsFix > 0;

  void resetOdbConfig() {
    telemetry = null;
    config = null;
    lastFlightStats = null;
    clearVersionMismatch();
    _safeNotifyListeners();
  }


  // ---------- COMMANDES ----------

  int _parseInt(String value, int fallback) => int.tryParse(value.trim()) ?? fallback;
  double _parseDouble(String value, double fallback) => double.tryParse(value.trim().replaceAll(',', '.')) ?? fallback;

  Future<void> refreshOdb() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x06]);
  }

  Future<void> commandPing() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x01]);
  }

  Future<void> commandArm(bool arm) async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x02, arm ? 1 : 0]);
  }

  Future<void> commandFire(int pyroIndex) async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x03, pyroIndex]);
  }

  Future<void> applyOdbSettings({
    required String odbName,
    required String stageRole,
    required bool debugMode,
    required bool flightTestMode,
    required String axisProfile,
    required bool enableBuzzer,
    required String minNeededPyroNb,
    required String drogueFireAttemptMaxNb,
    required String mainFireAttemptMaxNb,
    required String accZLaunchThreshold,
    required String boostPhaseVThreshold,
    required String apogeeDetectVThreshold,
    required String mainDeployAltitudeThresholdM,
    required String landingDetectVThreshold,
    required String buzzerReportToneHz,
    required String landingDetectThresholdMs,
    required String fireAttemptDelayMs,
    required String pyrosArmingFailsafeMs,
    required String apogeeFailsafeMs,
    required String idefixFrequencyHz,
    required List<int> pyroRoles,
  }) async {
    if (!hasConnection) {
      if (hasVersionMismatch) {
        ConsoleService().log('Envoi bloqué : Conflit de version détecté.');
        return;
      }

      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }

    final newConfig = OdbConfig(
      odbName: odbName.trim(),
      stageRole: _parseInt(stageRole, this.stageRole),
      debugMode: debugMode,
      flightTestMode: flightTestMode,
      axisProfile: _parseInt(axisProfile, this.axisProfile),
      fireAttemptDelayMs: _parseInt(fireAttemptDelayMs, this.fireAttemptDelayMs),
      pyrosArmingFailsafeMs: _parseInt(pyrosArmingFailsafeMs, this.pyrosArmingFailsafeMs),
      minNeededPyroNb: _parseInt(minNeededPyroNb, this.minNeededPyroNb),
      pyroRoles: pyroRoles,
      accZLaunchThreshold: _parseDouble(accZLaunchThreshold, this.accZLaunchThreshold),
      boostPhaseVThreshold: _parseDouble(boostPhaseVThreshold, this.boostPhaseVThreshold),
      apogeeDetectVThreshold: _parseDouble(apogeeDetectVThreshold, this.apogeeDetectVThreshold),
      landingDetectVThreshold: _parseDouble(landingDetectVThreshold, this.landingDetectVThreshold),
      landingDetectThresholdMs: _parseInt(landingDetectThresholdMs, this.landingDetectThresholdMs),
      apogeeFailsafeMs: _parseInt(apogeeFailsafeMs, this.apogeeFailsafeMs),
      mainDeployAltitudeThresholdM: _parseDouble(mainDeployAltitudeThresholdM, this.mainDeployAltitudeThresholdM),
      drogueFireAttemptMaxNb: _parseInt(drogueFireAttemptMaxNb, this.drogueFireAttemptMaxNb),
      mainFireAttemptMaxNb: _parseInt(mainFireAttemptMaxNb, this.mainFireAttemptMaxNb),
      enableBuzzer: enableBuzzer,
      buzzerReportToneHz: _parseInt(buzzerReportToneHz, this.buzzerReportToneHz),
      idefixFrequencyHz: _parseInt(idefixFrequencyHz, this.idefixFrequencyHz),
    );

    await btService.sendBinary(0x02, newConfig.toBytes());
    ConsoleService().log('Envoi de la nouvelle configuration ...');

    await Future.delayed(const Duration(milliseconds: 200));

    await btService.sendBinary(0x03, [0x04]);
    ConsoleService().log('Demande de sauvegarde Flash et de redémarrage envoyée.');
  }

  Future<void> resetOdbSettingsToDefault() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x05]);
    ConsoleService().log('Demande de réinitialisation de la configuration envoyée.');
  }

  Future<void> resetOdbFlights() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x09]);
    ConsoleService().log('Demande de réinitialisation des données de vol envoyée.');
  }

  Future<void> resetOdbMemory() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x07]);
    ConsoleService().log('Demande de réinitialisation usine envoyée.');
  }

  Future<void> requestLastFlightEvents() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    ConsoleService().log('Demande des événements du dernier vol...');
    await btService.sendBinary(0x03, [0x08]);
  }

  Future<void> setReadyFlight() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x0A]);
    ConsoleService().log('Demande de mise en départ envoyée.');
  }

  Future<void> testArmingModule() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x0B]);
    ConsoleService().log('Demande de test du module d\'armement envoyée.');
  }

  Future<void> testPyrosContinuity() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x0C]);
    ConsoleService().log('Demande de test de la continuité des pyros envoyée.');
  }

  Future<void> setSubArmed() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x0D]);
    ConsoleService().log('Demande de mise en sub armed envoyée.');
  }

  Future<void> setSubBoost() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x0E]);
    ConsoleService().log('Demande de mise en sub boost envoyée.');
  }

  Future<void> setSubFast() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x0F]);
    ConsoleService().log('Demande de mise en sub fast envoyée.');
  }

  Future<void> setSubCoast() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x10]);
    ConsoleService().log('Demande de mise en sub coast envoyée.');
  }

  Future<void> setSubDrogue() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x11]);
    ConsoleService().log('Demande de mise en sub drogue envoyée.');
  }

  Future<void> setSubMain() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x12]);
    ConsoleService().log('Demande de mise en sub main envoyée.');
  }

  Future<void> setSubLanded() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x13]);
    ConsoleService().log('Demande de mise en sub landed envoyée.');
  }

  Future<void> testMachLock() async {
    if (!hasConnection) { ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB'); return; }
    await btService.sendBinary(0x03, [0x14]);
    ConsoleService().log('Demande de test mach lock envoyée.');
  }

  // ---------- PARSER ----------
  
  void parseBinaryMessage(int type, List<int> payload) {
    if (_isDisposed) return;
    final bytes = Uint8List.fromList(payload);

    try {
      if (type == 0x01) { // MSG_TELEMETRY
        telemetry = OdbTelemetry.fromBytes(bytes);

        if (bytes.length != telemetry!.payloadSize) {
          ConsoleService().log(
            'Erreur: taille télémétrie invalide (${bytes.length} octets, '
            'déclarée ${telemetry!.payloadSize}).',
          );
          telemetry = null;
          _safeNotifyListeners();
          return;
        }

        if (telemetry!.versionMajor != expectedTelemetryMajor || telemetry!.versionMinor != expectedTelemetryMinor) {
          hasVersionMismatch = true;
          versionMismatchMessage = 'Télémétrie incompatible.\nAvionique : v${telemetry!.versionMajor}.${telemetry!.versionMinor} | Application (Attendue) : v$expectedTelemetryMajor.$expectedTelemetryMinor';
          ConsoleService().log('Erreur: Télémétrie v${telemetry!.versionMajor}.${telemetry!.versionMinor} non supportée.');
          _safeNotifyListeners();
          return;
        }

        clearVersionMismatch();
        _safeNotifyListeners();

      } else if (type == 0x02) { // MSG_GENERIC_DATA
        if (payload.length >= 4) {
          final magicNumber = ByteData.sublistView(bytes).getUint32(0, Endian.little); 
          
          if (magicNumber == 0x434F4E46) { // 'CONF'
            final tempConfig = OdbConfig.fromBytes(bytes);

            if (tempConfig.versionMajor == expectedConfigMajor && tempConfig.versionMinor == expectedConfigMinor) {
              config = tempConfig;
              clearVersionMismatch();
              _safeNotifyListeners();
              ConsoleService().log('Configuration ODB lue et synchronisée avec succès !');
            } else {
              hasVersionMismatch = true;
              versionMismatchMessage = 'Configuration incompatible.\nAvionique : v${tempConfig.versionMajor}.${tempConfig.versionMinor} | Application (Attendue) : v$expectedConfigMajor.$expectedConfigMinor';
              ConsoleService().log('Erreur: Configuration ODB v${tempConfig.versionMajor}.${tempConfig.versionMinor} non supportée.');
              _safeNotifyListeners();
            }
          } else {
            if (payload.length == 148) {
              try {
                lastFlightStats = OdbStats.fromBytes(bytes);
                _safeNotifyListeners();
                ConsoleService().log('Événements du dernier vol reçus (${payload.length} octets).');
              } catch (e) {
                ConsoleService().log('Erreur parsing stats ODB: $e');
              }
            } else {
              ConsoleService().log('Erreur: Magic Number inconnu ou taille invalide (${payload.length} octets).');
            }
          }
        } else {
          ConsoleService().log('Erreur: Payload MSG_GENERIC_DATA trop petit (${payload.length} octets).');
        }
        
      } else if (type == 0x04) { // MSG_ACK
        int cmdAcked = bytes[0];
        int status = bytes[1];
        ConsoleService().log('ACK Reçu (CMD: 0x${cmdAcked.toRadixString(16)}, Status: ${status == 1 ? "OK" : "FAIL"})');
      }
    } catch (e) {
      ConsoleService().log('Erreur parsing binaire (Type $type): $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}