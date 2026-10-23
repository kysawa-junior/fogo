import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../../engine/fogo_engine.dart';

/// Executa o pipeline do motor (parse OSM + geometria) em um isolate
/// dedicado, com progresso e cancelamento. A thread principal nunca é
/// bloqueada por arquivos grandes.
class OsmLoadController {
  Isolate? _isolate;
  Completer<FogoEngine?>? _pending;
  bool _running = false;

  bool get isRunning => _running;

  /// Carrega bytes `.osm`/`.osm.gz`. Completes com o motor pronto, null
  /// (cancelado ou sem conteúdo) ou erro.
  Future<FogoEngine?> load(
    Uint8List bytes, {
    void Function(String phase, int count)? onProgress,
  }) {
    if (_running) {
      throw StateError('Importação já em andamento.');
    }
    _running = true;

    final completer = Completer<FogoEngine?>();
    _pending = completer;
    final progressPort = ReceivePort();
    final errorPort = ReceivePort();

    void onDone() {
      progressPort.close();
      errorPort.close();
      _running = false;
      _isolate = null;
      _pending = null;
    }

    progressPort.listen((message) {
      if (message is List && message.length == 3 && message[0] == 'progress') {
        onProgress?.call(message[1] as String, message[2] as int);
      } else if (message is List &&
          message.length == 2 &&
          message[0] == 'result') {
        onDone();
        completer.complete(message[1] as FogoEngine?);
      } else if (message is List &&
          message.length >= 2 &&
          message[0] == 'error') {
        onDone();
        completer.completeError(
          StateError('Falha na importação: ${message[1]}'),
        );
      }
    });

    errorPort.listen((_) {});

    Isolate.spawn(_engineEntry, [progressPort.sendPort, bytes])
        .then((isolate) {
          _isolate = isolate;
          // Cancelado enquanto o isolate subia: encerra imediatamente.
          if (!completer.isCompleted && _pending != completer) {
            _finishCancelled(completer);
            isolate.kill(priority: Isolate.immediate);
          }
        })
        .catchError((Object error) {
          onDone();
          if (!completer.isCompleted) completer.completeError(error);
        });

    return completer.future;
  }

  void _finishCancelled(Completer<FogoEngine?> completer) {
    _running = false;
    _isolate = null;
    _pending = null;
    if (!completer.isCompleted) completer.complete(null);
  }

  /// Cancela a importação em andamento (isolate encerrado, future
  /// completa com null).
  void cancel() {
    final isolate = _isolate;
    final pending = _pending;
    if (isolate != null && pending != null) {
      _finishCancelled(pending);
      isolate.kill(priority: Isolate.immediate);
    } else if (pending != null) {
      _finishCancelled(pending);
    }
  }

  /// Entry point do isolate: pipeline puro do motor.
  static void _engineEntry(List<Object> args) {
    final SendPort sendPort = args[0] as SendPort;
    final Uint8List bytes = args[1] as Uint8List;
    try {
      final engine = FogoEngine.build(
        bytes,
        onProgress: (phase, count) => sendPort.send(['progress', phase, count]),
      );
      if (engine == null) {
        sendPort.send([
          'error',
          'Arquivo OSM sem nós utilizáveis (vazio, corrompido ou formato '
              'inesperado).',
        ]);
        return;
      }
      sendPort.send(['result', engine]);
    } catch (error) {
      sendPort.send(['error', '$error']);
    }
  }
}
