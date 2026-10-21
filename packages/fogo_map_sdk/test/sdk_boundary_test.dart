import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'SDK runtime sources do not import app, IO, plugin, network, or map APIs',
    () {
      final Directory library = Directory('lib');
      expect(library.existsSync(), isTrue);
      final List<File> dartFiles = library
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();
      expect(dartFiles, isNotEmpty);

      final RegExp forbiddenImports = RegExp(
        r'''(?:import|export)\s+['"](?:dart:io|package:(?:flutter_map|flutter_riverpod|go_router|http|latlong2|fogo/|fogo\.[^/]))''',
      );
      for (final File file in dartFiles) {
        final String source = file.readAsStringSync();
        expect(
          source,
          isNot(contains(forbiddenImports)),
          reason: '${file.path} crosses the portable package boundary',
        );
        expect(source, isNot(contains('MethodChannel')));
        expect(source, isNot(contains('EventChannel')));
      }

      final String packageSpec = File('pubspec.yaml').readAsStringSync();
      final String runtimeDependencies = packageSpec
          .split('dev_dependencies:')
          .first;
      for (final String forbidden in [
        'flutter_map:',
        'flutter_riverpod:',
        'go_router:',
        'http:',
        'latlong2:',
        'fogo:',
      ]) {
        expect(
          runtimeDependencies,
          isNot(contains(forbidden)),
          reason:
              'runtime dependency $forbidden is app-specific or platform-bound',
        );
      }
    },
  );
}
