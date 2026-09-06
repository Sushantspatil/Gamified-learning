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
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../learning_paths/domain/entities/learning_path.dart';
import '../../../learning_paths/presentation/providers/learning_path_providers.dart';
import '../../../learning_paths/presentation/widgets/learning_path_card.dart';
import '../../../profile/presentation/avatar_catalog.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

const _classLevels = ['11th', '12th'];
const _boards = ['Maharashtra State Board'];

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  int _step = 0;
  String? _selectedAvatarId;
  String? _selectedClassLevel;
  String? _selectedBoard;
  final Set<String> _selectedSubjectIds = {};

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull;
    final profile = ref.read(profileControllerProvider).valueOrNull;
    _nameController.text = user?.displayName ?? '';
    _selectedAvatarId = profile?.avatarId ?? 'default';
    _selectedClassLevel = profile?.classLevel;
    _selectedBoard = profile?.board ?? _boards.first;
    _selectedSubjectIds.addAll(profile?.selectedSubjectIds ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pathsAsync = ref.watch(learningPathsProvider);
    final isSaving =
        ref.watch(authControllerProvider).isLoading ||
        ref.watch(profileControllerProvider).isLoading ||
        ref.watch(selectedLearningPathControllerProvider).isLoading;

    ref.listen(profileControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Setup'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: pathsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _MessageState(
            message: 'Could not load subjects.',
            onRetry: () => ref.invalidate(learningPathsProvider),
          ),
          data: (paths) => Column(
            children: [
              Padding(
                padding: AppSpacing.paddingMd,
                child: _SetupProgress(step: _step),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: AppSpacing.horizontalMd,
                  child: _stepContent(paths),
                ),
              ),
              Padding(
                padding: AppSpacing.paddingMd,
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: AppButton(
                          key: const Key('setup-back-button'),
                          label: 'Back',
                          variant: AppButtonVariant.secondary,
                          onPressed: isSaving
                              ? null
                              : () => setState(() => _step -= 1),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: AppButton(
                        key: const Key('setup-next-button'),
                        label: _step == 3 ? 'Continue' : 'Next',
                        isLoading: isSaving,
                        onPressed: !_canContinue
                            ? null
                            : _step == 3
                            ? _completeProfile
                            : () => setState(() => _step += 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepContent(List<LearningPath> paths) {
    return switch (_step) {
      0 => _AvatarStep(
        selectedAvatarId: _selectedAvatarId,
        onSelected: (id) => setState(() => _selectedAvatarId = id),
      ),
      1 => _BasicDetailsStep(
        nameController: _nameController,
        selectedClassLevel: _selectedClassLevel,
        selectedBoard: _selectedBoard,
        onChanged: () => setState(() {}),
        onClassChanged: (value) => setState(() => _selectedClassLevel = value),
        onBoardChanged: (value) => setState(() => _selectedBoard = value),
      ),
      2 => _SubjectsStep(
        paths: paths,
        selectedSubjectIds: _selectedSubjectIds,
        onToggle: (id) => setState(() {
          if (_selectedSubjectIds.contains(id)) {
            _selectedSubjectIds.remove(id);
          } else {
            _selectedSubjectIds.add(id);
          }
        }),
      ),
      _ => _ConfirmStep(
        name: _nameController.text.trim(),
        avatarId: _selectedAvatarId ?? 'default',
        classLevel: _selectedClassLevel ?? '',
        board: _selectedBoard ?? '',
        selectedSubjects: paths
            .where((path) => _selectedSubjectIds.contains(path.id))
            .toList(),
        onEdit: (step) => setState(() => _step = step),
      ),
    };
  }

  bool get _canContinue {
    return switch (_step) {
      0 => _selectedAvatarId != null,
      1 =>
        _nameController.text.trim().isNotEmpty &&
            _selectedClassLevel != null &&
            _selectedBoard != null,
      2 => _selectedSubjectIds.isNotEmpty,
      _ => _selectedSubjectIds.isNotEmpty,
    };
  }

  Future<void> _completeProfile() async {
    final selectedSubjects = _selectedSubjectIds.toList();
    final displayName = _nameController.text.trim();
    final currentUser = ref.read(authControllerProvider).valueOrNull;
    if (currentUser != null && displayName != currentUser.displayName) {
      await ref
          .read(authControllerProvider.notifier)
          .updateDisplayName(displayName);
    }
    await ref
        .read(profileControllerProvider.notifier)
        .completeProfileSetup(
          avatarId: _selectedAvatarId ?? 'default',
          classLevel: _selectedClassLevel!,
          board: _selectedBoard!,
          selectedSubjectIds: selectedSubjects,
        );
    await ref
        .read(selectedLearningPathControllerProvider.notifier)
        .select(selectedSubjects.first);
    if (mounted) context.go(RouteNames.tutorial);
  }
}

class _SetupProgress extends StatelessWidget {
  final int step;

  const _SetupProgress({required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${step + 1} of 4', style: context.appTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        AppProgressBar(
          value: (step + 1) / 4,
          height: 7,
          semanticLabel: 'Profile setup progress',
        ),
      ],
    );
  }
}

class _AvatarStep extends StatelessWidget {
  final String? selectedAvatarId;
  final ValueChanged<String> onSelected;

  const _AvatarStep({required this.selectedAvatarId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return _StepFrame(
      title: 'Choose Your Avatar',
      subtitle: 'Pick a character that represents you',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: AvatarCatalog.icons.entries.map((entry) {
          final isSelected = selectedAvatarId == entry.key;
          return AppPressable(
            key: Key('setup-avatar-${entry.key}'),
            onTap: () => onSelected(entry.key),
            borderRadius: BorderRadius.circular(
              AppDimensions.borderRadiusCircular,
            ),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colors.primaryForeground : colors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    entry.value,
                    color: isSelected
                        ? colors.primaryForeground
                        : colors.textSecondary,
                    size: 34,
                  ),
                  if (isSelected)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Icon(
                        Icons.check_circle,
                        color: colors.primaryForeground,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BasicDetailsStep extends StatelessWidget {
  final TextEditingController nameController;
  final String? selectedClassLevel;
  final String? selectedBoard;
  final VoidCallback onChanged;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onBoardChanged;

  const _BasicDetailsStep({
    required this.nameController,
    required this.selectedClassLevel,
    required this.selectedBoard,
    required this.onChanged,
    required this.onClassChanged,
    required this.onBoardChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: 'Tell Us About You',
      subtitle: 'A few details help personalize your learning.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: nameController,
            label: 'Full Name',
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            key: const Key('setup-class-dropdown'),
            initialValue: selectedClassLevel,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Class'),
            items: [
              for (final level in _classLevels)
                DropdownMenuItem(value: level, child: Text(level)),
            ],
            onChanged: onClassChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            key: const Key('setup-board-dropdown'),
            initialValue: selectedBoard,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Board'),
            items: [
              for (final board in _boards)
                DropdownMenuItem(value: board, child: Text(board)),
            ],
            onChanged: onBoardChanged,
          ),
        ],
      ),
    );
  }
}

class _SubjectsStep extends StatelessWidget {
  final List<LearningPath> paths;
  final Set<String> selectedSubjectIds;
  final ValueChanged<String> onToggle;

  const _SubjectsStep({
    required this.paths,
    required this.selectedSubjectIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: 'Select Your Subjects',
      subtitle: 'Choose the subjects you want to learn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final path in paths) ...[
            LearningPathCard(
              path: path,
              isSelected: selectedSubjectIds.contains(path.id),
              onTap: () => onToggle(path.id),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  final String name;
  final String avatarId;
  final String classLevel;
  final String board;
  final List<LearningPath> selectedSubjects;
  final ValueChanged<int> onEdit;

  const _ConfirmStep({
    required this.name,
    required this.avatarId,
    required this.classLevel,
    required this.board,
    required this.selectedSubjects,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return _StepFrame(
      title: 'Confirm Your Profile',
      subtitle: 'Review your setup before starting the tutorial.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 38,
              child: Icon(AvatarCatalog.iconFor(avatarId), size: 38),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryRow(label: 'Name', value: name, onEdit: () => onEdit(1)),
          _SummaryRow(
            label: 'Class',
            value: classLevel,
            onEdit: () => onEdit(1),
          ),
          _SummaryRow(label: 'Board', value: board, onEdit: () => onEdit(1)),
          _SummaryRow(
            label: 'Subjects',
            value: selectedSubjects.map((subject) => subject.title).join(', '),
            onEdit: () => onEdit(2),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: AppSpacing.paddingMd,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.appTextStyles.labelSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(value, style: context.appTextStyles.titleMedium),
                ],
              ),
            ),
            TextButton(onPressed: onEdit, child: const Text('Edit')),
          ],
        ),
      ),
    );
  }
}

class _StepFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.appTextStyles.displayMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: context.appTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MessageState({required this.message, required this.onRetry});

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
