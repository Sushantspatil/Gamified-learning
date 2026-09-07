import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_progress_bar.dart';
import '../../../../shared/widgets/theme_mode_menu.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

class HowToPlayTutorialScreen extends ConsumerStatefulWidget {
  const HowToPlayTutorialScreen({super.key});

  @override
  ConsumerState<HowToPlayTutorialScreen> createState() =>
      _HowToPlayTutorialScreenState();
}

class _HowToPlayTutorialScreenState
    extends ConsumerState<HowToPlayTutorialScreen> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompleting = ref.watch(profileControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Play'),
        actions: const [ThemeModeMenu()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.paddingMd,
              child: AppProgressBar(
                value: (_index + 1) / _slides.length,
                height: 7,
                semanticLabel: 'Tutorial progress',
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) =>
                    _TutorialSlideCard(slide: _slides[index]),
              ),
            ),
            Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Skip',
                      variant: AppButtonVariant.text,
                      isLoading: isCompleting,
                      onPressed: _finish,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: _isLast ? 'Start Learning' : 'Next',
                      isLoading: isCompleting,
                      onPressed: _isLast ? _finish : _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isLast => _index == _slides.length - 1;

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    await ref.read(profileControllerProvider.notifier).completeTutorial();
    if (mounted) context.go(RouteNames.dashboard);
  }
}

class _TutorialSlideCard extends StatelessWidget {
  final _TutorialSlide slide;

  const _TutorialSlideCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;

    return SingleChildScrollView(
      padding: AppSpacing.horizontalMd,
      child: AppCard(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: slide.color(colors).withValues(alpha: 0.14),
                borderRadius: AppDimensions.radiusLg,
              ),
              child: Icon(slide.icon, color: slide.color(colors), size: 44),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(slide.title, style: context.appTextStyles.displayMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(slide.description, style: context.appTextStyles.bodyMedium),
            if (slide.chips.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final chip in slide.chips)
                    Chip(avatar: Icon(slide.icon, size: 16), label: Text(chip)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TutorialSlide {
  final String title;
  final String description;
  final IconData icon;
  final Color Function(AppThemeColors colors) color;
  final List<String> chips;

  const _TutorialSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.chips = const [],
  });
}

final _slides = [
  _TutorialSlide(
    title: 'Learn at Your Pace',
    description:
        'Explore subjects, chapters and topics with structured learning material.',
    icon: Icons.menu_book_outlined,
    color: (colors) => colors.primary,
  ),
  _TutorialSlide(
    title: 'Play & Practice',
    description:
        'Choose a subject, chapter, topic and game mode to practice what you have learned.',
    icon: Icons.sports_esports_outlined,
    color: (colors) => colors.secondary,
    chips: const ['MCQ', 'Match the Following', 'Sort It Out', 'Sudden Death'],
  ),
  _TutorialSlide(
    title: 'Use Power-ups',
    description:
        'Use hints and special abilities during games when you need help.',
    icon: Icons.flash_on_outlined,
    color: (colors) => colors.violet,
    chips: const ['Hint', '50:50', 'Skip', '+5 Sec'],
  ),
  _TutorialSlide(
    title: 'Earn Rewards',
    description:
        'Earn XP, coins, gems and streak progress as you complete activities.',
    icon: Icons.emoji_events_outlined,
    color: (_) => AppColors.coinGold,
    chips: const ['XP', 'Coins', 'Gems', 'Streaks'],
  ),
  _TutorialSlide(
    title: 'Compete & Grow',
    description:
        'Improve your score, maintain streaks and climb the leaderboard.',
    icon: Icons.leaderboard_outlined,
    color: (colors) => colors.warning,
  ),
];
