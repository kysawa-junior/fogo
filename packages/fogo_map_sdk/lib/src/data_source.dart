import 'dart:collection';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'data.dart';

enum FogoMapDataErrorKind { manifest, cell }

enum FogoMapDataPhase { loading, ready, empty, outsideCoverage, error }

/// Controlled data failure. Missing cells are not errors.
@immutable
class FogoMapDataError {
  const FogoMapDataError({
    required this.kind,
    required this.assetPath,
    required this.message,
    this.tier,
    this.x,
    this.y,
  });

  final FogoMapDataErrorKind kind;
  final String assetPath;
  final String message;
  final FogoCellTier? tier;
  final int? x;
  final int? y;

  String get key => '${tier?.name ?? 'manifest'}/$x/$y/$assetPath';
}

/// Map-data state surfaced through [FogoMapView.onDataStatus].
@immutable
class FogoMapDataStatus {
  FogoMapDataStatus({
    required this.phase,
    required this.manifest,
    required List<FogoMapDataError> errors,
    required this.requestedCellCount,
    required this.loadedCellCount,
  }) : errors = List.unmodifiable(errors);

  final FogoMapDataPhase phase;
  final FogoMapManifest? manifest;
  final List<FogoMapDataError> errors;
  final int requestedCellCount;
  final int loadedCellCount;

  bool get isLoading => phase == FogoMapDataPhase.loading;
  bool get hasErrors => errors.isNotEmpty;
}

class FogoMapDataException implements Exception {
  const FogoMapDataException(this.error);

  final FogoMapDataError error;

  @override
  String toString() => '${error.assetPath}: ${error.message}';
}

/// Loads the local manifest and gzip JSON cells through Flutter's asset API.
/// Cell caches are LRU-bounded to the baseline limits: 64 L0, 24 L1.
class FogoMapDataSource {
  FogoMapDataSource({
    AssetBundle? assetBundle,
    this.manifestAsset = 'assets/map/manifest.json',
    this.cellsAssetDirectory = 'assets/map/cells',
  }) : _assetBundle = assetBundle ?? rootBundle;

  static const int maxDecompressedCellBytes = 8 * 1024 * 1024;
  static const int l0CacheLimit = 64;
  static const int l1CacheLimit = 24;

  final AssetBundle _assetBundle;
  final String manifestAsset;
  final String cellsAssetDirectory;
  final LinkedHashMap<String, FogoMapCellData?> _l0 = LinkedHashMap();
  final LinkedHashMap<String, FogoMapCellData?> _l1 = LinkedHashMap();
  final Map<String, Future<FogoMapCellData?>> _inFlight = {};
  FogoMapManifest? _manifest;
  Future<FogoMapManifest>? _manifestInFlight;

  Future<FogoMapManifest> loadManifest() {
    final FogoMapManifest? loaded = _manifest;
    if (loaded != null) return Future.value(loaded);
    return _manifestInFlight ??= _loadManifest();
  }

  Future<FogoMapManifest> _loadManifest() async {
    try {
      final String text = await _assetBundle.loadString(manifestAsset);
      final FogoMapManifest manifest = FogoMapManifest.fromJson(
        jsonDecode(text),
      );
      _manifest = manifest;
      return manifest;
    } catch (error) {
      throw FogoMapDataException(
        FogoMapDataError(
          kind: FogoMapDataErrorKind.manifest,
          assetPath: manifestAsset,
          message: error.toString(),
        ),
      );
    } finally {
      _manifestInFlight = null;
    }
  }

  Future<FogoMapCellData?> loadCell(FogoCellTier tier, int x, int y) {
    final FogoMapManifest? manifest = _manifest;
    if (manifest == null) {
      throw StateError('Call loadManifest before requesting cells');
    }
    if (x < 0 || x >= manifest.columns || y < 0 || y >= manifest.rows) {
      return Future.value(null);
    }
    final String key = '${tier.name}/$x/$y';
    final LinkedHashMap<String, FogoMapCellData?> cache =
        tier == FogoCellTier.l0 ? _l0 : _l1;
    if (cache.containsKey(key)) {
      final FogoMapCellData? hit = cache.remove(key);
      cache[key] = hit;
      return Future.value(hit);
    }
    final Future<FogoMapCellData?>? pending = _inFlight[key];
    if (pending != null) return pending;
    late final Future<FogoMapCellData?> future;
    future = _loadCell(tier, x, y, key).whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  Future<FogoMapCellData?> _loadCell(
    FogoCellTier tier,
    int x,
    int y,
    String key,
  ) async {
    final String assetPath =
        '$cellsAssetDirectory/${tier.name}_${x}_$y.json.gz';
    final ByteData bytes;
    try {
      bytes = await _assetBundle.load(assetPath);
    } on FlutterError {
      _remember(tier, key, null);
      return null;
    }
    try {
      final Uint8List compressed = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      final Object? decoded = await compute<Uint8List, Object?>(
        _decodeGzipJson,
        compressed,
      );
      final FogoMapCellData cell = tier == FogoCellTier.l0
          ? FogoMapCellData.l0FromJson(decoded)
          : FogoMapCellData.l1FromJson(decoded);
      _remember(tier, key, cell);
      return cell;
    } catch (error) {
      throw FogoMapDataException(
        FogoMapDataError(
          kind: FogoMapDataErrorKind.cell,
          assetPath: assetPath,
          message: error.toString(),
          tier: tier,
          x: x,
          y: y,
        ),
      );
    }
  }

  void _remember(FogoCellTier tier, String key, FogoMapCellData? data) {
    final LinkedHashMap<String, FogoMapCellData?> cache =
        tier == FogoCellTier.l0 ? _l0 : _l1;
    final int limit = tier == FogoCellTier.l0 ? l0CacheLimit : l1CacheLimit;
    while (cache.length >= limit) {
      cache.remove(cache.keys.first);
    }
    cache[key] = data;
  }
}

Object? _decodeGzipJson(Uint8List compressed) {
  final OutputMemoryStream output = OutputMemoryStream();
  final bool decoded = GZipDecoder().decodeStream(
    InputMemoryStream(compressed),
    output,
    verify: true,
    maxOutputSize: FogoMapDataSource.maxDecompressedCellBytes,
  );
  if (!decoded) throw const FormatException('Truncated or invalid gzip cell');
  return jsonDecode(utf8.decode(output.getBytes()));
}
