class Question {
  final String paper, q, why, examStyle;
  final List<String> a;
  final int correct;

  const Question(
    this.paper,
    this.q,
    this.a,
    this.correct,
    this.why, {
    this.examStyle = 'zimsec-4005',
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    if (json['examStyle'] != 'zimsec-4005') {
      throw const FormatException('Only ZIMSEC 4005 questions are accepted');
    }
    final answers = List<String>.from(json['answers'] ?? const []);
    final correctIndex = (json['correctIndex'] as num?)?.toInt() ?? -1;
    if (answers.length != 4 ||
        correctIndex < 0 ||
        correctIndex >= answers.length) {
      throw const FormatException('Invalid ZIMSEC practice question');
    }
    return Question(
      json['paper'] == 'Paper 2' ? 'Paper 2' : 'Paper 1',
      json['question']?.toString() ?? '',
      answers,
      correctIndex,
      json['explanation']?.toString() ?? '',
    );
  }
}
