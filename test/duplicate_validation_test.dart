import 'package:jambi01/models/classification_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jambi01/models/report_model.dart';
import 'package:jambi01/services/duplicate_validation_service.dart';
import 'package:jambi01/utils/cosine_similarity.dart';
import 'package:jambi01/utils/haversine.dart';

void main() {
  test('Haversine calculates nearby points under 50 meters', () {
    final distance = Haversine.distanceInMeters(
      startLatitude: -1.6101,
      startLongitude: 103.6131,
      endLatitude: -1.6102,
      endLongitude: 103.6132,
    );

    expect(distance, lessThan(50));
  });

  test('Cosine similarity returns 1 for same vector', () {
    final score = CosineSimilarity.calculate([0.1, 0.2, 0.3], [0.1, 0.2, 0.3]);

    expect(score, closeTo(1, 0.0001));
  });

  test('Duplicate engine rejects spatial visual temporal duplicate', () {
    final now = DateTime(2026, 5, 13, 12);
    final candidate = _report(
      id: 'existing',
      latitude: -1.6101,
      longitude: 103.6131,
      createdAt: now.subtract(const Duration(hours: 1)),
      embedding: [0.5, 0.5, 0.5, 0.5],
    );

    final result = const DuplicateDecisionEngine().evaluate(
      latitude: -1.6102,
      longitude: 103.6132,
      timestamp: now,
      embedding: [0.5, 0.5, 0.5, 0.5],
      candidates: [candidate],
    );

    expect(result.isDuplicate, isTrue);
    expect(result.spatialValid, isTrue);
    expect(result.visualValid, isTrue);
    expect(result.temporalValid, isTrue);
    expect(result.matchedReportId, 'existing');
  });

  test('Duplicate engine accepts report when one layer fails', () {
    final now = DateTime(2026, 5, 13, 12);
    final candidate = _report(
      id: 'existing',
      latitude: -1.6101,
      longitude: 103.6131,
      createdAt: now.subtract(const Duration(days: 4)),
      embedding: [0.5, 0.5, 0.5, 0.5],
    );

    final result = const DuplicateDecisionEngine().evaluate(
      latitude: -1.6102,
      longitude: 103.6132,
      timestamp: now,
      embedding: [0.5, 0.5, 0.5, 0.5],
      candidates: [candidate],
    );

    expect(result.isDuplicate, isFalse);
    expect(result.spatialValid, isTrue);
    expect(result.visualValid, isTrue);
    expect(result.temporalValid, isFalse);
  });
}

ReportModel _report({
  required String id,
  required double latitude,
  required double longitude,
  required DateTime createdAt,
  required List<double> embedding,
}) {
  return ReportModel(
    id: id,
    userId: 'user-1',
    category: 'lubang_jalan',
    confidence: 0.9,
    latitude: latitude,
    longitude: longitude,
    imageUrl: 'https://example.com/report.jpg',
    createdAt: createdAt,
    status: ReportStatus.pending,
    classification: const ClassificationResult(
      label: 'lubang_jalan',
      confidence: 0.9,
      inferenceMs: 0,
    ),
    embedding: embedding,
  );
}
