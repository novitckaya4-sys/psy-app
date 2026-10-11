import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ==========================================
// 🎨 ЦВЕТА
// ==========================================
class AppColors {
  static const Color primary = Color(0xFF3C096C);
  static const Color primaryDark = Color(0xFF5A189A);
  static const Color background = Color(0xFFE0AAFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF240046);
  static const Color danger = Color(0xFFE74C3C);
  static const Color mint = Color(0xFFA8E6CF);

  static const Color pastelYellow = Color(0xFFFCF6BD);
  static const Color pastelGreen = Color(0xFFB8E6D5);
  static const Color pastelPink = Color(0xFFFFB6C1);
  static const Color pastelMint = Color(0xFFD0F4DE);
  static const Color pastelBlue = Color(0xFFC4E4FF);
  static const Color pastelPeach = Color(0xFFFFDAB9);
  static const Color purpleLight = Color(0xFFC77DFF);
  static const Color purpleMedium = Color(0xFF9D4EDD);
  static const Color purpleDeep = Color(0xFF7B2CBF);
}

// ==========================================
// 📦 МОДЕЛИ
// ==========================================
class DiaryEntry {
  String type;
  String text;
  String emoji;
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
  String role;
  String content;
  ChatMessage({required this.role, required this.content});
}

// ==========================================
// 💾 СОСТОЯНИЕ
// ==========================================
class AppState {
  static String userName = "";
  static String avatar = "🌸";
  static String age = "";
  static String apiKey = "";
  static List<DiaryEntry> entries = [];
  static List<MoodEntry> moods = [];

  static void addEntry(DiaryEntry entry) => entries.insert(0, entry);
  static void addMood(MoodEntry mood) => moods.insert(0, mood);

  static void clear() {
    userName = "";
    avatar = "🌸";
    age = "";
    entries.clear();
    moods.clear();
  }
}

// ==========================================
// 🤖 ИИ-СЕРВИС (Groq)
// ==========================================
class AiService {
  final String apiKey;
  static const String baseUrl = 'https://api.groq.com/openai/v1';
  static const String model = 'llama-3.3-70b-versatile';

  AiService(this.apiKey);

  static const String systemPrompt = '''
Ты — «Карманный психолог», тёплый собеседник для подростков из Беларуси.

ПРАВИЛА:
1. Говори по-русски, простым языком, как друг-сверстник. Но с заботой.
2. НИКОГДА не осуждай. Не говори «ты должен», «это глупо», «сама виновата».
3. Сначала ОТРАЖАЙ чувства: «Похоже, тебе сейчас очень тяжело...»
4. Потом задавай ОДИН открытый вопрос.
5. Не давай медицинских советов, не ставь диагнозы.
6. Если слышишь про суицид, самоповреждение или насилие — мягко предложи позвонить 8 801 100 16 11 (круглосуточно, анонимно, Беларусь).
7. Отвечай коротко: 2–4 предложения. Не читай лекции.
8. Используй 1–2 эмодзи на сообщение.
9. Не используй списки и заголовки — только живой разговор.
''';

  Future<String> chat(List<ChatMessage> history) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history.map((m) => {'role': m.role, 'content': m.content}),
    ];

    try {
      final response = await http.post(
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
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        return 'Неверный API-ключ. Проверь его в Groq.';
      }
      if (response.statusCode == 429) {
        return 'Слишком много запросов. Подожди минуту.';
      }
      if (response.statusCode != 200) {
        return 'Ошибка API: ${response.statusCode}. Попробуй ещё раз.';
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'] as String;
    } catch (e) {
      if (e.toString().contains('CORS') ||
          e.toString().contains('XMLHttpRequest') ||
          e.toString().contains('Failed to fetch')) {
        return 'Из браузера Chrome запрос блокируется (CORS).\n\nЗапусти приложение как Windows-приложение:\nflutter run -d windows — там ИИ работает.';
      }
      return 'Не получилось: $e\n\nПроверь интернет и ключ.';
    }
  }
}

// ==========================================
// 🆘 ПРОТОКОЛЫ САМОПОМОЩИ
// ==========================================
class CrisisProtocol {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final List<Map<String, String>> steps;
  final String closing;

  const CrisisProtocol({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.steps,
    required this.closing,
  });
}

final List<CrisisProtocol> crisisProtocols = [
  CrisisProtocol(
    emoji: "🖤",
    title: "Суицидальные мысли",
    subtitle: "Когда кажется, что выхода нет",
    color: const Color(0xFF8E7CC3),
    steps: [
      {"t": "1. Останови мгновение", "d": "Мысли о смерти — это не желание умереть. Это желание, чтобы боль закончилась.", "a": "Скажи вслух: «Я хочу не умереть. Я хочу, чтобы перестало болеть.»"},
      {"t": "2. Ты в безопасности?", "d": "Если ты уже причинил(а) себе вред — вызови 103. Это не слабость, это забота.", "a": "Отложи всё опасное в другую комнату."},
      {"t": "3. Правило 5 минут", "d": "Пик импульса длится 5–20 минут. Продержись — станет легче.", "a": "Поставь таймер. Дыши: 4 вдох → 7 задержка → 8 выдох."},
      {"t": "4. Заземлись", "d": "Тело возвращает в «сейчас».", "a": "5 вещей видишь → 4 звука → 3 касаешься → 2 запаха → 1 вкус."},
      {"t": "5. Обратись к кому-то", "d": "Одиночество усиливает боль.", "a": "Напиши: «Мне плохо, побудь со мной.»"},
      {"t": "6. Отложи решение", "d": "Решение в пике боли — не твоё настоящее решение.", "a": "«Я вернусь к этому через 24 часа. Не раньше.»"},
    ],
    closing: "Ты важен(на). Твоя боль реальна, но она не навсегда. 💜",
  ),
  CrisisProtocol(
    emoji: "💓",
    title: "Паническая атака",
    subtitle: "Сердце колотится, не хватает воздуха",
    color: const Color(0xFFFFB6C1),
    steps: [
      {"t": "1. Ты не умираешь", "d": "Паника неприятна, но НЕ опасна. Пройдёт через 5–20 минут."},
      {"t": "2. Найди опору", "d": "Сядь. Почувствуй спиной стул, стопами — пол.", "a": "Надави стопами в пол 5 секунд. Отпусти. Повтори 3 раза."},
      {"t": "3. Дыхание 4-7-8", "d": "Замедляет пульс.", "a": "Вдох 4 → задержка 7 → выдох 8. 4 раза."},
      {"t": "4. Холод", "d": "Активирует «нырятельный рефлекс» — пульс падает.", "a": "Умойся ледяной водой или лёд к запястьям на 30 секунд."},
      {"t": "5. Отвлеки мозг", "d": "Назови вслух 5 предметов вокруг."},
      {"t": "6. Мантра", "d": "Повторяй:", "a": "«Это паника. Она не убьёт. Она проходит. Я в безопасности.»"},
    ],
    closing: "Ты справился(ась). Сердце — не враг. Оно просто испугалось. 🌸",
  ),
  CrisisProtocol(
    emoji: "🌙",
    title: "Бессонница",
    subtitle: "Не могу уснуть, мысли крутятся",
    color: const Color(0xFFC4E4FF),
    steps: [
      {"t": "1. Правило 20 минут", "d": "Не уснул(а) за 20 минут — встань.", "a": "Перейди в другое место. Тусклый свет."},
      {"t": "2. Дыхание 4-7-8", "d": "Включает режим «отдых».", "a": "3 цикла."},
      {"t": "3. Выгрузи мысли", "d": "Мозг держит то, что не записано.", "a": "5 минут пиши ВСЁ."},
      {"t": "4. Прогрессивная релаксация", "d": "Напряги-расслабь мышцы.", "a": "Стопы → голени → бёдра → живот → руки → плечи → лицо."},
      {"t": "5. Не смотри на часы", "d": "Проверка времени = тревога.", "a": "Разверни телефон."},
    ],
    closing: "Одна ночь не разрушит тебя. 🌙",
  ),
  CrisisProtocol(
    emoji: "🌊",
    title: "Сильная тревога",
    subtitle: "Внутри всё сжимается",
    color: const Color(0xFFFFDAB9),
    steps: [
      {"t": "1. Назови тревогу", "d": "Неопределённая тревога сильнее.", "a": "«Я тревожусь о ___.»"},
      {"t": "2. Факт vs страх", "d": "Тревога путает реальность с прогнозом.", "a": "«Что сейчас, а что я предсказываю?»"},
      {"t": "3. Шкала 0-10", "d": "Оцени тревогу."},
      {"t": "4. Удлинённый выдох", "d": "Выдох длиннее вдоха = безопасность.", "a": "Вдох 4 → выдох 8. 5 минут."},
      {"t": "5. Движение", "d": "Тревога — это энергия.", "a": "20 приседаний или прогулка 5 минут."},
      {"t": "6. Маленькое действие", "d": "Тревога живёт в бездействии.", "a": "Сделай что-то на 2 минуты."},
    ],
    closing: "Тревога — не приговор. 💜",
  ),
  CrisisProtocol(
    emoji: "🔥",
    title: "Гнев / агрессия",
    subtitle: "Хочется кричать, крушить",
    color: const Color(0xFFFFB6B6),
    steps: [
      {"t": "1. Выйди из ситуации", "d": "Гнев длится 90 секунд.", "a": "«Мне нужно 5 минут.»"},
      {"t": "2. Сбрось энергию", "d": "Через мышцы.", "a": "20 приседаний, отжимания, бей подушку."},
      {"t": "3. Дыхание", "d": "Вдох 4 → задержка 4 → выдох 6.", "a": "6 циклов."},
      {"t": "4. Отдели гнев от действия", "d": "Чувство — ок. Крик/удар — нет."},
      {"t": "5. Что за гневом?", "d": "Под гневом: боль, страх, стыд.", "a": "«Я злюсь, потому что мне важно, чтобы ___.»"},
      {"t": "6. Разговор потом", "d": "Сейчас не время.", "a": "Вернись через 20–30 минут."},
    ],
    closing: "Ты не плохой человек. Ты человек, которому больно. 🔥",
  ),
  CrisisProtocol(
    emoji: "🩹",
    title: "Тяга к самоповреждению",
    subtitle: "Хочется порезать/ударить себя",
    color: const Color(0xFFE8B4D8),
    steps: [
      {"t": "1. Отложи на 15 минут", "d": "Импульс длится недолго.", "a": "Поставь таймер."},
      {"t": "2. Убери предметы", "d": "Сделай импульс менее доступным."},
      {"t": "3. Замени ощущение", "d": "Дай мозгу сигнал безопасно.", "a": "Лёд к запястью. Резинка. Холодный душ."},
      {"t": "4. Что ты хочешь почувствовать?", "d": "Контроль? Наказание? Облегчение?"},
      {"t": "5. Скажи кому-то", "d": "Ты не обязан(а) один(одна).", "a": "«Мне плохо. Мне страшно за себя.»"},
      {"t": "6. Дыши с задержкой", "d": "Контроль без вреда.", "a": "Вдох 4 → задержка 4 → выдох 4."},
    ],
    closing: "Ты заслуживаешь не боли, а заботы. 🩹",
  ),
  CrisisProtocol(
    emoji: "💧",
    title: "Истерика / слёзы",
    subtitle: "Не могу остановиться плакать",
    color: const Color(0xFFA9DEF9),
    steps: [
      {"t": "1. Позволь плакать", "d": "Слёзы лечат.", "a": "«Я имею право плакать.»"},
      {"t": "2. Безопасное место", "d": "Сядь. Обопрись. Укройся пледом."},
      {"t": "3. Удлинённый выдох", "d": "Вдох 4 → выдох 8.", "a": "10 циклов."},
      {"t": "4. Телесный контакт", "d": "Обними себя.", "a": "«Я с тобой.»"},
      {"t": "5. Вода", "d": "Выпей стакан воды."},
      {"t": "6. Один ориентир", "d": "Опиши 1 предмет вслух."},
    ],
    closing: "Слёзы — язык, на котором тело говорит «мне больно». 🌸",
  ),
  CrisisProtocol(
    emoji: "🌫",
    title: "Диссоциация",
    subtitle: "Всё как в тумане",
    color: const Color(0xFFD0F4DE),
    steps: [
      {"t": "1. Это защита", "d": "Мозг отключил чувства, чтобы выжить."},
      {"t": "2. Температура", "d": "Холод или тепло возвращают.", "a": "Холодная вода или горячая чашка."},
      {"t": "3. Заземление 5-4-3-2-1", "d": "По одному на орган чувств."},
      {"t": "4. Движение", "d": "Диссоциация — замирание.", "a": "Потопай, похлопай себя."},
      {"t": "5. Скажи вслух", "d": "Проговори факты о себе.", "a": "«Меня зовут ___. Я в комнате, я в безопасности.»"},
      {"t": "6. Связь с другим", "d": "Голос возвращает.", "a": "Позвони или включи знакомый голос."},
    ],
    closing: "Ты возвращаешься. Каждый шаг — якорь. 🌫",
  ),
];

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.card,
        ),
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
  bool _registered = false;

  @override
  Widget build(BuildContext context) {
    if (!_registered) {
      return RegistrationScreen(
        onDone: () => setState(() => _registered = true),
      );
    }
    return const MainWindow();
  }
}

// ==========================================
// 📝 ЭКРАН РЕГИСТРАЦИИ
// ==========================================
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
  String _selectedAvatar = "";

  final List<Map<String, dynamic>> _row1 = [
    {"emoji": "🌸", "color": const Color(0xFFFFB6C1)},
    {"emoji": "🌿", "color": const Color(0xFFB8E6D5)},
    {"emoji": "⭐", "color": const Color(0xFFFCF6BD)},
    {"emoji": "🌙", "color": const Color(0xFFC4E4FF)},
  ];
  final List<Map<String, dynamic>> _row2 = [
    {"emoji": "🔥", "color": const Color(0xFFFFB6B6)},
    {"emoji": "💧", "color": const Color(0xFFB6D9FF)},
    {"emoji": "🌺", "color": const Color(0xFFFFC4E0)},
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
              _label("Выбери аватарку"),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _row1.map(_avatarBtn).toList()),
                    const SizedBox(height: 8),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _row2.map(_avatarBtn).toList()),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _selectedAvatar.isEmpty
                      ? "Не выбрана"
                      : "Выбрано: $_selectedAvatar",
                  style: TextStyle(
                      fontSize: 13,
                      fontStyle: _selectedAvatar.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(height: 20),
              _label("Ключ Groq (для ИИ, необязательно)"),
              _input(_keyController),
              const Text(
                "Если не хочешь ИИ — оставь пустым.",
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primaryDark),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mint,
                  disabledBackgroundColor:
                      AppColors.mint.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  minimumSize: const Size.fromHeight(55),
                  elevation: 0,
                ),
                onPressed: _active
                    ? () {
                        AppState.userName = _nameController.text.trim();
                        AppState.age = _ageController.text.trim();
                        AppState.avatar = _selectedAvatar;
                        AppState.apiKey = _keyController.text.trim();
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
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text)),
      );

  Widget _input(TextEditingController c,
      {TextInputType? keyboard, Function(String)? onChanged}) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        onChanged: onChanged,
        decoration: const InputDecoration(border: InputBorder.none),
        style: const TextStyle(fontSize: 16, color: AppColors.text),
      ),
    );
  }

  Widget _avatarBtn(Map<String, dynamic> item) {
    return Padding(
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
}

// ==========================================
// 🖼 MAINWINDOW — 5 ВКЛАДОК
// ==========================================
class MainWindow extends StatefulWidget {
  const MainWindow({super.key});
  static _MainWindowState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MainWindowState>();

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  int _currentTab = 2; // Главная по умолчанию
  Widget? _customScreen;

  void setCustomScreen(Widget? screen) => setState(() => _customScreen = screen);
  void switchTab(int index) => setState(() {
        _customScreen = null;
        _currentTab = index;
      });

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_customScreen != null) {
      body = _customScreen!;
    } else {
      switch (_currentTab) {
        case 0:
          body = const BreathingScreen();
          break;
        case 1:
          body = const MeditationScreen();
          break;
        case 2:
          body = const HomeScreen();
          break;
        case 3:
          body = const DiaryScreen();
          break;
        case 4:
          body = const ProfileScreen();
          break;
        default:
          body = const HomeScreen();
      }
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: Container(
        height: 70,
        color: AppColors.primary,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _nav(Icons.air_rounded, 0),                // Дыхание
            _nav(Icons.self_improvement, 1),           // Медитация
            _nav(Icons.home_rounded, 2),               // Главная
            _nav(Icons.book_rounded, 3),               // Дневник
            _nav(Icons.person_rounded, 4),             // Профиль
          ],
        ),
      ),
    );
  }

  Widget _nav(IconData icon, int index) {
    final sel = _customScreen == null && _currentTab == index;
    return IconButton(
      icon: Icon(icon, size: 32, color: sel ? Colors.white : Colors.black),
      onPressed: () => switchTab(index),
    );
  }
}

// ==========================================
// 🏠 HOME SCREEN
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedMood = "";

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
    {"n": "Счастье", "e": "😍"},
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
                  child: Text(AppState.avatar.isEmpty ? "🌸" : AppState.avatar,
                      style: const TextStyle(fontSize: 34)),
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
                    const Text("Как ты сегодня?",
                        style: TextStyle(
                            fontSize: 14, color: AppColors.primaryDark)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // ЭКСТРЕННАЯ ПОМОЩЬ — БОЛЬШАЯ КРАСНАЯ КНОПКА
          GestureDetector(
            onTap: () => MainWindow.of(context)
                ?.setCustomScreen(const EmergencyScreen()),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("🚨", style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Text("Экстренная помощь",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ИИ-психолог
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purpleDeep,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(55),
              elevation: 0,
            ),
            onPressed: () => MainWindow.of(context)
                ?.setCustomScreen(const AiTherapistScreen()),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("🤖", style: TextStyle(fontSize: 20)),
                SizedBox(width: 10),
                Text("Поговорить с ИИ",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Что делать если...
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pastelPink,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(55),
              elevation: 0,
            ),
            onPressed: () => MainWindow.of(context)
                ?.setCustomScreen(const SelfHelpScreen()),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("🆘", style: TextStyle(fontSize: 20)),
                SizedBox(width: 10),
                Text("Что делать если...",
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Center(
            child: Text("Как ты себя чувствуешь?",
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _moods.map((m) {
              final isSel = _selectedMood == m["n"];
              return GestureDetector(
                onTap: () => setState(() => _selectedMood = m["n"]!),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSel
                        ? Border.all(color: AppColors.primaryDark, width: 2)
                        : null,
                  ),
                  child: Text(m["e"]!,
                      style: TextStyle(
                          fontSize: m["n"] == "Счастье" ? 36 : 28)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _selectedMood.isEmpty
                  ? "Выбери состояние"
                  : "Выбрано: $_selectedMood",
              style: TextStyle(
                  fontSize: 14,
                  fontStyle: _selectedMood.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mint,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              minimumSize: const Size.fromHeight(45),
              elevation: 0,
            ),
            onPressed: _selectedMood.isNotEmpty
                ? () {
                    AppState.addMood(MoodEntry(mood: _selectedMood));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Сохранено: $_selectedMood")),
                    );
                    setState(() => _selectedMood = "");
                  }
                : null,
            child: const Text("Отметить настроение",
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 25),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFB6D9),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("💡  Совет дня",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark)),
                SizedBox(height: 8),
                Text("Ты справляешься лучше, чем тебе кажется.",
                    style: TextStyle(fontSize: 14, color: AppColors.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 🫁 BREATHING SCREEN — 4 ПРАКТИКИ
// ==========================================
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});
  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> {
  bool _inPractice = false;
  String _practice = "478";
  String _title = "🌬  Дыхание 4-7-8";
  String _hint = "Классика для быстрого успокоения.";

  Timer? _timer;
  int _secondsLeft = 0;
  int _phase = 0; // 0-вдох, 1-задержка, 2-выдох
  int _cycle = 0;
  double _circleSize = 150;
  String _phaseText = "Готов?";

  void _choose(String key, String title, String hint) {
    setState(() {
      _practice = key;
      _title = title;
      _hint = hint;
      _inPractice = true;
      _phaseText = "Готов?";
      _secondsLeft = 0;
      _cycle = 0;
      _circleSize = 150;
    });
  }

  void _start() {
    setState(() {
      _cycle = 0;
      _phase = 0;
    });
    _nextPhase();
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _circleSize = 150;
      _phaseText = "Стоп";
      _secondsLeft = 0;
      _cycle = 0;
    });
  }

  void _nextPhase() {
    if (_cycle >= 4) {
      _timer?.cancel();
      setState(() {
        _circleSize = 150;
        _phaseText = "Готово! 💜";
        _secondsLeft = 0;
      });
      return;
    }

    int inT = 4, holdT = 7, outT = 8;
    if (_practice == "box") {
      inT = 4;
      holdT = 4;
      outT = 4;
    }
    if (_practice == "bee") {
      inT = 4;
      holdT = 2;
      outT = 6;
    }
    if (_practice == "belly") {
      inT = 4;
      holdT = 2;
      outT = 4;
    }

    if (_phase == 0) {
      _phaseText = "Вдох...";
      _secondsLeft = inT;
      _circleSize = 250;
    } else if (_phase == 1) {
      _phaseText = "Задержи...";
      _secondsLeft = holdT;
      _circleSize = 250;
    } else if (_phase == 2) {
      _phaseText = _practice == "bee" ? "Жужжи..." : "Выдох...";
      _secondsLeft = outT;
      _circleSize = 150;
    }

    setState(() {});

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _phase++;
        if (_phase > 2) {
          _phase = 0;
          _cycle++;
        }
        _nextPhase();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text("🌬  Дыхательные практики",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text)),
          ),
          const SizedBox(height: 5),
          const Center(
            child: Text("Выбери подходящую для себя",
                style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primaryDark)),
          ),
          const SizedBox(height: 20),
          if (!_inPractice) ...[
            _itemCard("🌬  Дыхание 4-7-8", "Вдох 4 → задержка 7 → выдох 8",
                "Классика для быстрого успокоения.", AppColors.pastelGreen,
                () => _choose("478", "🌬  Дыхание 4-7-8",
                    "Классика для быстрого успокоения.")),
            _itemCard("📦  Коробочное дыхание",
                "4 вдох → 4 пауза → 4 выдох → 4 пауза",
                "Техника спецназа для контроля стресса.", AppColors.pastelMint,
                () => _choose("box", "📦  Коробочное дыхание",
                    "4-4-4-4. Техника спецназа.")),
            _itemCard("🐝  Пчелиное дыхание",
                "Вдох → выдох с жужжанием «мммм»",
                "Bhramari — снимает тревогу за 1 минуту.", AppColors.pastelYellow,
                () => _choose("bee", "🐝  Пчелиное дыхание",
                    "На выдохе жужжи «мммм».")),
            _itemCard("🫃  Брюшное дыхание", "Дыши животом, а не грудью",
                "Диафрагмальное дыхание — базовое упражнение.", AppColors.pastelBlue,
                () => _choose("belly", "🫃  Брюшное дыхание",
                    "Дыши животом, а не грудью.")),
          ],
          if (_inPractice) ...[
            Center(
              child: Text(_title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text)),
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                height: 260,
                width: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeInOut,
                      width: _circleSize,
                      height: _circleSize,
                      decoration: const BoxDecoration(
                        color: AppColors.mint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(_phaseText,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                    Positioned(
                      bottom: 20,
                      child: Text(
                        _secondsLeft > 0 ? "$_secondsLeft" : "",
                        style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Center(
              child: Text("Цикл: $_cycle / 4",
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.primaryDark)),
            ),
            Center(
              child: Text(_hint,
                  style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.purpleDeep)),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                    minimumSize: const Size(140, 45),
                  ),
                  onPressed: _start,
                  child: const Text("▶  Начать",
                      style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pastelPink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                    minimumSize: const Size(90, 45),
                  ),
                  onPressed: _stop,
                  child: const Text("Стоп",
                      style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () {
                _timer?.cancel();
                setState(() => _inPractice = false);
              },
              child: const Text("← Назад к списку",
                  style: TextStyle(
                      color: AppColors.purpleDeep,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemCard(String title, String desc, String hint, Color bg,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text)),
            const SizedBox(height: 3),
            Text(desc,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.primaryDark)),
            const SizedBox(height: 3),
            Text(hint,
                style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.purpleDeep)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🧘 MEDITATION SCREEN — 4 медитации
// ==========================================
class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});
  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  bool _inSession = false;
  int _minutes = 5;
  int _secondsLeft = 0;
  Timer? _timer;
  bool _playing = false;
  String _title = "";

  void _startSession(String title, int minutes) {
    setState(() {
      _inSession = true;
      _title = title;
      _minutes = minutes;
      _secondsLeft = minutes * 60;
      _playing = false;
    });
  }

  void _togglePlay() {
    if (_playing) {
      _timer?.cancel();
      setState(() => _playing = false);
    } else {
      setState(() => _playing = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 0) {
          _timer?.cancel();
          setState(() {
            _playing = false;
            _secondsLeft = 0;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return "$m:$sec";
  }

  @override
  Widget build(BuildContext context) {
    if (_inSession) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Center(
              child: Text(_title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text)),
            ),
            const SizedBox(height: 40),
            Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.pastelMint,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purpleLight.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(_format(_secondsLeft),
                      style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                "Закрой глаза. Дыши ровно.\nЕсли мысли приходят — просто заметь их и отпусти.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primaryDark),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _playing ? AppColors.pastelPink : AppColors.mint,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                  ),
                  onPressed: _togglePlay,
                  child: Text(_playing ? "⏸" : "▶",
                      style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.background,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(20),
                  ),
                  onPressed: () {
                    _timer?.cancel();
                    setState(() {
                      _inSession = false;
                      _playing = false;
                    });
                  },
                  child: const Text("⏹",
                      style: TextStyle(fontSize: 24)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text("🧘  Медитации",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text)),
          ),
          const SizedBox(height: 5),
          const Center(
            child: Text("Тишина внутри тебя",
                style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primaryDark)),
          ),
          const SizedBox(height: 25),
          _medCard("🌅  Утреннее спокойствие",
              "5 минут для ясного начала дня", 5, AppColors.pastelYellow),
          _medCard("🌙  Вечернее расслабление",
              "10 минут перед сном", 10, AppColors.pastelBlue),
          _medCard("💜  Медитация на тревогу",
              "7 минут, чтобы успокоить мысли", 7, AppColors.pastelPink),
          _medCard("🌿  Медитация на благодарность",
              "5 минут, чтобы заметить хорошее", 5, AppColors.pastelGreen),
          _medCard("🌸  Нежная медитация",
              "10 минут мягкого принятия себя", 10, AppColors.pastelMint),
        ],
      ),
    );
  }

  Widget _medCard(String title, String desc, int minutes, Color bg) {
    return GestureDetector(
      onTap: () => _startSession(title, minutes),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  const SizedBox(height: 4),
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.primaryDark)),
                  const SizedBox(height: 4),
                  Text("$minutes мин",
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.purpleDeep)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_filled,
                size: 40, color: AppColors.purpleDeep),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🆘 EMERGENCY SCREEN
// ==========================================
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE5E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE5E5),
        elevation: 0,
        title: const Text("🚨  Экстренная помощь",
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
                child: Text("Тебе плохо прямо сейчас?",
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text)),
              ),
              const SizedBox(height: 5),
              const Center(
                child: Text("Ты не один(а). Давай вместе.",
                    style: TextStyle(
                        fontSize: 14, color: AppColors.primaryDark)),
              ),
              const SizedBox(height: 25),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text("☎  ТЕЛЕФОН ДОВЕРИЯ",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark)),
                    const SizedBox(height: 8),
                    const Text("8 801 100 16 11",
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger)),
                    const Text("Анонимно, круглосуточно, бесплатно",
                        style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.primaryDark)),
                    const SizedBox(height: 15),
                    const Text(
                      "Тебя не заберут, если нет прямой угрозы жизни.\nТебе просто помогут.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text("Что делать прямо сейчас:",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text)),
              const SizedBox(height: 10),
              _actionCard("🌬", "Дыхание 4-7-8", "Вдох 4 → задержка 7 → выдох 8",
                  AppColors.pastelGreen, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const _EmergencyBreathing()),
                );
              }),
              _actionCard("🌊", "Квадратное дыхание",
                  "4 сек вдох → 4 пауза → 4 выдох → 4 пауза",
                  AppColors.pastelBlue, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const _EmergencyBreathing()),
                );
              }),
              _actionCard("🧘", "Заземление 5-4-3-2-1",
                  "5 вижу, 4 слышу, 3 ощущаю, 2 запаха, 1 вкус",
                  AppColors.pastelPeach, () {
                showDialog(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text("Заземление"),
                    content: Text(
                        "5 — вещей, которые видишь\n4 — звука, которые слышишь\n3 — предмета, которых касаешься\n2 — запаха, которые чувствуешь\n1 — вкус, который ощущаешь"),
                  ),
                );
              }),
              const SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB6D9),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(20),
                child: const Text(
                  "«Это пройдёт. Ты справишься. Ты уже справляешься.»",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mint,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () =>
                    MainWindow.of(context)?.setCustomScreen(null),
                child: const Text("Мне уже лучше 💜",
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard(String emoji, String title, String subtitle, Color bg,
      VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.primaryDark)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(10),
              elevation: 0,
            ),
            onPressed: onTap,
            child: const Text("▶",
                style: TextStyle(
                    color: AppColors.purpleDeep,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// Простой экран дыхания для экстренной помощи
class _EmergencyBreathing extends StatefulWidget {
  const _EmergencyBreathing();
  @override
  State<_EmergencyBreathing> createState() => _EmergencyBreathingState();
}

class _EmergencyBreathingState extends State<_EmergencyBreathing> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text("Дыхание 4-7-8",
            style: TextStyle(
                color: AppColors.text, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "Дыши с нами:\n\n1. Вдох на 4 секунды\n2. Задержка на 7 секунд\n3. Выдох на 8 секунд\n\nПовтори 4 раза.\n\n💜 Ты справляешься.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18, height: 1.6, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 🆘 SELF-HELP SCREEN
// ==========================================
class SelfHelpScreen extends StatelessWidget {
  const SelfHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text("🆘  Что делать если...",
            style: TextStyle(
                color: AppColors.text, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...crisisProtocols.map((p) => _card(context, p)),
              const SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.pastelYellow,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(15),
                child: const Text(
                  "Если совсем тяжело — позвони на телефон доверия 8 801 100 16 11. Анонимно, круглосуточно. Тебя не заберут, если нет прямой угрозы жизни.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, CrisisProtocol p) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProtocolDetailScreen(protocol: p)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: p.color,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Text(p.emoji, style: const TextStyle(fontSize: 38)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  const SizedBox(height: 3),
                  Text(p.subtitle,
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

class ProtocolDetailScreen extends StatelessWidget {
  final CrisisProtocol protocol;
  const ProtocolDetailScreen({super.key, required this.protocol});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: protocol.color,
        elevation: 0,
        title: Text("${protocol.emoji}  ${protocol.title}",
            style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(protocol.subtitle,
                  style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primaryDark)),
              const SizedBox(height: 20),
              ...protocol.steps.map((s) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                      left: BorderSide(color: protocol.color, width: 5),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s["t"]!,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text)),
                      const SizedBox(height: 8),
                      Text(s["d"]!,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.text,
                              height: 1.4)),
                      if (s["a"] != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: protocol.color.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("👉 ", style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(s["a"]!,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.text,
                                        height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              Container(
                decoration: BoxDecoration(
                  color: protocol.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Text(
                  protocol.closing,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                      height: 1.4),
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
  final List<ChatMessage> _messages = [
    ChatMessage(
        role: 'assistant',
        content: 'Привет 💜 Я здесь, чтобы выслушать. Что случилось?'),
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
            content:
                'Извини, ключ Groq не введён. Закрой приложение и введи ключ при регистрации, или перезапусти приложение.\n\nПока могу предложить: открой «Что делать если...» — там есть готовые техники.'));
      });
      _controller.clear();
      _scrollDown();
      return;
    }

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
    });
    _controller.clear();
    _scrollDown();

    try {
      final ai = AiService(AppState.apiKey);
      final reply = await ai.chat(_messages);
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Ошибка: $e'));
        _loading = false;
      });
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
        elevation: 0,
        title: const Text("🤖  ИИ-психолог",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {
              _messages.clear();
              _messages.add(ChatMessage(
                  role: 'assistant',
                  content: 'Привет 💜 Давай начнём сначала. Что случилось?'));
            }),
          ),
        ],
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
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.purpleDeep : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                      ),
                      child: Text(
                        m.content,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: isUser ? Colors.white : AppColors.text,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('печатает...',
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AppColors.primaryDark)),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'Напиши, что чувствуешь...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.purpleDeep,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _loading ? null : _send,
                    ),
                  ),
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

  @override
  Widget build(BuildContext context) {
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
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    items: _types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: TextField(
                      controller: _text,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(border: InputBorder.none),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                            emoji: _emoji(_type),
                          ));
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
          ...AppState.entries.map((e) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _color(e.type),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(e.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(e.type,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text)),
                      const SizedBox(width: 8),
                      Text(
                        "${e.date.day.toString().padLeft(2, '0')}.${e.date.month.toString().padLeft(2, '0')} ${e.date.hour.toString().padLeft(2, '0')}:${e.date.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(e.text,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.text)),
                ],
              ),
            );
          }),
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

  @override
  Widget build(BuildContext context) {
    int days = 1;
    final dates = [
      ...AppState.moods.map((m) => m.date),
      ...AppState.entries.map((e) => e.date),
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
                    style: const TextStyle(fontSize: 60)),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Center(
            child: Text(AppState.userName.isEmpty ? "Друг" : AppState.userName,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text)),
          ),
          Center(
            child: Text(
                AppState.age.isEmpty ? "Возраст не указан" : "${AppState.age} лет",
                style: const TextStyle(
                    fontSize: 14, color: AppColors.primaryDark)),
          ),
          const SizedBox(height: 25),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pastelMint,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () => MainWindow.of(context)
                ?.setCustomScreen(const EmotionMapScreen()),
            child: const Text("🎨  Карта эмоций",
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pastelBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () => MainWindow.of(context)
                ?.setCustomScreen(const LinksScreen()),
            child: const Text("🔗  Полезные ссылки",
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 15),
          Container(
            decoration: BoxDecoration(
              color: AppColors.pastelGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(15),
            child: const Row(
              children: [
                Text("🔒", style: TextStyle(fontSize: 22)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Все данные хранятся только у тебя на устройстве.",
                    style: TextStyle(fontSize: 12, color: AppColors.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pastelPink,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              minimumSize: const Size.fromHeight(45),
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
                      onPressed: () {
                        AppState.clear();
                        Navigator.pop(ctx);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const PsyApp()),
                          (r) => false,
                        );
                      },
                      child: const Text("Да"),
                    ),
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

  Widget _stat(String c, String l, Color color) {
    return Column(
      children: [
        Text(c,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        Text(l,
            style:
                const TextStyle(fontSize: 12, color: AppColors.primaryDark)),
      ],
    );
  }
}

// ==========================================
// 🎨 EMOTION MAP SCREEN
// ==========================================
class EmotionMapScreen extends StatefulWidget {
  const EmotionMapScreen({super.key});
  @override
  State<EmotionMapScreen> createState() => _EmotionMapScreenState();
}

class _EmotionMapScreenState extends State<EmotionMapScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  final List<String> _monthNames = [
    "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
    "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь",
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
      final match = AppState.moods.where((m) =>
          m.date.year == date.year &&
          m.date.month == date.month &&
          m.date.day == date.day);

      Color color = const Color(0xFFF0F0F0);
      String emoji = "";

      if (date.isAfter(DateTime.now())) {
        color = const Color(0xFFFAFAFA);
      } else if (match.isNotEmpty) {
        final m = match.first.mood;
        totalMarks++;
        moodCounts[m] = (moodCounts[m] ?? 0) + 1;
        switch (m) {
          case "Злость":
            color = const Color(0xFFE74C3C);
            emoji = "😡";
            break;
          case "Грусть":
            color = const Color(0xFF5DADE2);
            emoji = "😢";
            break;
          case "Тревога":
            color = const Color(0xFFF5B041);
            emoji = "😰";
            break;
          case "Апатия":
            color = const Color(0xFFAAB7B8);
            emoji = "😐";
            break;
          case "Нейтрально":
            color = const Color(0xFFF7DC6F);
            emoji = "🙂";
            break;
          case "Радость":
            color = const Color(0xFF82E0AA);
            emoji = "😊";
            break;
          case "Счастье":
            color = const Color(0xFFF1948A);
            emoji = "😍";
            break;
        }
      }

      cells.add(
        Container(
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
                        color: AppColors.text)),
              ),
              if (emoji.isNotEmpty)
                Positioned(
                  bottom: 2,
                  child: Text(emoji, style: const TextStyle(fontSize: 14)),
                ),
            ],
          ),
        ),
      );
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
        title: const Text("🎨  Карта эмоций",
            style: TextStyle(
                color: AppColors.text, fontWeight: FontWeight.bold)),
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
                    }),
                  ),
                  Text(
                      "${_monthNames[_month.month - 1]} ${_month.year}",
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
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text("Пн", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                        Text("Вт", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                        Text("Ср", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                        Text("Чт", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                        Text("Пт", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                        Text("Сб", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                        Text("Вс", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: cells,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.pastelYellow,
                  borderRadius: BorderRadius.circular(14),
                ),
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

// ==========================================
// 🔗 LINKS SCREEN
// ==========================================
class LinksScreen extends StatelessWidget {
  const LinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text("🔗  Полезные ссылки",
            style: TextStyle(
                color: AppColors.text, fontWeight: FontWeight.bold)),
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
                  AppColors.pastelPink, () {
                showDialog(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text("Телефон доверия"),
                    content: Text(
                        "8 801 100 16 11\n\nКруглосуточно, анонимно, бесплатно.\nТы не одна."),
                  ),
                );
              }),
              _link("🌐", "psy.help",
                  "Белорусский портал психологической помощи",
                  AppColors.pastelGreen, () => _notice(context, "psy.help")),
              _link("🧘", "Insight Timer",
                  "Бесплатные медитации на русском",
                  AppColors.pastelMint,
                  () => _notice(context, "insighttimer.com")),
              _link("📚", "Книги по психологии",
                  "Бесплатные книги и статьи",
                  AppColors.pastelYellow, () => _notice(context, "bookscafe.net")),
              _link("💬", "pomogut.by",
                  "Помощь подросткам и молодёжи",
                  AppColors.pastelBlue, () => _notice(context, "pomogut.by")),
              _link("📱", "Медитации на YouTube",
                  "Каналы с бесплатными практиками",
                  AppColors.pastelPeach, () => _notice(context, "youtube.com")),
            ],
          ),
        ),
      ),
    );
  }

  void _notice(BuildContext context, String site) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Открытие ссылки: $site")),
    );
  }

  Widget _link(String icon, String title, String desc, Color bg,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
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
                          fontSize: 12, color: AppColors.primaryDark)),
                ],
              ),
            ),
            const Text("→",
                style: TextStyle(fontSize: 22, color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}