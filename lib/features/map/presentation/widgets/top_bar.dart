import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:fogo_map_sdk/fogo_map_sdk.dart'
    show FogoMapDataPhase, FogoMapDataStatus;

import '../../../../core/design_system/fogo_colors.dart';
import '../../../../core/design_system/fogo_spacing.dart';
import '../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../core/design_system/widgets/fogo_text_field.dart';
import '../../data/geocoding_service.dart' show GeoSearchResult;
import '../../providers/search_provider.dart';
import '../../providers/workspace_providers.dart';
import '../../../road/domain/road_change_proposal.dart';
import '../../../road/providers/proposals_provider.dart';

/// Módulo ativo exibido na barra (define o item em destaque).
enum FogoModule { operations, inventory, predictive }

/// Barra flutuante de navegação: módulos, busca geográfica real, rotas,
/// propostas e estado da base cartográfica. A identidade F.O.G.O. vive no
/// title bar do sistema — não aqui (ver base-design.pen).
class TopBar extends ConsumerStatefulWidget {
  const TopBar({
    super.key,
    required this.activeModule,
    required this.onSelectResult,
    required this.mapStatus,
  });

  final FogoModule activeModule;
  final void Function(GeoSearchResult) onSelectResult;
  final FogoMapDataStatus mapStatus;

  @override
  ConsumerState<TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<TopBar> {
  late final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectFirst() {
    final SearchState search = ref.read(searchQueryProvider);
    if (search.results.isNotEmpty) widget.onSelectResult(search.results.first);
  }

  @override
  Widget build(BuildContext context) {
    final int pending = ref
        .watch(proposalsProvider)
        .where((p) => p.status == ProposalStatus.pendingReview)
        .length;
    final FogoMapDataStatus status = widget.mapStatus;
    final bool loading = status.phase == FogoMapDataPhase.loading;
    final bool outsideCoverage =
        status.phase == FogoMapDataPhase.outsideCoverage;
    final bool hasError = status.phase == FogoMapDataPhase.error;
    final String mapStatusLabel = loading
        ? 'OSM local carregando'
        : outsideCoverage
        ? 'fora da cobertura'
        : hasError
        ? 'erro na base OSM'
        : status.hasErrors
        ? 'OSM local · parcial'
        : 'OSM local';
    final Color mapStatusColor = loading
        ? FogoColors.statusAttention
        : outsideCoverage || hasError
        ? FogoColors.statusOffline
        : FogoColors.statusNormal;

    return Container(
      height: FogoSpacing.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: FogoSpacing.lg),
      child: Row(
        children: [
          // Módulos
          _NavItem(
            label: 'Operações',
            active: widget.activeModule == FogoModule.operations,
            onTap: () => context.go('/'),
          ),
          const SizedBox(width: FogoSpacing.xs),
          _NavItem(
            label: 'Inventário',
            active: widget.activeModule == FogoModule.inventory,
            onTap: () => context.go('/inventory'),
          ),
          const SizedBox(width: FogoSpacing.xs),
          _NavItem(
            label: 'Cidade Preditiva',
            active: widget.activeModule == FogoModule.predictive,
            onTap: () => context.go('/predictive'),
          ),

          const Spacer(),

          // Busca geográfica real (Nominatim/OSM) — flexível para caber
          // em janelas estreitas (mínimo do app: 960px).
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: FogoTextField(
                hint: 'Buscar endereço, hidrante, via…',
                controller: _searchController,
                fill: FogoColors.surfaceCard,
                onChanged: (q) => ref.read(searchQueryProvider.notifier).set(q),
                onSubmitted: (_) => _selectFirst(),
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(width: FogoSpacing.md),

          // Rotas e otimização
          FogoIconButton(
            icon: LucideIcons.route,
            onTap: () => ref.read(sidePanelProvider.notifier).openRouting(),
          ),
          const SizedBox(width: FogoSpacing.md),

          // Propostas de alteração viária (módulo dormente)
          SizedBox(
            width: FogoSpacing.iconButtonSize,
            height: FogoSpacing.iconButtonSize,
            child: Stack(
              children: [
                Center(
                  child: FogoIconButton(
                    icon: LucideIcons.clipboard_list,
                    onTap: () =>
                        ref.read(sidePanelProvider.notifier).openProposals(),
                  ),
                ),
                if (pending > 0)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: FogoColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pending',
                        style: const TextStyle(
                          fontSize: 8,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: FogoColors.onAccent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: FogoSpacing.md),

          // Divisor e estado da cobertura OSM local.
          Container(width: 1, height: 18, color: FogoColors.borderSubtle),
          const SizedBox(width: FogoSpacing.md),
          Container(
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
                  decoration: BoxDecoration(
                    color: mapStatusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  mapStatusLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: FogoColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.active
        ? FogoColors.textPrimary
        : (_hover ? FogoColors.textPrimary : FogoColors.textSecondary);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.active
                ? FogoColors.activeSurface
                : FogoColors.transparent,
            borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              height: 1,
              fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
