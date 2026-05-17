import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart' as loc;

import '../models/classification_result.dart';
import '../providers/report_providers.dart';
import '../providers/service_providers.dart';
import '../services/duplicate_validation_service.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/primary_button.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  CameraController? _cameraController;
  File? _capturedFile;
  loc.LocationData? _location;
  ClassificationResult? _classification;
  final _descriptionController = TextEditingController();
  var _isInitializing = true;
  var _isProcessingCapture = false;
  var _isRunningLiveInference = false;
  String? _cameraError;
  DateTime _lastLiveInference = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(reportSubmissionControllerProvider);

    if (_isInitializing) {
      return const LoadingView(message: 'Menyiapkan kamera...');
    }

    if (_cameraError != null) {
      return ErrorView(
        message: _cameraError!,
        onRetry: () {
          setState(() {
            _cameraError = null;
            _isInitializing = true;
          });
          unawaited(_initializeCamera());
        },
      );
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _capturedFile == null ? _cameraPreview() : _photoPreview(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              _ClassificationSummary(classification: _classification),
              const SizedBox(height: 10),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan tambahan',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessingCapture || submitState.isLoading
                          ? null
                          : _capturedFile == null
                          ? null
                          : _retake,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Ambil Ulang'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _capturedFile == null
                        ? PrimaryButton(
                            label: 'Ambil Foto',
                            icon: Icons.camera_alt,
                            isLoading: _isProcessingCapture,
                            onPressed: _capturePhoto,
                          )
                        : PrimaryButton(
                            label: 'Kirim Laporan',
                            icon: Icons.cloud_upload_outlined,
                            isLoading: submitState.isLoading,
                            onPressed: _submitReport,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cameraPreview() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const LoadingView(message: 'Membuka kamera...');
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        if (_classification != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _ClassificationBadge(classification: _classification!),
          ),
      ],
    );
  }

  Widget _photoPreview() {
    final file = _capturedFile;
    if (file == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(file, width: double.infinity, fit: BoxFit.cover),
        if (_classification != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _ClassificationBadge(classification: _classification!),
          ),
      ],
    );
  }

  Future<void> _initializeCamera() async {
    try {
      await ref.read(imageClassificationServiceProvider).initialize();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Kamera tidak tersedia di perangkat ini.');
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      setState(() => _isInitializing = false);
      await _startLiveInference();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraError = error.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _startLiveInference() async {
    final controller = _cameraController;
    if (controller == null || controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream((image) {
      final now = DateTime.now();
      if (_capturedFile != null ||
          _isRunningLiveInference ||
          now.difference(_lastLiveInference) <
              const Duration(milliseconds: 900)) {
        return;
      }

      _lastLiveInference = now;
      _isRunningLiveInference = true;
      ref
          .read(imageClassificationServiceProvider)
          .classifyCameraImage(image)
          .then((classification) {
            if (!mounted || classification == null || _capturedFile != null) {
              return;
            }
            setState(() => _classification = classification);
          })
          .whenComplete(() => _isRunningLiveInference = false);
    });
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    setState(() => _isProcessingCapture = true);
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      final image = await controller.takePicture();
      final file = File(image.path);
      final classification = await ref
          .read(imageClassificationServiceProvider)
          .classifyFile(file);
      final location = await ref
          .read(locationServiceProvider)
          .getCurrentLocation();

      if (!mounted) {
        return;
      }

      setState(() {
        _capturedFile = file;
        _classification = classification;
        _location = location;
      });
    } catch (error) {
      _showSnackBar(error.toString());
      unawaited(_startLiveInference());
    } finally {
      if (mounted) {
        setState(() => _isProcessingCapture = false);
      }
    }
  }

  Future<void> _submitReport() async {
    final imageFile = _capturedFile;
    final location = _location;
    if (imageFile == null || location == null) {
      _showSnackBar('Foto dan GPS wajib tersedia.');
      return;
    }
    if (_classification == null) {
      _showSnackBar('Klasifikasi kerusakan belum tersedia.');
      return;
    }
    
    if (_classification!.label == 'TIDAK_VALID') {
      _showSnackBar('Foto ditolak! Objek ini tidak terdeteksi sebagai kerusakan fasilitas umum.');
      return;
    }

    try {
      await ref
          .read(reportSubmissionControllerProvider.notifier)
          .submitReport(
            imageFile: imageFile,
            classification: _classification!,
            location: location,
            description: _descriptionController.text,
          );
      _showSnackBar('Laporan berhasil dikirim.');
      await _retake();
    } on DuplicateReportException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar(error.toString());
    }
  }

  Future<void> _retake() async {
    setState(() {
      _capturedFile = null;
      _location = null;
      _classification = null;
      _descriptionController.clear();
    });
    await _startLiveInference();
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    if (controller == null) {
      return;
    }
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ClassificationSummary extends StatelessWidget {
  const _ClassificationSummary({required this.classification});

  final ClassificationResult? classification;

  @override
  Widget build(BuildContext context) {
    if (classification == null) {
      return const Row(
        children: [
          Icon(Icons.search_off),
          SizedBox(width: 8),
          Expanded(child: Text('Belum ada klasifikasi kerusakan.')),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.memory),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${classification!.label.replaceAll('_', ' ')} - '
            '${(classification!.confidence * 100).toStringAsFixed(1)}% '
            '(${classification!.inferenceMs} ms)',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ClassificationBadge extends StatelessWidget {
  const _ClassificationBadge({required this.classification});

  final ClassificationResult classification;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${classification.label.replaceAll('_', ' ')} '
                '${(classification.confidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
