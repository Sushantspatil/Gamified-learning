import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/game_scaffold.dart';
import '../../../questions/data/datasources/mock/question_mock_datasource.dart';
import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';
import '../widgets/quiz_celebration_overlay.dart';
import '../widgets/sudden_death_question_view.dart';

/// Development-only UI harness for Sudden Death.
///
/// The route that builds this screen is omitted from release/profile builds.
/// It intentionally owns only preview progression and visual feedback; it does
/// not submit scores, rewards, streaks, wallet mutations, or backend actions.
class SuddenDeathDemoScreen extends StatefulWidget {
  const SuddenDeathDemoScreen({super.key});

  @override
  State<SuddenDeathDemoScreen> createState() => _SuddenDeathDemoScreenState();
}

class _SuddenDeathDemoScreenState extends State<SuddenDeathDemoScreen> {
  late final Future<List<SuddenDeathQuestion>> _questionsFuture;
  var _currentIndex = 0;
  var _previewStreak = 0;
  var _bestPreviewStreak = 0;
  _DemoResult? _result;

  @override
  void initState() {
    super.initState();
    _questionsFuture = QuestionMockDatasource()
        .getQuestionsForTopicAndType(
          'sudden-death-ui-preview',
          QuestionType.suddenDeath,
        )
        .then(
          (questions) => questions.whereType<SuddenDeathQuestion>().toList(),
        );
  }

  void _handleAnswer(List<SuddenDeathQuestion> questions, Answer answer) {
    if (answer is! SuddenDeathAnswer || _result != null) return;
    final question = questions[_currentIndex];
    final isPreviewCorrect =
        answer.selectedOptionId == question.correctOptionId;

    if (!isPreviewCorrect) {
      setState(() => _result = _DemoResult.eliminated);
      return;
    }

    final nextStreak = _previewStreak + 1;
    final nextBest = nextStreak > _bestPreviewStreak
        ? nextStreak
        : _bestPreviewStreak;
    if (_currentIndex + 1 >= questions.length) {
      setState(() {
        _previewStreak = nextStreak;
        _bestPreviewStreak = nextBest;
        _result = _DemoResult.cleared;
      });
      return;
    }

    setState(() {
      _previewStreak = nextStreak;
      _bestPreviewStreak = nextBest;
      _currentIndex++;
    });
  }

  void _handleSkip(List<SuddenDeathQuestion> questions) {
    if (_result != null) return;
    if (_currentIndex + 1 >= questions.length) {
      setState(() {
        _previewStreak = 0;
        _result = _DemoResult.cleared;
      });
      return;
    }
    setState(() {
      _previewStreak = 0;
      _currentIndex++;
    });
  }

  void _restartPreview() {
    setState(() {
      _currentIndex = 0;
      _previewStreak = 0;
      _bestPreviewStreak = 0;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      body: FutureBuilder<List<SuddenDeathQuestion>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _DemoMessage(
              title: 'Preview unavailable',
              body: 'The isolated Sudden Death demo questions could not load.',
              onExit: () => Navigator.of(context).maybePop(),
            );
          }

          final questions = snapshot.data ?? const [];
          if (questions.isEmpty) {
            return _DemoMessage(
              title: 'No preview questions',
              body:
                  'Add dedicated Sudden Death mock questions to the mock datasource.',
              onExit: () => Navigator.of(context).maybePop(),
            );
          }

          final result = _result;
          if (result != null) {
            return _SuddenDeathDemoResult(
              result: result,
              survivedQuestions: result == _DemoResult.eliminated
                  ? _currentIndex
                  : _currentIndex + 1,
              bestPreviewStreak: _bestPreviewStreak,
              onReplay: _restartPreview,
              onDone: () => Navigator.of(context).maybePop(),
            );
          }

          final question = questions[_currentIndex];
          return SuddenDeathQuestionView(
            key: ValueKey(question.id),
            question: question,
            currentIndex: _currentIndex,
            totalQuestions: questions.length,
            currentStreak: _previewStreak,
            bestStreak: _bestPreviewStreak,
            energy: 0,
            coins: 100,
            isPreviewMode: true,
            onExit: () => Navigator.of(context).maybePop(),
            onSubmit: (answer) => _handleAnswer(questions, answer),
            onSkip: () => _handleSkip(questions),
            onTimeout: () => setState(() => _result = _DemoResult.timeUp),
          );
        },
      ),
    );
  }
}

enum _DemoResult { cleared, eliminated, timeUp }

class _SuddenDeathDemoResult extends StatelessWidget {
  final _DemoResult result;
  final int survivedQuestions;
  final int bestPreviewStreak;
  final VoidCallback onReplay;
  final VoidCallback onDone;

  const _SuddenDeathDemoResult({
    required this.result,
    required this.survivedQuestions,
    required this.bestPreviewStreak,
    required this.onReplay,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final isCleared = result == _DemoResult.cleared;
    final title = switch (result) {
      _DemoResult.cleared => 'Sudden Death cleared',
      _DemoResult.eliminated => 'Eliminated',
      _DemoResult.timeUp => "Time's up",
    };
    final message = switch (result) {
      _DemoResult.cleared => 'You survived every preview question.',
      _DemoResult.eliminated => 'One wrong answer ended this preview run.',
      _DemoResult.timeUp => 'The preview timer reached zero.',
    };
    final accent = isCleared ? colors.success : colors.error;

    return QuizCelebrationOverlay(
      enabled: isCleared,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingMd,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AppCard(
                variant: AppCardVariant.tinted,
                tintColor: accent,
                padding: AppSpacing.paddingLg,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCleared
                          ? Icons.emoji_events_rounded
                          : result == _DemoResult.timeUp
                          ? Icons.timer_off_rounded
                          : Icons.dangerous_rounded,
                      color: accent,
                      size: 64,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'UI preview — no score or rewards were calculated',
                        textAlign: TextAlign.center,
                        style: context.appTextStyles.labelLarge.copyWith(
                          color: colors.warning,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _PreviewMetric(
                          icon: Icons.shield_rounded,
                          label: '$survivedQuestions survived',
                        ),
                        _PreviewMetric(
                          icon: Icons.whatshot_rounded,
                          label: 'Best preview streak $bestPreviewStreak',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(label: 'Replay preview', onPressed: onReplay),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Done',
                      variant: AppButtonVariant.text,
                      onPressed: onDone,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PreviewMetric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.streakFire, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: context.appTextStyles.labelLarge),
        ],
      ),
    );
  }
}

class _DemoMessage extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onExit;

  const _DemoMessage({
    required this.title,
    required this.body,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: context.appTextStyles.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(body, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'Back', onPressed: onExit),
            ],
          ),
        ),
      ),
    );
  }
}
