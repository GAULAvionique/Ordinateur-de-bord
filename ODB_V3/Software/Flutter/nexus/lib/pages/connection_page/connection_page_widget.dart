// ...existing code...
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'connection_page_model.dart';
export 'connection_page_model.dart';
import 'package:provider/provider.dart';
import 'package:nexus/services/bluetooth_service.dart';
import 'package:nexus/services/data_service.dart';


class ConnectionPageWidget extends StatefulWidget {
  const ConnectionPageWidget({super.key});

  static String routeName = 'ConnectionPage';
  static String routePath = '/connectionPage';

  @override
  State<ConnectionPageWidget> createState() => _ConnectionPageWidgetState();
}

class _ConnectionPageWidgetState extends State<ConnectionPageWidget> {
  late ConnectionPageModel _model;
  static const int _minRssiThresholdDbm = -90;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConnectionPageModel());

    _model.textController ??= TextEditingController();
  }

  @override
  void dispose() {
    // Stop scan via service si disponible
    try {
      final svc = context.read<BluetoothServiceManager>();
      svc.stopScan();
    } catch (_) {}
    _model.dispose();
    super.dispose();
  }

  void _showBluetoothDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth désactivé'),
        content: const Text(
          'Le Bluetooth est requis pour rechercher des appareils.\n'
          'Veuillez l’activer dans les paramètres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (!kIsWeb && Platform.isAndroid) {
                FlutterBluePlus.turnOn();
              }
            },
            child: const Text('Activer'),
          ),
        ],
      ),
    );
  }

  List<ScanResult> _filteredResults(
    BluetoothServiceManager bt,
    String filter, {
    required bool hm11Only,
  }) {
    final lower = filter.toLowerCase();
    final bestByDevice = <String, ScanResult>{};

    for (final result in bt.scanResults) {
      if (bt.isHm11ScanResult(result) != hm11Only) continue;
      if (result.rssi < _minRssiThresholdDbm) continue;

      final id = result.device.remoteId.str;
      final matchesFilter = filter.isEmpty ||
          id.toLowerCase().contains(lower) ||
          result.device.platformName.toLowerCase().contains(lower);
      if (!matchesFilter) continue;

      final currentBest = bestByDevice[id];
      if (currentBest == null || result.rssi > currentBest.rssi) {
        bestByDevice[id] = result;
      }
    }

    final filteredResults = bestByDevice.values.toList()
      ..sort((a, b) {
        final byRssi = b.rssi.compareTo(a.rssi);
        if (byRssi != 0) return byRssi;
        final aName = a.device.platformName.isNotEmpty
            ? a.device.platformName
            : a.device.remoteId.str;
        final bName = b.device.platformName.isNotEmpty
            ? b.device.platformName
            : b.device.remoteId.str;
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });

    return filteredResults;
  }

  Widget _buildPageHeader(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connexion',
              style: FlutterFlowTheme.of(context).displaySmall.override(
                    font: GoogleFonts.interTight(
                      fontWeight: FontWeight.bold,
                      fontStyle: FlutterFlowTheme.of(context)
                          .displaySmall
                          .fontStyle,
                    ),
                    fontSize: 28,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.bold,
                    fontStyle: FlutterFlowTheme.of(context)
                        .displaySmall
                        .fontStyle,
                  ),
            ),
            Text(
              'Connexion de l\'application Nexus à l\'ODB',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                    fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
            ),
          ],
        ),
        Icon(
          Icons.settings,
          color: FlutterFlowTheme.of(context).primaryText,
          size: 24,
        ),
      ],
    );
  }

  Widget _buildDeviceTile(
    BuildContext context,
    ScanResult result,
    DataServiceManager dataService,
    BluetoothServiceManager bt,
  ) {
    final device = result.device;
    final connected = bt.connectedDevice?.remoteId == device.remoteId;

    return ListTile(
      leading: const Icon(Icons.bluetooth),
      title: Text(device.platformName.isNotEmpty ? device.platformName : 'Appareil inconnu'),
      subtitle: Text('${device.remoteId.str}  |  RSSI: ${result.rssi} dBm'),
      trailing: FFButtonWidget(
        onPressed: connected
            ? null
            : () async {
                try {
                  await context.read<BluetoothServiceManager>().connect(device, dataService);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur connexion: $e')),
                    );
                  }
                }
              },
        text: connected ? 'Connecté' : 'Connecter',
        options: FFButtonOptions(
          height: 36,
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
          color: connected ? FlutterFlowTheme.of(context).secondaryText : FlutterFlowTheme.of(context).primary,
          textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                font: GoogleFonts.interTight(
                  fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                ),
                color: Colors.white,
                letterSpacing: 0.0,
                fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
              ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildScanCard(
    BuildContext context,
    BluetoothServiceManager bt,
    DataServiceManager dataService,
    List<ScanResult> filteredResults,
    List<ScanResult> otherResults,
  ) {
    final hasConnectedDevice = bt.connectedDevice != null;
    final canUseScanButton = bt.isScanning || !hasConnectedDevice;

    return Container(
      width: double.infinity,
      height: 450,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            color: Color(0x33000000),
            offset: Offset(0, 2),
          )
        ],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.transparent,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Icon(Icons.bluetooth_searching, color: FlutterFlowTheme.of(context).primary, size: 24),
                    Text(
                      'Recherche Bluetooth',
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            font: GoogleFonts.interTight(
                              fontWeight: FontWeight.w600,
                              fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                            ),
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                          ),
                    ),
                  ].divide(const SizedBox(width: 8)),
                ),
                FFButtonWidget(
                  onPressed: canUseScanButton
                      ? () async {
                          if (bt.isScanning) {
                            await context.read<BluetoothServiceManager>().stopScan();
                            return;
                          }

                          if (bt.connectedDevice != null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Déconnectez l\'appareil avant de lancer un scan.'),
                                ),
                              );
                            }
                            return;
                          }

                          try {
                            final state = await FlutterBluePlus.adapterState.first;
                            debugPrint('Bluetooth state: $state');
                            if (state != BluetoothAdapterState.on) {
                              _showBluetoothDisabledDialog();
                            } else {
                              if(context.mounted) {
                                await context.read<BluetoothServiceManager>().refreshScan(timeout: const Duration(seconds: 15));
                              }
                            }
                          } catch (e) {
                            debugPrint('Erreur lecture état Bluetooth: $e');
                            _showBluetoothDisabledDialog();
                          }
                        }
                      : null,
                  text: '',
                  icon: Icon(
                    bt.isScanning
                        ? Icons.stop
                        : hasConnectedDevice
                            ? Icons.lock_outline
                            : Icons.refresh,
                    color: bt.isScanning
                        ? FlutterFlowTheme.of(context).error
                        : hasConnectedDevice
                            ? FlutterFlowTheme.of(context).secondaryText
                            : FlutterFlowTheme.of(context).success,
                    size: 24,
                  ),
                  options: FFButtonOptions(
                    height: 40,
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                    iconPadding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                    iconColor: FlutterFlowTheme.of(context).primary,
                    color: const Color(0x00EF3939),
                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                          font: GoogleFonts.interTight(
                            fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                            fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                          ),
                          color: Colors.white,
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                          fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                        ),
                    elevation: 0,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  showLoadingIndicator: false,
                ),
              ],
            ),
            Text(
              bt.isScanning
                  ? 'Recherche d\'appareils en cours...'
                : hasConnectedDevice
                  ? 'Scan désactivé: un appareil est déjà connecté.'
                  : (bt.scanResults.isEmpty ? 'Aucun appareil trouvé (BLE)' : 'Recherche Bluetooth arrêtée'),
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    letterSpacing: 0.0,
                    fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
            ),
            Divider(thickness: 1, color: FlutterFlowTheme.of(context).alternate),
            TextFormField(
              controller: _model.textController,
              focusNode: _model.textFieldFocusNode,
              autofocus: false,
              obscureText: false,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou UUID',
                hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      letterSpacing: 0.0,
                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: FlutterFlowTheme.of(context).alternate, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: FlutterFlowTheme.of(context).primary, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0x00000000), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0x00000000), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                prefixIcon: Icon(Icons.search, color: FlutterFlowTheme.of(context).secondaryText, size: 20),
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
              cursorColor: FlutterFlowTheme.of(context).primaryText,
              validator: _model.textControllerValidator.asValidator(context),
            ),
            Expanded(
              child: ListView(
                children: [
                  ...filteredResults.map((result) => _buildDeviceTile(context, result, dataService, bt)),
                  if (otherResults.isNotEmpty)
                    Material(
                      color: Colors.transparent,
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        leading: const Icon(Icons.devices_other),
                        title: Text('Autres appareils détectés (${otherResults.length})'),
                        children: otherResults
                            .map((result) => _buildDeviceTile(context, result, dataService, bt))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            if (bt.connectedDevice != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: ListTile(
                  leading: const Icon(Icons.bluetooth_connected),
                  title: Text(bt.connectedDevice?.platformName ?? bt.connectedDevice?.remoteId.str ?? 'Connecté'),
                  subtitle: const Text('Appareil connecté via service'),
                  trailing: FFButtonWidget(
                    onPressed: () => context.read<BluetoothServiceManager>().disconnect(),
                    text: 'Déconnecter',
                    options: FFButtonOptions(
                      height: 36,
                      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
                      color: FlutterFlowTheme.of(context).error,
                      textStyle: FlutterFlowTheme.of(context).bodySmall.override(color: FlutterFlowTheme.of(context).primaryBackground),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ].divide(const SizedBox(height: 12)),
        ),
      ),
    );
  }

  Widget _buildLogsCard(BuildContext context, BluetoothServiceManager bt) {
    return Container(
      width: double.infinity,
      height: 125,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            color: Color(0x33000000),
            offset: Offset(0, 2),
          )
        ],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: ListView.builder(
                reverse: false,
                itemCount: bt.logs.length,
                itemBuilder: (context, index) {
                  final log = bt.logs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      log,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                    ),
                  );
                },
              ),
            ),
          ].divide(const SizedBox(height: 12)),
        ),
      ),
    );
  }

  Widget _buildConnectionHistoryCard(BuildContext context, BluetoothServiceManager bt) {
    String formatDate(DateTime date) {
      String twoDigits(int value) => value.toString().padLeft(2, '0');
      return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} ${twoDigits(date.hour)}:${twoDigits(date.minute)}';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            color: Color(0x33000000),
            offset: Offset(0, 2),
          )
        ],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: FlutterFlowTheme.of(context).primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Historique des appareils',
                  style: FlutterFlowTheme.of(context).titleMedium.override(
                        font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: bt.connectedDeviceHistory.isEmpty
                      ? null
                      : () => bt.clearConnectionHistory(),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Effacer l’historique',
                  color: FlutterFlowTheme.of(context).error,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (bt.connectedDeviceHistory.isEmpty)
              Text(
                'Aucun appareil connecté récemment.',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(),
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
              )
            else
              ...bt.connectedDeviceHistory.map(
                (record) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.bluetooth, color: FlutterFlowTheme.of(context).primary),
                  title: Text(record.name),
                  subtitle: Text(
                    '${record.id}\nDernière connexion: ${formatDate(record.lastConnected)}',
                  ),
                  trailing: Text('${record.connectionCount}x'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BluetoothServiceManager>();
    final dataService = context.watch<DataServiceManager>();
    final filter = _model.textController?.text ?? '';
    final filteredResults = _filteredResults(bt, filter, hm11Only: true);
    final otherResults = _filteredResults(bt, filter, hm11Only: false);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPageHeader(context),
                  _buildScanCard(context, bt, dataService, filteredResults, otherResults),
                  _buildConnectionHistoryCard(context, bt),
                  _buildLogsCard(context, bt),
                ]
                    .divide(const SizedBox(height: 24))
                    .addToStart(const SizedBox(height: 24))
                    .addToEnd(const SizedBox(height: 24)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
