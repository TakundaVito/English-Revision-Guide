import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const blue = Color(0xff2854c7), pink = Color(0xffff5f9e);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  }
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'EmmaPrep Admin',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: blue),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfffff8fc),
    ),
    home: supabaseUrl.isEmpty || supabaseKey.isEmpty
        ? const MissingConfig()
        : const AuthGate(),
  );
}

class MissingConfig extends StatelessWidget {
  const MissingConfig({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: SelectableText(
            'EmmaPrep Admin needs configuration.\n\nCopy config.example.json to config.local.json, then run:\nflutter run -d chrome --dart-define-from-file=config.local.json',
          ),
        ),
      ),
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (_, _) => Supabase.instance.client.auth.currentSession == null
        ? const LoginPage()
        : const AdminHome(),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  String? error;
  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SizedBox(
        width: 430,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 54,
                  color: blue,
                ),
                const SizedBox(height: 12),
                const Text(
                  'EmmaPrep Admin',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: true,
                  onSubmitted: (_) => login(),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy ? null : login,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(busy ? 'Signing in…' : 'Sign in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int page = 0, revision = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('EmmaPrep Admin'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => setState(() => revision++),
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: Supabase.instance.client.auth.signOut,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
    body: Row(
      children: [
        NavigationRail(
          selectedIndex: page,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (value) => setState(() => page = value),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.menu_book_rounded),
              label: Text('Lessons'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.quiz_rounded),
              label: Text('Questions'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.publish_rounded),
              label: Text('Releases'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.settings_rounded),
              label: Text('Settings'),
            ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: switch (page) {
            0 => RecordsPage(
              kind: RecordKind.lesson,
              revision: revision,
              changed: refresh,
            ),
            1 => RecordsPage(
              kind: RecordKind.question,
              revision: revision,
              changed: refresh,
            ),
            2 => ReleasesPage(revision: revision, changed: refresh),
            _ => SettingsPage(revision: revision, changed: refresh),
          },
        ),
      ],
    ),
  );
  void refresh() => setState(() => revision++);
}

enum RecordKind { lesson, question }

class RecordsPage extends StatelessWidget {
  final RecordKind kind;
  final int revision;
  final VoidCallback changed;
  const RecordsPage({
    required this.kind,
    required this.revision,
    required this.changed,
    super.key,
  });
  String get table => kind == RecordKind.lesson ? 'lessons' : 'questions';
  Future<List<Map<String, dynamic>>> load() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from(table)
            .select()
            .order('paper')
            .order('sort_order'),
      );
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    key: ValueKey('$kind-$revision'),
    future: load(),
    builder: (context, snapshot) => PageFrame(
      title: kind == RecordKind.lesson ? 'Lessons' : 'ZIMSEC questions',
      subtitle: kind == RecordKind.lesson
          ? 'Create practical Paper 1 and Paper 2 teaching content.'
          : 'Only original questions practising typical ZIMSEC 4005 skills.',
      action: FilledButton.icon(
        onPressed: () => edit(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(kind == RecordKind.lesson ? 'New lesson' : 'New question'),
      ),
      child: snapshot.hasError
          ? ErrorText(snapshot.error)
          : !snapshot.hasData
          ? const Center(child: CircularProgressIndicator())
          : snapshot.data!.isEmpty
          ? const Center(
              child: Text('Nothing here yet. Create the first item.'),
            )
          : ListView.separated(
              itemCount: snapshot.data!.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final row = snapshot.data![index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(row['paper'] == 'Paper 1' ? 'P1' : 'P2'),
                  ),
                  title: Text(
                    (row[kind == RecordKind.lesson ? 'title' : 'question'])
                        .toString(),
                  ),
                  subtitle: Text(
                    row['enabled'] == true
                        ? 'Included in next release'
                        : 'Disabled',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => edit(context, row),
                  ),
                );
              },
            ),
    ),
  );
  Future<void> edit(BuildContext context, [Map<String, dynamic>? row]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ContentEditor(kind: kind, row: row),
    );
    if (saved == true) changed();
  }
}

class ContentEditor extends StatefulWidget {
  final RecordKind kind;
  final Map<String, dynamic>? row;
  const ContentEditor({required this.kind, this.row, super.key});
  @override
  State<ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends State<ContentEditor> {
  late final title = TextEditingController(
    text: widget.row?['title']?.toString(),
  );
  late final slug = TextEditingController(
    text: widget.row?['slug']?.toString(),
  );
  late final subtitle = TextEditingController(
    text: widget.row?['subtitle']?.toString(),
  );
  late final intro = TextEditingController(
    text: widget.row?['introduction']?.toString(),
  );
  late final notes = TextEditingController(
    text: (widget.row?['notes'] as List?)?.join('\n'),
  );
  late final checklist = TextEditingController(
    text: (widget.row?['checklist'] as List?)?.join('\n'),
  );
  late final question = TextEditingController(
    text: widget.row?['question']?.toString(),
  );
  late final answers = TextEditingController(
    text: (widget.row?['answers'] as List?)?.join('\n'),
  );
  late final explanation = TextEditingController(
    text: widget.row?['explanation']?.toString(),
  );
  late final correct = TextEditingController(
    text: '${(widget.row?['correct_index'] as int? ?? 0) + 1}',
  );
  late String paper = widget.row?['paper']?.toString() ?? 'Paper 1';
  late bool enabled = widget.row?['enabled'] as bool? ?? true;
  bool busy = false;
  Future<void> save() async {
    final answerList = splitLines(answers.text);
    final data = widget.kind == RecordKind.lesson
        ? {
            'slug': slug.text.trim(),
            'paper': paper,
            'title': title.text.trim(),
            'subtitle': subtitle.text.trim(),
            'introduction': intro.text.trim(),
            'notes': splitLines(notes.text),
            'checklist': splitLines(checklist.text),
            'enabled': enabled,
          }
        : {
            'paper': paper,
            'exam_style': 'zimsec-4005',
            'question': question.text.trim(),
            'answers': answerList,
            'correct_index': (int.tryParse(correct.text) ?? 1) - 1,
            'explanation': explanation.text.trim(),
            'enabled': enabled,
          };
    setState(() => busy = true);
    try {
      final query = Supabase.instance.client.from(
        widget.kind == RecordKind.lesson ? 'lessons' : 'questions',
      );
      if (widget.row == null) {
        await query.insert(data);
      } else {
        await query.update(data).eq('id', widget.row!['id']);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.row == null ? 'Create draft' : 'Edit draft'),
    content: SizedBox(
      width: 680,
      child: SingleChildScrollView(
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: paper,
              decoration: input('Paper'),
              items: [
                'Paper 1',
                'Paper 2',
              ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (value) => setState(() => paper = value!),
            ),
            const SizedBox(height: 14),
            if (widget.kind == RecordKind.lesson) ...[
              Field(slug, 'Unique ID', hint: 'formal-letter-complaints'),
              Field(title, 'Title'),
              Field(subtitle, 'Subtitle'),
              Field(intro, 'Introduction', lines: 3),
              Field(notes, 'Teaching notes — one per line', lines: 5),
              Field(checklist, 'Checklist — one per line', lines: 4),
            ] else ...[
              Field(question, 'Question', lines: 4),
              Field(answers, 'Answers — one per line', lines: 5),
              Field(correct, 'Correct answer number', hint: '1'),
              Field(explanation, 'Simple explanation', lines: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Exam style is locked to zimsec-4005.',
                  style: TextStyle(color: blue, fontWeight: FontWeight.w700),
                ),
              ),
            ],
            SwitchListTile(
              title: const Text('Include in next release'),
              value: enabled,
              onChanged: (value) => setState(() => enabled = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: busy ? null : save,
        icon: const Icon(Icons.save_rounded),
        label: Text(busy ? 'Saving…' : 'Save draft'),
      ),
    ],
  );
}

class ReleasesPage extends StatelessWidget {
  final int revision;
  final VoidCallback changed;
  const ReleasesPage({
    required this.revision,
    required this.changed,
    super.key,
  });
  Future<List<Map<String, dynamic>>> load() async =>
      List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('content_releases')
            .select()
            .order('published_at', ascending: false),
      );
  Future<void> publish(BuildContext context) async {
    final now = DateTime.now();
    final version = TextEditingController(
      text: '${now.year}.${now.month.toString().padLeft(2, '0')}.1',
    );
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Publish enabled content?'),
        content: TextField(
          controller: version,
          decoration: input('Version, for example 2026.08.1'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    try {
      await Supabase.instance.client.rpc(
        'publish_emmaprep_content',
        params: {'release_version': version.text.trim()},
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Content published.')));
      }
      changed();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Publish failed: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(revision),
        future: load(),
        builder: (context, snapshot) => PageFrame(
          title: 'Releases',
          subtitle: 'The app receives only the active atomic snapshot.',
          action: FilledButton.icon(
            onPressed: () => publish(context),
            icon: const Icon(Icons.publish_rounded),
            label: const Text('Publish content'),
          ),
          child: snapshot.hasError
              ? ErrorText(snapshot.error)
              : !snapshot.hasData
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: snapshot.data!
                      .map(
                        (row) => ListTile(
                          leading: Icon(
                            row['published'] == true
                                ? Icons.check_circle
                                : Icons.archive_rounded,
                            color: row['published'] == true
                                ? Colors.green
                                : Colors.grey,
                          ),
                          title: Text(row['version'].toString()),
                          subtitle: Text(row['published_at'].toString()),
                          trailing: Chip(
                            label: Text(
                              row['published'] == true ? 'Active' : 'Archived',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      );
}

class SettingsPage extends StatefulWidget {
  final int revision;
  final VoidCallback changed;
  const SettingsPage({
    required this.revision,
    required this.changed,
    super.key,
  });
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final minimumVersion = TextEditingController();
  final maintenanceNotice = TextEditingController();
  final cacheSeconds = TextEditingController();
  String model = 'gpt-5.4-mini';
  bool aiEnabled = true, loading = true, saving = false;
  Map<String, dynamic>? health;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = List<Map<String, dynamic>>.from(
        await Supabase.instance.client.from('app_config').select(),
      );
      final values = {
        for (final row in rows) row['key'].toString(): row['value'],
      };
      minimumVersion.text = values['minimum_version']?.toString() ?? '1.3.0';
      maintenanceNotice.text = values['maintenance_notice']?.toString() ?? '';
      cacheSeconds.text = values['content_cache_seconds']?.toString() ?? '300';
      model = values['ai_model']?.toString() ?? 'gpt-5.4-mini';
      aiEnabled = values['ai_enabled'] as bool? ?? true;
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'health',
        );
        health = Map<String, dynamic>.from(response.data as Map);
      } catch (_) {
        health = null;
      }
    } catch (caught) {
      error = '$caught';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    final cache = int.tryParse(cacheSeconds.text.trim());
    if (cache == null || cache < 60 || cache > 3600) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache time must be between 60 and 3600 seconds.'),
        ),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('app_config').upsert([
        {'key': 'ai_enabled', 'value': aiEnabled, 'updated_by': userId},
        {'key': 'ai_model', 'value': model, 'updated_by': userId},
        {'key': 'content_cache_seconds', 'value': cache, 'updated_by': userId},
        {
          'key': 'maintenance_notice',
          'value': maintenanceNotice.text.trim(),
          'updated_by': userId,
        },
        {
          'key': 'minimum_version',
          'value': minimumVersion.text.trim(),
          'updated_by': userId,
        },
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Remote settings saved.')));
      widget.changed();
    } catch (caught) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $caught')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'API & app settings',
    subtitle:
        'Manage safe remote controls. Provider secrets remain in Supabase Secrets.',
    action: FilledButton.icon(
      onPressed: saving ? null : save,
      icon: const Icon(Icons.save_rounded),
      label: Text(saving ? 'Saving…' : 'Save settings'),
    ),
    child: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? ErrorText(error)
        : ListView(
            children: [
              const Text(
                'AI coach',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.smart_toy_rounded),
                title: const Text('AI coach enabled'),
                subtitle: const Text(
                  'Disable chat remotely without publishing another APK.',
                ),
                value: aiEnabled,
                onChanged: (value) => setState(() => aiEnabled = value),
              ),
              DropdownButtonFormField<String>(
                initialValue: model,
                decoration: input('OpenAI model'),
                items: const [
                  DropdownMenuItem(
                    value: 'gpt-5.4-mini',
                    child: Text('GPT-5.4 mini — economical tutor'),
                  ),
                  DropdownMenuItem(
                    value: 'gpt-5.4',
                    child: Text('GPT-5.4 — higher capability'),
                  ),
                ],
                onChanged: (value) => setState(() => model = value!),
              ),
              const SizedBox(height: 8),
              const Text(
                'The OpenAI API key cannot be viewed or changed here. Set it only in Supabase Secrets.',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Divider(height: 38),
              const Text(
                'Mobile app controls',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              Field(
                minimumVersion,
                'Minimum supported app version',
                hint: '1.3.0',
              ),
              Field(
                maintenanceNotice,
                'Maintenance notice',
                hint: 'Leave blank when the service is operating normally',
                lines: 3,
              ),
              Field(cacheSeconds, 'Content cache time in seconds', hint: '300'),
              const Divider(height: 38),
              const Text(
                'API status',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_rounded),
                title: const Text('Supabase project'),
                subtitle: const SelectableText(supabaseUrl),
              ),
              StatusTile(
                'Admin health endpoint',
                health?['ok'] == true,
                detail: health == null
                    ? 'Deploy the health function to enable status checks.'
                    : 'Connected',
              ),
              StatusTile(
                'OpenAI secret configured',
                health?['openAiConfigured'] == true,
                detail: health == null ? 'Status unavailable' : null,
              ),
              StatusTile(
                'Rate-limit salt configured',
                health?['rateLimitSaltConfigured'] == true,
                detail: health == null ? 'Status unavailable' : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.new_releases_rounded),
                title: const Text('Published content release'),
                subtitle: Text(
                  health?['contentRelease']?['version']?.toString() ??
                      'No active release reported',
                ),
              ),
              const Divider(height: 38),
              const Text(
                'About',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.admin_panel_settings_rounded),
                title: Text('EmmaPrep Admin'),
                subtitle: Text(
                  'Version 1.1.0 — Takunda Vito\ntakunda.vito.co.zw',
                ),
              ),
              const Text(
                'This dashboard manages EmmaPrep English content and safe remote configuration. It does not store provider secrets in browser code.',
                style: TextStyle(height: 1.45),
              ),
            ],
          ),
  );
}

class StatusTile extends StatelessWidget {
  final String label;
  final bool good;
  final String? detail;
  const StatusTile(this.label, this.good, {this.detail, super.key});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      good ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
      color: good ? Colors.green : Colors.orange,
    ),
    title: Text(label),
    subtitle: detail == null ? null : Text(detail!),
  );
}

class PageFrame extends StatelessWidget {
  final String title, subtitle;
  final Widget child, action;
  const PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.action,
    super.key,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(subtitle),
                ],
              ),
            ),
            action,
          ],
        ),
        const SizedBox(height: 22),
        Expanded(
          child: Card(
            child: Padding(padding: const EdgeInsets.all(18), child: child),
          ),
        ),
      ],
    ),
  );
}

class Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int lines;
  const Field(
    this.controller,
    this.label, {
    this.hint,
    this.lines = 1,
    super.key,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      maxLines: lines,
      decoration: input(label, hint),
    ),
  );
}

class ErrorText extends StatelessWidget {
  final Object? error;
  const ErrorText(this.error, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Could not load data. Install the migration and administrator profile.\n\n$error',
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.red),
    ),
  );
}

InputDecoration input(String label, [String? hint]) => InputDecoration(
  labelText: label,
  hintText: hint,
  border: const OutlineInputBorder(),
);
List<String> splitLines(String value) => value
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();
