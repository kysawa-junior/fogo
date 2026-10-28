import 'package:fogo/engine/domain/road_properties.dart';
import 'package:fogo/engine/geo/geo_coordinate.dart';
import 'package:fogo/engine/osm/osm_elements.dart';
import 'package:fogo/engine/osm/osm_feature_mapper.dart';
import 'package:fogo/engine/osm/road_deduplicator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OSM road direction mapping', () {
    final cases =
        <
          ({
            String label,
            Map<String, String> tags,
            RoadDirection direction,
            bool oneway,
          })
        >[
          (
            label: 'oneway=yes is forward and one-way',
            tags: {'oneway': 'yes'},
            direction: RoadDirection.forward,
            oneway: true,
          ),
          (
            label: 'oneway=-1 is reverse and one-way',
            tags: {'oneway': '-1'},
            direction: RoadDirection.reverse,
            oneway: true,
          ),
          (
            label: 'oneway=no permits both directions',
            tags: {'oneway': 'no'},
            direction: RoadDirection.both,
            oneway: false,
          ),
          (
            label: 'missing oneway on roundabout defaults forward',
            tags: {'junction': 'roundabout'},
            direction: RoadDirection.forward,
            oneway: true,
          ),
          (
            label: 'explicit roundabout oneway=no overrides default',
            tags: {'junction': 'roundabout', 'oneway': 'no'},
            direction: RoadDirection.both,
            oneway: false,
          ),
          (
            label: 'other oneway values permit both directions',
            tags: {'oneway': 'reversible'},
            direction: RoadDirection.both,
            oneway: false,
          ),
          (
            label: 'other roundabout oneway values do not imply one-way',
            tags: {'junction': 'roundabout', 'oneway': 'reversible'},
            direction: RoadDirection.both,
            oneway: false,
          ),
          (
            label: 'absent oneway on ordinary road permits both',
            tags: const {},
            direction: RoadDirection.both,
            oneway: false,
          ),
        ];

    for (final item in cases) {
      test(item.label, () {
        final store = _storeWithWays([
          _way(10, [31, 11, 90], item.tags),
        ]);
        final road = OsmFeatureMapper().map(store).roads.single;

        expect(road.properties.direction, item.direction);
        expect(road.properties.oneway, item.oneway);
        expect(road.nodeRefs, [
          31,
          11,
          90,
        ], reason: 'reverse direction must not rewrite ordered OSM references');
        expect(road.points, [
          const GeoCoordinate(-22.1, -49.1),
          const GeoCoordinate(-22.2, -49.2),
          const GeoCoordinate(-22.3, -49.3),
        ], reason: 'point order and nodeRefs stay aligned and unchanged');
      });
    }
  });

  group('road deduplication preserves direction semantics', () {
    test('roads with differing directions are not deduplicated', () {
      final store = _storeWithWays([
        _way(100, [31, 11, 90], {'name': 'Shared', 'oneway': 'yes'}),
        _way(101, [31, 11, 90], {'name': 'Shared', 'oneway': '-1'}),
      ]);
      final roads = OsmFeatureMapper().map(store).roads;

      final result = RoadDeduplicator.dedupe(roads, store);

      expect(result.roads, hasLength(2));
      expect(result.removed, 0);
      expect(result.roads.map((road) => road.properties.direction), [
        RoadDirection.forward,
        RoadDirection.reverse,
      ]);
    });

    test('identical directions on identical ways can be deduplicated', () {
      final store = _storeWithWays([
        _way(100, [31, 11, 90], {'name': 'Shared', 'oneway': 'yes'}),
        _way(101, [31, 11, 90], {'name': 'Shared', 'oneway': 'yes'}),
      ]);
      final roads = OsmFeatureMapper().map(store).roads;

      final result = RoadDeduplicator.dedupe(roads, store);

      expect(result.roads, hasLength(1));
      expect(result.removed, 1);
      expect(result.roads.single.properties.direction, RoadDirection.forward);
    });
  });
}

OsmDataStore _storeWithWays(List<OsmWay> ways) {
  final store = OsmDataStore()
    ..addNode(OsmNode(id: 31, lat: -22.1, lon: -49.1))
    ..addNode(OsmNode(id: 11, lat: -22.2, lon: -49.2))
    ..addNode(OsmNode(id: 90, lat: -22.3, lon: -49.3));
  for (final way in ways) {
    store.addWay(way);
  }
  return store;
}

OsmWay _way(int id, List<int> refs, Map<String, String> extraTags) => OsmWay(
  id: id,
  nodeRefs: refs,
  tags: {'highway': 'residential', ...extraTags},
);
