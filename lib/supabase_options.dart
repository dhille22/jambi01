class SupabaseOptions {
  const SupabaseOptions._();

  static const defaultProjectUrl = 'https://grsaehmfmelxxtqeloqk.supabase.co';
  static const _rawUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: defaultProjectUrl,
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdyc2FlaG1mbWVseHh0cWVsb3FrIiwi'
        'cm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3NTI1OTgsImV4cCI6MjA5NDMyODU5OH0.'
        'c5MkBdvo1zRhWZFYBD539JMRlElnWYzv0uiDVxqHqGg',
  );
  static const reportImagesBucket = String.fromEnvironment(
    'SUPABASE_REPORT_IMAGES_BUCKET',
    defaultValue: 'report-images',
  );

  static String get url => _normalizeProjectUrl(_rawUrl);

  static void validate() {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Supabase belum lengkap dikonfigurasi. Project URL sudah diset ke '
        '$defaultProjectUrl. Jalankan aplikasi dengan '
        '--dart-define=SUPABASE_ANON_KEY=<anon-public-key>.',
      );
    }
  }

  static String _normalizeProjectUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    const restSuffix = '/rest/v1';
    if (normalized.endsWith(restSuffix)) {
      normalized = normalized.substring(
        0,
        normalized.length - restSuffix.length,
      );
    }

    return normalized;
  }
}
