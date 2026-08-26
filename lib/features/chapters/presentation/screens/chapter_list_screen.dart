import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../learning_paths/presentation/widgets/learning_path_card.dart';

/// Learn tab root: shows study subjects first. Chapter/topic drilling happens
/// in pushed detail routes so Learn remains study-focused.
class ChapterListScreen extends ConsumerWidget {
  const ChapterListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final selectedPathId = ref
        .watch(selectedLearningPathControllerProvider)
        .valueOrNull;

    return GameScaffold(
      appBar: AppBar(
        title: const Text('Learn'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: pathsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load subjects.',
                    style: context.appTextStyles.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Retry',
                    onPressed: () => ref.invalidate(learningPathsProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (paths) {
            if (paths.isEmpty) {
              return Center(
                child: Text(
                  'No subjects available yet.',
                  style: context.appTextStyles.bodyLarge,
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                96,
              ),
              itemCount: paths.length + 1,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subjects',
                          style: context.appTextStyles.displayMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Study material, chapters, and topic notes live here.',
                          style: context.appTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                final path = paths[index - 1];
                return LearningPathCard(
                  path: path,
                  isSelected: path.id == selectedPathId,
                  onTap: () => context.push(RouteNames.subjectPath(path.id)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
