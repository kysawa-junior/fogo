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
    this.prefix,
    this.suffix,
    this.bordered = true,
    this.radius,
    this.height,
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

  /// Elemento à direita do campo (base-design.pen: atalho "⌘K" da busca).
  final Widget? suffix;

  /// Elemento à esquerda do campo (base-design.pen: lupa da busca do
  /// rodapé).
  final Widget? prefix;

  /// O design usa campos sem contorno (busca do header); formulários
  /// densos mantêm a borda para feedback de foco.
  final bool bordered;

  /// Raio dos cantos — null usa `radiusSm`; a busca do header usa 9.
  final double? radius;

  /// Altura fixa do campo de uma linha — null usa `controlHeight`
  /// (base-design.pen: busca do rodapé usa 40).
  final double? height;

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
    final double effectiveRadius = widget.radius ?? FogoSpacing.radiusSm;
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
            // Campo de busca: altura fixa (padrão 34, busca do rodapé
            // 40 — base-design.pen). Campos multilinha crescem.
            height: widget.maxLines > 1
                ? null
                : (widget.height ?? FogoSpacing.controlHeight),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: widget.bordered ? 8 : 0,
            ),
            decoration: BoxDecoration(
              color: widget.fill,
              borderRadius: BorderRadius.circular(effectiveRadius),
              border: widget.bordered ? Border.all(color: border) : null,
            ),
            child: Row(
              children: [
                if (widget.prefix != null) ...[
                  widget.prefix!,
                  const SizedBox(width: FogoSpacing.sm),
                ],
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Placeholder (EditableText não o tem por padrão).
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.controller,
                        builder: (_, value, _) {
                          if (value.text.isNotEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            widget.hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FogoText.caption.copyWith(
                              color: FogoColors.textTertiary,
                            ),
                          );
                        },
                      ),
                      EditableText(
                        controller: widget.controller,
                        focusNode: _focus,
                        style: FogoText.body,
                        cursorColor: FogoColors.accent,
                        selectionColor: FogoColors.accent.withValues(
                          alpha: 0.35,
                        ),
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
                    ],
                  ),
                ),
                if (widget.suffix != null) ...[
                  const SizedBox(width: FogoSpacing.sm),
                  widget.suffix!,
                ],
              ],
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
