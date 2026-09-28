import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus/services/data_service.dart';
import 'package:nexus/services/console_service.dart';

class ConnectedDeviceRecord {
  ConnectedDeviceRecord({
    required this.id,
    required this.name,
    required this.lastConnected,
    required this.connectionCount,
  });

  final String id;
  final String name;
  final DateTime lastConnected;
  final int connectionCount;
}

class BluetoothServiceManager with ChangeNotifier {
  static const String _nordicUartWriteUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String _hm11ServiceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String _bluetoothBaseUuidSuffix = '-0000-1000-8000-00805f9b34fb';
  static const Set<String> _standardServiceUuids = {
    '1800',
    '1801',
    '180a',
    '180d',
    '180f',
    '1810',
    '1811',
    '1812',
  };

  BluetoothServiceManager() {
    ConsoleService().addListener(_onConsoleChanged);
    _loadConnectedDeviceHistory();
  }

  bool isHm11ScanResult(ScanResult result) {
    final name = result.device.platformName.toLowerCase();
    final advertisedServices = result.advertisementData.serviceUuids
        .map((uuid) => uuid.toString().toLowerCase())
        .toSet();
    return advertisedServices.contains(_hm11ServiceUuid) ||
        advertisedServices.contains('ffe0') ||
        name.contains('hmsoft') ||
        name.contains('hm-11') ||
        name.contains('hm11') ||
        name.contains('odb');
  }

  Future<void> _loadConnectedDeviceHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final records = preferences.getStringList('connected_odb_history') ?? [];
    for (final record in records) {
      final fields = record.split('|');
      if (fields.length != 4) continue;
      final date = DateTime.tryParse(fields[2]);
      final count = int.tryParse(fields[3]);
      if (date == null || count == null) continue;
      connectedDeviceHistory.add(ConnectedDeviceRecord(
        id: fields[0],
        name: fields[1],
        lastConnected: date,
        connectionCount: count,
      ));
    }
    notifyListeners();
  }

  Future<void> _rememberConnectedDevice(BluetoothDevice device) async {
    final id = device.remoteId.str;
    final name = device.platformName.isNotEmpty ? device.platformName : 'ODB Device';
    final index = connectedDeviceHistory.indexWhere((record) => record.id == id);
    final count = index >= 0 ? connectedDeviceHistory[index].connectionCount + 1 : 1;
    final record = ConnectedDeviceRecord(
      id: id,
      name: name,
      lastConnected: DateTime.now(),
      connectionCount: count,
    );
    if (index >= 0) {
      connectedDeviceHistory[index] = record;
    } else {
      connectedDeviceHistory.add(record);
    }
    connectedDeviceHistory.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'connected_odb_history',
      connectedDeviceHistory
          .map((item) => '${item.id}|${item.name}|${item.lastConnected.toIso8601String()}|${item.connectionCount}')
          .toList(),
    );
    notifyListeners();
  }

  Future<void> clearConnectionHistory() async {
    connectedDeviceHistory.clear();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('connected_odb_history');
    notifyListeners();
  }

  // ---------- STATE ----------
  List<ScanResult> scanResults = [];
  bool isScanning = false;

  BluetoothDevice? connectedDevice;
  final List<ConnectedDeviceRecord> connectedDeviceHistory = [];
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;
  StreamSubscription<List<ScanResult>>? scanResultsSubscription;
  final Map<Guid, StreamSubscription<List<int>>> notifySubscriptions = {};
  BluetoothCharacteristic? _writeCharacteristic;
  final List<BluetoothCharacteristic> _writeCandidates = [];
  DataServiceManager? _dataService;

  // ---------- RSSI ----------
  /// stocke le dernier RSSI connu (-999 = inconnu)
  int rssi = -999;
  String get rssiDisplay => rssi == -999 ? '—' : '$rssi dBm';

  /// relance un scan court pour get le rssi
  Future<void> refreshScan({Duration timeout = const Duration(seconds: 5)}) async {
    if (isScanning) await stopScan();
    await startScan(timeout: timeout);
  }

  // ---------- LOGS ----------
  void _onConsoleChanged() => notifyListeners();
  List<String> get logs => ConsoleService().logs;

  Future<bool> _ensureScanPermissions() async {
    if (kIsWeb) return true;

    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    final results = await permissions.request();
    final bluetoothGranted = results[Permission.bluetoothScan]?.isGranted == true &&
        results[Permission.bluetoothConnect]?.isGranted == true;
    final locationGranted = results[Permission.locationWhenInUse]?.isGranted == true;

    if (!bluetoothGranted && !locationGranted) {
      ConsoleService().log('Permissions Bluetooth refusées');
      return false;
    }

    return true;
  }

  // ---------- SCAN ----------
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    if (isScanning) return;

    final hasPermissions = await _ensureScanPermissions();
    if (!hasPermissions) {
      return;
    }

    ConsoleService().clear();
    ConsoleService().log('Démarrage du scan Bluetooth');

    scanResults.clear();
    isScanning = true;
    notifyListeners();

    await scanResultsSubscription?.cancel();
    scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      scanResults = results;
      // Met à jour le RSSI en prenant la valeur du périphérique connecté (si présent)
      if (results.isNotEmpty) {
        ConsoleService().log('${results.length} appareil(s) détecté(s)');
        final match = connectedDevice != null
            ? results.firstWhere((r) => r.device.remoteId == connectedDevice!.remoteId, orElse: () => results.first)
            : results.first;
        rssi = match.rssi;
      } else {
        rssi = -999;
      }
      notifyListeners();
    });

    await FlutterBluePlus.startScan(timeout: timeout);

    FlutterBluePlus.isScanning
        .where((v) => v == false)
        .first
        .then((_) {
      isScanning = false;
      ConsoleService().log('Scan Bluetooth terminé');
      notifyListeners();
    });
  }

  Future<void> stopScan() async {
    if (!isScanning) return;

    await FlutterBluePlus.stopScan();
    isScanning = false;
    ConsoleService().log('Scan Bluetooth arrêté manuellement');
    notifyListeners();
  }

  // ---------- CONNECT ----------
  Future<void> connect(BluetoothDevice device, DataServiceManager dataService) async {
    dataService.resetOdbConfig();
    
    final name = device.platformName.isNotEmpty ? device.platformName : device.remoteId.str;
    try {
      _dataService = dataService;
      ConsoleService().log('Connexion à $name');

      await connectionSubscription?.cancel();
      await connectedDevice?.disconnect();
      await stopScan();

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      connectedDevice = device;
      await _rememberConnectedDevice(device);
      notifyListeners();

      connectionSubscription = device.connectionState.listen((state) {
        ConsoleService().log('État connexion: $state');

        if (state == BluetoothConnectionState.disconnected) {
          _resetConnectionState();
          ConsoleService().log('Appareil déconnecté');
        }
      });

      await discoverServices(dataService);

      ConsoleService().log('Connexion établie avec $name');


      await Future.delayed(const Duration(milliseconds: 500)); 
      await dataService.refreshOdb();
    } catch (e) {
      ConsoleService().log('Erreur de connexion: $e');
      debugPrint('Erreur connexion: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (connectedDevice == null) {
      ConsoleService().log('Aucun appareil à déconnecter');
      return;
    }

    ConsoleService().log('Déconnexion en cours');

    await connectionSubscription?.cancel();
    connectionSubscription = null;

    try {
      await connectedDevice!.disconnect();
      ConsoleService().log('Déconnexion réussie');
    } catch (e) {
      ConsoleService().log('Erreur déconnexion: $e');
      debugPrint('Erreur disconnect: $e');
    } finally {
      _resetConnectionState();
    }
  }

  void _resetConnectionState() {
    _dataService?.resetOdbConfig();
    connectedDevice = null;
    rssi = -999;
    _writeCharacteristic = null;
    _writeCandidates.clear();

    for (final sub in notifySubscriptions.values) {
      sub.cancel();
    }
    notifySubscriptions.clear();
    _dataService = null;

    notifyListeners();
  }

  // ---------- SERVICES ----------
  Future<void> discoverServices(DataServiceManager dataService) async {
    if (connectedDevice == null) return;

    ConsoleService().log('Découverte des services');

    try {
      _writeCharacteristic = null;
      _writeCandidates.clear();
      final services = await connectedDevice!.discoverServices().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Service discovery timeout'),
      );
      ConsoleService().log('${services.length} service(s) trouvé(s)');

    for (final service in services) {
      final serviceUuid = service.uuid.toString().toLowerCase();
      final isStandardService = _isStandardBluetoothUuid(serviceUuid) || _standardServiceUuids.contains(serviceUuid);

      ConsoleService().log(
        'Service découvert: ${service.uuid} '
        '${isStandardService ? '(standard)' : '(personnalisé)'}',
      );

      for (final c in service.characteristics) {
        if (c.properties.notify) {
          ConsoleService().log('Notification activée: ${c.uuid}');
          await enableNotifications(c, dataService);
        }

        if (!isStandardService && (c.properties.write || c.properties.writeWithoutResponse)) {
          _writeCandidates.add(c);

          final uuid = c.uuid.toString().toLowerCase();
          if (_writeCharacteristic == null || uuid == _nordicUartWriteUuid) {
            _writeCharacteristic = c;
          }

          ConsoleService().log(
            'Caractéristique écriture détectée: ${c.uuid} '
            '(write=${c.properties.write}, writeNoResp=${c.properties.writeWithoutResponse})',
          );
        } else if (c.properties.write || c.properties.writeWithoutResponse) {
          ConsoleService().log(
            'Caractéristique écrivable ignorée car standard: ${c.uuid} '
            '(service=${service.uuid})',
          );
        }
      }
    }

      _writeCandidates.sort((a, b) {
        final aUuid = a.uuid.toString().toLowerCase();
        final bUuid = b.uuid.toString().toLowerCase();
        if (aUuid == _nordicUartWriteUuid && bUuid != _nordicUartWriteUuid) {
          return -1;
        }
        if (bUuid == _nordicUartWriteUuid && aUuid != _nordicUartWriteUuid) {
          return 1;
        }
        if (a.properties.write && !b.properties.write) {
          return -1;
        }
        if (b.properties.write && !a.properties.write) {
          return 1;
        }
        return a.uuid.toString().compareTo(b.uuid.toString());
      });

      if (_writeCandidates.isNotEmpty) {
        _writeCharacteristic = _writeCandidates.first;
        ConsoleService().log('Caractéristique écriture prioritaire: ${_writeCharacteristic!.uuid}');
      }
    } catch (e) {
      ConsoleService().log('Erreur découverte services: $e');
      debugPrint('Erreur discoverServices: $e');
    }
  }

  bool _isStandardBluetoothUuid(String uuid) {
    return uuid.endsWith(_bluetoothBaseUuidSuffix);
  }

  final List<int> _rxBuffer = [];

  Future<void> enableNotifications(BluetoothCharacteristic c, DataServiceManager dataService) async {
    try {
      if (notifySubscriptions.containsKey(c.uuid)) return;
      await c.setNotifyValue(true);

      var sub = c.lastValueStream.listen((data) {
        if (data.isEmpty) return;
        _rxBuffer.addAll(data);

        while (_rxBuffer.length >= 5) {
          if (_rxBuffer[0] != 0xAB || _rxBuffer[1] != 0xCD) {
            _rxBuffer.removeAt(0);
            continue;
          }

          int type = _rxBuffer[2];
          int length = _rxBuffer[3];

          if (_rxBuffer.length < length + 5) {
            break;
          }

          int expectedChecksum = type ^ length;
          for (int i = 0; i < length; i++) {
            expectedChecksum ^= _rxBuffer[4 + i];
          }

          int receivedChecksum = _rxBuffer[4 + length];

          if (expectedChecksum == receivedChecksum) {
            final payload = _rxBuffer.sublist(4, 4 + length);
            if (!dataService.isDisposed) {
              dataService.parseBinaryMessage(type, payload);
            }
          } else {
            ConsoleService().log('Erreur CRC Trame binaire (Type: $type)');
          }

          // Retire la trame traitée du buffer
          _rxBuffer.removeRange(0, length + 5);
        }
      });

      notifySubscriptions[c.uuid] = sub;
    } catch (e) {
      ConsoleService().log("Erreur enableNotifications: $e");
    }
  }

  Future<void> sendBinary(int type, List<int> payload, {BluetoothCharacteristic? characteristic}) async {
    List<int> frame = [0xAB, 0xCD, type, payload.length];
    int checksum = type ^ payload.length;
    for (int byte in payload) {
      frame.add(byte);
      checksum ^= byte;
    }
    frame.add(checksum);

    await _sendRawBytes(frame, characteristic: characteristic);
  }

  Future<void> _sendRawBytes(List<int> bytes, {BluetoothCharacteristic? characteristic}) async {
    final preferred = characteristic != null
        ? [characteristic]
        : [if (_writeCharacteristic != null) _writeCharacteristic!, ..._writeCandidates];
        
    if (preferred.isEmpty) return;

    Object? lastError;
    try {
      for (final c in preferred) {
        try {
          bool withoutResp = c.properties.writeWithoutResponse && !c.properties.write;
          int chunkSize = 20;
          for (int i = 0; i < bytes.length; i += chunkSize) {
            int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
            List<int> chunk = bytes.sublist(i, end);
            
            await c.write(chunk, withoutResponse: withoutResp);
            await Future.delayed(const Duration(milliseconds: 20));
          }
          return;
        } catch (error) {
          lastError = error;
        }
      }
      ConsoleService().log(
          'Erreur TX Binaire: aucune caractéristique n\'a accepté la trame${lastError == null ? '' : ': $lastError'}');
    } catch (e) {
      ConsoleService().log('Erreur TX Binaire: $e');
    }
  }

  Future<void> send(String message, {BluetoothCharacteristic? characteristic}) async {
    if (connectedDevice == null) {
      ConsoleService().log('Aucun appareil connecté');
      return;
    }
    final preferred = characteristic != null
        ? <BluetoothCharacteristic>[characteristic]
        : <BluetoothCharacteristic>{
            if (_writeCharacteristic != null) _writeCharacteristic!,
            ..._writeCandidates,
          }.toList();

    if (preferred.isEmpty) {
      ConsoleService().log('Aucune caractéristique d\'écriture disponible');
      return;
    }

    final payload = utf8.encode(message);
    try {
      for (final c in preferred) {
        final withoutResponse = c.properties.writeWithoutResponse && !c.properties.write;
        try {
          await c.write(payload, withoutResponse: withoutResponse);
          _writeCharacteristic = c;
          ConsoleService().log('TX: $message via ${c.uuid}');
          return;
        } catch (e) {
          ConsoleService().log('Échec écriture via ${c.uuid}: $e');
        }
      }

      ConsoleService().log('Erreur envoi message: aucune caractéristique d\'écriture n\'a accepté la commande');
    } catch (e) {
      ConsoleService().log('Erreur envoi message: $e');
    }
  }

  @override
  void dispose() {
    try {
      ConsoleService().removeListener(_onConsoleChanged);
    } catch (_) {}

    connectionSubscription?.cancel();
    scanResultsSubscription?.cancel();
    for (final sub in notifySubscriptions.values) {
      sub.cancel();
    }
    notifySubscriptions.clear();
    super.dispose();
  }
}
