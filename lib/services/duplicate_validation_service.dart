import '../core/app_constants.dart';
import '../models/report_model.dart';
import '../utils/cosine_similarity.dart';
import '../utils/haversine.dart';
import 'report_service.dart';

class DuplicateReportException implements Exception {
  const DuplicateReportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DuplicateCheckResult {
  const DuplicateCheckResult({
    required this.isDuplicate,
    required this.spatialValid,
    required this.visualValid,
    required this.temporalValid,
    required this.nearestDistanceMeters,
    required this.bestSimilarity,
    this.matchedReportId,
  });

  final bool isDuplicate;
  final bool spatialValid;
  final bool visualValid;
  final bool temporalValid;
  final double nearestDistanceMeters;
  final double bestSimilarity;
  final String? matchedReportId;
}

class DuplicateDecisionEngine {
  const DuplicateDecisionEngine({
    this.distanceThresholdMeters = AppConstants.duplicateDistanceMeters,
    this.visualThreshold = AppConstants.duplicateCosineThreshold,
    this.temporalWindow = const Duration(
      hours: AppConstants.duplicateTemporalWindowHours,
    ),
  });

  final double distanceThresholdMeters;
  final double visualThreshold;
  final Duration temporalWindow;

  DuplicateCheckResult evaluate({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required List<double> embedding,
    required Iterable<ReportModel> candidates,
  }) {
    var spatialValid = false;
    var visualValid = false;
    var temporalValid = false;
    var nearestDistance = double.infinity;
    var bestSimilarity = 0.0;
    String? matchedReportId;

    for (final candidate in candidates) {
      final distance = Haversine.distanceInMeters(
        startLatitude: latitude,
        startLongitude: longitude,
        endLatitude: candidate.latitude,
        endLongitude: candidate.longitude,
      );
      final similarity = CosineSimilarity.calculate(
        embedding,
        candidate.embedding,
      );
      final age = timestamp.difference(candidate.createdAt).abs();

      final candidateSpatial = distance <= distanceThresholdMeters;
      final candidateVisual = similarity >= visualThreshold;
      final candidateTemporal = age <= temporalWindow;

      if (distance < nearestDistance) {
        nearestDistance = distance;
      }
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
      }

      if (candidateSpatial) {
        spatialValid = true;
      }
      if (candidateVisual) {
        visualValid = true;
      }
      if (candidateTemporal) {
        temporalValid = true;
      }

      if (candidateSpatial && candidateVisual && candidateTemporal) {
        matchedReportId = candidate.id;
        return DuplicateCheckResult(
          isDuplicate: true,
          spatialValid: true,
          visualValid: true,
          temporalValid: true,
          nearestDistanceMeters: distance,
          bestSimilarity: similarity,
          matchedReportId: matchedReportId,
        );
      }
    }

    return DuplicateCheckResult(
      isDuplicate: false,
      spatialValid: spatialValid,
      visualValid: visualValid,
      temporalValid: temporalValid,
      nearestDistanceMeters: nearestDistance.isFinite ? nearestDistance : 0,
      bestSimilarity: bestSimilarity,
      matchedReportId: matchedReportId,
    );
  }
}

class DuplicateValidationService {
  DuplicateValidationService(
    this._reportService, {
    DuplicateDecisionEngine engine = const DuplicateDecisionEngine(),
  }) : _engine = engine;

  final ReportService _reportService;
  final DuplicateDecisionEngine _engine;

  Future<DuplicateCheckResult> validate({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    required List<double> embedding,
  }) async {
    final candidates = await _reportService.fetchRecentReports(
      since: timestamp.subtract(_engine.temporalWindow),
    );

    return _engine.evaluate(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      embedding: embedding,
      candidates: candidates,
    );
  }
}
