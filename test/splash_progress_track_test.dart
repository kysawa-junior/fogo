import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fogo/app/boot/splash_brand_panel.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preenchimento cresce e fica ancorado à esquerda', (tester) async {
    final int quarter = await _fillWidth(tester, 0.25);
    final int threeQuarters = await _fillWidth(tester, 0.75);

    expect(quarter, greaterThan(0));
    // 25% de 100px: o preenchimento para antes da metade (ancorado à
    // esquerda — não desliza) e cresce quando a fração sobe.
    expect(quarter, lessThan(40));
    expect(threeQuarters, greaterThan(60));
  });
}

/// Largura (em px) do preenchimento ciano da trilha de 100px.
Future<int> _fillWidth(WidgetTester tester, double value) async {
  final GlobalKey key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 100,
            height: 10,
            child: SplashProgressTrack(value: value),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final RenderRepaintBoundary boundary =
      tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
  final ByteData? data = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 1);
    return image.toByteData(format: ui.ImageByteFormat.rawRgba);
  });
  expect(data, isNotNull);

  int last = -1;
  for (int y = 0; y < 10; y++) {
    for (int x = 0; x < 100; x++) {
      final int i = (y * 100 + x) * 4;
      // Ciano (0xFF0FC3FF): azul muito acima do vermelho.
      if (data!.getUint8(i + 2) > data.getUint8(i) + 40) last = x;
    }
  }
  return last;
}
