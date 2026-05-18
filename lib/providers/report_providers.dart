import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart' as loc;
import 'package:uuid/uuid.dart';

import '../models/classification_result.dart';
import '../models/report_model.dart';
import '../services/auth_service.dart';
import '../services/duplicate_validation_service.dart';
import '../services/report_service.dart';
import '../services/image_classification_service.dart';
import '../services/storage_service.dart';
import '../utils/severity_utils.dart';
import 'auth_providers.dart';
import 'service_providers.dart';

final reportsStreamProvider = StreamProvider<List<ReportModel>>((ref) {
  ref.watch(authStateProvider); // Rebuild stream if auth state (like token) changes
  return ref.watch(reportServiceProvider).watchReports();
});

final userReportsStreamProvider = StreamProvider<List<ReportModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value(const <ReportModel>[]);
  }
  return ref.watch(reportServiceProvider).watchUserReports(user.id);
});

final currentLocationProvider = FutureProvider<loc.LocationData>((ref) {
  return ref.watch(locationServiceProvider).getCurrentLocation();
});

final reportSubmissionControllerProvider =
    StateNotifierProvider<ReportSubmissionController, AsyncValue<void>>((ref) {
      return ReportSubmissionController(
        authService: ref.watch(authServiceProvider),
        reportService: ref.watch(reportServiceProvider),
        storageService: ref.watch(storageServiceProvider),
        classificationService: ref.watch(imageClassificationServiceProvider),
        duplicateValidationService: ref.watch(
          duplicateValidationServiceProvider,
        ),
      );
    });

class ReportSubmissionController extends StateNotifier<AsyncValue<void>> {
  ReportSubmissionController({
    required AuthService authService,
    required ReportService reportService,
    required StorageService storageService,
    required ImageClassificationService classificationService,
    required DuplicateValidationService duplicateValidationService,
  }) : _authService = authService,
       _reportService = reportService,
       _storageService = storageService,
       _classificationService = classificationService,
       _duplicateValidationService = duplicateValidationService,
       super(const AsyncData(null));

  final AuthService _authService;
  final ReportService _reportService;
  final StorageService _storageService;
  final ImageClassificationService _classificationService;
  final DuplicateValidationService _duplicateValidationService;
  final _uuid = const Uuid();

  Future<ReportModel> submitReport({
    required File imageFile,
    required ClassificationResult classification,
    required loc.LocationData location,
    String? description,
  }) async {
    state = const AsyncLoading();
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw StateError('Sesi login tidak ditemukan.');
      }

      final latitude = location.latitude;
      final longitude = location.longitude;
      if (latitude == null || longitude == null) {
        throw StateError('Koordinat GPS belum tersedia.');
      }

      final metadata = await _classificationService.validateCapturedImage(
        imageFile,
      );
      if (!metadata.isValid) {
        throw StateError(metadata.messages.join('\n'));
      }

      final capturedAt = DateTime.now();
      final embedding = await _classificationService.extractEmbeddingFromFile(
        imageFile,
      );
      final duplicate = await _duplicateValidationService.validate(
        latitude: latitude,
        longitude: longitude,
        timestamp: capturedAt,
        embedding: embedding,
      );

      if (duplicate.isDuplicate) {
        throw const DuplicateReportException('Laporan sudah ada sebelumnya');
      }

      final reportId = _uuid.v4();
      final imageUrl = await _storageService.uploadReportImage(
        file: imageFile,
        userId: user.id,
        reportId: reportId,
        capturedAt: capturedAt,
      );

      final report = ReportModel(
        id: reportId,
        userId: user.id,
        category: classification.label,
        confidence: classification.confidence,
        latitude: latitude,
        longitude: longitude,
        imageUrl: imageUrl,
        createdAt: capturedAt,
        status: ReportStatus.pending,
        classification: classification,
        embedding: embedding,
        description: (description?.trim().isEmpty ?? true)
            ? null
            : description!.trim(),
        deviceTimestamp: capturedAt,
        severityPercentage: SeverityUtils.getSeverityPercentage(classification.confidence),
        severityLabel: SeverityUtils.getSeverityLabel(classification.confidence),
        priorityLevel: SeverityUtils.getPriorityLevel(classification.confidence),
      );

      await _reportService.createReport(report);
      state = const AsyncData(null);
      return report;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
