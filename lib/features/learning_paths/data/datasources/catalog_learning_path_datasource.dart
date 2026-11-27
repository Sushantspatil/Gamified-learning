import '../../../../core/network/backend_topic_mapper.dart';
import '../../domain/entities/learning_path.dart';
import '../../domain/entities/subject_catalog.dart';
import '../models/learning_path_model.dart';
import 'learning_path_datasource.dart';
import 'remote/subject_catalog_remote_datasource.dart';

/// Learning paths = the subjects in the server's database, in its order.
class CatalogLearningPathDatasource implements LearningPathDatasource {
  final SubjectCatalogRepository Function() _catalog;

  const CatalogLearningPathDatasource(this._catalog);

  @override
  Future<List<LearningPathModel>> getLearningPaths() async {
    final subjects = await _catalog().load();
    return [
      for (final s in subjects)
        if (s.chapters.any((c) => c.hasContent))
          LearningPathModel(
            id: learningPathIdForSubjectCode(s.code),
            title: s.name,
            description: describeSubject(s),
            difficulty: LearningPathDifficulty.beginner,
            topicCount: s.chapters.length,
          ),
    ];
  }
}

const _modeNames = {
  'mcq': 'MCQ',
  'sudden_death': 'Sudden Death',
  'sort_it_out': 'Sort It Out',
  'match_the_following': 'Match',
};

/// The game modes that have questions, e.g. "MCQ · Sort It Out".
String describeModes(int Function(String mode) countFor) {
  final modes = [
    for (final e in _modeNames.entries)
      if (countFor(e.key) > 0) e.value,
  ];
  return modes.isEmpty ? 'No questions yet' : modes.join(' · ');
}

/// "10 chapters · MCQ · Sudden Death · Sort It Out" (+ topic pack note).
String describeSubject(SubjectCatalog s) {
  final chapters = s.chapters.length == 1
      ? '1 chapter'
      : '${s.chapters.length} chapters';
  final text = '$chapters · ${describeModes(s.countFor)}';
  return s.locked ? 'Topic pack (unlock in Shop) · $text' : text;
}
