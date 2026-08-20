import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../providers/chapter_providers.dart';

/// "Chapter summary" screen from the Dashboard requirements — shows a
/// chapter's description and its topics, each launching the quiz engine.
class ChapterSummaryScreen extends ConsumerWidget {
  final String chapterId;

  const ChapterSummaryScreen({super.key, required this.chapterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapterAsync = ref.watch(chapterByIdProvider(chapterId));
    final topicsAsync = ref.watch(topicsProvider(chapterId));
    final colors = context.themeColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chapter Summary'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: chapterAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('Could not load this chapter.', style: context.appTextStyles.bodyLarge),
          ),
          data: (chapter) {
            if (chapter == null) {
              return Center(child: Text('Chapter not found.', style: context.appTextStyles.bodyLarge));
            }

            return ListView(
              padding: AppSpacing.paddingMd,
              children: [
                Text(chapter.title, style: context.appTextStyles.displayMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(chapter.description, style: context.appTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                Text('Topics', style: context.appTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                topicsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) =>
                      Text('Could not load topics.', style: context.appTextStyles.bodyMedium),
                  data: (topics) {
                    if (topics.isEmpty) {
                      return Text('No topics yet.', style: context.appTextStyles.bodyMedium);
                    }

                    return Column(
                      children: [
                        for (final topic in topics)
                          Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: AppSpacing.paddingMd,
                            decoration: BoxDecoration(
                              color: colors.cardBackground,
                              borderRadius: AppDimensions.radiusMd,
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  topic.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                                  color: topic.isCompleted ? colors.success : colors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: Text(topic.title, style: context.appTextStyles.bodyLarge)),
                                TextButton(
                                  onPressed: () => context.push(RouteNames.quizPath(topic.id)),
                                  child: const Text('Start Quiz'),
                                ),
                              ],
                            ),
                          ),
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
