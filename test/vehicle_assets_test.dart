import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Assets dos modelos glTF das viaturas presentes no bundle. Regressão
/// direta do bug real: entradas de diretório no pubspec NÃO descem
/// subpastas — cada pasta de modelo precisa da própria linha.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('assets/vehicles declarados no manifest do bundle', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();
    const expected = [
      'assets/vehicles/bmw_police_car/scene.gltf',
      'assets/vehicles/bmw_police_car/scene.bin',
      'assets/vehicles/bmw_police_car/textures/Body_baseColor.png',
      'assets/vehicles/bmw_police_car/textures/Wheel_baseColor.png',
      'assets/vehicles/fire_truck/scene.gltf',
      'assets/vehicles/fire_truck/scene.bin',
    ];
    for (final key in expected) {
      expect(assets, contains(key), reason: 'asset ausente: $key');
    }
  });
}
