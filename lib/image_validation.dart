import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageValidationResult {
  final bool isValid;
  final String? format;
  final String? extension;
  final String? error;

  ImageValidationResult({
    required this.isValid,
    this.format,
    this.extension,
    this.error,
  });
}

/// Validación para archivos en móvil (File)
Future<ImageValidationResult> isValidImageFile(File file) async {
  try {
    if (!(await file.exists())) {
      return ImageValidationResult(isValid: false, error: 'El archivo no existe');
    }

    final bytes = await file.readAsBytes();
    return _validateImageBytes(bytes);
  } catch (e) {
    return ImageValidationResult(isValid: false, error: 'Error al leer el archivo: $e');
  }
}

/// Validación para web (Uint8List)
Future<ImageValidationResult> isValidImageBytes(Uint8List bytes) async {
  return _validateImageBytes(bytes);
}

/// Lógica compartida para validar bytes de imagen
ImageValidationResult _validateImageBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    return ImageValidationResult(isValid: false, error: 'La imagen está vacía');
  }

  final image = img.decodeImage(bytes);
  if (image == null) {
    return ImageValidationResult(isValid: false, error: 'Formato no soportado o imagen corrupta');
  }

  // Intentar detectar el formato a partir de los primeros bytes
  final header = bytes.take(12).toList();
  String? format;
  String? extension;

  if (header.length >= 3 &&
      header[0] == 0xFF &&
      header[1] == 0xD8 &&
      header[2] == 0xFF) {
    format = 'jpeg';
    extension = 'jpg';
  } else if (header.length >= 8 &&
      header[0] == 0x89 &&
      header[1] == 0x50 &&
      header[2] == 0x4E &&
      header[3] == 0x47) {
    format = 'png';
    extension = 'png';
  } else if (!kIsWeb && header.length >= 4 &&
      header[0] == 0x00 &&
      header[1] == 0x00 &&
      header[2] == 0x00 &&
      (header[3] == 0x18 || header[3] == 0x1C)) {
    format = 'heic';
    extension = 'heic';
  } else {
    format = 'jpeg';
    extension = 'jpg';
  }

  return ImageValidationResult(
    isValid: true,
    format: format,
    extension: extension,
  );
}
