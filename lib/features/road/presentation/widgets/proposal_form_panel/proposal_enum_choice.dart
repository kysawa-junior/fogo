part of 'proposal_form_panel.dart';

/// Enum change field (direction / operational status) showing the current
/// value and offering one chip per enum value.
class _ProposalEnumChoice<T> extends StatelessWidget {
  const _ProposalEnumChoice({
    required this.label,
    required this.current,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String current;
  final List<(T, String)> values;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Valor atual: $current', style: FogoText.caption),
        const SizedBox(height: FogoSpacing.xs),
        Text(label, style: FogoText.caption),
        const SizedBox(height: FogoSpacing.xs),
        FogoChoiceChips<T>(
          values: values,
          selected: selected,
          onSelected: onSelected,
        ),
      ],
    );
  }
}
