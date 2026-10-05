import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/bundled_content.dart';
import '../models/lesson.dart';
import '../models/question.dart';

const compiledApiBaseUrl = String.fromEnvironment('EMMAPREP_API_URL');
const compiledAppToken = String.fromEnvironment('EMMAPREP_APP_TOKEN');
bool supabaseReady = false;

String _encodeJpegDataUrl(Uint8List bytes) =>
    'data:image/jpeg;base64,${base64Encode(bytes)}';

Future<String> encodeImageForApi(XFile image) async =>
    compute(_encodeJpegDataUrl, await image.readAsBytes());

Future<void> logStudentEvent(
  String eventName, {
  String level = 'info',
  Map<String, dynamic> metadata = const {},
}) async {
  debugPrint('[EmmaPrep Student][$level] $eventName $metadata');
  if (!supabaseReady) return;
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  try {
    await Supabase.instance.client.from('app_events').insert({
      'actor_id': user.id,
      'source': 'student_app',
      'event_name': eventName,
      'level': level,
      'app_version': '1.10.0',
      'metadata': metadata,
    });
  } catch (error) {
    debugPrint(
      '[EmmaPrep Student][warning] event_log_failed ${error.runtimeType}',
    );
  }
}

class Store extends ChangeNotifier {
  final done = <String>{}, saved = <String>{};
  final remoteLessons = <Lesson>[];
  final remoteQuestions = <Question>[];
  final personalLessons = <Lesson>[];
  final personalQuestions = <Question>[];
  final scannedBatches = <Map<String, dynamic>>[];
  final announcements = <Map<String, dynamic>>[];
  int correct = 0, attempted = 0, streak = 0;
  bool darkMode = false,
      highContrast = false,
      reducedMotion = false,
      simpleLanguage = true,
      remoteCoachEnabled = true,
      remoteScannerEnabled = true;
  String maintenanceNotice = '';
  double textScale = 1.0;
  String last = '', contentVersion = 'Bundled 1.2', contentEtag = '';
  final String apiBaseUrl = compiledApiBaseUrl;
  final String apiToken = compiledAppToken;
  bool syncing = false;
  List<Lesson> get allLessons => [
    ...lessons,
    ...remoteLessons,
    ...personalLessons,
  ];
  List<Question> get allQuestions => [
    ...bank,
    ...remoteQuestions,
    ...personalQuestions,
  ];
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    // Remove configuration saved by early builds; production values now come
    // only from compile-time Dart defines and are never user-editable.
    await p.remove('apiBaseUrl');
    await p.remove('apiToken');
    done.addAll(p.getStringList('done') ?? []);
    saved.addAll(p.getStringList('saved') ?? []);
    correct = p.getInt('correct') ?? 0;
    attempted = p.getInt('attempted') ?? 0;
    streak = p.getInt('streak') ?? 0;
    last = p.getString('last') ?? '';
    contentVersion = p.getString('contentVersion') ?? 'Bundled 1.2';
    contentEtag = p.getString('contentEtag') ?? '';
    darkMode = p.getBool('darkMode') ?? false;
    highContrast = p.getBool('highContrast') ?? false;
    reducedMotion = p.getBool('reducedMotion') ?? false;
    simpleLanguage = p.getBool('simpleLanguage') ?? true;
    textScale = p.getDouble('textScale') ?? 1.0;
    _decodeContent(p.getString('remoteContent'));
    _decodeScanned(p.getString('scannedBatches'));
    notifyListeners();
    if (apiBaseUrl.isNotEmpty) {
      unawaited(syncContent(silent: true));
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('done', done.toList());
    await p.setStringList('saved', saved.toList());
    await p.setInt('correct', correct);
    await p.setInt('attempted', attempted);
    await p.setInt('streak', streak);
    await p.setString('last', last);
    await p.setString('contentVersion', contentVersion);
    await p.setString('contentEtag', contentEtag);
    await p.setBool('darkMode', darkMode);
    await p.setBool('highContrast', highContrast);
    await p.setBool('reducedMotion', reducedMotion);
    await p.setBool('simpleLanguage', simpleLanguage);
    await p.setDouble('textScale', textScale);
    await p.setString('scannedBatches', jsonEncode(scannedBatches));
  }

  void study() {
    final n = DateTime.now(),
        key = '${n.year}-${n.month}-${n.day}',
        y = n.subtract(const Duration(days: 1)),
        yk = '${y.year}-${y.month}-${y.day}';
    if (last != key) {
      streak = last == yk ? streak + 1 : 1;
      last = key;
    }
  }

  void complete(String id) {
    done.contains(id) ? done.remove(id) : done.add(id);
    study();
    save();
    notifyListeners();
    unawaited(logStudentEvent('lesson_progress_changed'));
  }

  void bookmark(String id) {
    saved.contains(id) ? saved.remove(id) : saved.add(id);
    save();
    notifyListeners();
  }

  void answer(bool ok) {
    attempted++;
    if (ok) correct++;
    study();
    save();
    notifyListeners();
    unawaited(logStudentEvent('practice_answered', metadata: {'correct': ok}));
  }

  void updateAccessibility({
    bool? dark,
    bool? contrast,
    bool? motion,
    bool? simple,
    double? scale,
  }) {
    if (dark != null) darkMode = dark;
    if (contrast != null) highContrast = contrast;
    if (motion != null) reducedMotion = motion;
    if (simple != null) simpleLanguage = simple;
    if (scale != null) textScale = scale;
    save();
    notifyListeners();
  }

  Map<String, String> get apiHeaders => {
    'Content-Type': 'application/json',
    if (apiToken.startsWith('sb_publishable_')) 'apikey': apiToken,
    if (supabaseReady && Supabase.instance.client.auth.currentSession != null)
      'Authorization':
          'Bearer ${Supabase.instance.client.auth.currentSession!.accessToken}',
    if (apiToken.isNotEmpty && !apiToken.startsWith('sb_publishable_'))
      'Authorization': 'Bearer $apiToken',
  };

  void _decodeScanned(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      scannedBatches
        ..clear()
        ..addAll(
          List<Map<String, dynamic>>.from(
            (jsonDecode(raw) as List).map(
              (item) => Map<String, dynamic>.from(item),
            ),
          ),
        );
      personalLessons.clear();
      personalQuestions.clear();
      for (final batch in scannedBatches) {
        final id = batch['id'].toString();
        final items = List<Map<String, dynamic>>.from(
          (batch['questions'] as List).map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
        if (items.isEmpty) continue;
        final paper = items.first['paper'] == 'Paper 2' ? 'Paper 2' : 'Paper 1';
        personalLessons.add(
          Lesson(
            'scan-$id',
            paper,
            'My scanned questions',
            '${items.length} solved questions',
            'Questions captured from your revision material and explained in simple language.',
            Icons.document_scanner_rounded,
            paper == 'Paper 2'
                ? const Color(0xff5679b6)
                : const Color(0xffff5f9e),
            items
                .map(
                  (item) =>
                      '${(item['passage']?.toString().isNotEmpty ?? false) ? 'Passage:\n${item['passage']}\n\n' : ''}${item['question']}\nAnswer: ${item['answers'][item['correctIndex']]}\n${item['studyNote']}',
                )
                .toList(),
            const [
              'Read the explanation',
              'Try again without looking',
              'Explain the answer aloud',
            ],
          ),
        );
        personalQuestions.addAll(
          items.map(
            (item) => Question.fromJson({...item, 'examStyle': 'zimsec-4005'}),
          ),
        );
      }
    } catch (_) {
      scannedBatches.clear();
      personalLessons.clear();
      personalQuestions.clear();
    }
  }

  Future<List<Map<String, dynamic>>> scanQuestions(List<XFile> images) async {
    if (apiBaseUrl.isEmpty) {
      throw const FormatException('The scanner API is not configured.');
    }
    final encoded = <String>[];
    unawaited(
      logStudentEvent(
        'question_scan_started',
        metadata: {'imageCount': images.take(3).length},
      ),
    );
    for (final image in images.take(3)) {
      encoded.add(await encodeImageForApi(image));
    }
    debugPrint(
      '[EmmaPrep Student][info] question_scan_upload_started {imageCount: ${encoded.length}}',
    );
    final response = await http
        .post(
          Uri.parse('$apiBaseUrl/v1/scan-questions'),
          headers: apiHeaders,
          body: jsonEncode({'images': encoded}),
        )
        .timeout(const Duration(seconds: 90));
    debugPrint(
      '[EmmaPrep Student][info] question_scan_http_completed {status: ${response.statusCode}}',
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      unawaited(
        logStudentEvent(
          'question_scan_failed',
          level: 'error',
          metadata: {
            'status': response.statusCode,
            if (data['providerStatus'] != null)
              'providerStatus': data['providerStatus'],
          },
        ),
      );
      debugPrint(
        '[EmmaPrep Student][error] question_scan_provider_status ${data['providerStatus'] ?? 'unknown'} request=${data['requestId'] ?? 'unknown'}',
      );
      throw FormatException(
        '${data['error']?.toString() ?? 'Question scan failed.'}${data['requestId'] == null ? '' : ' (request ${data['requestId']})'}',
      );
    }
    final candidates = List<Map<String, dynamic>>.from(
      (data['questions'] as List? ?? []).map(
        (item) => Map<String, dynamic>.from(item),
      ),
    );
    final items = <Map<String, dynamic>>[];
    for (final item in candidates) {
      try {
        item['passage'] = item['passage']?.toString().trim() ?? '';
        Question.fromJson({...item, 'examStyle': 'zimsec-4005'});
        items.add(item);
      } on FormatException {
        debugPrint('[EmmaPrep Student][warning] invalid_scanned_item_skipped');
      }
    }
    if (items.isEmpty) {
      throw const FormatException(
        'The pages were read, but no complete ZIMSEC English questions could be prepared. Try one clearer page at a time.',
      );
    }
    unawaited(
      logStudentEvent(
        'question_scan_succeeded',
        metadata: {
          'imageCount': images.take(3).length,
          'questionCount': items.length,
        },
      ),
    );
    return items;
  }

  Future<void> saveScannedQuestions(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    scannedBatches.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'questions': items,
    });
    _decodeScanned(jsonEncode(scannedBatches));
    await save();
    notifyListeners();
    unawaited(
      logStudentEvent(
        'scanned_questions_saved',
        metadata: {'questionCount': items.length},
      ),
    );
  }

  bool _decodeContent(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final parsedLessons = (data['lessons'] as List? ?? [])
          .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final parsedQuestions = (data['questions'] as List? ?? [])
          .map((e) => Question.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final parsedAnnouncements = List<Map<String, dynamic>>.from(
        (data['announcements'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e),
        ),
      );
      final appConfig = Map<String, dynamic>.from(
        data['appConfig'] as Map? ?? const {},
      );
      remoteLessons
        ..clear()
        ..addAll(parsedLessons);
      remoteQuestions
        ..clear()
        ..addAll(parsedQuestions);
      announcements
        ..clear()
        ..addAll(parsedAnnouncements);
      maintenanceNotice = appConfig['maintenance_notice']?.toString() ?? '';
      remoteCoachEnabled = appConfig['ai_enabled'] as bool? ?? true;
      remoteScannerEnabled =
          appConfig['question_scanner_enabled'] as bool? ?? true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> syncContent({bool silent = false}) async {
    if (apiBaseUrl.isEmpty) {
      return 'Online updates are not configured in this build.';
    }
    syncing = true;
    notifyListeners();
    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/v1/content'),
            headers: {
              ...apiHeaders,
              if (contentEtag.isNotEmpty) 'If-None-Match': contentEtag,
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 304) {
        return 'Content is already current.';
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'Update failed (${response.statusCode}).';
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['schema'] != 'emmaprep-content-v1' ||
          data['curriculum'] != 'zimsec-4005') {
        return 'Update rejected: unsupported curriculum format.';
      }
      final payload = jsonEncode({
        'lessons': data['lessons'] ?? [],
        'questions': data['questions'] ?? [],
        'announcements': data['announcements'] ?? [],
        'appConfig': data['appConfig'] ?? {},
      });
      if (!_decodeContent(payload)) {
        return 'Update rejected: invalid ZIMSEC content.';
      }
      contentVersion =
          data['version']?.toString() ?? 'Updated ${DateTime.now().toLocal()}';
      contentEtag = response.headers['etag'] ?? data['etag']?.toString() ?? '';
      final p = await SharedPreferences.getInstance();
      await p.setString('remoteContent', payload);
      await save();
      notifyListeners();
      return 'Updated: ${remoteLessons.length} lessons and ${remoteQuestions.length} questions received.';
    } catch (e) {
      return silent
          ? 'Offline content remains available.'
          : 'Could not update. Check the connection and server.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}
