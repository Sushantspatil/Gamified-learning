import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_theme_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/providers/core_providers.dart';
import '../../../domain/personal_best.dart';

/// "New personal best!" when this game beat the player's earlier best for the
/// mode, otherwise a quiet "Your best: N". It reads the earlier best and writes
/// the new one once, when the result first appears. With no storage available
/// (some tests) it shows nothing.
class PersonalBestBadge extends StatefulWidget {
  /// Short identifier of the game mode, used in the storage key.
  final String modeKey;
  final int score;

  const PersonalBestBadge({
    super.key,
    required this.modeKey,
    required this.score,
  });

  @override
  State<PersonalBestBadge> createState() => _PersonalBestBadgeState();
}

class _PersonalBestBadgeState extends State<PersonalBestBadge> {
  BestUpdate? _update;

  @override
  void initState() {
    super.initState();
    _update = _record();
  }

  BestUpdate? _record() {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final storage = container.read(localStorageServiceProvider);
      final key = 'best_score_${widget.modeKey}';
      final update = updateBest(
        previous: storage.getInt(key),
        score: widget.score,
      );
      if (update.shouldSave) storage.setInt(key, update.best);
      return update;
    } catch (_) {
      return null; // no scope or no storage: show nothing
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    if (update == null) return const SizedBox.shrink();
    final colors = context.themeColors;
    final styles = context.appTextStyles;

    if (update.isNewBest) {
      return Container(
        key: const Key('personal_best_new'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.warning.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.military_tech_rounded, color: colors.warning, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'New personal best!',
              style: styles.labelLarge.copyWith(
                color: colors.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    final previous = update.previousBest;
    if (previous == null) return const SizedBox.shrink();
    return Text(
      'Your best: $previous',
      key: const Key('personal_best_line'),
      style: styles.bodySmall.copyWith(color: colors.textSecondary),
    );
  }
}
