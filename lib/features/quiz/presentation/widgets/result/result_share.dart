import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// The message shared from a result screen.
String shareMessage({
  required String modeName,
  required int score,
  int? maxScore,
}) {
  final scoreText = (maxScore != null && maxScore > 0)
      ? '$score/$maxScore'
      : '$score';
  return 'I scored $scoreText in $modeName on SkillVerse! Can you beat me?';
}

/// Opens the phone's share sheet. Best effort: a phone that cannot share just
/// does nothing.
Future<void> shareText(String text) async {
  try {
    await SharePlus.instance.share(ShareParams(text: text));
  } catch (e) {
    debugPrint('Could not share: $e');
  }
}
