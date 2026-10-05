import 'package:emma_prep_english/models/lesson.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a Paper 2 lesson from remote content', () {
    final lesson = Lesson.fromJson({
      'id': 'summary-skills',
      'paper': 'Paper 2',
      'title': 'Summary skills',
      'subtitle': 'Select essential ideas',
      'introduction': 'Read before selecting points.',
      'notes': ['Use your own words.'],
      'checklist': ['Keep the original meaning.'],
    });

    expect(lesson.id, 'remote-summary-skills');
    expect(lesson.paper, 'Paper 2');
    expect(lesson.title, 'Summary skills');
    expect(lesson.sub, 'Select essential ideas');
    expect(lesson.intro, 'Read before selecting points.');
    expect(lesson.notes, ['Use your own words.']);
    expect(lesson.check, ['Keep the original meaning.']);
    expect(lesson.icon, Icons.cloud_download_rounded);
    expect(lesson.color, const Color(0xff5679b6));
  });

  test('uses safe defaults for incomplete Paper 1 content', () {
    final lesson = Lesson.fromJson({'id': 42, 'paper': 'Unexpected'});

    expect(lesson.id, 'remote-42');
    expect(lesson.paper, 'Paper 1');
    expect(lesson.title, 'Updated lesson');
    expect(lesson.sub, 'Content update');
    expect(lesson.intro, isEmpty);
    expect(lesson.notes, isEmpty);
    expect(lesson.check, isEmpty);
    expect(lesson.color, const Color(0xffff5f9e));
  });
}
