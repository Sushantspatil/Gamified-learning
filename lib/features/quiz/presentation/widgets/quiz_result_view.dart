import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/quiz_result.dart';

class QuizResultView extends StatelessWidget {
  final QuizResult result;
  final int? rewardXp;
  final int? rewardCoins;
  final bool leveledUp;
  final VoidCallback onDone;

  const QuizResultView({
    super.key,
    required this.result,
    required this.onDone,
    this.rewardXp,
    this.rewardCoins,
    this.leveledUp = false,
  });

  @override
  Widget build(BuildContext context) {
    final score = result.score;
    final colors = context.themeColors;

    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              result.endedEarly ? Icons.whatshot : Icons.emoji_events,
              color: result.endedEarly ? colors.error : AppColors.accentGold,
              size: 64,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              result.endedEarly ? 'Sudden Death — Quiz Ended' : 'Quiz Complete!',
              style: context.appTextStyles.displayMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '${score.earnedPoints} / ${score.maxPoints} points',
              style: context.appTextStyles.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${score.correctCount} of ${score.totalCount} correct',
              style: context.appTextStyles.bodyMedium,
            ),
            if (rewardXp != null && rewardCoins != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, color: AppColors.xpPurple, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Text('+$rewardXp XP', style: context.appTextStyles.labelLarge),
                  const SizedBox(width: AppSpacing.md),
                  Icon(Icons.monetization_on, color: AppColors.coinGold, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Text('+$rewardCoins Coins', style: context.appTextStyles.labelLarge),
                ],
              ),
            ],
            if (leveledUp) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Level Up!', style: context.appTextStyles.titleMedium),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(label: 'Done', onPressed: onDone),
          ],
        ),
      ),
    );
  }
}
