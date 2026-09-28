import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/coach_text.dart';

export 'services/coach_text.dart';

const plum = Color(0xff2854c7),
    coral = Color(0xffff5f9e),
    cream = Color(0xfffff7fb),
    ink = Color(0xff211a20);
const compiledApiBaseUrl = String.fromEnvironment('EMMAPREP_API_URL');
const compiledAppToken = String.fromEnvironment('EMMAPREP_APP_TOKEN');
const compiledSupabaseUrl = String.fromEnvironment('EMMAPREP_SUPABASE_URL');
const compiledSupabaseKey = String.fromEnvironment('EMMAPREP_SUPABASE_KEY');
const companyEvaluationMode = bool.fromEnvironment('EMMAPREP_EVALUATION_MODE');
const evaluatorName = String.fromEnvironment(
  'EMMAPREP_EVALUATOR_NAME',
  defaultValue: 'Prospective partner',
);
const evaluationFeedbackUrl = String.fromEnvironment('EMMAPREP_FEEDBACK_URL');
bool supabaseReady = false;

String _encodeJpegDataUrl(Uint8List bytes) =>
    'data:image/jpeg;base64,${base64Encode(bytes)}';

Future<String> encodeImageForApi(XFile image) async =>
    compute(_encodeJpegDataUrl, await image.readAsBytes());

String signedInStudentName() {
  if (!supabaseReady) return 'Student';
  final user = Supabase.instance.client.auth.currentUser;
  final displayName = user?.userMetadata?['display_name']?.toString().trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final emailName = user?.email?.split('@').first.trim();
  return emailName == null || emailName.isEmpty ? 'Student' : emailName;
}

String signedInStudentInitial() {
  final name = signedInStudentName();
  return name.characters.first.toUpperCase();
}

String learnerDisplayName() => signedInStudentName();

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (compiledSupabaseUrl.isNotEmpty && compiledSupabaseKey.isNotEmpty) {
    await Supabase.initialize(
      url: compiledSupabaseUrl,
      publishableKey: compiledSupabaseKey,
    );
    supabaseReady = true;
  }
  runApp(const EmmaPrep());
}

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

({String worked, String task}) practicalExample(
  Lesson lesson,
) => switch (lesson.id) {
  'composition' => (
    worked:
        'Question: “Write about a day a small mistake caused a big problem.”\n\nPlan: I miss the bus → borrow my sister’s bicycle → tyre bursts → arrive late for an important interview → learn to prepare the night before. The events connect because each one causes the next.',
    task:
        'Write a five-step plan for: “The message I wish I had read earlier.” Make every event cause the next one.',
  ),
  'guided' => (
    worked:
        'Task: Write a report about litter at school.\n\nWeak: “The school is dirty. Students are bad.”\n\nBetter finding: “Most litter collects beside the tuckshop because the nearest bin is behind the administration block.”\nRecommendation: “Place two labelled bins beside the tuckshop and appoint a weekly recycling team.”',
    task:
        'Write one factual finding and one practical recommendation about learners arriving late.',
  ),
  'style' => (
    worked:
        'To a friend: “Please come early so we can revise together.”\nTo the headteacher: “I respectfully request permission to use the library for our revision session.”\n\nThe purpose is similar, but the relationship changes the wording.',
    task:
        'Ask a friend and then a headteacher for the same favour. Make the two tones clearly different.',
  ),
  'comprehension' => (
    worked:
        'Passage clue: “Tariro checked the gate twice, then kept the key in her pocket.”\nQuestion: Why did Tariro keep the key?\nAnswer: She wanted to make sure nobody entered after she locked the gate.\n\nThe answer combines the clue with its logical meaning.',
    task:
        'Clue: “He kept looking at the dark clouds and quickened his steps.” What can you infer, and which words support you?',
  ),
  'summary' => (
    worked:
        'Original: “The kombis were often late, charged high fares and sometimes failed to arrive, so workers started walking.”\nSummary: “Workers walked because kombi services were unreliable and expensive.”\n\nThe shorter version keeps the cause and result but removes repetition.',
    task:
        'Shorten this: “The classroom had broken windows, leaking roofing and no working lights, so lessons stopped when the storm began.”',
  ),
  'language' => (
    worked:
        'Incorrect: “The list of books are on the desk.”\nCorrect: “The list of books is on the desk.”\n\nThe subject is list, not books, so the verb must be singular.',
    task: 'Correct and explain: “The basket of tomatoes were left outside.”',
  ),
  'narrative' => (
    worked:
        'Flat: “I lost the money. I went home. My mother was angry.”\nDeveloped turning point: “At the gate I reached into my pocket and felt only the torn lining. I could hide the truth, or walk inside and explain.”\n\nThe second version gives the character a meaningful choice.',
    task:
        'Write three sentences showing a character deciding whether to admit a mistake.',
  ),
  'argument' => (
    worked:
        'Claim: Schools should create one supervised study hour.\nEvidence: Many learners travel long distances and reach homes where chores leave little quiet time.\nExplanation: A supervised hour gives every learner reliable study time, not only those with quiet homes.',
    task:
        'Build claim → evidence → explanation for: “Every school should have a reading club.”',
  ),
  'functional' => (
    worked:
        'Speech opening: “Good morning, fellow learners. Every day we lose valuable study time searching for missing books. Today I propose a simple class-library register.”\n\nIt greets the audience, names a shared problem and introduces a solution.',
    task:
        'Write a two-sentence opening for a speech encouraging new learners to study consistently.',
  ),
  'summary-method' => (
    worked:
        'Focus: Problems caused by council water cuts.\nPassage details: queues form at the borehole; clinics cannot clean equipment; vegetable gardens dry; one resident tells a long story about carrying buckets.\nKeep the first three problems. Remove the resident’s story because it is only an example.',
    task:
        'From a paragraph about unemployment, list two core effects and one example that you would remove.',
  ),
  'inference' => (
    worked:
        'Words: “She folded the rejection letter carefully and placed it beside three others.”\nInference: She has applied several times and is disappointed but has not simply thrown the letters away.\nEvidence: “three others” shows repetition; “carefully” suggests the letters still matter.',
    task:
        'Infer the mood: “No one spoke. Even the radio had been switched off.” Explain using one textual clue.',
  ),
  'editing' => (
    worked:
        'Unclear: “Walking to school, the rain soaked Emma.” This sounds as if the rain was walking.\nClear: “While Emma was walking to school, the rain soaked her.”',
    task:
        'Correct the misplaced description: “Running across the road, the bag fell from Tino’s shoulder.”',
  ),
  'beginner-question-words' => (
    worked:
        'Question: “How did he rise?”\nIncomplete: “He rose.”\nComplete: “He rose slowly.”\n\nThe word how asks for the manner. Slowly is the detail that earns the mark.',
    task:
        'Answer fully: “Why did Rudo close the window?” Clue: Dust from the road was entering the room.',
  ),
  'beginner-own-words' => (
    worked:
        'Original: “The boat was angled awkwardly.”\nSimple meaning: “The boat was bent or slanted in a clumsy way.”\n\nAngled changes to bent/slanted; awkwardly changes to in a clumsy way.',
    task:
        'Put into your own words: “He scrambled up the steep bank.” Hint: he moved upward with difficulty.',
  ),
  'beginner-summary-actions' => (
    worked:
        'Passage: “Dewey’s throat became dry. He wanted to turn and run back.”\nUseful points: “His throat became dry” and “He felt like running back.”\n\nBoth show his reaction. We do not add our own opinion that he was cowardly.',
    task:
        'Separate these into ACTION and FEELING: “She stepped back and suddenly felt afraid.”',
  ),
  'beginner-paper1-task' => (
    worked:
        'Task: “As head prefect, write a speech advising new learners about study habits.”\nRole: head prefect. Audience: new learners. Purpose: advise. Content: practical study habits. Tone: friendly, confident and responsible.',
    task:
        'Decode this task: “Write a letter to your council complaining about unsafe roads near your school.” Identify role, audience, purpose and content.',
  ),
  'paper2-direct-retrieval' => (
    worked:
        'Passage: “After the bridge collapsed, villagers used the longer northern road.”\nQuestion: Why did the villagers use the northern road?\nAnswer: Because the bridge had collapsed.\n\nThe answer gives the stated cause directly. It does not add an unsupported opinion.',
    task:
        'Passage: “The clinic closed early when its generator stopped.” Why did the clinic close early? Answer in one precise sentence.',
  ),
  'paper2-reference-words' => (
    worked:
        'Sentence: “Rudo carried the injured bird home and placed it in a box.”\nQuestion: What does “it” refer to?\nAnswer: The injured bird.\n\nReplace the reference word with your answer. “Rudo placed the injured bird in a box” still makes sense.',
    task:
        'Sentence: “The driver handed Tariro the receipt, but she immediately lost it.” What does “it” refer to?',
  ),
  'paper2-context-vocabulary' => (
    worked:
        'Sentence: “The guard scrutinised every identity card before opening the gate.”\nMeaning: examined carefully.\n\n“Looked” is too weak because it misses the idea of careful attention.',
    task:
        'In “The child peered through the dusty window,” give a short phrase that means the same as “peered” in this context.',
  ),
  'paper2-word-choice' => (
    worked:
        'Sentence: “A tiny figure crawled across the enormous field.”\nQuestion: Why use “tiny”?\nAnswer: It emphasises how small and vulnerable the figure looked against the wide field.\n\nDo not answer only “because it was small”; explain the picture or effect.',
    task:
        'Why might a writer call a moving person “a speck” when viewed from high above? Give the contextual effect.',
  ),
  'paper2-summary-grid' => (
    worked:
        'Focus: actions taken by a lost traveller.\nRaw details: “He nervously shouted again and again. He climbed a tall rock. He waved his red shirt.”\nGrid notes: shouted repeatedly | climbed rock | waved shirt\nContinuous version: “He repeatedly called for help, climbed a rock and waved his shirt.”\n\nThe final sentence keeps three actions but removes decoration.',
    task:
        'Turn these into concise summary points: “She quickly tied the rope; she pulled the canoe ashore; she repeatedly checked it for damage.”',
  ),
  'p1-exam-map-2024' => (
    worked:
        'June 2024 instruction check:\n• Total time: 1 hour 30 minutes\n• Answer two questions\n• Section A: choose one composition, 350–450 words, 30 marks, about 50 minutes\n• Section B: answer the compulsory guided task, 20 marks, about 40 minutes\n\nSafe timing: Section A plan 5, write 40, edit 5; Section B plan 5, write 30, edit 5.',
    task:
        'Without looking, state how many questions you answer, the word range for Section A and the suggested time for each section.',
  ),
  'p1-description-2024' => (
    worked:
        'Exam question: “Describe what you would do with a million United States dollar prize.”\n\nDecode it: describe planned actions, choices and reasons. A strong route could move from immediate family needs, to education or enterprise, to community benefit, while showing priorities and consequences. Do not merely list purchases.',
    task:
        'Make a five-paragraph plan for the prize question. Give each paragraph one action, its reason and its likely result.',
  ),
  'p1-statement-story-2024' => (
    worked:
        'Exam statement: “The family secret had been exposed and there was nothing the father could do.”\n\nBuild backwards: What secret? Who exposed it? Why is the father powerless? Then build forwards: confrontation, consequence and change. The exact statement must matter naturally at the turning point or ending.',
    task:
        'Write a six-event plot in which the exposed secret causes the ending. Circle where the examination statement fits naturally.',
  ),
  'p1-argument-2024' => (
    worked:
        'Exam question: “How can the standard of discipline in schools be improved?”\n\nParagraph plan: clear rules and fair consequences; counselling and parent partnership; engaging lessons and activities; learner leadership; consistent adult example. Each paragraph needs method → explanation → practical example → expected result.',
    task:
        'Develop one paragraph on counselling using this frame: method, why it works, realistic school example, result.',
  ),
  'p1-open-title-2024' => (
    worked:
        'Exam title: “Food”.\n\nThe instruction says not to treat the title as a character’s name. Choose a controlled interpretation: a descriptive market scene, a story about scarcity or generosity, or an argument about food waste. Make “food” central from beginning to end.',
    task:
        'Choose one valid approach to “Food” and write a one-sentence controlling idea plus five paragraph purposes.',
  ),
  'p1-guided-letter-2024' => (
    worked:
        'June 2024 task map:\nRole: Junior Member of Parliament for the local area.\nReader: Officer-in-Charge of the nearest police station.\nPurpose: raise concern about rising crime, suggest causes and propose ways to reduce it.\nGiven ideas: awareness campaigns, youth unemployment, indiscipline, drug/alcohol abuse and community involvement.\n\nGroup the ideas instead of copying them: causes → unemployment, indiscipline, substance abuse; solutions → campaigns, community/police cooperation, youth programmes. Add one relevant developed idea.',
    task:
        'Write the subject line, formal opening and one developed cause-solution paragraph for this exact role and reader.',
  ),
  _ => (
    worked:
        'Take one rule from this lesson and apply it to a sentence or short paragraph from everyday life. Compare your first attempt with the checklist below.',
    task:
        'Create your own example, then explain in one sentence why it follows the lesson rule.',
  ),
};

String? modelAnswerFor(Lesson lesson) => switch (lesson.id) {
  'p1-description-2024' =>
    'If I won a million United States dollars, I would first place most of it in a secure account and seek qualified financial advice. Excitement can turn a prize into waste, so every major decision would need a budget and a clear purpose.\n\n'
        'My first priority would be my family. I would buy a modest home, arrange reliable medical care for my parents and create an education fund for younger relatives. These choices would provide security without creating an expensive lifestyle that the family could not maintain.\n\n'
        'Next, I would establish a solar-powered food-processing business that bought tomatoes, groundnuts and fruit from local farmers. The business could produce dried fruit, peanut butter and bottled sauces while creating employment. I would begin on a small scale, employ experienced managers and reinvest part of the profit.\n\n'
        'I would use another portion to open a community reading and skills centre with textbooks, internet access and evening lighting. Learners would gain a quiet study space, while young adults could attend practical courses. Finally, I would keep an emergency reserve and invest for the future. The prize would therefore become more than money for luxury: it would strengthen my family, create work and give other people lasting opportunities.',
  'p1-statement-story-2024' =>
    'The envelope lay unopened in the centre of the dining-room table. My father stood by the window while angry residents gathered outside our gate. That morning, a newspaper had published documents showing that he had secretly sold the community football ground to a property company. For years, he had led the campaign to protect it.\n\n'
        'Coach Moyo entered and placed the newspaper before him. “Why?” he asked. Father admitted that he had needed money for Mother’s treatment and had believed he could replace it before anyone discovered the sale. The drought had killed the cattle he planned to sell, while the company’s machines were already waiting beside the field. The family secret had been exposed and there was nothing the father could do.\n\n'
        'Then my sister brought out the sports club’s small cashbox. Her action inspired former players to begin a national fundraising campaign, and a lawyer offered to challenge the sale because residents had not been consulted. Months later, the agreement was cancelled. Father contributed everything he could, but he was not asked to lead the reopening celebration. Saving the field did not erase his betrayal; it merely gave him the chance to begin earning forgiveness.',
  'p1-argument-2024' =>
    'The standard of discipline in schools can be improved when schools combine clear rules with support that addresses the causes of misconduct. Punishment alone may stop an action briefly, but it does not always teach a learner to make better choices.\n\n'
        'First, each school should use a short code of conduct that learners and parents understand. It must connect each offence to a fair and consistent consequence. Schools should also provide counselling because repeated aggression, absence or substance abuse may be linked to bullying, grief or serious difficulties at home. Counselling does not excuse wrongdoing; it helps remove the problem that punishment may leave untouched.\n\n'
        'Parents should receive concerns early and help create improvement plans. Sport, debate, music and community service can also give learners responsibility and belonging. Finally, teachers must model punctuality, respect and self-control. Discipline becomes credible when adults follow the standards they demand.\n\n'
        'Therefore, better discipline requires fair rules, consistent consequences, counselling, parent cooperation, purposeful activities and responsible adult example. When these measures work together, discipline becomes part of education rather than a response based only on fear.',
  'p1-open-title-2024' =>
    'By five o’clock, the market had become a theatre of colour and sound. Tomatoes formed red mountains, vegetables glistened beneath sprays of water and vendors raised plates of sadza above the crowd. Tariro moved between the stalls with twelve dollars and a family waiting for supper.\n\n'
        'Near the exit, she noticed an elderly woman behind a tray of soft, spotted bananas. Buying them would leave little money for cooking oil, but the woman’s hands shook as she packed the fruit. Tariro bought the entire tray. At home, her brothers helped mash the bananas, mix them with flour and cook small cakes beside a pot of beans.\n\n'
        'The next morning, Tariro carried two cakes back to the market. The old woman tasted one and offered her an empty corner beside the stall. Within a week, Tariro was buying overripe fruit that vendors would otherwise throw away and turning it into affordable breakfasts. Food had first appeared as a daily problem measured in coins. Imagination transformed it into dignity, useful work and hope.',
  'p1-guided-letter-2024' =>
    '24 Chiedza Road\nMufaro Township\n14 June 2024\n\nThe Officer-in-Charge\nMufaro Police Station\nMufaro\n\nDear Sir/Madam\n\nRE: RISING CRIME IN MUFARO TOWNSHIP\n\n'
        'I write in my capacity as the Junior Member of Parliament for Mufaro to express residents’ concern about increasing robberies, assaults and house break-ins. The incidents have made workers afraid to travel after dark and forced some businesses to close early.\n\n'
        'Youth unemployment leaves some young people vulnerable to criminal groups promising quick money. Drug and alcohol abuse worsens the problem, while indiscipline and fear prevent residents from reporting offenders. I propose police-led awareness campaigns on safety and confidential reporting, together with targeted patrols around poorly lit roads and business centres.\n\n'
        'Residents could form neighbourhood watch groups under police guidance. Schools, churches and businesses should also provide counselling, sport, skills training and apprenticeships for young people. I therefore request a meeting between your station and community representatives to agree on responsibilities and a timetable.\n\nYours faithfully\n\nT. Moyo\nJunior Member of Parliament - Mufaro',
  _ => null,
};

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
  Lesson(
    'beginner-question-words',
    'Paper 2',
    'Understand the Question',
    'A beginner’s first step',
    'Before finding an answer, understand what the question wants. The 2022 examiner report says many learners lost marks because they repeated words or missed one key detail.',
    Icons.help_center_rounded,
    Color(0xff3478d4),
    [
      'Read the whole passage once. Do not start with only the paragraph number.',
      'Circle the doing word: name, explain, describe, give two, or use your own words.',
      'Underline small but important words such as again, beyond, how and why.',
      'Example: “How did he rise?” needs slowly. “He rose” is not complete.',
      'Read your answer beside the question. Ask: Did I answer every part?',
    ],
    [
      'I read the whole passage',
      'I found the doing word',
      'I noticed key details',
      'My answer fits every part',
    ],
  ),
  Lesson(
    'beginner-own-words',
    'Paper 2',
    'Own Words Made Easy',
    'Say the same meaning differently',
    'An own-words answer is not a new idea. It keeps the original meaning but changes the important vocabulary and sentence shape.',
    Icons.swap_horiz_rounded,
    Color(0xff925bd1),
    [
      'Step 1: find the exact words in the passage that answer the question.',
      'Step 2: explain those words to yourself in very simple language.',
      'Step 3: write the simple meaning without looking at the original sentence.',
      'Example from the examiner report: angled awkwardly can become bent in a clumsy way.',
      'Check that your replacement fits this passage. A dictionary meaning can still be wrong in context.',
    ],
    [
      'Meaning stayed the same',
      'Important words changed',
      'Sentence shape changed',
      'Answer still fits the passage',
    ],
  ),
  Lesson(
    'beginner-summary-actions',
    'Paper 2',
    'Summary: Actions & Feelings',
    'Learn from the November 2022 task',
    'The 2022 summary asked for Dewey’s actions and feelings. The examiner rewarded exact details and rejected incomplete points. This lesson teaches that precision simply.',
    Icons.playlist_add_check_circle_rounded,
    Color(0xffff5f9e),
    [
      'Make two quick labels: ACTION = what he did; FEELING = what happened inside him.',
      'Keep meaning-changing details. “He rose slowly” is different from “He rose”.',
      'Make pronouns clear. If you write “it”, the reader must know what “it” means.',
      'Turn description into the person’s experience: “There was stillness” becomes “He sensed the stillness”.',
      'Remove repeated examples, but never remove a word that completes the point.',
    ],
    [
      'Every point is an action or feeling',
      'Important how/when words remain',
      'Pronouns are clear',
      'No repeated point',
    ],
  ),
  Lesson(
    'beginner-paper1-task',
    'Paper 1',
    'Decode a Writing Task',
    'Know what to write before you begin',
    'A Paper 1 task becomes easier when you turn it into four small questions: Who am I? Who will read? Why am I writing? What must I include?',
    Icons.route_rounded,
    Color(0xff2854c7),
    [
      'WHO AM I? A student, witness, friend, reporter or speaker writes differently.',
      'WHO READS IT? A headteacher needs a different tone from a close friend.',
      'WHY? Decide whether you must describe, tell, explain, persuade or advise.',
      'WHAT? Turn every prompt into a checkbox and develop it with a reason or example.',
      'Plan the order in five minutes, then write one clear paragraph at a time.',
    ],
    [
      'Role identified',
      'Reader identified',
      'Purpose identified',
      'Every prompt planned',
    ],
  ),
  Lesson(
    'paper2-direct-retrieval',
    'Paper 2',
    'Direct Answers from the Passage',
    'Find the fact and match the question word',
    'Typical comprehension questions often ask what, why, where or how. A short answer earns the mark only when it includes the exact fact requested.',
    Icons.travel_explore_rounded,
    Color(0xff2f72b7),
    [
      'Use the paragraph reference to locate the answer, but read the sentence before and after it too.',
      'Match the question word: why needs a reason; how needs manner; what needs the named fact or action.',
      'Lift only when own words are not required, and never copy a whole paragraph.',
      'For one mark, give one complete point without an unnecessary story.',
      'Check that your answer can follow the wording of the question naturally.',
    ],
    [
      'Correct paragraph used',
      'Question word answered',
      'One complete point given',
      'No unsupported detail added',
    ],
  ),
  Lesson(
    'paper2-reference-words',
    'Paper 2',
    'Reference Words and Phrases',
    'Work out who or what a phrase identifies',
    'Questions such as “What does this refer to?” test whether you can follow people, animals, objects and ideas through a passage.',
    Icons.alt_route_rounded,
    Color(0xff4f6bb3),
    [
      'Spot the reference word or phrase: it, this, that, they, its passenger or the victim.',
      'Look backwards for the nearest noun that matches the meaning and grammar.',
      'Substitute your answer into the sentence; the sentence should still make sense.',
      'Give the precise noun, not a vague answer such as “the thing” or the wrong character.',
      'Use the surrounding action to decide between two possible nouns.',
    ],
    [
      'Reference expression identified',
      'Matching noun located',
      'Substitution makes sense',
      'Answer is precise',
    ],
  ),
  Lesson(
    'paper2-context-vocabulary',
    'Paper 2',
    'Vocabulary in Context',
    'Replace a word without changing its meaning',
    'The familiar word may not be the correct synonym. ZIMSEC-style vocabulary questions reward the meaning the word has in that particular sentence.',
    Icons.manage_search_rounded,
    Color(0xff7b5ca8),
    [
      'Read the complete sentence and picture the action before suggesting a synonym.',
      'Match the part of speech: replace a verb with a verb and an adverb with an adverb.',
      'Test your replacement inside the original sentence.',
      'Keep every important shade of meaning: “scrutinised” means examined carefully, not merely saw.',
      'Give one word or a short phrase when that is what the instruction requests.',
    ],
    [
      'Context read first',
      'Part of speech matches',
      'Important meaning preserved',
      'Response length follows instruction',
    ],
  ),
  Lesson(
    'paper2-word-choice',
    'Paper 2',
    'Why the Writer Chose That Word',
    'Explain the picture, scale or feeling created',
    'A word-choice question is not answered by repeating the word. Explain what it helps the reader see, feel or understand in that moment.',
    Icons.auto_awesome_rounded,
    Color(0xffad5a86),
    [
      'Give the simple contextual meaning first.',
      'Then explain the extra picture, contrast, attitude or emotion created.',
      'Relate the effect to the scene—for example, distance can make a large object look tiny.',
      'Avoid circular answers such as “speck is used because it was a speck”.',
      'Use the pattern: word → contextual meaning → effect on the scene.',
    ],
    [
      'Meaning explained',
      'Effect goes beyond repetition',
      'Answer fits the scene',
      'No technique-only answer',
    ],
  ),
  Lesson(
    'paper2-summary-grid',
    'Paper 2',
    'Summary Grid to Continuous Writing',
    'Select actions, count accurately and join them',
    'A grid helps control the word count, but the final response must be clear continuous writing that keeps only the requested actions, feelings, causes or effects.',
    Icons.grid_on_rounded,
    Color(0xff6a5aa8),
    [
      'Underline the summary focus and starting and ending paragraphs.',
      'Write one useful word in each grid cell; a hyphenated expression counts according to the paper instruction.',
      'Select distinct points before worrying about elegant sentences.',
      'Remove examples, description and repeated actions, but keep details that change meaning.',
      'Join points into grammatical prose, then recount and stay within the stated limit.',
    ],
    [
      'Focus and paragraph range correct',
      'Points are distinct and relevant',
      'Continuous writing is grammatical',
      'Words counted and limit respected',
    ],
  ),
  Lesson(
    'p1-exam-map-2024',
    'Paper 1',
    'June 2024 Paper 1: Know the Exam',
    'Question choice, marks, length and timing',
    'Start with the paper itself. A learner who misunderstands the choices, word range or timing can lose marks before the writing is judged.',
    Icons.timer_rounded,
    Color(0xff2854c7),
    [
      'Answer exactly two questions: one chosen composition from Section A and the compulsory Section B task.',
      'Section A carries 30 marks and requires 350–450 words; the paper advises 50 minutes.',
      'Section B carries 20 marks; the paper advises 40 minutes and a fresh page.',
      'Choose the Section A question you can develop accurately, not the one with the most impressive title.',
      'Reserve five minutes in each section for planning and five for checking.',
    ],
    [
      'Two answers only',
      'One Section A choice',
      'Section B completed',
      'Timing and word range remembered',
    ],
  ),
  Lesson(
    'p1-description-2024',
    'Paper 1',
    'Q1: Describe What You Would Do',
    'Turn a broad prize question into developed choices',
    'The exact June 2024 question asks what you would do with a million-US-dollar prize. It tests organisation, relevant development, control and clear expression—not a shopping list.',
    Icons.savings_rounded,
    Color(0xffd75d62),
    [
      'Underline “describe what you would do”; every main paragraph must present and develop an action.',
      'Arrange actions by priority or time: immediate, medium-term and long-term.',
      'For every choice, explain why it matters and what result it would produce.',
      'Use specific detail, but keep the imagined spending believable and connected.',
      'End by showing the overall difference the prize would make.',
    ],
    [
      'Actions answer the title',
      'Reasons and effects developed',
      'Paragraph order is logical',
      'Not merely a list',
    ],
  ),
  Lesson(
    'p1-statement-story-2024',
    'Paper 1',
    'Q2: Story from a Given Statement',
    'Make the supplied sentence essential to the plot',
    'June 2024 warns that forcing a supplied statement into an unrelated story is penalised. Plan the cause and consequences around the statement before writing.',
    Icons.account_tree_rounded,
    Color(0xffb85b78),
    [
      'Decide whether the statement is the opening, turning point or ending.',
      'Ask what must happen before the statement can be true.',
      'Ask what must change because of it; this creates the rest of the plot.',
      'Use few believable characters and one central conflict.',
      'Keep tense and viewpoint stable and avoid an unrelated memorised story.',
    ],
    [
      'Statement drives the plot',
      'Clear cause and consequence',
      'Conflict reaches a turning point',
      'Ending resolves the central problem',
    ],
  ),
  Lesson(
    'p1-argument-2024',
    'Paper 1',
    'Q3, Q5 and Q6: Views and Discussion',
    'Build a position with reasons, examples and balance',
    'The June 2024 paper includes “What are your views?”, “How can...?” and “Discuss.” These commands need related but different answer plans.',
    Icons.balance_rounded,
    Color(0xff9b6b43),
    [
      '“What are your views?” requires a clear position supported by reasons.',
      '“How can...be improved?” requires practical methods and explanations of how they work.',
      '“Discuss” requires fair consideration of both sides before a reasoned judgement.',
      'Use claim → explanation → example → link in each body paragraph.',
      'Avoid unsupported claims, insults and repeating the title as a conclusion.',
    ],
    [
      'Command word controls structure',
      'Position is clear',
      'Examples are realistic',
      'Conclusion weighs the argument',
    ],
  ),
  Lesson(
    'p1-open-title-2024',
    'Paper 1',
    'Q7: One-Word Open Title',
    'Choose one interpretation and control it',
    'The June 2024 title is “Food”, with an instruction not to use it as a character’s name. Open titles reward relevance and control, not an attempt to mention every possible meaning.',
    Icons.restaurant_rounded,
    Color(0xffde965d),
    [
      'Choose a mode before planning: narrative, descriptive, reflective or argumentative.',
      'Write one controlling sentence that explains what the whole composition will explore.',
      'Make every paragraph deepen that interpretation of the title.',
      'Use an opening image, conflict or claim that immediately establishes relevance.',
      'Check the special instruction; breaking it can damage relevance severely.',
    ],
    [
      'One clear interpretation',
      'Special instruction obeyed',
      'Title remains central',
      'Paragraphs develop rather than wander',
    ],
  ),
  Lesson(
    'p1-guided-letter-2024',
    'Paper 1',
    'Section B: Crime Letter',
    'Decode role, reader, causes and solutions',
    'The compulsory June 2024 task is a formal letter from a Junior Member of Parliament to a police Officer-in-Charge about rising crime. It requires concern, causes, solutions, supplied ideas and other relevant information.',
    Icons.mark_email_read_rounded,
    Color(0xff397f86),
    [
      'Use a formal letter format, a precise subject line and a respectful official tone.',
      'State the local crime concern and purpose immediately.',
      'Develop causes such as unemployment, indiscipline and substance abuse instead of copying the prompts.',
      'Develop solutions such as awareness campaigns, community involvement, visible policing and youth programmes.',
      'Link each recommendation to a cause and request clear action in the closing.',
    ],
    [
      'Role and reader correct',
      'Formal format and register',
      'Causes explained',
      'Solutions developed and linked',
    ],
  ),
];

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

const bank = <Question>[
  Question(
    'Paper 1',
    'In the June 2024 Paper 1, what must a candidate answer?',
    [
      'Any two Section A compositions',
      'One Section A composition and the Section B task',
      'Only the Section B task',
      'All seven Section A topics',
    ],
    1,
    'The instructions require two answers: one chosen composition from Section A and the compulsory question from Section B.',
  ),
  Question(
    'Paper 1',
    'What is the required Section A composition length in the June 2024 paper?',
    ['150–200 words', '250–300 words', '350–450 words', 'At least 600 words'],
    2,
    'The printed instruction specifies 350–450 words for Section A.',
  ),
  Question(
    'Paper 1',
    'A candidate chooses the million-dollar-prize question. Which plan best answers “Describe what you would do”?',
    [
      'A list of expensive items with no explanation',
      'A history of money in the world',
      'Prioritised actions, with reasons and likely results',
      'A story in which no prize is received',
    ],
    2,
    'The task requires developed actions. Reasons and consequences turn a list into a controlled composition.',
  ),
  Question(
    'Paper 1',
    'What is the main danger when writing a story from a supplied statement?',
    [
      'Using paragraphs',
      'Making the statement essential to the plot',
      'Forcing the statement into an unrelated memorised story',
      'Using past tense',
    ],
    2,
    'The paper explicitly warns that an irrelevant story with a forced statement will be penalised.',
  ),
  Question(
    'Paper 1',
    'Which structure best answers “How can the standard of discipline in schools be improved?”',
    [
      'Method → explanation → example → expected result',
      'A list of badly behaved learners',
      'A story about one school day',
      'Definitions of every word in the title',
    ],
    0,
    '“How can” asks for workable methods. Each method must be explained and connected to an improvement.',
  ),
  Question(
    'Paper 1',
    'For the June 2024 one-word title “Food”, which approach obeys the special instruction?',
    [
      'Make Food the name of the main character',
      'Write a focused composition about food waste',
      'Ignore food after the first sentence',
      'Write unrelated memorised notes',
    ],
    1,
    'A focused treatment of food waste keeps the title central and does not misuse “Food” as a character’s name.',
  ),
  Question(
    'Paper 1',
    'In the June 2024 Section B task, who is the writer?',
    [
      'The Officer-in-Charge',
      'A newspaper reporter',
      'The Junior Member of Parliament for the local area',
      'An unemployed youth',
    ],
    2,
    'The assigned role is the Junior Member of Parliament; this controls the authority, tone and viewpoint of the letter.',
  ),
  Question(
    'Paper 1',
    'Which paragraph most effectively develops a supplied Section B point?',
    [
      'Youth unemployment.',
      'Crime is bad and must stop.',
      'Limited work opportunities leave some young people idle and vulnerable to criminal groups; skills programmes and local apprenticeships could reduce that risk.',
      'There are many things to say about the area.',
    ],
    2,
    'It explains the cause, then proposes a linked and practical response instead of merely copying the prompt.',
  ),
  Question(
    'Paper 2',
    'Passage: “The match was postponed after rain flooded the pitch.” Why was the match postponed?',
    [
      'The pitch had been flooded by rain',
      'The players arrived late',
      'The crowd was too large',
      'The referee lost the ball',
    ],
    0,
    '“Why” asks for the cause. The passage directly states that rain flooded the pitch.',
  ),
  Question(
    'Paper 2',
    'Sentence: “Nyasha found the missing file and immediately gave it to the clerk.” What does “it” refer to?',
    ['Nyasha', 'The missing file', 'The clerk', 'The office'],
    1,
    'Replace “it” with “the missing file”: the resulting sentence is logical and grammatical.',
  ),
  Question(
    'Paper 2',
    'In “The inspector scrutinised the damaged wall,” which replacement best preserves “scrutinised”?',
    ['glanced at', 'examined carefully', 'walked past', 'repaired quickly'],
    1,
    '“Scrutinised” means examined very carefully; “glanced” loses the careful attention.',
  ),
  Question(
    'Paper 2',
    'A writer calls a distant bus “a yellow speck on the road.” What does “speck” emphasise?',
    [
      'The bus was dirty',
      'The bus looked very small because it was far away',
      'The road was yellow',
      'The bus was travelling slowly',
    ],
    1,
    'A speck is a very small visible mark. In context, the word creates a strong sense of distance and scale.',
  ),
  Question(
    'Paper 2',
    'Which is the best own-words version of “The frightened child clung tenaciously to the rail”?',
    [
      'The scared child held the rail very firmly',
      'The child touched the rail',
      'The angry child broke the rail',
      'The child stood near the rail',
    ],
    0,
    '“Frightened” becomes “scared” and “clung tenaciously” becomes “held very firmly”; the full meaning remains.',
  ),
  Question(
    'Paper 2',
    'The summary focus is “actions used to attract rescuers”. Which detail should be excluded?',
    [
      'She waved a bright cloth',
      'She shouted repeatedly',
      'She lit a smoky fire',
      'The mountain looked beautiful at sunset',
    ],
    3,
    'The sunset description is not an action used to attract rescuers, so it does not match the focus.',
  ),
  Question(
    'Paper 2',
    'Which summary sentence is most concise without losing the three actions?',
    [
      'He called and called loudly, and after that he then climbed up onto a rock and waved.',
      'He repeatedly called for help, climbed a rock and waved.',
      'There was calling, and the rock was climbed by him before waving happened.',
      'He was on a rock that was quite tall and it was a difficult situation.',
    ],
    1,
    'It preserves calling, climbing and waving in clear continuous writing without repetition or decoration.',
  ),
  Question(
    'Paper 2',
    'Question: “How did the injured runner cross the finish line?” Which answer is complete?',
    [
      'The runner crossed the finish line',
      'The runner crossed',
      'The injured runner limped slowly across the finish line',
      'At the finish line',
    ],
    2,
    '“How” requires the manner. “Limped slowly” supplies the precise detail the other answers omit.',
  ),
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
      'Emma said “I am ready.”',
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
  Question(
    'Paper 2',
    'The question asks, “How did Tariro stand?” Which answer is complete?',
    [
      'Tariro stood.',
      'Tariro stood perfectly still.',
      'Tariro was there.',
      'Still.',
    ],
    1,
    'The word “how” asks for the manner. “Perfectly still” completes the answer.',
  ),
  Question(
    'Paper 2',
    'Change “angled awkwardly” into simple own words.',
    [
      'bent in a clumsy way',
      'moving quickly',
      'standing proudly',
      'broken completely',
    ],
    0,
    'The 2022 examiner report accepted meanings such as bent/slanted and clumsily/strangely.',
  ),
  Question(
    'Paper 2',
    'Which summary point clearly shows a feeling?',
    [
      'He opened the gate.',
      'He suddenly felt cold with fear.',
      'The trees were tall.',
      'There was a path.',
    ],
    1,
    'It tells us what happened inside the person and keeps the important detail “suddenly”.',
  ),
  Question(
    'Paper 2',
    'Why should you read the whole passage before answering?',
    [
      'To memorise every word',
      'Some answers need information from different parts',
      'To avoid reading questions',
      'To make the paper longer',
    ],
    1,
    'The examiner report warns that some questions require a whole-story understanding.',
  ),
  Question(
    'Paper 1',
    'A task says: “As head prefect, write a speech to new learners advising them about study habits.” Who is the audience?',
    ['The head prefect', 'New learners', 'The examiner only', 'Parents'],
    1,
    'The new learners will hear the speech, so examples and tone must suit them.',
  ),
];

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
            paper == 'Paper 2' ? const Color(0xff5679b6) : coral,
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
    home: const BrandedLaunch(),
  );
}

class BrandedLaunch extends StatefulWidget {
  const BrandedLaunch({super.key});
  @override
  State<BrandedLaunch> createState() => _BrandedLaunchState();
}

class _BrandedLaunchState extends State<BrandedLaunch> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ready) return supabaseReady ? const StudentAuthGate() : const Shell();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff101a48), plum, coral],
          ),
        ),
        child: const SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OloidMark(size: 122),
                SizedBox(height: 24),
                Text(
                  'EmmaPrep English',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 30),
                Text(
                  'POWERED BY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'TAKUNDA VITO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'takunda.vito.co.zw',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudentAuthGate extends StatefulWidget {
  const StudentAuthGate({super.key});
  @override
  State<StudentAuthGate> createState() => _StudentAuthGateState();
}

class _StudentAuthGateState extends State<StudentAuthGate> {
  bool registrationEnabled = false;
  @override
  void initState() {
    super.initState();
    loadPolicy();
  }

  Future<void> loadPolicy() async {
    try {
      final row = await Supabase.instance.client
          .from('app_config')
          .select('value')
          .eq('key', 'registration_enabled')
          .maybeSingle();
      if (mounted) setState(() => registrationEnabled = row?['value'] == true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (_, _) => Supabase.instance.client.auth.currentSession == null
        ? StudentLoginPage(registrationEnabled: registrationEnabled)
        : const Shell(),
  );
}

class StudentLoginPage extends StatefulWidget {
  final bool registrationEnabled;
  const StudentLoginPage({required this.registrationEnabled, super.key});
  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool create = false, busy = false, hidePassword = true;
  String? message;

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.length < 8) {
      setState(
        () => message =
            'Enter a valid email and a password of at least 8 characters.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (create && widget.registrationEnabled) {
        final result = await Supabase.instance.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'display_name': name.text.trim()},
        );
        if (result.session == null) {
          message =
              'Account created. Check your email to confirm it, then sign in.';
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
        unawaited(logStudentEvent('student_signed_in'));
      }
    } on AuthException catch (error) {
      message = error.message;
      debugPrint(
        '[EmmaPrep Student][warning] sign_in_failed ${error.statusCode ?? 'auth_error'}',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    if (!email.text.contains('@')) {
      setState(() => message = 'Enter your email address first.');
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.text.trim(),
      );
      setState(
        () => message = 'Password reset instructions were sent to your email.',
      );
    } on AuthException catch (error) {
      setState(() => message = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const EnglishTutorMark(size: 88),
                    const SizedBox(height: 14),
                    Text(
                      create
                          ? 'Create your EmmaPrep account'
                          : 'Welcome to EmmaPrep',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      create
                          ? 'Your progress and learning space begin here.'
                          : 'Sign in to continue your ZIMSEC English revision.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    if (create) ...[
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 13),
                    ],
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 13),
                    TextField(
                      controller: password,
                      obscureText: hidePassword,
                      onSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => hidePassword = !hidePassword),
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    ),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          message!,
                          style: const TextStyle(
                            color: coral,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 17),
                    FilledButton.icon(
                      onPressed: busy ? null : submit,
                      icon: Icon(
                        create ? Icons.person_add_rounded : Icons.login_rounded,
                      ),
                      label: Text(
                        busy
                            ? 'Please wait…'
                            : create
                            ? 'Create account'
                            : 'Sign in',
                      ),
                    ),
                    if (!create)
                      TextButton(
                        onPressed: resetPassword,
                        child: const Text('Forgot password?'),
                      ),
                    if (widget.registrationEnabled)
                      TextButton(
                        onPressed: () => setState(() {
                          create = !create;
                          message = null;
                        }),
                        child: Text(
                          create
                              ? 'I already have an account'
                              : 'Create a new account',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
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
    if (supabaseReady && Supabase.instance.client.auth.currentUser != null) {
      unawaited(logStudentEvent('student_app_session_started'));
    }
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: store,
    builder: (_, _) {
      final colors = ColorScheme.fromSeed(
        seedColor: plum,
        brightness: store.darkMode ? Brightness.dark : Brightness.light,
        surface: store.darkMode ? const Color(0xff10162a) : cream,
      );
      final theme = ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: colors.surface,
        cardTheme: CardThemeData(
          elevation: store.highContrast ? 2 : 0,
          color: store.darkMode ? const Color(0xff19213a) : Colors.white,
          shape: RoundedRectangleBorder(
            side: store.highContrast
                ? BorderSide(color: colors.onSurface, width: 1.4)
                : BorderSide.none,
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      );
      final media = MediaQuery.of(c).copyWith(
        textScaler: TextScaler.linear(store.textScale),
        disableAnimations: store.reducedMotion,
      );
      return Theme(
        data: theme,
        child: MediaQuery(
          data: media,
          child: Scaffold(
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
                  icon: OloidMark(size: 27),
                  selectedIcon: OloidMark(size: 30),
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
        ),
      );
    },
  );
}

class Pad extends StatelessWidget {
  final Widget child;
  const Pad(this.child, {super.key});
  @override
  Widget build(BuildContext c) =>
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8), child: child);
}

class OloidMark extends StatelessWidget {
  final double size;
  const OloidMark({this.size = 38, super.key});

  @override
  Widget build(BuildContext c) => SizedBox(
    width: size,
    height: size,
    child: ClipOval(
      child: Container(
        color: Colors.black,
        child: OverflowBox(
          minWidth: size * 2.6,
          maxWidth: size * 2.6,
          minHeight: size * 2.6,
          maxHeight: size * 2.6,
          child: Transform.translate(
            offset: Offset(0, size * .12),
            child: Image.asset(
              'assets/branding/takunda_vito_logo.png',
              fit: BoxFit.contain,
              semanticLabel: 'Takunda Vito oloid symbol',
            ),
          ),
        ),
      ),
    ),
  );
}

class EnglishTutorMark extends StatelessWidget {
  final double size;
  const EnglishTutorMark({this.size = 58, super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Image.asset(
      'assets/branding/english_tutor_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    ),
  );
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
          SizedBox(
            height: 86,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      learnerDisplayName(),
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const OloidMark(size: 34),
                  ],
                ),
                Positioned(
                  left: 0,
                  child: Tooltip(
                    message: 'Signed in as ${signedInStudentName()}',
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: coral,
                      foregroundColor: Colors.white,
                      child: Text(
                        signedInStudentInitial(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: IconButton.filledTonal(
                    tooltip: 'Accessibility and appearance',
                    onPressed: () => Navigator.push(
                      c,
                      MaterialPageRoute(builder: (_) => AccessibilityPage(s)),
                    ),
                    icon: const Icon(Icons.settings_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (companyEvaluationMode) ...[
            EvaluationBanner(s),
            const SizedBox(height: 14),
          ],
          if (s.maintenanceNotice.isNotEmpty) ...[
            RemoteNoticeCard(
              title: 'Service notice',
              message: s.maintenanceNotice,
              icon: Icons.info_rounded,
            ),
            const SizedBox(height: 12),
          ],
          ...s.announcements.map(
            (notice) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RemoteNoticeCard(
                title: notice['title']?.toString() ?? 'EmmaPrep update',
                message: notice['message']?.toString() ?? '',
                icon: Icons.campaign_rounded,
              ),
            ),
          ),
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
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: coral,
                foregroundColor: Colors.white,
                child: Icon(Icons.flash_on_rounded),
              ),
              title: const Text(
                '48-hour Paper 1 route',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'Start with exact exam questions, timed plans and high-value writing decisions.',
              ),
              trailing: const Icon(Icons.arrow_forward_rounded),
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => CrashCoursePage(s)),
              ),
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
                  Expanded(
                    child: Text(
                      'Exam tip\nRead every command word twice. It tells you what the examiner rewards.',
                      style: const TextStyle(height: 1.4),
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

class EvaluationBanner extends StatelessWidget {
  final Store store;
  const EvaluationBanner(this.store, {super.key});

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xfffff0c7),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: const CircleAvatar(
        backgroundColor: Color(0xffffc56e),
        foregroundColor: ink,
        child: Icon(Icons.business_center_rounded),
      ),
      title: const Text(
        'COMPANY EVALUATION BUILD',
        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .6),
      ),
      subtitle: Text(
        'Prepared for $evaluatorName. Uses demonstration data and does not require a student account.',
      ),
      trailing: const Icon(Icons.arrow_forward_rounded),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EvaluationGuidePage(store)),
      ),
    ),
  );
}

class EvaluationGuidePage extends StatelessWidget {
  final Store store;
  const EvaluationGuidePage(this.store, {super.key});

  static const checks = <(IconData, String, String)>[
    (
      Icons.menu_book_rounded,
      'Review the curriculum',
      'Open lessons in Paper 1 and Paper 2 and inspect the examples and learner checklists.',
    ),
    (
      Icons.quiz_rounded,
      'Complete a quiz',
      'Answer a mixture of questions and review the score and explanations.',
    ),
    (
      Icons.offline_bolt_rounded,
      'Test offline use',
      'Turn off connectivity and confirm that bundled lessons and quizzes remain available.',
    ),
    (
      Icons.accessibility_new_rounded,
      'Check accessibility',
      'Try large text, high contrast, dark mode and reduced motion.',
    ),
    (
      Icons.insights_rounded,
      'Inspect progress tracking',
      'Complete and bookmark lessons, then reopen the app to confirm local persistence.',
    ),
  ];

  Future<void> _openFeedback() async {
    if (evaluationFeedbackUrl.isEmpty) return;
    await launchUrl(
      Uri.parse(evaluationFeedbackUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Company evaluation')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Welcome, $evaluatorName',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'This evaluation build is designed for product review. It contains demonstration content, stores progress only on this device, and must not be used with real student information.',
          style: TextStyle(height: 1.45),
        ),
        const SizedBox(height: 20),
        ...checks.map(
          (check) => Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: CircleAvatar(child: Icon(check.$1)),
              title: Text(
                check.$2,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(check.$3),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start evaluating'),
        ),
        if (evaluationFeedbackUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openFeedback,
            icon: const Icon(Icons.rate_review_rounded),
            label: const Text('Send evaluation feedback'),
          ),
        ],
      ],
    ),
  );
}

class AccessibilityPage extends StatelessWidget {
  final Store s;
  const AccessibilityPage(this.s, {super.key});

  Future<void> openDeveloperSite() async {
    await launchUrl(
      Uri.parse('https://takunda.vito.co.zw'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Accessibility & appearance')),
    body: ListenableBuilder(
      listenable: s,
      builder: (_, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          if (supabaseReady &&
              Supabase.instance.client.auth.currentUser != null) ...[
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: plum,
                  foregroundColor: Colors.white,
                  child: Text(
                    signedInStudentInitial(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                title: Text(signedInStudentName()),
                subtitle: Text(
                  Supabase.instance.client.auth.currentUser!.email ??
                      'EmmaPrep account',
                ),
                trailing: TextButton.icon(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (c.mounted) Navigator.pop(c);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [plum, coral]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.accessibility_new_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Make EmmaPrep comfortable for your eyes and easier to understand.',
                    style: TextStyle(
                      color: Colors.white,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_rounded),
            title: const Text('Dark theme'),
            subtitle: const Text('Use darker colours in low light.'),
            value: s.darkMode,
            onChanged: (v) => s.updateAccessibility(dark: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.contrast_rounded),
            title: const Text('High contrast'),
            subtitle: const Text(
              'Add stronger borders and clearer separation.',
            ),
            value: s.highContrast,
            onChanged: (v) => s.updateAccessibility(contrast: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.motion_photos_off_rounded),
            title: const Text('Reduce motion'),
            subtitle: const Text('Limit animations and movement.'),
            value: s.reducedMotion,
            onChanged: (v) => s.updateAccessibility(motion: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lightbulb_outline_rounded),
            title: const Text('Simple explanations'),
            subtitle: const Text(
              'Show extra beginner-friendly reminders in lessons.',
            ),
            value: s.simpleLanguage,
            onChanged: (v) => s.updateAccessibility(simple: v),
          ),
          const Divider(height: 28),
          const ListTile(
            leading: Icon(Icons.text_fields_rounded),
            title: Text('Text size'),
            subtitle: Text('Move the slider until reading feels comfortable.'),
          ),
          Slider(
            value: s.textScale,
            min: .9,
            max: 1.4,
            divisions: 5,
            label: '${(s.textScale * 100).round()}%',
            onChanged: (v) => s.updateAccessibility(scale: v),
          ),
          Center(
            child: Text(
              'This is how your reading text will look.',
              style: TextStyle(fontSize: 16 * s.textScale),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      OloidMark(size: 36),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About EmmaPrep English',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text('Version 1.10.0 (build 15)'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.person_rounded),
                    title: Text('Developer'),
                    subtitle: Text('Takunda Vito'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language_rounded),
                    title: const Text('Developer website'),
                    subtitle: const Text('takunda.vito.co.zw'),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                    onTap: openDeveloperSite,
                  ),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.school_rounded),
                    title: Text('Learning focus'),
                    subtitle: Text(
                      'ZIMSEC English Language 4005 Paper 1 and Paper 2 revision',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'EmmaPrep English is an independent revision aid and is not an official ZIMSEC product.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save settings'),
            onPressed: () async {
              await s.save();
              if (!c.mounted) return;
              ScaffoldMessenger.of(
                c,
              ).showSnackBar(const SnackBar(content: Text('Settings saved.')));
            },
          ),
        ],
      ),
    ),
  );
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
      // Leave enough vertical room for two-line subtitles on narrow phones.
      // A shorter fixed height caused the card's Column to overflow at 360 px.
      height: 228,
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
                    style: TextStyle(
                      color: Theme.of(c).colorScheme.onSurfaceVariant,
                    ),
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

class CrashCoursePage extends StatelessWidget {
  final Store store;
  const CrashCoursePage(this.store, {super.key});

  static const lessonIds = [
    'p1-exam-map-2024',
    'p1-description-2024',
    'p1-statement-story-2024',
    'p1-argument-2024',
    'p1-open-title-2024',
    'p1-guided-letter-2024',
  ];

  @override
  Widget build(BuildContext context) {
    final route = lessonIds
        .map((id) => lessons.firstWhere((lesson) => lesson.id == id))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('48-hour Paper 1 route')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [plum, coral]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Text(
              'Day 1: learn the exam map, choose one Section A style and complete its timed plan.\n\nDay 2: master the compulsory Section B letter, write one full Section A answer and edit both against the checklists.',
              style: TextStyle(
                color: Colors.white,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Work in this order',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...route.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: entry.value.color,
                    foregroundColor: Colors.white,
                    child: Text('${entry.key + 1}'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: LessonTile(entry.value, store)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Rapid revision improves question choice, planning and accuracy, but marks still depend on completing timed writing and correcting mistakes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
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
        if (modelAnswerFor(l) case final String answer) ...[
          const SizedBox(height: 16),
          ModelAnswerCard(answer),
        ],
        if (s.simpleLanguage) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  plum.withValues(alpha: .12),
                  coral.withValues(alpha: .12),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: coral.withValues(alpha: .35)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.child_care_rounded, color: coral),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Easy way: read one point, say it aloud in your own simple words, then make your own example before moving on.',
                    style: TextStyle(height: 1.45, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        PracticalExampleCard(l),
        const SizedBox(height: 22),
        Text(
          'CORE NOTES',
          style: TextStyle(
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
            color: Theme.of(c).colorScheme.onSurfaceVariant,
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

class ModelAnswerCard extends StatelessWidget {
  final String answer;
  const ModelAnswerCard(this.answer, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xffe8f7ef),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xff4c9270), width: 1.4),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xff32765a),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: Colors.white),
              SizedBox(width: 9),
              Text(
                'MODEL ANSWER',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .9,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(17),
          child: SelectableText(
            answer,
            style: const TextStyle(color: ink, height: 1.55, fontSize: 15.5),
          ),
        ),
      ],
    ),
  );
}

class PracticalExampleCard extends StatelessWidget {
  final Lesson lesson;
  const PracticalExampleCard(this.lesson, {super.key});

  @override
  Widget build(BuildContext c) {
    final example = practicalExample(lesson);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(c).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lesson.color.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [plum, coral]),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.visibility_rounded, color: Colors.white),
                SizedBox(width: 9),
                Text(
                  'EXAM QUESTION & APPROACH',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(example.worked, style: const TextStyle(height: 1.5)),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: coral.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.edit_rounded, color: coral),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'YOUR TURN\n${example.task}',
                    style: const TextStyle(
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Practice extends StatelessWidget {
  final Store s;
  const Practice(this.s, {super.key});
  @override
  Widget build(BuildContext c) => Pad(
    ListView(
      children: [
        const Text(
          'ZIMSEC 4005 practice',
          style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
        ),
        const Text('Only Paper 1 and Paper 2 exam-skill questions.'),
        const SizedBox(height: 22),
        if (s.remoteScannerEnabled)
          Drill(
            'Scan questions',
            'Photograph one or several questions, get explanations, then add them to Study and Practice.',
            Icons.document_scanner_rounded,
            plum,
            () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => QuestionScannerPage(s)),
            ),
          ),
        Drill(
          'Mixed exam check',
          'Five ZIMSEC 4005 skill questions.',
          Icons.bolt,
          coral,
          () => go(c, null, 5),
        ),
        Drill(
          'Paper 1 exam skills',
          'Composition, guided writing and register.',
          Icons.edit_note,
          const Color(0xffde965d),
          () => go(c, 'Paper 1', null),
        ),
        Drill(
          'Paper 2 exam skills',
          'Comprehension, summary and language structures.',
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

class QuestionScannerPage extends StatefulWidget {
  final Store store;
  const QuestionScannerPage(this.store, {super.key});
  @override
  State<QuestionScannerPage> createState() => _QuestionScannerPageState();
}

class _QuestionScannerPageState extends State<QuestionScannerPage> {
  final picker = ImagePicker();
  final images = <XFile>[];
  List<Map<String, dynamic>> results = [];
  bool busy = false, pickerBusy = false;
  String? error;

  Future<void> addCamera() async {
    if (pickerBusy) return;
    setState(() => pickerBusy = true);
    try {
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 72,
        maxWidth: 1600,
      );
      if (image != null && mounted) {
        final stable = XFile.fromData(
          await image.readAsBytes(),
          name: 'camera-${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: 'image/jpeg',
        );
        setState(() {
          if (images.length < 3) images.add(stable);
        });
      }
    } catch (caught) {
      debugPrint(
        '[EmmaPrep Student][error] scanner_camera_failed ${caught.runtimeType}',
      );
    } finally {
      if (mounted) setState(() => pickerBusy = false);
    }
  }

  Future<void> addGallery() async {
    if (pickerBusy) return;
    setState(() => pickerBusy = true);
    try {
      final picked = await picker.pickMultiImage(
        imageQuality: 72,
        maxWidth: 1600,
        limit: 3,
      );
      final stable = <XFile>[];
      for (final image in picked.take(3)) {
        stable.add(
          XFile.fromData(
            await image.readAsBytes(),
            name: image.name,
            mimeType: image.mimeType ?? 'image/jpeg',
          ),
        );
      }
      if (mounted) {
        setState(() {
          images
            ..clear()
            ..addAll(stable);
        });
      }
    } catch (caught) {
      debugPrint(
        '[EmmaPrep Student][error] scanner_gallery_failed ${caught.runtimeType}',
      );
    } finally {
      if (mounted) setState(() => pickerBusy = false);
    }
  }

  Future<void> scan() async {
    if (images.isEmpty) {
      setState(() => error = 'Capture or select at least one clear picture.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      results = [];
    });
    try {
      final found = await widget.store.scanQuestions(images);
      if (mounted) {
        setState(() {
          results = found;
          if (found.isEmpty) {
            error = 'No clear ZIMSEC English questions were found.';
          }
        });
      }
    } catch (caught) {
      debugPrint(
        '[EmmaPrep Student][error] question_scan_request_failed ${caught.runtimeType}',
      );
      if (mounted) {
        setState(
          () => error = caught is FormatException
              ? caught.message.toString()
              : 'Could not scan the pictures. Check the connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save() async {
    await widget.store.saveScannedQuestions(results);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to Study and Practice.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan revision questions')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [plum, coral]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Text(
            'Take clear, straight pictures with all question numbers and answer choices visible. You may use up to three pictures in one scan.',
            style: TextStyle(
              color: Colors.white,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy || pickerBusy ? null : addCamera,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy || pickerBusy ? null : addGallery,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.collections_rounded, color: plum),
              title: Text(
                '${images.length} picture${images.length == 1 ? '' : 's'} ready',
              ),
              subtitle: const Text(
                'Images are sent for analysis but are not saved in your study history.',
              ),
              trailing: IconButton(
                onPressed: busy ? null : () => setState(images.clear),
                icon: const Icon(Icons.clear_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : scan,
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(
              busy ? 'Reading questions…' : 'Read and answer questions',
            ),
          ),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              error!,
              style: const TextStyle(color: coral, fontWeight: FontWeight.w700),
            ),
          ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            '${results.length} question${results.length == 1 ? '' : 's'} found',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...results.asMap().entries.map((entry) {
            final item = entry.value;
            final answers = List<String>.from(item['answers']);
            final correct = (item['correctIndex'] as num).toInt();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['paper']} · Question ${entry.key + 1}',
                      style: const TextStyle(
                        color: plum,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if ((item['passage']?.toString().isNotEmpty ?? false)) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: plum.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item['passage'].toString(),
                          style: const TextStyle(height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      item['question'].toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Answer: ${answers[correct]}',
                      style: const TextStyle(
                        color: Color(0xff32765a),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['explanation'].toString(),
                      style: const TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Study note: ${item['studyNote']}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.library_add_check_rounded),
            label: const Text('Add all to Study and Practice'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Always compare the captured wording with the original picture. Image recognition and AI answers can make mistakes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ],
    ),
  );
}

class RemoteNoticeCard extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const RemoteNoticeCard({
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: coral.withValues(alpha: .12),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: coral,
        foregroundColor: Colors.white,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(message, style: const TextStyle(height: 1.4)),
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
                    Text(
                      sub,
                      style: TextStyle(
                        color: Theme.of(c).colorScheme.onSurfaceVariant,
                      ),
                    ),
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
            Color fill = Theme.of(c).colorScheme.surfaceContainerHighest,
                border = Theme.of(c).colorScheme.outlineVariant;
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
                p >= 70
                    ? 'Excellent work, ${learnerDisplayName()}!'
                    : 'Keep building, ${learnerDisplayName()}.',
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
  final picker = ImagePicker();
  final attachments = <XFile>[];
  late final messages = <ChatMessage>[
    ChatMessage(
      false,
      'Hi ${learnerDisplayName()}! I’m your English study coach. Ask me to explain a skill, mark a short answer, create a practice question, or help you plan a composition.',
    ),
  ];
  bool sending = false, pickerBusy = false;

  Future<void> addCoachPictures({required bool camera}) async {
    if (pickerBusy) return;
    setState(() => pickerBusy = true);
    try {
      final selected = camera
          ? <XFile>[
              if (await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 72,
                    maxWidth: 1600,
                  )
                  case final XFile image)
                image,
            ]
          : await picker.pickMultiImage(
              imageQuality: 72,
              maxWidth: 1600,
              limit: 3,
            );
      final stable = <XFile>[];
      for (final image in selected.take(3)) {
        stable.add(
          XFile.fromData(
            await image.readAsBytes(),
            name: image.name,
            mimeType: image.mimeType ?? 'image/jpeg',
          ),
        );
      }
      if (mounted) {
        setState(() {
          if (camera) {
            attachments.addAll(stable.take(3 - attachments.length));
          } else {
            attachments
              ..clear()
              ..addAll(stable);
          }
        });
      }
    } catch (caught) {
      debugPrint(
        '[EmmaPrep Student][error] coach_picker_failed ${caught.runtimeType}',
      );
    } finally {
      if (mounted) setState(() => pickerBusy = false);
    }
  }

  Future<void> addCoachPdf() async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      final bytes = selection?.files.single.bytes;
      if (bytes == null) return;
      final document = await PdfDocument.openData(bytes);
      final pages = <XFile>[];
      try {
        for (var number = 1; number <= min(3, document.pagesCount); number++) {
          final page = await document.getPage(number);
          try {
            final width = min(1600.0, page.width * 2);
            final rendered = await page.render(
              width: width,
              height: width * page.height / page.width,
              format: PdfPageImageFormat.jpeg,
              backgroundColor: '#FFFFFF',
              quality: 76,
            );
            if (rendered != null) {
              pages.add(
                XFile.fromData(
                  rendered.bytes,
                  name: 'pdf-page-$number.jpg',
                  mimeType: 'image/jpeg',
                ),
              );
            }
          } finally {
            await page.close();
          }
        }
      } finally {
        await document.close();
      }
      if (mounted) {
        setState(() {
          attachments
            ..clear()
            ..addAll(pages);
        });
      }
    } catch (caught) {
      debugPrint(
        '[EmmaPrep Student][error] coach_pdf_failed ${caught.runtimeType}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read that PDF. Try clear page pictures.'),
          ),
        );
      }
    }
  }

  Future<void> send([String? prompt]) async {
    final typed = (prompt ?? input.text).trim();
    final text = typed.isEmpty && attachments.isNotEmpty
        ? 'Read these pages, explain the passage and answer every visible ZIMSEC English question.'
        : typed;
    if (text.isEmpty || sending) return;
    if (widget.s.apiBaseUrl.isEmpty) {
      setState(
        () => messages.add(
          const ChatMessage(
            false,
            'The online coach is not configured in this build. Learning notes and practice remain available offline.',
          ),
        ),
      );
      return;
    }
    setState(() {
      messages.add(ChatMessage(true, text));
      sending = true;
      input.clear();
    });
    try {
      final encodedAttachments = <String>[];
      for (final attachment in attachments) {
        encodedAttachments.add(await encodeImageForApi(attachment));
      }
      final response = await http
          .post(
            Uri.parse('${widget.s.apiBaseUrl}/v1/chat'),
            headers: widget.s.apiHeaders,
            body: jsonEncode({
              'message': text,
              'student': learnerDisplayName(),
              'course': 'ZIMSEC English Language 4005/01 and 4005/02',
              'mode': 'learning_and_practice',
              'locale': 'Zimbabwe',
              'teaching_style':
                  'Use simple English, Zimbabwean everyday examples, one worked example, then one short practice task.',
              'images': encodedAttachments,
              'history': messages
                  .skip(max(0, messages.length - 12))
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
        final failure = jsonDecode(response.body) as Map<String, dynamic>;
        throw FormatException(
          '${failure['error'] ?? 'Tutor request failed'}${failure['requestId'] == null ? '' : ' (request ${failure['requestId']})'}',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply =
          data['reply']?.toString() ??
          data['message']?.toString() ??
          'The coach returned an empty response.';
      if (mounted) {
        setState(() {
          messages.add(ChatMessage(false, coachDisplayText(reply)));
          attachments.clear();
        });
      }
    } on TimeoutException {
      debugPrint('[EmmaPrep Student][error] coach_request_timeout');
      if (mounted) {
        setState(
          () => messages.add(
            const ChatMessage(
              false,
              'The tutor took too long to respond. Try once more. If this continues, ask the administrator to check the chat function and AI provider secret.',
            ),
          ),
        );
      }
    } catch (caught) {
      debugPrint(
        '[EmmaPrep Student][error] coach_request_failed ${caught.runtimeType}',
      );
      if (mounted) {
        setState(
          () => messages.add(
            ChatMessage(
              false,
              caught is FormatException
                  ? caught.message.toString()
                  : 'I could not reach the study service. Check your internet connection and try again. Your lessons and practice still work offline.',
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
            const EnglishTutorMark(size: 48),
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
        if (attachments.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: const Icon(Icons.attach_file_rounded, size: 18),
              label: Text(
                '${attachments.length} page${attachments.length == 1 ? '' : 's'} attached',
              ),
              onDeleted: sending ? null : () => setState(attachments.clear),
            ),
          ),
          const SizedBox(height: 8),
        ],
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
                    color: m.user
                        ? plum
                        : Theme.of(c).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SelectableText(
                    m.user ? m.text : coachDisplayText(m.text),
                    style: TextStyle(
                      color: m.user
                          ? Colors.white
                          : Theme.of(c).colorScheme.onSurface,
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
            PopupMenuButton<String>(
              enabled: !sending && !pickerBusy,
              tooltip: 'Attach pages',
              icon: const Icon(Icons.add_circle_outline_rounded),
              onSelected: (value) {
                if (value == 'camera') {
                  addCoachPictures(camera: true);
                } else if (value == 'gallery') {
                  addCoachPictures(camera: false);
                } else {
                  addCoachPdf();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'camera', child: Text('Take a picture')),
                PopupMenuItem(value: 'gallery', child: Text('Choose pictures')),
                PopupMenuItem(value: 'pdf', child: Text('Choose a PDF')),
              ],
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: input,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Ask your study coach…',
                  filled: true,
                  fillColor: Theme.of(c).colorScheme.surfaceContainerHighest,
                  border: const OutlineInputBorder(
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
                    style: TextStyle(
                      color: Theme.of(c).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Chip(
              avatar: s.syncing
                  ? const SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_done_rounded, size: 18),
              label: Text(s.syncing ? 'Updating' : 'Automatic'),
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
