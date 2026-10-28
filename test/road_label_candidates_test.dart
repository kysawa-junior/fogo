import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fogo/engine/fogo_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fogo/features/map/presentation/render/label_candidates.dart';

void main() {
  test(
    'road label uses cumulative midpoint and area label policy stays stable',
    () {
      final engine = FogoEngine.build(
        Uint8List.fromList(utf8.encode(_unevenRoadAndAreaOsm)),
      )!;
      final candidates = extractLabelCandidates(engine);
      final road = candidates.singleWhere(
        (candidate) => candidate.text == 'Uneven',
      );
      final projectedRoad = [
        for (final point in engine.model.roads.single.points)
          engine.projector.project(point),
      ];
      final totalLength = _length(projectedRoad);
      final expected = _pointAt(projectedRoad, totalLength / 2);
      final arithmeticMeanX =
          projectedRoad.fold<double>(0, (sum, point) => sum + point.x) /
          projectedRoad.length;

      expect(road.worldPoint.x, closeTo(expected.x, 1e-5));
      expect(road.worldPoint.z, closeTo(expected.z, 1e-5));
      expect(road.worldPoint.x, isNot(closeTo(arithmeticMeanX, 1)));

      // Tangente do segmento do rótulo: unitária e alinhada à via.
      final tangentLength = math.sqrt(
        road.tangentX * road.tangentX + road.tangentZ * road.tangentZ,
      );
      expect(tangentLength, closeTo(1, 1e-6));
      expect(road.tangentX, isNot(0));

      final area = candidates.singleWhere(
        (candidate) => candidate.text == 'Named Area',
      );
      final outer = engine.model.landAreas.single.polygons.first.first;
      final meanLat =
          outer.fold<double>(0, (sum, point) => sum + point.latitude) /
          outer.length;
      final meanLon =
          outer.fold<double>(0, (sum, point) => sum + point.longitude) /
          outer.length;
      final areaCenter = engine.projector.project(
        GeoCoordinate(meanLat, meanLon),
      );
      expect(area.worldPoint.x, closeTo(areaCenter.x, 1e-5));
      expect(area.worldPoint.z, closeTo(areaCenter.z, 1e-5));
      expect(area.priority, 2);
      expect(area.maxDistanceMeters, 4000);

      expect(engine.map2d.strokes, hasLength(1));
      expect(engine.map2d.fills, hasLength(1));
    },
  );
}

double _length(List<Vector3> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += (points[i] - points[i - 1]).length;
  }
  return total;
}

Vector3 _pointAt(List<Vector3> points, double distance) {
  var walked = 0.0;
  for (var i = 1; i < points.length; i++) {
    final segmentLength = (points[i] - points[i - 1]).length;
    if (segmentLength > 0 && walked + segmentLength >= distance) {
      return points[i - 1] +
          (points[i] - points[i - 1]) * ((distance - walked) / segmentLength);
    }
    walked += segmentLength;
  }
  return points.last;
}

const _unevenRoadAndAreaOsm = '''
<osm version="0.6">
  <node id="1" lat="0" lon="0"/>
  <node id="2" lat="0" lon="0.0001"/>
  <node id="3" lat="0" lon="0.001"/>
  <way id="10">
    <nd ref="1"/><nd ref="2"/><nd ref="3"/>
    <tag k="highway" v="residential"/>
    <tag k="name" v="Uneven"/>
  </way>
  <node id="4" lat="0.002" lon="0"/>
  <node id="5" lat="0.002" lon="0.001"/>
  <node id="6" lat="0.003" lon="0.001"/>
  <node id="7" lat="0.003" lon="0"/>
  <way id="20">
    <nd ref="4"/><nd ref="5"/><nd ref="6"/><nd ref="7"/><nd ref="4"/>
    <tag k="landuse" v="residential"/>
    <tag k="name" v="Named Area"/>
  </way>
</osm>
''';
