import 'package:flutter/material.dart';

class Lesson {
  final String id, paper, title, sub, intro;
  final IconData icon;
  final Color color;
  final List<String> notes, check;

  const Lesson(
    this.id,
    this.paper,
    this.title,
    this.sub,
    this.intro,
    this.icon,
    this.color,
    this.notes,
    this.check,
  );

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    'remote-${json['id'] ?? json['title'].hashCode}',
    json['paper'] == 'Paper 2' ? 'Paper 2' : 'Paper 1',
    json['title']?.toString() ?? 'Updated lesson',
    json['subtitle']?.toString() ?? 'Content update',
    json['introduction']?.toString() ?? '',
    Icons.cloud_download_rounded,
    json['paper'] == 'Paper 2'
        ? const Color(0xff5679b6)
        : const Color(0xffff5f9e),
    List<String>.from(json['notes'] ?? const []),
    List<String>.from(json['checklist'] ?? const []),
  );
}
