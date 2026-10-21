import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'camera_preferences.dart';

/// Instância inicializada em main() antes do runApp.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider deve ser sobrescrito em main()',
  ),
);

final cameraPreferencesProvider = Provider<CameraPreferences>(
  (ref) => CameraPreferences(ref.watch(sharedPreferencesProvider)),
);
