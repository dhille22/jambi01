import 'package:flutter/material.dart';

class SeverityLevel {
  final int percentage;
  final String label;
  final String priority;
  final Color color;

  const SeverityLevel({
    required this.percentage,
    required this.label,
    required this.priority,
    required this.color,
  });
}
