import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../providers/chapter_providers.dart';
import '../widgets/chapter_card.dart';

/// Shows the chapters for the learner's currently selected learning path.
class ChapterListScreen extends ConsumerWidget {
  const ChapterListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPathId = ref.watch(selectedLearningPathControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chapters'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: selectedPathId == null
            ? Center(
                child: Text('No learning path selected yet.', style: context.appTextStyles.bodyLarge),
              )
            : Consumer(
                builder: (context, ref, _) {
                  final chaptersAsync = ref.watch(chaptersProvider(selectedPathId));

                  return chaptersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => Center(
                      child: Padding(
                        padding: AppSpacing.paddingLg,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Could not load chapters.', style: context.appTextStyles.bodyLarge),
                            const SizedBox(height: AppSpacing.md),
                            AppButton(
                              label: 'Retry',
                              onPressed: () => ref.invalidate(chaptersProvider(selectedPathId)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (chapters) {
                      if (chapters.isEmpty) {
                        return Center(
                          child: Text(
                            'No chapters available yet.',
                            style: context.appTextStyles.bodyLarge,
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: AppSpacing.paddingMd,
                        itemCount: chapters.length,
                        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final chapter = chapters[index];
                          return ChapterCard(
                            chapter: chapter,
                            onTap: () => context.push(RouteNames.chapterPath(chapter.id)),
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
