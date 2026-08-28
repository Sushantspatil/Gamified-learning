import '../../models/chapter_model.dart';
import '../../models/topic_model.dart';
import '../chapter_datasource.dart';

/// MOCK DATA — replace the binding in chapter_providers.dart with a
/// Firestore-backed implementation when the backend is ready. Do not extend
/// this class with production logic.
class ChapterMockDatasource implements ChapterDatasource {
  static final Map<String, List<String>> _chapterTitlesByPath = {
    'web-dev': ['HTML Foundations', 'CSS & Layout', 'JavaScript Essentials'],
    'data-science': [
      'Statistics Basics',
      'Python for Data',
      'Data Visualization',
    ],
    'ai-ml': ['Linear Algebra', 'Neural Networks', 'Model Training'],
    'cybersecurity': [
      'Network Fundamentals',
      'Threats & Attacks',
      'Cryptography Basics',
    ],
  };

  static final Map<String, List<String>> _topicTitlesByChapter = {
    'HTML Foundations': [
      'Tags & Elements',
      'Forms',
      'Semantic HTML',
      'Accessibility',
    ],
    'CSS & Layout': ['Selectors', 'Flexbox', 'Grid', 'Responsive Design'],
    'JavaScript Essentials': [
      'Variables & Types',
      'Functions',
      'DOM Manipulation',
      'Async/Await',
    ],
    'Statistics Basics': [
      'Mean & Median',
      'Distributions',
      'Correlation',
      'Hypothesis Testing',
    ],
    'Python for Data': [
      'NumPy Arrays',
      'Pandas DataFrames',
      'Data Cleaning',
      'Aggregation',
    ],
    'Data Visualization': [
      'Chart Types',
      'Matplotlib',
      'Dashboards',
      'Storytelling with Data',
    ],
    'Linear Algebra': [
      'Vectors',
      'Matrices',
      'Eigenvalues',
      'Matrix Multiplication',
    ],
    'Neural Networks': [
      'Perceptrons',
      'Activation Functions',
      'Backpropagation',
      'CNNs',
    ],
    'Model Training': [
      'Loss Functions',
      'Optimizers',
      'Overfitting',
      'Deployment',
    ],
    'Network Fundamentals': ['OSI Model', 'TCP/IP', 'Firewalls', 'VPNs'],
    'Threats & Attacks': ['Phishing', 'Malware', 'DDoS', 'Social Engineering'],
    'Cryptography Basics': [
      'Symmetric Keys',
      'Asymmetric Keys',
      'Hashing',
      'Digital Signatures',
    ],
  };

  List<ChapterModel> _buildChapters(String learningPathId) {
    final titles = _chapterTitlesByPath[learningPathId] ?? const [];
    return List.generate(titles.length, (index) {
      final title = titles[index];
      return ChapterModel(
        id: '$learningPathId-chapter-${index + 1}',
        learningPathId: learningPathId,
        title: title,
        description: 'Learn the core concepts of $title.',
        order: index + 1,
        topicCount: _topicTitlesByChapter[title]?.length ?? 0,
      );
    });
  }

  @override
  Future<List<ChapterModel>> getChapters(String learningPathId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _buildChapters(learningPathId);
  }

  @override
  Future<ChapterModel?> getChapterById(String chapterId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    for (final pathId in _chapterTitlesByPath.keys) {
      for (final chapter in _buildChapters(pathId)) {
        if (chapter.id == chapterId) return chapter;
      }
    }
    return null;
  }

  @override
  Future<List<TopicModel>> getTopics(String chapterId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final chapter = await getChapterById(chapterId);
    if (chapter == null) return [];

    final titles = _topicTitlesByChapter[chapter.title] ?? const [];
    return List.generate(titles.length, (index) {
      return TopicModel(
        id: '$chapterId-topic-${index + 1}',
        chapterId: chapterId,
        title: titles[index],
        order: index + 1,
        isCompleted: false,
      );
    });
  }
}
