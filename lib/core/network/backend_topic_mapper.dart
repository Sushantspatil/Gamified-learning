/// Central topic mapping for backend compatibility.
///
/// Maps frontend topic identifiers to backend-supported topic identifiers.
/// The backend currently seeds all multi-mode content under 'accounting'.
/// Frontend sub-topics under Accounting (e.g. 'accounting-basics', 'accounting-journal')
/// map to 'accounting'. Unrelated topics (e.g. 'web-dev', 'python') retain their original ID.
library;

String mapToBackendTopicId(String frontendTopicId) {
  final trimmed = frontendTopicId.trim().toLowerCase();
  if (trimmed.contains('accounting')) {
    return 'accounting';
  }
  if (trimmed == 'math' ||
      trimmed == 'maths' ||
      trimmed.contains('matiks') ||
      trimmed.contains('math')) {
    return 'maths';
  }
  return frontendTopicId;
}

/// Returns whether the given frontend topic maps to backend-supported data.
bool isBackendSupportedTopic(String? topicId) {
  if (topicId == null || topicId.trim().isEmpty) return false;
  final mapped = mapToBackendTopicId(topicId);
  return mapped == 'accounting' || mapped == 'maths';
}

/// Returns whether the given frontend topic maps to backend-supported data.
/// Preserved for backward compatibility.
bool isBackendSupportedAccountingTopic(String? topicId) {
  return isBackendSupportedTopic(topicId);
}

