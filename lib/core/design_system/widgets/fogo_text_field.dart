import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../theme/fogo_typography.dart';
import '../fogo_colors.dart';
import '../fogo_spacing.dart';

/// Campo de texto do design system, construído sobre [EditableText]
/// (sem widgets Material).
class FogoTextField extends StatefulWidget {
  const FogoTextField({
    super.key,
    this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.maxLines = 1,
    this.minLines,
    this.digitsOnly = false,
    this.width,
    this.autofocus = false,
    this.fill = FogoColors.surfaceRaised,
  });

  final String? label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final int maxLines;
  final int? minLines;
  final bool digitsOnly;
  final double? width;
  final bool autofocus;

  /// Preenchimento do campo — o campo de busca do header usa o vidro escuro.
  final Color fill;

  @override
  State<FogoTextField> createState() => _FogoTextFieldState();
}

class _FogoTextFieldState extends State<FogoTextField> {
  late final FocusNode _focus = FocusNode(debugLabel: 'fogo_field');
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focus.requestFocus(),
      );
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = widget.errorText != null;
    final Color border = hasError
        ? FogoColors.statusCritical
        : _focused
        ? FogoColors.accent
        : FogoColors.border;
    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            Text(widget.label!, style: FogoText.caption),
            const SizedBox(height: FogoSpacing.xs),
          ],
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.fill,
              borderRadius: BorderRadius.circular(FogoSpacing.radiusSm),
              border: Border.all(color: border),
            ),
            child: EditableText(
              controller: widget.controller,
              focusNode: _focus,
              style: FogoText.body,
              cursorColor: FogoColors.accent,
              selectionColor: FogoColors.accent.withValues(alpha: 0.35),
              backgroundCursorColor: FogoColors.textDisabled,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              keyboardType: widget.maxLines > 1
                  ? TextInputType.multiline
                  : (widget.digitsOnly
                        ? const TextInputType.numberWithOptions()
                        : TextInputType.text),
              inputFormatters: widget.digitsOnly
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              textInputAction: widget.maxLines > 1
                  ? TextInputAction.newline
                  : TextInputAction.search,
              // Sem menu de contexto Material; atalhos de teclado continuam funcionando.
              contextMenuBuilder: (_, _) => const SizedBox.shrink(),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: FogoSpacing.xs),
            Text(
              widget.errorText!,
              style: FogoText.caption.copyWith(
                color: FogoColors.statusCritical,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
