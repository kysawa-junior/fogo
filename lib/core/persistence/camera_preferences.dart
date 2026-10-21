import 'package:shared_preferences/shared_preferences.dart';

/// Persistência da câmera (posição/zoom) entre sessões.
class CameraPreferences {
  const CameraPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const String _lat = 'fogo.camera.lat';
  static const String _lng = 'fogo.camera.lng';
  static const String _zoom = 'fogo.camera.zoom';

  ({double lat, double lng, double zoom})? load() {
    final double? lat = _prefs.getDouble(_lat);
    final double? lng = _prefs.getDouble(_lng);
    final double? zoom = _prefs.getDouble(_zoom);
    if (lat == null || lng == null || zoom == null) return null;
    return (lat: lat, lng: lng, zoom: zoom);
  }

  Future<void> save(double lat, double lng, double zoom) async {
    await _prefs.setDouble(_lat, lat);
    await _prefs.setDouble(_lng, lng);
    await _prefs.setDouble(_zoom, zoom);
  }
}
