import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';

/// Uses explicit up/down controls rather than drag-and-drop — simpler to
/// operate, more accessible, and avoids pulling in a drag/reorder package
/// for what is otherwise a short list.
class SortItRightView extends StatefulWidget {
  final SortItRightQuestion question;
  final void Function(Answer answer) onSubmit;

  const SortItRightView({super.key, required this.question, required this.onSubmit});

  @override
  State<SortItRightView> createState() => _SortItRightViewState();
}

class _SortItRightViewState extends State<SortItRightView> {
  late List<String> _order;

  @override
  void initState() {
    super.initState();
    // Rotate by one so the initial order is never already correct (for
    // lists longer than one item), without needing real randomness.
    final items = widget.question.itemsInOrder;
    _order = items.length > 1 ? [...items.skip(1), items.first] : List.of(items);
  }

  void _moveUp(int index) {
    if (index == 0) return;
    setState(() {
      final item = _order.removeAt(index);
      _order.insert(index - 1, item);
    });
  }

  void _moveDown(int index) {
    if (index == _order.length - 1) return;
    setState(() {
      final item = _order.removeAt(index);
      _order.insert(index + 1, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.question.prompt, style: context.appTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: ListView.separated(
            itemCount: _order.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              return Container(
                padding: AppSpacing.paddingSm,
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: AppDimensions.radiusSm,
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(_order[index], style: context.appTextStyles.bodyMedium)),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up),
                      onPressed: index == 0 ? null : () => _moveUp(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: index == _order.length - 1 ? null : () => _moveDown(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Submit',
          onPressed: () => widget.onSubmit(
            SortAnswer(questionId: widget.question.id, orderedItems: List.of(_order)),
          ),
        ),
      ],
    );
  }
}
