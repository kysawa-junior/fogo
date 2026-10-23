part of 'map_3d_page.dart';

/// Painel de fontes cartográficas: cidades do catálogo regional
/// (extratos OSM empacotados), importação de arquivo `.osm` do usuário,
/// cancelamento e avisos de importação.
class _SourcePanel extends ConsumerWidget {
  const _SourcePanel({required this.onImport});

  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mapEngineProvider);
    final bool loading = state.phase is MapLoading;
    final bool ready = state.phase is MapReady;

    return FogoPanel(
      width: 232,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Base cartográfica 3D', style: FogoText.title),
          const SizedBox(height: FogoSpacing.xs),
          const Text(
            'Motor próprio F.O.G.O. · Flutter Scene',
            style: TextStyle(fontSize: 10, color: FogoColors.textSecondary),
          ),
          const SizedBox(height: FogoSpacing.lg),
          for (final city in RegionCatalog.cities) ...[
            _CityButton(
              city: city,
              active: state.activeCityId == city.id,
              enabled: !loading,
              onTap: () => ref.read(mapEngineProvider.notifier).loadCity(city),
            ),
            const SizedBox(height: FogoSpacing.xs),
          ],
          const SizedBox(height: FogoSpacing.sm),
          FogoButton(
            label: 'Importar arquivo .osm…',
            variant: FogoButtonVariant.primary,
            onTap: loading ? null : onImport,
          ),
          if (loading) ...[
            const SizedBox(height: FogoSpacing.md),
            _LoadingIndicator(state: state),
          ],
          if (state.phase is MapError) ...[
            const SizedBox(height: FogoSpacing.md),
            Text(
              (state.phase as MapError).message,
              style: const TextStyle(
                fontSize: 11,
                color: FogoColors.statusCritical,
              ),
            ),
          ],
          if (ready && state.sourceLabel.isNotEmpty) ...[
            const SizedBox(height: FogoSpacing.md),
            Text(
              'Carregado: ${state.sourceLabel}',
              style: const TextStyle(
                fontSize: 11,
                color: FogoColors.textSecondary,
              ),
            ),
          ],
          if (ready && state.issues.isNotEmpty) ...[
            const SizedBox(height: FogoSpacing.xs),
            Text(
              '${state.issues.length}+ avisos de importação '
              '(refs ausentes/geom. inválida)',
              style: const TextStyle(
                fontSize: 10,
                color: FogoColors.statusAttention,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CityButton extends StatelessWidget {
  const _CityButton({
    required this.city,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final MapCity city;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FogoButton(
        label: city.name,
        variant: active ? FogoButtonVariant.primary : FogoButtonVariant.ghost,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

class _LoadingIndicator extends ConsumerWidget {
  const _LoadingIndicator({required this.state});

  final MapEngineState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = state.phase;
    final label = phase is MapLoading ? phase.label : '';
    final count = phase is MapLoading ? phase.count : 0;
    return Row(
      children: [
        const FogoSpinner(),
        const SizedBox(width: FogoSpacing.sm),
        Expanded(
          child: Text(
            '$label · $count',
            style: const TextStyle(
              fontSize: 11,
              color: FogoColors.textSecondary,
            ),
          ),
        ),
        FogoIconButton(
          icon: LucideIcons.x,
          onTap: () => ref.read(mapEngineProvider.notifier).cancelLoad(),
        ),
      ],
    );
  }
}
