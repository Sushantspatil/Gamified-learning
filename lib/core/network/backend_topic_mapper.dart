/// Maps frontend topic identifiers to backend subject codes (`subjects.code`).
///
/// Backend subjects (grade 11): `accounts`, `economics`, `maths1`, `maths2`.
/// `GET /subjects` lists them with chapters and per-game question counts.
/// Unrelated topics (e.g. 'web-dev', 'python') keep their original ID.
library;

String mapToBackendTopicId(String frontendTopicId) {
  final trimmed = frontendTopicId.trim().toLowerCase();
  if (trimmed.contains('accounting') || trimmed.contains('accounts')) {
    return 'accounts';
  }
  if (trimmed.contains('economics')) {
    return 'economics';
  }
  if (trimmed == 'maths2' ||
      trimmed == 'maths-2' ||
      trimmed.contains('statistics')) {
    return 'maths2';
  }
  if (trimmed == 'math' ||
      trimmed == 'maths' ||
      trimmed == 'maths1' ||
      trimmed == 'maths-1' ||
      trimmed.contains('matiks')) {
    return 'maths1';
  }
  return frontendTopicId;
}

/// Returns whether the given frontend topic maps to backend Accounts content.
bool isBackendSupportedAccountingTopic(String? topicId) {
  if (topicId == null || topicId.trim().isEmpty) return false;
  return mapToBackendTopicId(topicId) == 'accounts';
}
