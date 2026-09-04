import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../domain/entities/topic.dart';
import '../providers/chapter_providers.dart';

class TopicLearningScreen extends ConsumerWidget {
  final String chapterId;
  final String topicId;

  const TopicLearningScreen({
    super.key,
    required this.chapterId,
    required this.topicId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapterAsync = ref.watch(chapterByIdProvider(chapterId));
    final topicsAsync = ref.watch(topicsProvider(chapterId));

    return GameScaffold(
      appBar: AppBar(
        title: const Text('Learning material'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: topicsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            message: 'Could not load this topic.',
            onRetry: () => ref.invalidate(topicsProvider(chapterId)),
          ),
          data: (topics) {
            final topic = _findTopic(topics, topicId);
            if (topic == null) {
              return const _MessageState(message: 'Topic not found.');
            }

            return ListView(
              padding: AppSpacing.paddingMd,
              children: [
                Text(topic.title, style: context.appTextStyles.displayMedium),
                const SizedBox(height: AppSpacing.xs),
                chapterAsync.when(
                  loading: () => Text(
                    'Loading chapter context...',
                    style: context.appTextStyles.bodyMedium,
                  ),
                  error: (error, stackTrace) => Text(
                    'Chapter context unavailable.',
                    style: context.appTextStyles.bodyMedium,
                  ),
                  data: (chapter) => Text(
                    chapter?.title ?? 'Chapter unavailable',
                    style: context.appTextStyles.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study content',
                        style: context.appTextStyles.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Review the core ideas for ${topic.title}. Full notes and PDF content are not connected in the current mock data yet.',
                        style: context.appTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Examples',
                        style: context.appTextStyles.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Practice examples will appear here when study-material data is available.',
                        style: context.appTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('Summary', style: context.appTextStyles.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Use this section to revise the concept before moving into Play mode from the subject screen.',
                        style: context.appTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: context.appTextStyles.bodyLarge),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;

  const _MessageState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Text(message, style: context.appTextStyles.bodyLarge),
      ),
    );
  }
}

Topic? _findTopic(List<Topic> topics, String topicId) {
  for (final topic in topics) {
    if (topic.id == topicId) return topic;
  }
  return null;
}
