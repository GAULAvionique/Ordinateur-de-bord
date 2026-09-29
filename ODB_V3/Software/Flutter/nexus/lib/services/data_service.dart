import 'package:flutter/foundation.dart';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus/services/bluetooth_service.dart';
import 'package:nexus/services/console_service.dart';

// ============================================================================
// ========================== OUTILS BINAIRES (DRY) ===========================
// ============================================================================

class ByteCursor {
  final ByteData data;
  int offset = 0;

  ByteCursor(Uint8List bytes) : data = ByteData.sublistView(bytes);

  int readUint8() {
    final v = data.getUint8(offset);
    offset += 1;
    return v;
  }

  int readUint16() {
    final v = data.getUint16(offset, Endian.little);
    offset += 2;
    return v;
  }

  int readUint32() {
    final v = data.getUint32(offset, Endian.little);
    offset += 4;
    return v;
  }

  int readInt32() {
    final v = data.getInt32(offset, Endian.little);
    offset += 4;
    return v;
  }

  double readFloat32() {
    final v = data.getFloat32(offset, Endian.little);
    offset += 4;
    return v;
  }

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

  void writeUint8(int v) {
    data.setUint8(offset, v);
    offset += 1;
  }

  void writeUint16(int v) {
    data.setUint16(offset, v, Endian.little);
    offset += 2;
  }

  void writeUint32(int v) {
    data.setUint32(offset, v, Endian.little);
    offset += 4;
  }

  void writeInt32(int v) {
    data.setInt32(offset, v, Endian.little);
    offset += 4;
  }

  void writeFloat32(double v) {
    data.setFloat32(offset, v, Endian.little);
    offset += 4;
  }

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

int _calculateCrc32(Uint8List bytes, int length) {
  var crc = 0xFFFFFFFF;
  for (var index = 0; index < length; index++) {
    crc ^= bytes[index];
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1));
    }
  }
  return (~crc) & 0xFFFFFFFF;
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
  static const int fsmTransitionCount = 10;
  static const int serializedSize = 196;

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
  final int flightStartTimeMs;
  final List<int> fsmTransitions;
  final int missedFrames;

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
    required this.flightStartTimeMs,
    required this.fsmTransitions,
    required this.missedFrames,
  });

  factory OdbStats.fromBytes(Uint8List bytes) {
    if (bytes.length != serializedSize) {
      throw const FormatException('Invalid ODB statistics size');
    }
    final reader = ByteCursor(bytes);

    final flightId = reader.readUint32();
    final date = reader.readUint32();

    final pyros = List.generate(
        4, (_) => PyroEvent(reader.readUint8() != 0, reader.readUint32()));

    final pyrosArm = WindowEvent(
        reader.readUint8() != 0, reader.readUint32(), reader.readUint32());
    final machLock = WindowEvent(
        reader.readUint8() != 0, reader.readUint32(), reader.readUint32());

    Metric readMetric() => Metric(
        reader.readUint8() != 0, reader.readFloat32(), reader.readUint32());

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
      flightStartTimeMs: reader.readUint32(),
      fsmTransitions: List.generate(
        fsmTransitionCount,
        (_) => reader.readUint32(),
      ),
      missedFrames: reader.readUint32(),
    );
  }

  Uint8List toBytes() {
    final builder = ByteBuilder(serializedSize);
    builder.writeUint32(flightId);
    builder.writeUint32(date);
    for (final pyro in pyroEvents) {
      builder.writeUint8(pyro.fired ? 1 : 0);
      builder.writeUint32(pyro.timeMs);
    }
    void writeWindow(WindowEvent window) {
      builder.writeUint8(window.activated ? 1 : 0);
      builder.writeUint32(window.startTimeMs);
      builder.writeUint32(window.endTimeMs);
    }

    writeWindow(pyrosArm);
    writeWindow(machLock);
    void writeMetric(Metric metric) {
      builder.writeUint8(metric.valid ? 1 : 0);
      builder.writeFloat32(metric.value);
      builder.writeUint32(metric.timeMs);
    }

    for (final metric in [
      maxAltitudeGps,
      maxAltitudeBaro,
      maxAltitudeKalman,
      apogee,
      mainDeploy,
      drogueDeploy,
      maxAscendSpeed,
      maxAscendAccel,
      maxDescendSpeed,
      maxDescendAccel,
    ]) {
      writeMetric(metric);
    }
    builder.writeInt32(lastLat);
    builder.writeInt32(lastLon);
    builder.writeUint32(flightTimeMs);
    builder.writeUint32(flightStartTimeMs);
    if (fsmTransitions.length != fsmTransitionCount) {
      throw StateError('Invalid FSM transitions size');
    }
    for (final transition in fsmTransitions) {
      builder.writeUint32(transition);
    }
    builder.writeUint32(missedFrames);
    return builder.toBytes();
  }
}

class OdbConfig {
  static const int serializedSize = 99;
  static const int magicNumberSize = 4;
  static const int flightPacketSize = magicNumberSize + serializedSize;

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
  final double pyrosArmingMinAltitudeM;
  final int minNeededPyroNb;
  final List<int> pyroRoles;
  final int apogeeDetectionMode;
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
  final int crc32;

  OdbConfig({
    this.magicNumber = 0x434F4E46,
    this.versionMajor = 1,
    this.versionMinor = 3,
    this.payloadSize = serializedSize,
    required this.odbName,
    required this.stageRole,
    required this.debugMode,
    required this.flightTestMode,
    required this.axisProfile,
    required this.fireAttemptDelayMs,
    required this.pyrosArmingMinAltitudeM,
    required this.minNeededPyroNb,
    required this.pyroRoles,
    required this.apogeeDetectionMode,
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
    this.crc32 = 0,
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
      pyrosArmingMinAltitudeM: reader.readFloat32(),
      minNeededPyroNb: reader.readUint8(),
      pyroRoles: reader.readUint8Array(4),
      apogeeDetectionMode: reader.readUint8(),
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
      crc32: reader.readUint32(),
    );
  }

  OdbConfig copyWith({
    String? odbName,
    int? stageRole,
    bool? debugMode,
    bool? flightTestMode,
    int? axisProfile,
    int? fireAttemptDelayMs,
    double? pyrosArmingMinAltitudeM,
    int? minNeededPyroNb,
    List<int>? pyroRoles,
    int? apogeeDetectionMode,
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
    int? crc32,
  }) {
    return OdbConfig(
      odbName: odbName ?? this.odbName,
      stageRole: stageRole ?? this.stageRole,
      debugMode: debugMode ?? this.debugMode,
      flightTestMode: flightTestMode ?? this.flightTestMode,
      axisProfile: axisProfile ?? this.axisProfile,
      fireAttemptDelayMs: fireAttemptDelayMs ?? this.fireAttemptDelayMs,
        pyrosArmingMinAltitudeM:
          pyrosArmingMinAltitudeM ?? this.pyrosArmingMinAltitudeM,
      minNeededPyroNb: minNeededPyroNb ?? this.minNeededPyroNb,
      pyroRoles: pyroRoles ?? this.pyroRoles,
        apogeeDetectionMode:
          apogeeDetectionMode ?? this.apogeeDetectionMode,
      accZLaunchThreshold: accZLaunchThreshold ?? this.accZLaunchThreshold,
      boostPhaseVThreshold: boostPhaseVThreshold ?? this.boostPhaseVThreshold,
      apogeeDetectVThreshold:
          apogeeDetectVThreshold ?? this.apogeeDetectVThreshold,
      landingDetectVThreshold:
          landingDetectVThreshold ?? this.landingDetectVThreshold,
      landingDetectThresholdMs:
          landingDetectThresholdMs ?? this.landingDetectThresholdMs,
      apogeeFailsafeMs: apogeeFailsafeMs ?? this.apogeeFailsafeMs,
      mainDeployAltitudeThresholdM:
          mainDeployAltitudeThresholdM ?? this.mainDeployAltitudeThresholdM,
      drogueFireAttemptMaxNb:
          drogueFireAttemptMaxNb ?? this.drogueFireAttemptMaxNb,
      mainFireAttemptMaxNb: mainFireAttemptMaxNb ?? this.mainFireAttemptMaxNb,
      enableBuzzer: enableBuzzer ?? this.enableBuzzer,
      buzzerReportToneHz: buzzerReportToneHz ?? this.buzzerReportToneHz,
      idefixFrequencyHz: idefixFrequencyHz ?? this.idefixFrequencyHz,
      crc32: crc32 ?? this.crc32,
    );
  }

  Uint8List toBytes() {
    final writer = ByteBuilder(serializedSize);
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
    writer.writeFloat32(pyrosArmingMinAltitudeM);
    writer.writeUint8(minNeededPyroNb);
    writer.writeUint8Array(pyroRoles);
    writer.writeUint8(apogeeDetectionMode);
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
    final bytes = writer.toBytes();
    ByteData.sublistView(bytes).setUint32(
      serializedSize - 4,
      _calculateCrc32(bytes, serializedSize - 4),
      Endian.little,
    );
    return bytes;
  }

  bool get hasValidCrc {
    final bytes = toBytes();
    final calculatedCrc = ByteData.sublistView(bytes).getUint32(
      serializedSize - 4,
      Endian.little,
    );
    return crc32 == calculatedCrc;
  }
}

class OdbTelemetry {
  static const int serializedSize = 144;

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
  final int barometricTrend;

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
        kalmanV = reader.readFloat32(),
        barometricTrend = reader.readUint8() {
      reader.readUint8Array(3); // End padding
  }
}

enum SensorState { unknown, ok, error }

enum RadioState { disconnected, connecting, connected }

class FlightDataSample {
  FlightDataSample(this.telemetry, this.bytes);

  final OdbTelemetry telemetry;
  final Uint8List bytes;
}

// ============================================================================
// ========================== GESTIONNAIRE PRINCIPAL ==========================
// ============================================================================

class DataServiceManager with ChangeNotifier {
  static const int chunkHeaderSize = 4;
  static const int chunkMinimumSize = chunkHeaderSize + 1;
  static const int ackMinimumSize = 2;
  static const int flightIdSize = 4;
  static const int flightDataAckSize = ackMinimumSize + 2 + flightIdSize;

  // Types de messages entrants.
  static const int msgTypeTelemetry = 0x01;
  static const int msgTypeConfig = 0x02;
  static const int msgTypeCommand = 0x03;
  static const int msgTypeAck = 0x04;
  static const int msgTypeStatsChunk = 0x05;
  static const int msgTypeDataChunk = 0x06;

  // Types de commandes sortantes.
  static const int cmdTypeAction = 0x03;
  static const int cmdTypeConfig = 0x02;

  // Actions.
  static const int actionPing = 0x01;
  static const int actionArm = 0x02;
  static const int actionFire = 0x03;
  static const int actionSaveConfig = 0x04;
  static const int actionResetConfig = 0x05;
  static const int actionRefresh = 0x06;
  static const int actionResetMemory = 0x07;
  static const int actionRequestFlightStats = 0x08;
  static const int actionResetFlights = 0x09;
  static const int actionPlayMelody = 0x0A;
  static const int actionSetReady = 0x0B;
  static const int actionTestArmingModule = 0x0C;
  static const int actionTestPyrosContinuity = 0x0D;
  static const int actionSetSubArmed = 0x0E;
  static const int actionSetSubBoost = 0x0F;
  static const int actionSetSubFast = 0x10;
  static const int actionSetSubCoast = 0x11;
  static const int actionSetSubDrogue = 0x12;
  static const int actionSetSubMain = 0x13;
  static const int actionSetSubLanded = 0x14;
  static const int actionTestMachLock = 0x15;
  static const int actionRequestFlightData = 0x16;
  static const int actionCancelFlightData = 0x17;

  static const int configMagicNumber = 0x434F4E46;

  static const int stageRoleBooster = 2;
  static const int stageRoleSustainer = 3;
  static const int apogeeDetectionAuto = 0;
  static const int apogeeDetectionKalman = 1;
  static const int apogeeDetectionBarometric = 2;
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
  static const int expectedConfigMinor = 3;
  static const int expectedTelemetryMajor = 1;
  static const int expectedTelemetryMinor = 4;

  final BluetoothServiceManager btService;
  DataServiceManager(this.btService) {
    _loadSavedFlightStats();
  }
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
  final List<OdbStats> flightStats = [];
  final List<OdbStats> savedFlightStats = [];
  final Map<int, OdbConfig> flightConfigs = {};
  final Map<int, List<FlightDataSample>> savedFlightData = {};
  final Map<int, Map<int, List<int>>> _flightDataChunks = {};
  OdbStats? _pendingFlightSave;
  bool isLoadingFlightData = false;
  bool _isDrainingCanceledFlightData = false;
  int _flightDataCancelGeneration = 0;
  bool get isStoppingFlightData => _isDrainingCanceledFlightData;
  int? flightDataFlightId;
  int flightDataSamplesReceived = 0;
  int? flightDataSamplesTotal;
  int flightDataChunksReceived = 0;
  final Map<int, Map<int, List<int>>> _flightStatsChunks = {};
  bool isLoadingFlightStats = false;
  String? flightStatsError;
  int? flightStatsFound;
  int _flightStatsRequestId = 0;

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

  String get odbFrameVersion => telemetry != null
      ? 'v${telemetry!.versionMajor}.${telemetry!.versionMinor}'
      : '';
  String get odbConfigFrameVersion =>
      config != null ? 'v${config!.versionMajor}.${config!.versionMinor}' : '';
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
  int get barometricTrend => telemetry?.barometricTrend ?? 0;
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
  int get apogeeDetectionMode =>
      config?.apogeeDetectionMode ?? apogeeDetectionKalman;
  double get mainDeployAltitudeThresholdM =>
      config?.mainDeployAltitudeThresholdM ?? 0.0;
  double get landingDetectVThreshold => config?.landingDetectVThreshold ?? 0.0;
  int get buzzerReportToneHz => config?.buzzerReportToneHz ?? 0;
  int get landingDetectThresholdMs => config?.landingDetectThresholdMs ?? 0;
  int get fireAttemptDelayMs => config?.fireAttemptDelayMs ?? 0;
  double get pyrosArmingMinAltitudeM =>
      config?.pyrosArmingMinAltitudeM ?? 0.0;
  int get apogeeFailsafeMs => config?.apogeeFailsafeMs ?? 0;
  int get idefixFrequencyHz => config?.idefixFrequencyHz ?? 0;
  List<int> get pyroRoles => config?.pyroRoles ?? List.filled(4, 0);

  // ---------- Setters UI ----------

  set odbName(String value) {
    config = config?.copyWith(odbName: value);
    _safeNotifyListeners();
  }

  set stageRole(int value) {
    config = config?.copyWith(stageRole: value);
    _safeNotifyListeners();
  }

  set debugMode(bool value) {
    config = config?.copyWith(debugMode: value);
    _safeNotifyListeners();
  }

  set flightTestMode(bool value) {
    config = config?.copyWith(flightTestMode: value);
    _safeNotifyListeners();
  }

  set axisProfile(int value) {
    config = config?.copyWith(axisProfile: value);
    _safeNotifyListeners();
  }

  set enableBuzzer(bool value) {
    config = config?.copyWith(enableBuzzer: value);
    _safeNotifyListeners();
  }

  set minNeededPyroNb(int value) {
    config = config?.copyWith(minNeededPyroNb: value);
    _safeNotifyListeners();
  }

  set drogueFireAttemptMaxNb(int value) {
    config = config?.copyWith(drogueFireAttemptMaxNb: value);
    _safeNotifyListeners();
  }

  set mainFireAttemptMaxNb(int value) {
    config = config?.copyWith(mainFireAttemptMaxNb: value);
    _safeNotifyListeners();
  }

  set accZLaunchThreshold(double value) {
    config = config?.copyWith(accZLaunchThreshold: value);
    _safeNotifyListeners();
  }

  set boostPhaseVThreshold(double value) {
    config = config?.copyWith(boostPhaseVThreshold: value);
    _safeNotifyListeners();
  }

  set apogeeDetectVThreshold(double value) {
    config = config?.copyWith(apogeeDetectVThreshold: value);
    _safeNotifyListeners();
  }

  set mainDeployAltitudeThresholdM(double value) {
    config = config?.copyWith(mainDeployAltitudeThresholdM: value);
    _safeNotifyListeners();
  }

  set landingDetectVThreshold(double value) {
    config = config?.copyWith(landingDetectVThreshold: value);
    _safeNotifyListeners();
  }

  set buzzerReportToneHz(int value) {
    config = config?.copyWith(buzzerReportToneHz: value);
    _safeNotifyListeners();
  }

  set landingDetectThresholdMs(int value) {
    config = config?.copyWith(landingDetectThresholdMs: value);
    _safeNotifyListeners();
  }

  set fireAttemptDelayMs(int value) {
    config = config?.copyWith(fireAttemptDelayMs: value);
    _safeNotifyListeners();
  }

  set pyrosArmingMinAltitudeM(double value) {
    config = config?.copyWith(pyrosArmingMinAltitudeM: value);
    _safeNotifyListeners();
  }

  set apogeeDetectionMode(int value) {
    config = config?.copyWith(apogeeDetectionMode: value);
    _safeNotifyListeners();
  }

  set apogeeFailsafeMs(int value) {
    config = config?.copyWith(apogeeFailsafeMs: value);
    _safeNotifyListeners();
  }

  set idefixFrequencyHz(int value) {
    config = config?.copyWith(idefixFrequencyHz: value);
    _safeNotifyListeners();
  }

  set pyroRoles(List<int> value) {
    config = config?.copyWith(pyroRoles: value);
    _safeNotifyListeners();
  }

  // ---------- États des capteurs dynamiques ----------

  RadioState get radioState => (systemStates & (1 << 5)) != 0
      ? RadioState.connected
      : RadioState.disconnected;
  SensorState get gpsSensorState =>
      (systemStates & (1 << 8)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get barometerSensorState =>
      (systemStates & (1 << 7)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get imuSensorState =>
      (systemStates & (1 << 6)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get accHighGSensorState =>
      (systemStates & (1 << 9)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get temperatureSensorState =>
      (systemStates & (1 << 10)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get sdSensorState =>
      (systemStates & (1 << 11)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get flashSensorState =>
      (systemStates & (1 << 12)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get btModuleState =>
      (systemStates & (1 << 13)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get idefixSensorState =>
      (systemStates & (1 << 14)) != 0 ? SensorState.ok : SensorState.error;
  SensorState get batterySensorState =>
      batteryVoltage > 0 ? SensorState.ok : SensorState.error;
  bool get goodPowerState => batteryVoltage >= 5.0;
  SensorState get pyroArmingModuleState =>
      (systemStates & (1 << 4)) != 0 ? SensorState.ok : SensorState.error;

  bool get pyrosArmed => eventPyrosArmed;
  List<bool> get pyros {
    return [
      ((systemStates & (1 << 3)) != 0) && !eventPyro1Fired,
      ((systemStates & (1 << 2)) != 0) && !eventPyro2Fired,
      ((systemStates & (1 << 1)) != 0) && !eventPyro3Fired,
      ((systemStates & (1 << 0)) != 0) && !eventPyro4Fired,
    ];
  }

  double pressureToAltitude(double pressureHpa,
      [double seaLevelHpa = 1013.25]) {
    if (pressureHpa <= 0 || seaLevelHpa <= 0) return 0.0;
    final ratio = pressureHpa / seaLevelHpa;
    final alt = 44330.0 * (1 - pow(ratio, 1 / 5.255));
    return alt.isFinite ? alt.toDouble() : 0.0;
  }

  double get barometerAlt => pressureToAltitude(barometerPressure);

  int get pyrosActiveCount => pyros.where((p) => p).length;
  String get pyrosSummary => pyros.map((p) => p ? '1' : '0').join(',');
  static const List<String> _pyroRoleNames = [
    'None',
    'Main',
    'Drogue',
    'Main #2',
    'Drogue #1'
  ];

  String pyroRoleLabel(int pyroIndex, {bool connected = true}) {
    if (!connected) return '-';
    final roleIndex = pyroIndex < pyroRoles.length ? pyroRoles[pyroIndex] : 0;
    if (roleIndex < 0 || roleIndex >= _pyroRoleNames.length) {
      return _pyroRoleNames.first;
    }
    return _pyroRoleNames[roleIndex];
  }

  bool get eventPyrosArmed => (eventStates & eventFlagPyrosArmed) != 0;
  bool get eventPyro1Fired => (eventStates & eventFlagPyro1Fired) != 0;
  bool get eventPyro2Fired => (eventStates & eventFlagPyro2Fired) != 0;
  bool get eventPyro3Fired => (eventStates & eventFlagPyro3Fired) != 0;
  bool get eventPyro4Fired => (eventStates & eventFlagPyro4Fired) != 0;
  bool get eventApogeeDetected => (eventStates & eventFlagApogeeDetected) != 0;
  bool get eventMainDeployed => (eventStates & eventFlagMainDeployed) != 0;
  bool get eventDrogueDeployed => (eventStates & eventFlagDrogueDeployed) != 0;
  bool get eventMachLockEnabled =>
      (eventStates & eventFlagMachLockEnabled) != 0;

  String get timeBootFormatted {
    if (timeBootMs <= 0) return '00h:00m:00s:00ms';
    final hours = timeBootMs ~/ 3600000;
    final minutes = (timeBootMs % 3600000) ~/ 60000;
    final seconds = (timeBootMs % 60000) ~/ 1000;
    final milliseconds = timeBootMs % 1000;
    return '${hours.toString().padLeft(2, '0')}h:${minutes.toString().padLeft(2, '0')}m:${seconds.toString().padLeft(2, '0')}s:${milliseconds.toString().padLeft(2, '0')}ms';
  }

  bool get odbSensorState => (temperatureSensorState == SensorState.ok &&
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
  bool get hasValidGpsFix =>
      hasConnection && gpsSensorState == SensorState.ok && gpsFix > 0;

  void resetOdbConfig() {
    telemetry = null;
    config = null;
    lastFlightStats = null;
    flightStats.clear();
    _flightStatsChunks.clear();
    isLoadingFlightStats = false;
    flightStatsError = null;
    flightStatsFound = null;
    clearVersionMismatch();
    _safeNotifyListeners();
  }

  Future<void> _loadSavedFlightStats() async {
    final preferences = await SharedPreferences.getInstance();
    final records = preferences.getStringList('saved_flight_stats') ?? [];
    for (final record in records) {
      try {
        savedFlightStats
            .add(OdbStats.fromBytes(Uint8List.fromList(base64Decode(record))));
      } catch (_) {}
    }
    for (final stats in savedFlightStats) {
      final configRecord =
          preferences.getString('saved_flight_config_${stats.flightId}');
      if (configRecord != null) {
        try {
          flightConfigs[stats.flightId] = OdbConfig.fromBytes(
            Uint8List.fromList(base64Decode(configRecord)),
          );
        } catch (_) {}
      }
      final samples =
          preferences.getStringList('saved_flight_data_${stats.flightId}') ??
              [];
      savedFlightData[stats.flightId] = samples.map((record) {
        final raw = Uint8List.fromList(base64Decode(record));
        return FlightDataSample(OdbTelemetry.fromBytes(raw), raw);
      }).toList();
    }
    savedFlightStats
        .sort((first, second) => second.flightId.compareTo(first.flightId));
    _safeNotifyListeners();
  }

  bool isFlightSaved(OdbStats stats) => savedFlightStats.any(
        (saved) => saved.flightId == stats.flightId && saved.date == stats.date,
      );

  Future<void> saveFlightStats(OdbStats stats) async {
    if (!isFlightSaved(stats)) savedFlightStats.add(stats);
    savedFlightStats
        .sort((first, second) => second.flightId.compareTo(first.flightId));
    await _persistSavedFlightStats();
    _safeNotifyListeners();
  }

  Future requestFlightDataForSave(OdbStats stats) async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }

    if (isLoadingFlightData) {
      ConsoleService().log('Un téléchargement de vol est déjà en cours.');
      return;
    }

    if (_isDrainingCanceledFlightData) {
      ConsoleService().log(
          'Le téléchargement précédent est encore en cours d’arrêt.');
      return;
    }

    if (isFlightSaved(stats)) {
      ConsoleService().log('Le vol #${stats.flightId} est déjà sauvegardé.');
      return;
    }

    _pendingFlightSave = stats;
    _isDrainingCanceledFlightData = false;
    _flightDataChunks.clear();
    isLoadingFlightData = true;
    flightDataFlightId = stats.flightId;
    flightDataSamplesReceived = 0;
    flightDataSamplesTotal = null;
    flightDataChunksReceived = 0;
    savedFlightData.remove(stats.flightId);
    _safeNotifyListeners();

    final id = stats.flightId;
    final payload = [
      actionRequestFlightData,
      id & 0xFF,
      (id >> 8) & 0xFF,
      (id >> 16) & 0xFF,
      (id >> 24) & 0xFF,
    ];

    await btService.sendBinary(cmdTypeAction, payload);
    ConsoleService().log(
        'Demande de téléchargement des données du vol #${stats.flightId} envoyée.');
  }

  Future<void> cancelFlightDataDownload() async {
    if (!isLoadingFlightData) return;

    final canceledFlightId = flightDataFlightId;
    isLoadingFlightData = false;
    flightDataSamplesReceived = 0;
    flightDataSamplesTotal = null;
    flightDataChunksReceived = 0;
    _flightDataChunks.clear();
    _isDrainingCanceledFlightData = true;
    final cancelGeneration = ++_flightDataCancelGeneration;
    if (canceledFlightId != null) {
      savedFlightData.remove(canceledFlightId);
    }
    ConsoleService().log('Téléchargement du vol annulé.');
    _safeNotifyListeners();

    if (!hasConnection) {
      _pendingFlightSave = null;
      flightDataFlightId = null;
      _isDrainingCanceledFlightData = false;
      return;
    }

    await btService.sendBinary(cmdTypeAction, [actionCancelFlightData]);

    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!_isDrainingCanceledFlightData ||
          cancelGeneration != _flightDataCancelGeneration) {
        return;
      }
      _pendingFlightSave = null;
      flightDataFlightId = null;
      _isDrainingCanceledFlightData = false;
      ConsoleService().log(
          'Délai d’arrêt dépassé; nouveau téléchargement autorisé.');
      _safeNotifyListeners();
    });
  }

  Future<void> deleteSavedFlightStats(OdbStats stats) async {
    savedFlightStats.removeWhere(
      (saved) => saved.flightId == stats.flightId && saved.date == stats.date,
    );
    savedFlightData.remove(stats.flightId);
    flightConfigs.remove(stats.flightId);
    await _persistSavedFlightStats();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('saved_flight_data_${stats.flightId}');
    await preferences.remove('saved_flight_config_${stats.flightId}');
    _safeNotifyListeners();
  }

  Future<void> clearSavedFlightStats() async {
    savedFlightStats.clear();
    savedFlightData.clear();
    flightConfigs.clear();
    await _persistSavedFlightStats();
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith('saved_flight_data_'));
    for (final key in keys) {
      await preferences.remove(key);
    }
    final configKeys = preferences
        .getKeys()
        .where((key) => key.startsWith('saved_flight_config_'));
    for (final key in configKeys) {
      await preferences.remove(key);
    }
    _safeNotifyListeners();
  }

  Future<void> _persistSavedFlightStats() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'saved_flight_stats',
      savedFlightStats.map((stats) => base64Encode(stats.toBytes())).toList(),
    );
  }

  Future<void> _persistSavedFlightData(int flightId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'saved_flight_data_$flightId',
      (savedFlightData[flightId] ?? [])
          .map((sample) => base64Encode(sample.bytes))
          .toList(),
    );
  }

  Future<void> _persistSavedFlightConfig(int flightId) async {
    final config = flightConfigs[flightId];
    if (config == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'saved_flight_config_$flightId',
      base64Encode(config.toBytes()),
    );
  }

  // ---------- COMMANDES ----------

  Future<void> refreshOdb() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionRefresh]);
  }

  Future<void> commandPing() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionPing]);
  }

  Future<void> commandPlayMelody() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionPlayMelody]);
    ConsoleService().log('Demande de lecture de la mélodie envoyée.');
  }

  Future<void> commandArm(bool arm) async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionArm, arm ? 1 : 0]);
  }

  Future<void> commandFire(int pyroIndex) async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionFire, pyroIndex]);
  }

  Future<void> applyOdbSettings(OdbConfig newConfig) async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    if (hasVersionMismatch) {
      ConsoleService().log('Envoi bloqué : Conflit de version détecté.');
      return;
    }

    await btService.sendBinary(cmdTypeConfig, newConfig.toBytes());
    ConsoleService().log('Envoi de la nouvelle configuration ...');

    await Future.delayed(const Duration(milliseconds: 200));

    await btService.sendBinary(cmdTypeAction, [actionSaveConfig]);
    ConsoleService()
        .log('Demande de sauvegarde Flash et de redémarrage envoyée.');
  }

  Future<void> resetOdbSettingsToDefault() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionResetConfig]);
    ConsoleService()
        .log('Demande de réinitialisation de la configuration envoyée.');
  }

  Future<void> resetOdbFlights() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionResetFlights]);
    ConsoleService()
        .log('Demande de réinitialisation des données de vol envoyée.');
  }

  Future<void> resetOdbMemory() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionResetMemory]);
    ConsoleService().log('Demande de réinitialisation usine envoyée.');
  }

  Future<void> requestLastFlightEvents() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    flightStats.clear();
    _flightStatsChunks.clear();
    lastFlightStats = null;
    isLoadingFlightStats = true;
    flightStatsError = null;
    flightStatsFound = null;
    final requestId = ++_flightStatsRequestId;
    _safeNotifyListeners();
    ConsoleService().log('Demande des événements de tous les vols...');
    await btService.sendBinary(cmdTypeAction, [actionRequestFlightStats]);
    Future<void>.delayed(const Duration(seconds: 300), () {
      if (isLoadingFlightStats && requestId == _flightStatsRequestId) {
        isLoadingFlightStats = false;
        flightStatsError =
            'Le délai de récupération des statistiques est dépassé.';
        ConsoleService()
            .log('Échec: aucun retour de l’ODB pour les statistiques.');
        _safeNotifyListeners();
      }
    });
  }

  void cancelFlightStatsRequest() {
    if (!isLoadingFlightStats) return;
    isLoadingFlightStats = false;
    _flightStatsRequestId++;
    _flightStatsChunks.clear();
    flightStatsError = null;
    ConsoleService().log('Recherche des événements arrêtée.');
    _safeNotifyListeners();
  }

  Future<void> setReadyFlight() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionSetReady]);
    ConsoleService().log('Demande de mise en départ envoyée.');
  }

  Future<void> testArmingModule() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionTestArmingModule]);
    ConsoleService().log('Demande de test du module d\'armement envoyée.');
  }

  Future<void> testPyrosContinuity() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionTestPyrosContinuity]);
    ConsoleService().log('Demande de test de la continuité des pyros envoyée.');
  }

  Future<void> setSubArmed() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionSetSubArmed]);
    ConsoleService().log('Demande de mise en sub armed envoyée.');
  }

  Future<void> setSubBoost() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionSetSubBoost]);
    ConsoleService().log('Demande de mise en sub boost envoyée.');
  }

  Future<void> setSubFast() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionSetSubFast]);
    ConsoleService().log('Demande de mise en sub fast envoyée.');
  }

  Future<void> setSubCoast() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionSetSubCoast]);
    ConsoleService().log('Demande de mise en sub coast envoyée.');
  }

  Future<void> setSubDrogue() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionSetSubDrogue]);
    ConsoleService().log('Demande de mise en sub drogue envoyée.');
  }

  Future<void> setSubMain() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionSetSubMain]);
    ConsoleService().log('Demande de mise en sub main envoyée.');
  }

  Future<void> setSubLanded() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionSetSubLanded]);
    ConsoleService().log('Demande de mise en sub landed envoyée.');
  }

  Future<void> testMachLock() async {
    if (!hasConnection) {
      ConsoleService().log('Aucune connexion Bluetooth avec l\'ODB');
      return;
    }
    await btService.sendBinary(cmdTypeAction, [actionTestMachLock]);
    ConsoleService().log('Demande de test mach lock envoyée.');
  }

  // ---------- PARSER ----------

  Future<void> parseBinaryMessage(int type, List<int> payload) async {
    if (_isDisposed) return;
    final bytes = Uint8List.fromList(payload);

    try {
      switch (type) {
        case msgTypeTelemetry:
          _handleTelemetry(bytes);
          break;
        case msgTypeConfig:
          _handleGenericData(bytes, payload.length);
          break;
        case msgTypeCommand:
          break;
        case msgTypeAck:
          await _handleAck(bytes);
          break;
        case msgTypeStatsChunk:
          if (isLoadingFlightStats) _parseFlightStatsChunk(bytes);
          break;
        case msgTypeDataChunk:
          _parseFlightDataChunk(bytes);
          break;
        default:
          ConsoleService().log('Type de message inconnu : $type');
      }
    } catch (e) {
      ConsoleService().log('Erreur parsing binaire (Type $type): $e');
    }
  }

  void _handleTelemetry(Uint8List bytes) {
    telemetry = OdbTelemetry.fromBytes(bytes);
    if (bytes.length != telemetry!.payloadSize) {
      ConsoleService().log(
          'Erreur: taille télémétrie invalide (${bytes.length} octets, déclarée ${telemetry!.payloadSize}).');
      telemetry = null;
      _safeNotifyListeners();
      return;
    }
    if (telemetry!.versionMajor != expectedTelemetryMajor ||
        telemetry!.versionMinor != expectedTelemetryMinor) {
      hasVersionMismatch = true;
      versionMismatchMessage =
          'Télémétrie incompatible.\nAvionique : v${telemetry!.versionMajor}.${telemetry!.versionMinor} | Application (Attendue) : v$expectedTelemetryMajor.$expectedTelemetryMinor';
      ConsoleService().log(
          'Erreur: Télémétrie v${telemetry!.versionMajor}.${telemetry!.versionMinor} non supportée.');
      _safeNotifyListeners();
      return;
    }
    clearVersionMismatch();
    _safeNotifyListeners();
  }

  void _handleGenericData(Uint8List bytes, int payloadLength) {
    if (payloadLength < 4) {
      ConsoleService().log(
          'Erreur: Payload MSG_GENERIC_DATA trop petit ($payloadLength octets).');
      return;
    }
    final magicNumber = ByteData.sublistView(bytes).getUint32(0, Endian.little);
    if (magicNumber == configMagicNumber) {
      final isFlightConfig =
          payloadLength == OdbConfig.flightPacketSize &&
            _pendingFlightSave != null &&
            isLoadingFlightData;
      if (payloadLength != OdbConfig.serializedSize && !isFlightConfig) {
      ConsoleService().log('Configuration de vol ignorée hors téléchargement.');
      return;
      }
        final configBytes = isFlightConfig
        ? bytes.sublist(
          OdbConfig.magicNumberSize, OdbConfig.flightPacketSize)
          : bytes;
      final tempConfig = OdbConfig.fromBytes(configBytes);
      if (!tempConfig.hasValidCrc) {
        ConsoleService().log('Configuration ODB rejetée: CRC32 invalide.');
        return;
      }
      if (tempConfig.versionMajor == expectedConfigMajor &&
          tempConfig.versionMinor == expectedConfigMinor) {
        if (isFlightConfig) {
          flightConfigs[_pendingFlightSave!.flightId] = tempConfig;
          ConsoleService().log(
              'Configuration historique du vol #${_pendingFlightSave!.flightId} reçue.');
        } else {
          config = tempConfig;
          ConsoleService()
              .log('Configuration ODB lue et synchronisée avec succès !');
        }
        clearVersionMismatch();
        _safeNotifyListeners();
      } else {
        hasVersionMismatch = true;
        versionMismatchMessage =
            'Configuration incompatible.\nAvionique : v${tempConfig.versionMajor}.${tempConfig.versionMinor} | Application (Attendue) : v$expectedConfigMajor.$expectedConfigMinor';
        ConsoleService().log(
            'Erreur: Configuration ODB v${tempConfig.versionMajor}.${tempConfig.versionMinor} non supportée.');
        _safeNotifyListeners();
      }
      return;
    }
    if (payloadLength == OdbStats.serializedSize) {
      try {
        final stats = OdbStats.fromBytes(bytes);
        flightStats.add(stats);
        lastFlightStats = stats;
        _safeNotifyListeners();
        ConsoleService().log(
            'Statistiques du vol #${stats.flightId} reçues ($payloadLength octets).');
      } catch (e) {
        flightStatsError = 'Impossible de lire les statistiques reçues.';
        ConsoleService().log('Erreur parsing stats ODB: $e');
        _safeNotifyListeners();
      }
    } else {
      flightStatsError = 'Réponse de l’ODB invalide ($payloadLength octets).';
      ConsoleService().log(
          'Erreur: Magic Number inconnu ou taille invalide ($payloadLength octets).');
      _safeNotifyListeners();
    }
  }

  Future<void> _handleAck(Uint8List bytes) async {
    if (bytes.length < ackMinimumSize) return;
    final cmdAcked = bytes[0];
    final status = bytes[1];
    if (cmdAcked == actionRequestFlightStats) {
      isLoadingFlightStats = false;
      if (status != 1 && flightStatsError == null) {
        flightStatsError =
            'L’ODB n’a pas pu récupérer les statistiques en mémoire.';
      } else if (status == 1 && flightStats.isEmpty) {
        flightStatsError = null;
      }
      _safeNotifyListeners();
      if (bytes.length >= 3) {
        flightStatsFound = bytes[2];
        _safeNotifyListeners();
        ConsoleService().log(
            'ODB: ${bytes[2]} vol(s) trouvé(s), ${flightStats.length} reçu(s).');
      }
    } else if (cmdAcked == actionRequestFlightData &&
        _pendingFlightSave != null) {
      if (!isLoadingFlightData) {
        if (status == 0 || status == 1) {
          _pendingFlightSave = null;
          flightDataFlightId = null;
          _isDrainingCanceledFlightData = false;
          _flightDataChunks.clear();
          ConsoleService().log(
              'Transmission du vol annulé terminée côté ODB.');
          _safeNotifyListeners();
        }
        return;
      }
      final stats = _pendingFlightSave!;
      if (status == 2) {
        flightDataSamplesTotal = bytes.length >= ackMinimumSize + 2
            ? ByteData.sublistView(bytes).getUint16(2, Endian.little)
            : 0;
        ConsoleService().log(
            'Vol #${stats.flightId}: $flightDataSamplesTotal échantillons à transférer.');
        _safeNotifyListeners();
        return;
      }
      if (status == 1) {
        final samples = savedFlightData[stats.flightId] ?? [];
        await saveFlightStats(stats);
        await _persistSavedFlightData(stats.flightId);
        await _persistSavedFlightConfig(stats.flightId);
        final receivedFlightId = bytes.length >= flightDataAckSize
            ? ByteData.sublistView(bytes).getUint32(4, Endian.little)
            : stats.flightId;
        ConsoleService().log(
            'Données du vol #$receivedFlightId sauvegardées (${samples.length} échantillons, $flightDataChunksReceived morceaux).');
      } else {
        ConsoleService()
            .log('Échec du téléchargement du vol #${stats.flightId}.');
      }
      isLoadingFlightData = false;
      _pendingFlightSave = null;
      flightDataFlightId = null;
      _isDrainingCanceledFlightData = false;
      _flightDataChunks.clear();
      _safeNotifyListeners();
    }
    ConsoleService().log(
        'ACK Reçu (CMD: 0x${cmdAcked.toRadixString(16)}, Status: ${status == 1 ? "OK" : "FAIL"})');
  }

  void _parseFlightDataChunk(Uint8List bytes) {
    if (!isLoadingFlightData ||
        _pendingFlightSave == null ||
        bytes.length < chunkHeaderSize) {
      return;
    }
    flightDataChunksReceived++;
    final sampleIndex = bytes[0] | (bytes[1] << 8);
    final chunkIndex = bytes[2];
    final chunkCount = bytes[3];
    if (chunkCount == 0 ||
        chunkIndex >= chunkCount ||
        bytes.length < chunkMinimumSize) {
      return;
    }
    final chunks = _flightDataChunks.putIfAbsent(sampleIndex, () => {});
    chunks[chunkIndex] = bytes.sublist(chunkHeaderSize);
    if (chunks.length != chunkCount) return;
    final sampleBytes = <int>[];
    for (var index = 0; index < chunkCount; index++) {
      final chunk = chunks[index];
      if (chunk == null) return;
      sampleBytes.addAll(chunk);
    }
    _flightDataChunks.remove(sampleIndex);
    try {
      final raw = Uint8List.fromList(sampleBytes);
      if (raw.length != OdbTelemetry.serializedSize) {
        ConsoleService().log(
            'Échantillon $sampleIndex incomplet: ${raw.length}/${OdbTelemetry.serializedSize} octets.');
        return;
      }
      final telemetry = OdbTelemetry.fromBytes(raw);
      final flightId = _pendingFlightSave!.flightId;
      savedFlightData
          .putIfAbsent(flightId, () => [])
          .add(FlightDataSample(telemetry, raw));
      flightDataSamplesReceived++;
      _safeNotifyListeners();
    } catch (error) {
      ConsoleService().log('Erreur parsing donnée de vol: $error');
    }
  }

  void _parseFlightStatsChunk(Uint8List bytes) {
    if (bytes.length < chunkHeaderSize) {
      flightStatsError = 'Trame de statistiques incomplète.';
      _safeNotifyListeners();
      return;
    }

    final flightIndex = bytes[0];
    final chunkIndex = bytes[1];
    final chunkCount = bytes[2];
    final chunkLength = bytes[3];
    if (chunkCount == 0 ||
        chunkIndex >= chunkCount ||
        chunkLength > bytes.length - chunkHeaderSize) {
      flightStatsError = 'Trame de statistiques invalide.';
      _safeNotifyListeners();
      return;
    }

    final chunks = _flightStatsChunks.putIfAbsent(flightIndex, () => {});
    chunks[chunkIndex] = bytes.sublist(
      chunkHeaderSize, chunkHeaderSize + chunkLength);
    if (chunks.length != chunkCount) return;

    final completeStats = <int>[];
    for (var index = 0; index < chunkCount; index++) {
      final chunk = chunks[index];
      if (chunk == null) return;
      completeStats.addAll(chunk);
    }
    _flightStatsChunks.remove(flightIndex);

    try {
      final stats = OdbStats.fromBytes(Uint8List.fromList(completeStats));
      flightStats.add(stats);
      lastFlightStats = stats;
      _safeNotifyListeners();
      ConsoleService().log('Statistiques du vol #${stats.flightId} reçues.');
    } catch (e) {
      flightStatsError = 'Impossible de lire les statistiques reçues.';
      ConsoleService().log('Erreur parsing stats ODB: $e');
      _safeNotifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

extension DataServiceDisplay on DataServiceManager {
  double get batteryPercent => batteryVoltageMax > 0
      ? (batteryVoltage / batteryVoltageMax * 100).clamp(0, 100)
      : 0.0;
  String get batteryVoltageDisplay =>
      batteryVoltage > 0 ? '${batteryVoltage.toStringAsFixed(2)} V' : '—';
  String get batteryVoltageMaxDisplay =>
      batteryVoltageMax > 0 ? '${batteryVoltageMax.toStringAsFixed(2)} V' : '—';
  String get batteryPercentDisplay =>
      batteryVoltageMax > 0 ? '${batteryPercent.toStringAsFixed(1)}%' : '—';
  String get temperatureDisplay =>
      temperature != 0.0 ? '${temperature.toStringAsFixed(2)} °C' : '—';

  String pyroVoltageDisplay(int pyroIndex, {required bool connected}) {
    if (!connected || pyroIndex < 0 || pyroIndex >= pyrosMv.length) return '—';
    return '${(pyrosMv[pyroIndex] / 1000.0).toStringAsFixed(2)} V';
  }

  String get altitudeDisplay {
    if (!hasConnection) return '—';
    if (barometerSensorState == SensorState.ok) {
      return '${barometerAlt.toStringAsFixed(0)} m';
    }
    if (hasValidGpsFix) return '${gpsAlt.toStringAsFixed(0)} m';
    return '—';
  }

  String pyroDisplayLabel(int pyroIndex, {required bool connected}) => connected
      ? 'Pyro ${pyroIndex + 1} (${pyroRoleLabel(pyroIndex, connected: connected)})'
      : 'Pyro ${pyroIndex + 1} (-)';

  String get missionStateDisplay {
    if (missionState < 0) return '—';
    final globalState = (missionState >> 4) & 0x0F;
    final subState = missionState & 0x0F;
    switch (globalState) {
      case 0:
        switch (subState) {
          case 0:
            return 'PREFLIGHT (Static)';
          case 1:
            return 'PREFLIGHT (Pyros Test)';
          case 2:
            return 'PREFLIGHT (Ready)';
          default:
            return 'PREFLIGHT';
        }
      case 1:
        return 'ARMED';
      case 2:
        switch (subState) {
          case 0:
            return 'INFLIGHT (Boost)';
          case 1:
            return 'INFLIGHT (Fast)';
          case 2:
            return 'INFLIGHT (Coast)';
          case 3:
            return 'INFLIGHT (Drogue)';
          case 4:
            return 'INFLIGHT (Main)';
          case 5:
            return 'INFLIGHT (Landed)';
          default:
            return 'INFLIGHT';
        }
      case 3:
        return 'POSTFLIGHT';
      default:
        return '—';
    }
  }

  String get systemStateDisplay =>
      systemStates > 0 ? 'Flags $systemStates' : '—';
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

  String get gpsVelocityDisplay =>
      hasValidGpsFix ? '${gpsVelocity.toStringAsFixed(1)} m/s' : '—';
  String get gpsCourseDisplay =>
      hasValidGpsFix ? '${gpsCourse.toStringAsFixed(0)}°' : '—';
  String get missionStatus =>
      missionStateDisplay != '—' ? missionStateDisplay : systemStateDisplay;
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
  String get imuAccVerticalDisplay =>
      hasConnection && imuSensorState == SensorState.ok
          ? '${imuAccVertical.toStringAsFixed(2)} m/s²'
          : '—';
  String get highGAccVerticalDisplay =>
      hasConnection && accHighGSensorState == SensorState.ok
          ? '${highGAccVertical.toStringAsFixed(2)} m/s²'
          : '—';
  String get pressureDisplay =>
      hasConnection && barometerSensorState == SensorState.ok
          ? barometerPressure.toStringAsFixed(2)
          : '—';
  String get altitudeMslDisplay =>
      hasConnection ? altitudeMslM.toStringAsFixed(2) : '—';
  String get barometricTrendDisplay {
    final usesBarometricTrend =
      apogeeDetectionMode == DataServiceManager.apogeeDetectionBarometric ||
      (apogeeDetectionMode == DataServiceManager.apogeeDetectionAuto &&
        stageRole == DataServiceManager.stageRoleBooster);
    if (!usesBarometricTrend) return 'Indisponible';
    if (!hasConnection || barometerSensorState != SensorState.ok) return '—';
    switch (barometricTrend) {
      case 1:
        return 'Ascendante';
      case 2:
        return 'Descendante';
      default:
        return 'Stable';
    }
  }
  String get kalmanAltitudeDisplay =>
      hasConnection ? kalmanAltitudeM.toStringAsFixed(2) : '—';
  String get kalmanVelocityDisplay =>
      hasConnection ? kalmanVelocityMS.toStringAsFixed(2) : '—';
  String get gpsLatDisplay =>
      hasValidGpsFix ? '${gpsLat.toStringAsFixed(6)}°' : '—';
  String get gpsLonDisplay =>
      hasValidGpsFix ? '${gpsLon.toStringAsFixed(6)}°' : '—';
  String get gpsAltDisplay =>
      hasValidGpsFix ? '${gpsAlt.toStringAsFixed(1)} m' : '—';
  String get gpsSatellitesDisplay =>
      hasValidGpsFix ? '$gpsSatellites satellites' : '—';
  String get gpsFixDisplay =>
      hasConnection ? (gpsFix > 0 ? 'Actif' : 'Aucun fix') : '—';
}
