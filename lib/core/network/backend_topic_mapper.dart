/// Maps frontend topic identifiers to backend subject codes (`subjects.code`).
///
/// Backend subjects (grade 11): `accounts`, `economics`, `maths1`, `maths2`,
/// `mental_maths` (chapters 1-3 = Easy/Medium/Hard levels).
/// `GET /subjects` lists them with chapters and per-game question counts.
/// Unrelated topics (e.g. 'web-dev', 'python') keep their original ID.
library;

// ---- Ids built from the server's subject catalog (`GET /subjects`) ----------

/// Topic id that plays a whole subject (all chapters mixed), e.g. `accounts--all`.
String catalogSubjectTopicId(String subjectCode) => '$subjectCode--all';

/// Topic id that plays one chapter of a subject, e.g. `accounts--ch4`.
String catalogChapterTopicId(String subjectCode, int chapterNo) =>
    '$subjectCode--ch$chapterNo';

/// Chapter id (Learn / Play pickers) for "all chapters" of a subject.
String catalogAllChaptersId(String subjectCode) => '$subjectCode--all-chapters';

/// Chapter id (Learn / Play pickers) for one chapter of a subject.
String catalogChapterId(String subjectCode, int chapterNo) =>
    '$subjectCode--chapter-$chapterNo';

final _catalogTopicPattern = RegExp(r'^([a-z0-9_]+)--(?:all|ch(\d{1,2}))$');
final _catalogChapterPattern = RegExp(
  r'^([a-z0-9_]+)--(?:all-chapters|chapter-(\d{1,2}))$',
);

/// A subject code and optional chapter (null = whole subject).
typedef CatalogRef = ({String subjectCode, int? chapterNo});

CatalogRef? _parse(RegExp pattern, String id) {
  final m = pattern.firstMatch(id.trim().toLowerCase());
  if (m == null) return null;
  final chapter = m.group(2);
  return (
    subjectCode: m.group(1)!,
    chapterNo: chapter == null ? null : int.parse(chapter),
  );
}

/// Parses a topic id made by [catalogSubjectTopicId] / [catalogChapterTopicId].
CatalogRef? parseCatalogTopicId(String id) => _parse(_catalogTopicPattern, id);

/// Parses a chapter id made by [catalogAllChaptersId] / [catalogChapterId].
CatalogRef? parseCatalogChapterId(String id) =>
    _parse(_catalogChapterPattern, id);

/// Learning path ids the app used before subjects came from the server. They
/// are kept for these subjects so saved selections and profiles still match.
const _legacyLearningPathIds = {
  'accounts': 'accounting',
  'maths1': 'maths',
  'mental_maths': 'mental-maths',
};

/// The learning path id shown in the app for a backend subject code.
String learningPathIdForSubjectCode(String subjectCode) =>
    _legacyLearningPathIds[subjectCode] ?? subjectCode;

/// The backend subject code of a learning path id (inverse of
/// [learningPathIdForSubjectCode]).
String subjectCodeForLearningPathId(String learningPathId) {
  final id = learningPathId.trim().toLowerCase();
  for (final entry in _legacyLearningPathIds.entries) {
    if (entry.value == id) return entry.key;
  }
  return id;
}

String mapToBackendTopicId(String frontendTopicId) {
  final catalog = parseCatalogTopicId(frontendTopicId);
  if (catalog != null) return catalog.subjectCode;
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
int? backendChapterNoForTopic(String frontendTopicId) {
  final catalog = parseCatalogTopicId(frontendTopicId);
  if (catalog != null) return catalog.chapterNo;
  return mentalMathsLevelTopics[frontendTopicId.trim().toLowerCase()];
}

/// Backend subjects with playable content in all four game modes.
const _playableBackendSubjects = {
  'accounts',
  'mental_maths',
  'maths1',
  'maths',
};

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
