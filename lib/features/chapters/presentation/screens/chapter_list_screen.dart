import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../learning_paths/domain/entities/learning_path.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';

/// Subjects tab root: one simple card per subject. Tapping a subject opens its
/// topics (one screen), and a topic opens its notes.
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
        title: const Text('Subjects'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: pathsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: AppSpacing.paddingMd,
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
                AppSpacing.sm,
                AppSpacing.screenPadding,
                96,
              ),
              itemCount: paths.length + 1,
              separatorBuilder: (context, index) =>
                  SizedBox(height: index == 0 ? AppSpacing.md : AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    'Pick a subject to read its notes.',
                    style: context.appTextStyles.bodyMedium.copyWith(
                      color: context.themeColors.textSecondary,
                    ),
                  );
                }

                final path = paths[index - 1];
                return _SubjectCard(
                  path: path,
                  accent: _accentFor(context, index - 1),
                  isCurrent: path.id == selectedPathId,
                  onTap: () {
                    // The subject you open becomes your current one (the
                    // dashboard follows it), so there is nothing to tick.
                    if (path.id != selectedPathId) {
                      ref
                          .read(selectedLearningPathControllerProvider.notifier)
                          .select(path.id);
                    }
                    context.push(RouteNames.subjectPath(path.id));
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  static Color _accentFor(BuildContext context, int index) {
    final colors = context.themeColors;
    final accents = [
      colors.subjectAccountancy,
      colors.subjectBusinessStudies,
      colors.subjectEconomics,
    ];
    return accents[index % accents.length];
  }
}

class _SubjectCard extends StatelessWidget {
  final LearningPath path;
  final Color accent;
  final bool isCurrent;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.path,
    required this.accent,
    required this.isCurrent,
    required this.onTap,
  });

  String get _details {
    final level = switch (path.difficulty) {
      LearningPathDifficulty.beginner => 'Beginner',
      LearningPathDifficulty.intermediate => 'Intermediate',
      LearningPathDifficulty.advanced => 'Advanced',
    };
    final count = path.topicCount;
    return '$level • $count ${count == 1 ? 'topic' : 'topics'}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return AppPressable(
      onTap: onTap,
      borderRadius: AppDimensions.radiusCard,
      child: AppCard(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: AppDimensions.radiusMd,
              ),
              child: Icon(Icons.menu_book_rounded, color: accent, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(path.title, style: context.appTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _details,
                    style: context.appTextStyles.labelSmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (isCurrent)
              const AppBadge(label: 'Current', variant: AppBadgeVariant.primary)
            else
              Icon(Icons.chevron_right, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
