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
  return frontendTopicId;
}

/// Returns whether the given frontend topic maps to backend-supported Accounting data.
bool isBackendSupportedAccountingTopic(String? topicId) {
  if (topicId == null || topicId.trim().isEmpty) return false;
  return mapToBackendTopicId(topicId) == 'accounting';
}
