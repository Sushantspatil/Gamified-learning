import 'package:flutter/material.dart';

import '../../../questions/domain/entities/answer.dart';
import '../../../questions/domain/entities/question.dart';

class McqQuestionView extends StatefulWidget {
  final McqQuestion question;
  final int currentIndex;
  final int totalQuestions;
  final int currentStreak;
  final int coins;
  final int energy;
  final VoidCallback onExit;
  final void Function(Answer answer) onSubmit;

  const McqQuestionView({
    super.key,
    required this.question,
    required this.currentIndex,
    required this.totalQuestions,
    required this.currentStreak,
    required this.coins,
    required this.energy,
    required this.onExit,
    required this.onSubmit,
  });

  @override
  State<McqQuestionView> createState() => _McqQuestionViewState();
}

class _McqQuestionViewState extends State<McqQuestionView> {
  String? _selectedOptionId;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _McqQuizColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          children: [
            QuizTopBar(
              coins: widget.coins,
              energy: widget.energy,
              onBack: widget.onExit,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    QuizProgressCard(
                      currentQuestion: widget.currentIndex + 1,
                      totalQuestions: widget.totalQuestions,
                      streak: widget.currentStreak,
                    ),
                    const SizedBox(height: 16),
                    QuestionCard(
                      question: widget.question,
                      selectedOptionId: _selectedOptionId,
                      onOptionSelected: (optionId) {
                        setState(() => _selectedOptionId = optionId);
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            _BottomActionArea(
              canSubmit: _selectedOptionId != null,
              onSubmit: _selectedOptionId == null
                  ? null
                  : () => widget.onSubmit(
                      McqAnswer(
                        questionId: widget.question.id,
                        selectedOptionId: _selectedOptionId!,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuizTopBar extends StatelessWidget {
  final int coins;
  final int energy;
  final VoidCallback onBack;

  const QuizTopBar({
    super.key,
    required this.coins,
    required this.energy,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          _SoftIconButton(icon: Icons.arrow_back_rounded, onPressed: onBack),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'MCQ Quiz',
                  style: TextStyle(
                    color: _McqQuizColors.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '✦ Science Basics ✦',
                  style: TextStyle(
                    color: _McqQuizColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatChip(
                icon: Icons.monetization_on_rounded,
                value: coins.toString(),
                iconColor: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              StatChip(
                icon: Icons.bolt_rounded,
                value: energy.toString(),
                iconColor: Color(0xFFFFB020),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color iconColor;

  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: _McqQuizDecoration.softCard(radius: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 17),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: _McqQuizColors.textDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class QuizProgressCard extends StatelessWidget {
  final int currentQuestion;
  final int totalQuestions;
  final int streak;

  const QuizProgressCard({
    super.key,
    required this.currentQuestion,
    required this.totalQuestions,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalQuestions == 0
        ? 0.0
        : currentQuestion / totalQuestions;
    final percent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _McqQuizDecoration.softCard(radius: 20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Question',
                      style: TextStyle(
                        color: _McqQuizColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$currentQuestion / $totalQuestions',
                      style: const TextStyle(
                        color: _McqQuizColors.textDark,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Streak',
                    style: TextStyle(
                      color: _McqQuizColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.deepOrangeAccent.shade200,
                        size: 20,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        streak.toString(),
                        style: const TextStyle(
                          color: _McqQuizColors.textDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    color: _McqQuizColors.primary,
                    backgroundColor: _McqQuizColors.progressTrack,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: _McqQuizColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QuestionCard extends StatelessWidget {
  final McqQuestion question;
  final String? selectedOptionId;
  final ValueChanged<String> onOptionSelected;

  const QuestionCard({
    super.key,
    required this.question,
    required this.selectedOptionId,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: _McqQuizDecoration.softCard(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _Badge(icon: Icons.star_rounded, label: 'Challenge'),
              const Spacer(),
              _Badge(label: '+${question.points} XP'),
            ],
          ),
          const SizedBox(height: 18),
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 68),
                child: Text(
                  question.prompt,
                  style: const TextStyle(
                    color: _McqQuizColors.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.45,
                  ),
                ),
              ),
              const Positioned(
                right: 8,
                top: 10,
                child: Icon(
                  Icons.science_outlined,
                  color: _McqQuizColors.scienceIcon,
                  size: 66,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          for (var index = 0; index < question.options.length; index++) ...[
            McqOptionTile(
              label: String.fromCharCode(65 + index),
              text: question.options[index].text,
              isSelected: question.options[index].id == selectedOptionId,
              onTap: () => onOptionSelected(question.options[index].id),
            ),
            if (index != question.options.length - 1)
              const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class McqOptionTile extends StatelessWidget {
  final String label;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const McqOptionTile({
    super.key,
    required this.label,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? _McqQuizColors.optionSelectedBorder
        : _McqQuizColors.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? _McqQuizColors.optionSelectedBackground
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x146C5CE7),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? _McqQuizColors.primary
                      : _McqQuizColors.optionBadge,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? null
                      : Border.all(color: _McqQuizColors.border),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : _McqQuizColors.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: _McqQuizColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GradientSubmitButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const GradientSubmitButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? const [
                      _McqQuizColors.secondaryPurple,
                      _McqQuizColors.primary,
                    ]
                  : const [Color(0xFFC8C4EE), Color(0xFFB8B1E7)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x336C5CE7),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Submit Answer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 46),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 25),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomActionArea extends StatelessWidget {
  final bool canSubmit;
  final VoidCallback? onSubmit;

  const _BottomActionArea({required this.canSubmit, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding + 10, top: 2),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 44, height: 44, child: _GiftButton()),
              const SizedBox(width: 12),
              Expanded(child: GradientSubmitButton(onPressed: onSubmit)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            canSubmit ? 'Ready to submit' : 'Select the correct answer',
            style: const TextStyle(
              color: _McqQuizColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SoftIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 38,
          height: 38,
          decoration: _McqQuizDecoration.softCard(radius: 19),
          child: Icon(icon, color: _McqQuizColors.textDark, size: 21),
        ),
      ),
    );
  }
}

class _GiftButton extends StatelessWidget {
  const _GiftButton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _McqQuizDecoration.softCard(radius: 14),
      child: const Icon(
        Icons.card_giftcard_rounded,
        color: _McqQuizColors.primary,
        size: 23,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _Badge({this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _McqQuizColors.badgeBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: _McqQuizColors.primary, size: 15),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: _McqQuizColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _McqQuizDecoration {
  _McqQuizDecoration._();

  static BoxDecoration softCard({required double radius}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _McqQuizColors.border),
      boxShadow: const [
        BoxShadow(
          color: _McqQuizColors.shadow,
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    );
  }
}

class _McqQuizColors {
  _McqQuizColors._();

  static const Color primary = Color(0xFF6C5CE7);
  static const Color secondaryPurple = Color(0xFF8B5CF6);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE5E7EB);
  static const Color badgeBackground = Color(0xFFF1EDFF);
  static const Color progressTrack = Color(0xFFEDE9FE);
  static const Color optionSelectedBackground = Color(0xFFFAF8FF);
  static const Color optionSelectedBorder = Color(0xFFB8A7FF);
  static const Color optionBadge = Color(0xFFF1F5F9);
  static const Color scienceIcon = Color(0xFFE5DCFF);
  static const Color shadow = Color(0x120F172A);
}
