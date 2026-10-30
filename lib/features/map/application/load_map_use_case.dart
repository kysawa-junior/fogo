import 'dart:io';

import 'package:flutter/services.dart';

import '../../../engine/fogo_engine.dart';
import 'osm_load_controller.dart';

/// Caso de uso: coordenar a importação de um arquivo OSM e a preparação
/// do mapa (entidades → topologia → geometria → cena), fora da UI e fora
/// do ViewModel. O pipeline roda em isolate (ver [OsmLoadController]).
class LoadMapUseCase {
  LoadMapUseCase() : _controller = OsmLoadController();

  final OsmLoadController _controller;

  bool get isRunning => _controller.isRunning;

  void cancel() => _controller.cancel();

  /// Importa um asset empacotado (`.osm`/`.osm.gz` do catálogo regional).
  Future<FogoEngine?> loadAsset(
    String assetPath, {
    void Function(String phase, int count, double fraction)? onProgress,
  }) async {
    final bytes = await rootBundle.load(assetPath);
    return loadBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      onProgress: onProgress,
    );
  }

  /// Importa um arquivo local escolhido pelo usuário.
  Future<FogoEngine?> loadFile(
    String path, {
    void Function(String phase, int count, double fraction)? onProgress,
  }) async {
    final bytes = await File(path).readAsBytes();
    return loadBytes(bytes, onProgress: onProgress);
  }

  Future<FogoEngine?> loadBytes(
    Uint8List bytes, {
    void Function(String phase, int count, double fraction)? onProgress,
  }) {
    return _controller.load(bytes, onProgress: onProgress);
  }
}
