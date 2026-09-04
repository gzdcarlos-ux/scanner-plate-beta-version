import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/models/renajud_status.dart';
import '../core/renajud_service.dart';
import '../services/alert_service.dart';
import '../services/plate_ocr_service.dart';
import '../widgets/alert_card.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  final PlateOcrService _ocrService = PlateOcrService();
  final AlertService _alertService = AlertService(cooldown: const Duration(seconds: 3));
  final RenajudService _renajudService = RenajudService();

  // Trava de processamento: evita que um novo frame seja analisado pelo
  // ML Kit enquanto o anterior ainda não terminou, prevenindo o acúmulo
  // de frames em memória e travamentos do app.
  bool _isProcessing = false;

  bool _isCameraReady = false;
  String? _lastRawPlateSeen;
  RenajudStatus? _activeAlert;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        // YUV420 é o formato exigido para a conversão manual feita em
        // PlateOcrService no Android.
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
      });

      await controller.startImageStream(_onFrameAvailable);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar câmera: $e')),
        );
      }
    }
  }

  /// Callback chamado pelo `camera` a cada novo frame do stream.
  /// Aplica a trava `_isProcessing` para descartar frames enquanto o
  /// anterior ainda está sendo processado pelo ML Kit.
  Future<void> _onFrameAvailable(CameraImage image) async {
    if (_isProcessing) return; // descarta o frame — processamento anterior ainda em curso
    _isProcessing = true;

    try {
      final controller = _cameraController;
      if (controller == null) return;

      final plates = await _ocrService.processFrame(
        image: image,
        cameraDescription: controller.description,
        sensorOrientation: controller.description.sensorOrientation,
      );

      for (final plate in plates) {
        await _handleRecognizedPlate(plate);
      }
    } catch (_) {
      // Falhas pontuais de OCR em um frame não devem derrubar o stream.
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _handleRecognizedPlate(String plate) async {
    _lastRawPlateSeen = plate;

    // RenajudService decide sozinho a ordem de consulta (mock -> local ->
    // remoto). A tela não sabe (nem precisa saber) de onde veio a resposta.
    final status = await _renajudService.check(plate);

    // Só dispara alerta se HÁ restrição confirmada. Placa não encontrada
    // ou erro não geram alerta — apenas atualizam o texto de debug.
    if (!status.isRestricted) {
      if (mounted) setState(() {}); // atualiza apenas o "última placa lida"
      return;
    }

    // Aplica o cooldown para não repetir o mesmo alerta a cada frame.
    if (!_alertService.shouldAlert(plate)) return;

    await _alertService.vibrate();

    if (mounted) {
      setState(() => _activeAlert = status);

      // Some com o card automaticamente após alguns segundos.
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _activeAlert?.plate == status.plate) {
          setState(() => _activeAlert = null);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      controller.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      controller.startImageStream(_onFrameAvailable);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Escaneando...')),
      body: !_isCameraReady || _cameraController == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_cameraController!),

                // Indicador discreto da última leitura bruta (útil para debug/calibração).
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _lastRawPlateSeen != null
                          ? 'Última placa lida: $_lastRawPlateSeen'
                          : 'Aponte a câmera para a placa do veículo',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ),

                // Card de alerta quando há correspondência na base local.
                if (_activeAlert != null)
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: AlertCard(
                      record: _activeAlert!,
                      onDismiss: () => setState(() => _activeAlert = null),
                    ),
                  ),
              ],
            ),
    );
  }
}
