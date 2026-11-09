import 'package:flutter/material.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_theme_colors.dart';
import '../../../../../shared/widgets/app_button.dart';

/// The bar pinned to the bottom of a result screen, so the next move is always
/// one tap away. The first screen offers "Continue" (when a progress screen
/// follows) and the last offers "Play again" and "Done"; both can share the
/// score and open the score details.
class ResultActionBar extends StatelessWidget {
  final String primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback onPrimary;

  /// A quieter second button ("Done"), or null for none.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final VoidCallback? onShare;
  final VoidCallback? onDetails;

  const ResultActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.secondaryLabel,
    this.onSecondary,
    this.onShare,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  key: const Key('result_primary'),
                  label: primaryLabel,
                  leadingIcon: primaryIcon == null ? null : Icon(primaryIcon),
                  onPressed: onPrimary,
                ),
              ),
              if (secondaryLabel != null ||
                  onShare != null ||
                  onDetails != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    if (secondaryLabel != null)
                      Expanded(
                        child: AppButton(
                          key: const Key('result_secondary'),
                          label: secondaryLabel!,
                          variant: AppButtonVariant.secondary,
                          onPressed: onSecondary,
                        ),
                      )
                    else
                      const Spacer(),
                    if (onDetails != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(
                        key: const Key('result_details_button'),
                        onPressed: onDetails,
                        child: const Text('Score details'),
                      ),
                    ],
                    if (onShare != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.outlined(
                        key: const Key('result_share'),
                        tooltip: 'Share your score',
                        onPressed: onShare,
                        icon: const Icon(Icons.ios_share_rounded),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
