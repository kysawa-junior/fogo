import 'package:flutter/widgets.dart';

import '../../../../core/design_system/fogo_colors.dart';
import '../../../../core/design_system/fogo_spacing.dart';

/// Atalhos de enquadramento: região completa, Marília e Garça.
/// O atalho em foco fica destacado (ver base-design.pen).
class RegionControls extends StatefulWidget {
  const RegionControls({
    super.key,
    required this.onRegion,
    required this.onMarilia,
    required this.onGarca,
  });

  final VoidCallback onRegion;
  final VoidCallback onMarilia;
  final VoidCallback onGarca;

  @override
  State<RegionControls> createState() => _RegionControlsState();
}

class _RegionControlsState extends State<RegionControls> {
  String _selected = 'marilia';

  void _select(String id, VoidCallback action) {
    setState(() => _selected = id);
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CityChip(
            label: 'Região',
            selected: _selected == 'regiao',
            onTap: () => _select('regiao', widget.onRegion),
          ),
          const SizedBox(width: FogoSpacing.xs),
          _CityChip(
            label: 'Marília',
            selected: _selected == 'marilia',
            onTap: () => _select('marilia', widget.onMarilia),
          ),
          const SizedBox(width: FogoSpacing.xs),
          _CityChip(
            label: 'Garça',
            selected: _selected == 'garca',
            onTap: () => _select('garca', widget.onGarca),
          ),
        ],
      ),
    );
  }
}

class _CityChip extends StatefulWidget {
  const _CityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CityChip> createState() => _CityChipState();
}

class _CityChipState extends State<_CityChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.selected
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
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: widget.selected
                ? FogoColors.activeSurface
                : FogoColors.transparent,
            borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
            boxShadow: widget.selected
                ? const [
                    BoxShadow(
                      color: FogoColors.accentSoft,
                      offset: Offset(0, 0),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                height: 1,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
