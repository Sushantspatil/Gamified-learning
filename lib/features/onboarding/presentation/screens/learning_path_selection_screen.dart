import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../learning_paths/presentation/widgets/learning_path_card.dart';

class LearningPathSelectionScreen extends ConsumerStatefulWidget {
  const LearningPathSelectionScreen({super.key});

  @override
  ConsumerState<LearningPathSelectionScreen> createState() => _LearningPathSelectionScreenState();
}

class _LearningPathSelectionScreenState extends ConsumerState<LearningPathSelectionScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final selectionState = ref.watch(selectedLearningPathControllerProvider);
    final isSubmitting = selectionState.isLoading;

    ref.listen(selectedLearningPathControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString())),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Path'),
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
                  Text('Could not load learning paths.', style: context.appTextStyles.bodyLarge),
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
                child: Text('No learning paths available yet.', style: context.appTextStyles.bodyLarge),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: AppSpacing.paddingMd,
                  child: Text(
                    'Pick a learning path to get started. You can change this later.',
                    style: context.appTextStyles.bodyMedium,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: AppSpacing.horizontalMd,
                    itemCount: paths.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final path = paths[index];
                      return LearningPathCard(
                        path: path,
                        isSelected: _selectedId == path.id,
                        onTap: () => setState(() => _selectedId = path.id),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: AppSpacing.paddingMd,
                  child: AppButton(
                    label: 'Continue',
                    isLoading: isSubmitting,
                    onPressed: _selectedId == null
                        ? null
                        : () => ref
                            .read(selectedLearningPathControllerProvider.notifier)
                            .select(_selectedId!),
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
