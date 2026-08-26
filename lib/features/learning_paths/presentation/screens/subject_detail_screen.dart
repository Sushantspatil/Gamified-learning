import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../chapters/presentation/providers/chapter_providers.dart';
import '../../domain/entities/learning_path.dart';
import '../providers/learning_path_providers.dart';

class SubjectDetailScreen extends ConsumerWidget {
  final String subjectId;

  const SubjectDetailScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final chaptersAsync = ref.watch(chaptersProvider(subjectId));

    return GameScaffold(
      appBar: AppBar(
        title: const Text('Subject'),
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

            return ListView(
              padding: AppSpacing.paddingMd,
              children: [
                Text(subject.title, style: context.appTextStyles.displayMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subject.description,
                  style: context.appTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study Material',
                        style: context.appTextStyles.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Notes and PDFs are not connected yet. Chapter summaries and topic study pages are available from the mock curriculum.',
                        style: context.appTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Chapters', style: context.appTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                chaptersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => _ErrorState(
                    message: 'Could not load chapters.',
                    onRetry: () => ref.invalidate(chaptersProvider(subjectId)),
                  ),
                  data: (chapters) {
                    if (chapters.isEmpty) {
                      return const _MessageState(
                        message: 'No chapters available yet.',
                      );
                    }

                    return Column(
                      children: [
                        for (final chapter in chapters) ...[
                          AppPressable(
                            onTap: () => context.push(
                              RouteNames.chapterPath(chapter.id),
                            ),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Chapter ${chapter.order}',
                                          style:
                                              context.appTextStyles.labelSmall,
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          chapter.title,
                                          style:
                                              context.appTextStyles.titleMedium,
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          '${chapter.topicCount} topics',
                                          style:
                                              context.appTextStyles.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
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

LearningPath? _findSubject(List<LearningPath> paths, String subjectId) {
  for (final path in paths) {
    if (path.id == subjectId) return path;
  }
  return null;
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
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
        padding: AppSpacing.paddingLg,
        child: Text(message, style: context.appTextStyles.bodyLarge),
      ),
    );
  }
}
