# Jambi Crowd Report

Aplikasi mobile crowdsourcing pengaduan kerusakan fasilitas umum Kota Jambi.

Judul penelitian yang lebih sesuai untuk versi classifier:

> Perancangan Aplikasi Pengaduan Kerusakan Fasilitas Umum Kota Jambi Berbasis Crowdsourcing Menggunakan Pre-trained Model Deep Learning untuk Klasifikasi Citra

## Keputusan Arsitektur AI

Project ini sudah diganti dari YOLO object detection menjadi **image classification**.

Model yang dipakai:

- MobileNetV3Large
- Transfer learning dari ImageNet
- Export ke TFLite
- On-device inference di Flutter

Alasan:

- Tidak membutuhkan anotasi bounding box.
- Dataset lebih mudah dibuat: cukup folder gambar per kelas.
- Lebih ringan dan realistis untuk mobile.
- Cocok jika foto laporan wajib fokus pada satu kerusakan utama.

## Fitur Utama

- Authentication: login, register, logout, session persistence Supabase Auth.
- Dashboard peta: OpenStreetMap, marker kerusakan, current location, heatmap sederhana, statistik realtime.
- Laporan: kamera langsung, GPS otomatis, timestamp otomatis, validasi metadata, tanpa upload galeri.
- AI classification: label kerusakan, confidence score, latency, dummy inference saat model belum tersedia.
- Riwayat laporan: list, detail, status laporan.
- Statistik: jumlah laporan per kategori dari Supabase Realtime.
- Duplicate detection:
  - Layer 1: Haversine <= 50 meter.
  - Layer 2: cosine similarity embedding >= 0.85.
  - Layer 3: temporal window 24 jam.

## Struktur Flutter

```text
lib/
  core/
  models/
  services/
  providers/
  views/
  widgets/
  routes/
  utils/
```

## Setup Flutter

```bash
flutter pub get
flutter run
```

Jika ada lebih dari satu device:

```bash
flutter run -d chrome
flutter run -d <android-device-id>
```

## Setup Supabase

1. Buat project Supabase.
2. Aktifkan Email/Password di Authentication.
3. Jalankan SQL di `supabase/schema.sql` melalui SQL Editor Supabase.
4. Project URL sudah diset ke `https://grsaehmfmelxxtqeloqk.supabase.co` di `lib/supabase_options.dart`.
5. Anon key Supabase sudah diset di `lib/supabase_options.dart`, jadi aplikasi bisa langsung dijalankan:

```powershell
flutter run
```

Bucket storage default bernama `report-images`. Jika memakai nama lain:

```powershell
flutter run `
  --dart-define=SUPABASE_REPORT_IMAGES_BUCKET=<bucket-name>
```

Jika ingin override URL project, pakai URL dasar Supabase, bukan endpoint REST:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://grsaehmfmelxxtqeloqk.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<anon-public-key>
```

## Setup Peta

Peta memakai OpenStreetMap melalui `flutter_map`, sehingga tidak membutuhkan Google Maps API key.

## Dataset Classification

Dataset sekarang menggunakan struktur folder per kelas:

```text
dataset_classifier/
  train/
    lubang_jalan/
    drainase_rusak/
    penerangan_rusak/
    trotoar_rusak/
    sampah_menumpuk/
  valid/
    lubang_jalan/
    drainase_rusak/
    penerangan_rusak/
    trotoar_rusak/
    sampah_menumpuk/
  test/
    lubang_jalan/
    drainase_rusak/
    penerangan_rusak/
    trotoar_rusak/
    sampah_menumpuk/
```

Tidak perlu file label YOLO `.txt`.

## Training AI

Install dependency Python:

```bash
pip install -r requirements.txt
```

Training:

```bash
python train.py
```

Evaluasi:

```bash
python evaluate.py
```

Inference gambar:

```bash
python inference.py --source path/to/image.jpg
```

Webcam:

```bash
python webcam_detection.py
```

Export TFLite:

```bash
python export_tflite.py --float16
```

Model TFLite output:

```text
assets/models/facility_classifier.tflite
```

## Testing

```bash
flutter analyze
flutter test
python -m py_compile train.py evaluate.py inference.py webcam_detection.py export_tflite.py preprocess.py embedding_extraction.py
```

## Catatan Implementasi

File `lib/services/image_classification_service.dart` berisi fallback dummy inference agar UI, Supabase, GPS, kamera, dan duplicate validation tetap bisa dikembangkan sebelum model final tersedia.

Lokasi fine-tuning ada di `train.py`. Sesuaikan dataset, epoch, batch size, image size, learning rate, dan augmentation untuk eksperimen skripsi.
