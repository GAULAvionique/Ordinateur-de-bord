import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:nexus/services/data_service.dart';
import 'settings_page_model.dart';
export 'settings_page_model.dart';

class SettingsPageWidget extends StatefulWidget {
  const SettingsPageWidget({super.key});

  static String routeName = 'SettingsPage';
  static String routePath = '/settingsPage';

  @override
  State<SettingsPageWidget> createState() => _SettingsPageWidgetState();
}

class _SettingsPageWidgetState extends State<SettingsPageWidget> {
  late SettingsPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _odbNameController = TextEditingController();
  final TextEditingController _pyroDelayController = TextEditingController();
  final TextEditingController _pyroFailsafeController = TextEditingController();
  final TextEditingController _minPyrosController = TextEditingController();
  final TextEditingController _accLaunchController = TextEditingController();
  final TextEditingController _boostVoltageController = TextEditingController();
  final TextEditingController _apogeeVoltageController =
      TextEditingController();
  final TextEditingController _landingVoltageController =
      TextEditingController();
  final TextEditingController _landingDelayController = TextEditingController();
  final TextEditingController _apogeeFailsafeController =
      TextEditingController();
  final TextEditingController _deployAltitudeController =
      TextEditingController();
  final TextEditingController _maxDrogueController = TextEditingController();
  final TextEditingController _maxMainController = TextEditingController();
  final TextEditingController _idefixFrequencyController =
      TextEditingController();
  bool _debugMode = false;
  bool _flightTestMode = false;
  int _axisProfileValue = DataServiceManager.axisProfileP0;
  bool _enableBuzzer = false;
  double _buzzerToneHz = 100.0;
  int _stageRoleValue = DataServiceManager.stageRoleSustainer;
  int _apogeeDetectionMode = DataServiceManager.apogeeDetectionKalman;
  final List<int> _pyroRoleValues = List<int>.filled(4, 0);
  String _packageName = '';
  String _appVersion = '';
  String _buildNumber = '';
  String _lastHydratedConfigSignature = '';
  bool _hasPendingTextEdits = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SettingsPageModel());
    _loadPackageInfo();

    _model.expandableExpandableController = ExpandableController(
      initialExpanded: false,
    )..addListener(() => safeSetState(() {}));
    _model.resetExpandableController = ExpandableController(
      initialExpanded: false,
    )..addListener(() => safeSetState(() {}));
    _model.sensorsExpandableController = ExpandableController(
      initialExpanded: false,
    )..addListener(() => safeSetState(() {}));
    _model.pyrosExpandableController = ExpandableController(
      initialExpanded: false,
    )..addListener(() => safeSetState(() {}));
    _model.phaseExpandableController = ExpandableController(
      initialExpanded: false,
    )..addListener(() => safeSetState(() {}));
    _model.parachuteExpandableController = ExpandableController(
      initialExpanded: false,
    )..addListener(() => safeSetState(() {}));
    _model.idefixExpandableController = ExpandableController(
      initialExpanded: false,
    )..addListener(() => safeSetState(() {}));
    _model.audioExpandableController = ExpandableController(
      initialExpanded: false,
    )..addListener(() => safeSetState(() {}));
    _model.aProposExpandableController = ExpandableController(
      initialExpanded: false,
    )..addListener(() => safeSetState(() {}));
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    safeSetState(() {
      _packageName = info.packageName;
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  @override
  void dispose() {
    _odbNameController.dispose();
    _pyroDelayController.dispose();
    _pyroFailsafeController.dispose();
    _minPyrosController.dispose();
    _accLaunchController.dispose();
    _boostVoltageController.dispose();
    _apogeeVoltageController.dispose();
    _landingVoltageController.dispose();
    _landingDelayController.dispose();
    _apogeeFailsafeController.dispose();
    _deployAltitudeController.dispose();
    _maxDrogueController.dispose();
    _maxMainController.dispose();
    _idefixFrequencyController.dispose();
    _model.dispose();

    super.dispose();
  }

  String _buildOdbConfigSignature(DataServiceManager data) {
    return [
      data.odbName,
      data.stageRole,
      data.debugMode,
      data.flightTestMode,
      data.axisProfile,
      data.enableBuzzer,
      data.minNeededPyroNb,
      data.drogueFireAttemptMaxNb,
      data.mainFireAttemptMaxNb,
      data.accZLaunchThreshold,
      data.boostPhaseVThreshold,
      data.apogeeDetectVThreshold,
      data.apogeeDetectionMode,
      data.mainDeployAltitudeThresholdM,
      data.landingDetectVThreshold,
      data.buzzerReportToneHz,
      data.landingDetectThresholdMs,
      data.fireAttemptDelayMs,
      data.pyrosArmingMinAltitudeM,
      data.apogeeFailsafeMs,
      data.idefixFrequencyHz,
      data.pyroRoles.join(','),
    ].join('|');
  }

  int _parseInt(String value, int fallback) =>
      int.tryParse(value.trim()) ?? fallback;
  double _parseDouble(String value, double fallback) =>
      double.tryParse(value.trim().replaceAll(',', '.')) ?? fallback;

  void _syncOdbConfig(DataServiceManager data) {
    if (!data.hasOdbConfig) {
      if (_lastHydratedConfigSignature.isEmpty) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || data.hasOdbConfig) {
          return;
        }

        _lastHydratedConfigSignature = '';
        safeSetState(() {
          _odbNameController.clear();
          _stageRoleValue = DataServiceManager.stageRoleSustainer;
          _apogeeDetectionMode = DataServiceManager.apogeeDetectionKalman;
          _debugMode = false;
          _flightTestMode = false;
          _axisProfileValue = DataServiceManager.axisProfileP0;
          _enableBuzzer = false;
          _buzzerToneHz = 100.0;
          _pyroDelayController.clear();
          _pyroFailsafeController.clear();
          _minPyrosController.clear();
          _accLaunchController.clear();
          _boostVoltageController.clear();
          _apogeeVoltageController.clear();
          _landingVoltageController.clear();
          _landingDelayController.clear();
          _apogeeFailsafeController.clear();
          _deployAltitudeController.clear();
          _maxDrogueController.clear();
          _maxMainController.clear();
          _idefixFrequencyController.clear();
          for (var i = 0; i < _pyroRoleValues.length; i++) {
            _pyroRoleValues[i] = 0;
          }
        });
      });

      return;
    }

    final configSignature = _buildOdbConfigSignature(data);
    if (configSignature == _lastHydratedConfigSignature ||
        _hasPendingTextEdits) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !data.hasOdbConfig) {
        return;
      }

      final hydratedSignature = _buildOdbConfigSignature(data);
      if (hydratedSignature == _lastHydratedConfigSignature) {
        return;
      }

      _lastHydratedConfigSignature = hydratedSignature;
      safeSetState(() {
        _odbNameController.text = data.odbName;
        _stageRoleValue = data.stageRole;
        _debugMode = data.debugMode;
        _flightTestMode = data.flightTestMode;
        _axisProfileValue = data.axisProfile;
        _enableBuzzer = data.enableBuzzer;
        _buzzerToneHz = data.buzzerReportToneHz > 0
            ? data.buzzerReportToneHz.toDouble()
            : _buzzerToneHz;
        _pyroDelayController.text = data.fireAttemptDelayMs.toString();
        _pyroFailsafeController.text =
          data.pyrosArmingMinAltitudeM.toStringAsFixed(2);
        _minPyrosController.text = data.minNeededPyroNb.toString();
        _accLaunchController.text = data.accZLaunchThreshold.toStringAsFixed(2);
        _boostVoltageController.text = data.boostPhaseVThreshold.toStringAsFixed(2);
        _apogeeVoltageController.text = data.apogeeDetectVThreshold.toStringAsFixed(2);
        _apogeeDetectionMode = data.apogeeDetectionMode;
        _landingVoltageController.text = data.landingDetectVThreshold.toStringAsFixed(2);
        _landingDelayController.text = data.landingDetectThresholdMs.toString();
        _apogeeFailsafeController.text = data.apogeeFailsafeMs.toString();
        _deployAltitudeController.text = data.mainDeployAltitudeThresholdM.toStringAsFixed(2);
        _maxDrogueController.text = data.drogueFireAttemptMaxNb.toString();
        _maxMainController.text = data.mainFireAttemptMaxNb.toString();
        _idefixFrequencyController.text = data.idefixFrequencyHz.toString();
        for (var i = 0; i < _pyroRoleValues.length; i++) {
          _pyroRoleValues[i] = i < data.pyroRoles.length ? data.pyroRoles[i] : 0;
        }
      });
    });
  }

  Widget _buildStageRoleDropdown(
    BuildContext context, {
    required DataServiceManager data,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
        SizedBox(
          width: 180,
          child: Text(
            'Rôle de stage',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  fontSize: 14.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
          ),
        ),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _stageRoleValue == DataServiceManager.stageRoleBooster
                ? DataServiceManager.stageRoleBooster
                : DataServiceManager.stageRoleSustainer,
            onChanged: enabled
                ? (value) {
                    if (value == null) return;
                    safeSetState(() {
                      _stageRoleValue = value;
                    });
                    data.stageRole = value;
                  }
                : null,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              filled: true,
              fillColor: FlutterFlowTheme.of(context).secondaryBackground,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context).primary,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem<int>(
                value: DataServiceManager.stageRoleBooster,
                child: Text('Booster'),
              ),
              DropdownMenuItem<int>(
                value: DataServiceManager.stageRoleSustainer,
                child: Text('Sustainer'),
              ),
            ],
          ),
        ),
          ],
        ),
        _buildParameterDescription(
          context,
          'Booster: étage propulsif. Sustainer: étage qui poursuit le vol après séparation.',
        ),
      ],
    );
  }

  Widget _buildAxisProfileDropdown(
    BuildContext context, {
    required DataServiceManager data,
    required bool enabled,
  }) {
    final axisProfileLabels = <String>[
      'Z+',
      'Z+90°',
      'Z+180°',
      'Z+270°',
      'Y+',
      'X-',
      'Y-',
      'X+',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
        SizedBox(
          width: 180,
          child: Text(
            'Profil axe',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  fontSize: 14.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
          ),
        ),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _axisProfileValue,
            onChanged: enabled
                ? (value) {
                    if (value == null) return;
                    safeSetState(() {
                      _axisProfileValue = value;
                    });
                    data.axisProfile = value;
                  }
                : null,
            isExpanded: true,
            items: List.generate(
              axisProfileLabels.length,
              (index) => DropdownMenuItem<int>(
                value: index,
                child: Text(axisProfileLabels[index]),
              ),
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              filled: true,
              fillColor: FlutterFlowTheme.of(context).secondaryBackground,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context).primary,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
          ],
        ),
      ],
    );
  }

  Widget _buildAxisVisualizer(BuildContext context, int profile) {
    String noseAxis = '';
    String description = '';
    IconData visualIcon;
    Color iconColor = FlutterFlowTheme.of(context).primary;

    switch (profile) {
      case 0:
      case 1:
      case 2:
      case 3:
        noseAxis = 'Axe +Z (P0-P3)';
        description = 'La carte est fixée à plat. L\'axe Z pointe vers le nez.';
        visualIcon = Icons.layers;
        iconColor = FlutterFlowTheme.of(context).secondary;
        break;
      case 4:
        noseAxis = 'Axe +Y (P4)';
        description = 'La carte est fixée verticalement. Le module Bluetooth pointe vers le nez de la fusée.';
        visualIcon = Icons.arrow_upward_rounded;
        iconColor = FlutterFlowTheme.of(context).warning;
        break;
      case 5:
        noseAxis = 'Axe -X (P5)';
        description = 'La carte est fixée horizontalement. Le module Bluetooth pointe vers la droite de la fusée.';
        visualIcon = Icons.arrow_downward_rounded;
        iconColor = FlutterFlowTheme.of(context).error;
        break;
      case 6:
        noseAxis = 'Axe -Y (P6)';
        description = 'La carte est fixée verticalement. Le module Bluetooth pointe vers le sol.';
        visualIcon = Icons.arrow_downward_rounded;
        iconColor = FlutterFlowTheme.of(context).error;
        break;
      case 7:
        noseAxis = 'Axe +X (P7)';
        description = 'La carte est fixée horizontalement. Le module Bluetooth pointe vers la gauche de la fusée.';
        visualIcon = Icons.arrow_upward_rounded;
        iconColor = FlutterFlowTheme.of(context).warning;
        break;
      default:
        noseAxis = 'Inconnu';
        description = 'Profil non reconnu.';
        visualIcon = Icons.help_outline;
        iconColor = FlutterFlowTheme.of(context).error;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey<int>(profile),
        margin: const EdgeInsets.only(top: 16.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).primaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 4,
                    color: Color(0x1A000000),
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Icon(
                visualIcon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Direction Apogée : $noseAxis',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                          ),
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.inter(
                            height: 1.4,
                          ),
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _pyroRoleLabels = [
    'NA',
    'M1',
    'D1',
    'M2',
    'D2',
  ];

  Widget _buildPyroRoleDropdown(
    BuildContext context, {
    required DataServiceManager data,
    required int pyroIndex,
    required bool enabled,
  }) {
    final currentValue = _pyroRoleValues[pyroIndex].clamp(0, 4).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
          SizedBox(
            width: 180,
            child: Text(
              'Pyro ${pyroIndex + 1}',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    fontSize: 14.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
            ),
          ),
          Expanded(
            child: InputDecorator(
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).primary,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: currentValue,
                  isDense: true,
                  isExpanded: true,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  menuMaxHeight: 280,
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor:
                      FlutterFlowTheme.of(context).secondaryBackground,
                  onChanged: enabled
                      ? (value) {
                          if (value == null) return;
                          safeSetState(() {
                            _pyroRoleValues[pyroIndex] = value;
                            data.pyroRoles[pyroIndex] = value;
                          });
                        }
                      : null,
                  items: List.generate(
                    _pyroRoleLabels.length,
                    (index) => DropdownMenuItem<int>(
                      value: index,
                      child: Text(_pyroRoleLabels[index]),
                    ),
                  ),
                ),
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledSettingField(
    BuildContext context, {
    required String label,
    required String description,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    String? initialValue,
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    bool enabled = true,
  }) {
    final field = TextFormField(
      controller: controller,
      initialValue: controller == null ? (initialValue ?? '') : null,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLength: maxLength,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        filled: true,
        fillColor: FlutterFlowTheme.of(context).secondaryBackground,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: FlutterFlowTheme.of(context).primary,
            width: 1,
          ),
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: Text(
                label,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontStyle: FlutterFlowTheme.of(
                          context,
                        ).bodyMedium.fontStyle,
                      ),
                      fontSize: 14.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
              ),
            ),
            Expanded(child: field),
          ],
        ),
        _buildParameterDescription(context, description),
      ],
    );
  }

  Widget _buildParameterDescription(BuildContext context, String description) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
      child: Text(
        description,
        style: FlutterFlowTheme.of(context).bodySmall.override(
              font: GoogleFonts.inter(),
              color: FlutterFlowTheme.of(context).secondaryText,
              fontSize: 12.0,
            ),
      ),
    );
  }

  Widget _buildBooleanSetting(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: enabled ? onChanged : null,
      title: Text(
        title,
        style: FlutterFlowTheme.of(context).bodyLarge.override(
              font: GoogleFonts.inter(
                fontWeight: FlutterFlowTheme.of(context).bodyLarge.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
              ),
              letterSpacing: 0.0,
              fontWeight: FlutterFlowTheme.of(context).bodyLarge.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: FlutterFlowTheme.of(context).bodySmall.override(
              font: GoogleFonts.inter(
                fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
              ),
              color: FlutterFlowTheme.of(context).secondaryText,
              letterSpacing: 0.0,
              fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
            ),
      ),
      activeThumbColor: FlutterFlowTheme.of(context).primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSliderSetting(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required String description,
    required ValueChanged<double> onChanged,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
        SizedBox(
          width: 180,
          child: Text(
            '$label: ${value.round()}',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  fontSize: 14.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: 260,
            activeColor: FlutterFlowTheme.of(context).primary,
            onChanged: enabled ? onChanged : null,
          ),
        ),
          ],
        ),
        _buildParameterDescription(context, description),
      ],
    );
  }

  Widget _buildSectionCard(BuildContext context, Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            color: const Color(0x33000000),
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }

  Widget _buildProfileSection(
    BuildContext context,
    TextStyle headerStyle, {
    required DataServiceManager data,
    required bool enabled,
  }) {
    return _buildSectionCard(
      context,
      Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(
                Icons.person,
                color: FlutterFlowTheme.of(context).primary,
                size: 24.0,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  16.0,
                  0.0,
                  0.0,
                  0.0,
                ),
                child: Text('Profile', style: headerStyle),
              ),
            ],
          ),
          _buildLabeledSettingField(
            context,
            label: 'Nom ODB',
            description: 'Nom affiché pour identifier cette carte ODB.',
            hintText: '',
            maxLength: 12,
            controller: _odbNameController,
            enabled: enabled,
            onChanged: (_) {
              safeSetState(() {
                _hasPendingTextEdits = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStageSection(
    BuildContext context,
    TextStyle headerStyle, {
    required DataServiceManager data,
    required bool enabled,
  }) {
    return _buildSectionCard(
      context,
      ExpandableNotifier(
        controller: _model.resetExpandableController,
        child: ExpandablePanel(
          header: Row(
            children: [
              Icon(
                Icons.layers,
                color: FlutterFlowTheme.of(context).primary,
                size: 24,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 0, 0),
                child: Text('Stage', style: headerStyle),
              ),
            ],
          ),
          collapsed: const SizedBox.shrink(),
          expanded: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStageRoleDropdown(context, data: data, enabled: enabled),
              _buildBooleanSetting(
                context,
                title: 'Mode Debug',
                subtitle: 'Activé: fonctions et diagnostics de debug; désactivé: fonctionnement normal.',
                value: _debugMode,
                enabled: enabled,
                onChanged: (value) {
                  safeSetState(() {
                    _debugMode = value;
                  });
                  data.debugMode = value;
                },
              ),
              _buildBooleanSetting(
                context,
                title: 'Mode Test Flight',
                subtitle: 'Activé: simulation de vol sans déclenchement réel; désactivé: séquence de vol normale.',
                value: _flightTestMode,
                enabled: enabled,
                onChanged: (value) {
                  safeSetState(() {
                    _flightTestMode = value;
                  });
                  data.flightTestMode = value;
                },
              ),
            ].divide(const SizedBox(height: 12.0)),
          ),
        ),
      ),
    );
  }

  Widget _buildPyrosSection(
    BuildContext context,
    TextStyle headerStyle, {
    required DataServiceManager data,
    required bool enabled,
  }) {
    return _buildSectionCard(
      context,
      ExpandableNotifier(
        controller: _model.pyrosExpandableController,
        child: ExpandablePanel(
          header: Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: FlutterFlowTheme.of(context).tertiary,
                size: 24,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 0, 0),
                child: Text('Pyros', style: headerStyle),
              ),
            ],
          ),
          collapsed: const SizedBox.shrink(),
          expanded: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(
                4,
                (index) => _buildPyroRoleDropdown(
                  context,
                  data: data,
                  pyroIndex: index,
                  enabled: enabled,
                ),
              ),
              _buildParameterDescription(
                context,
                'Pour chaque sortie: NA = inutilisée; M1 = parachute principal; D1 = drogue; M2 et D2 = sorties de secours correspondantes.',
              ),
              _buildLabeledSettingField(
                context,
                label: 'Délai essais allumage (ms)',
                description: 'Temps entre deux tentatives d’allumage d’un même pyro.',
                hintText: '',
                keyboardType: TextInputType.number,
                controller: _pyroDelayController,
                enabled: enabled,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
              _buildLabeledSettingField(
                context,
                label: 'Altitude minimale armement pyros (m)',
                description: 'Altitude minimale avant d’autoriser l’armement des pyros.',
                hintText: '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                controller: _pyroFailsafeController,
                enabled: enabled,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
              _buildLabeledSettingField(
                context,
                label: 'Nombre minimal de pyros lancement',
                description: 'Nombre de pyros connectés requis pour autoriser le lancement.',
                hintText: '',
                keyboardType: TextInputType.number,
                controller: _minPyrosController,
                enabled: enabled,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
            ].divide(const SizedBox(height: 12.0)),
          ),
        ),
      ),
    );
  }

  Widget _buildSensorsSection(
    BuildContext context,
    TextStyle headerStyle, {
    required DataServiceManager data,
    required bool enabled,
  }) {
    return _buildSectionCard(
      context,
      ExpandableNotifier(
        controller: _model.sensorsExpandableController,
        child: ExpandablePanel(
          header: Row(
            children: [
              Icon(
                Icons.sensors,
                color: FlutterFlowTheme.of(context).primary,
                size: 24,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 0, 0),
                child: Text('Capteurs', style: headerStyle),
              ),
            ],
          ),
          collapsed: const SizedBox.shrink(),
          expanded: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAxisProfileDropdown(context, data: data, enabled: enabled),
              _buildAxisVisualizer(context, _axisProfileValue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseSection(
    BuildContext context,
    TextStyle headerStyle, {
    required DataServiceManager data,
    required bool enabled,
  }) {
    return _buildSectionCard(
      context,
      ExpandableNotifier(
        controller: _model.phaseExpandableController,
        child: ExpandablePanel(
          header: Row(
            children: [
              Icon(
                Icons.stacked_line_chart,
                color: FlutterFlowTheme.of(context).warning,
                size: 24,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 0, 0),
                child: Text('Phases', style: headerStyle),
              ),
            ],
          ),
          collapsed: const SizedBox.shrink(),
          expanded: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildApogeeDetectionModeDropdown(
                context,
                data: data,
                enabled: enabled,
              ),
              _buildLabeledSettingField(
                context,
                label: 'Seuil accélération verticale lancement (m/s²)',
                description: 'Accélération verticale minimale qui valide le décollage.',
                hintText: '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                controller: _accLaunchController,
                enabled: enabled,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
              _buildLabeledSettingField(
                context,
                label: 'Seuil vitesse boost (m/s)',
                description: 'Vitesse verticale à partir de laquelle la phase boost est terminée.',
                hintText: '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                controller: _boostVoltageController,
                enabled: enabled,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
              _buildLabeledSettingField(
                context,
                label: 'Seuil vitesse détection apogée (m/s)',
                description: 'Vitesse verticale utilisée par les modes Auto et Kalman pour détecter l’apogée.',
                hintText: '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                controller: _apogeeVoltageController,
                enabled: enabled &&
                  _apogeeDetectionMode !=
                    DataServiceManager.apogeeDetectionBarometric,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
              _buildLabeledSettingField(
                context,
                label: 'Seuil vitesse détection atterrissage (m/s)',
                description: 'Vitesse verticale maximale à maintenir pendant la durée de confirmation d’atterrissage.',
                hintText: '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                controller: _landingVoltageController,
                enabled: enabled,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
              _buildLabeledSettingField(
                context,
                label: 'Délai détection atterrissage (ms)',
                description: 'Durée pendant laquelle la vitesse doit rester sous le seuil avant de déclarer l’atterrissage.',
                hintText: '',
                keyboardType: TextInputType.number,
                controller: _landingDelayController,
                enabled: enabled,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
              _buildLabeledSettingField(
                context,
                label: 'Délai failsafe apogée (ms)',
                description: 'Délai maximal avant de forcer le passage à la phase drogue si l’apogée n’est pas détectée.',
                hintText: '',
                keyboardType: TextInputType.number,
                controller: _apogeeFailsafeController,
                enabled: enabled,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
            ].divide(const SizedBox(height: 12.0)),
          ),
        ),
      ),
    );
  }

  Widget _buildApogeeDetectionModeDropdown(
    BuildContext context, {
    required DataServiceManager data,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
        Expanded(
          flex: 2,
          child: Text(
            'Mode détection apogée',
            softWrap: true,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  fontSize: 14.0,
                ),
          ),
        ),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            initialValue: _apogeeDetectionMode,
            isExpanded: true,
            onChanged: enabled
                ? (value) {
                    if (value == null) return;
                    safeSetState(() {
                      _apogeeDetectionMode = value;
                      _hasPendingTextEdits = true;
                    });
                    data.apogeeDetectionMode = value;
                  }
                : null,
            items: const [
              DropdownMenuItem<int>(
                value: DataServiceManager.apogeeDetectionAuto,
                child: Text('Auto'),
              ),
              DropdownMenuItem<int>(
                value: DataServiceManager.apogeeDetectionKalman,
                child: Text('Kalman'),
              ),
              DropdownMenuItem<int>(
                value: DataServiceManager.apogeeDetectionBarometric,
                child: Text('Barométrique'),
              ),
            ],
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              filled: true,
              fillColor: FlutterFlowTheme.of(context).secondaryBackground,
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: FlutterFlowTheme.of(context).alternate,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
          ],
        ),
        _buildParameterDescription(
          context,
          'Auto: Kalman pour un sustainer et barométrique pour un booster; Kalman: vitesse filtrée; Barométrique: tendance d’altitude descendante.',
        ),
      ],
    );
  }

  Widget _buildIdefixSection(
    BuildContext context,
    TextStyle headerStyle, {
    required DataServiceManager data,
    required bool enabled,
  }) {
    return _buildSectionCard(
      context,
      ExpandableNotifier(
        controller: _model.idefixExpandableController,
        child: ExpandablePanel(
          header: Row(
            children: [
              Icon(
                Icons.memory,
                color: FlutterFlowTheme.of(context).secondary,
                size: 24,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 0, 0),
                child: Text('Idefix', style: headerStyle),
              ),
            ],
          ),
          collapsed: const SizedBox.shrink(),
          expanded: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabeledSettingField(
                context,
                label: 'Fréquence Idefix (Hz)',
                description: 'Fréquence radio utilisée par le module Idefix pour communiquer avec le beacon.',
                hintText: '',
                keyboardType: TextInputType.number,
                controller: _idefixFrequencyController,
                enabled: enabled,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParachuteSection(
    BuildContext context,
    TextStyle headerStyle, {
    required DataServiceManager data,
    required bool enabled,
  }) {
    return _buildSectionCard(
      context,
      ExpandableNotifier(
        controller: _model.parachuteExpandableController,
        child: ExpandablePanel(
          header: Row(
            children: [
              Icon(
                Icons.paragliding,
                color: FlutterFlowTheme.of(context).secondary,
                size: 24,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 0, 0),
                child: Text('Parachute', style: headerStyle),
              ),
            ],
          ),
          collapsed: const SizedBox.shrink(),
          expanded: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabeledSettingField(
                context,
                label: 'Altitude déploiement main (m)',
                description: 'Altitude à laquelle l’ODB quitte la phase drogue et commande le parachute principal.',
                hintText: '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                controller: _deployAltitudeController,
                enabled: enabled,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
              _buildLabeledSettingField(
                context,
                label: 'Nombre max essais drogue',
                description: 'Nombre maximal de tentatives pour déclencher le parachute drogue.',
                hintText: '',
                keyboardType: TextInputType.number,
                controller: _maxDrogueController,
                enabled: enabled,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
              _buildLabeledSettingField(
                context,
                label: 'Nombre max essais main',
                description: 'Nombre maximal de tentatives pour déclencher le parachute principal.',
                hintText: '',
                keyboardType: TextInputType.number,
                controller: _maxMainController,
                enabled: enabled,
                onChanged: (_) {
                  safeSetState(() {
                    _hasPendingTextEdits = true;
                  });
                },
              ),
            ].divide(const SizedBox(height: 12.0)),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioSection(
    BuildContext context,
    TextStyle headerStyle, {
    required DataServiceManager data,
    required bool enabled,
  }) {
    return _buildSectionCard(
      context,
      ExpandableNotifier(
        controller: _model.audioExpandableController,
        child: ExpandablePanel(
          header: Row(
            children: [
              Icon(
                Icons.audiotrack,
                color: FlutterFlowTheme.of(context).secondary,
                size: 24,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 0, 0),
                child: Text('Audio', style: headerStyle),
              ),
            ],
          ),
          collapsed: const SizedBox.shrink(),
          expanded: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBooleanSetting(
                context,
                title: 'Buzzer',
                subtitle: 'Activé: rapports sonores de l’ODB; désactivé: aucun rapport sonore.',
                value: _enableBuzzer,
                enabled: enabled,
                onChanged: (value) {
                  safeSetState(() {
                    _enableBuzzer = value;
                  });
                  data.enableBuzzer = value;
                },
              ),
              _buildSliderSetting(
                context,
                label: 'Tonalité buzzer (Hz)',
                description: 'Fréquence sonore du buzzer lorsque les rapports audio sont activés.',
                value: _buzzerToneHz,
                min: 100.0,
                max: 2700.0,
                enabled: enabled,
                onChanged: (value) {
                  safeSetState(() {
                    _buzzerToneHz = value;
                  });
                  data.buzzerReportToneHz = value.round();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection(
    BuildContext context,
    TextStyle headerStyle,
    DataServiceManager data,
  ) {
    return _buildSectionCard(
      context,
      ExpandableNotifier(
        controller: _model.aProposExpandableController,
        child: ExpandablePanel(
          header: Row(
            children: [
              Icon(
                Icons.info,
                color: FlutterFlowTheme.of(context).secondaryText,
                size: 24,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 0, 0),
                child: Text('À propos', style: headerStyle),
              ),
            ],
          ),
          collapsed: const SizedBox.shrink(),
          expanded: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Package'),
                subtitle: Text(
                  _packageName.isNotEmpty ? _packageName : 'Chargement...',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Version de l’application'),
                subtitle: Text(
                  _appVersion.isNotEmpty
                      ? '$_appVersion+$_buildNumber'
                      : 'Chargement...',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Version de la trame ODB'),
                subtitle: Text(
                  data.odbFrameVersion.isNotEmpty
                      ? data.odbFrameVersion
                      : 'Inconnue',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Version de la Config ODB'),
                subtitle: Text(
                  data.odbConfigFrameVersion.isNotEmpty
                      ? data.odbConfigFrameVersion
                      : 'Inconnue',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResetSection(
    BuildContext context,
    TextStyle headerStyle,
    DataServiceManager data,
  ) {
    return _buildSectionCard(
      context,
      ExpandableNotifier(
        controller: _model.expandableExpandableController,
        child: ExpandablePanel(
          header: Row(
            children: [
              Icon(
                Icons.restart_alt_rounded,
                color: FlutterFlowTheme.of(context).warning,
                size: 24,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 0, 0),
                child: Text('Réinitialisation', style: headerStyle),
              ),
            ],
          ),
          collapsed: const SizedBox.shrink(),
          expanded: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attention : ces actions réinitialisent la configuration ou la mémoire complète de l\'ODB.',
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.inter(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).warning,
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).bodySmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
              ),
              Center(
                child: ElevatedButton.icon(
                  onPressed: data.hasConnection
                      ? () async {
                          await data.resetOdbFlights();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Réinitialisation des données de vol ODB demandée',
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset vols'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlutterFlowTheme.of(context).warning,
                    foregroundColor: FlutterFlowTheme.of(
                      context,
                    ).primaryBackground,
                  ),
                ),
              ),
              Center(
                child: ElevatedButton.icon(
                  onPressed: data.hasConnection
                      ? () async {
                          await data.resetOdbSettingsToDefault();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Réinitialisation de la configuration ODB demandée',
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset config'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlutterFlowTheme.of(context).warning,
                    foregroundColor: FlutterFlowTheme.of(
                      context,
                    ).primaryBackground,
                  ),
                ),
              ),
              Center(
                child: ElevatedButton.icon(
                  onPressed: data.hasConnection
                      ? () async {
                          await data.resetOdbMemory();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Réinitialisation mémoire ODB demandée',
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset mémoire'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlutterFlowTheme.of(context).warning,
                    foregroundColor: FlutterFlowTheme.of(
                      context,
                    ).primaryBackground,
                  ),
                ),
              ),
            ].divide(const SizedBox(height: 12.0)),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, DataServiceManager data) {
    final canSend = data.hasConnection;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canSend
                ? () async {
                    await data.refreshOdb();
                    if (!context.mounted) return;
                    safeSetState(() {
                      _hasPendingTextEdits = false;
                    });
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Rafraîchissement configuration ODB demandé',
                        ),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlutterFlowTheme.of(context).primary,
              foregroundColor: FlutterFlowTheme.of(context).primaryBackground,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canSend
                ? () async {
                    final currentConfig = data.config ??
                        OdbConfig(
                          odbName: data.odbName,
                          stageRole: data.stageRole,
                          debugMode: data.debugMode,
                          flightTestMode: data.flightTestMode,
                          axisProfile: data.axisProfile,
                          fireAttemptDelayMs: data.fireAttemptDelayMs,
                            pyrosArmingMinAltitudeM:
                              data.pyrosArmingMinAltitudeM,
                          minNeededPyroNb: data.minNeededPyroNb,
                          pyroRoles: data.pyroRoles,
                            apogeeDetectionMode: data.apogeeDetectionMode,
                          accZLaunchThreshold: data.accZLaunchThreshold,
                          boostPhaseVThreshold: data.boostPhaseVThreshold,
                          apogeeDetectVThreshold: data.apogeeDetectVThreshold,
                          landingDetectVThreshold: data.landingDetectVThreshold,
                          landingDetectThresholdMs:
                              data.landingDetectThresholdMs,
                          apogeeFailsafeMs: data.apogeeFailsafeMs,
                          mainDeployAltitudeThresholdM:
                              data.mainDeployAltitudeThresholdM,
                          drogueFireAttemptMaxNb: data.drogueFireAttemptMaxNb,
                          mainFireAttemptMaxNb: data.mainFireAttemptMaxNb,
                          enableBuzzer: data.enableBuzzer,
                          buzzerReportToneHz: data.buzzerReportToneHz,
                          idefixFrequencyHz: data.idefixFrequencyHz,
                        );
                    final newConfig = currentConfig.copyWith(
                      odbName: _odbNameController.text.trim(),
                      stageRole: _stageRoleValue,
                      debugMode: _debugMode,
                      flightTestMode: _flightTestMode,
                      axisProfile: _axisProfileValue,
                      enableBuzzer: _enableBuzzer,
                      minNeededPyroNb: _parseInt(
                          _minPyrosController.text, data.minNeededPyroNb),
                      drogueFireAttemptMaxNb: _parseInt(
                          _maxDrogueController.text,
                          data.drogueFireAttemptMaxNb),
                      mainFireAttemptMaxNb: _parseInt(
                          _maxMainController.text, data.mainFireAttemptMaxNb),
                      accZLaunchThreshold: _parseDouble(
                          _accLaunchController.text, data.accZLaunchThreshold),
                      boostPhaseVThreshold: _parseDouble(
                          _boostVoltageController.text,
                          data.boostPhaseVThreshold),
                      apogeeDetectVThreshold: _parseDouble(
                          _apogeeVoltageController.text,
                          data.apogeeDetectVThreshold),
                        apogeeDetectionMode: _apogeeDetectionMode,
                      mainDeployAltitudeThresholdM: _parseDouble(
                          _deployAltitudeController.text,
                          data.mainDeployAltitudeThresholdM),
                      landingDetectVThreshold: _parseDouble(
                          _landingVoltageController.text,
                          data.landingDetectVThreshold),
                      buzzerReportToneHz: _buzzerToneHz.round(),
                      landingDetectThresholdMs: _parseInt(
                          _landingDelayController.text,
                          data.landingDetectThresholdMs),
                      fireAttemptDelayMs: _parseInt(
                          _pyroDelayController.text, data.fireAttemptDelayMs),
                        pyrosArmingMinAltitudeM: _parseDouble(
                          _pyroFailsafeController.text,
                          data.pyrosArmingMinAltitudeM),
                      apogeeFailsafeMs: _parseInt(
                          _apogeeFailsafeController.text,
                          data.apogeeFailsafeMs),
                      idefixFrequencyHz: _parseInt(
                          _idefixFrequencyController.text,
                          data.idefixFrequencyHz),
                      pyroRoles: _pyroRoleValues,
                    );
                    await data.applyOdbSettings(newConfig);
                    if (!context.mounted) return;
                    safeSetState(() {
                      _hasPendingTextEdits = false;
                    });
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Paramètres ODB envoyés')),
                    );
                  }
                : null,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Appliquer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FlutterFlowTheme.of(context).error,
              foregroundColor: FlutterFlowTheme.of(context).primaryBackground,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataServiceManager>();
    final connected = data.hasConnection;
    _syncOdbConfig(data);

    final expandableHeaderStyle =
        FlutterFlowTheme.of(context).bodyMedium.override(
              font: GoogleFonts.interTight(
                fontWeight: FontWeight.w600,
                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
              ),
              fontSize: 16.0,
              letterSpacing: 0.0,
              fontWeight: FontWeight.w600,
              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
            );

    final sections = <Widget>[
      _buildProfileSection(
        context,
        expandableHeaderStyle,
        data: data,
        enabled: connected,
      ),
      _buildSensorsSection(
        context,
        expandableHeaderStyle,
        data: data,
        enabled: connected,
      ),
      _buildStageSection(
        context,
        expandableHeaderStyle,
        data: data,
        enabled: connected,
      ),
      _buildPyrosSection(
        context,
        expandableHeaderStyle,
        data: data,
        enabled: connected,
      ),
      _buildPhaseSection(
        context,
        expandableHeaderStyle,
        data: data,
        enabled: connected,
      ),
      _buildParachuteSection(
        context,
        expandableHeaderStyle,
        data: data,
        enabled: connected,
      ),
      _buildIdefixSection(
        context,
        expandableHeaderStyle,
        data: data,
        enabled: connected,
      ),
      _buildAudioSection(
        context,
        expandableHeaderStyle,
        data: data,
        enabled: connected,
      ),
      _buildResetSection(context, expandableHeaderStyle, data),
      _buildActionButtons(context, data),
      Text(
        'Certains paramètres nécessitent le redémarrage de l\'alimentation pour prendre effet.',
        style: FlutterFlowTheme.of(context).bodySmall.override(
              font: GoogleFonts.inter(
                fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
              ),
              color: FlutterFlowTheme.of(context).warning,
              letterSpacing: 0.0,
              fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
            ),
      ),
      _buildAboutSection(context, expandableHeaderStyle, data),
    ];

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
            padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: FlutterFlowTheme.of(context).displaySmall.override(
                          font: GoogleFonts.interTight(
                            fontWeight: FontWeight.bold,
                            fontStyle: FlutterFlowTheme.of(
                              context,
                            ).displaySmall.fontStyle,
                          ),
                          fontSize: 28.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.bold,
                          fontStyle: FlutterFlowTheme.of(
                            context,
                          ).displaySmall.fontStyle,
                        ),
                  ),
                  Text(
                    'Paramètres Nexus & de l\'ordinateur de bord',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FlutterFlowTheme.of(
                              context,
                            ).bodyMedium.fontWeight,
                            fontStyle: FlutterFlowTheme.of(
                              context,
                            ).bodyMedium.fontStyle,
                          ),
                          color: FlutterFlowTheme.of(
                            context,
                          ).secondaryText,
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(
                            context,
                          ).bodyMedium.fontWeight,
                          fontStyle: FlutterFlowTheme.of(
                            context,
                          ).bodyMedium.fontStyle,
                        ),
                  ),
                  ...sections,
                ]
                    .divide(SizedBox(height: 16.0))
                    .addToStart(SizedBox(height: 16.0))
                    .addToEnd(SizedBox(height: 24.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
