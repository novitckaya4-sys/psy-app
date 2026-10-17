import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rive/rive.dart' as rive;
import 'package:vibration/vibration.dart';

// ==========================================
// 🎨 ЦВЕТА
// ==========================================
class AppColors {
  static const Color primary = Color(0xFF8B5CF6);
  static const Color background = Color(0xFFFAFAFC);
  static const Color text = Color(0xFF1F2937);
  static const Color textLight = Color(0xFF6B7280);
  static const Color danger = Color(0xFFEF4444);
  
  static const Color mint = Color(0xFFD1FAE5);
  static const Color pastelYellow = Color(0xFFFEF9C3);
  static const Color pastelGreen = Color(0xFFD1FAE5);
  static const Color pastelPink = Color(0xFFFCE7F3);
  static const Color pastelBlue = Color(0xFFDBEAFE);
  static const Color pastelPeach = Color(0xFFFED7AA);
  static const Color pastelMint = Color(0xFFE0F2E9);
}

// ==========================================
// 📦 МОДЕЛИ И СОСТОЯНИЕ
// ==========================================
class DiaryEntry {
  String type, text, emoji;
  DateTime date;
  DiaryEntry({this.type = "Идея", this.text = "", this.emoji = "💡", DateTime? date}) : date = date ?? DateTime.now();
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

class AppState {
  static String userName = "Друг", avatar = "🌸", apiKey = "";
  static List<DiaryEntry> entries = [];
  static List<MoodEntry> moods = [];
  static List<String> worryBox = [];
  
  static int catLevel = 1;
  static int catXp = 0;
  static int catHunger = 50; 
  
  static void addXp(int amount) {
    catXp += amount;
    if (catXp >= 100) { catLevel++; catXp = 0; }
  }
  static void feedCat() { if (catHunger < 100) catHunger += 25; }

  static void addEntry(DiaryEntry entry) => entries.insert(0, entry);
  static void addMood(MoodEntry mood) => moods.insert(0, mood);

  static void clear() {
    userName = "Друг"; avatar = "🌸"; apiKey = ""; entries.clear(); moods.clear(); worryBox.clear();
    catLevel = 1; catXp = 0; catHunger = 50;
  }
}

// ==========================================
// 💡 ТЕКСТЫ
// ==========================================
final Map<String, String> moodSupport = {
  "Злость": "Злость указывает на нарушение границ. Попробуй выразить это через «Я-сообщение».",
  "Грусть": "Грусть — способ психики переварить потерю. Позволь себе побыть в ней.",
  "Тревога": "Тревога — это энергия. Попробуй сделать 20 приседаний или выпить воды.",
  "Апатия": "Это режим энергосбережения. Начни с малого — просто умойся прохладной водой.",
  "Нейтрально": "Спокойное состояние — отличная база. Сделай сегодня что-то для себя.",
  "Радость": "Зафиксируй этот момент. Что именно сделало тебя счастливым(ой)?",
  "Счастье": "Прекрасно! Поделись своей радостью с кем-то близким.",
};

// ==========================================
// 🤖 ИИ
// ==========================================
class AiService {
  final String apiKey;
  final String systemPrompt;
  static const String baseUrl = 'https://api.groq.com/openai/v1';
  static const String model = 'openai/gpt-oss-120b';

  AiService({required this.apiKey, String? prompt}) : systemPrompt = prompt ?? defaultPrompt;

  static const String defaultPrompt = '''
Ты — «Карманный психолог», теплый собеседник для подростков.
ПРАВИЛА:
1. Говори по-русски, простым языком, как друг-сверстник.
2. НИКОГДА не осуждай.
3. Сначала ОТРАЖАЙ чувства, потом задавай ОДИН открытый вопрос.
4. Не давай медицинских советов.
5. При суициде/самоповреждении — мягко предложи позвонить 8 801 100 16 11.
6. Отвечай коротко: 2–4 предложения.
''';

  Future<String> chat(List<ChatMessage> history) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history.map((m) => {'role': m.role, 'content': m.content}),
    ];
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
        body: jsonEncode({'model': model, 'messages': messages, 'temperature': 0.75, 'max_tokens': 400}),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return '⚠ Ошибка API: ${response.statusCode}.';
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'] as String;
    } catch (e) {
      return '⚠ Не получилось связаться с ИИ. Проверь ключ и интернет.';
    }
  }
}

// ==========================================
// 🚀 ТОЧКА ВХОДА
// ==========================================
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary, surface: Colors.white),
      ),
      home: const RootScreen(),
    );
  }
}

// ==========================================
// 🧭 КОРНЕВОЙ ЭКРАН
// ==========================================
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
      AppState.avatar = prefs.getString('avatar') ?? '🌸';
      AppState.apiKey = prefs.getString('apiKey') ?? '';
      AppState.catLevel = prefs.getInt('catLevel') ?? 1;
      AppState.catXp = prefs.getInt('catXp') ?? 0;
      AppState.catHunger = prefs.getInt('catHunger') ?? 50;
      setState(() => _registered = true);
    } else {
      setState(() => _registered = false);
    }
  }

  Future<void> _saveUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', AppState.userName);
    await prefs.setString('avatar', AppState.avatar);
    await prefs.setString('apiKey', AppState.apiKey);
    await prefs.setInt('catLevel', AppState.catLevel);
    await prefs.setInt('catXp', AppState.catXp);
    await prefs.setInt('catHunger', AppState.catHunger);
  }

  @override
  Widget build(BuildContext context) {
    if (_registered == null) return const Scaffold(body: Center(child: Text("🌸", style: TextStyle(fontSize: 80))));
    if (_registered == false) {
      return RegistrationScreen(onDone: () async {
        await _saveUser();
        setState(() => _registered = true);
      });
    }
    return const MainWindow();
  }
}

// ==========================================
// 📝 РЕГИСТРАЦИЯ
// ==========================================
class RegistrationScreen extends StatefulWidget {
  final VoidCallback onDone;
  const RegistrationScreen({super.key, required this.onDone});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("🌸", style: TextStyle(fontSize: 80), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                const Text("Карманный психолог", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                const Text("Твоё безопасное пространство", style: TextStyle(fontSize: 16, color: AppColors.textLight), textAlign: TextAlign.center),
                const SizedBox(height: 40),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: "Как тебя зовут?", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _keyController,
                  decoration: InputDecoration(labelText: "API Ключ Groq (необязательно)", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 20)),
                  onPressed: _nameController.text.trim().isEmpty ? null : () {
                    AppState.userName = _nameController.text.trim();
                    AppState.apiKey = _keyController.text.trim();
                    widget.onDone();
                  },
                  child: const Text("Начать", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 🖼 MAINWINDOW (4 вкладки)
// ==========================================
class MainWindow extends StatefulWidget {
  const MainWindow({super.key});
  static _MainWindowState? of(BuildContext context) => context.findAncestorStateOfType<_MainWindowState>();

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  int _currentTab = 0;
  Widget? _customScreen;

  void setCustomScreen(Widget? screen) => setState(() => _customScreen = screen);

  void _handleBack() {
    if (_customScreen != null) {
      setState(() => _customScreen = null);
    } else if (_currentTab != 0) {
      setState(() => _currentTab = 0);
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
        case 0: body = const HomeScreen(); break;
        case 1: body = const LessonsScreen(); break;
        case 2: body = const PetScreen(); break;
        case 3: body = const ProfileScreen(); break;
        default: body = const HomeScreen();
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) _handleBack(); },
      child: Scaffold(
        body: SafeArea(bottom: false, child: body),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))]),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _nav(Icons.home_rounded, 0),
                  _nav(Icons.self_improvement, 1),
                  _nav(Icons.pets, 2),
                  _nav(Icons.person_rounded, 3),
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
      onTap: () => setState(() { _customScreen = null; _currentTab = index; }),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: sel ? 20 : 15, vertical: 10),
        decoration: BoxDecoration(color: sel ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(30)),
        child: Icon(icon, size: 28, color: sel ? AppColors.primary : Colors.grey),
      ),
    );
  }
}

// ==========================================
// 🏠 HOME SCREEN
// ==========================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text("Привет, ${AppState.userName}!", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 8),
          const Text("Как ты сегодня?", style: TextStyle(fontSize: 16, color: AppColors.textLight)),
          const SizedBox(height: 40),

          GestureDetector(
            onTap: () => MainWindow.of(context)?.setCustomScreen(const TippScreen()),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF87171), Color(0xFFEF4444)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: const Column(
                children: [
                  Text("🆘", style: TextStyle(fontSize: 40)),
                  SizedBox(height: 10),
                  Text("Мне плохо прямо сейчас", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Скорая психологическая помощь", style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
          const Text("Быстрые действия", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(child: _quickCard(context, "📦", "Сейф тревог", AppColors.pastelBlue, () => MainWindow.of(context)?.setCustomScreen(const WorryBoxScreen()))),
              const SizedBox(width: 15),
              Expanded(child: _quickCard(context, "⚖️", "Суд над мыслью", AppColors.pastelPink, () => MainWindow.of(context)?.setCustomScreen(const ThoughtCourtScreen()))),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _quickCard(context, "🤖", "Поговорить с ИИ", AppColors.mint, () => MainWindow.of(context)?.setCustomScreen(const AiTherapistScreen()))),
              const SizedBox(width: 15),
              Expanded(child: _quickCard(context, "✍️", "Неотправленное", AppColors.pastelPeach, () => MainWindow.of(context)?.setCustomScreen(const UnsentLetterScreen()))),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _quickCard(context, "📔", "Дневник", AppColors.pastelYellow, () => MainWindow.of(context)?.setCustomScreen(const DiaryScreen()))),
              const SizedBox(width: 15),
              Expanded(child: _quickCard(context, "🕵️", "Детектор искажений", Colors.grey.shade200, () => MainWindow.of(context)?.setCustomScreen(const DistortionDetectorScreen()))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickCard(BuildContext context, String emoji, String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 📚 LESSONS SCREEN
// ==========================================
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text("Уроки", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 8),
          const Text("Пройди урок, чтобы покормить котика", style: TextStyle(fontSize: 16, color: AppColors.textLight)),
          const SizedBox(height: 30),

          _lessonTile(context, "🌬️", "Дыхание 4-7-8", "Успокой пульс за 2 минуты", AppColors.pastelBlue, () => MainWindow.of(context)?.setCustomScreen(const BreathingScreen())),
          _lessonTile(context, "👁️", "Заземление 5-4-3-2-1", "Вернись в реальность", AppColors.pastelGreen, () => MainWindow.of(context)?.setCustomScreen(const GroundingScreen())),
          _lessonTile(context, "📱", "Тактильный граундинг", "Синхронизация с вибрацией", AppColors.pastelPink, () => MainWindow.of(context)?.setCustomScreen(const HapticGroundingScreen())),
        ],
      ),
    );
  }

  Widget _lessonTile(BuildContext context, String emoji, String title, String desc, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Row(
          children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24)))),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                  Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🐱 PET SCREEN
// ==========================================
class PetScreen extends StatefulWidget {
  const PetScreen({super.key});
  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  String _thoughtBubble = "Я тебя ждал! 💜";
  rive.SMIInput<bool>? _isHappyInput;

  @override
  void initState() {
    super.initState();
    if (AppState.catHunger < 30) _thoughtBubble = "🍕 Я голоден... Покорми меня?";
  }

  void _petTheCat() {
    setState(() { _thoughtBubble = "Мур-мур! 💜"; });
    if (_isHappyInput != null) {
      _isHappyInput!.value = true;
      Future.delayed(const Duration(seconds: 2), () { if (_isHappyInput != null) _isHappyInput!.value = false; });
    }
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _thoughtBubble = "Спасибо, что ты рядом ✨"); });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text("Твой питомец", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Уровень: ${AppState.catLevel} ", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Text("Сытость: ${AppState.catHunger}%", style: const TextStyle(color: AppColors.textLight)),
            ],
          ),
          const SizedBox(height: 30),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(_thoughtBubble),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: AppColors.pastelBlue, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
              child: Text(_thoughtBubble, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 250, width: 250,
            child: rive.RiveAnimation.asset(
              'assets/cat.riv',
              fit: BoxFit.contain,
              onInit: (artboard) {
                final controller = rive.StateMachineController.fromArtboard(artboard, 'State Machine 1');
                if (controller != null) {
                  artboard.addController(controller);
                  _isHappyInput = controller.findInput<bool>('Happy');
                }
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _petTheCat,
                icon: const Icon(Icons.favorite, color: Colors.white),
                label: const Text("Погладить", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              ),
              const SizedBox(width: 15),
              ElevatedButton.icon(
                onPressed: () => MainWindow.of(context)?.setCustomScreen(const LessonsScreen()), 
                icon: const Icon(Icons.restaurant, color: Colors.white),
                label: const Text("Покормить", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.mint, foregroundColor: AppColors.text, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 👤 PROFILE SCREEN
// ==========================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: AppColors.primary, width: 3)),
              child: Center(child: Text(AppState.avatar, style: const TextStyle(fontSize: 50))),
            ),
          ),
          const SizedBox(height: 15),
          Center(child: Text(AppState.userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text))),
          const SizedBox(height: 40),
          const Text("Полезные ссылки", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 15),
          _linkTile("📞", "Телефон доверия", "8 801 100 16 11", AppColors.pastelPink, () => _launchUrl("tel:88011001611")),
          _linkTile("🌐", "psy.help", "Портал помощи", AppColors.pastelGreen, () => _launchUrl("https://psy.help")),
          _linkTile("🧘", "Insight Timer", "Медитации", AppColors.pastelMint, () => _launchUrl("https://insighttimer.com/ru")),
          _linkTile("💬", "pomogut.by", "Помощь подросткам", AppColors.pastelBlue, () => _launchUrl("https://pomogut.by")),
          const SizedBox(height: 40),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              AppState.clear();
              if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PsyApp()), (r) => false);
            },
            child: const Text("Сбросить все данные", style: TextStyle(color: AppColors.danger, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _linkTile(String icon, String title, String desc, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                  Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 18, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🌬️ BREATHING SCREEN (Урок)
// ==========================================
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});
  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> {
  int _cycle = 0;
  int _secondsLeft = 4;
  String _phaseText = "Вдох...";
  bool _running = false;
  Timer? _timer;

  void _start() {
    setState(() { _running = true; _cycle = 0; _phaseText = "Вдох..."; _secondsLeft = 4; });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          if (_phaseText == "Вдох...") { _phaseText = "Задержка..."; _secondsLeft = 7; }
          else if (_phaseText == "Задержка...") { _phaseText = "Выдох..."; _secondsLeft = 8; }
          else {
            _phaseText = "Вдох..."; _secondsLeft = 4; _cycle++;
            if (_cycle >= 4) {
              _timer?.cancel(); _running = false;
              AppState.addXp(20); AppState.feedCat();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Урок пройден! Котик сыт 💜")));
              MainWindow.of(context)?.setCustomScreen(null);
            }
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: AppColors.text)),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_phaseText, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 30),
              Container(
                width: 200, height: 200,
                decoration: BoxDecoration(color: AppColors.pastelBlue, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: _secondsLeft * 5, spreadRadius: _secondsLeft * 2)]),
                child: Center(child: Text(_running ? "$_secondsLeft" : "Готов?", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 50),
              if (!_running) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), onPressed: _start, child: const Text("Начать урок", style: TextStyle(fontSize: 18))),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 👁️ GROUNDING SCREEN (Урок)
// ==========================================
class GroundingScreen extends StatefulWidget {
  const GroundingScreen({super.key});
  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingScreenState extends State<GroundingScreen> {
  int _step = 0;
  final List<String> _steps = ["Найди 5 синих предметов вокруг", "Почувствуй 4 твердые поверхности", "Услышь 3 звука", "Почувствуй 2 запаха", "Почувствуй 1 вкус (сделай глоток воды)"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: AppColors.text)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.remove_red_eye, size: 60, color: AppColors.primary),
              const SizedBox(height: 30),
              Text(_steps[_step], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text), textAlign: TextAlign.center),
              const SizedBox(height: 50),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                onPressed: () {
                  setState(() {
                    if (_step < _steps.length - 1) { _step++; }
                    else {
                      AppState.addXp(30); AppState.feedCat();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ты здесь и сейчас. Котик доволен! 💜")));
                      MainWindow.of(context)?.setCustomScreen(null);
                    }
                  });
                },
                child: Text(_step == _steps.length - 1 ? "Завершить" : "Сделано", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 📱 HAPTIC GROUNDING (Урок)
// ==========================================
class HapticGroundingScreen extends StatefulWidget {
  const HapticGroundingScreen({super.key});
  @override
  State<HapticGroundingScreen> createState() => _HapticGroundingScreenState();
}

class _HapticGroundingScreenState extends State<HapticGroundingScreen> {
  int _clicks = 0;

  void _vibrate() {
    Vibration.vibrate(duration: 100);
    setState(() => _clicks++);
    if (_clicks >= 10) {
      AppState.addXp(20); AppState.feedCat();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Синхронизация завершена! Котик сыт 💜")));
      MainWindow.of(context)?.setCustomScreen(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: AppColors.text)),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Нажимай в такт вибрации", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 50),
              GestureDetector(
                onTap: _vibrate,
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(color: AppColors.pastelPink, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 20)]),
                  child: Center(child: Text("$_clicks / 10", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 🆘 TIPP SCREEN (Скорая помощь)
// ==========================================
class TippScreen extends StatefulWidget {
  const TippScreen({super.key});
  @override
  State<TippScreen> createState() => _TippScreenState();
}

class _TippScreenState extends State<TippScreen> {
  int _step = 0;
  int _timerSeconds = 0;
  Timer? _timer;

  final List<Map<String, String>> _steps = [
    {"title": "Температура", "desc": "Намочи лицо ледяной водой на 30 секунд.", "btn": "Я сделал(а)"},
    {"title": "Движение", "desc": "Сделай 20 быстрых приседаний.", "btn": "Сделано"},
    {"title": "Дыхание", "desc": "Вдох 4, задержка 7, выдох 8.", "btn": "Начать таймер"},
  ];

  void _nextStep() {
    if (_step < _steps.length - 1) { setState(() => _step++); }
    else {
      AppState.addXp(20); AppState.feedCat();
      MainWindow.of(context)?.setCustomScreen(null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ты справился(ась)! 💜")));
    }
  }

  void _startTimer() {
    setState(() => _timerSeconds = 4);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_timerSeconds > 0) { _timerSeconds--; }
        else { _timer?.cancel(); _nextStep(); }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _steps[_step];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: AppColors.text)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: (_step + 1) / _steps.length, backgroundColor: Colors.white, color: AppColors.primary),
              const SizedBox(height: 40),
              Text("Шаг ${_step + 1}: ${current['title']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)),
              const SizedBox(height: 20),
              Text(current['desc']!, style: const TextStyle(fontSize: 18, color: AppColors.textLight, height: 1.5)),
              const Spacer(),
              if (_timerSeconds > 0) Center(child: Text("$_timerSeconds", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: AppColors.primary))),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: _timerSeconds > 0 ? null : (_step == 2 ? _startTimer : _nextStep),
                child: Text(current['btn']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 📦 WORRY BOX SCREEN
// ==========================================
class WorryBoxScreen extends StatefulWidget {
  const WorryBoxScreen({super.key});
  @override
  State<WorryBoxScreen> createState() => _WorryBoxScreenState();
}

class _WorryBoxScreenState extends State<WorryBoxScreen> {
  final _controller = TextEditingController();

  void _addWorry() {
    if (_controller.text.trim().isEmpty) return;
    setState(() { AppState.worryBox.insert(0, _controller.text.trim()); _controller.clear(); });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Мысль заперта до вечера 💜")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text("📦 Сейф тревог", style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)), iconTheme: const IconThemeData(color: AppColors.text)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              const Text("Выгрузи мысль. Мы вернемся к ней в 18:30.", style: TextStyle(fontSize: 16, color: AppColors.textLight)),
              const SizedBox(height: 20),
              TextField(controller: _controller, maxLines: 3, decoration: InputDecoration(hintText: "О чем ты беспокоишься?", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
              const SizedBox(height: 15),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _addWorry, child: const Text("Запереть в сейф")),
              const SizedBox(height: 30),
              Expanded(
                child: ListView.builder(
                  itemCount: AppState.worryBox.length,
                  itemBuilder: (context, i) => Container(
                    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                    child: Row(children: [const Icon(Icons.lock_outline, color: Colors.grey), const SizedBox(width: 15), Expanded(child: Text(AppState.worryBox[i]))]),
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

// ==========================================
// ⚖️ THOUGHT COURT SCREEN
// ==========================================
class ThoughtCourtScreen extends StatefulWidget {
  const ThoughtCourtScreen({super.key});
  @override
  State<ThoughtCourtScreen> createState() => _ThoughtCourtScreenState();
}

class _ThoughtCourtScreenState extends State<ThoughtCourtScreen> {
  final _thoughtCtrl = TextEditingController();
  final _proCtrl = TextEditingController();
  final _contraCtrl = TextEditingController();
  bool _verdictReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text("⚖️ Суд над мыслью", style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)), iconTheme: const IconThemeData(color: AppColors.text)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _inputBlock("Мысль (Обвинение)", _thoughtCtrl, AppColors.pastelYellow),
              _inputBlock("Факты ЗА (Прокурор)", _proCtrl, AppColors.pastelPink),
              _inputBlock("Факты ПРОТИВ (Адвокат)", _contraCtrl, AppColors.pastelGreen),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () { if (_thoughtCtrl.text.isNotEmpty && _proCtrl.text.isNotEmpty && _contraCtrl.text.isNotEmpty) setState(() => _verdictReady = true); },
                child: const Text("Вынести вердикт", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              if (_verdictReady) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(15)),
                  child: const Text("Сбалансированный взгляд: у твоей тревоги есть и плюсы, и минусы. Это не конец света, а просто ситуация, которую можно решить.", style: TextStyle(fontSize: 16, color: AppColors.text)),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputBlock(String label, TextEditingController ctrl, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          TextField(controller: ctrl, decoration: const InputDecoration(border: InputBorder.none, hintText: "...")),
        ],
      ),
    );
  }
}

// ==========================================
// ✍️ UNSENT LETTER SCREEN
// ==========================================
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
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text("✍️ Неотправленное", style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)), iconTheme: const IconThemeData(color: AppColors.text)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: _burned
              ? const Center(child: Text("Письмо сожжено. Стало легче? 💜", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))
              : Column(
                  children: [
                    const Text("Напиши всё, что накипело. Никто это не прочитает.", style: TextStyle(fontSize: 16, color: AppColors.textLight)),
                    const SizedBox(height: 20),
                    Expanded(
                      child: TextField(
                        controller: _controller, maxLines: null, expands: true,
                        decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: () { setState(() => _burned = true); AppState.addXp(10); },
                      child: const Text("Сжечь", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ==========================================
// 🤖 AI THERAPIST SCREEN
// ==========================================
class AiTherapistScreen extends StatefulWidget {
  const AiTherapistScreen({super.key});
  @override
  State<AiTherapistScreen> createState() => _AiTherapistScreenState();
}

class _AiTherapistScreenState extends State<AiTherapistScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [ChatMessage(role: 'assistant', content: 'Привет 💜 Я здесь, чтобы выслушать. Что случилось?')];
  bool _loading = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    if (AppState.apiKey.isEmpty) {
      setState(() { _messages.add(ChatMessage(role: 'user', content: text)); _messages.add(ChatMessage(role: 'assistant', content: 'Извини, ключ Groq не введён.')); });
      _controller.clear(); return;
    }

    setState(() { _messages.add(ChatMessage(role: 'user', content: text)); _loading = true; });
    _controller.clear(); _scrollDown();

    try {
      final ai = AiService(apiKey: AppState.apiKey);
      final reply = await ai.chat(_messages);
      setState(() { _messages.add(ChatMessage(role: 'assistant', content: reply)); _loading = false; });
    } catch (e) {
      setState(() { _messages.add(ChatMessage(role: 'assistant', content: 'Ошибка: $e')); _loading = false; });
    }
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.primary, title: const Row(children: [Text("🤖", style: TextStyle(fontSize: 20)), SizedBox(width: 10), Text("ИИ-Психолог", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll, padding: const EdgeInsets.all(16), itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  final isUser = m.role == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(color: isUser ? AppColors.primary : Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Text(m.content, style: TextStyle(color: isUser ? Colors.white : AppColors.text)),
                    ),
                  );
                },
              ),
            ),
            if (_loading) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
            Container(
              padding: const EdgeInsets.all(12), color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Напиши, что чувствуешь...'), onSubmitted: (_) => _send())),
                      IconButton(icon: const Icon(Icons.send, color: AppColors.primary), onPressed: _loading ? null : _send),
                    ],
                  ),
                  const Text("⚠️ Бот не заменит квалифицированную психологическую помощь.", style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🕵️ DISTORTION DETECTOR SCREEN
// ==========================================
class DistortionDetectorScreen extends StatefulWidget {
  const DistortionDetectorScreen({super.key});
  @override
  State<DistortionDetectorScreen> createState() => _DistortionDetectorScreenState();
}

class _DistortionDetectorScreenState extends State<DistortionDetectorScreen> {
  final _controller = TextEditingController();
  String _result = "";
  bool _loading = false;

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (AppState.apiKey.isEmpty) { setState(() => _result = '⚠ Ключ Groq не введён.'); return; }

    setState(() { _loading = true; _result = ""; });

    const detectorPrompt = '''
Ты — детектор когнитивных искажений. Анализируй мысль человека и находи искажения.
ВОЗМОЖНЫЕ ИСКАЖЕНИЯ: Катастрофизация, Чёрно-белое мышление, Чтение мыслей, Обобщение, Обесценивание, Долженствование, Персонализация.
ФОРМАТ ОТВЕТА: 🎯 Искажение, 💭 Что происходит, 🔄 А что если наоборот, 💜 Поддержка. Отвечай коротко.
''';

    try {
      final ai = AiService(apiKey: AppState.apiKey, prompt: detectorPrompt);
      final reply = await ai.chat([ChatMessage(role: 'user', content: text)]);
      setState(() { _result = reply; _loading = false; AppState.addXp(10); });
    } catch (e) {
      setState(() { _result = 'Ошибка: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.primary, title: const Text("🕵️ Детектор искажений", style: TextStyle(color: Colors.white))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Напиши свою мысль. Я найду когнитивное искажение и предложу контраргумент.", style: TextStyle(fontSize: 13, color: AppColors.textLight, height: 1.4)),
              const SizedBox(height: 14),
              Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.all(14), child: TextField(controller: _controller, maxLines: 4, decoration: const InputDecoration(border: InputBorder.none, hintText: "Например: «Я провалил экзамен, значит я ничтожество»"))),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)), minimumSize: const Size.fromHeight(50)),
                onPressed: _loading ? null : _analyze,
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("🧠 Найти искажение", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              if (_result.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.all(18), child: Text(_result, style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.5))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 📔 DIARY SCREEN
// ==========================================
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

  String _emoji(String t) => {"Идея": "💡", "Благодарность": "🙏", "Неудача": "😔", "Успех": "🎉"}[t] ?? "📝";
  Color _color(String t) => {"Идея": AppColors.pastelYellow, "Благодарность": AppColors.pastelGreen, "Неудача": AppColors.pastelPink, "Успех": AppColors.mint}[t] ?? AppColors.background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text("📔 Дневник", style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)), iconTheme: const IconThemeData(color: AppColors.text)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_showForm)
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), minimumSize: const Size.fromHeight(50)), onPressed: () => setState(() => _showForm = true), child: const Text("➕ Новая запись")),
              
              if (_showForm) ...[
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      DropdownButton<String>(value: _type, isExpanded: true, items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) => setState(() => _type = v!)),
                      TextField(controller: _text, maxLines: 5, decoration: const InputDecoration(hintText: "Твои мысли...")),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => setState(() => _showForm = false), child: const Text("Отмена")),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: () {
                              if (_text.text.trim().isEmpty) return;
                              AppState.addEntry(DiaryEntry(type: _type, text: _text.text.trim(), emoji: _emoji(_type)));
                              AppState.addXp(15);
                              _text.clear(); setState(() => _showForm = false);
                            },
                            child: const Text("Сохранить", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
              ],

              ...AppState.entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _color(e.type), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Text(e.emoji), const SizedBox(width: 8), Text(e.type, style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text("${e.date.hour}:${e.date.minute.toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 11))]),
                    const SizedBox(height: 8),
                    Text(e.text),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}