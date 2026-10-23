part of 'top_bar.dart';

/// Estado do motor 3D: label + cor para o badge da barra.
(String, Color) _engineStatusPresentation(MapEngineState state) {
  final (String label, Color color) = switch (state.phase) {
    MapIdle() => ('motor 3D · sem base', FogoColors.statusOffline),
    MapLoading(:final label, :final count) => (
      'importando OSM · $label $count',
      FogoColors.statusAttention,
    ),
    MapReady() => (
      state.activeCityId.isEmpty
          ? 'OSM 3D · ${state.sourceLabel}'
          : 'OSM 3D · ${state.sourceLabel}',
      FogoColors.statusNormal,
    ),
    MapError() => ('erro na importação', FogoColors.statusCritical),
  };
  return (label, color);
}

/// Small pill showing the engine state with a status dot.
class _MapStatusBadge extends StatelessWidget {
  const _MapStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FogoColors.overlayFaint,
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
