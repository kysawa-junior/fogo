part of 'proposal_form_panel.dart';

/// Numeric change field (speed limit / lanes) showing the current value.
class _ProposalValueField extends StatelessWidget {
  const _ProposalValueField({
    required this.label,
    required this.current,
    required this.controller,
    required this.errorText,
  });

  final String label;
  final String current;
  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Valor atual: $current', style: FogoText.caption),
        const SizedBox(height: FogoSpacing.xs),
        FogoTextField(
          label: label,
          hint: 'Informe o valor',
          controller: controller,
          digitsOnly: true,
          errorText: errorText,
          width: double.infinity,
        ),
      ],
    );
  }
}
