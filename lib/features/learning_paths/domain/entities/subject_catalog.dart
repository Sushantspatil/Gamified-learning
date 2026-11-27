import 'package:equatable/equatable.dart';

/// One chapter of a [SubjectCatalog], with how many questions each game mode
/// has in it (keys are backend game modes: `mcq`, `sudden_death`,
/// `sort_it_out`, `match_the_following`; Match counts pairs).
class CatalogChapter extends Equatable {
  final int chapterNo;
  final String title;
  final Map<String, int> counts;

  const CatalogChapter({
    required this.chapterNo,
    required this.title,
    this.counts = const {},
  });

  int countFor(String backendGameMode) => counts[backendGameMode] ?? 0;

  bool get hasContent => counts.values.any((n) => n > 0);

  @override
  List<Object?> get props => [chapterNo, title, counts];
}

/// A subject exactly as the server's database has it (`GET /subjects`).
class SubjectCatalog extends Equatable {
  /// Backend subject code (`subjects.code`), e.g. `accounts`, `maths2`.
  final String code;
  final String name;
  final int grade;
  final List<CatalogChapter> chapters;

  /// True for a topic-pack subject the player does not own yet.
  final bool locked;

  const SubjectCatalog({
    required this.code,
    required this.name,
    required this.grade,
    required this.chapters,
    this.locked = false,
  });

  /// Questions of a game mode across all chapters.
  int countFor(String backendGameMode) =>
      chapters.fold(0, (sum, c) => sum + c.countFor(backendGameMode));

  CatalogChapter? chapter(int chapterNo) {
    for (final c in chapters) {
      if (c.chapterNo == chapterNo) return c;
    }
    return null;
  }

  @override
  List<Object?> get props => [code, name, grade, chapters, locked];
}
