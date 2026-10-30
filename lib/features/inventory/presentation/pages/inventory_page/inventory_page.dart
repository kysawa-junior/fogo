import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/design_system/fogo_colors.dart';
import '../../../../../core/design_system/fogo_spacing.dart';
import '../../../../../core/design_system/widgets/fogo_button.dart';
import '../../../../../core/design_system/widgets/fogo_chip.dart';
import '../../../../../core/design_system/widgets/fogo_empty_state.dart';
import '../../../../../core/design_system/widgets/fogo_icon_button.dart';
import '../../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../../core/design_system/widgets/fogo_text_field.dart';
import '../../../../../core/theme/fogo_typography.dart';
import '../../../../map/providers/workspace_providers.dart';
import '../../../data/fogo_api_client.dart';
import '../../../domain/equipment.dart';
import '../../../domain/vehicle.dart';
import '../../../providers/equipment_provider.dart';
import '../../equipment_labels.dart';

part 'equipment_details_modal.dart';
part 'equipment_row.dart';
part 'inventory_toolbar.dart';
part 'vehicle_row.dart';

/// Largura dos cards de ativo (base-design.pen: cards compactos de 300px).
const double _cardWidth = 300;

/// Raio do card flutuante do inventário (base-design.pen: 26).
const double _inventoryCardRadius = 26;

/// Inventário Inteligente: CARD FLUTUANTE (modal) sobre o workspace — o
/// mapa continua atrás do card. O conteúdo é o catálogo do fogo-server
/// (equipamentos + viaturas) com filtro local; clicar num equipamento abre
/// o modal de detalhes (o botão "Ver no mapa" leva ao mapa).
///
/// O tamanho do card é do hospedeiro (Map3dPage): 1100×600 no
/// base-design.pen, encolhido quando a janela é menor.
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key, this.onClose});

  /// Fecha o card flutuante. Ausente = volta ao mapa pela rota '/'.
  final VoidCallback? onClose;

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  late final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// Modal de detalhes aberto (null = nenhum).
  OverlayEntry? _detailsEntry;

  /// Filtro por estado do equipamento (null = todos).
  EquipmentStatus? _statusFilter;

  @override
  void dispose() {
    _closeDetails();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Fecha o card: injeta o callback do hospedeiro ou volta ao mapa.
  void _close() {
    final VoidCallback? onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    context.go('/');
  }

  void _openOnMap(Equipment equipment) {
    ref.read(selectionProvider.notifier).selectEquipment(equipment.id);
    _close();
  }

  /// Modal de detalhes: `OverlayEntry` no overlay do Navigator (a raiz é
  /// `WidgetsApp` — nenhum helper de Material no projeto).
  void _showDetails(Equipment equipment) {
    _closeDetails();
    final OverlayState overlay = Overlay.of(context);
    late final OverlayEntry entry;
    void close() {
      if (_detailsEntry == null) return;
      _detailsEntry = null;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (context) => _EquipmentDetailsOverlay(
        equipment: equipment,
        onClose: close,
        onViewOnMap: () {
          close();
          _openOnMap(equipment);
        },
      ),
    );
    _detailsEntry = entry;
    overlay.insert(entry);
  }

  /// Fecha o modal de detalhes (idempotente).
  void _closeDetails() {
    final OverlayEntry? entry = _detailsEntry;
    _detailsEntry = null;
    entry?.remove();
  }

  void _refresh() {
    ref.invalidate(equipmentProvider);
    ref.invalidate(vehicleRegistryProvider);
  }

  /// Erro da seção (null = sem erro) — não invalida dados em cache.
  static Object? _failure(AsyncValue<dynamic> async) => switch (async) {
    AsyncError(:final error) => error,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();
    final AsyncValue<List<Equipment>> equipmentAsync = ref.watch(
      equipmentProvider,
    );
    final AsyncValue<List<Vehicle>> vehiclesAsync = ref.watch(
      vehicleRegistryProvider,
    );
    final FogoApiClient api = ref.watch(fogoApiClientProvider);

    final List<Equipment> equipments = equipmentAsync.value ?? const [];
    final List<Vehicle> vehicles = vehiclesAsync.value ?? const [];

    final List<Equipment> filteredEquipment = [
      for (final Equipment item in equipments)
        if ((query.isEmpty ||
                item.name.toLowerCase().contains(query) ||
                item.id.toLowerCase().contains(query)) &&
            (_statusFilter == null || item.status == _statusFilter))
          item,
    ];
    final List<Vehicle> filteredVehicles = [
      for (final Vehicle item in vehicles)
        if (query.isEmpty ||
            item.plate.toLowerCase().contains(query) ||
            item.id.toLowerCase().contains(query))
          item,
    ];

    // Catálogo sem nada cadastrado vs. filtro/busca sem resultado.
    final bool catalogEmpty = equipments.isEmpty && vehicles.isEmpty;
    final bool noMatch = filteredEquipment.isEmpty && filteredVehicles.isEmpty;

    // Servidor fora: erro bloqueia o card só quando NENHUMA seção tem
    // dados (as duas falham juntas — mesma origem).
    final Object? failure = _failure(equipmentAsync) ?? _failure(vehiclesAsync);
    final bool waiting =
        equipments.isEmpty &&
        vehicles.isEmpty &&
        (equipmentAsync.isLoading || vehiclesAsync.isLoading);

    // Contadores do rodapé da barra de filtros.
    final String counts = _statusFilter == null
        ? '${filteredEquipment.length} de ${equipments.length} equipamentos · '
              '${filteredVehicles.length} de ${vehicles.length} viaturas'
        : '${filteredEquipment.length} de ${equipments.length} equipamentos';

    return Container(
      decoration: BoxDecoration(
        color: FogoColors.surfaceCard,
        borderRadius: BorderRadius.circular(_inventoryCardRadius),
        boxShadow: FogoSpacing.modalShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_inventoryCardRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 30, 40, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: FogoSpacing.xl),
              // Faixa de status + filtro por estado (só quando há catálogo).
              if (equipments.isNotEmpty) ...[
                _InventoryStats(equipments: equipments),
                const SizedBox(height: FogoSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _StatusFilterBar(
                        selected: _statusFilter,
                        onSelected: (EquipmentStatus? status) =>
                            setState(() => _statusFilter = status),
                      ),
                    ),
                    const SizedBox(width: FogoSpacing.md),
                    Text(
                      counts,
                      style: FogoText.micro.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: FogoSpacing.md),
              Expanded(
                child: switch ((failure, catalogEmpty, noMatch, waiting)) {
                  (final Object error, true, _, _) => _networkError(error),
                  (_, true, _, false) => const FogoEmptyState(
                    icon: LucideIcons.database,
                    title: 'Inventário vazio',
                    message:
                        'Nenhum equipamento ou viatura cadastrado no '
                        'fogo-server. Cadastre pelo endpoint REST para vê-los '
                        'aqui.',
                  ),
                  (_, false, true, _) => const FogoEmptyState(
                    icon: LucideIcons.search_x,
                    title: 'Nenhum item encontrado',
                    message: 'Ajuste a busca ou o filtro de estado.',
                  ),
                  (_, false, false, _) => _list(
                    filteredEquipment: filteredEquipment,
                    filteredVehicles: filteredVehicles,
                  ),
                  _ => const FogoEmptyState(
                    icon: LucideIcons.loader_circle,
                    title: 'Carregando inventário…',
                    message: 'Consultando o fogo-server.',
                  ),
                },
              ),
              const SizedBox(height: FogoSpacing.md),
              Text(
                'Fonte: fogo-server (${api.baseUri}) — '
                'sobrescreva com --dart-define=FOGO_API_URL=<url>.',
                style: FogoText.micro,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cabeçalho do card: título + busca + fechar (base-design.pen
  /// "Cabeçalho da Página").
  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Inventário Inteligente',
                style: FogoText.title.copyWith(
                  fontSize: 28,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Catálogo de ativos conectados · fogo-server',
                style: FogoText.body.copyWith(
                  fontSize: 13,
                  color: FogoColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: FogoSpacing.lg),
        FogoIconButton(
          icon: LucideIcons.refresh_cw,
          onTap: _refresh,
          filled: false,
          size: 36,
          iconSize: 15,
        ),
        const SizedBox(width: FogoSpacing.sm),
        SizedBox(
          width: 360,
          child: FogoTextField(
            hint: 'Buscar por nome, id ou placa',
            controller: _searchController,
            accentColor: FogoColors.activeSurface,
            fill: FogoColors.bg,
            bordered: false,
            radius: 12,
            height: 42,
            prefix: const Icon(
              LucideIcons.search,
              size: 15,
              color: FogoColors.textTertiary,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: FogoSpacing.sm),
        FogoIconButton(
          icon: LucideIcons.x,
          onTap: _close,
          filled: false,
          size: 36,
          iconSize: 15,
        ),
      ],
    );
  }

  Widget _list({
    required List<Equipment> filteredEquipment,
    required List<Vehicle> filteredVehicles,
  }) {
    // Box simples: sem fundo — o canvas do card é o fundo da lista.
    return ListView(
      controller: _scrollController,
      children: [
        // Grade de cards (Wrap): colunas emergem da largura.
        if (filteredEquipment.isNotEmpty) ...[
          _sectionHeader('Equipamentos', filteredEquipment.length),
          Wrap(
            spacing: FogoSpacing.lg,
            runSpacing: FogoSpacing.md,
            children: [
              for (final Equipment equipment in filteredEquipment)
                _EquipmentRow(
                  equipment: equipment,
                  onTap: () => _showDetails(equipment),
                ),
            ],
          ),
        ],
        // Com filtro de estado o card mostra só equipamentos — viaturas
        // ficariam sem relação com o filtro.
        if (filteredVehicles.isNotEmpty && _statusFilter == null) ...[
          _sectionHeader('Viaturas', filteredVehicles.length),
          Wrap(
            spacing: FogoSpacing.lg,
            runSpacing: FogoSpacing.md,
            children: [
              for (final Vehicle vehicle in filteredVehicles)
                _VehicleRow(vehicle: vehicle),
            ],
          ),
        ],
      ],
    );
  }

  /// Cabeçalho de seção (Equipamentos / Viaturas) com barra de acento e
  /// contador. Ciano = `activeSurface` do base-design.pen.
  Widget _sectionHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(
        top: FogoSpacing.md,
        bottom: FogoSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: FogoColors.activeSurface,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: FogoSpacing.sm),
          Text(
            label.toUpperCase(),
            style: FogoText.micro.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
              color: FogoColors.textPrimary,
            ),
          ),
          const SizedBox(width: FogoSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: FogoColors.overlayFaint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$count',
              style: FogoText.micro.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Estado de falha de rede (servidor indisponível) com retry.
  Widget _networkError(Object error) {
    return Column(
      children: [
        Expanded(
          child: FogoEmptyState(
            icon: LucideIcons.server_off,
            title: 'Não foi possível consultar o fogo-server',
            message: '$error',
          ),
        ),
        FogoIconButton(icon: LucideIcons.refresh_cw, onTap: _refresh),
      ],
    );
  }
}

/// Badge de estado do ativo (base-design.pen): ponto + rótulo na cor do
/// estado, sem borda.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
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
            style: FogoText.caption.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
