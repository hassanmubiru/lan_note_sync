// lib/services/ocr/ocr_service.dart
//
// OCR Service — Extract text from images using Google ML Kit Text Recognition
//
// Usage:
//   final text = await OcrService.extractTextFromFile(imagePath: '/path/to/image.jpg');

import 'dart:convert' show base64Decode;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final _textRecognizer = TextRecognizer(script: ScriptType.latin);

  /// Extract text from an image file
  static Future<String> extractTextFromFile({required String imagePath}) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      final extractedText = _formatRecognizedText(recognizedText);
      debugPrint('[OCR] Extracted ${extractedText.length} chars from image');
      
      await inputImage.close();
      return extractedText;
    } catch (e) {
      debugPrint('[OCR] Error: $e');
      rethrow;
    }
  }

  /// Extract text from a File object
  static Future<String> extractTextFromFileObject({required File imageFile}) async {
    return extractTextFromFile(imagePath: imageFile.path);
  }

  /// Extract text from base64 encoded image data
  static Future<String> extractTextFromBase64({required String base64Data}) async {
    try {
      // Decode base64 to bytes
      final bytes = base64Decode(base64Data);
      
      // Create temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      
      try {
        final text = await extractTextFromFile(imagePath: tempFile.path);
        return text;
      } finally {
        // Clean up temp file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      debugPrint('[OCR] Base64 error: $e');
      rethrow;
    }
  }

  /// Format recognized text blocks into readable markdown
  static String _formatRecognizedText(RecognizedText recognizedText) {
    final blocks = recognizedText.blocks;
    
    if (blocks.isEmpty) {
      return '# Whiteboard Content\n\nNo text detected. This may be a diagram or image.';
    }

    final buffer = StringBuffer('# Whiteboard Content\n\n');
    
    for (final block in blocks) {
      // Group lines into paragraphs
      for (final line in block.lines) {
        buffer.writeln(line.text);
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  /// Dispose resources
  static Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
