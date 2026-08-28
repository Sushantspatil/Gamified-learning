import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../domain/entities/spin_result.dart';
import '../../domain/entities/spin_wheel_segment.dart';
import '../providers/spin_wheel_providers.dart';
import '../widgets/spin_wheel_painter.dart';

class SpinWheelScreen extends ConsumerStatefulWidget {
  const SpinWheelScreen({super.key});

  @override
  ConsumerState<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends ConsumerState<SpinWheelScreen> {
  bool _isSpinning = false;
  SpinResult? _result;

  Future<void> _spin() async {
    setState(() {
      _isSpinning = true;
      _result = null;
    });
    final result = await ref.read(spinWheelControllerProvider.notifier).spin();
    if (!mounted) return;
    setState(() {
      _isSpinning = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final segmentsAsync = ref.watch(spinWheelSegmentsProvider);
    final availableAsync = ref.watch(spinWheelControllerProvider);
    final colors = context.themeColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spin Wheel'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: segmentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(
              'Could not load the spin wheel.',
              style: context.appTextStyles.bodyLarge,
            ),
          ),
          data: (segments) {
            SpinWheelSegment? winner;
            if (_result != null) {
              for (final segment in segments) {
                if (segment.id == _result!.segmentId) winner = segment;
              }
            }

            return ListView(
              padding: AppSpacing.paddingLg,
              children: [
                SizedBox(
                  height: 220,
                  width: 220,
                  child: Center(
                    child: SizedBox(
                      height: 200,
                      width: 200,
                      child: CustomPaint(
                        painter: SpinWheelPainter(
                          segments: segments,
                          highlightedSegmentId: winner?.id,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final segment in segments)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.cardBackground,
                          borderRadius: AppDimensions.radiusLg,
                          border: Border.all(
                            color: winner?.id == segment.id
                                ? colors.primary
                                : colors.border,
                            width: winner?.id == segment.id ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          segment.label,
                          style: context.appTextStyles.labelLarge,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (winner != null)
                  Center(
                    child: Text(
                      'You won ${winner.label}!',
                      style: context.appTextStyles.titleLarge,
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                availableAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Text(
                    'Could not check spin availability.',
                    style: context.appTextStyles.bodyLarge,
                  ),
                  data: (isAvailable) {
                    if (!isAvailable) {
                      return Center(
                        child: Text(
                          'Come back tomorrow for your next spin.',
                          textAlign: TextAlign.center,
                          style: context.appTextStyles.bodyLarge,
                        ),
                      );
                    }
                    return AppButton(
                      label: 'Spin',
                      isLoading: _isSpinning,
                      onPressed: _spin,
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
