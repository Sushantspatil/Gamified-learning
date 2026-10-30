/// Maps frontend topic identifiers to backend subject codes (`subjects.code`).
///
/// Backend subjects (grade 11): `accounts`, `economics`, `maths1`, `maths2`,
/// `mental_maths` (chapters 1-3 = Easy/Medium/Hard levels).
/// `GET /subjects` lists them with chapters and per-game question counts.
/// Unrelated topics (e.g. 'web-dev', 'python') keep their original ID.
library;

String mapToBackendTopicId(String frontendTopicId) {
  final trimmed = frontendTopicId.trim().toLowerCase();
  if (trimmed.startsWith('mental-maths')) {
    return 'mental_maths';
  }
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
      trimmed.contains('matiks') ||
      trimmed.contains('math')) {
    return 'maths1';
  }
  return frontendTopicId;
}

/// Mental Maths level topics and the backend chapter each one plays.
const mentalMathsLevelTopics = {
  'mental-maths-easy': 1,
  'mental-maths-medium': 2,
  'mental-maths-hard': 3,
};

/// Backend `chapter_no` a frontend topic is limited to, or null for the whole subject.
int? backendChapterNoForTopic(String frontendTopicId) =>
    mentalMathsLevelTopics[frontendTopicId.trim().toLowerCase()];

/// Backend subjects with playable content in all four game modes.
const _playableBackendSubjects = {'accounts', 'mental_maths'};

/// Returns whether the topic maps to a backend subject playable in every game mode.
bool isBackendPlayableTopic(String? topicId) {
  if (topicId == null || topicId.trim().isEmpty) return false;
  return _playableBackendSubjects.contains(mapToBackendTopicId(topicId));
}

/// Returns whether the given frontend topic maps to backend-supported data.
bool isBackendSupportedTopic(String? topicId) {
  if (topicId == null || topicId.trim().isEmpty) return false;
  final mapped = mapToBackendTopicId(topicId);
  return mapped == 'accounts' ||
      mapped == 'accounting' ||
      mapped == 'maths' ||
      mapped == 'maths1';
}

/// Returns whether the given frontend topic maps to backend Accounts content.
/// Preserved for backward compatibility.
bool isBackendSupportedAccountingTopic(String? topicId) {
  return isBackendSupportedTopic(topicId);
}

