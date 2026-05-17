import 'classification_result.dart';

enum ReportStatus {
  pending('Menunggu'),
  verified('Terverifikasi'),
  inProgress('Diproses'),
  resolved('Selesai'),
  rejected('Ditolak');

  const ReportStatus(this.label);

  final String label;

  static ReportStatus fromValue(String? value) {
    return ReportStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ReportStatus.pending,
    );
  }
}

class ReportModel {
  const ReportModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.confidence,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.createdAt,
    required this.status,
    required this.classification,
    required this.embedding,
    this.description,
    this.deviceTimestamp,
    this.severityPercentage = 0,
    this.severityLabel = 'Sangat Baik',
    this.priorityLevel = 'Rendah',
  });

  final String id;
  final String userId;
  final String category;
  final double confidence;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final DateTime createdAt;
  final ReportStatus status;
  final ClassificationResult classification;
  final List<double> embedding;
  final String? description;
  final DateTime? deviceTimestamp;
  final int severityPercentage;
  final String severityLabel;
  final String priorityLevel;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'category': category,
      'confidence': confidence,
      'latitude': latitude,
      'longitude': longitude,
      'image_url': imageUrl,
      'created_at': createdAt.toUtc().toIso8601String(),
      'status': status.name,
      'classification': classification.toMap(),
      'embedding': embedding,
      'description': description,
      'device_timestamp': deviceTimestamp?.toUtc().toIso8601String(),
      'severity_percentage': severityPercentage,
      'severity_label': severityLabel,
      'priority_level': priorityLevel,
    };
  }

  factory ReportModel.fromMap(String id, Map<String, dynamic> map) {
    final rawClassification = map['classification'];
    final rawEmbedding = map['embedding'] as List? ?? const [];

    return ReportModel(
      id: id,
      userId: _readString(map, 'user_id', 'userId'),
      category: map['category'] as String? ?? 'unknown',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      imageUrl: _readString(map, 'image_url', 'imageUrl'),
      createdAt:
          _readDate(map['created_at'] ?? map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: ReportStatus.fromValue(map['status'] as String?),
      classification: _readClassification(rawClassification, map),
      embedding: rawEmbedding
          .map((value) => (value as num).toDouble())
          .toList(),
      description: map['description'] as String?,
      deviceTimestamp: _readDate(
        map['device_timestamp'] ?? map['deviceTimestamp'],
      ),
      severityPercentage: (map['severity_percentage'] as num?)?.toInt() ?? 0,
      severityLabel: map['severity_label'] as String? ?? 'Sangat Baik',
      priorityLevel: map['priority_level'] as String? ?? 'Rendah',
    );
  }

  ReportModel copyWith({
    String? id,
    String? userId,
    String? category,
    double? confidence,
    double? latitude,
    double? longitude,
    String? imageUrl,
    DateTime? createdAt,
    ReportStatus? status,
    ClassificationResult? classification,
    List<double>? embedding,
    String? description,
    DateTime? deviceTimestamp,
    int? severityPercentage,
    String? severityLabel,
    String? priorityLevel,
  }) {
    return ReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      classification: classification ?? this.classification,
      embedding: embedding ?? this.embedding,
      description: description ?? this.description,
      deviceTimestamp: deviceTimestamp ?? this.deviceTimestamp,
      severityPercentage: severityPercentage ?? this.severityPercentage,
      severityLabel: severityLabel ?? this.severityLabel,
      priorityLevel: priorityLevel ?? this.priorityLevel,
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String _readString(
    Map<String, dynamic> map,
    String primaryKey,
    String fallbackKey,
  ) {
    return map[primaryKey] as String? ?? map[fallbackKey] as String? ?? '';
  }

  static ClassificationResult _readClassification(
    Object? value,
    Map<String, dynamic> map,
  ) {
    if (value is Map) {
      return ClassificationResult.fromMap(Map<String, dynamic>.from(value));
    }

    // Backward compatibility for reports created by the earlier YOLO prototype.
    final rawDetections = map['detections'] as List? ?? const [];
    if (rawDetections.isNotEmpty && rawDetections.first is Map) {
      final first = Map<String, dynamic>.from(rawDetections.first as Map);
      return ClassificationResult.fromMap(first);
    }

    return ClassificationResult(
      label: map['category'] as String? ?? 'unknown',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      inferenceMs: 0,
    );
  }
}
