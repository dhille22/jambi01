import 'package:location/location.dart' as loc;

class LocationPermissionException implements Exception {
  const LocationPermissionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationService {
  LocationService(this._location) {
    // Memaksa GPS untuk menggunakan tingkat akurasi paling tinggi
    _location.changeSettings(
      accuracy: loc.LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 0,
    );
  }

  final loc.Location _location;

  Future<loc.LocationData> getCurrentLocation() async {
    var enabled = await _location.serviceEnabled();
    if (!enabled) {
      enabled = await _location.requestService();
      if (!enabled) {
        throw const LocationPermissionException('Layanan lokasi belum aktif.');
      }
    }

    var permission = await _location.hasPermission();
    if (permission == loc.PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }

    if (permission == loc.PermissionStatus.denied ||
        permission == loc.PermissionStatus.deniedForever) {
      throw const LocationPermissionException(
        'Izin lokasi diperlukan untuk mengirim laporan.',
      );
    }

    return _location.getLocation();
  }

  Stream<loc.LocationData> watchLocation() => _location.onLocationChanged;
}
