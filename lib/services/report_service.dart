import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report_model.dart';

class ReportService {
  ReportService(this._client);

  final SupabaseClient _client;
  static const _table = 'reports';

  Stream<List<ReportModel>> watchReports() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(_mapRows);
  }

  Stream<List<ReportModel>> watchUserReports(String userId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map(_mapRows);
  }

  Future<List<ReportModel>> fetchRecentReports({
    required DateTime since,
    int limit = 250,
  }) async {
    final rows = await _client
        .from(_table)
        .select()
        .gte('created_at', since.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);

    return _mapRows(rows);
  }

  Future<void> createReport(ReportModel report) async {
    await _client.from(_table).insert(report.toMap());
  }

  Future<void> updateStatus({
    required String reportId,
    required ReportStatus status,
  }) async {
    await _client
        .from(_table)
        .update({'status': status.name})
        .eq('id', reportId);
  }

  List<ReportModel> _mapRows(List<Map<String, dynamic>> rows) {
    return rows
        .map((row) => ReportModel.fromMap(row['id'] as String, row))
        .toList();
  }
}
