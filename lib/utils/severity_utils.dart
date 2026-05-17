import 'package:flutter/material.dart';
import '../models/severity_level.dart';

class SeverityUtils {
  /// Mengkonversi confidence (0.0 - 1.0) menjadi persentase (0 - 100)
  static int getSeverityPercentage(double confidence) {
    return (confidence * 100).round().clamp(0, 100);
  }

  /// Mengambil data tingkat keparahan berdasarkan confidence
  static SeverityLevel getSeverityLevel(double confidence) {
    final percentage = getSeverityPercentage(confidence);

    if (percentage < 20) {
      return SeverityLevel(
        percentage: percentage,
        label: 'Sangat Baik',
        priority: 'Rendah',
        color: Colors.green.shade800, // hijau tua
      );
    } else if (percentage < 40) {
      return SeverityLevel(
        percentage: percentage,
        label: 'Kerusakan Ringan',
        priority: 'Rendah',
        color: Colors.lightGreen, // hijau muda
      );
    } else if (percentage < 60) {
      return SeverityLevel(
        percentage: percentage,
        label: 'Kerusakan Sedang',
        priority: 'Sedang',
        color: Colors.yellow.shade700, // kuning
      );
    } else if (percentage < 80) {
      return SeverityLevel(
        percentage: percentage,
        label: 'Kerusakan Berat',
        priority: 'Tinggi',
        color: Colors.orange, // oranye
      );
    } else {
      return SeverityLevel(
        percentage: percentage,
        label: 'Kerusakan Sangat Parah',
        priority: 'Darurat',
        color: Colors.red, // merah
      );
    }
  }

  /// Helper tunggal untuk mempermudah akses ke label
  static String getSeverityLabel(double confidence) => getSeverityLevel(confidence).label;

  /// Helper tunggal untuk mempermudah akses ke priority
  static String getPriorityLevel(double confidence) => getSeverityLevel(confidence).priority;

  /// Helper tunggal untuk mempermudah akses ke warna
  static Color getSeverityColor(double confidence) => getSeverityLevel(confidence).color;
}
