import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/report_model.dart';
import '../providers/report_providers.dart';
import '../utils/date_formatter.dart';
import '../utils/severity_utils.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/report_card.dart';
import '../widgets/report_status_chip.dart';

class ReportHistoryPage extends ConsumerWidget {
  const ReportHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(userReportsStreamProvider);

    return reports.when(
      loading: () => const LoadingView(message: 'Memuat riwayat...'),
      error: (error, _) => ErrorView(message: 'Gagal memuat riwayat: $error'),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Belum ada laporan.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final report = items[index];
            return ReportCard(
              report: report,
              onTap: () => _showDetail(context, report),
            );
          },
        );
      },
    );
  }

  void _showDetail(BuildContext context, ReportModel report) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ReportDetailSheet(report: report),
    );
  }
}

class _ReportDetailSheet extends StatelessWidget {
  const _ReportDetailSheet({required this.report});

  final ReportModel report;

  @override
  Widget build(BuildContext context) {
    final severityColor = SeverityUtils.getSeverityColor(report.confidence);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  report.imageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              report.category.replaceAll('_', ' '),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ReportStatusChip(status: report.status),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    report.priorityLevel,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: severityColor,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailRow(
              icon: Icons.schedule,
              label: DateFormatter.compact(report.createdAt),
            ),
            _DetailRow(
              icon: Icons.place_outlined,
              label:
                  '${report.latitude.toStringAsFixed(6)}, ${report.longitude.toStringAsFixed(6)}',
            ),
            _DetailRow(
              icon: Icons.warning_amber_rounded,
              label: 'Tingkat Keparahan: ${report.severityLabel} (${report.severityPercentage}%)',
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: report.severityPercentage / 100,
              color: severityColor,
              backgroundColor: severityColor.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            if (report.description != null) ...[
              const SizedBox(height: 12),
              Text(report.description!),
            ],
            const SizedBox(height: 24),
            Text(
              'Lokasi Kerusakan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(report.latitude, report.longitude),
                    initialZoom: 16,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'id.go.jambikota.crowdreport',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(report.latitude, report.longitude),
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.location_on,
                            color: severityColor,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
