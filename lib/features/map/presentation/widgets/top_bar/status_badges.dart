part of 'top_bar.dart';

/// Estado do motor 3D: label + cor para o chip do header.
(String, Color) _engineStatusPresentation(MapEngineState state) {
  final (String label, Color color) = switch (state.phase) {
    MapIdle() => ('sem base', FogoColors.statusOffline),
    MapLoading(:final label, :final count) => (
      'importando · $label $count',
      FogoColors.statusAttention,
    ),
    // base-design.pen: chip "● base OSM" quando a carga terminou.
    MapReady() => ('base OSM', FogoColors.statusNormal),
    MapError() => ('erro na importação', FogoColors.statusCritical),
  };
  return (label, color);
}

/// Chip "● base OSM" do header (base-design.pen): fundo #01010e, raio 8,
/// padding 6/10, ponto 5px, rótulo 11/500 secundário.
class _MapStatusBadge extends StatelessWidget {
  const _MapStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FogoColors.surfaceCard,
        borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: FogoColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
