import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:nexus/services/bluetooth_service.dart';
import 'package:nexus/services/data_service.dart';

void main() {
  Uint8List telemetryBytes() {
    final data = ByteData(140);
    data.setUint8(0, 1);
    data.setUint8(1, 3);
    data.setUint16(2, 140, Endian.little);
    data.setUint32(4, 12345, Endian.little);
    data.setUint16(13, 7400, Endian.little);
    data.setFloat32(79, 1013.25, Endian.little);
    data.setFloat32(83, 21.5, Endian.little);
    data.setInt32(112, 123400, Endian.little);
    data.setFloat32(135, 3.45, Endian.little);
    return data.buffer.asUint8List();
  }

  testWidgets('parses binary telemetry and updates shared consumers', (tester) async {
    final bluetoothService = BluetoothServiceManager();
    final dataService = DataServiceManager(bluetoothService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BluetoothServiceManager>.value(value: bluetoothService),
          ChangeNotifierProvider<DataServiceManager>.value(value: dataService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Consumer<DataServiceManager>(
                  builder: (context, data, child) {
                    return Text(
                      'overview:${data.timeBootMs}|${data.vinMv}|${data.gpsAlt}',
                      key: const Key('overview-view'),
                    );
                  },
                ),
                Consumer<DataServiceManager>(
                  builder: (context, data, child) {
                    return Text(
                      'settings:${data.temperature}|${data.barometerPressure}|${data.kalmanVelocityMS}',
                      key: const Key('settings-view'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await dataService.parseBinaryMessage(
      DataServiceManager.msgTypeTelemetry,
      telemetryBytes(),
    );

    await tester.pump();

    expect(find.byKey(const Key('overview-view')), findsOneWidget);
    expect(find.text('overview:12345|7400|123.4'), findsOneWidget);
    expect(find.byKey(const Key('settings-view')), findsOneWidget);
    expect(
      find.textContaining('settings:21.5|1013.25|3.45'),
      findsOneWidget,
    );
  });

  test('configuration round-trip preserves pyro roles', () {
    final config = OdbConfig(
      odbName: 'test',
      stageRole: DataServiceManager.stageRoleSustainer,
      debugMode: false,
      flightTestMode: false,
      axisProfile: DataServiceManager.axisProfileP0,
      fireAttemptDelayMs: 100,
      pyrosArmingFailsafeMs: 200,
      minNeededPyroNb: 1,
      pyroRoles: [0, 1, 2, 3],
      accZLaunchThreshold: 1,
      boostPhaseVThreshold: 2,
      apogeeDetectVThreshold: 3,
      landingDetectVThreshold: 4,
      landingDetectThresholdMs: 500,
      apogeeFailsafeMs: 600,
      mainDeployAltitudeThresholdM: 700,
      drogueFireAttemptMaxNb: 2,
      mainFireAttemptMaxNb: 2,
      enableBuzzer: true,
      buzzerReportToneHz: 1000,
      idefixFrequencyHz: 2000000,
    );

    final decoded = OdbConfig.fromBytes(config.toBytes());
    expect(decoded.pyroRoles, equals(<int>[0, 1, 2, 3]));
  });

  test('telemetry does not modify configuration roles', () async {
    final bluetoothService = BluetoothServiceManager();
    final dataService = DataServiceManager(bluetoothService);

    await dataService.parseBinaryMessage(
      DataServiceManager.msgTypeTelemetry,
      telemetryBytes(),
    );

    expect(dataService.pyroRoles, equals(<int>[0, 0, 0, 0]));
  });
}
