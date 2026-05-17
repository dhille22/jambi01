import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart' as loc;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_options.dart';
import '../services/auth_service.dart';
import '../services/duplicate_validation_service.dart';
import '../services/report_service.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../services/image_classification_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService(ref.watch(supabaseClientProvider));
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(
    ref.watch(supabaseClientProvider),
    bucket: SupabaseOptions.reportImagesBucket,
  );
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(loc.Location());
});

final imageClassificationServiceProvider = Provider<ImageClassificationService>(
  (ref) {
    final service = ImageClassificationService();
    ref.onDispose(service.dispose);
    return service;
  },
);

final duplicateValidationServiceProvider = Provider<DuplicateValidationService>(
  (ref) {
    return DuplicateValidationService(ref.watch(reportServiceProvider));
  },
);
