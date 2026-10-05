import 'dart:convert';

import 'package:emma_prep_english/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    supabaseReady = false;
  });

  test('loads progress, preferences, and valid remote content', () async {
    SharedPreferences.setMockInitialValues({
      'done': ['composition'],
      'saved': ['guided'],
      'correct': 7,
      'attempted': 10,
      'streak': 3,
      'last': '2026-9-27',
      'darkMode': true,
      'highContrast': true,
      'reducedMotion': true,
      'simpleLanguage': false,
      'textScale': 1.25,
      'apiBaseUrl': 'https://legacy.invalid',
      'apiToken': 'legacy-secret',
      'remoteContent': jsonEncode({
        'lessons': [
          {
            'id': 'remote-lesson',
            'paper': 'Paper 2',
            'title': 'Remote lesson',
            'subtitle': 'Fresh material',
            'introduction': 'Synced safely.',
            'notes': ['Read carefully.'],
            'checklist': ['Answer the focus.'],
          },
        ],
        'questions': [
          {
            'paper': 'Paper 2',
            'examStyle': 'zimsec-4005',
            'question': 'What is the focus?',
            'answers': ['A', 'B', 'C', 'D'],
            'correctIndex': 1,
            'explanation': 'B matches the focus.',
          },
        ],
        'announcements': [
          {'title': 'Revision week', 'message': 'Try a quiz.'},
        ],
        'appConfig': {
          'maintenance_notice': 'Updates tonight',
          'ai_enabled': false,
          'question_scanner_enabled': false,
        },
      }),
    });

    final store = Store();
    await store.load();

    expect(store.done, contains('composition'));
    expect(store.saved, contains('guided'));
    expect(store.correct, 7);
    expect(store.attempted, 10);
    expect(store.streak, 3);
    expect(store.darkMode, isTrue);
    expect(store.highContrast, isTrue);
    expect(store.reducedMotion, isTrue);
    expect(store.simpleLanguage, isFalse);
    expect(store.textScale, 1.25);
    expect(store.remoteLessons.single.title, 'Remote lesson');
    expect(store.remoteQuestions.single.q, 'What is the focus?');
    expect(store.announcements.single['title'], 'Revision week');
    expect(store.maintenanceNotice, 'Updates tonight');
    expect(store.remoteCoachEnabled, isFalse);
    expect(store.remoteScannerEnabled, isFalse);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('apiBaseUrl'), isFalse);
    expect(preferences.containsKey('apiToken'), isFalse);
  });

  test(
    'malformed remote content is ignored without losing local data',
    () async {
      SharedPreferences.setMockInitialValues({
        'done': ['guided'],
        'remoteContent': '{not-json',
      });

      final store = Store();
      await store.load();

      expect(store.done, contains('guided'));
      expect(store.remoteLessons, isEmpty);
      expect(store.remoteQuestions, isEmpty);
    },
  );

  test('progress actions toggle state and count answers', () async {
    final store = Store();

    store.complete('composition');
    expect(store.done, contains('composition'));
    expect(store.streak, 1);
    store.complete('composition');
    expect(store.done, isNot(contains('composition')));

    store.bookmark('guided');
    expect(store.saved, contains('guided'));
    store.bookmark('guided');
    expect(store.saved, isNot(contains('guided')));

    store.answer(true);
    store.answer(false);
    expect(store.attempted, 2);
    expect(store.correct, 1);

    await store.save();
    final restored = Store();
    await restored.load();
    expect(restored.attempted, 2);
    expect(restored.correct, 1);
    expect(restored.streak, 1);
  });

  test('accessibility preferences persist across store instances', () async {
    final store = Store();
    store.updateAccessibility(
      dark: true,
      contrast: true,
      motion: true,
      simple: false,
      scale: 1.4,
    );
    await store.save();

    final restored = Store();
    await restored.load();
    expect(restored.darkMode, isTrue);
    expect(restored.highContrast, isTrue);
    expect(restored.reducedMotion, isTrue);
    expect(restored.simpleLanguage, isFalse);
    expect(restored.textScale, 1.4);
  });

  test('API headers never emit an empty authorization credential', () {
    final headers = Store().apiHeaders;
    expect(headers['Content-Type'], 'application/json');
    expect(headers, isNot(contains('Authorization')));
    expect(headers, isNot(contains('apikey')));
  });
}
