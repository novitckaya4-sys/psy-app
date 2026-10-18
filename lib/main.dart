import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration_fixed/vibration_fixed.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:gal/gal.dart';
import 'package:flutter_painter/flutter_painter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class AppColors {
  static const Color primary = Color(0xFF5B21B6);
  static const Color primaryDark = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFFEDE9FE);
  static const Color background = Color(0xFFF3E5FF);
  static const Color text = Color(0xFF3B0764);
  static const Color textLight = Color(0xFF6B7280);
  static const Color danger = Color(0xFFEF4444);
  static const Color mint = Color(0xFFB7E4C7);
  static const Color pastelYellow = Color(0xFFFEF9C3);
  static const Color pastelGreen = Color(0xFFD1FAE5);
  static const Color pastelPink = Color(0xFFFBCFE8);
  static const Color pastelMint = Color(0xFFE0F2E9);
  static const Color pastelBlue = Color(0xFFDBEAFE);
  static const Color pastelPeach = Color(0xFFFED7AA);
  static const Color purpleLight = Color(0xFFC084FC);
  static const Color purpleMedium = Color(0xFFA855F7);
  static const Color purpleDeep = Color(0xFF9333EA);
}

class DiaryEntry {
  String type, text, emoji;
  DateTime date;
  DiaryEntry({this.type = "Идея", this.text = "", this.emoji = "💡", DateTime? date})
      : date = date ?? DateTime.now();
}

class MoodEntry {
  String mood;
  DateTime date;
  MoodEntry({this.mood = "", DateTime? date}) : date = date ?? DateTime.now();
}

class ChatMessage {
  String role, content;
  ChatMessage({required this.role, required this.content});
}

class TestResult {
  String testName, result, interpretation;
  DateTime date;
  TestResult({
    required this.testName,
    required this.result,
    required this.interpretation,
    DateTime? date,
  }) : date = date ?? DateTime.now();
}

class AppState {
  static String userName = "", avatar = "🌸", age = "", apiKey = "";
  static List<DiaryEntry> entries = [];
  static List<MoodEntry> moods = [];
  static List<TestResult> testResults = [];
  static String petName = "Мурзик";
  static int catLevel = 1, catXp = 0, catHunger = 50;
  static bool vibrationEnabled = true, soundEnabled = true;
  static List<String> completedLessons = [];
  static List<Map<String, dynamic>> savedDrawings = [];
  static Map<String, List<String>> lessonAnswers = {};

  static void addXp(int amount) {
    catXp += amount;
    if (catXp >= 100) {
      catLevel++;
      catXp = 0;
    }
  }

  static void feedCat() {
    if (catHunger < 100) catHunger += 25;
  }

  static void addEntry(DiaryEntry e) => entries.insert(0, e);
  static void addMood(MoodEntry m) => moods.insert(0, m);
  static void addTestResult(TestResult r) => testResults.insert(0, r);

  static void completeLesson(String lessonTitle, List<String> answers) {
    if (!completedLessons.contains(lessonTitle)) {
      completedLessons.add(lessonTitle);
    }
    lessonAnswers[lessonTitle] = answers;
  }

  static void addDrawing(String lessonTitle, Uint8List imageBytes) {
    savedDrawings.insert(0, {
      'lesson': lessonTitle,
      'image': imageBytes,
      'date': DateTime.now().toIso8601String(),
    });
  }

  static void clear() {
    userName = "";
    avatar = "🌸";
    age = "";
    apiKey = "";
    entries.clear();
    moods.clear();
    testResults.clear();
    petName = "Мурзик";
    catLevel = 1;
    catXp = 0;
    catHunger = 50;
    vibrationEnabled = true;
    soundEnabled = true;
    completedLessons.clear();
    savedDrawings.clear();
    lessonAnswers.clear();
  }
}

const List<String> greetingTips = [
  "Ты справляешься лучше, чем тебе кажется. 💜",
  "Твои чувства — настоящие. Ты имеешь право их испытывать. 🌸",
  "Один шаг — уже движение. Не требуй от себя всего сразу. ✨",
  "Ты не обязан(а) быть сильным(ой) всё время. Отдых — это тоже забота. 🌿",
  "Дыши. Всё, что ты сейчас чувствуешь, — пройдёт. 🌊",
];

const Map<String, String> moodSupport = {
  "Злость": "Злость указывает на нарушение границ. Попробуй выразить это через «Я-сообщение».",
  "Грусть": "Грусть — способ психики переварить потерю. Позволь себе побыть в ней.",
  "Тревога": "Тревога — это энергия. Попробуй сделать 20 приседаний или выпить воды.",
  "Апатия": "Это режим энергосбережения. Начни с малого — просто умойся прохладной водой.",
  "Нейтрально": "Спокойное состояние — отличная база. Сделай сегодня что-то для себя.",
  "Радость": "Зафиксируй этот момент. Что именно сделало тебя счастливым(ой)?",
  "Счастье": "Прекрасно! Поделись своей радостью с кем-то близким.",
};

class AiService {
  final String apiKey;
  final String systemPrompt;
  
  // Прямой адрес Groq (работает с включенным VPN)
  static const String baseUrl = 'https://api.groq.com/openai/v1';
  static const String model = 'openai/gpt-oss-120b';

  AiService({required this.apiKey, String? prompt})
      : systemPrompt = prompt ?? defaultPrompt;

  static const String defaultPrompt = '''
Ты — «Карманный психолог», тёплый собеседник для подростков из Беларуси.

ПРАВИЛА:
1. Говори по-русски, простым языком, как друг-сверстник. Но с заботой.
2. НИКОГДА не осуждай.
3. Сначала ОТРАЖАЙ чувства, потом задавай ОДИН открытый вопрос.
4. Не давай медицинских советов, не ставь диагнозы.
5. При суициде/самоповреждении — мягко предложи позвонить 8 801 100 16 11.
6. Отвечай коротко: 2–4 предложения.
7. Используй 1–2 эмодзи.
''';

  Future<String> chat(List<ChatMessage> history) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history.map((m) => {'role': m.role, 'content': m.content}),
    ];

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'temperature': 0.75,
              'max_tokens': 400,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        return '⚠ Неверный API-ключ. Проверь его в Groq.';
      }
      if (response.statusCode == 429) {
        return '⚠ Слишком много запросов. Подожди минуту.';
      }
      if (response.statusCode != 200) {
        return '⚠ Ошибка API: ${response.statusCode}. Попробуй ещё раз.';
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'] as String;
      
    } catch (e) {
      return '⚠ Не получилось связаться с ИИ.\n\nПроверь:\n1. Включен ли VPN?\n2. Ключ Groq введён (начинается с gsk_)?\n3. Есть ли интернет?';
    }
  }
}

void main() => runApp(const PsyApp());

class PsyApp extends StatelessWidget {
  const PsyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Карманный психолог',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: Colors.white,
        ),
      ),
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  bool? _registered;
  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('userName') ?? '';
    if (savedName.isNotEmpty) {
      AppState.userName = savedName;
      AppState.age = prefs.getString('age') ?? '';
      AppState.avatar = prefs.getString('avatar') ?? '🌸';
      AppState.apiKey = prefs.getString('apiKey') ?? '';
      AppState.petName = prefs.getString('petName') ?? 'Мурзик';
      AppState.catLevel = prefs.getInt('catLevel') ?? 1;
      AppState.catXp = prefs.getInt('catXp') ?? 0;
      AppState.catHunger = prefs.getInt('catHunger') ?? 50;
      AppState.vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      AppState.soundEnabled = prefs.getBool('soundEnabled') ?? true;
      AppState.completedLessons = prefs.getStringList('completedLessons') ?? [];
      setState(() => _registered = true);
    } else {
      setState(() => _registered = false);
    }
  }

  Future<void> _saveUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', AppState.userName);
    await prefs.setString('age', AppState.age);
    await prefs.setString('avatar', AppState.avatar);
    await prefs.setString('apiKey', AppState.apiKey);
    await prefs.setString('petName', AppState.petName);
    await prefs.setInt('catLevel', AppState.catLevel);
    await prefs.setInt('catXp', AppState.catXp);
    await prefs.setInt('catHunger', AppState.catHunger);
    await prefs.setBool('vibrationEnabled', AppState.vibrationEnabled);
    await prefs.setBool('soundEnabled', AppState.soundEnabled);
    await prefs.setStringList('completedLessons', AppState.completedLessons);
  }

  @override
  Widget build(BuildContext context) {
    if (_registered == null) {
      return const Scaffold(body: Center(child: Text("🌸", style: TextStyle(fontSize: 80))));
    }
    if (_registered == false) {
      return RegistrationScreen(onDone: () async {
        await _saveUser();
        setState(() => _registered = true);
      });
    }
    return const MainWindow();
  }
}

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onDone;
  const RegistrationScreen({super.key, required this.onDone});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _keyController = TextEditingController();
  final _petNameController = TextEditingController(text: "Мурзик");
  String _selectedAvatar = "";
  final List<Map<String, dynamic>> _row1 = [
    {"emoji": "🌸", "color": const Color(0xFFFBCFE8)},
    {"emoji": "🌿", "color": const Color(0xFFD1FAE5)},
    {"emoji": "⭐", "color": const Color(0xFFFEF9C3)},
    {"emoji": "🌙", "color": const Color(0xFFDBEAFE)}
  ];
  final List<Map<String, dynamic>> _row2 = [
    {"emoji": "🔥", "color": const Color(0xFFFECACA)},
    {"emoji": "💧", "color": const Color(0xFFBFDBFE)},
    {"emoji": "🌺", "color": const Color(0xFFFBCFE8)}
  ];
  bool get _active =>
      _nameController.text.trim().isNotEmpty && _selectedAvatar.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Text("🌸", style: TextStyle(fontSize: 70))),
              const SizedBox(height: 10),
              const Center(
                child: Text("Карманный психолог",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text)),
              ),
              const Center(
                child: Text("Твоё личное пространство",
                    style: TextStyle(fontSize: 14, color: AppColors.primaryDark)),
              ),
              const SizedBox(height: 30),
              _label("Как тебя зовут?"),
              _input(_nameController, onChanged: (_) => setState(() {})),
              const SizedBox(height: 20),
              _label("Сколько тебе лет?"),
              _input(_ageController, keyboard: TextInputType.number),
              const SizedBox(height: 20),
              _label("Имя питомца"),
              _input(_petNameController),
              const SizedBox(height: 20),
              _label("Выбери аватарку"),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(15),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: _row1.map(_avatarBtn).toList()),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: _row2.map(_avatarBtn).toList()),
                ]),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _selectedAvatar.isEmpty ? "Не выбрана" : "Выбрано: $_selectedAvatar",
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: _selectedAvatar.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _label("Ключ Groq (для ИИ)"),
              _input(_keyController),
              const Text("Без ключа ИИ работать не будет.",
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primaryDark)),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mint,
                  disabledBackgroundColor: AppColors.mint.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  minimumSize: const Size.fromHeight(55),
                  elevation: 0,
                ),
                onPressed: _active
                    ? () {
                        AppState.userName = _nameController.text.trim();
                        AppState.age = _ageController.text.trim();
                        AppState.apiKey = _keyController.text.trim();
                        AppState.avatar = _selectedAvatar;
                        AppState.petName = _petNameController.text.trim().isEmpty
                            ? "Мурзик"
                            : _petNameController.text.trim();
                        widget.onDone();
                      }
                    : null,
                child: const Text("Начать",
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
      );

  Widget _input(TextEditingController c,
      {TextInputType? keyboard, Function(String)? onChanged}) =>
      Container(
        decoration:
            BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          onChanged: onChanged,
          decoration: const InputDecoration(border: InputBorder.none),
          style: const TextStyle(fontSize: 16, color: AppColors.text),
        ),
      );

  Widget _avatarBtn(Map<String, dynamic> item) => Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap: () => setState(() => _selectedAvatar = item["emoji"]),
          child: Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: item["color"],
              shape: BoxShape.circle,
              border: _selectedAvatar == item["emoji"]
                  ? Border.all(color: AppColors.primaryDark, width: 2)
                  : null,
            ),
            child: Center(
                child: Text(item["emoji"], style: const TextStyle(fontSize: 26))),
          ),
        ),
      );
}

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});
  static MainWindowState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainWindowState>();
  @override
  State<MainWindow> createState() => MainWindowState();
}

class MainWindowState extends State<MainWindow> {
  int _currentTab = 3;
  Widget? _customScreen;
  void setCustomScreen(Widget? screen) => setState(() => _customScreen = screen);

  void _handleBack() {
    if (_customScreen != null) {
      setState(() => _customScreen = null);
    } else if (_currentTab != 3) {
      setState(() => _currentTab = 3);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_customScreen != null) {
      body = _customScreen!;
    } else {
      switch (_currentTab) {
        case 0:
          body = const SosScreen();
          break;
        case 1:
          body = const BreathingScreen();
          break;
        case 2:
          body = const MeditationScreen();
          break;
        case 3:
          body = const HomeScreen();
          break;
        case 4:
          body = const DiaryScreen();
          break;
        case 5:
          body = const PetScreen();
          break;
        case 6:
          body = const ProfileScreen();
          break;
        default:
          body = const HomeScreen();
      }
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: SafeArea(bottom: false, child: body),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(color: AppColors.primary),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _nav(Icons.warning_amber_rounded, 0),
                  _nav(Icons.air_rounded, 1),
                  _nav(Icons.self_improvement, 2),
                  _nav(Icons.home_rounded, 3),
                  _nav(Icons.book_rounded, 4),
                  _nav(Icons.pets, 5),
                  _nav(Icons.person_rounded, 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nav(IconData icon, int index) {
    final sel = _customScreen == null && _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _customScreen = null;
        _currentTab = index;
      }),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: sel ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(icon, size: 24, color: sel ? Colors.white : Colors.white60),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedMood = "", _currentGreetingTip = "", _currentMoodTip = "";

  @override
  void initState() {
    super.initState();
    _currentGreetingTip = greetingTips[Random().nextInt(greetingTips.length)];
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return "Доброй ночи";
    if (h < 12) return "Доброе утро";
    if (h < 18) return "Добрый день";
    return "Добрый вечер";
  }

  final _moods = [
    {"n": "Злость", "e": "😡"},
    {"n": "Грусть", "e": "😢"},
    {"n": "Тревога", "e": "😰"},
    {"n": "Апатия", "e": "😐"},
    {"n": "Нейтрально", "e": "🙂"},
    {"n": "Радость", "e": "😊"},
    {"n": "Счастье", "e": "😍"}
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppColors.mint, width: 3),
                ),
                child: Center(
                  child: Text(
                    AppState.avatar.isEmpty ? "🌸" : AppState.avatar,
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${_greeting()}, ${AppState.userName}!",
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(_currentGreetingTip,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.text),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () => MainWindow.of(context)?.setCustomScreen(const SosScreen()),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF87171), Color(0xFFEF4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6))
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("🆘", style: TextStyle(fontSize: 24)),
                  SizedBox(width: 12),
                  Text("Мне плохо прямо сейчас",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Center(
            child: Text("Как ты себя чувствуешь?",
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _moods.map((m) {
              final isSel = _selectedMood == m["n"];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMood = m["n"]!;
                    _currentMoodTip = moodSupport[m["n"]]!;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSel
                        ? AppColors.purpleLight.withValues(alpha: 0.3)
                        : Colors.transparent,
                    border: isSel
                        ? Border.all(color: AppColors.primaryDark, width: 2)
                        : null,
                  ),
                  child: Text(m["e"]!,
                      style: TextStyle(fontSize: isSel ? 34 : 28, height: 1.1)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _selectedMood.isEmpty
                ? const SizedBox()
                : Container(
                    key: ValueKey(_currentMoodTip),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                        color: AppColors.pastelGreen,
                        borderRadius: BorderRadius.circular(15)),
                    child: Text(_currentMoodTip,
                        style:
                            const TextStyle(fontSize: 14, color: AppColors.text),
                        textAlign: TextAlign.center),
                  ),
          ),
          const SizedBox(height: 20),
          if (_selectedMood.isNotEmpty)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mint,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                minimumSize: const Size.fromHeight(48),
                elevation: 0,
              ),
              onPressed: () {
                AppState.addMood(MoodEntry(mood: _selectedMood));
                AppState.addXp(10);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Сохранено: $_selectedMood")));
                setState(() {
                  _selectedMood = "";
                  _currentMoodTip = "";
                });
              },
              child: const Text("Отметить настроение",
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 30),
          _bigButton("🎨", "Календарь эмоций", "Посмотри прошлые дни",
              AppColors.pastelMint,
              () => MainWindow.of(context)?.setCustomScreen(const EmotionMapScreen())),
          _bigButton("🔥", "Тепловая карта", "Смотри свои эмоциональные паттерны",
              Colors.white,
              () => MainWindow.of(context)?.setCustomScreen(const HeatMapScreen())),
          _bigButton("🤖", "Инструменты ИИ", "Психолог, детектор, роли",
              AppColors.pastelPink,
              () => MainWindow.of(context)?.setCustomScreen(const AiToolsScreen())),
          _bigButton("📝", "Тесты", "Пройди тесты на самопознание",
              AppColors.pastelBlue,
              () => MainWindow.of(context)?.setCustomScreen(const TestsListScreen())),
        ],
      ),
    );
  }

  Widget _bigButton(String emoji, String title, String desc, Color color,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.primaryDark)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 18, color: AppColors.text),
          ],
        ),
      ),
    );
  }
}

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  int _phase = 0, _secondsLeft = 4;
  Timer? _timer;
  bool _running = false;
  String _phaseText = "Готов?";

  void _start() {
    setState(() {
      _running = true;
      _phase = 0;
      _secondsLeft = 4;
      _phaseText = "Вдох...";
    });
    _tick();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        if (_phase == 0) {
          setState(() {
            _phase = 1;
            _secondsLeft = 7;
            _phaseText = "Задержи...";
          });
        } else if (_phase == 1) {
          setState(() {
            _phase = 2;
            _secondsLeft = 8;
            _phaseText = "Выдох...";
          });
        } else {
          setState(() {
            _phase = 0;
            _secondsLeft = 4;
            _phaseText = "Вдох...";
          });
        }
      }
    });
  }

  double _getScale() {
    if (_phaseText == "Вдох...") {
      return 1.0 + (4 - _secondsLeft) / 4 * 0.4;
    }
    if (_phaseText == "Задержи...") {
      return 1.4;
    }
    if (_phaseText == "Выдох...") {
      return 1.4 - (8 - _secondsLeft) / 8 * 0.4;
    }
    return 1.0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showInstruction(String title, String instruction) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(instruction,
            style: const TextStyle(fontSize: 16, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Понятно"))
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF1F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => MainWindow.of(context)?.setCustomScreen(null),
        ),
        title: const Text("SOS",
            style: TextStyle(
                color: AppColors.danger, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.danger),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text("Я здесь. Я в безопасности.",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text)),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text("Нажми «Начать» и дыши с нами.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.primaryDark)),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 900),
                      width: 140 * (_running ? _getScale() : 1.0),
                      height: 140 * (_running ? _getScale() : 1.0),
                      decoration: BoxDecoration(
                        color: AppColors.mint.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.mint.withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 10)
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_phaseText,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text)),
                            const SizedBox(height: 8),
                            Text(_running ? "$_secondsLeft" : "—",
                                style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _running
                              ? AppColors.pastelPink
                              : AppColors.mint,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22)),
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () {
                          if (_running) {
                            _timer?.cancel();
                            setState(() {
                              _running = false;
                              _phaseText = "Стоп";
                              _secondsLeft = 0;
                            });
                          } else {
                            _start();
                          }
                        },
                        child: Text(_running ? "Стоп" : "▶  Начать дыхание",
                            style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _actionButton(
                  icon: "☎",
                  title: "Позвонить в телефон доверия",
                  color: AppColors.pastelPink,
                  onTap: () => _launchUrl("tel:88011001611")),
              _actionButton(
                  icon: "📝",
                  title: "Написать близкому",
                  color: AppColors.pastelBlue,
                  onTap: () {
                    _showInstruction(
                        "Напиши близкому",
                        "Скопируй этот текст и отправь тому, кому доверяешь:\n\n«Мне сейчас плохо. Побудь, пожалуйста, со мной. Мне нужна поддержка».");
                  }),
              _actionButton(
                  icon: "🚶",
                  title: "Умыться холодной водой",
                  color: AppColors.pastelGreen,
                  onTap: () {
                    _showInstruction(
                        "Холодная вода",
                        "Пойди в ванную и умойся ледяной водой. Задержи дыхание на 10-15 секунд. Это активирует 'рефлекс ныряльщика' и поможет телу успокоиться.");
                  }),
              _actionButton(
                  icon: "🧊",
                  title: "Лёд к запястью",
                  color: AppColors.pastelMint,
                  onTap: () {
                    _showInstruction(
                        "Лёд к запястью",
                        "Возьми кубик льда и приложи его к внутренней стороне запястья на 30 секунд. Или просто подержи руки под очень холодной водой. Это переключит внимание с эмоций на физические ощущения.");
                  }),
              _actionButton(
                  icon: "🤖",
                  title: "Поговорить с ИИ-психологом",
                  color: AppColors.pastelPeach,
                  onTap: () => MainWindow.of(context)
                      ?.setCustomScreen(const AiTherapistScreen())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 15),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text))),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});
  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> {
  String? _selectedPractice;
  int _cycle = 0, _secondsLeft = 4;
  String _phaseText = "Вдох...";
  bool _running = false;
  Timer? _timer;

  final List<Map<String, dynamic>> _practices = [
    {
      "name": "Дыхание 4-7-8",
      "desc": "Успокой пульс за 2 минуты",
      "inhale": 4,
      "hold": 7,
      "exhale": 8,
      "cycles": 4,
      "emoji": "🌬️"
    },
    {
      "name": "Квадратное дыхание",
      "desc": "Баланс и концентрация",
      "inhale": 4,
      "hold": 4,
      "exhale": 4,
      "cycles": 4,
      "emoji": "🟦"
    },
    {
      "name": "Дыхание 4-4-6",
      "desc": "Для сна и расслабления",
      "inhale": 4,
      "hold": 4,
      "exhale": 6,
      "cycles": 4,
      "emoji": "🌙"
    },
    {
      "name": "Глубокое дыхание",
      "desc": "Снять стресс",
      "inhale": 6,
      "hold": 0,
      "exhale": 8,
      "cycles": 3,
      "emoji": "🌊"
    },
  ];

  void _startPractice(Map<String, dynamic> p) {
    setState(() {
      _selectedPractice = p["name"];
      _running = true;
      _cycle = 0;
      _phaseText = "Вдох...";
      _secondsLeft = p["inhale"];
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          if (_phaseText == "Вдох...") {
            if (p["hold"] > 0) {
              _phaseText = "Задержка...";
              _secondsLeft = p["hold"];
            } else {
              _phaseText = "Выдох...";
              _secondsLeft = p["exhale"];
            }
          } else if (_phaseText == "Задержка...") {
            _phaseText = "Выдох...";
            _secondsLeft = p["exhale"];
          } else {
            _phaseText = "Вдох...";
            _secondsLeft = p["inhale"];
            _cycle++;
            if (_cycle >= p["cycles"]) {
              _timer?.cancel();
              _running = false;
              AppState.addXp(15);
              AppState.feedCat();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Практика завершена! Котик доволен 💜")));
              }
            }
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text("🌬️ Дыхание",
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(child: _running ? _practiceView() : _listView()),
    );
  }

  Widget _listView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Выбери практику",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 5),
          const Text("Разные виды дыхания для разных состояний",
              style:
                  TextStyle(fontSize: 13, color: AppColors.primaryDark)),
          const SizedBox(height: 20),
          ..._practices.map((p) => GestureDetector(
                onTap: () => _startPractice(p),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Text(p["emoji"],
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p["name"],
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text)),
                            Text(p["desc"],
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primaryDark)),
                          ],
                        ),
                      ),
                      const Icon(Icons.play_arrow_rounded,
                          size: 28, color: AppColors.primary),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _practiceView() {
    final p = _practices.firstWhere((x) => x["name"] == _selectedPractice);
    double scale = 1.0;
    if (_phaseText == "Вдох...") {
      scale = 1.0 + (p["inhale"] - _secondsLeft) / p["inhale"] * 0.4;
    } else if (_phaseText == "Задержка...") {
      scale = 1.4;
    } else if (_phaseText == "Выдох...") {
      scale = 1.4 - (p["exhale"] - _secondsLeft) / p["exhale"] * 0.4;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(p["name"],
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text)),
          const SizedBox(height: 10),
          Text(_phaseText,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          const SizedBox(height: 30),
          SizedBox(
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 900),
                  width: 140 * scale,
                  height: 140 * scale,
                  decoration: BoxDecoration(
                    color: AppColors.pastelBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: 10)
                    ],
                  ),
                  child: Center(
                      child: Text("$_secondsLeft",
                          style: const TextStyle(
                              fontSize: 40, fontWeight: FontWeight.bold))),
                ),
                Positioned(
                  bottom: 0,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22)),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () {
                      _timer?.cancel();
                      setState(() {
                        _running = false;
                        _selectedPractice = null;
                      });
                    },
                    child: const Text("Остановить"),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text("Цикл $_cycle из ${p["cycles"]}",
              style: const TextStyle(
                  fontSize: 14, color: AppColors.primaryDark)),
          const SizedBox(height: 20),
          TextButton(
            style:
                TextButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () {
              _timer?.cancel();
              MainWindow.of(context)?.setCustomScreen(null);
            },
            child: const Text("Выйти из практики",
                style:
                    TextStyle(color: AppColors.textLight, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});
  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  String? _selected;
  int _step = 0;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  final List<Map<String, dynamic>> _meditations = [
    {
      "name": "Медитация на дыхание",
      "desc": "5 минут • базовое спокойствие",
      "emoji": "🌿",
      "color": AppColors.pastelGreen,
      "steps": [
        "Сядь удобно.",
        "Вдох на 4 счёта. Выдох на 6.",
        "Следи за дыханием. Не меняй его.",
        "Мысли приходят и уходят. Ты просто наблюдаешь.",
        "Снова и снова возвращайся к дыханию.",
        "Побудь в тишине ещё немного. 💜"
      ]
    },
    {
      "name": "Сканирование тела",
      "desc": "7 минут • снять напряжение",
      "emoji": "💆",
      "color": AppColors.pastelBlue,
      "steps": [
        "Ляг или сядь удобно.",
        "Направь внимание в стопы. Что ты чувствуешь?",
        "Медленно поднимайся вверх: ноги, живот, грудь, руки, шея, голова.",
        "Замечай напряжение и расслабляй его.",
        "Ты в безопасности. Твоё тело расслабляется. 💜"
      ]
    },
    {
      "name": "Медитация на благодарность",
      "desc": "5 минут • для хорошего настроения",
      "emoji": "🙏",
      "color": AppColors.pastelYellow,
      "steps": [
        "Сядь удобно.",
        "Вспомни 3 вещи, за которые ты благодарен(на) сегодня.",
        "Почувствуй тепло в груди от этих мыслей.",
        "Пошли благодарность себе за то, что ты здесь. 💜"
      ]
    },
    {
      "name": "Медитация перед сном",
      "desc": "10 минут • для глубокого сна",
      "emoji": "🌙",
      "color": AppColors.pastelPink,
      "steps": [
        "Ляг в кровать.",
        "Дыши медленно и глубоко.",
        "Представь, как напряжение уходит из тела.",
        "Отпусти этот день. Он закончился.",
        "Ты в безопасности. Спи. 💜"
      ]
    },
  ];

  Future<void> _playMusic() async {
    if (!AppState.soundEnabled) return;
    try {
      setState(() => _isPlaying = true);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/meditation.mp3'));
    } catch (e) {
      debugPrint("Ошибка музыки: $e");
    }
  }

  void _startMeditation(Map<String, dynamic> m) {
    setState(() {
      _selected = m["name"];
      _step = 0;
    });
    _playMusic();
    _timer = Timer.periodic(const Duration(seconds: 12), (t) {
      if (!mounted) return;
      setState(() {
        if (_step < (m["steps"] as List).length - 1) {
          _step++;
        } else {
          _timer?.cancel();
          _audioPlayer.stop();
          setState(() => _isPlaying = false);
          AppState.addXp(20);
          AppState.feedCat();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Медитация завершена! 💜")));
            setState(() {
              _selected = null;
              _step = 0;
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text("🧘 Медитации",
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
          child: _selected == null ? _listView() : _meditationView()),
    );
  }

  Widget _listView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Выбери медитацию",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 5),
          const Text("Спокойная музыка, мягкий темп",
              style:
                  TextStyle(fontSize: 13, color: AppColors.primaryDark)),
          const SizedBox(height: 20),
          ..._meditations.map((m) => GestureDetector(
                onTap: () => _startMeditation(m),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: m["color"],
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Text(m["emoji"],
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m["name"],
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text)),
                            Text(m["desc"],
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primaryDark)),
                          ],
                        ),
                      ),
                      const Icon(Icons.play_arrow_rounded,
                          size: 28, color: AppColors.text),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _meditationView() {
    final m = _meditations.firstWhere((x) => x["name"] == _selected);
    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(m["name"],
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text)),
          const SizedBox(height: 30),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isPlaying)
                    const Icon(Icons.music_note,
                        size: 60, color: AppColors.primary)
                  else
                    const Icon(Icons.graphic_eq,
                        size: 40, color: AppColors.primary),
                  const SizedBox(height: 20),
                  Text((m["steps"] as List)[_step],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22,
                          color: AppColors.text,
                          height: 1.5)),
                ],
              ),
            ),
          ),
          Text("Шаг ${_step + 1} из ${(m["steps"] as List).length}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.primaryDark)),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () {
              _timer?.cancel();
              _audioPlayer.stop();
              setState(() {
                _selected = null;
                _step = 0;
                _isPlaying = false;
              });
            },
            child: const Text("Остановить"),
          ),
        ],
      ),
    );
  }
}

class PetScreen extends StatefulWidget {
  const PetScreen({super.key});
  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  String _thoughtBubble = "Я тебя ждал! 💜";
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentCard = 0;
  final List<Map<String, String>> _catCards = [
    {
      "img": "assets/images/cat1.jpg",
      "text":
          "И страх, и мечта просят тебя поверить в то, чего не существует. Выбирать тебе."
    },
    {
      "img": "assets/images/cat2.jpg",
      "text": "Всё является победой, когда цель — получить опыт."
    },
    {
      "img": "assets/images/cat3.jpg",
      "text": "Иногда начать сначала значит по-другому взглянуть на мир."
    },
    {
      "img": "assets/images/cat4.jpg",
      "text":
          "Ты можешь быть самым красивым оттенком голубого, но этого недостаточно для того, чей любимый цвет зелёный."
    },
    {
      "img": "assets/images/cat5.jpg",
      "text":
          "Ребёнок, рождённый в горящем доме, думает, что весь мир в огне. Но это не так."
    },
    {
      "img": "assets/images/cat6.jpg",
      "text":
          "Может, твой сад не растёт, потому что ты срываешь каждый распустившийся цветок, чтобы доказать, что ты — садовник."
    },
    {
      "img": "assets/images/cat7.jpg",
      "text": "Ты не можешь по чужой карте найти себя."
    },
  ];

  @override
  void initState() {
    super.initState();
    _updateThoughts();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_pageController.hasClients) {
        _currentCard = (_currentCard + 1) % _catCards.length;
        _pageController.animateToPage(_currentCard,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _updateThoughts() {
    final hour = DateTime.now().hour;
    if (hour >= 22 || hour < 8) {
      setState(() => _thoughtBubble = "💤 Я сплю... (Разбуди меня, погладив)");
    } else if (AppState.catHunger < 30) {
      setState(() => _thoughtBubble = "🍕 Я голоден... Покорми меня?");
    } else {
      setState(() => _thoughtBubble = "Я тебя ждал! 💜");
    }
  }

  String _getCatImage() {
    final hour = DateTime.now().hour;
    if (hour >= 22 || hour < 8) {
      return 'assets/images/cat_sleep.png';
    }
    if (AppState.catHunger < 30) {
      return 'assets/images/cat_hungry.png';
    }
    if (AppState.catHunger < 70) {
      return 'assets/images/cat_sleep.png';
    }
    return 'assets/images/cat_happy.png';
  }

  void _petTheCat() {
    setState(() {
      _thoughtBubble = "Мур-мур! 💜";
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _updateThoughts();
    });
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("История ${AppState.petName}"),
        content: const SingleChildScrollView(
          child: Text(
            "Однажды, в самый обычный день, ты нашёл(а) маленького котёнка. Он был один, напуган и дрожал от холода.\n\nТы взял(а) его на руки, и он сразу прижался к тебе. С тех пор он всегда рядом. Он не умеет говорить, но чувствует твоё настроение.\n\nКогда тебе грустно — он приходит и мурлычет. Когда ты радуешься — он прыгает и играет. Он — твой маленький друг, который всегда тебя ждёт.\n\nТеперь у тебя есть тот, кто всегда рад тебя видеть. 💜",
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Спасибо 💜"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text("🐱 ${AppState.petName}",
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text)),
          const SizedBox(height: 5),
          Text(
              "Уровень: ${AppState.catLevel} • Сытость: ${AppState.catHunger}%",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark)),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(_thoughtBubble),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.pastelBlue,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(_thoughtBubble,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.text)),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _petTheCat,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Image.asset(
                _getCatImage(),
                key: ValueKey(_getCatImage()),
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const Center(
                    child: Text("🐱", style: TextStyle(fontSize: 100))),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _petTheCat,
                icon: const Icon(Icons.favorite, color: Colors.white),
                label: const Text("Погладить"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  MainWindow.of(context)
                      ?.setCustomScreen(const LessonsScreen());
                },
                icon: const Icon(Icons.restaurant, color: AppColors.text),
                label: const Text("Покормить"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: AppColors.text),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _showHistory,
                icon: const Icon(Icons.info_outline, color: AppColors.primary),
                tooltip: "История",
              )
            ],
          ),
          const SizedBox(height: 30),
          Text("Мудрость ${AppState.petName}",
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text)),
          const SizedBox(height: 10),
          SizedBox(
            height: 280,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (i) => _currentCard = i,
              itemCount: _catCards.length,
              itemBuilder: (context, index) {
                final card = _catCards[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => GalleryScreen(
                                cards: _catCards, initialIndex: index)));
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration:
                        BoxDecoration(borderRadius: BorderRadius.circular(16)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            card["img"]!,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => Container(
                                color: AppColors.pastelMint,
                                child: const Center(
                                    child: Text("🐱",
                                        style: TextStyle(fontSize: 80)))),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6)
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.all(10),
                            alignment: Alignment.bottomCenter,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(AppState.petName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                Text(card["text"]!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_catCards.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentCard == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                    color: _currentCard == i
                        ? AppColors.primary
                        : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(4)),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class GalleryScreen extends StatefulWidget {
  final List<Map<String, String>> cards;
  final int initialIndex;
  const GalleryScreen({super.key, required this.cards, this.initialIndex = 0});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemCount: widget.cards.length,
                itemBuilder: (context, index) {
                  final card = widget.cards[index];
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Image.asset(
                            card["img"]!,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Center(
                                child: Text("🐱",
                                    style: TextStyle(fontSize: 100))),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(AppState.petName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text(card["text"]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.5)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text("${_currentIndex + 1} / ${widget.cards.length}",
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class SelfKnowledgeLesson {
  final String title, block, description;
  final int xp;
  final Color color;
  final String emoji;
  final List<Map<String, String>> steps;

  SelfKnowledgeLesson({
    required this.title,
    required this.block,
    required this.description,
    required this.xp,
    required this.color,
    required this.emoji,
    required this.steps,
  });
}

final List<SelfKnowledgeLesson> selfKnowledgeLessons = [
  SelfKnowledgeLesson(
    title: "Кто я? (роли и качества)",
    block: "Блок 1. Кто я?",
    description: "Разберись, что в тебе — роли, а что — настоящие качества",
    xp: 15,
    color: AppColors.pastelBlue,
    emoji: "🎭",
    steps: [
      {
        "t": "Шаг 1. Выпиши 10 ответов на вопрос «Кто я?»",
        "d":
            "Напиши 10 предложений, начинающихся с «Я — ...». Не думай долго, пиши первое, что приходит в голову."
      },
      {
        "t": "Шаг 2. Раздели на роли и качества",
        "d":
            "Просмотри список. Роли — это «сын», «ученик», «друг». Качества — это «любопытный», «тревожный», «добрый». Отметь, что к чему относится."
      },
      {
        "t": "Шаг 3. Что остаётся, если убрать роли?",
        "d":
            "Представь, что ты лишился всех ролей. Что останется? Это и есть твоё ядро. Запиши 3-5 качеств, которые остаются."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Колесо жизненного баланса",
    block: "Блок 1. Кто я?",
    description: "Оцени 8 сфер жизни и найди провалы",
    xp: 20,
    color: AppColors.pastelGreen,
    emoji: "🎡",
    steps: [
      {
        "t": "Шаг 1. Нарисуй круг и раздели на 8 секторов",
        "d":
            "Сферы: здоровье, работа/учёба, отношения, деньги, развитие, отдых, среда (дом), смысл (зачем я живу)."
      },
      {
        "t": "Шаг 2. Оцени каждую сферу от 1 до 10",
        "d": "Где 10 — всё идеально, 1 — полный провал. Будь честен(на) с собой."
      },
      {
        "t": "Шаг 3. Найди самые низкие оценки",
        "d":
            "Какие 2-3 сферы провалены сильнее всего? Почему? Что мешает их поднять?"
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Мои ценности",
    block: "Блок 1. Кто я?",
    description: "Определи топ-5 ценностей и проверь, совпадает ли с ними жизнь",
    xp: 20,
    color: AppColors.pastelYellow,
    emoji: "💎",
    steps: [
      {
        "t": "Шаг 1. Список ценностей",
        "d":
            "Выпиши 15-20 ценностей: свобода, безопасность, творчество, семья, дружба, развитие, честность, любовь, признание, покой, приключения, помощь другим, деньги, власть, красота, здоровье, знания, справедливость, независимость, уважение."
      },
      {
        "t": "Шаг 2. Сократи до топ-10",
        "d":
            "Вычеркни те, без которых можно обойтись. Оставь 10 самых важных."
      },
      {
        "t": "Шаг 3. Сократи до топ-5",
        "d":
            "Из 10 оставь 5. Это твоё ядро. Именно они определяют, что для тебя важно."
      },
      {
        "t": "Шаг 4. Проверка",
        "d":
            "Посмотри на свою жизнь. Совпадает ли то, как ты проводишь время, с этими 5 ценностями? Если нет — что можно изменить?"
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "История моей жизни в 6 главах",
    block: "Блок 1. Кто я?",
    description: "Разбей жизнь на главы и посмотри на сюжет",
    xp: 25,
    color: AppColors.pastelPink,
    emoji: "📖",
    steps: [
      {
        "t": "Шаг 1. Разбей жизнь на 6 глав",
        "d":
            "Например: детство, школа, первая дружба, переезд, увлечение, настоящее. Каждый период — глава."
      },
      {
        "t": "Шаг 2. Дай каждой главе название",
        "d":
            "Не «1-4 класс», а «Время открытий» или «Годы тишины». Как бы ты назвал(а) этот период?"
      },
      {
        "t": "Шаг 3. Определи главного героя",
        "d":
            "Кто главный герой твоей истории? Как он менялся? Что им двигало?"
      },
      {
        "t": "Шаг 4. Какой сюжет?",
        "d":
            "Это история преодоления? История поиска? История любви? Что объединяет все главы?"
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Эмоции — это информация",
    block: "Блок 2. Эмоции и характер",
    description: "Разбери эмоции как сигналы о потребностях",
    xp: 15,
    color: AppColors.pastelMint,
    emoji: "💭",
    steps: [
      {
        "t": "Шаг 1. Вспомни 3 ситуации",
        "d":
            "За последнюю неделю, где ты испытал(а) сильные эмоции. Запиши их."
      },
      {
        "t": "Шаг 2. Заполни таблицу",
        "d":
            "Ситуация → Эмоция → Потребность за ней. Например: «Меня перебили → злость → потребность в уважении»."
      },
      {
        "t": "Шаг 3. Что хочет сказать эмоция?",
        "d":
            "Каждая эмоция — это сигнал. Злость — границы нарушены. Грусть — потеря. Тревога — что-то важно. Страх — опасность. Радость — всё хорошо."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Тревога: круг контроля",
    block: "Блок 2. Эмоции и характер",
    description: "Раздели, что в твоих руках, а что нет",
    xp: 20,
    color: AppColors.pastelBlue,
    emoji: "⭕",
    steps: [
      {
        "t": "Шаг 1. Нарисуй два круга",
        "d": "Внутренний — «что я контролирую». Внешний — «что я не контролирую»."
      },
      {
        "t": "Шаг 2. Выпиши свою тревогу",
        "d": "Что именно тебя беспокоит? Например: «Экзамен»."
      },
      {
        "t": "Шаг 3. Разложи по кругам",
        "d":
            "Что зависит от тебя? (подготовка, сон, повторение). Что нет? (вопросы, погода, настроение учителя)."
      },
      {
        "t": "Шаг 4. Действуй только по внутреннему кругу",
        "d":
            "Всё, что во внешнем — отпусти. Ты не можешь это контролировать. Сделай один шаг из внутреннего круга."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Мой внутренний критик",
    block: "Блок 2. Эмоции и характер",
    description: "Познакомься с голосом, который тебя критикует",
    xp: 20,
    color: AppColors.pastelPeach,
    emoji: "🗣️",
    steps: [
      {
        "t": "Шаг 1. Дай имя критику",
        "d":
            "Как бы ты назвал(а) голос, который говорит «ты не справишься»? Может, «Серый» или «Тётя Люда»?"
      },
      {
        "t": "Шаг 2. Запиши 5 типичных фраз",
        "d":
            "Что этот критик обычно говорит? «Ты ленивый», «У тебя ничего не выйдет»."
      },
      {
        "t": "Шаг 3. Кто это говорит на самом деле?",
        "d":
            "Чей это голос? Мамы? Учителя? Общества? Ты сам(а)?"
      },
      {
        "t": "Шаг 4. Ответь критику",
        "d":
            "Что бы ты сказал(а) другу, которого так критикуют? Скажи это себе."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Сильные стороны (метод зеркало)",
    block: "Блок 2. Эмоции и характер",
    description: "Собери 5 отзывов о своей силе",
    xp: 25,
    color: AppColors.pastelYellow,
    emoji: "🪞",
    steps: [
      {
        "t": "Шаг 1. Спроси 5 человек",
        "d":
            "Спроси у 5 знакомых: «Что во мне сильного?» Запиши ответы. Это может быть неловко, но это важно."
      },
      {
        "t": "Шаг 2. Найди повторы",
        "d": "Какие качества повторяются? Это твои сильные стороны."
      },
      {
        "t": "Шаг 3. Добавь свои",
        "d":
            "Что ты сам(а) считаешь своей силой? Даже если это кажется мелочью."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Почему я снова наступаю на те же грабли",
    block: "Блок 3. Паттерны и сценарии",
    description: "Найди повторяющийся сценарий",
    xp: 25,
    color: AppColors.pastelGreen,
    emoji: "🔄",
    steps: [
      {
        "t": "Шаг 1. Вспомни 3 повторяющиеся ситуации",
        "d":
            "Что происходит с тобой снова и снова? Одинаковые конфликты? Одинаковые провалы?"
      },
      {
        "t": "Шаг 2. Разложи по схеме",
        "d":
            "Триггер → Реакция → Результат. Что запускает? Как ты реагируешь? Что получается в итоге?"
      },
      {
        "t": "Шаг 3. Найди цикл",
        "d":
            "Как эти три элемента связаны? Результат снова становится триггером?"
      },
      {
        "t": "Шаг 4. Где можно разорвать цикл?",
        "d":
            "Что можно изменить в триггере, реакции или результате? Начни с одного шага."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Установки из детства",
    block: "Блок 3. Паттерны и сценарии",
    description: "Разбери фразы, которые управляют тобой",
    xp: 20,
    color: AppColors.pastelPink,
    emoji: "📜",
    steps: [
      {
        "t": "Шаг 1. Вспомни фразы",
        "d":
            "«Нельзя», «Надо», «Не будь...» — что говорили тебе в детстве?"
      },
      {
        "t": "Шаг 2. Откуда фраза?",
        "d":
            "Кто это говорил? Мама, папа, бабушка, учитель? В какой ситуации?"
      },
      {
        "t": "Шаг 3. Чья она?",
        "d": "Это правда твоя установка или ты просто её усвоил(а)?"
      },
      {
        "t": "Шаг 4. Что ты хочешь с ней сделать?",
        "d":
            "Оставить, изменить или отпустить? Как бы звучала более здоровая фраза?"
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Прокрастинация как сигнал",
    block: "Блок 3. Паттерны и сценарии",
    description: "Пойми, чего ты избегаешь на самом деле",
    xp: 20,
    color: AppColors.pastelBlue,
    emoji: "⏳",
    steps: [
      {
        "t": "Шаг 1. Вспомни 3 последних откладывания",
        "d": "Что ты откладывал(а) на потом? Почему?"
      },
      {
        "t": "Шаг 2. Задай вопрос: «Чего я боюсь?»",
        "d": "Провала? Успеха? Осуждения? Скуки? Перегрузки?"
      },
      {
        "t": "Шаг 3. Разбей задачу",
        "d":
            "Слишком большая? Разбей на маленькие шаги. Первый шаг — самый лёгкий."
      },
      {
        "t": "Шаг 4. Сделай 1 шаг",
        "d": "Прямо сейчас. Просто начни. Не думая о результате."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Границы: где я теряю себя",
    block: "Блок 3. Паттерны и сценарии",
    description: "Найди ситуации, где ты говоришь «да», хотя хочешь «нет»",
    xp: 25,
    color: AppColors.pastelMint,
    emoji: "🚧",
    steps: [
      {
        "t": "Шаг 1. Список ситуаций",
        "d":
            "Когда ты говорил(а) «да», хотя хотел(а) «нет»? С кем? В каких ситуациях?"
      },
      {
        "t": "Шаг 2. Что ты чувствовал(а) потом?",
        "d": "Обиду? Злость? Усталость? Чувство, что тебя используют?"
      },
      {
        "t": "Шаг 3. Что мешает сказать «нет»?",
        "d": "Страх обидеть? Страх отвержения? Привычка?"
      },
      {
        "t": "Шаг 4. Попробуй одну фразу",
        "d":
            "«Я подумаю», «Мне неудобно это сделать», «Я сейчас не могу». Начни с малого."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Языки любви",
    block: "Блок 4. Отношения",
    description: "Как ты даёшь и хочешь получать заботу",
    xp: 20,
    color: AppColors.pastelPeach,
    emoji: "❤️",
    steps: [
      {
        "t": "Шаг 1. 5 языков любви",
        "d":
            "Слова, время, подарки, помощь, прикосновения. Какой для тебя главный?"
      },
      {
        "t": "Шаг 2. Как ты даёшь заботу?",
        "d": "Что ты чаще делаешь для других?"
      },
      {
        "t": "Шаг 3. Как хочешь получать?",
        "d": "Что для тебя — проявление любви?"
      },
      {
        "t": "Шаг 4. Совпадает ли?",
        "d":
            "Часто мы даём так, как хотим получать, а другой — иначе. Обсуди это с близкими."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Мои роли в конфликте",
    block: "Блок 4. Отношения",
    description: "Жертва, спасатель или преследователь?",
    xp: 20,
    color: AppColors.pastelPink,
    emoji: "🎭",
    steps: [
      {
        "t": "Шаг 1. Вспомни последний конфликт",
        "d": "С кем? Из-за чего?"
      },
      {
        "t": "Шаг 2. Какую роль ты играл(а)?",
        "d":
            "Жертва (мне плохо, помогите), Спасатель (я решу всё за других) или Преследователь (ты виноват)?"
      },
      {
        "t": "Шаг 3. Часто ли ты в этой роли?",
        "d": "Замечаешь ли ты повторение?"
      },
      {
        "t": "Шаг 4. Выход из роли",
        "d":
            "Как можно выйти? Например, сказать «я сам(а)», «это не моя ответственность»."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Кого я выбираю и почему",
    block: "Блок 4. Отношения",
    description:
        "Паттерн в отношениях: что общего у людей, в которых влюбляешься?",
    xp: 25,
    color: AppColors.pastelGreen,
    emoji: "🔍",
    steps: [
      {
        "t": "Шаг 1. Вспомни 3-5 человек",
        "d": "В которых ты был(а) влюблен(а) или которые тебе нравились."
      },
      {
        "t": "Шаг 2. Что у них общего?",
        "d": "Характер? Внешность? Поведение? Отношение к тебе?"
      },
      {
        "t": "Шаг 3. Что это говорит о тебе?",
        "d": "Что ты ищешь? Безопасность? Приключения? Признание?"
      },
      {
        "t": "Шаг 4. Это осознанный выбор?",
        "d": "Или ты просто повторяешь сценарий?"
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Идеальный день через 5 лет",
    block: "Блок 5. Смысл и движение",
    description: "Опиши детально, что можно начать делать уже сейчас",
    xp: 25,
    color: AppColors.pastelBlue,
    emoji: "🌅",
    steps: [
      {
        "t": "Шаг 1. Опиши свой день через 5 лет",
        "d":
            "Где ты? С кем? Чем занимаешься? Как выглядит твой день с утра до вечера?"
      },
      {
        "t": "Шаг 2. Что из этого можно начать делать на этой неделе?",
        "d": "Не всё сразу. Один маленький шаг."
      },
      {
        "t": "Шаг 3. Что тебе мешает начать?",
        "d": "Что мешает уже сегодня сделать этот шаг?"
      },
      {
        "t": "Шаг 4. Сделай этот шаг",
        "d": "Не откладывай. Даже если он крошечный."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Икигай",
    block: "Блок 5. Смысл и движение",
    description: "Найди пересечение 4 кругов",
    xp: 30,
    color: AppColors.pastelMint,
    emoji: "🎯",
    steps: [
      {
        "t": "Шаг 1. Что я люблю?",
        "d": "Что тебе нравится делать, от чего ты получаешь удовольствие?"
      },
      {"t": "Шаг 2. Что я умею?", "d": "В чём ты хорош(а)?"},
      {"t": "Шаг 3. Что нужно миру?", "d": "Что ты можешь дать другим?"},
      {
        "t": "Шаг 4. За что платят?",
        "d": "Что можно превратить в источник дохода?"
      },
      {
        "t": "Шаг 5. Найди пересечение",
        "d": "Икигай — это то, что находится на пересечении всех четырёх."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Письмо себе через 10 лет",
    block: "Блок 5. Смысл и движение",
    description: "Напиши письмо и ответь от будущего себя",
    xp: 25,
    color: AppColors.pastelYellow,
    emoji: "✉️",
    steps: [
      {
        "t": "Шаг 1. Напиши письмо себе через 10 лет",
        "d": "Что ты хочешь сказать? О чём мечтаешь?"
      },
      {
        "t": "Шаг 2. Ответь от будущего себя",
        "d": "Что бы сказал(а) тебе ты через 10 лет?"
      },
      {
        "t": "Шаг 3. Что удивило?",
        "d": "Что нового ты узнал(а) о своих желаниях?"
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Страхи: топ-5 → план",
    block: "Блок 5. Смысл и движение",
    description: "Разбери страхи: вероятность, худший сценарий, первый шаг",
    xp: 30,
    color: AppColors.pastelPeach,
    emoji: "😨",
    steps: [
      {"t": "Шаг 1. Выпиши 5 страхов", "d": "Что тебя пугает?"},
      {
        "t": "Шаг 2. Оцени вероятность",
        "d": "От 0 до 100%. Насколько это реально?"
      },
      {
        "t": "Шаг 3. Худший сценарий",
        "d": "Что самое плохое может случиться? Ты это переживёшь?"
      },
      {
        "t": "Шаг 4. Первый шаг",
        "d": "Что можно сделать, чтобы страх стал меньше?"
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Мой личный манифест",
    block: "Блок 5. Смысл и движение",
    description: "10 пунктов: во что я верю, как хочу жить",
    xp: 30,
    color: AppColors.pastelPink,
    emoji: "📝",
    steps: [
      {
        "t": "Шаг 1. Закончи предложения",
        "d":
            "«Я верю, что...», «Для меня важно...», «Я никогда не...», «Я всегда...», «Моя жизнь — это...»."
      },
      {
        "t": "Шаг 2. Сформулируй 10 пунктов",
        "d":
            "Это твой манифест. То, что для тебя неприемлемо, и то, чего ты хочешь."
      },
      {
        "t": "Шаг 3. Перечитывай",
        "d": "Возвращайся к этому списку, когда сомневаешься."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Дневник жалоб на себя",
    block: "Блок 6. Новые уроки",
    description: "Выгрузи всё, что тебя не устраивает в себе",
    xp: 20,
    color: AppColors.pastelPink,
    emoji: "📝",
    steps: [
      {
        "t": "Шаг 1. Напиши 10 жалоб на себя",
        "d":
            "Всё, что тебе не нравится в себе, в своей жизни, в своём поведении. Не фильтруй."
      },
      {
        "t": "Шаг 2. Перечитай",
        "d": "Что из этого — реальность, а что — накрученное?"
      },
      {
        "t": "Шаг 3. Выбери одну жалобу",
        "d": "Самую важную. Что можно с ней сделать?"
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Свидание с собой",
    block: "Блок 6. Новые уроки",
    description: "Проведи время с собой и узнай, что тебе нравится",
    xp: 25,
    color: AppColors.pastelPeach,
    emoji: "💖",
    steps: [
      {
        "t": "Шаг 1. Выбери день",
        "d":
            "Когда ты проведёшь 2 часа только для себя. Без телефона, без других людей."
      },
      {
        "t": "Шаг 2. Сделай что-то для себя",
        "d":
            "Прогулка, рисование, чтение, ванна, музыка. Всё, что тебе нравится."
      },
      {
        "t": "Шаг 3. Запиши чувства",
        "d": "Что ты почувствовал(а)? Что понравилось? Что нет?"
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Детектив внутреннего голоса",
    block: "Блок 6. Новые уроки",
    description: "Найди, кто говорит в твоей голове",
    xp: 20,
    color: AppColors.pastelBlue,
    emoji: "🔍",
    steps: [
      {
        "t": "Шаг 1. Запиши мысль",
        "d": "Какая мысль крутится у тебя в голове чаще всего?"
      },
      {
        "t": "Шаг 2. Чей это голос?",
        "d": "Мама? Учитель? Друг? Ты сам(а)?"
      },
      {
        "t": "Шаг 3. Что он хочет сказать?",
        "d": "О чём он пытается тебя предупредить?"
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Тест-драйв нового «я»",
    block: "Блок 6. Новые уроки",
    description: "Попробуй вести себя как другой человек",
    xp: 25,
    color: AppColors.pastelGreen,
    emoji: "🎭",
    steps: [
      {
        "t": "Шаг 1. Выбери качество",
        "d":
            "Какое качество ты хочешь в себе развить? Смелость? Спокойствие? Уверенность?"
      },
      {
        "t": "Шаг 2. Веди себя так",
        "d":
            "Один день веди себя так, будто это качество у тебя уже есть."
      },
      {
        "t": "Шаг 3. Запиши результат",
        "d": "Что получилось? Что было сложно? Что понравилось?"
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Квест «Кто я по паспорту чувств»",
    block: "Блок 6. Новые уроки",
    description: "Составь свой психологический паспорт",
    xp: 20,
    color: AppColors.pastelYellow,
    emoji: "🪪",
    steps: [
      {
        "t": "Шаг 1. Заполни паспорт",
        "d":
            "Имя, возраст, любимые эмоции, нелюбимые эмоции, что тебя радует, что огорчает."
      },
      {"t": "Шаг 2. Добавь качества", "d": "5 сильных сторон, 5 слабых."},
      {
        "t": "Шаг 3. Перечитывай",
        "d": "Возвращайся к паспорту, когда сомневаешься."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Разоблачение внутреннего критика",
    block: "Блок 6. Новые уроки",
    description: "Ответь своему критику",
    xp: 25,
    color: AppColors.pastelMint,
    emoji: "🦸",
    steps: [
      {
        "t": "Шаг 1. Запиши 5 фраз критика",
        "d": "Что он тебе говорит?"
      },
      {
        "t": "Шаг 2. Ответь на каждую",
        "d":
            "Как бы ты ответил(а) другу, которого так критикуют?"
      },
      {
        "t": "Шаг 3. Замени фразы",
        "d": "Придумай поддерживающие фразы вместо критикующих."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Финальный экзамен «Сам себе друг»",
    block: "Блок 6. Новые уроки",
    description: "Проверь, научился ли ты поддерживать себя",
    xp: 30,
    color: AppColors.pastelPink,
    emoji: "🎓",
    steps: [
      {
        "t": "Шаг 1. Вспомни сложную ситуацию",
        "d": "Что произошло? Как ты себя чувствовал(а)?"
      },
      {
        "t": "Шаг 2. Напиши поддержку",
        "d":
            "Что бы ты сказал(а) другу в такой ситуации? Скажи это себе."
      },
      {
        "t": "Шаг 3. Сделай что-то для себя",
        "d": "Маленький шаг, который покажет заботу о себе."
      },
    ],
  ),
  SelfKnowledgeLesson(
    title: "Нарисуй своё состояние",
    block: "Блок 6. Новые уроки",
    description: "Нарисуй, что ты чувствуешь",
    xp: 25,
    color: AppColors.pastelBlue,
    emoji: "🎨",
    steps: [
      {
        "t": "Шаг 1. Открой холст",
        "d":
            "Закрой глаза и представь, как выглядит твоё состояние сейчас."
      },
      {
        "t": "Шаг 2. Нарисуй",
        "d":
            "Используй цвета, формы, линии. Не думай о красоте. Можно менять толщину кисти."
      },
      {
        "t": "Шаг 3. Сохрани",
        "d":
            "Нажми «В профиль», чтобы рисунок остался в профиле, или «В галерею», чтобы отправить в галерею телефона."
      },
    ],
  ),
];

class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: const Text("Уроки самопознания",
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: selfKnowledgeLessons.length,
          itemBuilder: (context, i) {
            final l = selfKnowledgeLessons[i];
            final isCompleted = AppState.completedLessons.contains(l.title);
            return GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => LessonScreen(lesson: l))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: l.color, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Text(l.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text)),
                          Text(l.description,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryDark)),
                        ],
                      ),
                    ),
                    if (isCompleted)
                      const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 5),
                    Text("+${l.xp} XP",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.purpleDeep)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LessonScreen extends StatefulWidget {
  final SelfKnowledgeLesson lesson;
  const LessonScreen({super.key, required this.lesson});
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _step = 0;
  bool _showCanvas = false;
  bool _isProcessing = false;
  final _noteController = TextEditingController();
  final List<String> _answers = [];

  late PainterController _painterController;
  final _canvasKey = GlobalKey();
  bool _isSaving = false;
  double _strokeWidth = 5.0;

  @override
  void initState() {
    super.initState();
    _painterController = PainterController();
    _painterController.background = null;
    _painterController.freeStyleStrokeWidth = _strokeWidth;
  }

  @override
  void dispose() {
    _painterController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveToProfile() async {
    setState(() => _isSaving = true);
    try {
      final size = _canvasKey.currentContext!.size!;
      final image = await _painterController.renderImage(size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        AppState.addDrawing(widget.lesson.title, bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Рисунок сохранён в профиль! 💜")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка сохранения: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);
    try {
      final size = _canvasKey.currentContext!.size!;
      final image = await _painterController.renderImage(size);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        await Gal.putImageBytes(bytes,
            name: 'drawing_${DateTime.now().millisecondsSinceEpoch}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Рисунок скачан в галерею! 📸")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка скачивания: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _nextStep() {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    _answers.add(_noteController.text);

    if (_step < widget.lesson.steps.length - 1) {
      setState(() {
        _step++;
        _noteController.clear();
      });
    } else {
      AppState.addXp(widget.lesson.xp);
      AppState.feedCat();
      AppState.completeLesson(widget.lesson.title, _answers);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Урок пройден! +${widget.lesson.xp} XP 💜")));
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: widget.lesson.color,
        elevation: 0,
        title: Text("${widget.lesson.emoji}  ${widget.lesson.title}",
            style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (_step + 1) / widget.lesson.steps.length,
                backgroundColor: Colors.white,
                color: AppColors.primary,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(widget.lesson.steps[_step]["t"]!,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text)),
                      const SizedBox(height: 20),
                      Text(widget.lesson.steps[_step]["d"]!,
                          style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.text,
                              height: 1.5)),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10)),
                        child: TextField(
                          controller: _noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "Запиши свои мысли..."),
                        ),
                      ),
                      if (widget.lesson.title == "Нарисуй своё состояние") ...[
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () =>
                              setState(() => _showCanvas = !_showCanvas),
                          child: Text(
                              _showCanvas ? "Скрыть холст" : "Открыть холст"),
                        ),
                        if (_showCanvas) ...[
                          const SizedBox(height: 20),
                          Container(
                            height: 350,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: AppColors.primary),
                            ),
                            child: RepaintBoundary(
                              key: _canvasKey,
                              child: FlutterPainter(
                                controller: _painterController,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _colorBtn(Colors.black),
                                    _colorBtn(Colors.red),
                                    _colorBtn(Colors.blue),
                                    _colorBtn(Colors.green),
                                    _colorBtn(Colors.yellow),
                                    _colorBtn(Colors.purple),
                                    IconButton(
                                      icon: const Icon(Icons.color_lens,
                                          color: AppColors.primary),
                                      onPressed: _openColorPicker,
                                      tooltip: "Все цвета",
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _toolBtn(Icons.brush, "Кисть", false),
                                    _toolBtn(Icons.cleaning_services,
                                        "Ластик", true),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: AppColors.danger),
                                      onPressed: () {
                                        _painterController.clearDrawables();
                                      },
                                      tooltip: "Очистить всё",
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text("Толщина: ",
                                        style: TextStyle(fontSize: 13)),
                                    Expanded(
                                      child: Slider(
                                        value: _strokeWidth,
                                        min: 1,
                                        max: 20,
                                        divisions: 19,
                                        label: _strokeWidth.round().toString(),
                                        onChanged: (v) {
                                          setState(
                                              () => _strokeWidth = v);
                                          _painterController
                                              .freeStyleStrokeWidth = v;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _isSaving
                                          ? null
                                          : _saveToProfile,
                                      icon: _isSaving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2))
                                          : const Icon(Icons.save, size: 18),
                                      label: const Text("В профиль"),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.mint,
                                          foregroundColor: AppColors.text),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _isSaving
                                          ? null
                                          : _saveToGallery,
                                      icon: _isSaving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2))
                                          : const Icon(Icons.download,
                                              size: 18),
                                      label: const Text("В галерею"),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.pastelBlue,
                                          foregroundColor: AppColors.text),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isProcessing ? null : _nextStep,
                child: Text(
                    _step < widget.lesson.steps.length - 1
                        ? "Дальше"
                        : "Завершить урок",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Выбери цвет"),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _painterController.freeStyleColor,
            onColorChanged: (color) {
              _painterController.freeStyleMode = FreeStyleMode.draw;
              _painterController.freeStyleColor = color;
            },
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Готово"),
          ),
        ],
      ),
    );
  }

  Widget _colorBtn(Color color) {
    return GestureDetector(
      onTap: () {
        _painterController.freeStyleMode = FreeStyleMode.draw;
        _painterController.freeStyleColor = color;
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _toolBtn(IconData icon, String tooltip, bool isEraser) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: AppColors.primary),
        onPressed: () {
          _painterController.freeStyleMode =
              isEraser ? FreeStyleMode.erase : FreeStyleMode.draw;
        },
      ),
    );
  }
}

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  bool _showForm = false;
  String _type = "Идея";
  final _text = TextEditingController();
  final List<String> _types = ["Идея", "Благодарность", "Неудача", "Успех"];

  String _emoji(String t) {
    switch (t) {
      case "Идея":
        return "💡";
      case "Благодарность":
        return "🙏";
      case "Неудача":
        return "😔";
      case "Успех":
        return "🎉";
      default:
        return "📝";
    }
  }

  Color _color(String t) {
    switch (t) {
      case "Идея":
        return AppColors.pastelYellow;
      case "Благодарность":
        return AppColors.pastelGreen;
      case "Неудача":
        return AppColors.pastelPink;
      case "Успех":
        return AppColors.pastelMint;
      default:
        return AppColors.background;
    }
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return "Сегодня";
    if (diff == 1) return "Вчера";
    if (diff < 7) return "$diff дня назад";
    return "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<DiaryEntry>> grouped = {};
    for (final e in AppState.entries) {
      final key = "${e.date.year}-${e.date.month}-${e.date.day}";
      grouped.putIfAbsent(key, () => []).add(e);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("📔  Дневник",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text)),
          const SizedBox(height: 5),
          const Text("Твои мысли, победы и уроки",
              style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppColors.primaryDark)),
          const SizedBox(height: 20),
          if (!_showForm)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mint,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () => setState(() => _showForm = true),
              child: const Text("➕  Новая запись",
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          if (_showForm) ...[
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Новая запись",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    items: _types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.all(10),
                    child: TextField(
                      controller: _text,
                      maxLines: 5,
                      decoration:
                          const InputDecoration(border: InputBorder.none),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mint),
                        onPressed: () {
                          if (_text.text.trim().isEmpty) return;
                          AppState.addEntry(DiaryEntry(
                              type: _type,
                              text: _text.text.trim(),
                              emoji: _emoji(_type)));
                          _text.clear();
                          setState(() => _showForm = false);
                        },
                        child: const Text("Сохранить"),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.background),
                        onPressed: () => setState(() => _showForm = false),
                        child: const Text("Отмена"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
          ],
          if (AppState.entries.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 30),
                child: Text("Пока нет записей. Нажми «➕ Новая запись»!",
                    style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primaryDark)),
              ),
            ),
          ...grouped.entries.map((groupEntry) {
            final dayEntries = groupEntry.value;
            final firstDate = dayEntries.first.date;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(top: 12, bottom: 8, left: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.purpleDeep,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(_dayLabel(firstDate),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                          "${dayEntries.length} ${dayEntries.length == 1 ? "запись" : "записей"}",
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryDark)),
                    ],
                  ),
                ),
                ...dayEntries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: _color(e.type),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(e.emoji,
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(e.type,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.text)),
                              const Spacer(),
                              Text(
                                  "${e.date.hour.toString().padLeft(2, '0')}:${e.date.minute.toString().padLeft(2, '0')}",
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primaryDark)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(e.text,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.text,
                                  height: 1.4)),
                        ],
                      ),
                    )),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    int days = 1;
    final dates = [
      ...AppState.moods.map((m) => m.date),
      ...AppState.entries.map((e) => e.date)
    ];
    if (dates.isNotEmpty) {
      dates.sort();
      days = DateTime.now().difference(dates.first).inDays + 1;
      if (days < 1) days = 1;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: AppColors.mint, width: 4),
              ),
              child: Center(
                  child: Text(AppState.avatar.isEmpty ? "🌸" : AppState.avatar,
                      style: const TextStyle(fontSize: 60))),
            ),
          ),
          const SizedBox(height: 15),
          Center(
              child: Text(AppState.userName.isEmpty ? "Друг" : AppState.userName,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text))),
          Center(
              child: Text(
                  AppState.age.isEmpty ? "Возраст не указан" : "${AppState.age} лет",
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.primaryDark))),
          const SizedBox(height: 25),
          Container(
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Вибрация",
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text)),
                  subtitle: const Text("Тактильный отклик",
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textLight)),
                  value: AppState.vibrationEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) async {
                    setState(() => AppState.vibrationEnabled = val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('vibrationEnabled', val);
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text("Звук (музыка в медитациях)",
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text)),
                  subtitle: const Text("Фоновая музыка при медитации",
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textLight)),
                  value: AppState.soundEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) async {
                    setState(() => AppState.soundEnabled = val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('soundEnabled', val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          if (AppState.testResults.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🧠  Мои результаты тестов",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  const SizedBox(height: 15),
                  ...AppState.testResults.map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.pastelMint,
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.testName,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text)),
                            const SizedBox(height: 4),
                            Text(r.result,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primaryDark)),
                            const SizedBox(height: 4),
                            Text(r.interpretation,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 15),
          ],
          if (AppState.savedDrawings.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🎨  Мои рисунки",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  const SizedBox(height: 15),
                  ...AppState.savedDrawings.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(d['image'],
                                  width: 60, height: 60, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(d['lesson'],
                                    style: const TextStyle(fontSize: 14))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 15),
          ],
          if (AppState.completedLessons.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("📚  Пройденные уроки",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  const SizedBox(height: 15),
                  ...AppState.completedLessons.map((l) {
                    final answers = AppState.lessonAnswers[l] ?? [];
                    return Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding:
                            const EdgeInsets.only(left: 26, bottom: 10),
                        leading: const Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                        title: Text(l,
                            style: const TextStyle(fontSize: 14)),
                        children: answers.isEmpty
                            ? [
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Text("Нет сохранённых ответов",
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.textLight)),
                                )
                              ]
                            : answers.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final ans = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Шаг ${idx + 1}: ",
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryDark)),
                                      Expanded(
                                        child: Text(
                                          ans.isEmpty ? "(пусто)" : ans,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.text),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 15),
          ],
          Container(
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text("📊  Прогресс",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(AppState.moods.length.toString(), "Отметок",
                        AppColors.purpleDeep),
                    _stat(AppState.entries.length.toString(), "Записей",
                        AppColors.purpleLight),
                    _stat(days.toString(), "Дней", AppColors.purpleMedium),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                  child: _bigButton(
                      emoji: "🎨",
                      title: "Календарь эмоций",
                      color: AppColors.pastelMint,
                      onTap: () => MainWindow.of(context)
                          ?.setCustomScreen(const EmotionMapScreen()))),
              const SizedBox(width: 12),
              Expanded(
                  child: _bigButton(
                      emoji: "🔗",
                      title: "Полезные ссылки",
                      color: AppColors.pastelBlue,
                      onTap: () => MainWindow.of(context)
                          ?.setCustomScreen(const LinksScreen()))),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            decoration: BoxDecoration(
                color: AppColors.pastelGreen,
                borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(15),
            child: const Row(
              children: [
                Text("🔒", style: TextStyle(fontSize: 22)),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        "Все данные хранятся только у тебя на устройстве.",
                        style: TextStyle(
                            fontSize: 12, color: AppColors.text))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pastelPink,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Сброс данных"),
                  content: const Text("Точно удалить ВСЕ данные?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Нет")),
                    TextButton(
                      onPressed: () async {
                        final prefs =
                            await SharedPreferences.getInstance();
                        await prefs.clear();
                        AppState.clear();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PsyApp()),
                              (r) => false);
                        }
                      },
                      child: const Text("Да"),
                    )
                  ],
                ),
              );
            },
            child: const Text("🗑  Сбросить все данные",
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _stat(String c, String l, Color color) => Column(
        children: [
          Text(c,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(l,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.primaryDark)),
        ],
      );

  Widget _bigButton({
    required String emoji,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 6),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text)),
            ],
          ),
        ),
      );
}

class EmotionMapScreen extends StatefulWidget {
  const EmotionMapScreen({super.key});
  @override
  State<EmotionMapScreen> createState() => _EmotionMapScreenState();
}

class _EmotionMapScreenState extends State<EmotionMapScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final List<String> _monthNames = [
    "Январь",
    "Февраль",
    "Март",
    "Апрель",
    "Май",
    "Июнь",
    "Июль",
    "Август",
    "Сентябрь",
    "Октябрь",
    "Ноябрь",
    "Декабрь"
  ];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final nextMonth = DateTime(_month.year, _month.month + 1, 1);
    final daysInMonth = nextMonth.subtract(const Duration(days: 1)).day;
    final startOffset = (firstDay.weekday - 1) % 7;
    int totalMarks = 0;
    final moodCounts = <String, int>{};
    final cells = <Widget>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox(width: 44, height: 44));
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_month.year, _month.month, day);
      final matches = AppState.moods
          .where((m) =>
              m.date.year == date.year &&
              m.date.month == date.month &&
              m.date.day == date.day)
          .toList();
      Color color = const Color(0xFFF0F0F0);
      String emojis = "";
      if (date.isAfter(DateTime.now())) {
        color = const Color(0xFFFAFAFA);
      } else if (matches.isNotEmpty) {
        totalMarks += matches.length;
        for (var m in matches) {
          moodCounts[m.mood] = (moodCounts[m.mood] ?? 0) + 1;
          switch (m.mood) {
            case "Злость":
              emojis += "😡";
              break;
            case "Грусть":
              emojis += "😢";
              break;
            case "Тревога":
              emojis += "😰";
              break;
            case "Апатия":
              emojis += "😐";
              break;
            case "Нейтрально":
              emojis += "🙂";
              break;
            case "Радость":
              emojis += "😊";
              break;
            case "Счастье":
              emojis += "😍";
              break;
          }
        }
        if (matches.length == 1) {
          color = AppColors.pastelYellow;
        } else if (matches.length == 2) {
          color = AppColors.pastelGreen;
        } else {
          color = AppColors.pastelPink;
        }
      }
      cells.add(Container(
        margin: const EdgeInsets.all(2),
        decoration:
            BoxDecoration(color: color, shape: BoxShape.circle),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
                top: 3,
                child: Text("$day",
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text))),
            if (emojis.isNotEmpty)
              Positioned(
                bottom: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                      emojis.length > 3
                          ? emojis.substring(0, 3)
                          : emojis,
                      style: const TextStyle(fontSize: 8)),
                ),
              ),
          ],
        ),
      ));
    }
    String summary = "За ${_monthNames[_month.month - 1]} нет отметок.";
    if (totalMarks > 0) {
      final top = moodCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      summary =
          "За ${_monthNames[_month.month - 1]} ты отмечал(а) настроение $totalMarks раз.\nЧаще всего — «${top.first.key}» (${top.first.value} раз).\n💜";
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text("🎨 Календарь эмоций",
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() {
                            _month =
                                DateTime(_month.year, _month.month - 1, 1);
                          })),
                  Text("${_monthNames[_month.month - 1]} ${_month.year}",
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () {
                        final nxt =
                            DateTime(_month.year, _month.month + 1, 1);
                        if (!nxt.isAfter(DateTime.now())) {
                          setState(() => _month = nxt);
                        }
                      }),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text("Пн",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark)),
                        Text("Вт",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark)),
                        Text("Ср",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark)),
                        Text("Чт",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark)),
                        Text("Пт",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark)),
                        Text("Сб",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark)),
                        Text("Вс",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: cells),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                    color: AppColors.pastelYellow,
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(15),
                child: Text(summary,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.text)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeatMapScreen extends StatelessWidget {
  const HeatMapScreen({super.key});

  Color _colorForCount(int count) {
    if (count == 0) return const Color(0xFFE5E7EB);
    if (count == 1) return const Color(0xFFD1FAE5);
    if (count == 2) return const Color(0xFFA7F3D0);
    if (count == 3) return const Color(0xFF6EE7B7);
    if (count <= 5) return const Color(0xFF34D399);
    return const Color(0xFF059669);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final Map<String, int> counts = {};
    for (final m in AppState.moods) {
      final key = "${m.date.year}-${m.date.month}-${m.date.day}";
      counts[key] = (counts[key] ?? 0) + 1;
    }
    for (final e in AppState.entries) {
      final key = "${e.date.year}-${e.date.month}-${e.date.day}";
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final months = <DateTime>[];
    for (int i = 0; i <= 2; i++) {
      months.add(DateTime(today.year, today.month - i, 1));
    }
    final monthNames = [
      "Январь",
      "Февраль",
      "Март",
      "Апрель",
      "Май",
      "Июнь",
      "Июль",
      "Август",
      "Сентябрь",
      "Октябрь",
      "Ноябрь",
      "Декабрь"
    ];
    final weekDays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];
    final totalMarks = counts.values.fold<int>(0, (a, b) => a + b);
    final activeDays = counts.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text("🔥  Тепловая карта",
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Активность за 3 месяца",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              const SizedBox(height: 5),
              const Text(
                  "Каждая клетка — день. Чем темнее, тем больше отметок.",
                  style: TextStyle(
                      fontSize: 13, color: AppColors.primaryDark)),
              const SizedBox(height: 20),
              ...months.map((month) {
                final firstDay = DateTime(month.year, month.month, 1);
                final nextMonth =
                    DateTime(month.year, month.month + 1, 1);
                final daysInMonth =
                    nextMonth.subtract(const Duration(days: 1)).day;
                final startOffset = (firstDay.weekday - 1) % 7;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${monthNames[month.month - 1]} ${month.year}",
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: weekDays
                            .map((d) => Text(d,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark)))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          ...List.generate(
                              startOffset, (_) => const SizedBox()),
                          ...List.generate(daysInMonth, (i) {
                            final day = i + 1;
                            final date = DateTime(
                                month.year, month.month, day);
                            final key =
                                "${date.year}-${date.month}-${date.day}";
                            final count = counts[key] ?? 0;
                            final isFuture = date.isAfter(today);
                            return Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                  color: isFuture
                                      ? const Color(0xFFFAFAFA)
                                      : _colorForCount(count),
                                  borderRadius:
                                      BorderRadius.circular(4)),
                              child: Center(
                                  child: Text("$day",
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: isFuture
                                              ? Colors.grey.shade300
                                              : Colors.black54))),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              Row(
                children: [
                  const Text("Меньше",
                      style: TextStyle(
                          fontSize: 11, color: AppColors.primaryDark)),
                  const SizedBox(width: 8),
                  ...[0, 1, 2, 3, 5, 7].map((c) => Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                            color: _colorForCount(c),
                            borderRadius: BorderRadius.circular(3)),
                      )),
                  const SizedBox(width: 8),
                  const Text("Больше",
                      style: TextStyle(
                          fontSize: 11, color: AppColors.primaryDark)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                    color: AppColors.pastelYellow,
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("📊  Твоя статистика",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat(totalMarks.toString(), "Отметок",
                            AppColors.purpleDeep),
                        _stat(activeDays.toString(), "Активных дней",
                            AppColors.purpleMedium),
                        _stat(
                            "${(activeDays / 90 * 100).toStringAsFixed(0)}%",
                            "Регулярность",
                            AppColors.purpleLight),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String c, String l, Color color) => Column(
        children: [
          Text(c,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(l,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.primaryDark)),
        ],
      );
}

class LinksScreen extends StatelessWidget {
  const LinksScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text("🔗 Полезные ссылки",
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _link("📞", "Телефон доверия",
                  "8 801 100 16 11 — круглосуточно, анонимно",
                  AppColors.pastelPink,
                  () => _launchUrl("tel:88011001611")),
              _link("🌐", "psy.help",
                  "Белорусский портал психологической помощи",
                  AppColors.pastelGreen,
                  () => _launchUrl("https://psy.help")),
              _link("🧘", "Insight Timer",
                  "Бесплатные медитации на русском",
                  AppColors.pastelMint,
                  () => _launchUrl("https://insighttimer.com/ru")),
              _link("💬", "pomogut.by", "Помощь подросткам и молодёжи",
                  AppColors.pastelBlue,
                  () => _launchUrl("https://pomogut.by")),
              _link("📱", "Медитации на YouTube",
                  "Каналы с бесплатными практиками",
                  AppColors.pastelPeach,
                  () => _launchUrl("https://youtube.com")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _link(String icon, String title, String desc, Color bg,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryDark)),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new,
                  size: 18, color: AppColors.text),
            ],
          ),
        ),
      );
}

class TippScreen extends StatefulWidget {
  const TippScreen({super.key});
  @override
  State<TippScreen> createState() => _TippScreenState();
}

class _TippScreenState extends State<TippScreen> {
  int _step = 0, _timerSeconds = 0;
  Timer? _timer;
  final List<Map<String, String>> _steps = [
    {
      "title": "Температура",
      "desc": "Намочи лицо ледяной водой на 30 секунд.",
      "btn": "Я сделал(а)"
    },
    {
      "title": "Движение",
      "desc": "Сделай 20 быстрых приседаний.",
      "btn": "Сделано"
    },
    {
      "title": "Дыхание",
      "desc": "Вдох 4, задержка 7, выдох 8.",
      "btn": "Начать таймер"
    }
  ];

  void _nextStep() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      AppState.addXp(20);
      AppState.feedCat();
      if (mounted) {
        MainWindow.of(context)?.setCustomScreen(null);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ты справился(ась)! 💜")));
      }
    }
  }

  void _startTimer() {
    setState(() => _timerSeconds = 4);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_timerSeconds > 0) {
          _timerSeconds--;
        } else {
          _timer?.cancel();
          _nextStep();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _steps[_step];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.text)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                  value: (_step + 1) / _steps.length,
                  backgroundColor: Colors.white,
                  color: AppColors.primary),
              const SizedBox(height: 40),
              Text("Шаг ${_step + 1}: ${current['title']}",
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text)),
              const SizedBox(height: 20),
              Text(current['desc']!,
                  style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.textLight,
                      height: 1.5)),
              const Spacer(),
              if (_timerSeconds > 0)
                Center(
                    child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 150 + (_timerSeconds * 10),
                  height: 150 + (_timerSeconds * 10),
                  decoration: BoxDecoration(
                      color: AppColors.pastelBlue.withValues(alpha: 0.5),
                      shape: BoxShape.circle),
                  child: Center(
                      child: Text("$_timerSeconds",
                          style: const TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary))),
                )),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _timerSeconds > 0
                    ? null
                    : (_step == 2 ? _startTimer : _nextStep),
                child: Text(current['btn']!,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GroundingScreen extends StatefulWidget {
  const GroundingScreen({super.key});
  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingScreenState extends State<GroundingScreen> {
  int _step = 0;
  final List<String> _steps = [
    "Найди 5 синих предметов вокруг",
    "Почувствуй 4 твердые поверхности",
    "Услышь 3 звука",
    "Почувствуй 2 запаха",
    "Почувствуй 1 вкус (сделай глоток воды)"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.text)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.remove_red_eye,
                  size: 60, color: AppColors.primary),
              const SizedBox(height: 30),
              Text(_steps[_step],
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text),
                  textAlign: TextAlign.center),
              const SizedBox(height: 50),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  if (_step < _steps.length - 1) {
                    setState(() => _step++);
                  } else {
                    AppState.addXp(30);
                    AppState.feedCat();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Ты здесь и сейчас. Котик доволен! 💜")));
                      MainWindow.of(context)?.setCustomScreen(null);
                    }
                  }
                },
                child: Text(
                    _step == _steps.length - 1 ? "Завершить" : "Сделано",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HapticGroundingScreen extends StatefulWidget {
  const HapticGroundingScreen({super.key});
  @override
  State<HapticGroundingScreen> createState() =>
      _HapticGroundingScreenState();
}

class _HapticGroundingScreenState extends State<HapticGroundingScreen> {
  int _clicks = 0;

  void _vibrate() {
    if (AppState.vibrationEnabled) {
      Vibration.vibrate(duration: 100);
    }
    setState(() => _clicks++);
    if (_clicks >= 10) {
      AppState.addXp(20);
      AppState.feedCat();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Синхронизация завершена! Котик сыт 💜")));
        MainWindow.of(context)?.setCustomScreen(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.text)),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Нажимай в такт вибрации",
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 50),
              GestureDetector(
                onTap: _vibrate,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.pastelPink,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 20)
                    ],
                  ),
                  child: Center(
                      child: Text("$_clicks / 10",
                          style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThoughtCourtScreen extends StatefulWidget {
  const ThoughtCourtScreen({super.key});
  @override
  State<ThoughtCourtScreen> createState() => _ThoughtCourtScreenState();
}

class _ThoughtCourtScreenState extends State<ThoughtCourtScreen> {
  final _thoughtCtrl = TextEditingController(),
      _proCtrl = TextEditingController(),
      _contraCtrl = TextEditingController();
  bool _verdictReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("⚖️ Суд над мыслью",
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _inputBlock("Мысль (Обвинение)", _thoughtCtrl,
                  AppColors.pastelYellow),
              _inputBlock("Факты ЗА (Прокурор)", _proCtrl,
                  AppColors.pastelPink),
              _inputBlock("Факты ПРОТИВ (Адвокат)", _contraCtrl,
                  AppColors.pastelGreen),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () {
                  if (_thoughtCtrl.text.isNotEmpty &&
                      _proCtrl.text.isNotEmpty &&
                      _contraCtrl.text.isNotEmpty) {
                    setState(() => _verdictReady = true);
                  }
                },
                child: const Text("Вынести вердикт",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              if (_verdictReady) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(15)),
                  child: const Text(
                      "Сбалансированный взгляд: у твоей тревоги есть и плюсы, и минусы. Это не конец света, а просто ситуация, которую можно решить.",
                      style: TextStyle(
                          fontSize: 16, color: AppColors.text)),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputBlock(
          String label, TextEditingController ctrl, Color color) =>
      Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                    border: InputBorder.none, hintText: "...")),
          ],
        ),
      );
}

class WorryBoxScreen extends StatefulWidget {
  const WorryBoxScreen({super.key});
  @override
  State<WorryBoxScreen> createState() => _WorryBoxScreenState();
}

class _WorryBoxScreenState extends State<WorryBoxScreen> {
  final _controller = TextEditingController();
  final List<String> _box = [];

  void _addWorry() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _box.insert(0, _controller.text.trim());
      _controller.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Мысль заперта до вечера 💜")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("📦 Сейф тревог",
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              const Text("Выгрузи мысль. Мы вернемся к ней в 18:30.",
                  style: TextStyle(
                      fontSize: 16, color: AppColors.textLight)),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                maxLines: 3,
                decoration: InputDecoration(
                    hintText: "О чем ты беспокоишься?",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _addWorry,
                child: const Text("Запереть в сейф"),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView.builder(
                  itemCount: _box.length,
                  itemBuilder: (context, i) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, color: Colors.grey),
                        const SizedBox(width: 15),
                        Expanded(child: Text(_box[i])),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UnsentLetterScreen extends StatefulWidget {
  const UnsentLetterScreen({super.key});
  @override
  State<UnsentLetterScreen> createState() => _UnsentLetterScreenState();
}

class _UnsentLetterScreenState extends State<UnsentLetterScreen> {
  final _controller = TextEditingController();
  bool _burned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("✍️ Неотправленное",
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: _burned
              ? const Center(
                  child: Text("Письмо сожжено. Стало легче? 💜",
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)))
              : Column(
                  children: [
                    const Text(
                        "Напиши всё, что накипело. Никто это не прочитает.",
                        style: TextStyle(
                            fontSize: 16, color: AppColors.textLight)),
                    const SizedBox(height: 20),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () {
                        setState(() => _burned = true);
                        AppState.addXp(10);
                      },
                      child: const Text("Сжечь",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class AiTherapistScreen extends StatefulWidget {
  const AiTherapistScreen({super.key});
  @override
  State<AiTherapistScreen> createState() => _AiTherapistScreenState();
}

class _AiTherapistScreenState extends State<AiTherapistScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [
    ChatMessage(
        role: 'assistant',
        content: 'Привет 💜 Я здесь, чтобы выслушать. Что случилось?')
  ];
  bool _loading = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    if (AppState.apiKey.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(role: 'user', content: text));
        _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Извини, ключ Groq не введён.'));
      });
      _controller.clear();
      return;
    }
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
    });
    _controller.clear();
    _scrollDown();
    try {
      final ai = AiService(apiKey: AppState.apiKey);
      final reply = await ai.chat(_messages);
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: reply));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
              ChatMessage(role: 'assistant', content: 'Ошибка: $e'));
          _loading = false;
        });
      }
    }
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Row(
          children: [
            Text("🤖", style: TextStyle(fontSize: 20)),
            SizedBox(width: 10),
            Text("ИИ-Психолог",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  final isUser = m.role == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                          color: isUser ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: Text(m.content,
                          style: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : AppColors.text)),
                    ),
                  );
                },
              ),
            ),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator()),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                            hintText: 'Напиши, что чувствуешь...'),
                        onSubmitted: (_) => _send(),
                      )),
                      IconButton(
                          icon: const Icon(Icons.send,
                              color: AppColors.primary),
                          onPressed: _loading ? null : _send)
                    ],
                  ),
                  const Text(
                      "⚠️ Бот не заменит квалифицированную психологическую помощь.",
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DistortionDetectorScreen extends StatefulWidget {
  const DistortionDetectorScreen({super.key});
  @override
  State<DistortionDetectorScreen> createState() =>
      _DistortionDetectorScreenState();
}

class _DistortionDetectorScreenState extends State<DistortionDetectorScreen> {
  final _controller = TextEditingController();
  String _result = "";
  bool _loading = false;

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (AppState.apiKey.isEmpty) {
      setState(() => _result = '⚠ Ключ Groq не введён.');
      return;
    }
    setState(() {
      _loading = true;
      _result = "";
    });
    const detectorPrompt = '''Ты — детектор когнитивных искажений. Анализируй мысль человека и находи искажения. ВОЗМОЖНЫЕ ИСКАЖЕНИЯ: Катастрофизация, Чёрно-белое мышление, Чтение мыслей, Обобщение, Обесценивание, Долженствование, Персонализация. ФОРМАТ ОТВЕТА: 🎯 Искажение, 💭 Что происходит, 🔄 А что если наоборот, 💜 Поддержка. Отвечай коротко.''';
    try {
      final ai = AiService(apiKey: AppState.apiKey, prompt: detectorPrompt);
      final reply =
          await ai.chat([ChatMessage(role: 'user', content: text)]);
      if (mounted) {
        setState(() {
          _result = reply;
          _loading = false;
          AppState.addXp(10);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = 'Ошибка: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text("🕵️ Детектор искажений",
            style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                  "Напиши свою мысль. Я найду когнитивное искажение и предложу контраргумент.",
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                      height: 1.4)),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(14),
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText:
                          "Например: «Я провалил экзамен, значит я ничтожество»"),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _loading ? null : _analyze,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("🧠 Найти искажение",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
              ),
              if (_result.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.all(18),
                  child: Text(_result,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.text,
                          height: 1.5)),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class RolePlayScreen extends StatefulWidget {
  const RolePlayScreen({super.key});
  @override
  State<RolePlayScreen> createState() => _RolePlayScreenState();
}

class _RolePlayScreenState extends State<RolePlayScreen> {
  String? _selectedRole;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  final Map<String, String> _prompts = {
    "Мама":
        "Ты — заботливая, но тревожная мама. Ты хочешь лучшего для ребёнка, но часто давишь.",
    "Друг": "Ты — лучший друг. Ты поддерживаешь, но можешь быть резким.",
    "Учитель": "Ты — строгий учитель. Ты требуешь дисциплины.",
    "Босс": "Ты — требовательный босс. Ты ценишь результат."
  };

  void _startRole(String role) {
    setState(() {
      _selectedRole = role;
      _messages.clear();
      _messages
          .add(ChatMessage(role: 'assistant', content: '🎭 Я — $role. Начинай разговор.'));
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading || _selectedRole == null) return;
    if (AppState.apiKey.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(role: 'user', content: text));
        _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Извини, ключ Groq не введён.'));
      });
      _controller.clear();
      return;
    }
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
    });
    _controller.clear();
    _scrollDown();
    try {
      final ai =
          AiService(apiKey: AppState.apiKey, prompt: _prompts[_selectedRole]);
      final reply = await ai.chat(_messages);
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: reply));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
              ChatMessage(role: 'assistant', content: 'Ошибка: $e'));
          _loading = false;
        });
      }
    }
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
            _selectedRole == null
                ? "🎭 Примерка ролей"
                : "🎭 $_selectedRole",
            style: const TextStyle(color: Colors.white)),
      ),
      body:
          SafeArea(child: _selectedRole == null ? _roleList() : _chatView()),
    );
  }

  Widget _roleList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Выбери роль, чтобы потренироваться",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ..._prompts.keys.map((r) => GestureDetector(
                onTap: () => _startRole(r),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(r,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                ),
              )),
        ],
      ),
    );
  }

  Widget _chatView() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[i];
              final isUser = m.role == 'user';
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78),
                  decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(m.content,
                      style: TextStyle(
                          color: isUser ? Colors.white : AppColors.text)),
                ),
              );
            },
          ),
        ),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator()),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                  child: TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Ответь...'),
                onSubmitted: (_) => _send(),
              )),
              IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _loading ? null : _send)
            ],
          ),
        ),
      ],
    );
  }
}

class ConversationTrainerScreen extends StatefulWidget {
  const ConversationTrainerScreen({super.key});
  @override
  State<ConversationTrainerScreen> createState() =>
      _ConversationTrainerScreenState();
}

class _ConversationTrainerScreenState
    extends State<ConversationTrainerScreen> {
  final _scenarioController = TextEditingController();
  final _replyController = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _training = false, _loading = false;

  void _startTraining() {
    final scenario = _scenarioController.text.trim();
    if (scenario.isEmpty) return;
    setState(() {
      _training = true;
      _messages.clear();
      _messages.add(ChatMessage(
          role: 'assistant',
          content:
              '🎭 Начинаем. Ситуация: $scenario\n\nЯ — твой собеседник. Начинай.'));
    });
  }

  Future<void> _send() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _loading) return;
    if (AppState.apiKey.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(role: 'user', content: text));
        _messages.add(ChatMessage(
            role: 'assistant', content: '⚠ Ключ Groq не введён.'));
      });
      _replyController.clear();
      return;
    }
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
    });
    _replyController.clear();
    _scrollDown();
    final prompt =
        '''Ты — тренажёр сложных разговоров. Пользователь описал ситуацию: "${_scenarioController.text.trim()}". Ты играешь роль собеседника. Будь реалистичен. Отвечай коротко — 2-3 предложения.''';
    try {
      final ai = AiService(apiKey: AppState.apiKey, prompt: prompt);
      final reply = await ai.chat(_messages);
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: reply));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
              ChatMessage(role: 'assistant', content: 'Ошибка: $e'));
          _loading = false;
        });
      }
    }
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text("💬 Тренажёр разговоров",
            style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(child: _training ? _chatView() : _setupView()),
    );
  }

  Widget _setupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Опиши ситуацию",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _scenarioController,
              maxLines: 4,
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Например: «Хочу попросить повышение»"),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
            ),
            onPressed: _startTraining,
            child: const Text("🎭 Начать тренировку"),
          ),
        ],
      ),
    );
  }

  Widget _chatView() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[i];
              final isUser = m.role == 'user';
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78),
                  decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(m.content,
                      style: TextStyle(
                          color: isUser ? Colors.white : AppColors.text)),
                ),
              );
            },
          ),
        ),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator()),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                  child: TextField(
                controller: _replyController,
                decoration:
                    const InputDecoration(hintText: 'Твой ответ...'),
                onSubmitted: (_) => _send(),
              )),
              IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _loading ? null : _send)
            ],
          ),
        ),
      ],
    );
  }
}

class TestsListScreen extends StatelessWidget {
  const TestsListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: const Text("Психологические тесты",
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _testTile(context, "💪", "Насколько ты уверен в себе?",
                  "20 вопросов", AppColors.pastelBlue, "confidence"),
              _testTile(context, "😊", "Тест «Характер»", "19 вопросов",
                  AppColors.pastelGreen, "character"),
              _testTile(context, "🗣️", "Тип в общении",
                  "9 высказываний", AppColors.pastelPink, "communication"),
              _testTile(context, "🤝", "Коммуникабельность",
                  "40 вопросов", AppColors.pastelMint, "sociability"),
              _testTile(context, "⚖️", "Социальная желательность",
                  "20 вопросов", AppColors.pastelYellow, "social_desirability"),
              _testTile(context, "🦚", "Нарцисс",
                  "Определи уровень нарциссизма",
                  AppColors.pastelPeach, "narcissist"),
              _testTile(context, "😔", "Мазохист",
                  "Склонность к самопожертвованию",
                  AppColors.pastelPink, "masochist"),
              _testTile(context, "🔥", "Уровень стресса",
                  "Насколько ты напряжен(а)?",
                  AppColors.pastelYellow, "stress"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _testTile(BuildContext context, String emoji, String title,
          String desc, Color color, String testType) =>
      GestureDetector(
        onTap: () => MainWindow.of(context)
            ?.setCustomScreen(TestScreen(testType: testType)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryDark)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 18, color: AppColors.text),
            ],
          ),
        ),
      );
}

class TestScreen extends StatefulWidget {
  final String testType;
  const TestScreen({super.key, required this.testType});
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  int _current = 0, _score = 0;
  bool _started = false, _finished = false;
  String _resultText = "", _interpretation = "";

  late final Map<String, Map<String, dynamic>> _tests = {
    "confidence": {
      "name": "Тест на уверенность",
      "instruction":
          "Этот тест поможет понять, насколько ты уверен(а) в себе. Отвечай честно, не задумываясь слишком долго. Здесь нет правильных или неправильных ответов.",
      "questions": [
        {
          "q": "Ты узнал, что приятель говорит о тебе плохо. Ты:",
          "a": [
            {"t": "Поищешь удобный случай выяснить отношения", "s": 3},
            {"t": "Перестанешь общаться и будешь избегать встреч", "s": 0}
          ]
        },
        {
          "q": "Когда ты входишь в автобус, тебя грубо толкают. Ты:",
          "a": [
            {"t": "Громко протестуешь", "s": 3},
            {"t": "Молча пытаешься пробраться вперёд", "s": 0},
            {"t": "Ждёшь, когда войдут все", "s": 1}
          ]
        },
        {
          "q": "Одноклассник отстаивает противоположную точку зрения. Ты:",
          "a": [
            {"t": "Не высказываешь свою точку зрения", "s": 0},
            {"t": "Отстаиваешь свою, пытаясь доказать правоту", "s": 4}
          ]
        },
        {
          "q":
              "Ты опоздал на школьный вечер. Все места заняты, кроме первого ряда. Ты:",
          "a": [
            {"t": "Стоишь у двери и ругаешь себя", "s": 0},
            {"t": "Без колебаний идёшь в первый ряд", "s": 5},
            {"t": "Долго решаешь, но потом проходишь", "s": 1}
          ]
        },
        {
          "q":
              "Согласен ли ты, что одноклассники часто используют тебя в своих интересах?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 4}
          ]
        },
        {
          "q": "Трудно ли тебе вступить в разговор с незнакомыми людьми?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 4}
          ]
        },
        {
          "q": "Ты купил бракованную вещь. Легко ли тебе вернуть покупку?",
          "a": [
            {"t": "Нет", "s": 0},
            {"t": "Да", "s": 5}
          ]
        },
        {
          "q": "Можешь ли ты сказать, что одноклассники более уверены в себе, чем ты?",
          "a": [
            {"t": "Нет", "s": 4},
            {"t": "Да", "s": 0}
          ]
        },
        {
          "q":
              "Друзья требуют от тебя услугу, чреватую неприятностями. Легко ли тебе отказаться?",
          "a": [
            {"t": "Нет", "s": 0},
            {"t": "Да", "s": 5}
          ]
        },
        {
          "q": "Есть возможность поговорить с известным человеком. Ты:",
          "a": [
            {"t": "Используешь эту возможность", "s": 4},
            {"t": "Не используешь", "s": 0}
          ]
        },
        {
          "q": "Учитель поручает тебе позвонить в учреждение. Ты:",
          "a": [
            {"t": "Под любым предлогом отказываешься", "s": 0},
            {"t": "Звонишь без колебаний", "s": 5},
            {"t": "Собираешься с духом и звонишь", "s": 1}
          ]
        },
        {
          "q": "Тебе поставили незаслуженно низкую оценку. Ты:",
          "a": [
            {"t": "Молча переживаешь", "s": 0},
            {"t": "Споришь с учителем", "s": 2}
          ]
        },
        {
          "q": "Ты не понимаешь объяснений учителя. Ты:",
          "a": [
            {"t": "Не будешь задавать вопросов", "s": 0},
            {"t": "Спокойно попросишь объяснить ещё раз", "s": 5},
            {"t": "Задашь вопрос после уроков", "s": 2}
          ]
        },
        {
          "q": "В кинотеатре соседи громко разговаривают. Ты:",
          "a": [
            {"t": "Терпишь, а потом ругаешься", "s": 0},
            {"t": "Просишь перестать разговаривать", "s": 5},
            {"t": "Молча терпишь", "s": 1}
          ]
        },
        {
          "q": "Кто-то пытается пролезть перед тобой в очереди. Ты:",
          "a": [
            {"t": "Глотаешь обиду и молчишь", "s": 0},
            {"t": "Даёшь отпор", "s": 4}
          ]
        },
        {
          "q":
              "Легко ли тебе вступить в разговор с человеком противоположного пола, который очень нравится?",
          "a": [
            {"t": "Очень трудно", "s": 0},
            {"t": "Легко", "s": 5},
            {"t": "Очень трудно начать, потом легче", "s": 2}
          ]
        },
        {
          "q": "Ты идёшь на рынок. Легко ли тебе торговаться?",
          "a": [
            {"t": "Да", "s": 3},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Волнуешься ли ты, когда нужно выступить перед классом?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 4}
          ]
        },
        {
          "q": "Тебя хвалят перед классом. Ты:",
          "a": [
            {"t": "Не знаешь, что сказать", "s": 0},
            {"t": "Благодаришь за похвалу", "s": 4},
            {"t": "Спокойно воспринимаешь благодарность", "s": 1}
          ]
        },
        {
          "q": "При хорошем знании предмета ты хотел бы сдавать:",
          "a": [
            {"t": "Устный экзамен", "s": 3},
            {"t": "Письменный экзамен", "s": 0},
            {"t": "Всё равно", "s": 5}
          ]
        },
      ],
    },
    "character": {
      "name": "Тест «Характер»",
      "instruction":
          "Ответь «Да» или «Нет» на утверждения. Не думай слишком долго. Первый ответ — самый честный.",
      "questions": [
        {
          "q":
              "Считаете ли вы, что у многих ваших знакомых плохой характер?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Раздражают ли вас повседневные мелкие обязанности?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Верите ли вы, что ваши друзья преданы вам?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Вам неприятно, когда незнакомый человек на улице говорит вам «ты»?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Способны ли вы ударить собаку или кошку?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Часто ли вы принимаете лекарство?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Вам надоедает ходить в один и тот же магазин за продуктами?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Тяготят ли вас общественные обязанности?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Способны ли вы ждать опаздывающего более пяти минут?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Способны ли вы ждать телефонный звонок, не проявляя беспокойства?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Часто ли вам приходит мысль о вашей невезучести?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Часто ли меняется ваша фигура?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Можете ли вы с улыбкой воспринимать подшучивание друзей?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Нравится ли вам жизнь вашей семьи?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Злопамятны ли вы?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Раздражают ли вас изменения в природе?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Случается ли вам с утра быть в плохом настроении?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Раздражает ли вас современная живопись, музыка?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Надоедает ли вам присутствие в доме чужих людей?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
      ],
    },
    "communication": {
      "name": "Тип в общении",
      "instruction":
          "Оцени каждое утверждение от 0 до 4. 0 — совсем не про тебя, 4 — точно про тебя.",
      "questions": [
        {
          "q": "Я легко сближаюсь с людьми.",
          "a": [
            {"t": "0", "s": 0},
            {"t": "1", "s": 1},
            {"t": "2", "s": 2},
            {"t": "3", "s": 3},
            {"t": "4", "s": 4}
          ]
        },
        {
          "q":
              "У меня много знакомых, с которыми я охотно встречаюсь.",
          "a": [
            {"t": "0", "s": 0},
            {"t": "1", "s": 1},
            {"t": "2", "s": 2},
            {"t": "3", "s": 3},
            {"t": "4", "s": 4}
          ]
        },
        {
          "q": "Я разговорчивый человек.",
          "a": [
            {"t": "0", "s": 0},
            {"t": "1", "s": 1},
            {"t": "2", "s": 2},
            {"t": "3", "s": 3},
            {"t": "4", "s": 4}
          ]
        },
        {
          "q": "Я непринуждённо чувствую себя с незнакомыми людьми.",
          "a": [
            {"t": "0", "s": 0},
            {"t": "1", "s": 1},
            {"t": "2", "s": 2},
            {"t": "3", "s": 3},
            {"t": "4", "s": 4}
          ]
        },
        {
          "q":
              "Мне стало бы неприятно, если бы надолго исчезла возможность общения.",
          "a": [
            {"t": "0", "s": 0},
            {"t": "1", "s": 1},
            {"t": "2", "s": 2},
            {"t": "3", "s": 3},
            {"t": "4", "s": 4}
          ]
        },
        {
          "q":
              "Когда мне надо что-то узнать, я предпочитаю спросить, а не копаться в книгах.",
          "a": [
            {"t": "0", "s": 0},
            {"t": "1", "s": 1},
            {"t": "2", "s": 2},
            {"t": "3", "s": 3},
            {"t": "4", "s": 4}
          ]
        },
        {
          "q": "Мне удаётся оживить скучную компанию.",
          "a": [
            {"t": "0", "s": 0},
            {"t": "1", "s": 1},
            {"t": "2", "s": 2},
            {"t": "3", "s": 3},
            {"t": "4", "s": 4}
          ]
        },
        {
          "q": "Я говорю быстро.",
          "a": [
            {"t": "0", "s": 0},
            {"t": "1", "s": 1},
            {"t": "2", "s": 2},
            {"t": "3", "s": 3},
            {"t": "4", "s": 4}
          ]
        },
        {
          "q":
              "Когда я надолго оторван от людей, мне очень хочется поговорить с кем-нибудь.",
          "a": [
            {"t": "0", "s": 0},
            {"t": "1", "s": 1},
            {"t": "2", "s": 2},
            {"t": "3", "s": 3},
            {"t": "4", "s": 4}
          ]
        },
      ],
    },
    "sociability": {
      "name": "Коммуникабельность",
      "instruction":
          "Ответь «Да» или «Нет». Этот тест покажет, насколько легко ты находишь общий язык с людьми.",
      "questions": [
        {
          "q": "Много ли у вас друзей, с которыми постоянно общаетесь?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Часто ли вам удаётся склонить большинство товарищей к принятию вашего мнения?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Долго ли вас беспокоит чувство обиды, причинённой кем-то из товарищей?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Всегда ли вам трудно ориентироваться в критической ситуации?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Есть ли у вас стремление к установлению новых знакомств?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Нравится ли вам заниматься общественной работой?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Верно ли, что вам приятнее проводить время с книгами, чем с людьми?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Легко ли вы отступаете от намерений при помехах?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Легко ли вы устанавливаете контакты с людьми старше вас?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Любите ли вы организовывать развлечения с товарищами?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Трудно ли вам включаться в новые компании?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Часто ли вы откладываете дела на другие дни?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Легко ли вам устанавливать контакты с незнакомыми?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Стремитесь ли вы, чтобы товарищи действовали по-вашему?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Трудно ли вы осваиваетесь в новом коллективе?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Верно ли, что у вас не бывает конфликтов из-за невыполнения обещаний?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Стремитесь ли вы познакомиться с новым человеком?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Часто ли вы принимаете инициативу в важных делах?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Раздражают ли вас окружающие, хочется побыть одному?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Правда ли, что вы плохо ориентируетесь в незнакомой обстановке?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Нравится ли вам постоянно находиться среди людей?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Возникает ли раздражение, если не удаётся закончить начатое?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Испытываете ли стеснение, проявляя инициативу в знакомстве?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Правда ли, что вы утомляетесь от частого общения?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Любите ли вы участвовать в коллективных играх?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Часто ли проявляете инициативу в решении вопросов товарищей?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Чувствуете ли неуверенность среди малознакомых?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Верно ли, что вы редко стремитесь доказать свою правоту?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Легко ли вам внести оживление в малознакомую компанию?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Принимаете ли участие в общественной работе класса?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Стремитесь ли ограничить круг знакомых небольшим количеством?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Верно ли, что вы не стремитесь отстаивать своё мнение, если оно не принято?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Чувствуете ли непринуждённость в незнакомой компании?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Охотно ли приступаете к организации мероприятий?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Правда ли, что вы не чувствуете уверенности, говоря большой группе?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Часто ли опаздываете на встречи?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Верно ли, что у вас много друзей?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Часто ли оказываетесь в центре внимания?",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Часто ли смущаетесь при общении с малознакомыми?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Правда ли, что вы не уверенно чувствуете себя в большой группе?",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
      ],
    },
    "social_desirability": {
      "name": "Социальная желательность",
      "instruction":
          "Отвечай «Да» или «Нет». Этот тест показывает, насколько ты склонен(на) соответствовать ожиданиям других.",
      "questions": [
        {
          "q":
              "Я внимательно читаю каждую книгу, прежде чем вернуть её в библиотеку.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Я не испытываю колебаний, когда кому-нибудь нужно помочь в беде.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я всегда внимательно слежу за тем, как я одет.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Дома я веду себя за столом так же, как и в столовой.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я никогда ни к кому не испытываю антипатии.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Был случай, когда я бросил что-то делать из-за неуверенности в силах.",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Иногда я люблю позлословить об отсутствующих.",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Я всегда внимательно слушаю собеседника, кто бы он ни был.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Был случай, когда я придумал вескую причину, чтобы оправдаться.",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Случалось, я пользовался оплошностью человека.",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Я всегда охотно признаю свои ошибки.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Иногда вместо прощения я стараюсь отплатить тем же.",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Были случаи, когда я настаивал на том, чтобы делали по-моему.",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "У меня не возникает внутреннего протеста, когда меня просят оказать услугу.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "У меня никогда не возникает досады, когда высказывают противоположное мнение.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Перед длительной поездкой я всегда тщательно продумываю, что взять с собой.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Были случаи, когда я завидовал удаче других.",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Иногда меня раздражают люди, которые обращаются ко мне с вопросами.",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q":
              "Когда у людей неприятности, я иногда думаю, что они получили по заслугам.",
          "a": [
            {"t": "Да", "s": 0},
            {"t": "Нет", "s": 1}
          ]
        },
        {
          "q": "Я никогда с улыбкой не говорил неприятных вещей.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
      ],
    },
    "narcissist": {
      "name": "Тест на нарциссизм",
      "instruction":
          "Ответь «Да» или «Нет». Этот тест покажет, насколько у тебя выражены нарциссические черты. Не пугайся — это просто исследование.",
      "questions": [
        {
          "q":
              "Я считаю, что я особенный человек и заслуживаю особого отношения.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Мне нравится быть в центре внимания.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Я часто думаю о том, насколько я талантлив(а) и красив(а).",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Мне трудно признавать свои ошибки.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я ожидаю, что другие будут делать то, что я хочу.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я завидую успехам других.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я считаю, что большинство людей не понимают меня.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я часто использую других в своих целях.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Мне важно, чтобы мной восхищались.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я считаю себя лучше других.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
      ],
    },
    "masochist": {
      "name": "Тест на мазохизм",
      "instruction":
          "Ответь «Да» или «Нет». Этот тест покажет, склонен(на) ли ты к самопожертвованию и страданию. Будь честен(на) с собой.",
      "questions": [
        {
          "q": "Мне часто кажется, что я заслуживаю страданий.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я готов(а) терпеть боль, если это поможет другим.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Мне трудно сказать «нет», даже если мне это вредит.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я часто жертвую своими интересами ради других.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q":
              "Я чувствую себя виноватым(ой), когда что-то получаю для себя.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Мне нравится, когда меня жалеют.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я часто выбираю партнёров, которые причиняют мне боль.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я думаю, что любовь должна быть связана со страданием.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
      ],
    },
    "stress": {
      "name": "Уровень стресса",
      "instruction":
          "Ответь «Да» или «Нет». Этот тест покажет, насколько ты напряжен(а) в последнее время.",
      "questions": [
        {
          "q": "Я часто чувствую напряжение в теле.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Мне трудно расслабиться.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я часто раздражаюсь по мелочам.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "У меня проблемы со сном.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я чувствую усталость даже после отдыха.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Мне трудно сосредоточиться.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я часто чувствую тревогу без причины.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
        {
          "q": "Я избегаю общения с людьми.",
          "a": [
            {"t": "Да", "s": 1},
            {"t": "Нет", "s": 0}
          ]
        },
      ],
    },
  };

  void _answer(int score) {
    final test = _tests[widget.testType]!;
    final questions = test["questions"] as List;
    setState(() {
      _score += score;
      if (_current < questions.length - 1) {
        _current++;
      } else {
        _finished = true;
        _calculateResult();
        AppState.addXp(30);
        AppState.feedCat();
        AppState.addTestResult(TestResult(
            testName: test["name"] as String,
            result: "$_score баллов",
            interpretation: _interpretation));
      }
    });
  }

  void _calculateResult() {
    final type = widget.testType;
    if (type == "confidence") {
      if (_score <= 12) {
        _resultText = "Сильная неуверенность в себе";
        _interpretation =
            "Тебе стоит работать над самооценкой. Начни с маленьких побед и не бойся отстаивать своё мнение.";
      } else if (_score <= 32) {
        _resultText = "Низкая уверенность в себе";
        _interpretation =
            "Ты часто сомневаешься в себе. Пробуй проявлять инициативу в мелочах — это укрепит веру в себя.";
      } else if (_score <= 60) {
        _resultText = "Средний уровень уверенности";
        _interpretation =
            "Ты неплохо справляешься, но иногда сомневаешься. Развивай навыки общения и отстаивания границ.";
      } else if (_score <= 72) {
        _resultText = "Высокая уверенность в себе";
        _interpretation =
            "Отлично! Ты уверен в себе и умеешь отстаивать свои интересы. Продолжай в том же духе.";
      } else {
        _resultText = "Очень высокий уровень уверенности";
        _interpretation =
            "Впечатляюще! Ты очень уверен в себе. Главное — не переходить в самоуверенность и уважать других.";
      }
    } else if (type == "character") {
      if (_score > 15) {
        _resultText = "С характером можно жить хорошо";
        _interpretation =
            "Вы покладисты, доброжелательны и тактичны. Людям рядом с вами комфортно.";
      } else if (_score >= 8) {
        _resultText = "Есть недостатки, но много достоинств";
        _interpretation =
            "В вашем характере есть и плюсы, и минусы. Не бойтесь раскрывать свои достоинства.";
      } else {
        _resultText = "Характер требует внимания";
        _interpretation =
            "Вокруг вас часто возникают конфликты. Попробуйте развивать терпимость и эмпатию.";
      }
    } else if (type == "communication") {
      if (_score <= 12) {
        _resultText = "Интроверт";
        _interpretation =
            "Вы обращены в себя, с трудом вступаете в контакт. Цените уединение, но помните: общение — тоже ресурс.";
      } else if (_score <= 24) {
        _resultText = "Амбаверт";
        _interpretation =
            "У вас спокойные, ровные отношения с людьми. Вы ответственны и умеете общаться — идеальный баланс.";
      } else {
        _resultText = "Экстраверт";
        _interpretation =
            "Вы общительны, оптимистичны, любите быть в центре внимания. Но следите за обязательствами и эмоциями.";
      }
    } else if (type == "sociability") {
      if (_score <= 10) {
        _resultText = "Низкий уровень коммуникабельности";
        _interpretation =
            "Вам трудно в новых компаниях. Начните с малого: улыбка, вопрос, комплимент — и контакт наладится.";
      } else if (_score <= 20) {
        _resultText = "Средний уровень";
        _interpretation =
            "Вы неплохо общаетесь, но иногда теряетесь. Тренируйтесь задавать открытые вопросы и слушать.";
      } else if (_score <= 30) {
        _resultText = "Высокий уровень";
        _interpretation =
            "Вы легко заводите знакомства и чувствуете себя в компании как рыба в воде. Отлично!";
      } else {
        _resultText = "Очень высокий уровень";
        _interpretation =
            "Вы — душа компании! Но помните: иногда полезно побыть одному, чтобы восстановить силы.";
      }
    } else if (type == "social_desirability") {
      if (_score <= 5) {
        _resultText = "Низкая мотивация одобрения";
        _interpretation =
            "Вы не стремитесь казаться лучше, чем есть. Это может быть и независимостью, и излишней строгостью к себе.";
      } else if (_score <= 12) {
        _resultText = "Средняя мотивация одобрения";
        _interpretation =
            "Вы умеренно ориентированы на социальные нормы. Это здоровый баланс между искренностью и тактом.";
      } else {
        _resultText = "Высокая мотивация одобрения";
        _interpretation =
            "Вы очень стараетесь соответствовать ожиданиям других. Помните: быть собой — тоже важно.";
      }
    } else if (type == "narcissist") {
      if (_score <= 3) {
        _resultText = "Низкий уровень нарциссизма";
        _interpretation =
            "У тебя здоровая самооценка без перекосов в сторону самолюбования. Ты умеешь ценить других.";
      } else if (_score <= 6) {
        _resultText = "Средний уровень нарциссизма";
        _interpretation =
            "У тебя есть некоторые нарциссические черты, но они не мешают тебе строить отношения. Это нормально.";
      } else {
        _resultText = "Высокий уровень нарциссизма";
        _interpretation =
            "Тебе стоит обратить внимание на то, как ты относишься к другим. Помни: уважение — это основа любых отношений.";
      }
    } else if (type == "masochist") {
      if (_score <= 2) {
        _resultText = "Низкий уровень мазохизма";
        _interpretation =
            "Ты умеешь заботиться о себе и не склонен(на) к самопожертвованию в ущерб себе.";
      } else if (_score <= 4) {
        _resultText = "Средний уровень мазохизма";
        _interpretation =
            "Ты иногда жертвуешь собой ради других, но не всегда в ущерб себе. Это нормально.";
      } else {
        _resultText = "Высокий уровень мазохизма";
        _interpretation =
            "Тебе стоит учиться говорить «нет» и заботиться о своих потребностях. Ты тоже важен(на).";
      }
    } else if (type == "stress") {
      if (_score <= 2) {
        _resultText = "Низкий уровень стресса";
        _interpretation = "Ты спокоен(на) и расслаблен(а). Отличный результат!";
      } else if (_score <= 4) {
        _resultText = "Средний уровень стресса";
        _interpretation =
            "У тебя есть напряжение, но оно не критично. Попробуй больше отдыхать и дышать.";
      } else {
        _resultText = "Высокий уровень стресса";
        _interpretation =
            "Тебе стоит обратить внимание на отдых и дыхательные практики. И, возможно, поговорить с кем-то близким.";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final test = _tests[widget.testType]!;
    final questions = test["questions"] as List;
    if (!_started) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.text),
          title: Text(test["name"] as String,
              style: const TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.bold)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment, size: 60, color: AppColors.primary),
                const SizedBox(height: 20),
                const Text("Инструкция",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text)),
                const SizedBox(height: 20),
                Text(test["instruction"] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.text,
                        height: 1.5)),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(55),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () => setState(() => _started = true),
                  child: const Text("Начать тест",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: Text(test["name"] as String,
            style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _finished
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("✨ Результат",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text)),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          children: [
                            Text(_resultText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                            const SizedBox(height: 15),
                            Text("Баллы: $_score",
                                style: const TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textLight)),
                            const SizedBox(height: 15),
                            Text(_interpretation,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.text,
                                    height: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mint,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22)),
                          minimumSize: const Size.fromHeight(50),
                        ),
                        onPressed: () =>
                            MainWindow.of(context)?.setCustomScreen(null),
                        child: const Text("Вернуться",
                            style: TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(
                        value: (_current + 1) / questions.length,
                        backgroundColor: Colors.white,
                        color: AppColors.primary),
                    const SizedBox(height: 10),
                    Text(
                        "Вопрос ${_current + 1} из ${questions.length}",
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textLight)),
                    const SizedBox(height: 30),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(questions[_current]["q"] as String,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text,
                                    height: 1.4)),
                            const SizedBox(height: 30),
                            ...(questions[_current]["a"] as List).map((ans) =>
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 12),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.text,
                                      padding: const EdgeInsets.all(18),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          side: const BorderSide(
                                              color: AppColors.primaryLight,
                                              width: 1)),
                                      elevation: 0,
                                    ),
                                    onPressed: () =>
                                        _answer(ans["s"] as int),
                                    child: Text(ans["t"] as String,
                                        style: const TextStyle(
                                            fontSize: 16),
                                        textAlign: TextAlign.center),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class AiToolsScreen extends StatelessWidget {
  const AiToolsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: const Text("Инструменты ИИ",
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolTile(
                  context,
                  "🤖",
                  "ИИ-Психолог",
                  "Поговори с нейросетью",
                  AppColors.pastelBlue,
                  () => MainWindow.of(context)
                      ?.setCustomScreen(const AiTherapistScreen())),
              _toolTile(
                  context,
                  "🕵️",
                  "Детектор искажений",
                  "Найди ошибки в мыслях",
                  AppColors.pastelPink,
                  () => MainWindow.of(context)
                      ?.setCustomScreen(const DistortionDetectorScreen())),
              _toolTile(
                  context,
                  "🎭",
                  "Примерка ролей",
                  "Потренируй разговор",
                  AppColors.pastelPeach,
                  () => MainWindow.of(context)
                      ?.setCustomScreen(const RolePlayScreen())),
              _toolTile(
                  context,
                  "💬",
                  "Тренажёр разговоров",
                  "Подготовься к сложному разговору",
                  AppColors.pastelGreen,
                  () => MainWindow.of(context)
                      ?.setCustomScreen(const ConversationTrainerScreen())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolTile(BuildContext context, String emoji, String title,
          String desc, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryDark)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 18, color: AppColors.text),
            ],
          ),
        ),
      );
}