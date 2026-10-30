part of 'inventory_page.dart';

/// Modal de detalhes do equipamento: overlay escuro sobre a página com
/// TODAS as informações do ativo (estado, categoria, localização, via,
/// última atualização e telemetria). O card da lista é compacto — este
/// modal é o lugar de ler o resto.
class _EquipmentDetailsOverlay extends StatefulWidget {
  const _EquipmentDetailsOverlay({
    required this.equipment,
    required this.onClose,
    required this.onViewOnMap,
  });

  final Equipment equipment;
  final VoidCallback onClose;
  final VoidCallback onViewOnMap;

  @override
  State<_EquipmentDetailsOverlay> createState() =>
      _EquipmentDetailsOverlayState();
}

class _EquipmentDetailsOverlayState extends State<_EquipmentDetailsOverlay> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // ESC fecha o modal: o foco precisa estar dentro do overlay (o campo
    // de busca da página pode estar focado).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final Equipment equipment = widget.equipment;
    final Color status = equipmentStatusColor(equipment.status);
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          // Barrier: clique fora fecha o modal.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: ColoredBox(
                color: FogoColors.bg.withValues(alpha: 0.72),
              ),
            ),
          ),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: FogoMotion.fast,
              curve: FogoMotion.curve,
              builder: (context, value, child) =>
                  Opacity(opacity: value, child: child),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: FogoPanel(
                  modal: true,
                  child: _content(equipment, status),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(Equipment equipment, Color status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cabeçalho: ícone, nome, id e fechar.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: status.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
                border: Border.all(color: status.withValues(alpha: 0.35)),
              ),
              child: Icon(
                equipmentCategoryIcon(equipment.category),
                size: 19,
                color: status,
              ),
            ),
            const SizedBox(width: FogoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    equipment.name,
                    style: FogoText.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(equipment.id, style: FogoText.mono),
                ],
              ),
            ),
            FogoIconButton(icon: LucideIcons.x, onTap: widget.onClose),
          ],
        ),
        const SizedBox(height: FogoSpacing.md),
        Row(
          children: [
            FogoChip(
              label: equipmentStatusLabel(equipment.status),
              color: status,
            ),
            const SizedBox(width: FogoSpacing.sm),
            FogoChip(
              label: equipmentCategoryLabel(equipment.category),
              color: FogoColors.info,
            ),
          ],
        ),
        const SizedBox(height: FogoSpacing.lg),
        _attributes(equipment),
        const SizedBox(height: FogoSpacing.lg),
        _telemetry(equipment),
        const SizedBox(height: FogoSpacing.lg),
        // Ações.
        Row(
          children: [
            FogoButton(
              label: 'Ver no mapa',
              icon: LucideIcons.locate_fixed,
              variant: FogoButtonVariant.primary,
              height: 42,
              radius: FogoSpacing.radiusMd,
              onTap: widget.onViewOnMap,
            ),
            const SizedBox(width: FogoSpacing.sm),
            FogoButton(
              label: 'Fechar',
              variant: FogoButtonVariant.ghost,
              height: 42,
              radius: FogoSpacing.radiusMd,
              onTap: widget.onClose,
            ),
          ],
        ),
      ],
    );
  }

  /// Grade de 2 colunas com os atributos do equipamento.
  Widget _attributes(Equipment equipment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _field(
              'Categoria',
              equipmentCategoryLabel(equipment.category),
            ),
            const SizedBox(width: FogoSpacing.md),
            _field('Estado', equipmentStatusLabel(equipment.status)),
          ],
        ),
        const SizedBox(height: FogoSpacing.md),
        Row(
          children: [
            _field(
              'Localização',
              '${equipment.location.latitude.toStringAsFixed(5)}, '
              '${equipment.location.longitude.toStringAsFixed(5)}',
              mono: true,
            ),
            const SizedBox(width: FogoSpacing.md),
            _field(
              'Via associada',
              equipment.roadId ?? 'Sem via',
              mono: equipment.roadId != null,
            ),
          ],
        ),
        const SizedBox(height: FogoSpacing.md),
        Row(
          children: [
            _field('Última atualização', _lastSeen(equipment.lastSeenAt)),
            const SizedBox(width: FogoSpacing.md),
            _field(
              'Leituras',
              equipment.telemetry.isEmpty
                  ? 'Sem leituras'
                  : '${equipment.telemetry.length} campos',
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(String label, String value, {bool mono = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: FogoText.micro),
          const SizedBox(height: 2),
          Text(
            value,
            style: mono
                ? FogoText.mono.copyWith(color: FogoColors.textPrimary)
                : FogoText.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Telemetria em grade de 2 colunas (chave/valor já formatados pelo
  /// backend).
  Widget _telemetry(Equipment equipment) {
    final List<MapEntry<String, String>> entries = equipment.telemetry.entries
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TELEMETRIA', style: FogoText.micro),
        const SizedBox(height: FogoSpacing.sm),
        if (entries.isEmpty)
          Text('Sem telemetria disponível', style: FogoText.caption)
        else
          for (int i = 0; i < entries.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: FogoSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _telemetryField(entries[i])),
                  const SizedBox(width: FogoSpacing.md),
                  Expanded(
                    child: i + 1 < entries.length
                        ? _telemetryField(entries[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _telemetryField(MapEntry<String, String> entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          entry.key,
          style: FogoText.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          entry.value,
          style: FogoText.mono.copyWith(color: FogoColors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Última leitura: data absoluta + tempo relativo ("há 5 min").
  String _lastSeen(DateTime? at) {
    if (at == null) return 'Sem leitura';
    return '${_formatDate(at)} · ${_relative(DateTime.now().difference(at))}';
  }

  String _formatDate(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${two(at.year)} '
        '${two(at.hour)}:${two(at.minute)}';
  }

  String _relative(Duration diff) {
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inHours < 1) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    return 'há ${diff.inDays} d';
  }
}
