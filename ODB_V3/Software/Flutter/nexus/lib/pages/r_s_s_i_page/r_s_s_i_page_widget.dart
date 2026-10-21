import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'r_s_s_i_page_model.dart';
export 'r_s_s_i_page_model.dart';
import 'package:nexus/services/bluetooth_service.dart';


class RSSIPageWidget extends StatefulWidget {
  const RSSIPageWidget({super.key});

  static String routeName = 'RSSIPage';
  static String routePath = '/rSSIPage';

  @override
  State<RSSIPageWidget> createState() => _RSSIPageWidgetState();
}

class _RSSIPageWidgetState extends State<RSSIPageWidget> {
  late RSSIPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RSSIPageModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Widget _buildSignalDial(
    BuildContext context,
    BluetoothServiceManager bt,
    bool connected,
  ) {
    Color rssiColor(int rssi) {
      if (!connected) return FlutterFlowTheme.of(context).secondaryText;
      if (rssi >= -50) return FlutterFlowTheme.of(context).success;
      if (rssi >= -70) return FlutterFlowTheme.of(context).warning;
      return FlutterFlowTheme.of(context).error;
    }

    final signalColor = rssiColor(bt.rssi);

    return Container(
      width: double.infinity,
      height: 435.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        boxShadow: const [
          BoxShadow(
            blurRadius: 4.0,
            color: Color(0x33000000),
            offset: Offset(0.0, 2.0),
          )
        ],
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Stack(
            alignment: const AlignmentDirectional(0.0, 0.0),
            children: [
              Container(
                width: 280.0,
                height: 280.0,
                decoration: BoxDecoration(
                  color: signalColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 200.0,
                height: 200.0,
                decoration: BoxDecoration(
                  color: signalColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 120.0,
                height: 120.0,
                decoration: BoxDecoration(
                  color: signalColor.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 60.0,
                height: 60.0,
                decoration: BoxDecoration(
                  color: signalColor,
                  shape: BoxShape.circle,
                ),
                child: Align(
                  alignment: const AlignmentDirectional(0.0, 0.0),
                  child: Icon(
                    connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: FlutterFlowTheme.of(context).info,
                    size: 32.0,
                  ),
                ),
              ),
              Opacity(
                opacity: 0.6,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    width: 300.0,
                    height: 300.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: signalColor,
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(
            connected ? 'RSSI: ${bt.rssi} dBm' : '—',
            style: FlutterFlowTheme.of(context).titleSmall.override(
                  font: GoogleFonts.interTight(
                    fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                    fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                  ),
                  color: signalColor,
                  letterSpacing: 0.0,
                  fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: FFButtonWidget(
              onPressed: connected
                  ? () async {
                      debugPrint('Actualiser la recherche demandée ...');
                      await context
                          .read<BluetoothServiceManager>()
                          .refreshScan(timeout: const Duration(seconds: 5));
                    }
                  : null,
              text: connected ? 'Actualiser la recherche' : 'Aucune appareil connecté',
              icon: Icon(
                Icons.refresh,
                color: FlutterFlowTheme.of(context).primaryBackground,
                size: 20.0,
              ),
              options: FFButtonOptions(
                width: double.infinity,
                height: 48.0,
                padding: const EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                iconPadding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                iconColor: FlutterFlowTheme.of(context).info,
                color: connected
                    ? FlutterFlowTheme.of(context).primary
                    : FlutterFlowTheme.of(context).secondaryText,
                textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                      font: GoogleFonts.interTight(
                        fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                        fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      letterSpacing: 0.0,
                      fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                      fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                    ),
                elevation: 0.0,
                borderSide: const BorderSide(
                  color: Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0x1A2196F3),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              Icons.info_outline,
              color: FlutterFlowTheme.of(context).primary,
              size: 20.0,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimation basée sur la puissance du signal Bluetooth (RSSI)',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                          fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                  ),
                  Text(
                    'La précision est variable selon l\'environnement (10 ~ 30 m), sans indication directionnelle.',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.inter(
                            fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                            fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).secondaryText,
                          fontSize: 11.0,
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                          fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                  ),
                ],
              ),
            ),
          ].divide(const SizedBox(width: 12.0)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BluetoothServiceManager>();
    final connected = bt.connectedDevice != null;

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
            padding: const EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Détection ODB',
                          style: FlutterFlowTheme.of(context)
                              .displaySmall
                              .override(
                                font: GoogleFonts.interTight(
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .displaySmall
                                      .fontStyle,
                                ),
                                fontSize: 28.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .displaySmall
                                    .fontStyle,
                              ),
                        ),
                        Text(
                          'Recherche de l\'ordinateur de bord \nvia Bluetooth Low Energy',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.settings,
                      color: FlutterFlowTheme.of(context).primaryText,
                      size: 24.0,
                    ),
                  ],
                ),
                _buildSignalDial(context, bt, connected),
                _buildInfoBanner(context),
              ]
                  .divide(const SizedBox(height: 24.0))
                  .addToStart(const SizedBox(height: 32.0))
                  .addToEnd(const SizedBox(height: 32.0)),
            ),
          ),
        ),
      ),
    );
  }
}
