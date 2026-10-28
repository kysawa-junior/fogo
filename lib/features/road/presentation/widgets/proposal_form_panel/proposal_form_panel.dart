/// Proposal form library: the stateful form lives in this file; the reusable
/// field widgets and the success view live in sibling parts.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../core/design_system/fogo_colors.dart';
import '../../../../../core/design_system/fogo_spacing.dart';
import '../../../../../core/design_system/widgets/fogo_button.dart';
import '../../../../../core/design_system/widgets/fogo_chips.dart';
import '../../../../../core/design_system/widgets/fogo_panel.dart';
import '../../../../../core/design_system/widgets/fogo_text_field.dart';
import '../../../../../core/theme/fogo_typography.dart';
import '../../../../map/presentation/widgets/panel_header.dart';
import '../../../domain/road.dart';
import '../../../domain/road_change.dart';
import '../../../providers/proposals_provider.dart';
import '../../road_labels.dart';

part 'proposal_value_field.dart';
part 'proposal_enum_choice.dart';
part 'proposal_success_view.dart';

/// Formulário contextual de proposta de alteração viária, com validação.
class ProposalFormPanel extends ConsumerStatefulWidget {
  const ProposalFormPanel({
    super.key,
    required this.road,
    required this.onCancel,
    required this.onDone,
  });

  final Road road;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  ConsumerState<ProposalFormPanel> createState() => _ProposalFormPanelState();
}

class _ProposalFormPanelState extends ConsumerState<ProposalFormPanel> {
  ChangeKind _kind = ChangeKind.speedLimit;
  FlowDirection? _direction;
  OperationalStatus? _status;
  late final TextEditingController _valueController = TextEditingController();
  late final TextEditingController _justificationController =
      TextEditingController();
  String? _valueError;
  String? _justificationError;
  String? _createdId;

  @override
  void dispose() {
    _valueController.dispose();
    _justificationController.dispose();
    super.dispose();
  }

  bool get _needsNumericValue =>
      _kind == ChangeKind.speedLimit || _kind == ChangeKind.lanes;

  void _submitDraft() {
    final int? numeric = _needsNumericValue
        ? int.tryParse(_valueController.text.trim())
        : null;
    final String? valueError = switch (_kind) {
      ChangeKind.speedLimit => RoadChangeValidation.speedKmh(numeric),
      ChangeKind.lanes => RoadChangeValidation.lanes(numeric),
      _ => null,
    };
    final String? justificationError = RoadChangeValidation.justification(
      _justificationController.text,
    );
    final bool enumMissing = switch (_kind) {
      ChangeKind.direction => _direction == null,
      ChangeKind.status => _status == null,
      _ => false,
    };

    setState(() {
      _valueError = valueError;
      _justificationError = justificationError;
    });
    if (valueError != null ||
        justificationError != null ||
        enumMissing ||
        (_needsNumericValue && numeric == null)) {
      return;
    }

    final change = buildRoadChange(
      kind: _kind,
      road: widget.road,
      numericValue: numeric,
      direction: _direction,
      status: _status,
    );
    final String id = ref
        .read(proposalsProvider.notifier)
        .createDraft(
          roadId: widget.road.id,
          change: change,
          justification: _justificationController.text.trim(),
        );
    setState(() => _createdId = id);
  }

  void _sendToReview() {
    final notifier = ref.read(proposalsProvider.notifier);
    final bool ok = notifier.sendToReview(_createdId!);
    if (ok) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    if (_createdId != null) {
      return _ProposalSuccessView(
        createdId: _createdId!,
        onSendToReview: _sendToReview,
        onDone: widget.onDone,
      );
    }
    return FogoPanel(
      modal: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelHeader(
            icon: LucideIcons.pencil,
            title: 'Proposta de alteração viária',
            subtitle: widget.road.name,
            onClose: widget.onCancel,
          ),
          const SizedBox(height: FogoSpacing.md),
          Text('O que será alterado', style: FogoText.caption),
          const SizedBox(height: FogoSpacing.xs),
          FogoChoiceChips<ChangeKind>(
            values: const [
              (ChangeKind.speedLimit, 'Limite de velocidade'),
              (ChangeKind.lanes, 'Faixas'),
              (ChangeKind.direction, 'Sentido'),
              (ChangeKind.status, 'Estado operacional'),
            ],
            selected: _kind,
            onSelected: (kind) => setState(() => _kind = kind),
          ),
          const SizedBox(height: FogoSpacing.md),
          switch (_kind) {
            ChangeKind.speedLimit => _ProposalValueField(
              label: 'Novo limite (km/h)',
              current: '${widget.road.speedLimitKmh} km/h',
              controller: _valueController,
              errorText: _valueError,
            ),
            ChangeKind.lanes => _ProposalValueField(
              label: 'Nova quantidade de faixas',
              current: '${widget.road.lanes} faixas',
              controller: _valueController,
              errorText: _valueError,
            ),
            ChangeKind.direction => _ProposalEnumChoice<FlowDirection>(
              label: 'Novo sentido',
              current: flowDirectionLabel(widget.road.direction),
              values: FlowDirection.values
                  .map((d) => (d, flowDirectionLabel(d)))
                  .toList(),
              selected: _direction ?? widget.road.direction,
              onSelected: (d) => setState(() => _direction = d),
            ),
            ChangeKind.status => _ProposalEnumChoice<OperationalStatus>(
              label: 'Novo estado operacional',
              current: operationalStatusLabel(widget.road.status),
              values: OperationalStatus.values
                  .map((s) => (s, operationalStatusLabel(s)))
                  .toList(),
              selected: _status ?? widget.road.status,
              onSelected: (s) => setState(() => _status = s),
            ),
          },
          const SizedBox(height: FogoSpacing.md),
          FogoTextField(
            label: 'Justificativa',
            hint: 'Motivo técnico da alteração (mín. 20 caracteres)',
            controller: _justificationController,
            maxLines: 4,
            minLines: 3,
            errorText: _justificationError,
          ),
          const SizedBox(height: FogoSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FogoButton(
                  label: 'Criar rascunho',
                  icon: LucideIcons.file_text,
                  variant: FogoButtonVariant.primary,
                  expanded: true,
                  onTap: _submitDraft,
                ),
              ),
              const SizedBox(width: FogoSpacing.sm),
              FogoButton(label: 'Cancelar', onTap: widget.onCancel),
            ],
          ),
        ],
      ),
    );
  }
}
