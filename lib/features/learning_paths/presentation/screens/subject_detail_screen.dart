import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../chapters/domain/entities/chapter.dart';
import '../../../chapters/domain/entities/topic.dart';
import '../../../chapters/presentation/providers/chapter_providers.dart';
import '../../domain/entities/learning_path.dart';
import '../providers/learning_path_providers.dart';

/// One screen for a subject: its topics, grouped under their chapter. A subject
/// with a single chapter named like itself shows just the topics. Tapping a
/// topic opens its notes.
class SubjectLearnChaptersScreen extends ConsumerWidget {
  final String subjectId;

  const SubjectLearnChaptersScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final chaptersAsync = ref.watch(chaptersProvider(subjectId));
    final subject = pathsAsync.valueOrNull == null
        ? null
        : _findSubject(pathsAsync.valueOrNull!, subjectId);

    return GameScaffold(
      appBar: AppBar(
        title: Text(
          subject?.title ?? 'Subject',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: pathsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ErrorState(
            message: 'Could not load this subject.',
            onRetry: () => ref.invalidate(learningPathsProvider),
          ),
          data: (paths) {
            final subject = _findSubject(paths, subjectId);
            if (subject == null) {
              return const _MessageState(message: 'Subject not found.');
            }

            return chaptersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ErrorState(
                message: 'Could not load the topics.',
                onRetry: () => ref.invalidate(chaptersProvider(subjectId)),
              ),
              data: (chapters) {
                if (chapters.isEmpty) {
                  return const _MessageState(
                    message: 'No notes available yet.',
                  );
                }

                // A lone chapter that just repeats the subject's name adds
                // nothing, so its heading is left out.
                final showHeadings =
                    chapters.length > 1 ||
                    !_sameTitle(chapters.first.title, subject.title);

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.sm,
                    AppSpacing.screenPadding,
                    96,
                  ),
                  itemCount: chapters.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.lg),
                  itemBuilder: (context, index) => _ChapterSection(
                    chapter: chapters[index],
                    showHeading: showHeadings,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ChapterSection extends ConsumerWidget {
  final Chapter chapter;
  final bool showHeading;

  const _ChapterSection({required this.chapter, required this.showHeading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider(chapter.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading) ...[
          Text(
            chapter.title,
            style: context.appTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        topicsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => _ErrorState(
            message: 'Could not load the topics.',
            onRetry: () => ref.invalidate(topicsProvider(chapter.id)),
          ),
          data: (topics) {
            if (topics.isEmpty) {
              return Text(
                'No topics yet.',
                style: context.appTextStyles.bodyMedium,
              );
            }
            return Column(
              children: [
                for (var index = 0; index < topics.length; index++) ...[
                  _TopicRow(
                    chapterId: chapter.id,
                    topic: topics[index],
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
  }
}

class _TopicRow extends StatelessWidget {
  final String chapterId;
  final Topic topic;
  final int number;

  const _TopicRow({
    required this.chapterId,
    required this.topic,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: () => context.push(RouteNames.topicPath(chapterId, topic.id)),
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
                color: topic.isCompleted
                    ? colors.success.withValues(alpha: 0.12)
                    : colors.primary.withValues(alpha: 0.10),
                borderRadius: AppDimensions.radiusMd,
              ),
              child: topic.isCompleted
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
              child: Text(
                topic.title,
                style: context.appTextStyles.titleMedium,
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textSecondary),
          ],
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
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.appTextStyles.bodyLarge,
        ),
      ),
    );
  }
}

LearningPath? _findSubject(List<LearningPath> paths, String subjectId) {
  for (final path in paths) {
    if (path.id == subjectId) return path;
  }
  return null;
}

bool _sameTitle(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();
