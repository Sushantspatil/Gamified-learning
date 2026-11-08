import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_theme_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../application/reminders_controller.dart';

/// The "Daily Reminders" switch for the profile settings. Left out on devices
/// that cannot show scheduled reminders (web, desktop).
class ReminderSettingsRow extends ConsumerWidget {
  const ReminderSettingsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(reminderSchedulerProvider).isSupported) {
      return const SizedBox.shrink();
    }
    final colors = context.themeColors;
    final styles = context.appTextStyles;
    final settings = ref.watch(reminderSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: AppSpacing.lg),
        // A plain row (not a list tile), like the sound switch above it.
        Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              color: colors.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Reminders', style: styles.bodyMedium),
                  Text(
                    'A nudge to protect your streak',
                    style: styles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              key: const Key('reminders_switch'),
              value: settings.enabled,
              activeThumbColor: colors.primary,
              onChanged: (on) async {
                final controller = ref.read(reminderSettingsProvider.notifier);
                if (!on) {
                  await controller.disable();
                  return;
                }
                final granted = await controller.enable();
                if (granted || !context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Notifications are blocked. You can allow them in your phone settings.',
                      ),
                    ),
                  );
              },
            ),
          ],
        ),
      ],
    );
  }
}
