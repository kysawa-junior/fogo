import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/design_system/fogo_colors.dart';
import '../../../../core/design_system/fogo_spacing.dart';
import '../../../../core/design_system/widgets/fogo_chips.dart';
import '../../../../core/design_system/widgets/fogo_chip.dart';
import '../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../core/theme/fogo_typography.dart';
import '../../domain/road_filter.dart';
import '../../providers/layers_provider.dart';

/// Controle de camadas da base real e filtros de vias que afetam o mapa.
class LayersPanel extends ConsumerStatefulWidget {
  const LayersPanel({super.key});

  @override
  ConsumerState<LayersPanel> createState() => _LayersPanelState();
}

class _LayersPanelState extends ConsumerState<LayersPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return FogoIconButton(
        icon: LucideIcons.layers,
        iconColor: FogoColors.accent,
        onTap: () => setState(() => _expanded = true),
      );
    }

    final Set<MapLayerId> active = ref.watch(layersProvider);

    return FogoPanel(
      width: 282,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Camadas', style: FogoText.subtitle)),
              FogoIconButton(
                icon: LucideIcons.chevron_up,
                size: 22,
                iconSize: 13,
                onTap: () => setState(() => _expanded = false),
              ),
            ],
          ),
          const SizedBox(height: FogoSpacing.sm),
          for (final LayerSpec spec in kLayerSpecs)
            _LayerRow(
              spec: spec,
              active: active.contains(spec.id),
              onToggle: spec.available
                  ? () => ref.read(layersProvider.notifier).toggle(spec.id)
                  : null,
            ),
          _sectionLabel('Vias por classe'),
          FogoToggleChips<RoadFilterGroup>(
            values: RoadFilterGroup.values.map((g) => (g, g.label)).toList(),
            selected: ref.watch(roadFilterProvider),
            onToggled: (value, _) =>
                ref.read(roadFilterProvider.notifier).toggle(value),
          ),
          const SizedBox(height: FogoSpacing.md),
          Text(
            'Sem seleção = todas as classes visíveis. '
            'Camadas indisponíveis aguardam fonte de dados real.',
            style: FogoText.micro,
          ),
        ],
      ),
    );
  }

  static Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: FogoSpacing.md, bottom: FogoSpacing.xs),
    child: Text(text, style: FogoText.caption),
  );
}

class _LayerRow extends StatefulWidget {
  const _LayerRow({
    required this.spec,
    required this.active,
    required this.onToggle,
  });

  final LayerSpec spec;
  final bool active;
  final VoidCallback? onToggle;

  @override
  State<_LayerRow> createState() => _LayerRowState();
}

class _LayerRowState extends State<_LayerRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool available = widget.spec.available;
    return MouseRegion(
      cursor: available ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: Opacity(
          opacity: available ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: widget.active
                        ? FogoColors.accent
                        : (_hover && available
                              ? FogoColors.surfaceHover
                              : FogoColors.transparent),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: widget.active
                          ? FogoColors.accent
                          : FogoColors.borderStrong,
                    ),
                  ),
                  child: widget.active
                      ? const Icon(
                          LucideIcons.check,
                          size: 11,
                          color: FogoColors.onAccent,
                        )
                      : null,
                ),
                const SizedBox(width: FogoSpacing.sm),
                Expanded(
                  child: Text(
                    widget.spec.label,
                    style: FogoText.body.copyWith(fontSize: 12.5),
                  ),
                ),
                if (!available)
                  const FogoChip(
                    label: 'sem fonte',
                    color: FogoColors.statusOffline,
                    showDot: false,
                    outlined: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
