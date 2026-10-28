import '../../../../engine/domain/road_type.dart';
import '../../../../engine/fogo_engine.dart';

/// Tipos de ícone da base 2D. Semáforo = dado real do modelo; os demais
/// são DISPOSITIVOS DEMO derivados deterministicamente do próprio modelo
/// (viatura perto de delegacia, radar em via arterial, câmera em
/// cruzamento) — posições sempre dentro da região carregada, para
/// qualquer `.osm` (do catálogo ou importado).
enum MapIconKind {
  signal,
  policeVehicle,
  fireVehicle,
  radar,
  camera;

  String get label => switch (this) {
    signal => 'Semáforo',
    policeVehicle => 'Viatura de Polícia',
    fireVehicle => 'Viatura de Bombeiro',
    radar => 'Radar',
    camera => 'Câmera de Segurança',
  };
}

/// Ícone posicionável na base 2D (projetado, em metros — mesma convenção
/// x leste / z sul da cena).
class MapIcon {
  const MapIcon({
    required this.id,
    required this.x,
    required this.z,
    required this.kind,
  });

  /// Id estável: de semáforo é o id da FEATURE (seleção real); de
  /// dispositivo demo é `device/<tipo>/<fonte>`.
  final String id;
  final double x;
  final double z;
  final MapIconKind kind;
}

/// Extrai os ícones do modelo carregado — puro, sem cena 3D. Roda UMA
/// vez por carga (junto aos rótulos), nunca por frame.
List<MapIcon> extractMapIcons(FogoEngine engine) {
  final icons = <MapIcon>[];
  final projector = engine.projector;
  final model = engine.model;

  // Semáforos: posições reais do modelo (id = feature → seleção real).
  for (final signal in model.signals) {
    final p = projector.project(signal.position);
    icons.add(MapIcon(id: signal.id, x: p.x, z: p.z, kind: MapIconKind.signal));
  }

  // Viaturas de polícia/bombeiro: NÃO são estáticas — a frota simulada
  // ([VehicleFleet]) fornece as posições por frame (Map2DView as junta
  // aos ícones). Delegacias continuam marcando o mapa como área.

  // Radar: via arterial (motorway/trunk/primary/secondary), amostrado
  // por hash estável do id — determinístico entre cargas.
  const radarClasses = {
    RoadType.motorway,
    RoadType.trunk,
    RoadType.primary,
    RoadType.secondary,
  };
  var radars = 0;
  for (final road in model.roads) {
    if (radars >= 30) break;
    if (!radarClasses.contains(road.type)) continue;
    if (road.points.length < 2) continue;
    if (_stableHash(road.id) % 4 != 0) continue;
    final a = projector.project(road.points[road.points.length ~/ 2 - 1]);
    final b = projector.project(road.points[road.points.length ~/ 2]);
    icons.add(
      MapIcon(
        id: 'device/radar/${road.id}',
        x: (a.x + b.x) / 2,
        z: (a.z + b.z) / 2,
        kind: MapIconKind.radar,
      ),
    );
    radars++;
  }

  // Câmera: cruzamentos amostrados (câmera de segurança de esquina).
  var cameras = 0;
  for (final crossing in model.crossings) {
    if (cameras >= 40) break;
    if (_stableHash(crossing.id) % 5 != 0) continue;
    final p = projector.project(crossing.position);
    icons.add(
      MapIcon(
        id: 'device/camera/${crossing.id}',
        x: p.x + 3,
        z: p.z + 3,
        kind: MapIconKind.camera,
      ),
    );
    cameras++;
  }

  return icons;
}

/// Hash determinístico (String.hashCode não é estável entre execuções).
int _stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h == 0 ? 1 : h;
}
