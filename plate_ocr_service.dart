import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/services.dart';

import '../utils/plate_utils.dart';

/// Encapsula o ML Kit Text Recognizer e a lógica de conversão do frame
/// bruto da câmera (`CameraImage`) para o formato exigido pelo ML Kit
/// (`InputImage`), além da extração de placas via RegEx sobre o texto
/// reconhecido.
class PlateOcrService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Processa um frame da câmera e retorna o conjunto de placas válidas
  /// encontradas (já higienizadas). Retorna conjunto vazio se nada for
  /// reconhecido.
  Future<Set<String>> processFrame({
    required CameraImage image,
    required CameraDescription cameraDescription,
    required int sensorOrientation,
  }) async {
    final inputImage = _inputImageFromCameraImage(
      image,
      cameraDescription,
      sensorOrientation,
    );

    if (inputImage == null) return {};

    final RecognizedText recognizedText = await _recognizer.processImage(inputImage);
    return PlateUtils.extractPlates(recognizedText.text);
  }

  Future<void> dispose() async {
    await _recognizer.close();
  }

  /// Converte um `CameraImage` (formato YUV420/NV21 no Android) para o
  /// `InputImage` esperado pelo google_mlkit_text_recognition.
  ///
  /// Referência oficial de conversão recomendada pelo pacote
  /// google_mlkit_commons para o plugin `camera` em modo `startImageStream`.
  InputImage? _inputImageFromCameraImage(
    CameraImage image,
    CameraDescription camera,
    int sensorOrientation,
  ) {
    // Rotação: necessário mapear a orientação do sensor para o enum do ML Kit.
    final rotation = _rotationIntToImageRotation(sensorOrientation);
    if (rotation == null) return null;

    // Formato de imagem: no Android o plugin `camera` entrega YUV420 em
    // múltiplos planos; concatenamos os bytes de todos os planos.
    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    // O ML Kit no Android aceita nv21. Caso o formato não seja reconhecido
    // diretamente, convertê-lo explicitamente evita frames corrompidos.
    if (Platform.isAndroid) {
      final nv21Bytes = _yuv420ToNv21(image);
      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      );
      return InputImage.fromBytes(bytes: nv21Bytes, metadata: inputImageData);
    }

    // iOS entrega BGRA8888 em um único plano — usado sem conversão.
    if (format == null ||
        (format != InputImageFormat.bgra8888 && Platform.isIOS)) {
      return null;
    }

    final plane = image.planes.first;
    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: plane.bytes, metadata: inputImageData);
  }

  InputImageRotation? _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return null;
    }
  }

  /// Converte os planos YUV420 (Y, U, V separados, com possível padding/
  /// stride diferente de `width`) para o layout NV21 (Y plano + VU
  /// intercalado) exigido pelo ML Kit no Android.
  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    // --- Plano Y ---
    int outputIndex = 0;
    for (int row = 0; row < height; row++) {
      final int rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(
        outputIndex,
        outputIndex + width,
        yPlane.bytes.sublist(rowStart, rowStart + width),
      );
      outputIndex += width;
    }

    // --- Planos U/V intercalados como VU (NV21) ---
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    int uvIndex = ySize;
    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final int uIndex = row * uvRowStride + col * uvPixelStride;
        final int vIndex = row * uvRowStride + col * uvPixelStride;

        nv21[uvIndex++] = vPlane.bytes[vIndex];
        nv21[uvIndex++] = uPlane.bytes[uIndex];
      }
    }

    return nv21;
  }
}
