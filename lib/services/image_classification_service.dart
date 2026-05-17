import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;

import '../core/app_constants.dart';
import '../core/secrets.dart';
import '../models/classification_result.dart';

class CaptureMetadataValidation {
  const CaptureMetadataValidation({
    required this.isValid,
    required this.messages,
  });

  final bool isValid;
  final List<String> messages;
}

class ImageClassificationService {
  GenerativeModel? _model;
  final List<String> _labels = AppConstants.damageClasses;
  var _initialized = false;
  var _dummyFrameIndex = 0;

  bool get isInitialized => _initialized;
  bool get hasModel => _model != null;

  void dispose() {
    _initialized = false;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    // Mengambil API Key dari file secrets.dart yang diabaikan oleh Git
    const apiKey = AppSecrets.geminiApiKey;
    
    if (apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(
            properties: {
              'label': Schema.enumString(enumValues: _labels),
              'confidence': Schema.number(format: 'float'),
            },
            requiredProperties: ['label', 'confidence'],
          ),
        ),
      );
    }

    _initialized = true;
  }

  Future<ClassificationResult> classifyFile(File file) async {
    await initialize();

    final stopwatch = Stopwatch()..start();
    final bytes = await file.readAsBytes();

    if (_model == null) {
      return _dummyClassification(stopwatch.elapsedMilliseconds);
    }

    try {
      final prompt = TextPart(
        'Tugas Anda adalah mengklasifikasikan kerusakan fasilitas umum ke dalam SALAH SATU dari kategori berikut: ${_labels.join(", ")}. '
        'PENTING: Jika gambar yang diberikan TIDAK MENUNJUKKAN kerusakan fasilitas umum sama sekali (misalnya: hanya foto wajah orang, hewan, ruangan dalam rumah, atau objek yang tidak relevan), Anda WAJIB mengembalikan label "TIDAK_VALID". '
        'Output hanya boleh berupa objek JSON valid tanpa markdown, dengan kunci "label" (string) dan "confidence" (angka 0.0 sampai 1.0).'
      );
      // Asumsi foto dari kamera adalah jpeg/jpg
      final imagePart = DataPart('image/jpeg', bytes);

      final response = await _model!.generateContent([
        Content.multi([prompt, imagePart])
      ]);
      stopwatch.stop();

      var textResponse = response.text ?? '{}';
      
      // Bersihkan jika gemini membalas dengan format markdown ```json ... ```
      textResponse = textResponse.replaceAll('```json', '').replaceAll('```', '').trim();

      final jsonMap = jsonDecode(textResponse) as Map<String, dynamic>;
      final label = jsonMap['label'] as String? ?? _labels.first;
      final confidence = (jsonMap['confidence'] as num?)?.toDouble() ?? 0.0;

      return ClassificationResult(
        label: label,
        confidence: confidence,
        inferenceMs: stopwatch.elapsedMilliseconds,
        modelName: 'gemini-flash-latest',
      );
    } catch (e) {
      stopwatch.stop();
      // Mengembalikan pesan error langsung ke layar HP agar kita tahu masalahnya
      return ClassificationResult(
        label: 'ERROR: ${e.toString().split('\n').first}',
        confidence: 0.0,
        inferenceMs: stopwatch.elapsedMilliseconds,
        modelName: 'gemini-error',
      );
    }
  }

  Future<ClassificationResult?> classifyCameraImage(CameraImage image) async {
    await initialize();

    // Untuk camera preview yang realtime, kita abaikan saja pemanggilan Gemini
    // agar kuota API tidak langsung habis dalam sedetik. Biarkan dummy berjalan
    // ringan untuk sekadar UX di layar.
    _dummyFrameIndex++;
    if (_dummyFrameIndex % 8 != 0) {
      return null;
    }

    return _dummyClassification(16);
  }

  Future<List<double>> extractEmbeddingFromFile(File file) async {
    // Fungsi ini tidak diganti karena hanya melakukan perhitungan histogram warna dasar
    // untuk mengecek duplikat (cosine similarity), tidak memakai model AI berat.
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return const [];
    }

    final resized = img.copyResize(decoded, width: 64, height: 64);
    final histogram = List<double>.filled(40, 0);

    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        final r = (pixel.r / 32).floor().clamp(0, 7);
        final g = (pixel.g / 32).floor().clamp(0, 7);
        final b = (pixel.b / 32).floor().clamp(0, 7);
        final gray = ((pixel.r + pixel.g + pixel.b) / 3 / 16).floor().clamp(
          0,
          15,
        );

        histogram[r] += 1;
        histogram[8 + g] += 1;
        histogram[16 + b] += 1;
        histogram[24 + gray] += 1;
      }
    }

    final norm = math.sqrt(
      histogram.fold<double>(0, (sum, value) => sum + value * value),
    );
    if (norm == 0) {
      return histogram;
    }

    return histogram.map((value) => value / norm).toList(growable: false);
  }

  Future<CaptureMetadataValidation> validateCapturedImage(File file) async {
    final messages = <String>[];
    final exists = await file.exists();
    if (!exists) {
      return const CaptureMetadataValidation(
        isValid: false,
        messages: ['File foto tidak ditemukan.'],
      );
    }

    final stat = await file.stat();
    if (stat.size <= 0) {
      messages.add('File foto kosong.');
    }

    final capturedDelta = DateTime.now().difference(stat.modified).abs();
    if (capturedDelta > const Duration(minutes: 10)) {
      messages.add(
        'Metadata waktu foto tidak sesuai dengan sesi kamera aktif.',
      );
    }

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      messages.add('Format foto tidak dapat dibaca.');
    } else if (decoded.width < 320 || decoded.height < 320) {
      messages.add('Resolusi foto terlalu rendah untuk klasifikasi visual.');
    }

    return CaptureMetadataValidation(
      isValid: messages.isEmpty,
      messages: messages,
    );
  }

  ClassificationResult _dummyClassification(int inferenceMs) {
    final index = DateTime.now().second % _labels.length;
    return ClassificationResult(
      label: _labels[index],
      confidence: 0.74,
      inferenceMs: inferenceMs,
      modelName: 'MobileNetV3Large-dummy',
    );
  }
}
