import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo/engine/fogo_engine.dart';
import 'package:fogo/features/map/presentation/render/flutter_scene_adapter.dart';
import 'package:fogo/features/map/presentation/render/fogo_scene_view.dart';
import 'package:fogo/features/map/presentation/render/label_candidates.dart';
import 'package:fogo/features/map/presentation/render/map_2d/map_2d_renderer.dart';
import 'package:fogo/features/map/presentation/render/map_2d/map_2d_view.dart';
import 'package:flutter_scene/scene.dart' as fscene;

const _osmFixture = '''
<osm version="0.6">
  <node id="1" lat="0" lon="0"/>
  <node id="2" lat="0" lon="0.0001"/>
  <node id="3" lat="0" lon="0.001"/>
  <way id="10">
    <nd ref="1"/><nd ref="2"/><nd ref="3"/>
    <tag k="highway" v="residential"/>
    <tag k="name" v="Main Street"/>
    <tag k="width" v="8"/>
  </way>
</osm>
''';

bool _gpuAvailable() {
  try {
    fscene.Scene();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  testWidgets('Map2DView paints labels in the renderer (no widget overlay)', (
    tester,
  ) async {
    final engine = FogoEngine.build(
      Uint8List.fromList(utf8.encode(_osmFixture)),
    )!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Map2DView(
              engine: engine,
              camera: OrbitCamera(),
              labelCandidates: extractLabelCandidates(engine),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Rótulos vivem DENTRO do CustomPaint (decal sobre a via) — não há
    // camada de widgets de rótulo acima do mapa.
    expect(find.byType(CustomPaint), findsWidgets);
    expect(
      extractLabelCandidates(engine),
      isNotEmpty,
      reason: 'named fixture road yields a label candidate',
    );
  });

  testWidgets('FogoSceneView carries no UI label overlay (GPU-gated)', (
    tester,
  ) async {
    if (!_gpuAvailable()) {
      markTestSkipped('No Impeller GPU context');
      return;
    }
    final engine = FogoEngine.build(
      Uint8List.fromList(utf8.encode(_osmFixture)),
    )!;
    final adapter = FlutterSceneAdapter();
    await adapter.uploadScene(engine.scene);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: FogoSceneView(
              adapter: adapter,
              camera: OrbitCamera(),
              enabled: true,
              onEntityPicked: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CustomPaint), findsOneWidget);
  });

  test('pxPerMeter casa com o FOV 45° do flutter_scene (mesmo zoom 2D/3D)', () {
    // PerspectiveCamera default: fovRadiansY = 45° → px/m = h/(2·tan(22.5°)·d).
    const h = 800.0, d = 1000.0;
    expect(
      Map2DRenderer.pxPerMeter(h, d),
      closeTo(h / (2 * math.tan(math.pi / 8) * d), 1e-9),
    );
  });

  test('Map2DRenderer paints street-name decals along the road', () {
    final engine = FogoEngine.build(
      Uint8List.fromList(utf8.encode(_osmFixture)),
    )!;
    final renderer = Map2DRenderer(engine.map2d);
    final labels = extractLabelCandidates(engine);
    final point = labels.first.worldPoint;
    // Próximo (500 m): rótulos visíveis; painter roda rotação, colisão
    // e rasterização de texto sem exceção.
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, const ui.Rect.fromLTRB(0, 0, 800, 600));
    renderer.paint(
      canvas,
      targetX: point.x,
      targetZ: point.z,
      azimuth: 0,
      pxPerMeter: 0.6,
      viewWidth: 800,
      viewHeight: 600,
      distanceMeters: 500,
      labels: labels,
    );
    recorder.endRecording().dispose();
  });
}
