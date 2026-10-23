/// Top bar library: navigation items and the status badge live in sibling
/// parts; the bar itself composes them here.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design_system/fogo_colors.dart';
import '../../../../../core/design_system/fogo_spacing.dart';
import '../../../../../core/design_system/widgets/fogo_text_field.dart';
import '../../../data/geocoding_service.dart' show GeoSearchResult;
import '../../../providers/map_engine_providers.dart';
import '../../../providers/search_provider.dart';

part 'nav_item.dart';
part 'status_badges.dart';

/// Módulo ativo exibido na barra (define o item em destaque).
enum FogoModule { operations, inventory, predictive }

/// Barra flutuante de navegação: módulos, busca geográfica real e estado
/// do motor cartográfico 3D. A identidade F.O.G.O. vive no title bar do
/// sistema — não aqui (ver base-design.pen).
class TopBar extends ConsumerStatefulWidget {
  const TopBar({
    super.key,
    required this.activeModule,
    required this.engineState,
    required this.onSelectResult,
  });

  final FogoModule activeModule;
  final MapEngineState engineState;
  final void Function(GeoSearchResult) onSelectResult;

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
    final (String statusLabel, Color statusColor) = _engineStatusPresentation(
      widget.engineState,
    );

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

          // Busca geográfica real (Nominatim/OSM) — foca a câmera 3D.
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: FogoTextField(
                hint: 'Buscar endereço, via, cidade…',
                controller: _searchController,
                fill: FogoColors.surfaceCard,
                onChanged: (q) => ref.read(searchQueryProvider.notifier).set(q),
                onSubmitted: (_) => _selectFirst(),
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(width: FogoSpacing.md),

          // Estado do motor (base carregada).
          _MapStatusBadge(label: statusLabel, color: statusColor),
        ],
      ),
    );
  }
}
