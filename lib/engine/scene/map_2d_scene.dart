import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../domain/road_type.dart';

/// CENA 2D do motor — INDEPENDENTE do renderer 3D.
///
/// Primitivas leves (pontos projetados + cor), construídas UMA vez por
/// carga do modelo, sem mesh 3D, sem extrusão, sem flutter_scene: a
/// visão geral (modo mapa) desenha isto num único passe de canvas em
/// vez de milhares de draw calls da cena 3D. Geometria em METROS
/// projetados (mesma convenção da cena 3D: x leste, z sul).
class Map2DStroke {
  const Map2DStroke({
    required this.points,
    required this.widthMeters,
    required this.color,
    required this.type,
  });

  /// Polilinha aberta, x/z intercalados (`[x0, z0, x1, z1, ...]`).
  final Float32List points;

  /// Largura REAL da via (m) — escalada para px no render.
  final double widthMeters;
  final Vector3 color;
  final RoadType type;
}

/// Polígono preenchido (área/água/footprint de edifício — NUNCA volume).
class Map2DFill {
  const Map2DFill({
    required this.rings,
    required this.color,
    this.footprint = false,
  });

  /// `[0]` = contorno externo; demais = buracos (fillType even-odd).
  final List<Float32List> rings;
  final Vector3 color;

  /// Silhueta de edifício (pinta por cima das áreas no modo 2D).
  final bool footprint;
}

class Map2DScene {
  const Map2DScene({required this.strokes, required this.fills});

  final List<Map2DStroke> strokes;
  final List<Map2DFill> fills;
}
