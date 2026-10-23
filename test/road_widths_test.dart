import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:fogo/core/utils/geo_utils.dart';
import 'package:fogo/features/map/vector/road_widths.dart';
import 'package:fogo/features/map/vector/vector_data/vector_data.dart';
import 'package:fogo/features/map/vector/vector_painter.dart';

/// RoadWidths: tabela de larguras por classe (Regra de Ouro) e a
/// conversão m/px usada pelo pipeline.
void main() {
  group('RoadWidths — tabela do spec com clamp (Regra de Ouro)', () {
    test(
      'tabela por zoom: principais e secundárias nos intervalos pedidos',
      () {
        // z<=14: principais 2-3px, secundárias ~1px
        expect(RoadWidths.width(RoadClass.primary, 14), inInclusiveRange(2, 3));
        expect(
          RoadWidths.width(RoadClass.residential, 14),
          lessThanOrEqualTo(1.2),
        );
        // z15: principais 4-6, secundárias 2-3
        expect(RoadWidths.width(RoadClass.primary, 15), inInclusiveRange(4, 6));
        expect(
          RoadWidths.width(RoadClass.residential, 15),
          inInclusiveRange(2, 3),
        );
        // z16: principais 8-12, secundárias 4-6
        expect(
          RoadWidths.width(RoadClass.motorway, 16),
          inInclusiveRange(8, 12),
        );
        expect(
          RoadWidths.width(RoadClass.primary, 16),
          inInclusiveRange(8, 12),
        );
        expect(
          RoadWidths.width(RoadClass.secondary, 16),
          inInclusiveRange(4, 6),
        );
        expect(
          RoadWidths.width(RoadClass.residential, 16),
          inInclusiveRange(4, 6),
        );
        // z17: principais 14-18, secundárias 8-12
        expect(
          RoadWidths.width(RoadClass.motorway, 17),
          inInclusiveRange(14, 18),
        );
        expect(
          RoadWidths.width(RoadClass.primary, 17),
          inInclusiveRange(14, 18),
        );
        expect(
          RoadWidths.width(RoadClass.residential, 17),
          inInclusiveRange(8, 12),
        );
      },
    );

    test(
      'REGRA DE OURO: nenhuma via ultrapassa o máximo da classe (z>=18)',
      () {
        for (double z = 18; z <= 21; z += 0.5) {
          for (final RoadClass cls in RoadClass.values) {
            expect(
              RoadWidths.width(cls, z),
              lessThanOrEqualTo(RoadWidths.maxAllowed(cls)),
              reason: '$cls em z$z passou do clamp',
            );
          }
        }
        expect(RoadWidths.width(RoadClass.motorway, 19), 22);
        expect(RoadWidths.width(RoadClass.residential, 19), 14);
      },
    );

    test(
      'hierarquia em todos os zooms (secundária >= residencial no clamp)',
      () {
        for (double z = 8; z <= 19; z += 1) {
          expect(
            RoadWidths.width(RoadClass.motorway, z),
            greaterThan(RoadWidths.width(RoadClass.primary, z)),
          );
          expect(
            RoadWidths.width(RoadClass.primary, z),
            greaterThan(RoadWidths.width(RoadClass.secondary, z)),
          );
          // no clamp z>=18 ambas são "secundárias" (máx 14) — nunca inverte
          expect(
            RoadWidths.width(RoadClass.secondary, z),
            greaterThanOrEqualTo(RoadWidths.width(RoadClass.residential, z)),
          );
          expect(
            RoadWidths.width(RoadClass.residential, z),
            greaterThan(RoadWidths.width(RoadClass.service, z)),
          );
        }
      },
    );

    test('monotônica e suave por zoom (sem degraus bruscos)', () {
      for (final RoadClass cls in RoadClass.values) {
        double prev = RoadWidths.width(cls, 7);
        for (double z = 7.25; z <= 19; z += 0.25) {
          final double w = RoadWidths.width(cls, z);
          expect(w, greaterThan(prev - 0.001));
          expect(w - prev, lessThan(3.0), reason: '$cls degrau brusco em z$z');
          prev = w;
        }
      }
    });

    test('largura em tela permanece fixa por classe em todos os zooms', () {
      const LatLng center = LatLng(-22.2172, -49.95);
      const List<double> zooms = [7, 12, 14, 15, 16, 18, 20];
      for (final RoadClass cls in RoadClass.values) {
        final double fixedWidth = RoadWidths.width(cls, 16);
        for (final double zoom in zooms) {
          final double mpp = GeoUtils.metersPerPixel(center, zoom);
          final double fillPixels =
              RoadWidths.halfFillMeters(cls, zoom, mpp) * 2 / mpp;
          final double casingPixels =
              RoadWidths.halfCasingMeters(cls, zoom, mpp) * 2 / mpp;

          expect(
            fillPixels,
            closeTo(fixedWidth, 1e-9),
            reason: '$cls varia em z$zoom',
          );
          expect(
            casingPixels,
            closeTo(fixedWidth + 2.4, 1e-9),
            reason: 'casing de $cls varia em z$zoom',
          );
        }
      }
      expect(
        RoadWidths.width(RoadClass.residential, 12),
        lessThan(RoadWidths.width(RoadClass.residential, 16)),
        reason: 'perfil adaptativo usado por ferrovias permanece intacto',
      );
    });

    test('limites de visibilidade das classes permanecem estáveis', () {
      const List<(RoadClass, double)> thresholds = [
        (RoadClass.primary, 7.5),
        (RoadClass.secondary, 9),
        (RoadClass.tertiary, 11.5),
        (RoadClass.unclassified, 11.5),
        (RoadClass.residential, 11.5),
        (RoadClass.track, 13),
        (RoadClass.other, 14),
        (RoadClass.service, 14.5),
        (RoadClass.path, 16),
      ];
      for (final (RoadClass cls, double threshold) in thresholds) {
        expect(
          FogoVectorPainter.isRoadClassVisible(cls, threshold - 0.01),
          isFalse,
          reason: '$cls aparece antes do limite z$threshold',
        );
        expect(
          FogoVectorPainter.isRoadClassVisible(cls, threshold),
          isTrue,
          reason: '$cls não aparece no limite z$threshold',
        );
      }
      for (final RoadClass cls in [RoadClass.motorway, RoadClass.trunk]) {
        expect(FogoVectorPainter.isRoadClassVisible(cls, 0), isTrue);
      }
    });
  });

  test('sanidade: m/px decresce com zoom (conversão consistente)', () {
    const LatLng c = LatLng(-22.2172, -49.95);
    expect(
      GeoUtils.metersPerPixel(c, 16),
      lessThan(GeoUtils.metersPerPixel(c, 14)),
    );
  });
}
