import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/network/api_client.dart';
import 'package:skillverse_app/core/network/api_config.dart';
import 'package:skillverse_app/core/network/backend_topic_mapper.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/core/storage/storage_keys.dart';
import 'package:skillverse_app/features/chapters/data/datasources/chapter_datasource.dart';
import 'package:skillverse_app/features/chapters/data/models/chapter_model.dart';
import 'package:skillverse_app/features/chapters/data/models/topic_model.dart';
import 'package:skillverse_app/features/chapters/presentation/providers/chapter_providers.dart';
import 'package:skillverse_app/features/learning_paths/data/datasources/learning_path_datasource.dart';
import 'package:skillverse_app/features/learning_paths/data/models/learning_path_model.dart';
import 'package:skillverse_app/features/learning_paths/domain/entities/learning_path.dart';
import 'package:skillverse_app/features/learning_paths/presentation/providers/learning_path_providers.dart';
import 'package:skillverse_app/features/practice/presentation/providers/practice_providers.dart';
import 'package:skillverse_app/features/practice/presentation/screens/practice_screen.dart';
import 'package:skillverse_app/features/questions/domain/entities/question.dart';
import 'package:skillverse_app/features/questions/presentation/providers/question_providers.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/quiz_remote_datasource.dart';
import 'package:skillverse_app/features/quiz/data/datasources/remote/sudden_death_remote_datasource.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/quiz_providers.dart';
import 'package:skillverse_app/features/quiz/presentation/providers/sudden_death_providers.dart';
import 'package:skillverse_app/shared/widgets/app_button.dart';

class _FakeLocalStorage implements LocalStorageService {
  final Map<String, String> _map = {StorageKeys.authToken: 'test-token'};

  @override
  String? getString(String key) => _map[key];

  @override
  Future<bool> setString(String key, String value) async {
    _map[key] = value;
    return true;
  }

  @override
  int? getInt(String key) => null;

  @override
  Future<bool> setInt(String key, int value) async => true;

  @override
  bool? getBool(String key) => null;

  @override
  Future<bool> setBool(String key, bool value) async => true;

  @override
  Future<bool> remove(String key) async {
    _map.remove(key);
    return true;
  }
}

class _TestLearningPathDatasource implements LearningPathDatasource {
  @override
  Future<List<LearningPathModel>> getLearningPaths() async {
    return const [
      LearningPathModel(
        id: 'accounting',
        title: 'Accounting & Finance',
        description: 'Test Accounting',
        difficulty: LearningPathDifficulty.beginner,
        topicCount: 1,
      ),
      LearningPathModel(
        id: 'web-dev',
        title: 'Web Development',
        description: 'Test Web Dev',
        difficulty: LearningPathDifficulty.beginner,
        topicCount: 1,
      ),
    ];
  }
}

class _TestChapterDatasource implements ChapterDatasource {
  @override
  Future<List<ChapterModel>> getChapters(String learningPathId) async {
    if (learningPathId == 'accounting') {
      return const [
        ChapterModel(
          id: 'accounting-basics',
          learningPathId: 'accounting',
          title: 'Basic Accounting',
          description: 'Basic Chapter',
          order: 1,
          topicCount: 1,
        ),
      ];
    }
    return const [
      ChapterModel(
        id: 'web-basics',
        learningPathId: 'web-dev',
        title: 'HTML & CSS',
        description: 'Web Chapter',
        order: 1,
        topicCount: 1,
      ),
    ];
  }

  @override
  Future<ChapterModel?> getChapterById(String chapterId) async => null;

  @override
  Future<List<TopicModel>> getTopics(String chapterId) async {
    if (chapterId == 'accounting-basics') {
      return const [
        TopicModel(
          id: 'accounting-ledger',
          chapterId: 'accounting-basics',
          title: 'General Ledger',
          order: 1,
          isCompleted: false,
        ),
      ];
    }
    return const [
      TopicModel(
        id: 'web-tags',
        chapterId: 'web-basics',
        title: 'HTML Tags',
        order: 1,
        isCompleted: false,
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Topic Mapping & Game Mode Strings', () {
    test(
      'mapToBackendTopicId maps frontend topics to backend subject codes',
      () {
        expect(mapToBackendTopicId('accounting'), 'accounts');
        expect(mapToBackendTopicId('accounting-basics'), 'accounts');
        expect(mapToBackendTopicId('accounting-journal'), 'accounts');
        expect(mapToBackendTopicId('Accounting-Ledger'), 'accounts');
        expect(mapToBackendTopicId('economics'), 'economics');
        expect(mapToBackendTopicId('maths'), 'maths1');
        expect(mapToBackendTopicId('statistics'), 'maths2');
      },
    );

    test('mapToBackendTopicId maps math sub-topics to maths1', () {
      expect(mapToBackendTopicId('math'), 'maths1');
      expect(mapToBackendTopicId('maths'), 'maths1');
      expect(mapToBackendTopicId('mathematics'), 'maths1');
      expect(mapToBackendTopicId('math-basics'), 'maths1');
    });

    test('mapToBackendTopicId preserves unrelated subjects', () {
      expect(mapToBackendTopicId('web-dev'), 'web-dev');
      expect(mapToBackendTopicId('python-basics'), 'python-basics');
      expect(mapToBackendTopicId('data-science'), 'data-science');
    });

    test(
      'isBackendSupportedAccountingTopic correctly identifies backend-supported topics',
      () {
        expect(isBackendSupportedAccountingTopic('accounting'), isTrue);
        expect(isBackendSupportedAccountingTopic('accounting-basics'), isTrue);
        expect(isBackendSupportedAccountingTopic('maths'), isTrue);
        expect(isBackendSupportedAccountingTopic('mathematics'), isTrue);
        expect(isBackendSupportedAccountingTopic('web-dev'), isFalse);
        expect(isBackendSupportedAccountingTopic(null), isFalse);
        expect(isBackendSupportedAccountingTopic(''), isFalse);
      },
    );

    test(
      'QuestionTypeBackendValue maps all modes to exact backend wire strings',
      () {
        expect(QuestionType.mcq.backendGameMode, 'mcq');
        expect(
          QuestionType.matchTheFollowing.backendGameMode,
          'match_the_following',
        );
        expect(QuestionType.sortItRight.backendGameMode, 'sort_it_out');
        expect(QuestionType.suddenDeath.backendGameMode, 'sudden_death');
      },
    );
  });

  group('gameModeAvailabilityProvider Unit Tests', () {
    test('Before topic selection: all game modes are disabled with reason', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final availability = container.read(gameModeAvailabilityProvider(null));

      for (final mode in practicePlayableModes) {
        expect(availability[mode]?.isEnabled, isFalse);
        expect(availability[mode]?.reason, 'Select a topic first');
      }
    });

    test('When accounting topic is selected: all 4 modes are enabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final availability = container.read(
        gameModeAvailabilityProvider('accounting-basics'),
      );

      expect(availability[QuestionType.mcq]?.isEnabled, isTrue);
      expect(availability[QuestionType.mcq]?.reason, isNull);

      expect(availability[QuestionType.matchTheFollowing]?.isEnabled, isTrue);
      expect(availability[QuestionType.matchTheFollowing]?.reason, isNull);

      expect(availability[QuestionType.sortItRight]?.isEnabled, isTrue);
      expect(availability[QuestionType.sortItRight]?.reason, isNull);

      expect(availability[QuestionType.suddenDeath]?.isEnabled, isTrue);
      expect(availability[QuestionType.suddenDeath]?.reason, isNull);
    });

    test(
      'When non-accounting topic is selected: all modes are disabled with helpful reason',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final availability = container.read(
          gameModeAvailabilityProvider('web-dev'),
        );

        for (final mode in practicePlayableModes) {
          expect(availability[mode]?.isEnabled, isFalse);
          expect(
            availability[mode]?.reason,
            'Not available for this topic yet',
          );
        }
      },
    );

    test(
      'CRITICAL REGRESSION: availability is independent of generic questionsForTopicProvider',
      () {
        final container = ProviderContainer(
          overrides: [
            questionsForTopicProvider('accounting').overrideWith(
              (ref) async => [
                const McqQuestion(
                  id: 'q1',
                  topicId: 'accounting',
                  prompt: 'What is cash?',
                  points: 10,
                  options: [
                    QuestionOption(id: 'a', text: 'Asset'),
                    QuestionOption(id: 'b', text: 'Liability'),
                  ],
                  correctOptionId: 'a',
                ),
              ],
            ),
          ],
        );
        addTearDown(container.dispose);

        final availability = container.read(
          gameModeAvailabilityProvider('accounting'),
        );
        expect(availability[QuestionType.mcq]?.isEnabled, isTrue);
        expect(availability[QuestionType.matchTheFollowing]?.isEnabled, isTrue);
        expect(availability[QuestionType.sortItRight]?.isEnabled, isTrue);
        expect(availability[QuestionType.suddenDeath]?.isEnabled, isTrue);
      },
    );
  });

  group('BackendChapterDatasource & LearningPathDatasource Catalog Tests', () {
    test(
      'BackendLearningPathDatasource returns all expected learning paths',
      () async {
        const ds = BackendLearningPathDatasource();
        final paths = await ds.getLearningPaths();
        final pathIds = paths.map((p) => p.id).toSet();

        expect(pathIds, contains('accounting'));
        expect(pathIds, contains('maths'));
        expect(pathIds, contains('mental-maths'));
      },
    );

    test(
      'BackendChapterDatasource returns chapters and topics for all supported paths',
      () async {
        const ds = BackendChapterDatasource();

        // Accounting
        final accountingChapters = await ds.getChapters('accounting');
        expect(accountingChapters, isNotEmpty);
        expect(accountingChapters.first.id, 'accounting-basics');
        final accountingTopics = await ds.getTopics(
          accountingChapters.first.id,
        );
        expect(accountingTopics, isNotEmpty);
        expect(accountingTopics.first.id, 'accounting');

        // Maths (and aliases)
        for (final mathAlias in ['maths', 'math', 'maths1']) {
          final mathChapters = await ds.getChapters(mathAlias);
          expect(
            mathChapters,
            isNotEmpty,
            reason: 'Failed for alias: $mathAlias',
          );
          expect(mathChapters.first.id, 'maths-basics');
          final mathTopics = await ds.getTopics(mathChapters.first.id);
          expect(mathTopics, isNotEmpty);
          expect(mathTopics.first.id, 'maths');
        }

        // Mental Maths
        final mentalChapters = await ds.getChapters('mental-maths');
        expect(mentalChapters, isNotEmpty);
        expect(mentalChapters.first.id, 'mental-maths-levels');
        final mentalTopics = await ds.getTopics(mentalChapters.first.id);
        expect(mentalTopics.length, 3);
        expect(
          mentalTopics.map((t) => t.id),
          containsAll([
            'mental-maths-easy',
            'mental-maths-medium',
            'mental-maths-hard',
          ]),
        );
      },
    );

    test(
      'BackendChapterDatasource falls back to mock chapters for other paths',
      () async {
        const ds = BackendChapterDatasource();
        final webChapters = await ds.getChapters('web-dev');
        expect(webChapters, isNotEmpty);
        final topics = await ds.getTopics(webChapters.first.id);
        expect(topics, isNotEmpty);
      },
    );
  });

  group('BackendChapterDatasource & LearningPathDatasource Catalog Tests', () {
    test('BackendLearningPathDatasource returns all expected learning paths', () async {
      const ds = BackendLearningPathDatasource();
      final paths = await ds.getLearningPaths();
      final pathIds = paths.map((p) => p.id).toSet();

      expect(pathIds, contains('accounting'));
      expect(pathIds, contains('maths'));
      expect(pathIds, contains('mental-maths'));
    });

    test('BackendChapterDatasource returns chapters and topics for all supported paths', () async {
      const ds = BackendChapterDatasource();

      // Accounting
      final accountingChapters = await ds.getChapters('accounting');
      expect(accountingChapters, isNotEmpty);
      expect(accountingChapters.first.id, 'accounting-basics');
      final accountingTopics = await ds.getTopics(accountingChapters.first.id);
      expect(accountingTopics, isNotEmpty);
      expect(accountingTopics.first.id, 'accounting');

      // Maths (and aliases)
      for (final mathAlias in ['maths', 'math', 'maths1']) {
        final mathChapters = await ds.getChapters(mathAlias);
        expect(mathChapters, isNotEmpty, reason: 'Failed for alias: $mathAlias');
        expect(mathChapters.first.id, 'maths-basics');
        final mathTopics = await ds.getTopics(mathChapters.first.id);
        expect(mathTopics, isNotEmpty);
        expect(mathTopics.first.id, 'maths');
      }

      // Mental Maths
      final mentalChapters = await ds.getChapters('mental-maths');
      expect(mentalChapters, isNotEmpty);
      expect(mentalChapters.first.id, 'mental-maths-levels');
      final mentalTopics = await ds.getTopics(mentalChapters.first.id);
      expect(mentalTopics.length, 3);
      expect(
        mentalTopics.map((t) => t.id),
        containsAll([
          'mental-maths-easy',
          'mental-maths-medium',
          'mental-maths-hard',
        ]),
      );
    });

    test('BackendChapterDatasource falls back to mock chapters for other paths', () async {
      const ds = BackendChapterDatasource();
      final webChapters = await ds.getChapters('web-dev');
      expect(webChapters, isNotEmpty);
      final topics = await ds.getTopics(webChapters.first.id);
      expect(topics, isNotEmpty);
    });
  });

  group('Play Setup Screen — UI & Interaction Tests', () {
    void setWindowSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
    }

    Widget buildPlayScreen({required ProviderContainer container}) {
      final router = GoRouter(
        initialLocation: '/play',
        routes: [
          GoRoute(
            path: '/play',
            builder: (context, state) => const PlaySetupScreen(),
          ),
          GoRoute(
            path: '/quiz/:topicId/:quizType',
            builder: (context, state) => Scaffold(
              body: Text(
                'Quiz Destination: ${state.pathParameters["quizType"]}',
              ),
            ),
          ),
          GoRoute(
            path: '/sudden-death/:topicId',
            builder: (context, state) =>
                const Scaffold(body: Text('Sudden Death Destination')),
          ),
        ],
      );

      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      );
    }

    testWidgets('Mode cards are disabled before selecting topic', (
      tester,
    ) async {
      setWindowSize(tester);
      final fakeStorage = _FakeLocalStorage();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(fakeStorage),
          learningPathDatasourceProvider.overrideWithValue(
            _TestLearningPathDatasource(),
          ),
          chapterDatasourceProvider.overrideWithValue(_TestChapterDatasource()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildPlayScreen(container: container));
      await tester.pumpAndSettle();

      expect(find.text('Choose game mode'), findsOneWidget);
      expect(find.text('Select a topic first'), findsNWidgets(4));

      final startBtn = tester.widget<AppButton>(find.byType(AppButton));
      expect(startBtn.onPressed, isNull);
    });

    testWidgets(
      'Accounting topic enables all 4 game modes and allows mode selection',
      (tester) async {
        setWindowSize(tester);
        final fakeStorage = _FakeLocalStorage();
        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(fakeStorage),
            learningPathDatasourceProvider.overrideWithValue(
              _TestLearningPathDatasource(),
            ),
            chapterDatasourceProvider.overrideWithValue(
              _TestChapterDatasource(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildPlayScreen(container: container));
        await tester.pumpAndSettle();

        // 1. Select Subject: Accounting
        await tester.tap(find.byKey(const Key('play-subject-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accounting & Finance').last);
        await tester.pumpAndSettle();

        // 2. Select Chapter: Basic Accounting
        await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Basic Accounting').last);
        await tester.pumpAndSettle();

        // 3. Select Topic: General Ledger
        await tester.tap(find.byKey(const Key('play-topic-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('General Ledger').last);
        await tester.pumpAndSettle();

        expect(find.text('Select a topic first'), findsNothing);
        expect(find.text('MCQ'), findsOneWidget);
        expect(find.text('Match'), findsOneWidget);
        expect(find.text('Sort It Out'), findsOneWidget);
        expect(find.text('Sudden Death'), findsOneWidget);

        var startBtn = tester.widget<AppButton>(find.byType(AppButton));
        expect(startBtn.onPressed, isNull);

        await tester.tap(find.byKey(const Key('play-mode-matching')));
        await tester.pumpAndSettle();

        startBtn = tester.widget<AppButton>(find.byType(AppButton));
        expect(startBtn.onPressed, isNotNull);
      },
    );

    testWidgets('Backend chapters and topics are selectable for Mathematics and Mental Maths in Play mode', (tester) async {
      setWindowSize(tester);
      final fakeStorage = _FakeLocalStorage();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(fakeStorage),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildPlayScreen(container: container));
      await tester.pumpAndSettle();

      // 1. Select Subject: Mathematics
      await tester.tap(find.byKey(const Key('play-subject-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mathematics').last);
      await tester.pumpAndSettle();

      // 2. Select Chapter: Mathematics
      await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mathematics').last);
      await tester.pumpAndSettle();

      // 3. Select Topic: Mathematics Quiz
      await tester.tap(find.byKey(const Key('play-topic-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mathematics Quiz').last);
      await tester.pumpAndSettle();

      expect(find.text('Select a topic first'), findsNothing);

      // Now switch to Mental Maths
      await tester.tap(find.byKey(const Key('play-subject-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mental Maths').last);
      await tester.pumpAndSettle();

      // Chapter: Mental Maths
      await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mental Maths').last);
      await tester.pumpAndSettle();

      // Topic: Easy
      await tester.tap(find.byKey(const Key('play-topic-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Easy: Addition & Subtraction').last);
      await tester.pumpAndSettle();

      expect(find.text('Select a topic first'), findsNothing);
    });

    testWidgets(
      'Backend chapters and topics are selectable for Mathematics and Mental Maths in Play mode',
      (tester) async {
        setWindowSize(tester);
        final fakeStorage = _FakeLocalStorage();
        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(fakeStorage),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildPlayScreen(container: container));
        await tester.pumpAndSettle();

        // 1. Select Subject: Mathematics
        await tester.tap(find.byKey(const Key('play-subject-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mathematics').last);
        await tester.pumpAndSettle();

        // 2. Select Chapter: Mathematics
        await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mathematics').last);
        await tester.pumpAndSettle();

        // 3. Select Topic: Mathematics Quiz
        await tester.tap(find.byKey(const Key('play-topic-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mathematics Quiz').last);
        await tester.pumpAndSettle();

        expect(find.text('Select a topic first'), findsNothing);

        // Now switch to Mental Maths
        await tester.tap(find.byKey(const Key('play-subject-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mental Maths').last);
        await tester.pumpAndSettle();

        // Chapter: Mental Maths
        await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mental Maths').last);
        await tester.pumpAndSettle();

        // Topic: Easy
        await tester.tap(find.byKey(const Key('play-topic-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Easy: Addition & Subtraction').last);
        await tester.pumpAndSettle();

        expect(find.text('Select a topic first'), findsNothing);
      },
    );

    testWidgets('Changing subject/chapter/topic resets selected mode', (
      tester,
    ) async {
      setWindowSize(tester);
      final fakeStorage = _FakeLocalStorage();
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(fakeStorage),
          learningPathDatasourceProvider.overrideWithValue(
            _TestLearningPathDatasource(),
          ),
          chapterDatasourceProvider.overrideWithValue(_TestChapterDatasource()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildPlayScreen(container: container));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('play-subject-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accounting & Finance').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Basic Accounting').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('play-topic-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('General Ledger').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('play-mode-sortItOut')));
      await tester.pumpAndSettle();

      var startBtn = tester.widget<AppButton>(find.byType(AppButton));
      expect(startBtn.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('play-subject-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Web Development').last);
      await tester.pumpAndSettle();

      startBtn = tester.widget<AppButton>(find.byType(AppButton));
      expect(startBtn.onPressed, isNull);
    });

    testWidgets(
      'Session creation fails with graceful error: no crash, selection retained, SnackBar shown',
      (tester) async {
        setWindowSize(tester);
        late Map<String, dynamic> capturedBody;
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/quiz/sessions/create')) {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': false,
                'message':
                    'no match_the_following questions found for the selected topic',
              }),
              404,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(
          config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
          storage: _FakeLocalStorage(),
          httpClient: mockClient,
        );

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(_FakeLocalStorage()),
            learningPathDatasourceProvider.overrideWithValue(
              _TestLearningPathDatasource(),
            ),
            chapterDatasourceProvider.overrideWithValue(
              _TestChapterDatasource(),
            ),
            quizDatasourceProvider.overrideWithValue(
              QuizRemoteDatasource(apiClient: apiClient),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildPlayScreen(container: container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-subject-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accounting & Finance').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Basic Accounting').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-topic-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('General Ledger').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-mode-matching')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start game'));
        await tester.pumpAndSettle();

        expect(capturedBody['topic'], 'accounts');
        expect(capturedBody['game_mode'], 'match_the_following');
        expect(capturedBody['abandon_stale'], isTrue);

        expect(
          find.text('Match is not available for this topic yet.'),
          findsOneWidget,
        );
        expect(find.text('Choose game mode'), findsOneWidget);
        expect(find.byKey(const Key('play-mode-matching')), findsOneWidget);
      },
    );

    testWidgets(
      'Double tap protection: Start button shows Starting game... and blocks concurrent clicks',
      (tester) async {
        setWindowSize(tester);
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/quiz/sessions/create')) {
            requestCount++;
            await Future.delayed(const Duration(milliseconds: 100));
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'session': 'sess-123',
                  'topic': 'accounting',
                  'game_mode': 'sort_it_out',
                  'total_questions': 10,
                  'time_limit_sec': 70,
                  'time_limit_per_question_sec': 7,
                  'questions': [
                    {
                      'question': 'q-sort-1',
                      'prompt': 'Depreciation',
                      'points': 20,
                      'options': [
                        {'option': 'a', 'text': 'Debit'},
                        {'option': 'b', 'text': 'Credit'},
                      ],
                      'correct_option': 'a',
                      'pair_type': 'credit_debit',
                    },
                  ],
                },
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(
          config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
          storage: _FakeLocalStorage(),
          httpClient: mockClient,
        );

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(_FakeLocalStorage()),
            learningPathDatasourceProvider.overrideWithValue(
              _TestLearningPathDatasource(),
            ),
            chapterDatasourceProvider.overrideWithValue(
              _TestChapterDatasource(),
            ),
            quizDatasourceProvider.overrideWithValue(
              QuizRemoteDatasource(apiClient: apiClient),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildPlayScreen(container: container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-subject-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accounting & Finance').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Basic Accounting').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-topic-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('General Ledger').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-mode-sortItOut')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start game'));
        await tester.pump(const Duration(milliseconds: 10));

        expect(find.text('Starting game...'), findsOneWidget);
        final inFlightBtn = tester.widget<AppButton>(find.byType(AppButton));
        expect(inFlightBtn.onPressed, isNull);

        await tester.tap(find.byType(AppButton));
        await tester.pumpAndSettle();

        expect(requestCount, 1);
      },
    );

    testWidgets(
      'MCQ Start sends game_mode=mcq and navigates to quiz destination',
      (tester) async {
        setWindowSize(tester);
        late Map<String, dynamic> capturedBody;
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/quiz/sessions/create')) {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'session': 'sess-mcq-1',
                  'topic': 'accounting',
                  'game_mode': 'mcq',
                  'total_questions': 10,
                  'time_limit_sec': 150,
                  'questions': [
                    {
                      'question': 'q-mcq-1',
                      'prompt': 'What is accounting?',
                      'points': 10,
                      'options': [
                        {'option': 'a', 'text': 'Recording transactions'},
                        {'option': 'b', 'text': 'Cooking'},
                      ],
                    },
                  ],
                },
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(
          config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
          storage: _FakeLocalStorage(),
          httpClient: mockClient,
        );

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(_FakeLocalStorage()),
            learningPathDatasourceProvider.overrideWithValue(
              _TestLearningPathDatasource(),
            ),
            chapterDatasourceProvider.overrideWithValue(
              _TestChapterDatasource(),
            ),
            quizDatasourceProvider.overrideWithValue(
              QuizRemoteDatasource(apiClient: apiClient),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildPlayScreen(container: container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-subject-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accounting & Finance').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Basic Accounting').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-topic-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('General Ledger').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-mode-mcq')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start game'));
        await tester.pumpAndSettle();

        expect(capturedBody['topic'], 'accounts');
        expect(capturedBody['game_mode'], 'mcq');
        expect(find.text('Quiz Destination: mcq'), findsOneWidget);
      },
    );

    testWidgets(
      'Sudden Death Start sends game_mode=sudden_death and navigates to sudden death destination',
      (tester) async {
        setWindowSize(tester);
        late Map<String, dynamic> capturedBody;
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/quiz/sessions/create')) {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'session': 'sess-sd-1',
                  'topic': 'accounting',
                  'game_mode': 'sudden_death',
                  'total_questions': 10,
                  'time_limit_sec': 150,
                  'questions': [
                    {
                      'question': 'q-sd-1',
                      'prompt': 'SD Question',
                      'points': 10,
                      'options': [
                        {'option': 'a', 'text': 'Option A'},
                        {'option': 'b', 'text': 'Option B'},
                      ],
                    },
                  ],
                },
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(
          config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
          storage: _FakeLocalStorage(),
          httpClient: mockClient,
        );

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(_FakeLocalStorage()),
            learningPathDatasourceProvider.overrideWithValue(
              _TestLearningPathDatasource(),
            ),
            chapterDatasourceProvider.overrideWithValue(
              _TestChapterDatasource(),
            ),
            suddenDeathDatasourceProvider.overrideWithValue(
              SuddenDeathRemoteDatasource(
                apiClient: apiClient,
                storage: _FakeLocalStorage(),
                apiConfig: const ApiConfig(
                  baseUrl: 'http://localhost:8080/api/v1',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildPlayScreen(container: container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-subject-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accounting & Finance').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Basic Accounting').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-topic-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('General Ledger').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-mode-suddenDeath')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start game'));
        await tester.pumpAndSettle();

        expect(capturedBody['topic'], 'accounts');
        expect(capturedBody['game_mode'], 'sudden_death');
        expect(find.text('Sudden Death Destination'), findsOneWidget);
      },
    );

    testWidgets(
      'Sort It Out Start sends game_mode=sort_it_out and navigates to sort it out destination',
      (tester) async {
        setWindowSize(tester);
        late Map<String, dynamic> capturedBody;
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/quiz/sessions/create')) {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'session': 'sess-sort-1',
                  'topic': 'accounting',
                  'game_mode': 'sort_it_out',
                  'total_questions': 1,
                  'questions': [
                    {
                      'id': 'q-sort-1',
                      'title': 'Sort Title',
                      'description': 'Sort Desc',
                      'categories': ['Cat A', 'Cat B'],
                      'cards': [
                        {
                          'id': 'c-1',
                          'text': 'Card 1',
                          'correct_category': 'Cat A',
                        },
                      ],
                    },
                  ],
                },
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(
          config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
          storage: _FakeLocalStorage(),
          httpClient: mockClient,
        );

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(_FakeLocalStorage()),
            learningPathDatasourceProvider.overrideWithValue(
              _TestLearningPathDatasource(),
            ),
            chapterDatasourceProvider.overrideWithValue(
              _TestChapterDatasource(),
            ),
            quizDatasourceProvider.overrideWithValue(
              QuizRemoteDatasource(apiClient: apiClient),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildPlayScreen(container: container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-subject-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accounting & Finance').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Basic Accounting').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-topic-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('General Ledger').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-mode-sortItOut')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start game'));
        await tester.pumpAndSettle();

        expect(capturedBody['topic'], 'accounts');
        expect(capturedBody['game_mode'], 'sort_it_out');
        expect(find.text('Quiz Destination: sortItOut'), findsOneWidget);
      },
    );

    testWidgets(
      'Match the Following Start sends game_mode=match_the_following and navigates to match destination',
      (tester) async {
        setWindowSize(tester);
        late Map<String, dynamic> capturedBody;
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/quiz/sessions/create')) {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'session': 'sess-match-1',
                  'topic': 'accounting',
                  'game_mode': 'match_the_following',
                  'total_boards': 1,
                  'boards': [
                    {
                      'id': 'b-1',
                      'pairs': [
                        {'left': 'Assets', 'right': 'Things owned'},
                      ],
                    },
                  ],
                },
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final apiClient = ApiClient(
          config: const ApiConfig(baseUrl: 'http://localhost:8080/api/v1'),
          storage: _FakeLocalStorage(),
          httpClient: mockClient,
        );

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(_FakeLocalStorage()),
            learningPathDatasourceProvider.overrideWithValue(
              _TestLearningPathDatasource(),
            ),
            chapterDatasourceProvider.overrideWithValue(
              _TestChapterDatasource(),
            ),
            quizDatasourceProvider.overrideWithValue(
              QuizRemoteDatasource(apiClient: apiClient),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildPlayScreen(container: container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-subject-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Accounting & Finance').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-chapter-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Basic Accounting').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-topic-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('General Ledger').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('play-mode-matching')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Start game'));
        await tester.pumpAndSettle();

        expect(capturedBody['topic'], 'accounts');
        expect(capturedBody['game_mode'], 'match_the_following');
        expect(find.text('Quiz Destination: matching'), findsOneWidget);
      },
    );
  });
}
