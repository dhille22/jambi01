import 'package:flutter/material.dart';

import '../models/report_model.dart';

class ReportStatusChip extends StatelessWidget {
  const ReportStatusChip({super.key, required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      ReportStatus.pending => (Colors.orange, Icons.schedule),
      ReportStatus.verified => (Colors.blue, Icons.verified_outlined),
      ReportStatus.inProgress => (Colors.indigo, Icons.engineering),
      ReportStatus.resolved => (Colors.green, Icons.check_circle_outline),
      ReportStatus.rejected => (Colors.red, Icons.cancel_outlined),
    };

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(status.label),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
    );
  }
}
