import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  StorageService(this._client, {required String bucket}) : _bucket = bucket;

  final SupabaseClient _client;
  final String _bucket;

  Future<String> uploadReportImage({
    required File file,
    required String userId,
    required String reportId,
    required DateTime capturedAt,
  }) async {
    final path = '$userId/$reportId.jpg';
    final metadata = FileOptions(
      contentType: 'image/jpeg',
      upsert: true,
      metadata: {
        'reportId': reportId,
        'userId': userId,
        'capturedAt': capturedAt.toIso8601String(),
        'source': 'camera_live_capture',
      },
    );

    await _client.storage
        .from(_bucket)
        .upload(path, file, fileOptions: metadata);
    return _client.storage.from(_bucket).getPublicUrl(path);
  }
}
