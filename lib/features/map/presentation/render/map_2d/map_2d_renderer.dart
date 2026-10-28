import 'dart:math' as math;
import 'dart:typed_data';

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../../../../engine/domain/road_type.dart';
import '../../../../../engine/scene/map_scene.dart';
import '../../../../../engine/scene/map_2d_scene.dart';
import '../label_candidates.dart';
import '../map_icons.dart';
import '../scene_overlay.dart';

/// Célula do heatmap de risco, já em coordenadas de MUNDO (x/z metros
/// do projector) com a cor do nível — o renderer só pinta.
class HeatCell {
  const HeatCell({
    required this.rect,
    required this.color,
    required this.areaId,
  });

  /// Retângulo no plano x/z do mundo (minX, minZ, maxX, maxZ).
  final ui.Rect rect;
  final ui.Color color;
  final String areaId;
}

/// Cor do heatmap por score (0..100): verde → amarelo → laranja →
/// vermelho, com alpha fixo (legibilidade sobre a base 2D).
ui.Color heatColor(int score) {
  const stops = [0, 50, 75, 100];
  const colors = [
    ui.Color(0x6634D399), // verde
    ui.Color(0x80FACC15), // amarelo
    ui.Color(0x99FB923C), // laranja
    ui.Color(0xB3EF4444), // vermelho
  ];
  final s = score.clamp(0, 100).toDouble();
  for (var i = 0; i < stops.length - 1; i++) {
    if (s <= stops[i + 1]) {
      final t = (s - stops[i]) / (stops[i + 1] - stops[i]);
      return ui.Color.lerp(colors[i], colors[i + 1], t)!;
    }
  }
  return colors.last;
}

/// Renderizador do MODO 2D: converte [Map2DScene] em `ui.Path` UMA vez
/// e desenha por frame com a transform top-down da câmera — um único
/// passe de canvas, culling por AABB. NÃO usa flutter_scene nem mesh
/// 3D: é o segundo motor de render, independente do primeiro.
class Map2DRenderer {
  Map2DRenderer(Map2DScene scene) {
    // Áreas primeiro, footprints de edifício por cima (ordem de
    // leitura do mapa escuro).
    for (final fill in scene.fills.where((f) => !f.footprint)) {
      _addFill(fill);
    }
    for (final fill in scene.fills.where((f) => f.footprint)) {
      _addFill(fill);
    }
    // Vias: classe menor primeiro — vias maiores pintam por cima nas
    // interseções (equivalente 2D do depthLayer da cena 3D).
    final strokes = [...scene.strokes]
      ..sort((a, b) => _classRank(a.type).compareTo(_classRank(b.type)));
    for (final stroke in strokes) {
      final paint = ui.Paint()
        ..color = _color(stroke.color)
        ..style = ui.PaintingStyle.stroke
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round;
      _strokes.add((
        path: _polyline(stroke.points),
        paint: paint,
        bbox: _bbox(stroke.points),
        widthMeters: stroke.widthMeters,
        type: stroke.type,
      ));
    }
  }

  final List<({ui.Path path, ui.Paint paint, ui.Rect bbox})> _fills = [];
  final List<
    ({
      ui.Path path,
      ui.Paint paint,
      ui.Rect bbox,
      double widthMeters,
      RoadType type,
    })
  >
  _strokes = [];

  /// Escala px/metro que CASA com a projeção da cena 3D: o viewport usa
  /// o `PerspectiveCamera` default do flutter_scene — FOV vertical 45°
  /// (fovRadiansY default). 2D e 3D na MESMA escala = o mesmo mapa em
  /// duas dimensões; qualquer fator aqui vira "salto" na transição.
  static double pxPerMeter(double viewHeightPx, double distanceMeters) =>
      distanceMeters <= 0
      ? 0
      : viewHeightPx / (2 * math.tan(math.pi / 8) * distanceMeters);

  /// Visibilidade dos ícones (0..1): somem ANTES do véu do overlay —
  /// os semáforos 3D surgem no LOD 2 (1200 m), então a banda do fade
  /// termina em 1000 (overlay opaco) e começa em 1200. Além disso,
  /// some na visão geral (poluição visual em tela inteira).
  static double iconAlpha(double distanceMeters) {
    if (distanceMeters >= 12000) return 0;
    final fadeNear3D =
        1 - SceneOverlayOpacity.smoothstep((1200 - distanceMeters) / 200);
    return (1 - SceneOverlayOpacity.compute(distanceMeters)) * fadeNear3D;
  }

  /// Mundo→tela — MESMA base do transform de [paint] (rotate(az + π/2),
  /// scale(s,-s)). Exposto para o hit-test de toque do Map2DView bater
  /// com o que foi pintado. Retorna null fora da view.
  static ui.Offset? iconScreenPoint({
    required double worldX,
    required double worldZ,
    required double targetX,
    required double targetZ,
    required double azimuth,
    required double s,
    required double viewWidth,
    required double viewHeight,
  }) {
    if (s <= 0) return null;
    final theta = azimuth + math.pi / 2;
    final cosT = math.cos(theta), sinT = math.sin(theta);
    final vx = (worldX - targetX) * s;
    final vy = -(worldZ - targetZ) * s;
    final px = viewWidth / 2 + vx * cosT - vy * sinT;
    final py = viewHeight / 2 + vx * sinT + vy * cosT;
    const margin = 300.0;
    if (px < -margin || py < -margin) return null;
    if (px > viewWidth + margin || py > viewHeight + margin) return null;
    return ui.Offset(px, py);
  }

  /// Ordem de pintura das vias (menor primeiro).
  static int _classRank(RoadType t) => switch (t) {
    RoadType.footway ||
    RoadType.path ||
    RoadType.cycleway ||
    RoadType.track => 0,
    RoadType.service || RoadType.pedestrian => 1,
    RoadType.residential || RoadType.unclassified || RoadType.livingStreet => 2,
    RoadType.tertiary => 3,
    RoadType.secondary => 4,
    RoadType.primary => 5,
    RoadType.motorway || RoadType.trunk => 6,
    RoadType.rail => 7,
    RoadType.other => 1,
  };

  /// Largura mínima em px por classe — aOverview afastada (0.04 px/m)
  /// faria vias de 5 m medirem 0.2 px: invisível. Piso em px, largura
  /// real em metros vence quando o zoom é próximo.
  static double _minPx(RoadType t) => switch (t) {
    RoadType.motorway || RoadType.trunk => 2.2,
    RoadType.primary => 1.6,
    RoadType.secondary => 1.2,
    RoadType.tertiary => 1.0,
    RoadType.residential ||
    RoadType.unclassified ||
    RoadType.livingStreet ||
    RoadType.pedestrian ||
    RoadType.service ||
    RoadType.rail => 0.8,
    _ => 0.5,
  };

  /// Desenha um frame. Transform (derivada da câmera orbital no
  /// zênite): mundo→tela com rotação de azimute — mesma base do 3D.
  void paint(
    ui.Canvas canvas, {
    required double targetX,
    required double targetZ,
    required double azimuth,
    required double pxPerMeter,
    required double viewWidth,
    required double viewHeight,
    required double distanceMeters,
    required List<LabelCandidate> labels,
    List<MapIcon> icons = const [],
    double iconAlphaScale = 1.0,
    List<HeatCell> heat = const [],
  }) {
    final s = pxPerMeter;
    if (s <= 0) return;
    // Meio-diagonal visível em metros: culling conservativo cobre a
    // rotação do azimute (AABB circunscrito).
    final radius =
        math.sqrt(viewWidth * viewWidth + viewHeight * viewHeight) / 2 / s;
    final minX = targetX - radius, maxX = targetX + radius;
    final minZ = targetZ - radius, maxZ = targetZ + radius;
    bool culled(ui.Rect bbox) =>
        bbox.right < minX ||
        bbox.left > maxX ||
        bbox.bottom < minZ ||
        bbox.top > maxZ;

    canvas.save();
    canvas.translate(viewWidth / 2, viewHeight / 2);
    // Base do 3D: screen-up = forward no plano = -(cosA, sinA). Rotação
    // do painter precisa CASAR com o lookAt da cena (right = up ×
    // forward) — sem o +π, o 2D sai INVERTIDO 180° do 3D.
    canvas.rotate(azimuth + math.pi / 2);
    canvas.scale(s, -s);
    canvas.translate(-targetX, -targetZ);
    for (final f in _fills) {
      if (culled(f.bbox)) continue;
      canvas.drawPath(f.path, f.paint);
    }
    for (final st in _strokes) {
      if (culled(st.bbox)) continue;
      st.paint.strokeWidth = math.max(st.widthMeters, _minPx(st.type) / s);
      canvas.drawPath(st.path, st.paint);
    }
    // Heatmap de risco SOBRE a base (antes de rótulos/ícones): células
    // já em coordenadas de MUNDO (x/z do projector) — a transform acima
    // cuida da rotação/escala. Sem blur na v1: fill alpha por nível.
    for (final cell in heat) {
      if (culled(cell.rect)) continue;
      final paint = ui.Paint()..color = cell.color;
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          cell.rect.deflate(1.5),
          const ui.Radius.circular(6),
        ),
        paint,
      );
    }
    canvas.restore();
    // Rótulos por ÚLTIMO, em espaço de tela: texto deitado SOBRE a via
    // (mesma linguagem dos decals de nome de via da cena 3D — sem chip).
    _paintLabels(
      canvas,
      labels: labels,
      distanceMeters: distanceMeters,
      targetX: targetX,
      targetZ: targetZ,
      s: s,
      azimuth: azimuth,
      viewWidth: viewWidth,
      viewHeight: viewHeight,
    );
    if (icons.isNotEmpty && iconAlphaScale > 0) {
      _paintIcons(
        canvas,
        icons: icons,
        alphaScale: iconAlphaScale,
        distanceMeters: distanceMeters,
        targetX: targetX,
        targetZ: targetZ,
        s: s,
        azimuth: azimuth,
        viewWidth: viewWidth,
        viewHeight: viewHeight,
      );
    }
  }

  final Map<
    String,
    ({TextPainter fill, TextPainter outline, double width, double height})
  >
  _glyphs = {};

  /// Texto já rasterizado (fill + contorno), cacheado por (texto, tamanho).
  /// Mesma linguagem visual dos decals 3D ([FogoPalette.crossing] com
  /// contorno [FogoPalette.ground], w600, relação de stroke 5/64).
  ({TextPainter fill, TextPainter outline, double width, double height})?
  _glyph(String text, double fontSize) {
    final key = '$text|${fontSize.round()}';
    final cached = _glyphs[key];
    if (cached != null) return cached;
    final fill = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _color(FogoPalette.crossing),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    final outline = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          foreground: ui.Paint()
            ..color = _color(FogoPalette.ground)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = fontSize * 5 / 64
            ..strokeJoin = ui.StrokeJoin.round,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    fill.layout();
    outline.layout();
    final glyph = (
      fill: fill,
      outline: outline,
      width: math.max(fill.width, outline.width),
      height: math.max(fill.height, outline.height),
    );
    _glyphs[key] = glyph;
    return glyph;
  }

  /// Ícones por ÚLTIMO (topo): halo escuro + disco de cor do tipo +
  /// glifo branco — mesma linguagem para os quatro tipos. Alpha já vem
  /// da banda de zoom ([iconAlpha] × opacidade do overlay).
  void _paintIcons(
    ui.Canvas canvas, {
    required List<MapIcon> icons,
    required double alphaScale,
    required double distanceMeters,
    required double targetX,
    required double targetZ,
    required double s,
    required double azimuth,
    required double viewWidth,
    required double viewHeight,
  }) {
    final globalAlpha = iconAlpha(distanceMeters) * alphaScale;
    if (globalAlpha <= 0) return;
    double fade(double a) => (a * globalAlpha).clamp(0.0, 1.0);
    for (final icon in icons) {
      final p = iconScreenPoint(
        worldX: icon.x,
        worldZ: icon.z,
        targetX: targetX,
        targetZ: targetZ,
        azimuth: azimuth,
        s: s,
        viewWidth: viewWidth,
        viewHeight: viewHeight,
      );
      if (p == null) continue;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      // Halo: chip escuro com borda — legível sobre via clara ou área.
      canvas.drawCircle(
        ui.Offset.zero,
        10,
        ui.Paint()
          ..color = const ui.Color(0xE6121824).withValues(alpha: fade(0.9)),
      );
      canvas.drawCircle(
        ui.Offset.zero,
        10,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const ui.Color(0xFF33425C).withValues(alpha: fade(1)),
      );
      canvas.drawCircle(
        ui.Offset.zero,
        7,
        ui.Paint()..color = iconKindColor(icon.kind).withValues(alpha: fade(1)),
      );
      _paintGlyph(canvas, icon.kind, globalAlpha);
      canvas.restore();
    }
  }

  static ui.Color iconKindColor(MapIconKind kind) => switch (kind) {
    // Verde de semáforo; azul de viatura policial; vermelho de bombeiro;
    // âmbar de radar; ciano de câmera.
    MapIconKind.signal => const ui.Color(0xFF34D399),
    MapIconKind.policeVehicle => const ui.Color(0xFF60A5FA),
    MapIconKind.fireVehicle => const ui.Color(0xFFEF4444),
    MapIconKind.radar => const ui.Color(0xFFFBBF24),
    MapIconKind.camera => const ui.Color(0xFF22D3EE),
  };

  /// Glifo escuro dentro do disco de cor (7 px de raio).
  void _paintGlyph(ui.Canvas canvas, MapIconKind kind, double alpha) {
    ui.Paint paintFor(ui.Color c) =>
        ui.Paint()..color = c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));
    final dark = paintFor(const ui.Color(0xFF0B0B14)); // sobre disco claro
    switch (kind) {
      case MapIconKind.signal:
        // 3 pontos verticais do semáforo.
        for (final dy in [-3.5, 0.0, 3.5]) {
          canvas.drawCircle(ui.Offset(0, dy), 1.5, dark);
        }
      case MapIconKind.policeVehicle:
      case MapIconKind.fireVehicle:
        // Carroceria: retângulo arredondado + cabine (o disco de cor
        // distingue polícia/bombeiro).
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromCenter(center: ui.Offset(0, 0.5), width: 9, height: 5),
            const ui.Radius.circular(1.5),
          ),
          dark,
        );
        canvas.drawCircle(ui.Offset(-3, 3.2), 1.2, dark);
        canvas.drawCircle(ui.Offset(3, 3.2), 1.2, dark);
      case MapIconKind.radar:
        // Radar: arcos concêntricos (feixe) + ponto emissor.
        final arc = ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = dark.color;
        canvas.drawArc(
          ui.Rect.fromCenter(center: ui.Offset(-1, 0), width: 9, height: 9),
          -math.pi / 3,
          math.pi / 1.5,
          false,
          arc,
        );
        canvas.drawArc(
          ui.Rect.fromCenter(center: ui.Offset(-1, 0), width: 5, height: 5),
          -math.pi / 3,
          math.pi / 1.5,
          false,
          arc,
        );
        canvas.drawCircle(ui.Offset(-1.5, 0), 1.2, dark);
      case MapIconKind.camera:
        // Corpo de câmera + lente.
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromCenter(center: ui.Offset(0, 0), width: 9, height: 6),
            const ui.Radius.circular(1.5),
          ),
          dark,
        );
        // Lente: disco na cor do tipo dentro do corpo escuro.
        canvas.drawCircle(
          ui.Offset(0.5, 0),
          1.6,
          paintFor(iconKindColor(kind)),
        );
    }
  }

  void _paintLabels(
    ui.Canvas canvas, {
    required List<LabelCandidate> labels,
    required double distanceMeters,
    required double targetX,
    required double targetZ,
    required double s,
    required double azimuth,
    required double viewWidth,
    required double viewHeight,
  }) {
    if (labels.isEmpty) return;
    // MESMA base do transform do paint acima (azimuth + π/2): posição e
    // ângulo dos rótulos em espaço de tela idêntico ao das vias.
    final theta = azimuth + math.pi / 2;
    final cosT = math.cos(theta), sinT = math.sin(theta);
    final radiusPx =
        math.sqrt(viewWidth * viewWidth + viewHeight * viewHeight) / 2 + 300;
    // Prioridade menor primeiro (vence colisão) — igual ao overlay antigo.
    final ordered = [...labels]
      ..sort((a, b) => a.priority.compareTo(b.priority));
    final placed = <ui.Rect>[];
    var drawn = 0;
    for (final label in ordered) {
      if (drawn >= 30) break; // limite de poluição (igual ao overlay antigo)
      if (distanceMeters > label.maxDistanceMeters) continue;
      final vx = (label.worldPoint.x - targetX) * s;
      final vy = -(label.worldPoint.z - targetZ) * s;
      final px = viewWidth / 2 + vx * cosT - vy * sinT;
      final py = viewHeight / 2 + vx * sinT + vy * cosT;
      if ((px - viewWidth / 2).abs() > radiusPx ||
          (py - viewHeight / 2).abs() > radiusPx) {
        continue;
      }
      // Tamanho acompanha o zoom (pisos/cbram nos extremos): de longe
      // legível, de perto cresce como os decals de mundo do 3D.
      final fontSize = (12.0 * s).clamp(11.0, 22.0).toDouble();
      final glyph = _glyph(label.text, fontSize);
      if (glyph == null) continue;
      // Ângulo do texto: tangente da via projetada na tela; normalizado
      // para nunca ficar de cabeça pra baixo.
      var angle = math.atan2(-label.tangentZ, label.tangentX) + theta;
      while (angle > math.pi / 2) {
        angle -= math.pi;
      }
      while (angle <= -math.pi / 2) {
        angle += math.pi;
      }
      final cosA = math.cos(angle).abs(), sinA = math.sin(angle).abs();
      final box = ui.Rect.fromCenter(
        center: ui.Offset(px, py),
        width: glyph.width * cosA + glyph.height * sinA + 8,
        height: glyph.width * sinA + glyph.height * cosA + 4,
      );
      var collides = false;
      for (final r in placed) {
        if (r.overlaps(box)) {
          collides = true;
          break;
        }
      }
      if (collides) continue;
      placed.add(box);
      drawn++;
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(angle);
      final offset = ui.Offset(-glyph.width / 2, -glyph.height / 2);
      glyph.outline.paint(canvas, offset);
      glyph.fill.paint(canvas, offset);
      canvas.restore();
    }
  }

  void _addFill(Map2DFill fill) {
    final path = ui.Path()..fillType = ui.PathFillType.evenOdd;
    for (final ring in fill.rings) {
      if (ring.length < 6) continue; // < 3 pontos
      path.moveTo(ring[0], ring[1]);
      for (var i = 2; i < ring.length; i += 2) {
        path.lineTo(ring[i], ring[i + 1]);
      }
      path.close();
    }
    _fills.add((
      path: path,
      paint: ui.Paint()..color = _color(fill.color),
      bbox: _fillBbox(fill.rings),
    ));
  }

  static ui.Path _polyline(Float32List points) {
    final path = ui.Path();
    if (points.length < 4) return path;
    path.moveTo(points[0], points[1]);
    for (var i = 2; i < points.length; i += 2) {
      path.lineTo(points[i], points[i + 1]);
    }
    return path;
  }

  static ui.Rect _bbox(Float32List points) {
    var minX = double.infinity, maxX = -double.infinity;
    var minZ = double.infinity, maxZ = -double.infinity;
    for (var i = 0; i < points.length; i += 2) {
      final x = points[i], z = points[i + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (z < minZ) minZ = z;
      if (z > maxZ) maxZ = z;
    }
    return ui.Rect.fromLTRB(minX, minZ, maxX, maxZ);
  }

  static ui.Rect _fillBbox(List<Float32List> rings) {
    var minX = double.infinity, maxX = -double.infinity;
    var minZ = double.infinity, maxZ = -double.infinity;
    for (final ring in rings) {
      final b = _bbox(ring);
      minX = math.min(minX, b.left);
      maxX = math.max(maxX, b.right);
      minZ = math.min(minZ, b.top);
      maxZ = math.max(maxZ, b.bottom);
    }
    return ui.Rect.fromLTRB(minX, minZ, maxX, maxZ);
  }

  /// Cor da paleta (Vector3 0..1) como sRGB — mesmos valores numéricos
  /// usados nos materiais noturnos da cena 3D.
  static ui.Color _color(Vector3 c) => ui.Color.fromRGBO(
    (c.x * 255).round(),
    (c.y * 255).round(),
    (c.z * 255).round(),
    1,
  );
}
