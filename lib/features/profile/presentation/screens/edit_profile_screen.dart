import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_pressable.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../avatar_catalog.dart';
import '../providers/profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _selectedAvatarId;
  String? _selectedClassLevel;
  String? _selectedBoard;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _selectedAvatarId =
        ref.read(profileControllerProvider).valueOrNull?.avatarId ?? 'default';
    _selectedClassLevel = ref
        .read(profileControllerProvider)
        .valueOrNull
        ?.classLevel;
    _selectedBoard =
        ref.read(profileControllerProvider).valueOrNull?.board ??
        'Maharashtra State Board';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Server rejection for the name (e.g. already taken), shown under the field.
  String? _nameError;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return; // ignore repeated taps while a save is running
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    final currentUser = ref.read(authControllerProvider).valueOrNull;
    final currentProfile = ref.read(profileControllerProvider).valueOrNull;
    setState(() => _saving = true);

    try {
      // Name first: if the server refuses it nothing else is saved and the
      // screen stays open with the reason shown under the field.
      // Notifiers are fetched fresh at each call site: ProfileController
      // watches authControllerProvider, so a name change rebuilds it.
      if (currentUser != null && newName != currentUser.displayName) {
        try {
          await ref
              .read(authControllerProvider.notifier)
              .updateDisplayName(newName);
        } on ValidationException catch (error) {
          if (!mounted) return;
          setState(() => _nameError = error.message);
          _formKey.currentState!.validate();
          return;
        }
      }
      if (_selectedAvatarId != null &&
          _selectedAvatarId != currentProfile?.avatarId) {
        await ref
            .read(profileControllerProvider.notifier)
            .updateAvatar(_selectedAvatarId!);
      }
      if (currentProfile != null &&
          (_selectedClassLevel != currentProfile.classLevel ||
              _selectedBoard != currentProfile.board)) {
        await ref
            .read(profileControllerProvider.notifier)
            .completeProfileSetup(
              avatarId: _selectedAvatarId ?? currentProfile.avatarId,
              classLevel: _selectedClassLevel ?? '12th',
              board: _selectedBoard ?? 'Maharashtra State Board',
              selectedSubjectIds: currentProfile.selectedSubjectIds,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving =
        _saving ||
        ref.watch(authControllerProvider).isLoading ||
        ref.watch(profileControllerProvider).isLoading;
    final colors = context.themeColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingMd,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _nameController,
                  label: 'Display name',
                  onChanged: (_) {
                    // Editing the name clears the server's "taken" message.
                    if (_nameError == null) return;
                    setState(() => _nameError = null);
                    _formKey.currentState?.validate();
                  },
                  validator: (value) {
                    if (_nameError != null) return _nameError;
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a display name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  key: const Key('edit-class-dropdown'),
                  initialValue: _selectedClassLevel,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: const [
                    DropdownMenuItem(value: '11th', child: Text('11th')),
                    DropdownMenuItem(value: '12th', child: Text('12th')),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedClassLevel = value),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  key: const Key('edit-board-dropdown'),
                  initialValue: _selectedBoard,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Board'),
                  items: const [
                    DropdownMenuItem(
                      value: 'Maharashtra State Board',
                      child: Text('Maharashtra State Board'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _selectedBoard = value),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Choose an avatar',
                  style: context.appTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: AvatarCatalog.icons.entries.map((entry) {
                    final isSelected = _selectedAvatarId == entry.key;
                    return AppPressable(
                      onTap: () =>
                          setState(() => _selectedAvatarId = entry.key),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.borderRadiusCircular,
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: isSelected
                            ? colors.primary
                            : colors.surfaceElevated,
                        child: Icon(
                          entry.value,
                          color: isSelected
                              ? colors.primaryForeground
                              : colors.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Save', isLoading: isSaving, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
