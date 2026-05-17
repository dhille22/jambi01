class AppConstants {
  const AppConstants._();

  static const appName = 'Jambi Public Facility Watch';
  static const researchTitle =
      'Perancangan Aplikasi Pengaduan Kerusakan Fasilitas Umum Kota Jambi '
      'Berbasis Crowdsourcing Menggunakan Pre-trained Model Deep Learning';

  static const jambiLatitude = -1.6101;
  static const jambiLongitude = 103.6131;

  static const duplicateDistanceMeters = 50.0;
  static const duplicateCosineThreshold = 0.85;
  static const duplicateTemporalWindowHours = 24;

  static const labelsAssetPath = 'assets/labels/labels.txt';

  // Place the fine-tuned image classifier TFLite export here after training.
  static const classifierTfliteAssetPath =
      'assets/models/facility_classifier.tflite';

  static const damageClasses = <String>[
    'lubang_jalan',
    'drainase_rusak',
    'penerangan_rusak',
    'trotoar_rusak',
    'sampah_menumpuk',
  ];
}
