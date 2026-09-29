import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'events_page_model.dart';
export 'events_page_model.dart';
import 'package:nexus/services/data_service.dart';

class EventsPageWidget extends StatefulWidget {
  const EventsPageWidget({super.key});

  static String routeName = 'EventsPage';
  static String routePath = '/eventsPage';

  @override
  State<EventsPageWidget> createState() => _EventsPageWidgetState();
}

class _EventsPageWidgetState extends State<EventsPageWidget> {
  late EventsPageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EventsPageModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // Formatage des temps simples en secondes
  String _formatTimeMs(int timeMs) {
    if (timeMs == 0) return '—';
    return '${(timeMs / 1000.0).toStringAsFixed(2)} s';
  }

  // Formatage du pourcentage de données de vol reçues
  String _formatFlightDataProgress(DataServiceManager data) {
    final total = data.flightDataSamplesTotal;
    if (total == null) return '...';
    if (total <= 0) return '0 %';

    final percentage = (data.flightDataSamplesReceived * 100 / total)
        .clamp(0, 100)
        .toStringAsFixed(0);
    return '$percentage %';
  }

  // Formatage spécifique pour les window_event_t (Start -> End)
  String _formatWindow(WindowEvent window) {
    if (!window.activated && window.startTimeMs == 0) return '—';
    String start = _formatTimeMs(window.startTimeMs);
    String end = window.endTimeMs > 0 ? _formatTimeMs(window.endTimeMs) : 'En cours';
    return '$start -> $end';
  }

  String _formatGPSDate(int rawDate) {
    if (rawDate <= 0) return 'Date inconnue';
    final day = (rawDate >> 16) & 0xFF;
    final month = (rawDate >> 8) & 0xFF;
    final year = rawDate & 0xFF;
    if (day < 1 || day > 31 || month < 1 || month > 12) return 'Date inconnue';
    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/${(2000 + year).toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataServiceManager>();
    final connected = data.hasConnection;
    final statsList = connected
        ? (List<OdbStats>.from(data.flightStats)
          ..sort((first, second) {
            final idOrder = second.flightId.compareTo(first.flightId);
            return idOrder != 0 ? idOrder : second.date.compareTo(first.date);
          }))
        : <OdbStats>[];
    final isLoading = data.isLoadingFlightStats;
    final errorMessage = data.flightStatsError;

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
            padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Événements de vol',
                            style: FlutterFlowTheme.of(context).displaySmall.override(
                                  font: GoogleFonts.interTight(fontWeight: FontWeight.bold),
                                  fontSize: 28.0,
                                ),
                          ),

                          Text(
                            'Données des vols récupérées de l’ODB.',
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.inter(),
                                  color: FlutterFlowTheme.of(context).secondaryText,
                                ),
                          ),
                          if (data.flightStatsFound != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '${data.flightStatsFound} vol(s) trouvé(s), ${statsList.length} reçu(s).',
                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.inter(),
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: connected ? FlutterFlowTheme.of(context).primary : FlutterFlowTheme.of(context).secondaryText,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: IconButton(
                          icon: Icon(isLoading ? Icons.stop_rounded : Icons.download_rounded, color: Colors.white),
                          onPressed: connected
                              ? (isLoading ? data.cancelFlightStatsRequest : () => data.requestLastFlightEvents())
                              : null,
                          tooltip: isLoading ? 'Arrêter la recherche' : 'Télécharger les données',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24.0),

                  if (isLoading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16.0),
                            Text(
                              'Chargement des statistiques depuis la mémoire de l’ODB...',
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(),
                                    color: FlutterFlowTheme.of(context).secondaryText,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (errorMessage != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.error_outline, color: FlutterFlowTheme.of(context).error, size: 40.0),
                            const SizedBox(height: 12.0),
                            Text(
                              errorMessage,
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(),
                                    color: FlutterFlowTheme.of(context).error,
                                  ),
                            ),
                            const SizedBox(height: 16.0),
                            OutlinedButton.icon(
                              onPressed: connected ? () => data.requestLastFlightEvents() : null,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (statsList.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'Aucune donnée récupérée. Appuyez sur le bouton de téléchargement pour parcourir l\'ODB.',
                          textAlign: TextAlign.center,
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                font: GoogleFonts.inter(),
                                color: FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                      ),
                    ),

                  for (final stats in statsList) ...[
                    Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        title: Text(
                          'Vol #${stats.flightId}',
                          style: FlutterFlowTheme.of(context).titleLarge.override(
                                font: GoogleFonts.interTight(fontWeight: FontWeight.bold),
                              ),
                        ),
                        subtitle: Text(
                          _formatGPSDate(stats.date),
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                font: GoogleFonts.inter(),
                                color: FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (data.isLoadingFlightData && data.flightDataFlightId == stats.flightId)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _AnimatedDownloadIndicator(),
                                    const SizedBox(width: 6.0),
                                    Text(_formatFlightDataProgress(data)),
                                    IconButton(
                                      onPressed: data.cancelFlightDataDownload,
                                      icon: const Icon(Icons.stop_rounded),
                                      tooltip: 'Arrêter le téléchargement',
                                    ),
                                  ],
                                ),
                              )
                            else if (data.isStoppingFlightData)
                              const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Text('Arrêt en cours...'),
                              )
                            else
                              IconButton(
                                onPressed: data.isFlightSaved(stats) || data.isLoadingFlightData
                                    ? null
                                    : () => data.requestFlightDataForSave(stats),
                                icon: const Icon(Icons.bookmark_add_outlined),
                                tooltip: 'Sauvegarder ce vol',
                              ),
                            const Icon(Icons.expand_more),
                          ],
                        ),
                        children: _buildFlightStatistics(context, stats),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16.0),
                  Card(
                    elevation: 2.0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.bookmarks_outlined, color: FlutterFlowTheme.of(context).primary),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  'Vols sauvegardés (${data.savedFlightStats.length})',
                                  style: FlutterFlowTheme.of(context).titleLarge.override(
                                        font: GoogleFonts.interTight(fontWeight: FontWeight.bold),
                                      ),
                                ),
                              ),
                              IconButton(
                                onPressed: data.savedFlightStats.isEmpty
                                    ? null
                                    : () => _confirmClearSavedFlights(context, data),
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Effacer les vols sauvegardés',
                                color: FlutterFlowTheme.of(context).error,
                              ),
                            ],
                          ),
                          const Divider(),
                          if (data.savedFlightStats.isEmpty)
                            Text(
                              'Aucun vol sauvegardé.',
                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(),
                                    color: FlutterFlowTheme.of(context).secondaryText,
                                  ),
                            )
                          else
                            ...data.savedFlightStats.map((savedStats) => _buildSavedFlightTile(context, savedStats, data)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      )
    );
  }

  Future<void> _confirmClearSavedFlights(BuildContext context, DataServiceManager data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Effacer les vols sauvegardés ?'),
        content: const Text('Cette action supprimera tous les vols enregistrés dans l’application.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed == true) await data.clearSavedFlightStats();
  }

  Widget _buildSavedFlightTile(BuildContext context, OdbStats stats, DataServiceManager data) {
    final samples = data.savedFlightData[stats.flightId] ?? [];
    return ExpansionTile(
      initiallyExpanded: false,
      title: Text('Vol #${stats.flightId}'),
      subtitle: Text(_formatGPSDate(stats.date)),
      children: [
        ..._buildFlightSections(
          context,
          stats,
          data,
          samples: samples,
        ),
        const SizedBox(height: 12.0),
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: () => _confirmDeleteSavedFlight(context, data, stats),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer'),
            style: TextButton.styleFrom(
              foregroundColor: FlutterFlowTheme.of(context).error,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlightCharts(BuildContext context, OdbStats stats, List<FlightDataSample> samples) {
    final markers = <FlightChartMarker>[];
    for (var index = 0; index < stats.pyroEvents.length; index++) {
      final pyro = stats.pyroEvents[index];
      if (pyro.fired && pyro.timeMs > 0) {
        markers.add(FlightChartMarker(pyro.timeMs / 1000.0, 'P${index + 1}'));
      }
    }
    return Column(
      children: [
          _buildFlightChart(context, 'Altitude selon le temps', 'Altitude (m)', samples, [
          FlightChartSeries('Baromètre', (sample) => sample.telemetry.altitudeMslM, Colors.blue),
          FlightChartSeries('Kalman', (sample) => sample.telemetry.kalmanZ, Colors.orange),
          FlightChartSeries('GPS', (sample) => sample.telemetry.gpsAlt, Colors.green),
        ], markers),
          _buildFlightChart(context, 'Vitesse selon le temps', 'Vitesse (m/s)', samples, [
          FlightChartSeries('Kalman', (sample) => sample.telemetry.kalmanV, Colors.deepPurple),
          FlightChartSeries('GPS', (sample) => sample.telemetry.gpsVelocity, Colors.red),
        ], markers),
          _buildFlightChart(context, 'Accélération selon le temps', 'Accélération (m/s²)', samples, [
          FlightChartSeries('IMU vertical', (sample) => sample.telemetry.imuAccVertical, Colors.blue),
          FlightChartSeries('High-G vertical', (sample) => sample.telemetry.highgAccVertical, Colors.red),
        ], markers),
      ],
    );
  }

  Widget _buildFlightChart(
    BuildContext context,
    String title,
    String yAxisLabel,
    List<FlightDataSample> samples,
    List<FlightChartSeries> series,
    List<FlightChartMarker> markers,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: FlutterFlowTheme.of(context).titleSmall),
          Wrap(
            spacing: 10.0,
            children: series.map((item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8.0, height: 8.0, color: item.color),
                const SizedBox(width: 4.0),
                Text(item.label, style: FlutterFlowTheme.of(context).bodySmall),
              ],
            )).toList(),
          ),
          const SizedBox(height: 8.0),
          SizedBox(
            height: 190.0,
            width: double.infinity,
            child: CustomPaint(
              painter: FlightChartPainter(
                samples: samples,
                series: series,
                yAxisLabel: yAxisLabel,
                markers: markers,
                markerColor: FlutterFlowTheme.of(context).error,
                gridColor: FlutterFlowTheme.of(context).alternate,
                axisColor: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSavedFlight(
    BuildContext context,
    DataServiceManager data,
    OdbStats stats,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Supprimer le vol #${stats.flightId} ?'),
        content: const Text('Ce vol sera retiré des vols sauvegardés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) await data.deleteSavedFlightStats(stats);
  }

  List<Widget> _buildFlightSections(
    BuildContext context,
    OdbStats stats,
    DataServiceManager data, {
    required List<FlightDataSample> samples,
  }) {
    final flightConfig = data.flightConfigs[stats.flightId];
    return [
      ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.analytics_outlined),
        title: const Text('Statistiques'),
        children: _buildFlightStatistics(context, stats),
      ),
      ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.tune),
        title: const Text('Configuration'),
        children: [
          if (flightConfig != null)
            _buildFlightConfigSection(context, flightConfig)
          else
            _buildUnavailableSection(context, 'Configuration indisponible pour ce vol.'),
        ],
      ),
      ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.show_chart),
        title: const Text('Graphiques'),
        children: [
          if (samples.isNotEmpty)
            _buildFlightCharts(context, stats, samples)
          else
            _buildUnavailableSection(context, 'Données graphiques indisponibles pour ce vol.'),
        ],
      ),
    ];
  }

  Widget _buildUnavailableSection(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        message,
        style: FlutterFlowTheme.of(context).bodySmall.override(
              font: GoogleFonts.inter(),
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
      ),
    );
  }

  List<Widget> _buildFlightStatistics(
    BuildContext context,
    OdbStats stats,
  ) {
    return [
      _buildSectionCard(context, 'Informations Générales', Icons.info_outline, [
        _buildDataRow(context, 'ID du Vol', '#${stats.flightId}', ''),
        _buildDataRow(context, 'Temps de Vol Total', _formatTimeMs(stats.flightTimeMs), ''),
        _buildDataRow(context, 'Date', _formatGPSDate(stats.date), ''),
        _buildDataRow(context, 'Dernière Latitude', '${(stats.lastLat / 10000000.0).toStringAsFixed(5)}°', ''),
        _buildDataRow(context, 'Dernière Longitude', '${(stats.lastLon / 10000000.0).toStringAsFixed(5)}°', ''),
      ]),
      const SizedBox(height: 16.0),
      _buildSectionCard(context, 'Altitudes Max', Icons.terrain, [
        _buildDataRow(context, 'Kalman', stats.maxAltitudeKalman.valid ? '${stats.maxAltitudeKalman.value.toStringAsFixed(1)} m' : '—', _formatTimeMs(stats.maxAltitudeKalman.timeMs)),
        _buildDataRow(context, 'Baromètre', stats.maxAltitudeBaro.valid ? '${stats.maxAltitudeBaro.value.toStringAsFixed(1)} m' : '—', _formatTimeMs(stats.maxAltitudeBaro.timeMs)),
        _buildDataRow(context, 'GPS', stats.maxAltitudeGps.valid ? '${stats.maxAltitudeGps.value.toStringAsFixed(1)} m' : '—', _formatTimeMs(stats.maxAltitudeGps.timeMs)),
        _buildDataRow(context, 'Apogée Détectée', stats.apogee.valid ? '${stats.apogee.value.toStringAsFixed(1)} m' : '—', _formatTimeMs(stats.apogee.timeMs)),
      ]),
      const SizedBox(height: 16.0),
      _buildSectionCard(context, 'Cinématique Max', Icons.speed, [
        _buildDataRow(context, 'Vitesse Ascendante', stats.maxAscendSpeed.valid ? '${stats.maxAscendSpeed.value.toStringAsFixed(1)} m/s' : '—', _formatTimeMs(stats.maxAscendSpeed.timeMs)),
        _buildDataRow(context, 'Vitesse Descendante', stats.maxDescendSpeed.valid ? '${stats.maxDescendSpeed.value.toStringAsFixed(1)} m/s' : '—', _formatTimeMs(stats.maxDescendSpeed.timeMs)),
        _buildDataRow(context, 'Accélération Ascendante', stats.maxAscendAccel.valid ? '${stats.maxAscendAccel.value.toStringAsFixed(1)} m/s²' : '—', _formatTimeMs(stats.maxAscendAccel.timeMs)),
        _buildDataRow(context, 'Accélération Descendante', stats.maxDescendAccel.valid ? '${stats.maxDescendAccel.value.toStringAsFixed(1)} m/s²' : '—', _formatTimeMs(stats.maxDescendAccel.timeMs)),
      ]),
      const SizedBox(height: 16.0),
      _buildSectionCard(context, 'Sécurité & Verrouillages', Icons.security, [
        _buildDataRow(context, 'Armement Pyros', stats.pyrosArm.activated || stats.pyrosArm.startTimeMs > 0 ? 'Déclenché' : '—', _formatWindow(stats.pyrosArm)),
        _buildDataRow(context, 'Mach Lock', stats.machLock.activated || stats.machLock.startTimeMs > 0 ? 'Déclenché' : '—', _formatWindow(stats.machLock)),
      ]),
      const SizedBox(height: 16.0),
      _buildSectionCard(context, 'Déploiements & Pyros', Icons.local_fire_department, [
        _buildDataRow(context, 'Déploiement Drogue', stats.drogueDeploy.valid ? '${stats.drogueDeploy.value.toStringAsFixed(1)} m' : '—', _formatTimeMs(stats.drogueDeploy.timeMs)),
        _buildDataRow(context, 'Déploiement Principal', stats.mainDeploy.valid ? '${stats.mainDeploy.value.toStringAsFixed(1)} m' : '—', _formatTimeMs(stats.mainDeploy.timeMs)),
        for (var index = 0; index < stats.pyroEvents.length; index++)
          _buildDataRow(context, 'Pyro ${index + 1}', stats.pyroEvents[index].fired ? 'Déclenché' : '—', _formatTimeMs(stats.pyroEvents[index].timeMs)),
      ]),
      const SizedBox(height: 24.0),
    ];
  }

  Widget _buildFlightConfigSection(BuildContext context, OdbConfig config) {
    final stage = config.stageRole == DataServiceManager.stageRoleBooster
        ? 'Booster'
        : config.stageRole == DataServiceManager.stageRoleSustainer
            ? 'Sustainer'
            : 'Inconnu';
    const roleLabels = [
      'Aucun',
      'Principal',
      'Drogue',
      'Principal secours',
      'Drogue secours',
    ];
    final pyroRoles = config.pyroRoles.map((role) {
      return role >= 0 && role < roleLabels.length ? roleLabels[role] : 'Inconnu';
    }).join(' / ');

    return _buildSectionCard(context, 'Configuration du vol', Icons.tune, [
      _buildDataRow(context, 'Nom ODB', config.odbName, ''),
      _buildDataRow(context, 'Rôle d’étage', stage, ''),
      _buildDataRow(context, 'Profil d’axe', 'P${config.axisProfile}', ''),
      _buildDataRow(context, 'Mode test', config.flightTestMode ? 'Oui' : 'Non', ''),
      _buildDataRow(context, 'Rôles des pyros', pyroRoles, ''),
      _buildDataRow(context, 'Armement minimum', '${config.pyrosArmingMinAltitudeM.toStringAsFixed(1)} m', ''),
      _buildDataRow(context, 'Seuil lancement', '${config.accZLaunchThreshold.toStringAsFixed(2)} m/s²', ''),
      _buildDataRow(context, 'Seuil apogée', '${config.apogeeDetectVThreshold.toStringAsFixed(2)} m/s', ''),
      _buildDataRow(context, 'Altitude principal', '${config.mainDeployAltitudeThresholdM.toStringAsFixed(1)} m', ''),
      _buildDataRow(context, 'Délai tentative pyro', '${config.fireAttemptDelayMs} ms', ''),
      _buildDataRow(context, 'Buzzer', config.enableBuzzer ? '${config.buzzerReportToneHz} Hz' : 'Désactivé', ''),
    ]);
  }

  Widget _buildSectionCard(BuildContext context, String title, IconData icon, List<Widget> rows) {
    return Material(
      color: Colors.transparent,
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate, width: 1.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  Icon(icon, color: FlutterFlowTheme.of(context).primary, size: 24.0),
                  const SizedBox(width: 12.0),
                  Text(
                    title,
                    style: FlutterFlowTheme.of(context).titleMedium.override(
                          font: GoogleFonts.interTight(fontWeight: FontWeight.bold),
                        ),
                  ),
                ],
              ),
              const Divider(height: 24.0, thickness: 1.0, color: Color(0xFFE0E3E7)),
              ...rows.divide(const SizedBox(height: 12.0)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, String label, String value, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(),
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            time,
            textAlign: TextAlign.right,
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: GoogleFonts.inter(),
                  color: FlutterFlowTheme.of(context).tertiary,
                ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedDownloadIndicator extends StatefulWidget {
  const _AnimatedDownloadIndicator();

  @override
  State<_AnimatedDownloadIndicator> createState() => _AnimatedDownloadIndicatorState();
}

class _AnimatedDownloadIndicatorState extends State<_AnimatedDownloadIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = FlutterFlowTheme.of(context).primary;
    return SizedBox(
      width: 22.0,
      height: 22.0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              color: color,
            ),
          ),
          Icon(Icons.download_rounded, size: 11.0, color: color),
        ],
      ),
    );
  }
}

class FlightChartMarker {
  const FlightChartMarker(this.timeSeconds, this.label);

  final double timeSeconds;
  final String label;
}

class FlightChartSeries {
  const FlightChartSeries(this.label, this.value, this.color);

  final String label;
  final double Function(FlightDataSample) value;
  final Color color;
}

class FlightChartPainter extends CustomPainter {
  const FlightChartPainter({
    required this.samples,
    required this.series,
    required this.yAxisLabel,
    required this.markers,
    required this.markerColor,
    required this.gridColor,
    required this.axisColor,
  });

  final List<FlightDataSample> samples;
  final List<FlightChartSeries> series;
  final String yAxisLabel;
  final List<FlightChartMarker> markers;
  final Color markerColor;
  final Color gridColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    const left = 48.0;
    const right = 8.0;
    const top = 12.0;
    const bottom = 30.0;
    final chart = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final firstTime = samples.first.telemetry.timeBootMs / 1000.0;
    final times = samples.map((sample) => sample.telemetry.timeBootMs / 1000.0 - firstTime).toList();
    final values = series
      .expand((item) => samples.map(item.value))
      .where((item) => item.isFinite)
      .toList();
    if (values.isEmpty) return;
    final minTime = times.reduce(min);
    final maxTime = max(times.reduce(max), minTime + 1.0);
    var minValue = values.reduce(min);
    var maxValue = values.reduce(max);
    if ((maxValue - minValue).abs() < 0.001) {
      minValue -= 1.0;
      maxValue += 1.0;
    }
    final gridPaint = Paint()..color = gridColor.withValues(alpha: 0.45)..strokeWidth = 1.0;
    final axisPaint = Paint()..color = axisColor..strokeWidth = 1.2;
    canvas.drawLine(Offset(chart.left, chart.top), Offset(chart.left, chart.bottom), axisPaint);
    canvas.drawLine(Offset(chart.left, chart.bottom), Offset(chart.right, chart.bottom), axisPaint);
    for (var index = 0; index <= 4; index++) {
      final y = chart.top + chart.height * index / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _paintText(
        canvas,
        _formatAxisValue(maxValue - (maxValue - minValue) * index / 4),
        Offset(0, y - 7),
        axisColor,
        10,
      );
      final x = chart.left + chart.width * index / 4;
      canvas.drawLine(Offset(x, chart.bottom), Offset(x, chart.bottom + 4), axisPaint);
      _paintText(
        canvas,
        _formatAxisValue(minTime + (maxTime - minTime) * index / 4),
        Offset(x - 12, chart.bottom + 6),
        axisColor,
        10,
      );
    }
    _paintText(canvas, 'Temps (s)', Offset(chart.center.dx - 28, size.height - 13), axisColor, 10);
    _paintText(canvas, yAxisLabel, Offset(0, chart.top - 11), axisColor, 10);
    for (final item in series) {
      final linePaint = Paint()
        ..color = item.color.withValues(alpha: 0.68)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      final path = Path();
      var hasPoint = false;
      for (var index = 0; index < samples.length; index++) {
        final x = chart.left + ((times[index] - minTime) / (maxTime - minTime)) * chart.width;
        final sampleValue = item.value(samples[index]);
        if (!sampleValue.isFinite) continue;
        final y = chart.bottom - ((sampleValue - minValue) / (maxValue - minValue)) * chart.height;
        if (!hasPoint) {
          path.moveTo(x, y);
          hasPoint = true;
        } else {
          path.lineTo(x, y);
        }
      }
      if (hasPoint) canvas.drawPath(path, linePaint);
    }
    final markerPaint = Paint()..color = markerColor.withValues(alpha: 0.62)..strokeWidth = 1.5;
    for (final marker in markers) {
      if (marker.timeSeconds < minTime || marker.timeSeconds > maxTime) continue;
      final x = chart.left + ((marker.timeSeconds - minTime) / (maxTime - minTime)) * chart.width;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), markerPaint);
      final textPainter = TextPainter(
        text: TextSpan(text: marker.label, style: TextStyle(color: markerColor, fontSize: 10)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x + 2, chart.top));
    }
  }

  String _formatAxisValue(double value) {
    if (value.abs() >= 100 || value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  void _paintText(Canvas canvas, String text, Offset offset, Color color, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant FlightChartPainter oldDelegate) =>
      oldDelegate.samples != samples || oldDelegate.series != series;
}