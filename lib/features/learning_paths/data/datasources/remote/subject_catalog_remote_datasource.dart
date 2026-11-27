import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_endpoints.dart';
import '../../../../../core/network/backend_topic_mapper.dart';
import '../../../domain/entities/subject_catalog.dart';

/// Reads the subjects, chapters and per-mode question counts the database has.
abstract class SubjectCatalogDatasource {
  Future<List<SubjectCatalog>> getSubjects();
}

/// `GET /subjects`: `[{topic_id, name, grade, locked, chapters: [{chapter_no,
/// title, counts: {mcq: n, ...}}]}]`, ordered by the subjects' sort order.
class SubjectCatalogRemoteDatasource implements SubjectCatalogDatasource {
  final ApiClient _api;

  SubjectCatalogRemoteDatasource({required ApiClient apiClient})
    : _api = apiClient;

  @override
  Future<List<SubjectCatalog>> getSubjects() async {
    final data = await _api.get(ApiEndpoints.subjects);
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (item is Map<String, dynamic>) ?subjectCatalogFromJson(item),
    ];
  }
}

/// Parses one subject; returns null for a row without a code.
SubjectCatalog? subjectCatalogFromJson(Map<String, dynamic> json) {
  final code = (json['topic_id'] as String?)?.trim() ?? '';
  if (code.isEmpty) return null;
  final chapters = <CatalogChapter>[];
  final rawChapters = json['chapters'];
  if (rawChapters is List) {
    for (final c in rawChapters) {
      if (c is! Map<String, dynamic>) continue;
      final no = (c['chapter_no'] as num?)?.toInt();
      if (no == null) continue;
      final counts = <String, int>{};
      final rawCounts = c['counts'];
      if (rawCounts is Map) {
        rawCounts.forEach((mode, n) {
          if (mode is String && n is num) counts[mode] = n.toInt();
        });
      }
      final title = (c['title'] as String?)?.trim();
      chapters.add(
        CatalogChapter(
          chapterNo: no,
          title: title == null || title.isEmpty ? 'Chapter $no' : title,
          counts: counts,
        ),
      );
    }
  }
  chapters.sort((a, b) => a.chapterNo.compareTo(b.chapterNo));
  final name = (json['name'] as String?)?.trim();
  return SubjectCatalog(
    code: code,
    name: name == null || name.isEmpty ? code : name,
    grade: (json['grade'] as num?)?.toInt() ?? 0,
    chapters: chapters,
    locked: json['locked'] as bool? ?? false,
  );
}

/// Loads the catalog once and shares it (the content only changes when the
/// database is re-seeded). A failed load is retried on the next call.
class SubjectCatalogRepository {
  final SubjectCatalogDatasource _datasource;
  Future<List<SubjectCatalog>>? _pending;

  SubjectCatalogRepository(this._datasource);

  Future<List<SubjectCatalog>> load() {
    return _pending ??= _datasource.getSubjects().catchError((Object e) {
      _pending = null;
      throw e;
    });
  }

  /// The subject behind a learning path id or subject code, if any.
  Future<SubjectCatalog?> subjectFor(String learningPathOrCode) async {
    final subjects = await load();
    final id = learningPathOrCode.trim().toLowerCase();
    for (final s in subjects) {
      if (s.code == id) return s;
    }
    final mapped = subjectCodeForLearningPathId(id);
    for (final s in subjects) {
      if (s.code == mapped) return s;
    }
    return null;
  }
}
