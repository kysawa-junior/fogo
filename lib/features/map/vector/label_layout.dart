import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Layout de rótulos por frame: **detecção de colisão AABB** + **dedup por
/// distância** (mesma via/rótulo só reaparece após X pixels) — spec §2.
class LabelLayout {
  LabelLayout({this.sameLabelDistance = 350});

  /// Distância mínima (px) entre dois rótulos de MESMA chave (nome).
  final double sameLabelDistance;

  final List<Rect> _boxes = [];
  final Map<String, List<Offset>> _anchorsByKey = {};

  int placed = 0;
  int hidden = 0;

  /// Tenta reservar espaço para um rótulo.
  ///
  /// [key] identifica a via/rótulo (nome da rua) para dedup por distância;
  /// [anchor] é o ponto de referência no mundo-tela do rótulo;
  /// [aabb] é a caixa delimitadora (já expandida pela rotação).
  bool tryPlace({
    required String key,
    required Offset anchor,
    required Rect aabb,
  }) {
    final List<Offset> anchors = _anchorsByKey[key] ?? const [];
    for (final Offset other in anchors) {
      if ((other - anchor).distance < sameLabelDistance) {
        hidden++;
        return false;
      }
    }
    // margem de respiro entre rótulos distintos (2px)
    final Rect padded = aabb.inflate(2);
    for (final Rect box in _boxes) {
      if (box.overlaps(padded)) {
        hidden++;
        return false;
      }
    }
    _boxes.add(aabb);
    _anchorsByKey.putIfAbsent(key, () => []).add(anchor);
    placed++;
    return true;
  }

  /// AABB de um texto rotacionado por [angle] (rad), ancorado em [center],
  /// com dimensões [width]×[height] (conservador — cobre a diagonal).
  static Rect rotatedAabb(
    Offset center,
    double width,
    double height,
    double angle,
  ) {
    final double c = math.cos(angle).abs();
    final double s = math.sin(angle).abs();
    final double w = width * c + height * s;
    final double h = width * s + height * c;
    return Rect.fromCenter(center: center, width: w, height: h);
  }
}
