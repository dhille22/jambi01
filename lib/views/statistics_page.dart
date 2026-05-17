import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/statistics_providers.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/stat_card.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statistics = ref.watch(reportStatisticsProvider);

    return statistics.when(
      loading: () => const LoadingView(message: 'Menghitung statistik...'),
      error: (error, _) => ErrorView(message: 'Gagal memuat statistik: $error'),
      data: (value) {
        final maxCount = value.byCategory.values.fold<int>(
          1,
          (max, item) => item > max ? item : max,
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total laporan',
                    value: value.total.toString(),
                    icon: Icons.assignment,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    label: 'Selesai',
                    value: value.resolved.toString(),
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Jumlah Laporan per Kategori',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...value.byCategory.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CategoryBar(
                  label: entry.key.replaceAll('_', ' '),
                  value: entry.value,
                  fraction: entry.value / maxCount,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Jumlah Laporan per Tingkat Keparahan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...value.bySeverity.entries.map(
              (entry) {
                Color severityColor;
                switch (entry.key) {
                  case 'Sangat Baik':
                    severityColor = Colors.green.shade800;
                  case 'Kerusakan Ringan':
                    severityColor = Colors.lightGreen;
                  case 'Kerusakan Sedang':
                    severityColor = Colors.yellow.shade700;
                  case 'Kerusakan Berat':
                    severityColor = Colors.orange;
                  case 'Kerusakan Sangat Parah':
                    severityColor = Colors.red;
                  default:
                    severityColor = Theme.of(context).colorScheme.primary;
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CategoryBar(
                    label: entry.key,
                    value: entry.value,
                    fraction: entry.value / maxCount,
                    barColor: severityColor,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.label,
    required this.value,
    required this.fraction,
    this.barColor,
  });

  final String label;
  final int value;
  final double fraction;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final color = barColor ?? Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(value.toString()),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 12,
            value: fraction.clamp(0, 1),
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}
