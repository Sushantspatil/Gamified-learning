import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
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

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _selectedAvatarId =
        ref.read(profileControllerProvider).valueOrNull?.avatarId ?? 'default';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    final currentUser = ref.read(authControllerProvider).valueOrNull;
    final currentProfile = ref.read(profileControllerProvider).valueOrNull;

    // Fetch each notifier fresh at its call site rather than pre-capturing:
    // ProfileController watches authControllerProvider, so updating the
    // display name rebuilds it and invalidates any notifier reference taken
    // beforehand.
    if (currentUser != null && newName != currentUser.displayName) {
      await ref
          .read(authControllerProvider.notifier)
          .updateDisplayName(newName);
    }
    if (_selectedAvatarId != null &&
        _selectedAvatarId != currentProfile?.avatarId) {
      await ref
          .read(profileControllerProvider.notifier)
          .updateAvatar(_selectedAvatarId!);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving =
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
          padding: AppSpacing.paddingLg,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _nameController,
                  label: 'Display name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a display name';
                    }
                    return null;
                  },
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
