import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_constants.dart';
import '../models/report_model.dart';
import 'report_providers.dart';

class ReportStatistics {
  const ReportStatistics({
    required this.total,
    required this.pending,
    required this.resolved,
    required this.byCategory,
    required this.bySeverity,
  });

  final int total;
  final int pending;
  final int resolved;
  final Map<String, int> byCategory;
  final Map<String, int> bySeverity;

  factory ReportStatistics.fromReports(List<ReportModel> reports) {
    final byCategory = {
      for (final category in AppConstants.damageClasses) category: 0,
    };
    final bySeverity = {
      'Kerusakan Ringan': 0,
      'Kerusakan Sedang': 0,
      'Kerusakan Berat': 0,
      'Kerusakan Sangat Parah': 0,
    };

    for (final report in reports) {
      byCategory[report.category] = (byCategory[report.category] ?? 0) + 1;
      
      if (bySeverity.containsKey(report.severityLabel)) {
        bySeverity[report.severityLabel] = (bySeverity[report.severityLabel] ?? 0) + 1;
      }
    }

    return ReportStatistics(
      total: reports.length,
      pending: reports
          .where((report) => report.status == ReportStatus.pending)
          .length,
      resolved: reports
          .where((report) => report.status == ReportStatus.resolved)
          .length,
      byCategory: byCategory,
      bySeverity: bySeverity,
    );
  }

  factory ReportStatistics.empty() {
    return ReportStatistics.fromReports(const []);
  }
}

final reportStatisticsProvider = Provider<AsyncValue<ReportStatistics>>((ref) {
  final reports = ref.watch(reportsStreamProvider);
  return reports.whenData(ReportStatistics.fromReports);
});
