import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'package:fogo/app/fogo_app.dart';
import 'package:fogo/app/router/app_router.dart';
import 'package:fogo/app/window_close_handler.dart';
import 'package:fogo/core/design_system/widgets/fogo_titlebar/fogo_titlebar.dart';
import 'package:fogo/main.dart' as app;

const MethodChannel _windowManagerChannel = MethodChannel('window_manager');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final List<String> windowManagerCalls = [];

  setUp(() {
    windowManagerCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, (call) async {
          windowManagerCalls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowManagerChannel, null);
  });

  for (final TargetPlatform platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    testWidgets('startup skips window_manager on $platform', (tester) async {
      await _runOnPlatform(platform, () async {
        tester.view
          ..physicalSize = const Size(1440, 900)
          ..devicePixelRatio = 1;
        try {
          SharedPreferences.setMockInitialValues({});
          AppRouter.config.go('/predictive');

          await app.main();

          expect(windowManagerCalls, isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          tester.view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
        }
      });
    });

    testWidgets(
      'app shell omits desktop titlebar and close handler on $platform',
      (tester) async {
        await _runOnPlatform(platform, () async {
          AppRouter.config.go('/predictive');

          await tester.pumpWidget(const ProviderScope(child: FogoApp()));
          await tester.pumpAndSettle();

          expect(find.byType(FogoTitlebar), findsNothing);
          expect(find.byType(WindowCloseHandler), findsNothing);
          expect(windowManagerCalls, isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      },
    );

    testWidgets(
      'titlebar and close lifecycle never call window_manager on $platform',
      (tester) async {
        await _runOnPlatform(platform, () async {
          await tester.pumpWidget(
            const Directionality(
              textDirection: TextDirection.ltr,
              child: FogoTitlebar(),
            ),
          );
          expect(isDesktopWindowPlatform, isFalse);
          expect(find.byType(CustomPaint), findsNothing);
          expect(windowManager.hasListeners, isFalse);

          await tester.pumpWidget(
            const WindowCloseHandler(child: SizedBox.shrink()),
          );
          expect(windowManager.hasListeners, isFalse);
          await closeApplication();
          expect(windowManagerCalls, isEmpty);

          await tester.pumpWidget(const SizedBox.shrink());
          expect(windowManager.hasListeners, isFalse);
        });
      },
    );
  }

  testWidgets('desktop close listener attaches and detaches with lifecycle', (
    tester,
  ) async {
    await _runOnPlatform(TargetPlatform.macOS, () async {
      await tester.pumpWidget(
        const WindowCloseHandler(child: SizedBox.shrink()),
      );
      expect(isDesktopWindowPlatform, isTrue);
      expect(windowManager.hasListeners, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(windowManager.hasListeners, isFalse);
    });
  });

  testWidgets('desktop titlebar retains controls and their window action', (
    tester,
  ) async {
    await _runOnPlatform(TargetPlatform.windows, () async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FogoTitlebar(),
        ),
      );

      expect(find.byType(CustomPaint), findsNWidgets(3));
      await tester.tap(find.byType(CustomPaint).first);
      expect(windowManagerCalls, ['minimize']);
    });
  });
}

Future<void> _runOnPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}
