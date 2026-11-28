import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../app/theme/app_colors.dart';

/// Where a friend gets the app. The link works once the app is live on the
/// Play Store.
const String playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.skillverse.skillverse_app';

/// The game a result came from, with how it looks on the share card.
enum ShareMode {
  mcq('MCQ Quiz', Icons.quiz_rounded, AppColors.primary),
  sortItOut('Sort It Out', Icons.view_column_rounded, AppColors.secondary),
  match('Match the Following', Icons.link_rounded, AppColors.violet),
  suddenDeath(
    'Sudden Death',
    Icons.local_fire_department_rounded,
    AppColors.streakFire,
  );

  final String label;
  final IconData icon;
  final Color color;
  const ShareMode(this.label, this.icon, this.color);
}

/// What a result screen shares: the numbers on the card and in the message.
@immutable
class ShareResult {
  final ShareMode mode;
  final int points;

  /// Right answers (cards sorted, pairs matched) out of [total].
  final int correct;
  final int total;

  /// 0..1.
  final double accuracy;
  final Duration? time;

  const ShareResult({
    required this.mode,
    required this.points,
    required this.correct,
    required this.total,
    required this.accuracy,
    this.time,
  });

  bool get isSuddenDeath => mode == ShareMode.suddenDeath;

  bool get isPerfect =>
      !isSuddenDeath && total > 0 && correct >= total && accuracy >= 0.999;

  /// The big word on the card.
  String get headline {
    if (isSuddenDeath) {
      return switch (correct) {
        0 => 'BRAVE ATTEMPT',
        < 5 => 'SURVIVED $correct',
        < 10 => 'SURVIVED $correct!',
        _ => 'UNSTOPPABLE',
      };
    }
    if (isPerfect) return 'PERFECT SCORE';
    if (accuracy >= 0.8) return 'GREAT GAME';
    if (accuracy >= 0.5) return 'GOOD GAME';
    return 'LEVELLING UP';
  }

  /// The challenge at the bottom of the card.
  String get challenge {
    if (isSuddenDeath) return 'Can you last longer?';
    if (isPerfect) return 'Bet you can’t match it!';
    if (accuracy >= 0.5) return 'Can you beat me?';
    return 'Join me and let’s compete!';
  }
}

/// The text sent with the card: a line that fits the result, then the link.
String shareMessage(ShareResult r) {
  final right = r.total > 0 ? '${r.correct}/${r.total}' : '${r.points} points';
  final mode = r.mode.label;
  final line = switch (r) {
    _ when r.isSuddenDeath && r.correct == 0 =>
      'I just tried Sudden Death on SkillVerse 💀 One wrong answer and '
          'you’re out. Think you can survive longer?',
    _ when r.isSuddenDeath =>
      'I survived ${r.correct} question${r.correct == 1 ? '' : 's'} in '
          'Sudden Death on SkillVerse 💀 One wrong answer and you’re out. '
          'Can you last longer?',
    _ when r.isPerfect =>
      'Perfect score! 🏆 $right in $mode on SkillVerse. Bet you can’t '
          'match it.',
    _ when r.accuracy >= 0.8 =>
      'I scored $right in $mode on SkillVerse 🔥 Can you beat me? 👀',
    _ when r.accuracy >= 0.5 =>
      'I scored $right in $mode on SkillVerse 💪 Think you can do better?',
    _ =>
      'I’m levelling up my Commerce skills on SkillVerse 📚 ($right in '
          '$mode). Join me and let’s see who scores higher!',
  };
  return '$line\n\nCommerce quizzes for Class 11 & 12. Play free: '
      '$playStoreUrl';
}

/// Opens the phone's share sheet with text only. Best effort: a phone that
/// cannot share just does nothing.
Future<void> shareText(String text) async {
  try {
    await SharePlus.instance.share(ShareParams(text: text));
  } catch (e) {
    debugPrint('Could not share: $e');
  }
}

/// Shares [boundaryKey]'s picture (the card) with [text] as its caption.
/// Falls back to the text alone when the picture cannot be made.
Future<void> shareCard(GlobalKey boundaryKey, String text) async {
  Uint8List? png;
  try {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary != null) {
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      png = data?.buffer.asUint8List();
    }
  } catch (e) {
    debugPrint('Could not draw the share card: $e');
  }
  if (png == null) return shareText(text);
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: [
          XFile.fromData(
            png,
            mimeType: 'image/png',
            name: 'skillverse-result.png',
          ),
        ],
        fileNameOverrides: const ['skillverse-result.png'],
      ),
    );
  } catch (e) {
    debugPrint('Could not share the card: $e');
    await shareText(text);
  }
}

/// The picture that is shared: a 9:16 card (story/status size, 1080 x 1920
/// when shared) with the SkillVerse art, the result and a challenge.
///
/// Draws the same in light and dark mode; it never reads the app theme's
/// colours, so the picture always looks the same.
class ResultShareCard extends StatelessWidget {
  static const Size size = Size(360, 640);
  static const String background =
      'assets/images/splash/skillverse_splash_no_loader.png';

  final ShareResult result;

  /// The player's first name; null says "I".
  final String? playerName;

  const ResultShareCard({super.key, required this.result, this.playerName});

  @override
  Widget build(BuildContext context) {
    final accent = result.mode.color;
    final gold = result.isPerfect ? AppColors.accentGold : accent;
    final who = (playerName == null || playerName!.trim().isEmpty)
        ? 'I'
        : playerName!.trim();

    return MediaQuery(
      // The card is a fixed picture: ignore the phone's text size.
      data:
          MediaQuery.maybeOf(
            context,
          )?.copyWith(textScaler: TextScaler.noScaling) ??
          const MediaQueryData(),
      child: SizedBox.fromSize(
        size: size,
        // Its own text style, so the picture never depends on where it is
        // drawn (no Material above it means debug-underlined text).
        child: Material(
          type: MaterialType.transparency,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF0B0820)),
                Image.asset(
                  background,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                // Darken the lower part so the result reads clearly.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.38, 0.62, 1.0],
                      colors: [
                        Color(0x00000000),
                        Color(0x11000000),
                        Color(0xD90B0820),
                        Color(0xFA0B0820),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: _ModeChip(mode: result.mode),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _ResultPanel(
                    result: result,
                    who: who,
                    accent: accent,
                    highlight: gold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final ShareMode mode;
  const _ModeChip({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: mode.color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(mode.icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              mode.label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final ShareResult result;
  final String who;
  final Color accent;
  final Color highlight;

  const _ResultPanel({
    required this.result,
    required this.who,
    required this.accent,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final time = result.time;
    final stats = <Widget>[
      if (result.isSuddenDeath)
        _Stat(
          icon: Icons.local_fire_department_rounded,
          color: AppColors.streakFire,
          value: '${result.correct}',
          label: 'SURVIVED',
        )
      else if (result.total > 0)
        _Stat(
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF34D399),
          value: '${result.correct}/${result.total}',
          label: 'CORRECT',
        ),
      if (!result.isSuddenDeath)
        _Stat(
          icon: Icons.track_changes_rounded,
          color: AppColors.secondaryLight,
          value: '${(result.accuracy * 100).round()}%',
          label: 'ACCURACY',
        ),
      if (time != null && time > Duration.zero)
        _Stat(
          icon: Icons.timer_rounded,
          color: AppColors.primaryLight,
          value: _formatTime(time),
          label: 'TIME',
        ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF17123A).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                result.isPerfect
                    ? Icons.emoji_events_rounded
                    : Icons.auto_awesome_rounded,
                size: 18,
                color: highlight,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  result.headline,
                  key: const Key('share_card_headline'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlight,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$who scored',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${result.points}',
                  key: const Key('share_card_points'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 60,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: highlight.withValues(alpha: 0.8),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'pts',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: stats[i]),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            result.challenge,
            key: const Key('share_card_challenge'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Commerce quizzes for Class 11 & 12',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 20,
                    color: Color(0xFF17123A),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Play free on Google Play',
                    style: TextStyle(
                      color: Color(0xFF17123A),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// The share sheet: a preview of the card, and buttons to share it (picture
/// with the message) or the message alone.
Future<void> showShareResultSheet(
  BuildContext context, {
  required ShareResult result,
  String? playerName,
}) async {
  // Start decoding the background now; it is ready long before the player
  // taps Share in the sheet.
  precacheImage(
    const AssetImage(ResultShareCard.background),
    context,
    onError: (_, _) {},
  );
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0B0820),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _ShareSheet(result: result, playerName: playerName),
  );
}

class _ShareSheet extends StatefulWidget {
  final ShareResult result;
  final String? playerName;
  const _ShareSheet({required this.result, this.playerName});

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share({required bool withCard}) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final text = shareMessage(widget.result);
    try {
      if (withCard) {
        await shareCard(_cardKey, text);
      } else {
        await shareText(text);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final previewHeight = (screen.height * 0.6).clamp(
      220.0,
      ResultShareCard.size.height,
    );

    return SafeArea(
      key: const Key('share_result_sheet'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Challenge your friends',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: previewHeight,
              child: FittedBox(
                child: RepaintBoundary(
                  key: _cardKey,
                  child: ResultShareCard(
                    result: widget.result,
                    playerName: widget.playerName,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('share_result_card'),
                onPressed: _sharing ? null : () => _share(withCard: true),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.result.mode.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.share_rounded),
                label: const Text(
                  'Share',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            TextButton(
              key: const Key('share_result_text'),
              onPressed: _sharing ? null : () => _share(withCard: false),
              child: const Text(
                'Send the message without the picture',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
