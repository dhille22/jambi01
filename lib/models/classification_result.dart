class ClassificationResult {
  const ClassificationResult({
    required this.label,
    required this.confidence,
    required this.inferenceMs,
    this.modelName = 'MobileNetV3Large',
  });

  final String label;
  final double confidence;
  final int inferenceMs;
  final String modelName;

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'confidence': confidence,
      'inferenceMs': inferenceMs,
      'modelName': modelName,
    };
  }

  factory ClassificationResult.fromMap(Map<String, dynamic> map) {
    return ClassificationResult(
      label: map['label'] as String? ?? 'unknown',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      inferenceMs: (map['inferenceMs'] as num?)?.toInt() ?? 0,
      modelName: map['modelName'] as String? ?? 'MobileNetV3Large',
    );
  }
}
