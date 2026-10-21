import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fogo/features/map/vector/vector_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'manifest tileBounds retain named numeric coordinates and bbox order',
    () async {
      final Map<String, dynamic> source = jsonDecode(
        await rootBundle.loadString('assets/map/manifest.json'),
      ) as Map<String, dynamic>;

      final MapManifest manifest = MapManifest.fromJson(source);
      final MapTileBounds bounds = manifest.tileBounds;

      expect(bounds.west, -50.04);
      expect(bounds.south, -22.31);
      expect(bounds.east, -49.59);
      expect(bounds.north, -22.13);
      expect(bounds.toBbox(), [-50.04, -22.31, -49.59, -22.13]);
      expect(manifest.bbox, [-50.04, -22.31, -49.59, -22.13]);
      expect(
        () => MapManifest.fromJson({
          ...source,
          'bbox': [-22.31, -50.04, -22.13, -49.59],
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'tileBounds accepts integer JSON numbers and rejects invalid bounds',
    () {
      final MapTileBounds bounds = MapTileBounds.fromJson({
        'west': 1,
        'south': 2.0,
        'east': 3,
        'north': 4.0,
      });
      expect(bounds.toBbox(), [1.0, 2.0, 3.0, 4.0]);
      expect(
        () => MapTileBounds.fromJson({
          'west': '1',
          'south': 2,
          'east': 3,
          'north': 4,
        }),
        throwsFormatException,
      );
      expect(
        () => MapTileBounds.fromJson({
          'west': 3,
          'south': 2,
          'east': 1,
          'north': 4,
        }),
        throwsFormatException,
      );
    },
  );
}
