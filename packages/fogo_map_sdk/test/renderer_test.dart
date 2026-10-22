import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart';
import 'package:fogo_map_sdk/src/renderer.dart';
import 'package:fogo_map_sdk/src/road_geometry.dart';

import 'test_support.dart';

void main() {
  group('rendering order and clipping', () {
    test(
      'clips content to exact manifest bounds and paints roads above areas',
      () async {
        const Color background = Color(0xFF101010);
        const Color water = Color(0xFF0000FF);
        const Color road = Color(0xFFFF0000);
        final FogoMapManifest manifest = testManifest(
          bounds: const FogoGeoBounds(west: -2, south: -2, east: 2, north: 2),
          cellSize: 1,
        );
        final Uint8List pixels = await _render(
          camera: const FogoCameraState(center: FogoCoordinate(0, 0), zoom: 5),
          manifest: manifest,
          data: FogoMapRenderData(
            areas: [
              FogoMapArea(
                kind: FogoAreaKind.water,
                coordinates: [-5, -5, -5, 5, 5, 5, 5, -5],
                bbox: [-5, -5, 5, 5],
              ),
            ],
          ),
          style: FogoMapStyle(
            background: background,
            water: water,
            showRoads: false,
            showWaterLines: false,
            showRail: false,
            showBuildings: false,
            showLabels: false,
            showPois: false,
            showAttribution: false,
          ),
          size: const Size(512, 512),
        );
        expect(_pixel(pixels, 512, 256, 256), water);
        expect(_pixel(pixels, 512, 200, 256), background);
        expect(_pixel(pixels, 512, 256, 180), background);

        final Uint8List ordered = await _render(
          camera: const FogoCameraState(center: FogoCoordinate(0, 0), zoom: 16),
          manifest: testManifest(
            bounds: const FogoGeoBounds(west: -1, south: -1, east: 1, north: 1),
          ),
          data: FogoMapRenderData(
            areas: [
              FogoMapArea(
                kind: FogoAreaKind.green,
                coordinates: [
                  -0.003,
                  -0.003,
                  -0.003,
                  0.003,
                  0.003,
                  0.003,
                  0.003,
                  -0.003,
                ],
                bbox: [-0.003, -0.003, 0.003, 0.003],
              ),
            ],
            roads: [_road(FogoRoadClass.motorway, lat: 0)],
          ),
          style: FogoMapStyle(
            background: background,
            green: const Color(0xFF00FF00),
            roadMotorway: road,
            showWaterLines: false,
            showRail: false,
            showBuildings: false,
            showLabels: false,
            showPois: false,
            showAttribution: false,
          ),
          size: const Size(256, 256),
        );
        expect(_pixel(ordered, 256, 128, 128), road);
      },
    );

    test(
      'paints area, water-line, rail, building, road, and POI layers in order',
      () async {
        const Color water = Color(0xFF0000FF);
        const Color waterLine = Color(0xFFFF0000);
        const Color railBed = Color(0xFFFFFF00);
        const Color railTie = Color(0xFF00FFFF);
        const Color building = Color(0xFFFF00FF);
        const Color road = Color(0xFF00FF00);
        const Color poi = Color(0xFFFF8800);
        const Size size = Size(256, 256);
        final FogoCameraTransform transform = FogoCameraTransform(
          _camera,
          size,
        );
        final Uint8List pixels = await _render(
          camera: _camera,
          manifest: testManifest(
            bounds: const FogoGeoBounds(
              west: -0.02,
              south: -0.02,
              east: 0.02,
              north: 0.02,
            ),
          ),
          data: FogoMapRenderData(
            areas: [
              FogoMapArea(
                kind: FogoAreaKind.water,
                coordinates: [
                  -0.004,
                  -0.004,
                  -0.004,
                  0.004,
                  0.004,
                  0.004,
                  0.004,
                  -0.004,
                ],
                bbox: [-0.004, -0.004, 0.004, 0.004],
              ),
              FogoMapArea(
                kind: FogoAreaKind.boundary,
                coordinates: [
                  0.002,
                  -0.002,
                  0.002,
                  0.002,
                  -0.002,
                  0.002,
                  -0.002,
                  -0.002,
                ],
                bbox: [-0.002, -0.002, 0.002, 0.002],
              ),
            ],
            waterLines: [
              FogoMapWaterLine(
                kind: FogoWaterLineKind.river,
                name: '',
                coordinates: [0.0014, -0.01, 0.0014, 0.01],
                bbox: [0.0014, -0.01, 0.0014, 0.01],
              ),
              FogoMapWaterLine(
                kind: FogoWaterLineKind.river,
                name: '',
                coordinates: [0.0005, -0.01, 0.0005, 0.01],
                bbox: [0.0005, -0.01, 0.0005, 0.01],
              ),
            ],
            rails: [
              FogoMapRail(
                kind: FogoRailKind.rail,
                coordinates: [0.0005, -0.01, 0.0005, 0.01],
                bbox: [0.0005, -0.01, 0.0005, 0.01],
              ),
            ],
            buildings: [
              FogoMapArea(
                kind: FogoAreaKind.green,
                coordinates: [
                  0.0002,
                  -0.001,
                  0.0002,
                  0.001,
                  0.0008,
                  0.001,
                  0.0008,
                  -0.001,
                ],
                bbox: [0.0002, -0.001, 0.0008, 0.001],
              ),
            ],
            roads: [
              FogoMapRoad(
                roadClass: FogoRoadClass.primary,
                name: '',
                oneway: false,
                bridge: false,
                tunnel: false,
                coordinates: [0.0005, -0.0005, 0.0005, 0.0005],
                bbox: [0.0005, -0.0005, 0.0005, 0.0005],
              ),
            ],
            pois: const [
              FogoMapPoi(
                kind: FogoPoiKind.amenity,
                coordinate: FogoCoordinate(0.0005, 0),
                name: '',
              ),
            ],
          ),
          style: FogoMapStyle(
            background: const Color(0xFF101010),
            water: water,
            waterLine: waterLine,
            boundary: const Color(0xFFFFFFFF),
            railBed: railBed,
            railTie: railTie,
            building: building,
            roadPrimary: road,
            poiDot: poi,
            roadCasing: const Color(0xFF202020),
            showAttribution: false,
          ),
          size: size,
        );

        Color at(FogoCoordinate coordinate) {
          final Offset point = transform.project(coordinate)!;
          return _pixel(pixels, 256, point.dx.round(), point.dy.round());
        }

        expect(at(const FogoCoordinate(0.002, 0)), isNot(water));
        expect(at(const FogoCoordinate(0.0014, 0)), waterLine);
        final Color railPixel = at(const FogoCoordinate(0.0005, 0.002));
        expect(railPixel.g, greaterThan(0.8));
        expect(railPixel, isNot(water));
        expect(at(const FogoCoordinate(0.0005, 0.0007)), building);
        expect(at(const FogoCoordinate(0.0005, 0.0003)), road);
        expect(at(const FogoCoordinate(0.0005, 0)), poi);
      },
    );

    test(
      'road classes render in hierarchy order and obey style filters',
      () async {
        const Color background = Color(0xFF101010);
        const Color main = Color(0xFFFF0000);
        const Color primary = Color(0xFFFFFF00);
        final FogoMapManifest manifest = testManifest(
          bounds: const FogoGeoBounds(west: -1, south: -1, east: 1, north: 1),
        );
        final FogoMapRenderData data = FogoMapRenderData(
          roads: [_road(FogoRoadClass.primary), _road(FogoRoadClass.motorway)],
        );
        final Uint8List ordered = await _render(
          camera: _camera,
          manifest: manifest,
          data: data,
          style: FogoMapStyle(
            background: background,
            roadMotorway: main,
            roadPrimary: primary,
            showAreas: false,
            showWaterLines: false,
            showRail: false,
            showBuildings: false,
            showLabels: false,
            showPois: false,
            showAttribution: false,
          ),
        );
        expect(_pixel(ordered, 256, 128, 128), main);

        final Uint8List filtered = await _render(
          camera: _camera,
          manifest: manifest,
          data: data,
          style: FogoMapStyle(
            background: background,
            roadMotorway: main,
            roadPrimary: primary,
            roadFilter: const {FogoRoadFilterGroup.primary},
            showAreas: false,
            showWaterLines: false,
            showRail: false,
            showBuildings: false,
            showLabels: false,
            showPois: false,
            showAttribution: false,
          ),
        );
        expect(_pixel(filtered, 256, 128, 128), primary);
        expect(
          FogoMapPainter.isRoadClassVisible(FogoRoadClass.service, 14),
          isFalse,
        );
        expect(
          FogoMapPainter.isRoadClassVisible(FogoRoadClass.service, 14.5),
          isTrue,
        );
        expect(
          FogoMapStyle(roadFilter: const {FogoRoadFilterGroup.main})
              .roadClassVisible(FogoRoadClass.trunk),
          isTrue,
        );
        expect(
          FogoMapStyle(roadFilter: const {FogoRoadFilterGroup.main})
              .roadClassVisible(FogoRoadClass.residential),
          isFalse,
        );
      },
    );

    test(
      'road casing, bridge casing, tunnel fill, and one-way arrows render',
      () async {
        const Color background = Color(0xFF101010);
        const Color casing = Color(0xFF0000FF);
        const Color bridgeCasing = Color(0xFFFFFF00);
        const Color fill = Color(0xFF00FF00);
        final FogoMapManifest manifest = testManifest(
          bounds: const FogoGeoBounds(west: -1, south: -1, east: 1, north: 1),
        );
        final FogoMapStyle style = FogoMapStyle(
          background: background,
          roadCasing: casing,
          roadCasingBridge: bridgeCasing,
          roadMotorway: fill,
          roadTrunk: fill,
          onewayArrow: const Color(0xFFFFFFFF),
          showAreas: false,
          showWaterLines: false,
          showRail: false,
          showBuildings: false,
          showLabels: false,
          showPois: false,
          showAttribution: false,
        );
        final Uint8List road = await _render(
          camera: _camera,
          manifest: manifest,
          data: FogoMapRenderData(roads: [_road(FogoRoadClass.motorway)]),
          style: style,
        );
        expect(_pixel(road, 256, 128, 128), fill);
        final Color casingPixel = _pixel(road, 256, 128, 134);
        expect((casingPixel.b * 255).round(), greaterThan(100));
        expect((casingPixel.r * 255).round(), lessThan(100));

        final Uint8List bridge = await _render(
          camera: _camera,
          manifest: manifest,
          data: FogoMapRenderData(
            roads: [_road(FogoRoadClass.trunk, bridge: true)],
          ),
          style: style,
        );
        expect(_pixel(bridge, 256, 128, 128), fill);
        final Color bridgePixel = _pixel(bridge, 256, 128, 134);
        expect((bridgePixel.r * 255).round(), greaterThan(100));
        expect((bridgePixel.g * 255).round(), greaterThan(100));
        expect((bridgePixel.b * 255).round(), lessThan(100));

        final Uint8List tunnel = await _render(
          camera: _camera,
          manifest: manifest,
          data: FogoMapRenderData(
            roads: [_road(FogoRoadClass.trunk, lat: 0.0006, tunnel: true)],
          ),
          style: style,
        );
        final Color tunnelPixel = _pixel(tunnel, 256, 128, 100);
        expect(tunnelPixel, isNot(background));
        expect(
          tunnelPixel,
          isNot(fill),
          reason: 'tunnel is drawn with 45% alpha',
        );

        final Uint8List oneway = await _render(
          camera: _camera,
          manifest: manifest,
          data: FogoMapRenderData(
            roads: [_road(FogoRoadClass.motorway, oneway: true)],
          ),
          style: style,
        );
        expect(_differingPixels(road, oneway, 256), greaterThan(0));
      },
    );

    test('route polylines paint above clipped map features', () async {
      const Color background = Color(0xFF101010);
      const Color water = Color(0xFF0000FF);
      const Color routeColor = Color(0xFFFF0000);
      final Uint8List pixels = await _render(
        camera: _camera,
        manifest: testManifest(
          bounds: const FogoGeoBounds(west: -1, south: -1, east: 1, north: 1),
        ),
        data: FogoMapRenderData(
          areas: [
            FogoMapArea(
              kind: FogoAreaKind.water,
              coordinates: [
                -0.003,
                -0.003,
                -0.003,
                0.003,
                0.003,
                0.003,
                0.003,
                -0.003,
              ],
              bbox: [-0.003, -0.003, 0.003, 0.003],
            ),
          ],
        ),
        style: FogoMapStyle(
          background: background,
          water: water,
          showWaterLines: false,
          showRail: false,
          showRoads: false,
          showBuildings: false,
          showLabels: false,
          showPois: false,
          showAttribution: false,
        ),
        polylines: [
          FogoMapPolyline(
            id: 'route',
            points: const [FogoCoordinate(0, -0.003), FogoCoordinate(0, 0.003)],
            color: routeColor,
            width: 5,
          ),
        ],
      );
      expect(_pixel(pixels, 256, 128, 128), routeColor);
      expect(_pixel(pixels, 256, 128, 110), water);
    });

    test('route polylines use the pitched camera transform', () async {
      const Size size = Size(256, 256);
      const FogoCameraState camera = FogoCameraState(
        center: FogoCoordinate(0, 0),
        zoom: 16,
        pitch: 45,
      );
      const FogoCoordinate sample = FogoCoordinate(0.001, 0.001);
      const Color routeColor = Color(0xFFFF0000);
      final Uint8List pixels = await _render(
        camera: camera,
        manifest: testManifest(
          bounds: const FogoGeoBounds(west: -1, south: -1, east: 1, north: 1),
        ),
        data: FogoMapRenderData(),
        style: _quietStyle,
        polylines: [
          FogoMapPolyline(
            id: 'pitched-route',
            points: const [
              FogoCoordinate(-0.003, -0.003),
              FogoCoordinate(0.003, 0.003),
            ],
            color: routeColor,
            width: 5,
          ),
        ],
        size: size,
      );
      final Offset? pitchedPoint = FogoCameraTransform(
        camera,
        size,
      ).project(sample);
      final Offset? topDownPoint = FogoCameraTransform(
        camera.copyWith(pitch: 0),
        size,
      ).project(sample);
      expect(pitchedPoint, isNotNull);
      expect(topDownPoint, isNotNull);
      final Offset pitched = pitchedPoint!;
      final Offset topDown = topDownPoint!;

      expect(
        _pixel(pixels, 256, pitched.dx.round(), pitched.dy.round()),
        routeColor,
      );
      expect(
        _pixel(pixels, 256, topDown.dx.round(), topDown.dy.round()),
        isNot(routeColor),
      );
    });

    test('road surface width stays in screen pixels across zoom levels', () {
      final FogoMapRoad road = _road(FogoRoadClass.primary);
      for (final double zoom in [7, 12, 16, 19]) {
        final FogoCameraTransform transform = FogoCameraTransform(
          FogoCameraState(center: const FogoCoordinate(0, 0), zoom: zoom),
          const Size(256, 256),
        );
        final FogoRoadSurface surface = FogoRoadSurfaceBuilder.build([
          for (int i = 0; i < road.coordinates.length; i += 2)
            transform.groundOffset(
              FogoCoordinate(road.coordinates[i], road.coordinates[i + 1]),
            ),
        ], 5)!;
        final List<double> ys = [
          for (final Offset point in surface.contours.single) point.dy,
        ];
        expect(ys.reduce((a, b) => a < b ? a : b), closeTo(-5, 0.01));
        expect(ys.reduce((a, b) => a > b ? a : b), closeTo(5, 0.01));
      }
    });
  });

  group('buildings, labels, and POIs', () {
    test(
      'estimate flags control 3D extrusion of explicit and estimated heights',
      () async {
        final FogoMapManifest manifest = testManifest(
          bounds: const FogoGeoBounds(west: -1, south: -1, east: 1, north: 1),
        );
        final FogoMapArea flat = FogoMapArea(
          kind: FogoAreaKind.water,
          coordinates: [
            -0.0003,
            -0.0003,
            -0.0003,
            0.0003,
            0.0003,
            0.0003,
            0.0003,
            -0.0003,
          ],
          bbox: [-0.0003, -0.0003, 0.0003, 0.0003],
        );
        final FogoMapArea elevated = FogoMapArea(
          kind: flat.kind,
          coordinates: flat.coordinates,
          bbox: flat.bbox,
          heightMeters: 20,
        );
        final FogoMapStyle realOnly = FogoMapStyle(
          background: _quietStyle.background,
          building: _quietStyle.building,
          showAreas: false,
          showWaterLines: false,
          showRail: false,
          showRoads: false,
          showBuildings: true,
          showLabels: false,
          showPois: false,
          showAttribution: false,
          estimateBuildingHeights: false,
        );

        // Real-heights-only: a tagged building extrudes, a flat one does not.
        final Uint8List flatPixels = await _render(
          camera: _camera.copyWith(pitch: 45),
          manifest: manifest,
          data: FogoMapRenderData(buildings: [flat]),
          style: realOnly,
        );
        final Uint8List elevatedPixels = await _render(
          camera: _camera.copyWith(pitch: 45),
          manifest: manifest,
          data: FogoMapRenderData(buildings: [elevated]),
          style: realOnly,
        );
        expect(
          _differingPixels(elevatedPixels, flatPixels, 256),
          greaterThan(0),
        );

        // Default style estimates heights deterministically, so untagged
        // buildings also extrude at pitch, and repeated renders match.
        final Uint8List estimatedPixels = await _render(
          camera: _camera.copyWith(pitch: 45),
          manifest: manifest,
          data: FogoMapRenderData(buildings: [flat]),
          style: _quietStyle,
        );
        expect(
          _differingPixels(estimatedPixels, flatPixels, 256),
          greaterThan(0),
        );
        final Uint8List againPixels = await _render(
          camera: _camera.copyWith(pitch: 45),
          manifest: manifest,
          data: FogoMapRenderData(buildings: [flat]),
          style: _quietStyle,
        );
        expect(
          _differingPixels(estimatedPixels, againPixels, 256),
          0,
          reason: 'estimated heights must be deterministic',
        );

        final Uint8List hiddenPixels = await _render(
          camera: _camera.copyWith(pitch: 45),
          manifest: manifest,
          data: FogoMapRenderData(buildings: [flat]),
          style: FogoMapStyle(
            background: _quietStyle.background,
            showAreas: false,
            showWaterLines: false,
            showRail: false,
            showRoads: false,
            showBuildings: false,
            showLabels: false,
            showPois: false,
            showAttribution: false,
          ),
        );
        expect(
          _differingPixels(
            hiddenPixels,
            _solid(256, _quietStyle.background),
            256,
          ),
          0,
        );
      },
    );

    test('label toggles suppress labels and POIs; collision layout rejects overlap', () async {
      final FogoMapManifest manifest = testManifest(
        bounds: const FogoGeoBounds(west: -1, south: -1, east: 1, north: 1),
      );
      final FogoMapRenderData data = FogoMapRenderData(
        labels: const [
          FogoMapLabel(
            kind: FogoLabelKind.village,
            coordinate: FogoCoordinate(0, 0),
            text: 'Test town',
          ),
        ],
        pois: const [
          FogoMapPoi(
            kind: FogoPoiKind.amenity,
            coordinate: FogoCoordinate(-0.0007, -0.0007),
            name: 'Test POI',
          ),
        ],
      );
      final Uint8List visible = await _render(
        camera: _camera.copyWith(zoom: 17),
        manifest: manifest,
        data: data,
        style: _quietStyle,
      );
      final Uint8List hidden = await _render(
        camera: _camera.copyWith(zoom: 17),
        manifest: manifest,
        data: data,
        style: FogoMapStyle(
          background: _quietStyle.background,
          showAreas: false,
          showWaterLines: false,
          showRail: false,
          showRoads: false,
          showBuildings: false,
          showLabels: false,
          showPois: true,
          showAttribution: false,
        ),
      );
      expect(_differingPixels(visible, hidden, 256), greaterThan(0));
      expect(
        _differingPixels(hidden, _solid(256, _quietStyle.background), 256),
        0,
      );

      final Uint8List poiVisible = await _render(
        camera: _camera.copyWith(zoom: 17),
        manifest: manifest,
        data: FogoMapRenderData(
          pois: const [
            FogoMapPoi(
              kind: FogoPoiKind.amenity,
              coordinate: FogoCoordinate(0, 0),
              name: 'Visible POI',
            ),
          ],
        ),
        style: _quietStyle,
      );
      final Uint8List poiHidden = await _render(
        camera: _camera.copyWith(zoom: 17),
        manifest: manifest,
        data: FogoMapRenderData(
          pois: const [
            FogoMapPoi(
              kind: FogoPoiKind.amenity,
              coordinate: FogoCoordinate(0, 0),
              name: 'Visible POI',
            ),
          ],
        ),
        style: FogoMapStyle(
          background: _quietStyle.background,
          showAreas: false,
          showWaterLines: false,
          showRail: false,
          showRoads: false,
          showBuildings: false,
          showLabels: true,
          showPois: false,
          showAttribution: false,
        ),
      );
      expect(_differingPixels(poiVisible, poiHidden, 256), greaterThan(0));

      final FogoLabelLayout layout = FogoLabelLayout(sameLabelDistance: 350);
      expect(
        layout.tryPlace(
          key: 'place:Test',
          anchor: const Offset(50, 50),
          aabb: const Rect.fromLTWH(20, 45, 60, 10),
        ),
        isTrue,
      );
      expect(
        layout.tryPlace(
          key: 'road:Nearby',
          anchor: const Offset(85, 50),
          aabb: const Rect.fromLTWH(55, 45, 60, 10),
        ),
        isFalse,
        reason: 'overlapping labels must not both be placed',
      );
    });
  });
}

const FogoCameraState _camera = FogoCameraState(
  center: FogoCoordinate(0, 0),
  zoom: 16,
);

final FogoMapStyle _quietStyle = FogoMapStyle(
  background: const Color(0xFF101010),
  building: const Color(0xFFDDDDDD),
  labelCity: const Color(0xFFFFFFFF),
  labelSuburb: const Color(0xFFFFFFFF),
  labelPoi: const Color(0xFFFFFFFF),
  labelHalo: const Color(0xFF000000),
  poiDot: const Color(0xFFFF0000),
  showAreas: false,
  showWaterLines: false,
  showRail: false,
  showRoads: false,
  showBuildings: true,
  showLabels: true,
  showPois: true,
  showAttribution: false,
);

FogoMapRoad _road(
  FogoRoadClass roadClass, {
  double lat = 0,
  bool bridge = false,
  bool tunnel = false,
  bool oneway = false,
}) => FogoMapRoad(
  roadClass: roadClass,
  name: '',
  ref: null,
  oneway: oneway,
  bridge: bridge,
  tunnel: tunnel,
  coordinates: [lat, -0.004, lat, 0.004],
  bbox: [lat, -0.004, lat, 0.004],
);

Future<Uint8List> _render({
  required FogoCameraState camera,
  required FogoMapManifest manifest,
  required FogoMapRenderData data,
  required FogoMapStyle style,
  List<FogoMapPolyline> polylines = const [],
  Size size = const Size(256, 256),
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  FogoMapPainter(
    camera: camera,
    data: data,
    manifest: manifest,
    style: style,
    polylines: polylines,
    surfaceCache: FogoRoadSurfaceCache(),
    projectionCache: FogoProjectionCache(),
  ).paint(canvas, size);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  final ByteData bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!;
  image.dispose();
  picture.dispose();
  return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
}

Color _pixel(Uint8List bytes, int width, int x, int y) {
  final int i = (y * width + x) * 4;
  return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
}

int _differingPixels(Uint8List a, Uint8List b, int width) {
  int different = 0;
  for (int i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) {
      different++;
    }
  }
  return different;
}

Uint8List _solid(int size, Color color) => Uint8List.fromList([
  for (int i = 0; i < size * size; i++) ...[
    (color.r * 255).round(),
    (color.g * 255).round(),
    (color.b * 255).round(),
    (color.a * 255).round(),
  ],
]);
