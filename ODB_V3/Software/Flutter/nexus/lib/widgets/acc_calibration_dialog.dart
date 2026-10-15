import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nexus/services/data_service.dart';
import 'package:nexus/services/console_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';

class AccCalibrationDialog extends StatefulWidget {
  const AccCalibrationDialog({super.key});

  @override
  State<AccCalibrationDialog> createState() => _AccCalibrationDialogState();
}

class _AccCalibrationDialogState extends State<AccCalibrationDialog> {
  int _currentStep = 0;
  String _positionSource = 'odb'; // 'odb', 'phone', 'manual'

  // Étas GPS Smartphone
  bool _isPhoneGpsReady = false;
  bool _isCheckingPhoneGps = true;
  double? _phoneLat;
  double? _phoneAlt;
  String _phoneGpsStatusText = 'Vérification du GPS du téléphone...';

  final TextEditingController _latController =
      TextEditingController(text: '46.862165');
  final TextEditingController _altController =
      TextEditingController(text: '164.8');

  final List<Map<String, dynamic>> _facesInfo = [
    {
      'title': 'Face 1 : Z vers le Ciel',
      'desc': 'Posez la fusée bien à plat, MCU vers le haut (+9.8 m/s² sur Z)',
      'axis': 'Z',
      'sign': 1.0,
    },
    {
      'title': 'Face 2 : Z vers le Sol',
      'desc': 'Retournez la fusée, MCU vers le bas (-9.8 m/s² sur Z)',
      'axis': 'Z',
      'sign': -1.0,
    },
    {
      'title': 'Face 3 : Bluetooth vers le Ciel',
      'desc': 'Posez la fusée sur sa tranche, module Bluetooth vers le haut (+9.8 m/s² sur X capteur)',
      'axis': 'X',
      'sign': 1.0,
    },
    {
      'title': 'Face 4 : Bluetooth vers le Sol',
      'desc': 'Posez la fusée sur la tranche opposée, Bluetooth vers le bas (-9.8 m/s² sur X capteur)',
      'axis': 'X',
      'sign': -1.0,
    },
    {
      'title': 'Face 5 : Face avant vers le Sol',
      'desc': 'Pointez le nez/avant vers le bas, MCU vers vous (+9.8 m/s² sur Y capteur)',
      'axis': 'Y',
      'sign': 1.0,
    },
    {
      'title': 'Face 6 : Face avant vers le Ciel',
      'desc': 'Pointez le nez/avant vers le haut, MCU vers vous (-9.8 m/s² sur Y capteur)',
      'axis': 'Y',
      'sign': -1.0,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = context.read<DataServiceManager>();
      if (_isOdbGpsBaroReady(data)) {
        setState(() => _positionSource = 'odb');
      }
      _checkPhoneGps();
    });
  }

  bool _isOdbGpsBaroReady(DataServiceManager data) {
    return data.gpsSensorState == SensorState.ok &&
        data.barometerSensorState == SensorState.ok &&
        data.gpsFix > 0;
  }

  Future<void> _checkPhoneGps() async {
    setState(() {
      _isCheckingPhoneGps = true;
      _phoneGpsStatusText = 'Vérification du GPS du téléphone...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isPhoneGpsReady = false;
          _isCheckingPhoneGps = false;
          _phoneGpsStatusText = 'Indisponible : Localisation désactivée';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isPhoneGpsReady = false;
          _isCheckingPhoneGps = false;
          _phoneGpsStatusText = 'Indisponible : Permission GPS refusée';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );

      if (!mounted) return;
      setState(() {
        _phoneLat = pos.latitude;
        _phoneAlt = pos.altitude;
        _isPhoneGpsReady = true;
        _isCheckingPhoneGps = false;
        _phoneGpsStatusText =
            'Actif (${pos.latitude.toStringAsFixed(4)}°, Alt: ${pos.altitude.toStringAsFixed(1)} m)';
        final data = context.read<DataServiceManager>();
        if (!_isOdbGpsBaroReady(data) && _positionSource == 'odb') {
          _positionSource = 'phone';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPhoneGpsReady = false;
        _isCheckingPhoneGps = false;
        _phoneGpsStatusText = 'Indisponible : Aucun signal GPS téléphone';
      });
    }
  }

  bool _isOrientationValid(DataServiceManager data, int step) {
    if (step < 1 || step > 6) return false;

    final ax = data.highGAccX;
    final ay = data.highGAccY;
    final az = data.highGAccZ;

    final info = _facesInfo[step - 1];
    final String targetAxis = info['axis'] as String;
    final double sign = info['sign'] as double;

    const double minMainAxisG = 7.0; // m/s2
    const double maxMainAxisG = 12.0; // m/s2
    const double maxOrthoG = 2.0; // m/s2

    double mainVal = 0.0;
    double ortho1 = 0.0;
    double ortho2 = 0.0;

    if (targetAxis == 'Z') {
      mainVal = az * sign;
      ortho1 = ax.abs();
      ortho2 = ay.abs();
    } else if (targetAxis == 'Y') {
      mainVal = ay * sign;
      ortho1 = ax.abs();
      ortho2 = az.abs();
    } else if (targetAxis == 'X') {
      mainVal = ax * sign;
      ortho1 = ay.abs();
      ortho2 = az.abs();
    }

    return (mainVal >= minMainAxisG &&
        mainVal <= maxMainAxisG &&
        ortho1 <= maxOrthoG &&
        ortho2 <= maxOrthoG);
  }

  bool _isManualInputValid() {
    final lat = double.tryParse(_latController.text.replaceAll(',', '.'));
    final alt = double.tryParse(_altController.text.replaceAll(',', '.'));
    return lat != null && lat >= -90.0 && lat <= 90.0 && alt != null;
  }

  @override
  void dispose() {
    _latController.dispose();
    _altController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataServiceManager>();
    final theme = FlutterFlowTheme.of(context);

    final bool odbReady = _isOdbGpsBaroReady(data);

    if (data.accCalibFinishedSuccess != null) {
      final success = data.accCalibFinishedSuccess!;
      data.accCalibFinishedSuccess = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? theme.secondary : theme.error,
            content: Text(
              success
                  ? 'Calibration 6-faces calculée et sauvegardée en Flash !'
                  : 'Erreur lors du calcul ou de la sauvegarde Flash sur l\'ODB.',
            ),
          ),
        );
      });
    }

    if (_positionSource == 'odb' && !odbReady) {
      _positionSource = _isPhoneGpsReady ? 'phone' : 'manual';
    } else if (_positionSource == 'phone' && !_isPhoneGpsReady) {
      _positionSource = odbReady ? 'odb' : 'manual';
    }

    if (_currentStep >= 1 && _currentStep <= 6) {
      if (data.accCalibCapturedFaces >= 6) {
        _currentStep = 7;
      } else if (data.accCalibCapturedFaces >= _currentStep) {
        _currentStep = data.accCalibCapturedFaces + 1;
      }
    }

    final bool isFaceValid = _isOrientationValid(data, _currentStep);
    final Color statusColor = isFaceValid ? theme.success : theme.error;

    String odbSubtitle;
    if (odbReady) {
      odbSubtitle =
          'GPS & Baro OK (${data.gpsLat.toStringAsFixed(4)}°, ${data.altitudeMslM.toStringAsFixed(1)} m)';
    } else {
      final List<String> missing = [];
      if (data.gpsSensorState != SensorState.ok) missing.add('GPS_ERROR');
      if (data.barometerSensorState != SensorState.ok) {
        missing.add('BARO_ERROR');
      }
      if (data.gpsSensorState == SensorState.ok && data.gpsFix <= 0) {
        missing.add('Aucun Fix GPS');
      }
      odbSubtitle = 'Indisponible (${missing.join(', ')})';
    }

    final bool canStartStep0 = (_positionSource == 'odb' && odbReady) ||
        (_positionSource == 'phone' && _isPhoneGpsReady) ||
        (_positionSource == 'manual' && _isManualInputValid());

    return AlertDialog(
      backgroundColor: theme.secondaryBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      title: Row(
        children: [
          Icon(Icons.sensors, color: theme.primary, size: 28),
          const SizedBox(width: 12),
          Text(
            'Calibration 6-Faces',
            style: theme.titleLarge.override(
              font: GoogleFonts.interTight(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_currentStep == 0) ...[
                if (data.highg6FacesCalibrationState == CalibrationState.valid) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Une calibration 6-faces est déjà active et sauvegardée sur l\'ODB.\nDémarrer une nouvelle session écrasera les données actuelles.',
                            style: theme.bodyMedium.override(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Text(
                  'Sélectionnez la source de position pour le calcul de la gravité locale :',
                  style: theme.bodyMedium.override(color: theme.secondaryText),
                ),
                const SizedBox(height: 16),
                RadioGroup<String>(
                  groupValue: _positionSource,
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() => _positionSource = value);
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'odb',
                        enabled: odbReady,
                        activeColor: theme.primary,
                        title: Text(
                          'ODB (Baromètre + GPS embarqué)',
                          style: theme.bodyMedium,
                        ),
                        subtitle: Text(
                          odbSubtitle,
                          style: TextStyle(
                            color: odbReady ? theme.secondary : theme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      RadioListTile<String>(
                        value: 'phone',
                        enabled: _isPhoneGpsReady,
                        activeColor: theme.primary,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'GPS du téléphone',
                                style: theme.bodyMedium,
                              ),
                            ),
                            if (_isCheckingPhoneGps)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                tooltip: 'Actualiser le GPS du téléphone',
                                onPressed: _checkPhoneGps,
                              ),
                          ],
                        ),
                        subtitle: Text(
                          _phoneGpsStatusText,
                          style: TextStyle(
                            color: _isPhoneGpsReady
                                ? theme.secondary
                                : (_isCheckingPhoneGps
                                    ? theme.secondaryText
                                    : theme.error),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      RadioListTile<String>(
                        value: 'manual',
                        activeColor: theme.primary,
                        title: Text(
                          'Saisie manuelle',
                          style: theme.bodyMedium,
                        ),
                        subtitle: Text(
                          'Entrer latitude et altitude manuellement',
                          style: theme.bodySmall.override(
                            color: theme.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_positionSource == 'manual') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _latController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: InputDecoration(
                        labelText: 'Latitude (°)',
                        filled: true,
                        fillColor: theme.primaryBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.alternate),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.alternate),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.primary),
                        )),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _altController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: InputDecoration(
                        labelText: 'Altitude (m)',
                        filled: true,
                        fillColor: theme.primaryBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.alternate),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.alternate),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.primary),
                        )),
                  ),
                ],
              ] else if (_currentStep >= 1 && _currentStep <= 6) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.alternate),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Étape $_currentStep / 6',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.primary)),
                          Icon(Icons.layers, size: 20, color: theme.secondary),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _facesInfo[_currentStep - 1]['title'] as String,
                        style: theme.bodyLarge.override(
                            font:
                                GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _facesInfo[_currentStep - 1]['desc'] as String,
                        style: theme.bodySmall
                            .override(color: theme.secondaryText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 2.0),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFaceValid
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            color: statusColor,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isFaceValid
                                  ? 'Orientation valide — Prêt à capturer'
                                  : 'Orientation incorrecte ou inclinée',
                              style: theme.bodyMedium.override(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            'X: ${data.highGAccX.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Y: ${data.highGAccY.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Z: ${data.highGAccZ.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(height: 1, thickness: 0.8, color: statusColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'PITCH',
                                style: theme.bodySmall.override(
                                  color: theme.secondaryText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${data.pitch.toStringAsFixed(1)}°',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'ROLL',
                                style: theme.bodySmall.override(
                                  color: theme.secondaryText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${data.roll.toStringAsFixed(1)}°',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'YAW',
                                style: theme.bodySmall.override(
                                  color: theme.secondaryText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${data.yaw.toStringAsFixed(1)}°',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: data.isAccCalibBusy
                      ? Column(
                          children: [
                            CircularProgressIndicator(color: theme.primary),
                            const SizedBox(height: 12),
                            Text(
                              'Acquisition en cours sur l\'ODB...\nNe bougez surtout pas la fusée !',
                              textAlign: TextAlign.center,
                              style: theme.bodyMedium.override(
                                color: theme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          isFaceValid
                              ? 'Maintenez la fusée immobile et cliquez sur Capturer.'
                              : 'Tournez la fusée jusqu\'à ce que l\'indicateur passe au vert.',
                          textAlign: TextAlign.center,
                          style: theme.bodySmall
                              .override(color: theme.secondaryText),
                        ),
                ),
              ] else ...[
                Center(
                  child: data.isAccCalibBusy
                      ? Column(
                          children: [
                            CircularProgressIndicator(color: theme.primary),
                            const SizedBox(height: 12),
                            const Text(
                              'Calcul par descente de gradient et sauvegarde Flash en cours...',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                color: theme.secondary, size: 48),
                            SizedBox(height: 12),
                            Text('6 faces capturées avec succès !',
                                style: theme.titleMedium.override(
                                  fontWeight: FontWeight.bold,
                                )),
                            SizedBox(height: 8),
                            Text(
                              'Cliquez sur Calculer pour lancer l\'optimisation par descente de gradient sur l\'ODB et sauvegarder en Flash.',
                              textAlign: TextAlign.center,
                              style: theme.bodyMedium,
                            ),
                          ],
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: data.isAccCalibBusy
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  if (_currentStep > 0) {
                    await data.cancelAccCalibSession();
                  }
                  if (!mounted) return;
                  navigator.pop();
                },
          child: Text(
            'Annuler',
            style: theme.bodyMedium.override(color: theme.secondaryText),
          ),
        ),
        if (_currentStep == 0)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: theme.primaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: (data.isAccCalibBusy || !canStartStep0)
                ? null
                : () async {
                    await data.startAccCalibSession();
                    if (!mounted) return;
                    setState(() {
                      _currentStep = 1;
                    });
                  },
            child: const Text('Commencer'),
          )
        else if (_currentStep >= 1 && _currentStep <= 6)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isFaceValid ? theme.secondary : theme.secondaryText,
              foregroundColor: theme.primaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: (data.isAccCalibBusy || !isFaceValid)
                ? null
                : () async {
                    ConsoleService()
                        .log('Capture de la face $_currentStep en cours...');
                    await data.captureAccCalibFace();
                  },
            child: const Text('Capturer cette face'),
          )
        else
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.error,
              foregroundColor: theme.primaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: data.isAccCalibBusy
                ? null
                : () async {
                    ConsoleService().log('Lancement de l\'optimisation 6-faces sur l\'ODB...');

                    double? latToSend;
                    double? altToSend;
                    if (_positionSource == 'phone' && _phoneLat != null && _phoneAlt != null) {
                      latToSend = _phoneLat;
                      altToSend = _phoneAlt;
                    } else if (_positionSource == 'manual') {
                      latToSend = double.tryParse(_latController.text.replaceAll(',', '.'));
                      altToSend = double.tryParse(_altController.text.replaceAll(',', '.'));
                    }

                    await data.finalizeAccCalib(
                      latitude: latToSend,
                      altitude: altToSend,
                    );
                  },
            child: const Text('Calculer & Sauvegarder'),
          ),
      ],
    );
  }
}
