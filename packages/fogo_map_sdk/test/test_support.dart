import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart';

Map<String, Object?> manifestJson({
  double west = -2,
  double south = -2,
  double east = 2,
  double north = 2,
  double cellSize = 1,
  int columns = 4,
  int rows = 4,
  String source = 'test-map',
}) => {
  'bbox': [west, south, east, north],
  'tileBounds': {'west': west, 'south': south, 'east': east, 'north': north},
  'cellSize': cellSize,
  'cols': columns,
  'rows': rows,
  'attribution': '© OpenStreetMap contributors',
  'generatedAt': 'test',
  'source': source,
};

FogoMapManifest testManifest({
  FogoGeoBounds? bounds,
  double cellSize = 1,
  int columns = 4,
  int rows = 4,
  String source = 'test-map',
}) => FogoMapManifest(
  bounds: bounds ?? const FogoGeoBounds(west: -2, south: -2, east: 2, north: 2),
  cellSize: cellSize,
  columns: columns,
  rows: rows,
  attribution: '© OpenStreetMap contributors',
  generatedAt: 'test',
  source: source,
);

Uint8List gzipJson(Object? value) =>
    GZipEncoder().encodeBytes(utf8.encode(jsonEncode(value)));

class MemoryAssetBundle extends CachingAssetBundle {
  MemoryAssetBundle(this.assets);

  final Map<String, List<int>> assets;
  final List<String> loadRequests = [];

  @override
  Future<ByteData> load(String key) async {
    loadRequests.add(key);
    final List<int>? bytes = assets[key];
    if (bytes == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

class StubMapDataSource extends FogoMapDataSource {
  StubMapDataSource(this.manifest, {this.cell, this.onLoadCell});

  final FogoMapManifest manifest;
  final FogoMapCellData? cell;
  final Future<FogoMapCellData?> Function(FogoCellTier, int, int)? onLoadCell;
  final List<(FogoCellTier, int, int)> requests = [];

  @override
  Future<FogoMapManifest> loadManifest() async => manifest;

  @override
  Future<FogoMapCellData?> loadCell(FogoCellTier tier, int x, int y) async {
    requests.add((tier, x, y));
    return onLoadCell == null ? cell : onLoadCell!(tier, x, y);
  }
}

Map<String, Object?> areaRecord({Object? height}) => {
  'k': 0,
  'p': [-0.001, -0.001, -0.001, 0.001, 0.001, 0.001, 0.001, -0.001],
  'b': [-0.001, -0.001, 0.001, 0.001],
  'height': ?height,
};
