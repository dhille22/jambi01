# Firebase Setup

1. Buat Firebase project untuk aplikasi pengaduan fasilitas umum Kota Jambi.
2. Aktifkan Authentication dengan provider Email/Password.
3. Buat Cloud Firestore database.
4. Aktifkan Firebase Storage.
5. Jalankan FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<firebase-project-id>
```

6. Ganti `lib/firebase_options.dart` dengan file hasil FlutterFire.
7. Deploy rules:

```bash
firebase deploy --only firestore:rules,storage
```

8. Ganti `YOUR_GOOGLE_MAPS_API_KEY` di
`android/app/src/main/AndroidManifest.xml` dengan API key Google Maps Android.
