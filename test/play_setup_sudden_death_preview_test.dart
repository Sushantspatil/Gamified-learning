import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skillverse_app/app/theme/app_theme.dart';
import 'package:skillverse_app/core/providers/core_providers.dart';
import 'package:skillverse_app/core/storage/local_storage_service.dart';
import 'package:skillverse_app/features/chapters/domain/entities/chapter.dart';
import 'package:skillverse_app/features/chapters/domain/entities/topic.dart';
import 'package:skillverse_app/features/chapters/presentation/providers/chapter_providers.dart';
import 'package:skillverse_app/features/learning_paths/domain/entities/learning_path.dart';
import 'package:skillverse_app/features/learning_paths/presentation/providers/learning_path_providers.dart';
import 'package:skillverse_app/features/practice/presentation/screens/practice_screen.dart';
import 'package:skillverse_app/features/questions/presentation/providers/question_providers.dart';
import 'package:skillverse_app/shared/widgets/app_button.dart';
import 'package:skillverse_app/shared/widgets/app_pressable.dart';

const _path = LearningPath(
  id: 'accounting',
  title: 'Book-Keeping & Accountancy',
  description: 'Preview subject',
  difficulty: LearningPathDifficulty.beginner,
  topicCount: 1,
);

const _chapter = Chapter(
  id: 'accounting-basics',
  learningPathId: 'accounting',
  title: 'Book-Keeping & Accountancy',
  description: 'Preview chapter',
  order: 1,
  topicCount: 1,
);

const _topic = Topic(
  id: 'accounting',
  chapterId: 'accounting-basics',
  title: 'Backend quiz',
  order: 1,
  isCompleted: false,
);

void main() {
  testWidgets(
    'development Play setup enables Sudden Death from dedicated preview data',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storageService = await LocalStorageService.create();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(storageService),
            learningPathsProvider.overrideWith((ref) async => const [_path]),
            chaptersProvider.overrideWith(
              (ref, subjectId) async => const [_chapter],
            ),
            topicsProvider.overrideWith(
              (ref, chapterId) async => const [_topic],
            ),
            questionsForTopicProvider.overrideWith(
              (ref, topicId) async => const [],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const PlaySetupScreen(
              initialSubjectId: 'accounting',
              initialChapterId: 'accounting-basics',
              initialTopicId: 'accounting',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final suddenDeathCard = find.byKey(const Key('play-mode-suddenDeath'));
      expect(suddenDeathCard, findsOneWidget);
      expect(find.text('10 development preview questions'), findsOneWidget);
      expect(tester.widget<AppPressable>(suddenDeathCard).onTap, isNotNull);

      await tester.ensureVisible(suddenDeathCard);
      await tester.tap(suddenDeathCard);
      await tester.pumpAndSettle();

      final startButton = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Start game'),
      );
      expect(startButton.onPressed, isNotNull);
    },
  );
}
