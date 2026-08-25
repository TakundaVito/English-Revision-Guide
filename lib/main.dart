import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const plum = Color(0xff4e2148),
    coral = Color(0xffe66a5c),
    cream = Color(0xfffff8f0),
    ink = Color(0xff211a20);
void main() => runApp(const EmmaPrep());

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
    json['paper'] == 'Paper 2' ? const Color(0xff5679b6) : coral,
    List<String>.from(json['notes'] ?? const []),
    List<String>.from(json['checklist'] ?? const []),
  );
}

const lessons = <Lesson>[
  Lesson(
    'composition',
    'Paper 1',
    'Composition',
    'Narrative, descriptive & argumentative',
    'Build a controlled, relevant piece with a purposeful opening, clear paragraph journey and satisfying ending.',
    Icons.edit_note_rounded,
    Color(0xffd75d62),
    [
      'Plan for 5–7 minutes: audience, purpose, viewpoint and paragraph journey.',
      'Open in motion or with a precise image. Avoid memorised introductions.',
      'Vary sentence lengths deliberately; clarity matters more than “big words”.',
      'Keep tense and viewpoint consistent. Leave time to edit agreement and punctuation.',
    ],
    [
      'I answered the exact question',
      'Every paragraph advances the idea',
      'Vocabulary is natural and precise',
      'I checked tense, spelling and punctuation',
    ],
  ),
  Lesson(
    'guided',
    'Paper 1',
    'Guided Writing',
    'Letters, reports, speeches & articles',
    'Match content, register and format to the stated audience. Use every prompt, but develop rather than merely list it.',
    Icons.mark_email_read_rounded,
    Color(0xffde965d),
    [
      'Underline role, audience, purpose and required content before writing.',
      'Formal writing is polite and objective; informal writing is warm but never careless.',
      'Reports need headings and practical recommendations; speeches address listeners directly.',
      'Link points logically and explain consequences or examples.',
    ],
    [
      'Correct format and tone',
      'All content points developed',
      'Clear opening and close',
      'Paragraphs and linking words used',
    ],
  ),
  Lesson(
    'style',
    'Paper 1',
    'Register & Style',
    'Write for the real reader',
    'Decide what the reader knows, feels and needs to do, then choose language that fits the relationship.',
    Icons.record_voice_over_rounded,
    Color(0xff5c8d89),
    [
      'Purpose may be to inform, persuade, advise, complain, entertain or describe.',
      'Choose pronouns, vocabulary and sentence type for the relationship.',
      'Persuasion uses reason, evidence, emotion and a clear call to action.',
      'Avoid slang in formal tasks and stiff clichés in personal tasks.',
    ],
    [
      'Audience is obvious',
      'Tone stays consistent',
      'Evidence supports claims',
      'Ending fits the purpose',
    ],
  ),
  Lesson(
    'comprehension',
    'Paper 2',
    'Comprehension',
    'Read, infer and explain',
    'Answer from the passage with the precision demanded by the question. Marks often signal how many ideas are needed.',
    Icons.menu_book_rounded,
    Color(0xff5679b6),
    [
      'Read the question first, then locate and bracket the relevant lines.',
      '“In your own words” means changing vocabulary and sentence structure.',
      'For inference, combine textual evidence with what it logically suggests.',
      'Explain effects in context; naming a technique alone is not enough.',
    ],
    [
      'Answer is direct',
      'Enough distinct points for marks',
      'Own words where required',
      'Evidence is relevant',
    ],
  ),
  Lesson(
    'summary',
    'Paper 2',
    'Summary',
    'Select, transform & compress',
    'A summary rewards relevant points expressed briefly in your own words. Decoration and repetition waste the word limit.',
    Icons.compress_rounded,
    Color(0xff7c64a5),
    [
      'Identify the exact focus: causes, effects, problems, benefits or actions.',
      'Highlight complete points; remove examples, stories and repetition.',
      'Combine related ideas, paraphrase, and count words carefully.',
      'Write connected prose unless instructions request notes.',
    ],
    [
      'Every point matches the focus',
      'No examples or repetition',
      'Mostly own words',
      'Within the word limit',
    ],
  ),
  Lesson(
    'language',
    'Paper 2',
    'Language Use',
    'Grammar, vocabulary & effect',
    'Use context to understand words, correct sentences and explain how language creates meaning.',
    Icons.spellcheck_rounded,
    Color(0xff4c9270),
    [
      'Check subject–verb agreement, pronouns, tense sequence and modifiers.',
      'Learn words in collocations and sentences, not isolated lists.',
      'For imagery, explain the comparison and the picture or feeling it creates.',
      'Punctuation controls meaning: practise commas, apostrophes, colons and speech.',
    ],
    [
      'Grammar rule identified',
      'Correction preserves meaning',
      'Effect linked to context',
      'Spelling and punctuation checked',
    ],
  ),
  Lesson(
    'narrative',
    'Paper 1',
    'Narrative Craft',
    'Plot, character, dialogue & viewpoint',
    'Shape a believable story around a change, decision or discovery instead of reporting a sequence of unrelated events.',
    Icons.movie_creation_rounded,
    Color(0xffb85b78),
    [
      'Give the central character a clear desire, obstacle and meaningful choice.',
      'Use a simple arc: situation, pressure, turning point, consequence and reflection.',
      'Dialogue must reveal character or move the plot; punctuate each new speaker clearly.',
      'Slow down at the turning point with action, thought and sensory detail.',
      'End by resolving the central tension, not by adding a sudden dream or accident.',
    ],
    [
      'Conflict appears early',
      'Events are causally connected',
      'Dialogue has a purpose',
      'The ending grows from the story',
    ],
  ),
  Lesson(
    'argument',
    'Paper 1',
    'Argumentative Writing',
    'Claims, evidence & counterarguments',
    'Build a reasoned position that anticipates objections and supports each claim with explanation or relevant examples.',
    Icons.gavel_rounded,
    Color(0xff9b6b43),
    [
      'Define the issue and state a clear position without merely repeating the title.',
      'Use one controlling reason per paragraph: claim, evidence, explanation and link.',
      'Acknowledge the strongest opposing view, then answer it fairly.',
      'Prefer specific Zimbabwean or everyday evidence to sweeping claims such as “everyone knows”.',
      'Conclude by weighing the case and reinforcing the position rather than listing points again.',
    ],
    [
      'Position is unmistakable',
      'Reasons are distinct',
      'Evidence is explained',
      'Counterargument answered',
    ],
  ),
  Lesson(
    'functional',
    'Paper 1',
    'Functional Formats',
    'Reports, articles, speeches & letters',
    'Select the conventions that make a real-world text easy for its intended reader to understand and act upon.',
    Icons.article_rounded,
    Color(0xff397f86),
    [
      'A report uses a title, factual findings, useful headings and workable recommendations.',
      'A speech greets listeners, uses inclusive language, rhetorical emphasis and a memorable call to action.',
      'An article needs a purposeful headline, engaging lead, developed body and appropriate close.',
      'Formal letters identify the matter quickly, organise details logically and request a clear outcome.',
      'Never let format replace content: develop every prompt with reasons, effects or examples.',
    ],
    [
      'Format suits task',
      'Reader can scan the response',
      'All prompts developed',
      'Action or conclusion is clear',
    ],
  ),
  Lesson(
    'summary-method',
    'Paper 2',
    'Summary Method',
    'A repeatable exam workflow',
    'Turn a long passage into focused, economical prose through selection, paraphrase and controlled counting.',
    Icons.filter_alt_rounded,
    Color(0xff76579c),
    [
      'Box the summary focus and note whether one or several parts of the passage are included.',
      'Number candidate points in the margin and test each one directly against the focus.',
      'Strip away examples, quotations, figurative decoration and duplicated ideas.',
      'Paraphrase accurately; a shorter statement that changes the meaning earns nothing.',
      'Join related points economically, then count and edit to the stated limit.',
    ],
    [
      'Focus copied correctly',
      'Points are distinct',
      'Meaning preserved in own words',
      'Word limit checked',
    ],
  ),
  Lesson(
    'inference',
    'Paper 2',
    'Inference & Writer’s Effect',
    'Read beneath the literal meaning',
    'Move from a precise textual clue to a defensible conclusion, then explain how deliberate language shapes the reader’s response.',
    Icons.psychology_rounded,
    Color(0xff4e70a5),
    [
      'An inference must be supported by a clue; avoid importing knowledge the passage does not suggest.',
      'For attitude or tone, identify the feeling and connect it to a word, image or sentence pattern.',
      'For imagery, state the literal comparison, relevant shared quality and contextual effect.',
      'For sound or repetition, explain what is emphasised or how pace and mood change.',
      'Use the formula evidence → meaning → effect, but write it naturally.',
    ],
    [
      'Inference has evidence',
      'Tone is precisely named',
      'Technique is not the whole answer',
      'Effect fits the context',
    ],
  ),
  Lesson(
    'editing',
    'Paper 2',
    'Grammar & Editing',
    'Accuracy under exam pressure',
    'Diagnose errors systematically and protect meaning while correcting grammar, spelling and punctuation.',
    Icons.fact_check_rounded,
    Color(0xff3e8c68),
    [
      'Locate the true subject before choosing a singular or plural verb.',
      'Keep time relationships logical when shifting between past, present and perfect tenses.',
      'Place modifiers next to the words they describe to avoid accidental meanings.',
      'Use apostrophes for possession or omission, never simply to form a plural.',
      'Proofread in passes: sentence boundaries, verbs, pronouns, punctuation, then spelling.',
    ],
    [
      'Subject and verb agree',
      'Tense sequence is logical',
      'Pronouns have clear references',
      'Sentence boundaries checked',
    ],
  ),
];

class Question {
  final String paper, q, why;
  final List<String> a;
  final int correct;
  const Question(this.paper, this.q, this.a, this.correct, this.why);
  factory Question.fromJson(Map<String, dynamic> json) => Question(
    json['paper'] == 'Paper 2' ? 'Paper 2' : 'Paper 1',
    json['question']?.toString() ?? '',
    List<String>.from(json['answers'] ?? const []),
    (json['correctIndex'] as num?)?.toInt() ?? 0,
    json['explanation']?.toString() ?? '',
  );
}

const bank = <Question>[
  Question(
    'Paper 1',
    'Which opening best suits a formal report?',
    [
      'You will not believe what happened!',
      'This report outlines the causes of late attendance and recommends solutions.',
      'Dear best friend, here is the news.',
      'Once upon a time, the bell rang.',
    ],
    1,
    'A report states its purpose clearly in an objective, formal register.',
  ),
  Question(
    'Paper 1',
    '“Describe the market just before a storm.” What is the main task?',
    [
      'Tell a long life story',
      'Argue against markets',
      'Create a vivid sensory scene and changing atmosphere',
      'Write shopping instructions',
    ],
    2,
    'The command word “describe” calls for sensory detail and atmosphere.',
  ),
  Question(
    'Paper 1',
    'Which sentence is most persuasive?',
    [
      'Litter is bad.',
      'Perhaps somebody could act.',
      'By placing labelled bins at every block, the council can cut litter and protect our water.',
      'There are bins.',
    ],
    2,
    'It offers a practical action and explains its benefit.',
  ),
  Question(
    'Paper 1',
    'Choose the sentence with correct agreement.',
    [
      'The list of reasons are convincing.',
      'The list of reasons is convincing.',
      'The reasons in the list is convincing.',
      'The list have convincing reasons.',
    ],
    1,
    'The head subject is singular: “list … is”.',
  ),
  Question(
    'Paper 1',
    'Before a guided response, first…',
    [
      'Memorise a generic essay',
      'Identify role, audience, purpose and content points',
      'Ignore the prompts',
      'Begin with your longest word',
    ],
    1,
    'Role, audience, purpose and prompts control the response.',
  ),
  Question(
    'Paper 2',
    '“In your own words” means…',
    [
      'Copy the sentence',
      'Replace one word',
      'Change vocabulary and structure but preserve meaning',
      'Add an opinion',
    ],
    2,
    'True paraphrase reshapes expression without changing the idea.',
  ),
  Question(
    'Paper 2',
    'Which detail should usually leave a summary?',
    [
      'A relevant cause',
      'A required consequence',
      'A lengthy example illustrating a point',
      'A distinct solution',
    ],
    2,
    'Examples illustrate core points but are not usually summary points.',
  ),
  Question(
    'Paper 2',
    '“The classroom was an oven” suggests it was…',
    [
      'made of metal',
      'extremely hot and uncomfortable',
      'used for cooking',
      'empty and silent',
    ],
    1,
    'The metaphor transfers the intense heat of an oven to the room.',
  ),
  Question(
    'Paper 2',
    'For a 2-mark question, give…',
    [
      'one vague sentence',
      'two distinct relevant ideas',
      'a quotation without explanation',
      'everything in the passage',
    ],
    1,
    'Marks commonly indicate the number of separate valid points.',
  ),
  Question(
    'Paper 2',
    'Choose correct punctuation.',
    [
      'Emma said “I am ready”.',
      'Emma said, “I am ready.”',
      'Emma, said “I am ready.”',
      'Emma said “I am ready”.',
    ],
    1,
    'The reporting clause takes a comma; final punctuation stays inside the quotation.',
  ),
  Question(
    'Paper 1',
    'Which is the strongest argumentative topic sentence?',
    [
      'School uniforms are clothes.',
      'There are many opinions about uniforms.',
      'A practical uniform policy reduces visible inequality without limiting achievement.',
      'I will discuss uniforms.',
    ],
    2,
    'It makes a specific, debatable claim that the paragraph can prove.',
  ),
  Question(
    'Paper 1',
    'Which detail best develops a narrative turning point?',
    [
      'Several unrelated descriptions',
      'The character makes a difficult choice that changes what follows',
      'A new main character appears on the last line',
      'The writer explains the moral before the action',
    ],
    1,
    'A turning point grows from the conflict and changes the direction or stakes.',
  ),
  Question(
    'Paper 1',
    'A report recommendation should be…',
    [
      'vague and emotional',
      'practical and linked to a finding',
      'a copied question prompt',
      'a private joke',
    ],
    1,
    'Recommendations solve problems established by the report’s findings.',
  ),
  Question(
    'Paper 1',
    'Which phrase best acknowledges a counterargument?',
    [
      'Anyone who disagrees is foolish.',
      'Although the plan has an initial cost, the long-term savings outweigh it.',
      'There is no other view.',
      'This is obviously correct.',
    ],
    1,
    'It presents a real objection fairly and answers it with reasoning.',
  ),
  Question(
    'Paper 1',
    'What is wrong with “Walking home, the rain soaked Tariro”?',
    [
      'Nothing',
      'The modifier suggests the rain was walking',
      'The tense is future',
      'Tariro is plural',
    ],
    1,
    'The opening modifier must logically describe the subject that follows it.',
  ),
  Question(
    'Paper 2',
    'Which is an inference rather than a copied fact?',
    [
      'The shop closed at five.',
      'Her repeated glances at the clock suggest she was anxious to leave.',
      'The passage uses three paragraphs.',
      'The bag was blue.',
    ],
    1,
    'It combines a textual clue with a logical conclusion about the character.',
  ),
  Question(
    'Paper 2',
    'A writer repeats short questions during an argument mainly to…',
    [
      'reduce the word count',
      'create urgency and challenge the reader',
      'change every noun',
      'prove the questions are unanswered',
    ],
    1,
    'Repeated rhetorical questions can quicken pace and confront the audience.',
  ),
  Question(
    'Paper 2',
    'Which is the best summary version of “Because buses were scarce, expensive and frequently late, many workers walked”?',
    [
      'Workers walked because bus services were unreliable and unaffordable.',
      'There were buses and workers and walking.',
      'Buses were scarce, expensive and frequently late, so many workers walked all the way to work every day.',
      'Workers disliked everything.',
    ],
    0,
    'It preserves the cause and result while compressing related details.',
  ),
  Question(
    'Paper 2',
    'Choose the correct apostrophe use.',
    [
      'The students books were marked.',
      'The student’s books were marked.',
      'The students book’s were marked.',
      'The students’ books were marked.',
    ],
    3,
    'The books belong to several students, so the apostrophe follows the plural noun.',
  ),
  Question(
    'Paper 2',
    'In writer’s-effect answers, after identifying a metaphor you should…',
    [
      'stop immediately',
      'explain the comparison and its contextual impression',
      'copy the entire paragraph',
      'define every word',
    ],
    1,
    'Technique names earn little without analysis of meaning and effect in context.',
  ),
];

class Store extends ChangeNotifier {
  final done = <String>{}, saved = <String>{};
  final remoteLessons = <Lesson>[];
  final remoteQuestions = <Question>[];
  int correct = 0, attempted = 0, streak = 0;
  String last = '',
      apiBaseUrl = '',
      apiToken = '',
      contentVersion = 'Bundled 1.1';
  bool syncing = false;
  List<Lesson> get allLessons => [...lessons, ...remoteLessons];
  List<Question> get allQuestions => [...bank, ...remoteQuestions];
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    done.addAll(p.getStringList('done') ?? []);
    saved.addAll(p.getStringList('saved') ?? []);
    correct = p.getInt('correct') ?? 0;
    attempted = p.getInt('attempted') ?? 0;
    streak = p.getInt('streak') ?? 0;
    last = p.getString('last') ?? '';
    apiBaseUrl = p.getString('apiBaseUrl') ?? '';
    apiToken = p.getString('apiToken') ?? '';
    contentVersion = p.getString('contentVersion') ?? 'Bundled 1.1';
    _decodeContent(p.getString('remoteContent'));
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('done', done.toList());
    await p.setStringList('saved', saved.toList());
    await p.setInt('correct', correct);
    await p.setInt('attempted', attempted);
    await p.setInt('streak', streak);
    await p.setString('last', last);
    await p.setString('apiBaseUrl', apiBaseUrl);
    await p.setString('apiToken', apiToken);
    await p.setString('contentVersion', contentVersion);
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
  }

  void configureApi(String url, String token) {
    apiBaseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    apiToken = token.trim();
    save();
    notifyListeners();
  }

  Map<String, String> get apiHeaders => {
    'Content-Type': 'application/json',
    if (apiToken.isNotEmpty) 'Authorization': 'Bearer $apiToken',
  };

  void _decodeContent(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      remoteLessons
        ..clear()
        ..addAll(
          (data['lessons'] as List? ?? []).map(
            (e) => Lesson.fromJson(Map<String, dynamic>.from(e)),
          ),
        );
      remoteQuestions
        ..clear()
        ..addAll(
          (data['questions'] as List? ?? []).map(
            (e) => Question.fromJson(Map<String, dynamic>.from(e)),
          ),
        );
    } catch (_) {}
  }

  Future<String> syncContent() async {
    if (apiBaseUrl.isEmpty) return 'Add your API URL in Coach settings first.';
    syncing = true;
    notifyListeners();
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/v1/content'), headers: apiHeaders)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'Update failed (${response.statusCode}).';
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final payload = jsonEncode({
        'lessons': data['lessons'] ?? [],
        'questions': data['questions'] ?? [],
      });
      _decodeContent(payload);
      contentVersion =
          data['version']?.toString() ?? 'Updated ${DateTime.now().toLocal()}';
      final p = await SharedPreferences.getInstance();
      await p.setString('remoteContent', payload);
      await save();
      notifyListeners();
      return 'Updated: ${remoteLessons.length} lessons and ${remoteQuestions.length} questions received.';
    } catch (e) {
      return 'Could not update. Check the URL, connection and server.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}

class EmmaPrep extends StatelessWidget {
  const EmmaPrep({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'EmmaPrep English',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: plum, surface: cream),
      scaffoldBackgroundColor: cream,
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    ),
    home: const Shell(),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final store = Store();
  int tab = 0;
  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: store,
    builder: (_, _) => Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: [
            Home(store),
            Learn(store),
            Practice(store),
            CoachPage(store),
            Progress(store),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Coach',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
        ],
      ),
    ),
  );
}

class Pad extends StatelessWidget {
  final Widget child;
  const Pad(this.child, {super.key});
  @override
  Widget build(BuildContext c) =>
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8), child: child);
}

class Home extends StatelessWidget {
  final Store s;
  const Home(this.s, {super.key});
  @override
  Widget build(BuildContext c) {
    final p = s.done.length / s.allLessons.length;
    return Pad(
      ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MANGWANANI,',
                    style: TextStyle(
                      color: plum,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Emmaculate ✦',
                    style: TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 24,
                backgroundColor: plum,
                child: Text(
                  '${s.streak}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: plum,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_fire_department, color: Color(0xffffc56e)),
                    SizedBox(width: 8),
                    Text(
                      'TODAY’S REVISION',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Small steps.\nStrong results.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: p,
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(9),
                  backgroundColor: Colors.white24,
                  color: const Color(0xffffc56e),
                ),
                const SizedBox(height: 8),
                Text(
                  '${s.done.length} of ${s.allLessons.length} lessons mastered',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Choose a paper',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PaperCard(
                  'Paper 1',
                  'Writing &\ncomposition',
                  '90 min',
                  coral,
                  Icons.edit_rounded,
                  s,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PaperCard(
                  'Paper 2',
                  'Reading &\nlanguage',
                  '120 min',
                  const Color(0xff4f7e7b),
                  Icons.menu_book_rounded,
                  s,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xffffe6c7),
                    child: Icon(Icons.lightbulb, color: Color(0xffa55c00)),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Text(
                      'Emma’s exam tip\nRead every command word twice. It tells you what the examiner rewards.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaperCard extends StatelessWidget {
  final String title, sub, time;
  final Color color;
  final IconData icon;
  final Store s;
  const PaperCard(
    this.title,
    this.sub,
    this.time,
    this.color,
    this.icon,
    this.s, {
    super.key,
  });
  @override
  Widget build(BuildContext c) => InkWell(
    onTap: () => Navigator.push(
      c,
      MaterialPageRoute(builder: (_) => PaperPage(title, s)),
    ),
    borderRadius: BorderRadius.circular(24),
    child: Container(
      height: 190,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(sub, style: const TextStyle(color: Colors.white, height: 1.25)),
          const SizedBox(height: 8),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class Learn extends StatefulWidget {
  final Store s;
  const Learn(this.s, {super.key});
  @override
  State<Learn> createState() => _LearnState();
}

class _LearnState extends State<Learn> {
  String f = 'All';
  @override
  Widget build(BuildContext c) {
    final items = widget.s.allLessons
        .where(
          (l) =>
              f == 'All' ||
              l.paper == f ||
              (f == 'Saved' && widget.s.saved.contains(l.id)),
        )
        .toList();
    return Pad(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revision library',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
          ),
          const Text('Clear notes, made for focused study.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => SyllabusPage(widget.s)),
            ),
            icon: const Icon(Icons.assignment_rounded),
            label: const Text('Open syllabus guide'),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Paper 1', 'Paper 2', 'Saved']
                  .map(
                    (x) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(x),
                        selected: f == x,
                        onSelected: (_) => setState(() => f = x),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => LessonTile(items[i], widget.s),
            ),
          ),
        ],
      ),
    );
  }
}

class LessonTile extends StatelessWidget {
  final Lesson l;
  final Store s;
  const LessonTile(this.l, this.s, {super.key});
  @override
  Widget build(BuildContext c) => Card(
    child: InkWell(
      onTap: () => Navigator.push(
        c,
        MaterialPageRoute(builder: (_) => LessonPage(l, s)),
      ),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 64,
              decoration: BoxDecoration(
                color: l.color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(l.icon, color: l.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.paper.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: l.color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    l.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    l.sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            Icon(
              s.done.contains(l.id) ? Icons.check_circle : Icons.chevron_right,
              color: s.done.contains(l.id)
                  ? const Color(0xff4c9270)
                  : Colors.black38,
            ),
          ],
        ),
      ),
    ),
  );
}

class PaperPage extends StatelessWidget {
  final String paper;
  final Store s;
  const PaperPage(this.paper, this.s, {super.key});
  @override
  Widget build(BuildContext c) {
    final a = s.allLessons.where((l) => l.paper == paper);
    return Scaffold(
      appBar: AppBar(title: Text(paper)),
      body: Pad(
        ListView(
          children: [
            Text(
              paper == 'Paper 1' ? 'Confident writing' : 'Careful reading',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            ...a.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LessonTile(l, s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LessonPage extends StatelessWidget {
  final Lesson l;
  final Store s;
  const LessonPage(this.l, this.s, {super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      actions: [
        IconButton(
          onPressed: () => s.bookmark(l.id),
          icon: Icon(
            s.saved.contains(l.id) ? Icons.bookmark : Icons.bookmark_border,
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
      children: [
        Container(
          width: 68,
          height: 68,
          alignment: Alignment.centerLeft,
          child: CircleAvatar(
            radius: 34,
            backgroundColor: l.color.withValues(alpha: .15),
            child: Icon(l.icon, size: 35, color: l.color),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l.paper.toUpperCase(),
          style: TextStyle(
            color: l.color,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          l.title,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(l.intro, style: const TextStyle(height: 1.5, fontSize: 16)),
        const SizedBox(height: 22),
        const Text(
          'CORE NOTES',
          style: TextStyle(
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 10),
        ...l.notes.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: l.color,
                  child: Text(
                    '${e.key + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e.value, style: const TextStyle(height: 1.45)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exam-ready checklist',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ...l.check.map(
                  (x) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: l.color,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(child: Text(x)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: s.done.contains(l.id)
                ? const Color(0xff4c9270)
                : plum,
            padding: const EdgeInsets.all(17),
          ),
          onPressed: () => s.complete(l.id),
          icon: const Icon(Icons.done_all),
          label: Text(
            s.done.contains(l.id) ? 'Lesson mastered' : 'Mark as mastered',
          ),
        ),
      ],
    ),
  );
}

class Practice extends StatelessWidget {
  final Store s;
  const Practice(this.s, {super.key});
  @override
  Widget build(BuildContext c) => Pad(
    ListView(
      children: [
        const Text(
          'Practice',
          style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
        ),
        const Text('Test recall. Learn from every answer.'),
        const SizedBox(height: 22),
        Drill(
          'Quick 5',
          'Five mixed questions.',
          Icons.bolt,
          coral,
          () => go(c, null, 5),
        ),
        Drill(
          'Paper 1 drill',
          'Writing, register and grammar.',
          Icons.edit_note,
          const Color(0xffde965d),
          () => go(c, 'Paper 1', null),
        ),
        Drill(
          'Paper 2 drill',
          'Comprehension, summary and language.',
          Icons.menu_book,
          const Color(0xff5679b6),
          () => go(c, 'Paper 2', null),
        ),
      ],
    ),
  );
  void go(BuildContext c, String? p, int? n) => Navigator.push(
    c,
    MaterialPageRoute(
      builder: (_) => Quiz(s, paper: p, count: n),
    ),
  );
}

class Drill extends StatelessWidget {
  final String t, sub;
  final IconData icon;
  final Color color;
  final VoidCallback tap;
  const Drill(this.t, this.sub, this.icon, this.color, this.tap, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withValues(alpha: .14),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(sub, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    ),
  );
}

class Quiz extends StatefulWidget {
  final Store s;
  final String? paper;
  final int? count;
  const Quiz(this.s, {this.paper, this.count, super.key});
  @override
  State<Quiz> createState() => _QuizState();
}

class _QuizState extends State<Quiz> {
  late List<Question> items;
  int at = 0, score = 0;
  int? pick;
  @override
  void initState() {
    super.initState();
    items =
        widget.s.allQuestions
            .where((q) => widget.paper == null || q.paper == widget.paper)
            .toList()
          ..shuffle(Random());
    if (widget.count != null) items = items.take(widget.count!).toList();
  }

  @override
  Widget build(BuildContext c) {
    final q = items[at];
    return Scaffold(
      appBar: AppBar(title: Text('Question ${at + 1} of ${items.length}')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          LinearProgressIndicator(
            value: (at + 1) / items.length,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: coral,
          ),
          const SizedBox(height: 26),
          Text(
            q.paper.toUpperCase(),
            style: const TextStyle(
              color: coral,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            q.q,
            style: const TextStyle(
              fontSize: 23,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          ...q.a.asMap().entries.map((e) {
            final reveal = pick != null,
                ok = e.key == q.correct,
                chosen = pick == e.key;
            Color fill = Colors.white, border = Colors.black12;
            if (reveal && ok) {
              fill = const Color(0xffe7f5ee);
              border = const Color(0xff4c9270);
            } else if (chosen) {
              fill = const Color(0xffffece8);
              border = coral;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: pick == null
                    ? () {
                        setState(() => pick = e.key);
                        final right = e.key == q.correct;
                        if (right) score++;
                        widget.s.answer(right);
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: fill,
                    border: Border.all(color: border, width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${String.fromCharCode(65 + e.key)}.  ${e.value}',
                  ),
                ),
              ),
            );
          }),
          if (pick != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xfffff1d7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('Why: ${q.why}'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                if (at == items.length - 1) {
                  Navigator.pushReplacement(
                    c,
                    MaterialPageRoute(
                      builder: (_) => Result(score, items.length),
                    ),
                  );
                } else {
                  setState(() {
                    at++;
                    pick = null;
                  });
                }
              },
              child: Text(
                at == items.length - 1 ? 'See my result' : 'Next question',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class Result extends StatelessWidget {
  final int score, total;
  const Result(this.score, this.total, {super.key});
  @override
  Widget build(BuildContext c) {
    final p = (score / total * 100).round();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, color: coral, size: 64),
              const SizedBox(height: 16),
              Text(
                p >= 70 ? 'Beautiful work, Emma!' : 'Keep building, Emma.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '$score / $total',
                style: const TextStyle(
                  fontSize: 48,
                  color: plum,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text('$p% correct'),
              const SizedBox(height: 24),
              const Text(
                'Review anything that felt uncertain, then try again. Progress comes from correction.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Back to practice'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatMessage {
  final bool user;
  final String text;
  const ChatMessage(this.user, this.text);
}

class CoachPage extends StatefulWidget {
  final Store s;
  const CoachPage(this.s, {super.key});
  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <ChatMessage>[
    const ChatMessage(
      false,
      'Hi Emma! I’m your English study coach. Ask me to explain a skill, mark a short answer, create a practice question, or help you plan a composition.',
    ),
  ];
  bool sending = false;

  Future<void> send([String? prompt]) async {
    final text = (prompt ?? input.text).trim();
    if (text.isEmpty || sending) return;
    if (widget.s.apiBaseUrl.isEmpty) {
      await settings();
      if (widget.s.apiBaseUrl.isEmpty) return;
    }
    setState(() {
      messages.add(ChatMessage(true, text));
      sending = true;
      input.clear();
    });
    try {
      final response = await http
          .post(
            Uri.parse('${widget.s.apiBaseUrl}/v1/chat'),
            headers: widget.s.apiHeaders,
            body: jsonEncode({
              'message': text,
              'student': 'Emmaculate',
              'course': 'ZIMSEC English Language 4005/01 and 4005/02',
              'mode': 'learning_and_practice',
              'history': messages
                  .take(max(0, messages.length - 8))
                  .map(
                    (m) => {
                      'role': m.user ? 'user' : 'assistant',
                      'content': m.text,
                    },
                  )
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 40));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.statusCode);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply =
          data['reply']?.toString() ??
          data['message']?.toString() ??
          'The coach returned an empty response.';
      if (mounted) setState(() => messages.add(ChatMessage(false, reply)));
    } catch (_) {
      if (mounted) {
        setState(
          () => messages.add(
            const ChatMessage(
              false,
              'I could not reach the study API. Check Coach settings and your internet connection. Your lessons and practice still work offline.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> settings() async {
    final url = TextEditingController(text: widget.s.apiBaseUrl);
    final token = TextEditingController(text: widget.s.apiToken);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Study API settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Connect your own backend. Keep provider secret keys on the server, not inside this app.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.example.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: token,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'App access token (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.s.configureApi(url.text, token.text);
              Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Pad(
    Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emma Coach',
                    style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
                  ),
                  Text('Explain • practise • improve'),
                ],
              ),
            ),
            IconButton(
              onPressed: settings,
              tooltip: 'API settings',
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ActionChip(
                label: const Text('Quiz me'),
                onPressed: () => send(
                  'Quiz me on a random Paper 1 or Paper 2 skill. Ask one question at a time and wait for my answer.',
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('Plan an essay'),
                onPressed: () => send(
                  'Help me plan a ZIMSEC composition. Give me three suitable prompts to choose from.',
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('Explain summary'),
                onPressed: () => send(
                  'Teach me the summary method with a short worked example, then give me a practice task.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            itemCount: messages.length + (sending ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == messages.length) {
                return const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final m = messages[i];
              return Align(
                alignment: m.user
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.all(14),
                  constraints: const BoxConstraints(maxWidth: 330),
                  decoration: BoxDecoration(
                    color: m.user ? plum : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    m.text,
                    style: TextStyle(
                      color: m.user ? Colors.white : ink,
                      height: 1.4,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: input,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Ask your study coach…',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(18)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : send,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ],
    ),
  );
}

class SyllabusPage extends StatelessWidget {
  final Store s;
  const SyllabusPage(this.s, {super.key});

  Future<void> open(String url) async =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Syllabus guide')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        const Text(
          'ZIMSEC English Language',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const Text(
          'Ordinary Level • 4005/01 and 4005/02',
          style: TextStyle(color: plum, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'This in-app guide organises revision around the current Paper 1 and Paper 2 structure. Official ZIMSEC documents and examination instructions remain the final authority.',
              style: TextStyle(height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _syllabusCard('Paper 1 • 90 minutes', 'Writing', [
          'Composition: narrative, descriptive and argumentative control',
          'Guided or functional writing for a specified audience and purpose',
          'Organisation, register, vocabulary, grammar, spelling and punctuation',
        ], coral),
        _syllabusCard('Paper 2 • 120 minutes', 'Reading & language', [
          'Comprehension: retrieval, inference and explanation',
          'Summary: selection, own words, concision and word-limit control',
          'Vocabulary, grammar, punctuation and writer’s use of language',
        ], const Color(0xff5679b6)),
        const SizedBox(height: 10),
        const Text(
          'Official resources',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.open_in_new, color: plum),
          title: const Text('ZIMSEC English Language 4005/01'),
          subtitle: const Text('Official download page'),
          onTap: () => open(
            'https://www5.zimsec.co.zw/download/english-language-4005-01/',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.open_in_new, color: plum),
          title: const Text('ZIMSEC English Language 4005/02'),
          subtitle: const Text('Official download page'),
          onTap: () => open(
            'https://www5.zimsec.co.zw/download/english-language-4005-02/',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.library_books, color: plum),
          title: const Text('ZIMSEC syllabus library'),
          subtitle: const Text('Select the current year of study'),
          onTap: () => open('https://www5.zimsec.co.zw/syllabi/'),
        ),
        const Divider(height: 28),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Content updates',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    s.contentVersion,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: s.syncing
                  ? null
                  : () async {
                      final message = await s.syncContent();
                      if (c.mounted) {
                        ScaffoldMessenger.of(
                          c,
                        ).showSnackBar(SnackBar(content: Text(message)));
                      }
                    },
              icon: s.syncing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: const Text('Sync'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _syllabusCard(
    String heading,
    String title,
    List<String> items,
    Color color,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (x) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: color, size: 19),
                  const SizedBox(width: 9),
                  Expanded(child: Text(x)),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class Progress extends StatelessWidget {
  final Store s;
  const Progress(this.s, {super.key});
  @override
  Widget build(BuildContext c) {
    final a = s.attempted == 0 ? 0 : (s.correct / s.attempted * 100).round();
    return Pad(
      ListView(
        children: [
          const Text(
            'Your progress',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
          ),
          const Text('Consistency is your quiet advantage.'),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: plum,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Stat('${s.streak}', 'day streak'),
                Stat('${s.done.length}/${s.allLessons.length}', 'lessons'),
                Stat('$a%', 'accuracy'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Paper mastery',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          ...['Paper 1', 'Paper 2'].map((p) {
            final all = s.allLessons.where((l) => l.paper == p).toList(),
                d = all.where((l) => s.done.contains(l.id)).length;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          p,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text('$d / ${all.length}'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: d / all.length,
                      minHeight: 9,
                      borderRadius: BorderRadius.circular(8),
                      color: p == 'Paper 1' ? coral : const Color(0xff5679b6),
                    ),
                  ],
                ),
              ),
            );
          }),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.bookmark, color: coral),
                  const SizedBox(width: 12),
                  Text(
                    '${s.saved.length} saved lessons for quick review',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Stat extends StatelessWidget {
  final String v, l;
  const Stat(this.v, this.l, {super.key});
  @override
  Widget build(BuildContext c) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(l, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    ),
  );
}
