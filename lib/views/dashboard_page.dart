import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_constants.dart';
import '../models/report_model.dart';
import '../providers/report_providers.dart';
import '../providers/statistics_providers.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/stat_card.dart';
import '../utils/severity_utils.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsStreamProvider);
    final location = ref.watch(currentLocationProvider);
    final statistics = ref.watch(reportStatisticsProvider);

    return reports.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(message: 'Gagal memuat peta: $error'),
      data: (items) {
        final current = location.asData?.value;
        final hasCurrentLocation =
            current?.latitude != null && current?.longitude != null;
        final currentTarget = !hasCurrentLocation
            ? const LatLng(
                AppConstants.jambiLatitude,
                AppConstants.jambiLongitude,
              )
            : LatLng(current!.latitude!, current.longitude!);

        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: currentTarget,
                initialZoom: 13.2,
                minZoom: 11,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'id.go.jambikota.crowdreport',
                  maxNativeZoom: 19,
                ),
                CircleLayer(circles: _heatmapCircles(items)),
                MarkerLayer(
                  markers: [
                    if (hasCurrentLocation)
                      Marker(
                        point: currentTarget,
                        width: 34,
                        height: 34,
                        child: const _CurrentLocationMarker(),
                      ),
                    ..._markers(context, items),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                  showFlutterMapAttribution: false,
                ),
              ],
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: statistics.when(
                data: (value) => Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Total laporan',
                        value: value.total.toString(),
                        icon: Icons.assignment_outlined,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatCard(
                        label: 'Menunggu',
                        value: value.pending.toString(),
                        icon: Icons.schedule,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Marker> _markers(BuildContext context, List<ReportModel> reports) {
    return reports.map((report) {
      return Marker(
        point: LatLng(report.latitude, report.longitude),
        width: 44,
        height: 44,
        child: _ReportMapMarker(
          report: report,
          color: SeverityUtils.getSeverityColor(report.confidence),
          onTap: () => _showReportSummary(context, report),
        ),
      );
    }).toList();
  }

  List<CircleMarker> _heatmapCircles(List<ReportModel> reports) {
    return reports.map((report) {
      final color = SeverityUtils.getSeverityColor(report.confidence);
      return CircleMarker(
        point: LatLng(report.latitude, report.longitude),
        radius: 70,
        useRadiusInMeter: true,
        borderStrokeWidth: 1,
        borderColor: color.withValues(alpha: 0.32),
        color: color.withValues(alpha: 0.13),
      );
    }).toList();
  }

  void _showReportSummary(BuildContext context, ReportModel report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final color = SeverityUtils.getSeverityColor(report.confidence);
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      report.category.replaceAll('_', ' ').toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      report.priorityLevel,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: color,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Status: ${report.status.label}'),
              const SizedBox(height: 4),
              Text('Keparahan: ${report.severityLabel} (${report.severityPercentage}%)'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: report.severityPercentage / 100,
                color: color,
                backgroundColor: color.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _ReportMapMarker extends StatelessWidget {
  const _ReportMapMarker({
    required this.report,
    required this.color,
    required this.onTap,
  });

  final ReportModel report;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          '${report.category.replaceAll('_', ' ')} - ${report.status.label}',
      child: GestureDetector(
        onTap: onTap,
        child: Icon(Icons.location_on, color: color, size: 40),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const SizedBox(width: 16, height: 16),
        ),
      ),
    );
  }
}
