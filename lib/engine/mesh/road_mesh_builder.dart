import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../geometry/mesh_data.dart';

/// Superfície de via: ribbon ao longo da polilinha projetada, com junções
/// miter (clamp de ~70° p/ evitar spikes), largura coerente e sem
/// triângulos degenerados (segmentos nulos são removidos antes).
///
/// A superfície da via é separada das marcações e elementos visuais —
/// cada builder produz [MeshData]s independentes.
abstract final class RoadMeshBuilder {
  static final Vector3 _up = Vector3(0, 1, 0);

  /// `yLift` sobe a superfície (política de camadas verticais: layer·4 m,
  /// aplicada pelo chamador; pontes/túneis preservam o valor do domínio).
  static MeshData? build(
    List<Vector3> centerline,
    double widthMeters, {
    double yLift = 0,
  }) {
    final pts = _dedupe(centerline);
    if (pts.length < 2 || widthMeters <= 0) return null;
    final half = widthMeters / 2;

    final vertices = <Vector3>[];
    final tangents = <Vector3>[];

    for (var i = 0; i < pts.length; i++) {
      final prev = pts[i == 0 ? 0 : i - 1];
      final next = pts[i == pts.length - 1 ? i : i + 1];
      var tangent = next - prev;
      if (tangent.length2 < 1e-12) {
        tangent = Vector3(1, 0, 0);
      } else {
        tangent.normalize();
      }
      tangents.add(tangent);
    }

    // Offsets laterais com miter: média das normais dos segmentos vizinhos,
    // comprimento compensado por 1/cos(θ/2) com clamp.
    for (var i = 0; i < pts.length; i++) {
      final nPrev = _lateral(tangents[i == 0 ? 0 : i - 1]);
      final nNext = _lateral(tangents[i == pts.length - 1 ? i : i + 1]);
      var miter = nPrev + nNext;
      final len = miter.length;
      if (len < 1e-6) {
        miter = nPrev; // reversão 180°: usa a lateral anterior
      } else {
        miter.scale(1 / len);
      }
      final cosHalf = miter.dot(nNext).abs();
      final scale = 1 / math.max(cosHalf, 0.35); // clamp ~69.5°
      final offset = miter * (half * scale);
      final p = pts[i];
      vertices
        ..add(Vector3(p.x + offset.x, p.y + yLift, p.z + offset.z))
        ..add(Vector3(p.x - offset.x, p.y + yLift, p.z - offset.z));
    }

    final triangles = <int>[];
    for (var i = 0; i < pts.length - 1; i++) {
      final l0 = 2 * i, r0 = 2 * i + 1, l1 = 2 * i + 2, r1 = 2 * i + 3;
      // Winding: normal +Y (verificado em teste).
      triangles.addAll([l0, r0, l1, r0, r1, l1]);
    }

    return MeshData.fromVertices(vertices, triangles);
  }

  /// Normal lateral esquerda (cross(up, tangent)) no plano x/z.
  static Vector3 _lateral(Vector3 t) {
    final n = _up.cross(t)..y = 0;
    return n.length2 < 1e-12 ? Vector3(0, 0, 1) : n.normalized();
  }

  static List<Vector3> _dedupe(List<Vector3> pts) {
    final out = <Vector3>[];
    for (final p in pts) {
      if (p.x.isNaN || p.y.isNaN || p.z.isNaN) continue;
      if (out.isNotEmpty && (out.last - p).length2 < 1e-8) continue;
      out.add(p);
    }
    return out;
  }
}
