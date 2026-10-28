import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../geometry/mesh_data.dart';
import 'box_builder.dart';
import 'building_mesh_builder.dart';
import 'slab_mesh_builder.dart';

/// Modelos 3D especializados por amenity do lote (ENG: posto, delegacia
/// — extensível: um método por tipo novo).
///
/// Todos recebem o anel do LOTE já projetado (x/z do polígono OSM) e
/// devolvem UMA malha vertex-colored (multiplicadores 0..1 sobre a
/// tinta da paleta do tipo — mesma técnica de sombreamento dos
/// edifícios). Layout interno sintético e determinístico pela bbox do
/// lote: estimado, não levantado (osm não descreve o arranjo interno).
abstract final class AmenityMeshBuilder {
  /// Topo do pátio (plano da plataforma do lote) e base (plano do
  /// parque — reuso da hierarquia de áreas).
  static const double _lotTop = 0.060;
  static const double _lotBottom = 0.010;

  /// Posto de gasolina: pátio (plataforma) + loja + copa aberta sobre
  /// as bombas + bombas. Copas elevadas + caixas pequenas leem como
  /// posto de qualquer ângulo.
  static MeshData? fuelStation(List<List<Vector3>> rings) {
    if (rings.isEmpty) return null;
    final outer = rings[0];
    if (outer.length < 3) return null;
    final platform = SlabMeshBuilder.build(
      rings,
      top: _lotTop,
      bottom: _lotBottom,
    );
    if (platform == null) return null;
    final layout = _layout(outer);
    return _merge([
      (platform, 0.5),
      _loja(layout),
      _copa(layout),
      _bomba(layout, -1),
      _bomba(layout, 1),
    ]);
  }

  /// Delegacia: volume institucional do lote — extrusão completa
  /// (paredes+teto+piso) com pé-direito menor que o genérico (6 m).
  /// Distinção por forma + tinta da paleta (azulada). Landmark não é
  /// rangeGated: o pad plano do tile não o substitui.
  static MeshData? police(List<List<Vector3>> rings) =>
      BuildingMeshBuilder.build(
        rings,
        heightMeters: 6,
        minHeightMeters: _lotTop,
      )?.volume;

  /// Hospital: extrusão institucional do lote (12 m) — volume sólido
  /// em vez de plataforma plana.
  static MeshData? hospital(List<List<Vector3>> rings) =>
      BuildingMeshBuilder.build(
        rings,
        heightMeters: 12,
        minHeightMeters: _lotTop,
      )?.volume;

  /// Templo: extrusão do lote (12 m) — mesma técnica da delegacia.
  static MeshData? placeOfWorship(List<List<Vector3>> rings) =>
      BuildingMeshBuilder.build(
        rings,
        heightMeters: 12,
        minHeightMeters: _lotTop,
      )?.volume;

  /// Estádio: plataforma do lote + anel de ARQUIBANCADAS elevado —
  /// tigela que segue o contorno real do anel externo OSM (anel
  /// interno = encolhimento determinístico da bbox). O campo interno
  /// é o pitch (área separada) que o engine eleva 4 mm acima da
  /// plataforma — arquibancada alta, gramado baixo.
  static MeshData? stadium(List<List<Vector3>> rings) {
    if (rings.isEmpty) return null;
    final outer = rings[0];
    if (outer.length < 3) return null;
    final platform = SlabMeshBuilder.build(
      rings,
      top: _lotTop,
      bottom: _lotBottom,
    );
    if (platform == null) return null;
    final stands = SlabMeshBuilder.build(
      [outer, _shrunkRing(outer)],
      top: _lotTop + 8,
      bottom: _lotTop,
    );
    return _merge([(platform, 0.5), if (stands != null) (stands, 0.85)]);
  }

  /// Anel interno da arquibancada: contorno encolhido para o CENTRO
  /// DA BBOX (determinístico; 72% preserva a forma do anel real).
  static List<Vector3> _shrunkRing(List<Vector3> ring) {
    var minX = ring[0].x, maxX = minX, minZ = ring[0].z, maxZ = minZ;
    for (final p in ring) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.z < minZ) minZ = p.z;
      if (p.z > maxZ) maxZ = p.z;
    }
    final cx = (minX + maxX) / 2;
    final cz = (minZ + maxZ) / 2;
    return [
      for (final p in ring)
        Vector3(cx + (p.x - cx) * 0.72, p.y, cz + (p.z - cz) * 0.72),
    ];
  }

  /// Eixo principal do lote pela bbox (determinístico, sem PCA).
  /// `u` segue a convenção do [buildBox]: heading 0 = leste.
  static ({Vector3 center, Vector3 u, Vector3 v, double halfL, double halfW})
  _layout(List<Vector3> ring) {
    var minX = ring[0].x, maxX = minX, minZ = ring[0].z, maxZ = minZ;
    for (final p in ring) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.z < minZ) minZ = p.z;
      if (p.z > maxZ) maxZ = p.z;
    }
    final dx = maxX - minX, dz = maxZ - minZ;
    final heading = dx >= dz ? 0.0 : math.pi / 2;
    return (
      center: Vector3((minX + maxX) / 2, _lotTop, (minZ + maxZ) / 2),
      u: Vector3(math.cos(heading), 0, -math.sin(heading)),
      v: Vector3(math.sin(heading), 0, math.cos(heading)),
      halfL: (dx >= dz ? dx : dz) / 2,
      halfW: (dx >= dz ? dz : dx) / 2,
    );
  }

  static (MeshData, double) _loja(
    ({Vector3 center, Vector3 u, Vector3 v, double halfL, double halfW}) l,
  ) {
    final at = l.center + l.u * (-l.halfL * 0.55);
    return (
      buildBox(
        Vector3(at.x, _lotTop + 2.0, at.z),
        Vector3(
          math.max(l.halfL * 0.28, 2.5),
          2.0,
          math.max(l.halfW * 0.55, 2.0),
        ),
        headingRadians: math.atan2(-l.u.z, l.u.x),
      ),
      0.75,
    );
  }

  static (MeshData, double) _copa(
    ({Vector3 center, Vector3 u, Vector3 v, double halfL, double halfW}) l,
  ) {
    final at = l.center + l.u * (l.halfL * 0.25);
    return (
      buildBox(
        Vector3(at.x, _lotTop + 4.8, at.z),
        Vector3(
          math.max(l.halfL * 0.4, 3.5),
          0.2,
          math.max(l.halfW * 0.8, 3.0),
        ),
        headingRadians: math.atan2(-l.u.z, l.u.x),
      ),
      0.9,
    );
  }

  static (MeshData, double) _bomba(
    ({Vector3 center, Vector3 u, Vector3 v, double halfL, double halfW}) l,
    int side,
  ) {
    final at =
        l.center + l.u * (l.halfL * 0.25) + l.v * (l.halfW * 0.18 * side);
    return (
      buildBox(
        Vector3(at.x, _lotTop + 0.7, at.z),
        Vector3(0.4, 0.7, 0.5),
        headingRadians: math.atan2(-l.u.z, l.u.x),
      ),
      1.0,
    );
  }

  /// Concatena malhas com multiplicador de cor por parte (vertex colors
  /// RGBA 0..1 — mesma convenção do [BuildingMeshBuilder]).
  static MeshData _merge(List<(MeshData, double)> parts) {
    final vertices = <Vector3>[];
    final normals = <Vector3>[];
    final triangles = <int>[];
    final colors = <double>[];
    for (final (part, shade) in parts) {
      final base = vertices.length;
      for (var i = 0; i < part.vertexCount; i++) {
        vertices.add(
          Vector3(
            part.positions[i * 3],
            part.positions[i * 3 + 1],
            part.positions[i * 3 + 2],
          ),
        );
        normals.add(
          Vector3(
            part.normals[i * 3],
            part.normals[i * 3 + 1],
            part.normals[i * 3 + 2],
          ),
        );
        colors
          ..add(shade)
          ..add(shade)
          ..add(shade)
          ..add(1.0);
      }
      for (final t in part.indices) {
        triangles.add(t + base);
      }
    }
    final packed = Float32List(colors.length);
    for (var i = 0; i < colors.length; i++) {
      packed[i] = colors[i];
    }
    return MeshData(
      positions: _pack3(vertices),
      normals: _pack3(normals),
      indices: Uint32List.fromList(triangles),
      colors: packed,
    );
  }

  static Float32List _pack3(List<Vector3> v) {
    final out = Float32List(v.length * 3);
    for (var i = 0; i < v.length; i++) {
      out[i * 3] = v[i].x;
      out[i * 3 + 1] = v[i].y;
      out[i * 3 + 2] = v[i].z;
    }
    return out;
  }
}
