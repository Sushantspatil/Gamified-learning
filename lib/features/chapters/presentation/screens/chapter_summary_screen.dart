import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../providers/chapter_providers.dart';

/// Learn-mode chapter view: shows study topics only.
class ChapterSummaryScreen extends ConsumerWidget {
  final String chapterId;

  const ChapterSummaryScreen({super.key, required this.chapterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapterAsync = ref.watch(chapterByIdProvider(chapterId));
    final topicsAsync = ref.watch(topicsProvider(chapterId));

    return GameScaffold(
      appBar: AppBar(
        title: const Text('Topics'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: chapterAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(
              'Could not load this chapter.',
              style: context.appTextStyles.bodyLarge,
            ),
          ),
          data: (chapter) {
            if (chapter == null) {
              return Center(
                child: Text(
                  'Chapter not found.',
                  style: context.appTextStyles.bodyLarge,
                ),
              );
            }

            return ListView(
              padding: AppSpacing.paddingMd,
              children: [
                Text(chapter.title, style: context.appTextStyles.displayMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  chapter.description,
                  style: context.appTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Topics', style: context.appTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                topicsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Text(
                    'Could not load topics.',
                    style: context.appTextStyles.bodyMedium,
                  ),
                  data: (topics) {
                    if (topics.isEmpty) {
                      return Text(
                        'No learning material available yet.',
                        style: context.appTextStyles.bodyMedium,
                      );
                    }

                    return Column(
                      children: [
                        for (var index = 0; index < topics.length; index++) ...[
                          _TopicStudyCard(
                            chapterId: chapterId,
                            topicId: topics[index].id,
                            topicTitle: topics[index].title,
                            isCompleted: topics[index].isCompleted,
                            number: index + 1,
                          ),
                          if (index != topics.length - 1)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopicStudyCard extends StatelessWidget {
  final String chapterId;
  final String topicId;
  final String topicTitle;
  final bool isCompleted;
  final int number;

  const _TopicStudyCard({
    required this.chapterId,
    required this.topicId,
    required this.topicTitle,
    required this.isCompleted,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: () => context.push(RouteNames.topicPath(chapterId, topicId)),
      borderRadius: AppDimensions.radiusCard,
      child: AppCard(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCompleted
                    ? colors.success.withValues(alpha: 0.12)
                    : colors.primary.withValues(alpha: 0.10),
                borderRadius: AppDimensions.radiusMd,
              ),
              child: isCompleted
                  ? Icon(Icons.check_rounded, color: colors.success, size: 20)
                  : Text(
                      number.toString().padLeft(2, '0'),
                      style: context.appTextStyles.labelLarge.copyWith(
                        color: colors.primary,
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topicTitle, style: context.appTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isCompleted ? 'Completed' : 'Study material',
                    style: context.appTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
