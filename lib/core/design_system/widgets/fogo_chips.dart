import 'package:flutter/widgets.dart';

import '../fogo_colors.dart';
import '../fogo_spacing.dart';

typedef FogoChipValue<T> = (T value, String label);

/// Chips de seleção única (formulários de enum).
class FogoChoiceChips<T> extends StatelessWidget {
  const FogoChoiceChips({
    super.key,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<FogoChipValue<T>> values;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) =>
      _build(values, (v) => v == selected, (v) => onSelected(v));
}

/// Chips de alternância múltipla (filtros).
class FogoToggleChips<T> extends StatelessWidget {
  const FogoToggleChips({
    super.key,
    required this.values,
    required this.selected,
    required this.onToggled,
  });

  final List<FogoChipValue<T>> values;
  final Set<T> selected;
  final void Function(T value, bool nowSelected) onToggled;

  @override
  Widget build(BuildContext context) => _build(
    values,
    (v) => selected.contains(v),
    (v) => onToggled(v, !selected.contains(v)),
  );
}

Widget _build<T>(
  List<FogoChipValue<T>> values,
  bool Function(T) isSelected,
  ValueChanged<T> onTap,
) {
  return Wrap(
    spacing: FogoSpacing.sm,
    runSpacing: FogoSpacing.sm,
    children: [
      for (final (value, label) in values)
        _Chip(
          label: label,
          selected: isSelected(value),
          onTap: () => onTap(value),
        ),
    ],
  );
}

class _Chip extends StatefulWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected
                ? FogoColors.accentSoft
                : _hover
                ? FogoColors.surfaceHover
                : FogoColors.surfaceRaised,
            borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
            border: Border.all(
              color: widget.selected ? FogoColors.accent : FogoColors.border,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              height: 1,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
              color: widget.selected
                  ? FogoColors.textPrimary
                  : FogoColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
