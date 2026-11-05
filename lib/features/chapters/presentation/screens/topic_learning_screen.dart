import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../domain/entities/topic.dart';
import '../providers/chapter_providers.dart';

/// The notes for one topic. No study content is connected yet, so for now the
/// screen says so plainly instead of showing placeholder paragraphs.
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
    final chapter = ref.watch(chapterByIdProvider(chapterId)).valueOrNull;
    final topicsAsync = ref.watch(topicsProvider(chapterId));

    return GameScaffold(
      appBar: AppBar(
        title: const Text('Notes'),
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
                if (chapter != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    chapter.title,
                    style: context.appTextStyles.bodyMedium.copyWith(
                      color: context.themeColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const _NotesComingSoon(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotesComingSoon extends StatelessWidget {
  const _NotesComingSoon();

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return AppCard(
      key: const Key('notes_coming_soon'),
      padding: AppSpacing.paddingLg,
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 40, color: colors.primary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Notes are coming soon',
            textAlign: TextAlign.center,
            style: context.appTextStyles.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'We are still preparing the study notes for this topic. '
            'Please check back later.',
            textAlign: TextAlign.center,
            style: context.appTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
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
