/// Converts model output into plain, learner-friendly text for the app UI.
String coachDisplayText(String raw) {
  var text = raw
      .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
      .replaceAll(r'\n', '\n')
      .replaceAll(RegExp(r'```(?:markdown|text)?', caseSensitive: false), '')
      .trim();
  text = text
      .split('\n')
      .map((line) {
        var cleaned = line.replaceFirst(RegExp(r'^\s*#{1,6}\s*'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'^\s*[-*]\s+'), '• ');
        return cleaned.replaceAll('**', '').replaceAll('__', '');
      })
      .join('\n');
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
}
