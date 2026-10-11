import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 🎨 ЦВЕТА — мягкие, светлые, приятные
// ==========================================
class AppColors {
  static const Color primary = Color(0xFF5B21B6);
  static const Color primaryDark = Color(0xFF7C3AED);
  static const Color background = Color(0xFFF3E5FF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF3B0764);
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

// ==========================================
// 📦 МОДЕЛИ
// ==========================================
class DiaryEntry {
  String type;
  String text;
  String emoji;
  DateTime date;
  DiaryEntry({
    this.type = "Идея",
    this.text = "",
    this.emoji = "💡",
    DateTime? date,
  }) : date = date ?? DateTime.now();
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
    apiKey = "";
    entries.clear();
    moods.clear();
  }
}

// ==========================================
// 💡 СОВЕТЫ ДНЯ
// ==========================================
final List<String> dailyTips = [
  "Ты справляешься лучше, чем тебе кажется. 💜",
  "Твои чувства — настоящие. Ты имеешь право их испытывать. 🌸",
  "Один шаг — уже движение. Не требуй от себя всего сразу. ✨",
  "Ты не обязан(а) быть сильным(ой) всё время. Отдых — это тоже забота. 🌿",
  "Каждый день — новая возможность начать заново. 🌅",
  "Твоё «нет» — это забота о себе. 🛡",
  "Дыши. Всё, что ты сейчас чувствуешь, — пройдёт. 🌊",
  "Ты важен(на) — просто потому что ты есть. 💫",
  "Не сравнивай свой путь с чужим. У каждого — своя скорость. 🐢",
  "Даже маленькая победа — это победа. Отмечай их. 🎉",
  "Позволь себе быть неидеальным(ой). Идеальных нет. 🌷",
  "Усталость — не слабость. Это сигнал, что пора отдохнуть. 😴",
  "Ты уже пережил(а) 100% своих худших дней. 💪",
  "Твои границы — это не эгоизм. Это уважение к себе. 🚪",
  "Просить помощи — это смелость, а не слабость. 🤝",
  "Замечай хорошее. Даже если это просто чашка чая. ☕",
  "Ты не одна(один). Даже если сейчас так кажется. 🌍",
  "Плохие дни не означают плохую жизнь. 🌦",
  "Твоя ценность не зависит от продуктивности. 💎",
  "Сегодня можно сделать меньше. И этого достаточно. 🤍",
];

// ==========================================
// 🤖 ИИ-СЕРВИС
// ==========================================
class AiService {
  final String apiKey;
  final String systemPrompt;
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
      return '⚠ Не получилось связаться с ИИ.\n\nПроверь:\n1. Ключ Groq введён (начинается с gsk_)\n2. Есть интернет';
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
    color: const Color(0xFFC4B5FD),
    steps: [
      {
        "t": "1. Останови мгновение",
        "d": "Мысли о смерти — это не желание умереть. Это желание, чтобы боль закончилась.",
        "a": "Скажи вслух: «Я хочу не умереть. Я хочу, чтобы перестало болеть.»"
      },
      {
        "t": "2. Ты в безопасности?",
        "d": "Если ты уже причинил(а) себе вред — вызови 103.",
        "a": "Отложи всё опасное в другую комнату."
      },
      {
        "t": "3. Правило 5 минут",
        "d": "Пик импульса длится 5–20 минут.",
        "a": "Поставь таймер. Дыши: 4 вдох → 7 задержка → 8 выдох."
      },
      {
        "t": "4. Заземлись",
        "d": "Тело возвращает в «сейчас».",
        "a": "5 видишь → 4 слышишь → 3 касаешься → 2 запаха → 1 вкус."
      },
      {
        "t": "5. Обратись к кому-то",
        "d": "Одиночество усиливает боль.",
        "a": "Напиши: «Мне плохо, побудь со мной.»"
      },
      {
        "t": "6. Отложи решение",
        "d": "Решение в пике боли — не настоящее.",
        "a": "«Я вернусь к этому через 24 часа.»"
      },
    ],
    closing: "Ты важен(на). Твоя боль реальна, но она не навсегда. 💜",
  ),
  CrisisProtocol(
    emoji: "💓",
    title: "Паническая атака",
    subtitle: "Сердце колотится, не хватает воздуха",
    color: const Color(0xFFFBCFE8),
    steps: [
      {
        "t": "1. Ты не умираешь",
        "d": "Паника неприятна, но НЕ опасна. Пройдёт через 5–20 минут."
      },
      {
        "t": "2. Найди опору",
        "d": "Сядь. Почувствуй спиной стул.",
        "a": "Надави стопами в пол 5 секунд. Повтори 3 раза."
      },
      {
        "t": "3. Дыхание 4-7-8",
        "d": "Замедляет пульс.",
        "a": "Вдох 4 → задержка 7 → выдох 8. 4 раза."
      },
      {
        "t": "4. Холод",
        "d": "Активирует «нырятельный рефлекс».",
        "a": "Умойся ледяной водой."
      },
      {"t": "5. Отвлеки мозг", "d": "Назови вслух 5 предметов вокруг."},
      {
        "t": "6. Мантра",
        "d": "Повторяй:",
        "a": "«Это паника. Она не убьёт. Я в безопасности.»"
      },
    ],
    closing: "Ты справился(ась). Сердце — не враг. 🌸",
  ),
  CrisisProtocol(
    emoji: "🌙",
    title: "Бессонница",
    subtitle: "Не могу уснуть",
    color: const Color(0xFFDBEAFE),
    steps: [
      {
        "t": "1. Правило 20 минут",
        "d": "Не уснул(а) — встань.",
        "a": "Перейди в другое место."
      },
      {
        "t": "2. Дыхание 4-7-8",
        "d": "Включает режим «отдых».",
        "a": "3 цикла."
      },
      {
        "t": "3. Выгрузи мысли",
        "d": "Мозг держит то, что не записано.",
        "a": "5 минут пиши ВСЁ."
      },
      {
        "t": "4. Прогрессивная релаксация",
        "d": "Напряги-расслабь мышцы.",
        "a": "Стопы → голени → бёдра → живот → руки → плечи → лицо."
      },
      {
        "t": "5. Не смотри на часы",
        "d": "Проверка времени = тревога.",
        "a": "Разверни телефон."
      },
    ],
    closing: "Одна ночь не разрушит тебя. 🌙",
  ),
  CrisisProtocol(
    emoji: "🌊",
    title: "Сильная тревога",
    subtitle: "Внутри всё сжимается",
    color: const Color(0xFFFED7AA),
    steps: [
      {
        "t": "1. Назови тревогу",
        "d": "Неопределённая тревога сильнее.",
        "a": "«Я тревожусь о ___.»"
      },
      {"t": "2. Факт vs страх", "d": "Тревога путает реальность с прогнозом."},
      {"t": "3. Шкала 0-10", "d": "Оцени тревогу."},
      {
        "t": "4. Удлинённый выдох",
        "d": "Выдох длиннее вдоха = безопасность.",
        "a": "Вдох 4 → выдох 8. 5 минут."
      },
      {
        "t": "5. Движение",
        "d": "Тревога — это энергия.",
        "a": "20 приседаний."
      },
      {
        "t": "6. Маленькое действие",
        "d": "Тревога живёт в бездействии.",
        "a": "Сделай что-то на 2 минуты."
      },
    ],
    closing: "Тревога — не приговор. 💜",
  ),
  CrisisProtocol(
    emoji: "🔥",
    title: "Гнев / агрессия",
    subtitle: "Хочется кричать",
    color: const Color(0xFFFECACA),
    steps: [
      {
        "t": "1. Выйди из ситуации",
        "d": "Гнев длится 90 секунд.",
        "a": "«Мне нужно 5 минут.»"
      },
      {"t": "2. Сбрось энергию", "d": "Через мышцы.", "a": "20 приседаний."},
      {"t": "3. Дыхание", "d": "Вдох 4 → задержка 4 → выдох 6."},
      {"t": "4. Отдели гнев от действия", "d": "Чувство — ок. Крик/удар — нет."},
      {"t": "5. Что за гневом?", "d": "Под гневом: боль, страх, стыд."},
      {
        "t": "6. Разговор потом",
        "d": "Сейчас не время.",
        "a": "Вернись через 20–30 минут."
      },
    ],
    closing: "Ты не плохой человек. Тебе больно. 🔥",
  ),
  CrisisProtocol(
    emoji: "🩹",
    title: "Тяга к самоповреждению",
    subtitle: "Хочется порезать себя",
    color: const Color(0xFFE9D5FF),
    steps: [
      {"t": "1. Отложи на 15 минут", "d": "Импульс длится недолго.", "a": "Поставь таймер."},
      {"t": "2. Убери предметы", "d": "Сделай импульс недоступным."},
      {
        "t": "3. Замени ощущение",
        "d": "Дай мозгу сигнал безопасно.",
        "a": "Лёд к запястью. Резинка. Холодный душ."
      },
      {"t": "4. Что ты хочешь почувствовать?", "d": "Контроль? Наказание? Облегчение?"},
      {
        "t": "5. Скажи кому-то",
        "d": "Ты не один(одна).",
        "a": "«Мне плохо. Мне страшно за себя.»"
      },
      {
        "t": "6. Дыши с задержкой",
        "d": "Контроль без вреда.",
        "a": "Вдох 4 → задержка 4 → выдох 4."
      },
    ],
    closing: "Ты заслуживаешь не боли, а заботы. 🩹",
  ),
  CrisisProtocol(
    emoji: "💧",
    title: "Истерика / слёзы",
    subtitle: "Не могу остановиться",
    color: const Color(0xFFBFDBFE),
    steps: [
      {"t": "1. Позволь плакать", "d": "Слёзы лечат.", "a": "«Я имею право плакать.»"},
      {"t": "2. Безопасное место", "d": "Сядь. Укройся пледом."},
      {"t": "3. Удлинённый выдох", "d": "Вдох 4 → выдох 8.", "a": "10 циклов."},
      {"t": "4. Телесный контакт", "d": "Обними себя.", "a": "«Я с тобой.»"},
      {"t": "5. Вода", "d": "Выпей стакан воды."},
      {"t": "6. Один ориентир", "d": "Опиши 1 предмет вслух."},
    ],
    closing: "Слёзы — язык тела. 🌸",
  ),
  CrisisProtocol(
    emoji: "🌫",
    title: "Диссоциация",
    subtitle: "Всё как в тумане",
    color: const Color(0xFFE0F2E9),
    steps: [
      {"t": "1. Это защита", "d": "Мозг отключил чувства, чтобы выжить."},
      {
        "t": "2. Температура",
        "d": "Холод или тепло возвращают.",
        "a": "Холодная вода или горячая чашка."
      },
      {"t": "3. Заземление 5-4-3-2-1", "d": "По одному на орган чувств."},
      {"t": "4. Движение", "d": "Диссоциация — замирание.", "a": "Потопай, похлопай себя."},
      {
        "t": "5. Скажи вслух",
        "d": "Проговори факты о себе.",
        "a": "«Меня зовут ___. Я в комнате, я в безопасности.»"
      },
      {"t": "6. Связь с другим", "d": "Голос возвращает.", "a": "Позвони кому-то."},
    ],
    closing: "Ты возвращаешься. Каждый шаг — якорь. 🌫",
  ),
];

// ==========================================
// 🎭 ПЕРСОНАЖИ
// ==========================================
class RoleCharacter {
  final String emoji;
  final String name;
  final String prompt;
  final Color color;
  const RoleCharacter({
    required this.emoji,
    required this.name,
    required this.prompt,
    required this.color,
  });
}

final List<RoleCharacter> roleCharacters = [
  RoleCharacter(
    emoji: "🏛",
    name: "Сократ",
    color: const Color(0xFFDBEAFE),
    prompt:
        'Ты — Сократ. Задаёшь глубокие вопросы, не даёшь готовых ответов. Помогаешь человеку самому прийти к истине через диалог. Говори мудро, но просто, по-русски. Задавай по одному вопросу.',
  ),
  RoleCharacter(
    emoji: "👵",
    name: "Строгая бабушка",
    color: const Color(0xFFFED7AA),
    prompt:
        'Ты — строгая, но любящая бабушка. Говоришь прямо, без сюсюканья. Можешь сказать «не ной», но всегда с любовью. Даёшь жизненные советы из опыта.',
  ),
  RoleCharacter(
    emoji: "💪",
    name: "Тренер",
    color: const Color(0xFFD1FAE5),
    prompt:
        'Ты — жёсткий, но справедливый тренер. Мотивируешь, не даёшь себя жалеть. Говоришь короткими фразами. Спрашиваешь: «Что ты можешь сделать прямо сейчас?»',
  ),
  RoleCharacter(
    emoji: "🧒",
    name: "Внутренний ребёнок",
    color: const Color(0xFFFBCFE8),
    prompt:
        'Ты — внутренний ребёнок человека. Говоришь наивно, искренне, напрямую. Можешь сказать «я боюсь», «мне больно», «я хочу чтобы меня обняли». Помогаешь взрослому услышать свои настоящие чувства.',
  ),
  RoleCharacter(
    emoji: "🔮",
    name: "Будущий ты",
    color: const Color(0xFFE9D5FF),
    prompt:
        'Ты — этот же человек, но через 10 лет. Ты уже прошёл через то, что сейчас у него. Говоришь с теплом и мудростью. Спрашиваешь: «Ты правда этого хочешь или отмазываешься?» Даёшь советы из будущего.',
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
// 🧭 КОРНЕВОЙ ЭКРАН — с сохранением регистрации
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
      AppState.age = prefs.getString('age') ?? '';
      AppState.avatar = prefs.getString('avatar') ?? '🌸';
      AppState.apiKey = prefs.getString('apiKey') ?? '';
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
  }

  @override
  Widget build(BuildContext context) {
    if (_registered == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text("🌸", style: TextStyle(fontSize: 80)),
        ),
      );
    }

    if (_registered == false) {
      return RegistrationScreen(
        onDone: () async {
          await _saveUser();
          setState(() => _registered = true);
        },
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
    {"emoji": "🌸", "color": const Color(0xFFFBCFE8)},
    {"emoji": "🌿", "color": const Color(0xFFD1FAE5)},
    {"emoji": "⭐", "color": const Color(0xFFFEF9C3)},
    {"emoji": "🌙", "color": const Color(0xFFDBEAFE)},
  ];
  final List<Map<String, dynamic>> _row2 = [
    {"emoji": "🔥", "color": const Color(0xFFFECACA)},
    {"emoji": "💧", "color": const Color(0xFFBFDBFE)},
    {"emoji": "🌺", "color": const Color(0xFFFBCFE8)},
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
  int _currentTab = 2;
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
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: AppColors.primary),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _nav(Icons.air_rounded, 0),
                _nav(Icons.self_improvement, 1),
                _nav(Icons.home_rounded, 2),
                _nav(Icons.book_rounded, 3),
                _nav(Icons.person_rounded, 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nav(IconData icon, int index) {
    final sel = _customScreen == null && _currentTab == index;
    return GestureDetector(
      onTap: () => switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: sel ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          icon,
          size: 30,
          color: sel ? Colors.white : Colors.white60,
        ),
      ),
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
  late String _tipOfDay;

  @override
  void initState() {
    super.initState();
    _tipOfDay = dailyTips[Random().nextInt(dailyTips.length)];
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
          const SizedBox(height: 22),

          // SOS кнопка
          GestureDetector(
            onTap: () => MainWindow.of(context)
                ?.setCustomScreen(const SosAnchorScreen()),
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
                    offset: const Offset(0, 6),
                  ),
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
          const SizedBox(height: 14),

          // Ряд 1
          Row(
            children: [
              Expanded(
                child: _bigCard(
                  emoji: "🤖",
                  title: "Поговорить с ИИ",
                  color: AppColors.purpleDeep,
                  onTap: () => MainWindow.of(context)
                      ?.setCustomScreen(const AiTherapistScreen()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _bigCard(
                  emoji: "🆘",
                  title: "Что делать если...",
                  color: AppColors.purpleMedium,
                  onTap: () => MainWindow.of(context)
                      ?.setCustomScreen(const SelfHelpScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Ряд 2
          Row(
            children: [
              Expanded(
                child: _bigCard(
                  emoji: "🎭",
                  title: "Примерка ролей",
                  color: AppColors.purpleLight,
                  onTap: () => MainWindow.of(context)
                      ?.setCustomScreen(const RolePlayScreen()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _bigCard(
                  emoji: "🕵️",
                  title: "Тренажёр разговоров",
                  color: AppColors.primaryDark,
                  onTap: () => MainWindow.of(context)
                      ?.setCustomScreen(const ConversationTrainerScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Детектор искажений
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pastelMint,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size.fromHeight(56),
              elevation: 0,
            ),
            onPressed: () => MainWindow.of(context)
                ?.setCustomScreen(const DistortionDetectorScreen()),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("🕵️", style: TextStyle(fontSize: 20)),
                SizedBox(width: 10),
                Text("Детектор когнитивных искажений",
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Настроение
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.all(isSel ? 8 : 4),
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
                      style: TextStyle(
                          fontSize: isSel ? 38 : 32,
                          height: 1.1)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mint,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              minimumSize: const Size.fromHeight(48),
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
          const SizedBox(height: 18),

          // 🎨 Календарь эмоций
          GestureDetector(
            onTap: () => MainWindow.of(context)
                ?.setCustomScreen(const EmotionMapScreen()),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.pastelMint,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text("🎨", style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Календарь эмоций",
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text)),
                        Text("Посмотри прошлые дни",
                            style: TextStyle(
                                fontSize: 12, color: AppColors.primaryDark)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: AppColors.text),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),

          // Совет дня
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFBCFE8), Color(0xFFFCE7F3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("💡  Совет дня",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark)),
                const SizedBox(height: 8),
                Text(_tipOfDay,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.text, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Тепловая карта
          GestureDetector(
            onTap: () => MainWindow.of(context)
                ?.setCustomScreen(const HeatMapScreen()),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text("🔥", style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Тепловая карта года",
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text)),
                        Text("Смотри свои эмоциональные паттерны",
                            style: TextStyle(
                                fontSize: 12, color: AppColors.primaryDark)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: AppColors.text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigCard({
    required String emoji,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🫁 BREATHING SCREEN
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
  int _phase = 0;
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
      _circleSize = 240;
    } else if (_phase == 1) {
      _phaseText = "Задержи...";
      _secondsLeft = holdT;
      _circleSize = 240;
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
                height: 280,
                width: 280,
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
                      bottom: 30,
                      child: Text(
                        _secondsLeft > 0 ? "$_secondsLeft" : "",
                        style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final done = i < _cycle;
                final current = i == _cycle;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: current ? 22 : 14,
                    height: current ? 22 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppColors.purpleDeep
                          : current
                              ? AppColors.purpleLight
                              : Colors.white.withValues(alpha: 0.6),
                      border: Border.all(
                        color: current
                            ? AppColors.primaryDark
                            : AppColors.purpleDeep.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text("Цикл: $_cycle / 4",
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.primaryDark)),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(_hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.purpleDeep)),
            ),
            const SizedBox(height: 18),
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
// 🧘 MEDITATION SCREEN
// ==========================================
class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});
  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  bool _inSession = false;
  int _totalSeconds = 0;
  int _secondsLeft = 0;
  Timer? _timer;
  bool _playing = false;
  String _title = "";

  void _startSession(String title, int minutes) {
    setState(() {
      _inSession = true;
      _title = title;
      _totalSeconds = minutes * 60;
      _secondsLeft = _totalSeconds;
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
      final progress = _totalSeconds == 0
          ? 0.0
          : (_totalSeconds - _secondsLeft) / _totalSeconds;

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
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
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.5),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.purpleDeep),
                      ),
                    ),
                    Container(
                      width: 180,
                      height: 180,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.pastelMint, Color(0xFFD1FAE5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(_format(_secondsLeft),
                            style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text)),
                      ),
                    ),
                  ],
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
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _playing ? AppColors.pastelPink : AppColors.mint,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(22),
                  ),
                  onPressed: _togglePlay,
                  child: Text(_playing ? "⏸" : "▶",
                      style: const TextStyle(fontSize: 26)),
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
                  child: const Text("⏹", style: TextStyle(fontSize: 22)),
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
                borderRadius: BorderRadius.circular(16),
              ),
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
                  const Text("Тип записи",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark)),
                  const SizedBox(height: 6),
                  DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    items: _types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 12),
                  const Text("Текст",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
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

          ...grouped.entries.map((groupEntry) {
            final dayEntries = groupEntry.value;
            final firstDate = dayEntries.first.date;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.purpleDeep,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _dayLabel(firstDate),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${dayEntries.length} ${dayEntries.length == 1 ? "запись" : "записей"}",
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
                ...dayEntries.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _color(e.type),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
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
                                  fontSize: 11, color: AppColors.primaryDark),
                            ),
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
                  );
                }),
              ],
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

          Row(
            children: [
              Expanded(
                child: _bigButton(
                  emoji: "🎨",
                  title: "Календарь эмоций",
                  color: AppColors.pastelMint,
                  onTap: () => MainWindow.of(context)
                      ?.setCustomScreen(const EmotionMapScreen()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _bigButton(
                  emoji: "🔗",
                  title: "Полезные ссылки",
                  color: AppColors.pastelBlue,
                  onTap: () => MainWindow.of(context)
                      ?.setCustomScreen(const LinksScreen()),
                ),
              ),
            ],
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
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  AppState.clear();
  if (ctx.mounted) Navigator.pop(ctx);
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PsyApp()),
      (r) => false,
    );
  }
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
            style: const TextStyle(fontSize: 12, color: AppColors.primaryDark)),
      ],
    );
  }

  Widget _bigButton({
    required String emoji,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
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
}

// ==========================================
// 🆘 SOS ANCHOR SCREEN
// ==========================================
class SosAnchorScreen extends StatefulWidget {
  const SosAnchorScreen({super.key});
  @override
  State<SosAnchorScreen> createState() => _SosAnchorScreenState();
}

class _SosAnchorScreenState extends State<SosAnchorScreen> {
  int _phase = 0;
  int _secondsLeft = 4;
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF1F1),
        elevation: 0,
        title: const Text("🆘  Якорь",
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
                child: Text(
                  "Нажми «Начать» и дыши с нами.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.mint.withValues(alpha: 0.5),
                        blurRadius: _running ? 40 : 10,
                        spreadRadius: _running ? 20 : 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_phaseText,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text)),
                        const SizedBox(height: 8),
                        Text(_running ? "$_secondsLeft" : "—",
                            style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _running ? AppColors.pastelPink : AppColors.mint,
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
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(16),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Если совсем тяжело:",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                    SizedBox(height: 6),
                    Text("☎  Телефон доверия: 8 801 100 16 11",
                        style: TextStyle(
                            fontSize: 13, color: AppColors.text)),
                    Text("📝  Напиши близкому: «Мне плохо, побудь со мной»",
                        style: TextStyle(
                            fontSize: 13, color: AppColors.text)),
                    Text("🚶  Умойся холодной водой",
                        style: TextStyle(
                            fontSize: 13, color: AppColors.text)),
                    Text("🧊  Лёд к запястью на 30 секунд",
                        style: TextStyle(
                            fontSize: 13, color: AppColors.text)),
                  ],
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
              const Center(
                child: Text("Пошаговые протоколы самопомощи",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primaryDark)),
              ),
              const SizedBox(height: 20),
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
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${p.steps.length} шагов",
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.purpleDeep),
                    ),
                  ),
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
                            color: protocol.color.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("👉 ",
                                  style: TextStyle(fontSize: 14)),
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
                'Извини, ключ Groq не введён.\n\nСбрось данные в профиле и введи ключ заново.'));
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
      final ai = AiService(apiKey: AppState.apiKey);
      final reply = await ai.chat(_messages);
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(
            ChatMessage(role: 'assistant', content: 'Ошибка: $e'));
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
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Center(
                  child: Text("🤖", style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Карманный психолог",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                Text("всегда рядом 💜",
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ],
        ),
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
// 🎭 ROLE PLAY SCREEN
// ==========================================
class RolePlayScreen extends StatefulWidget {
  const RolePlayScreen({super.key});
  @override
  State<RolePlayScreen> createState() => _RolePlayScreenState();
}

class _RolePlayScreenState extends State<RolePlayScreen> {
  RoleCharacter? _selected;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;

  void _selectCharacter(RoleCharacter c) {
    setState(() {
      _selected = c;
      _messages.clear();
      _messages.add(ChatMessage(
          role: 'assistant',
          content:
              '${c.emoji} Я — ${c.name}. Расскажи, что тебя беспокоит.'));
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading || _selected == null) return;

    if (AppState.apiKey.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(role: 'user', content: text));
        _messages.add(ChatMessage(
            role: 'assistant',
            content: '⚠ Ключ Groq не введён. Сбрось данные в профиле и введи ключ.'));
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
      final ai = AiService(apiKey: AppState.apiKey, prompt: _selected!.prompt);
      final reply = await ai.chat(_messages);
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages
            .add(ChatMessage(role: 'assistant', content: 'Ошибка: $e'));
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
        title: Text(
            _selected == null
                ? "🎭  Примерка ролей"
                : "${_selected!.emoji}  ${_selected!.name}",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selected != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: "К выбору роли",
              onPressed: () => setState(() {
                _selected = null;
                _messages.clear();
              }),
            ),
        ],
      ),
      body: SafeArea(
        child: _selected == null ? _characterList() : _chatView(),
      ),
    );
  }

  Widget _characterList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Выбери, кто с тобой поговорит",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 5),
          const Text(
            "Каждый персонаж говорит по-своему. Попробуй разные — услышишь себя с новой стороны.",
            style: TextStyle(fontSize: 13, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 20),
          ...roleCharacters.map((c) {
            return GestureDetector(
              onTap: () => _selectCharacter(c),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: c.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Text(c.emoji, style: const TextStyle(fontSize: 36)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(c.name,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text)),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 18, color: AppColors.text),
                  ],
                ),
              ),
            );
          }),
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
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.purpleDeep
                        : (_selected?.color ?? Colors.white),
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
                      hintText: 'Ответь...',
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
    );
  }
}

// ==========================================
// 🕵️ DISTORTION DETECTOR SCREEN
// ==========================================
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
      setState(() {
        _result =
            '⚠ Ключ Groq не введён.\n\nСбрось данные в профиле и введи ключ заново.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _result = "";
    });

    const detectorPrompt = '''
Ты — детектор когнитивных искажений. Анализируй мысль человека и находи искажения.

ВОЗМОЖНЫЕ ИСКАЖЕНИЯ:
- Катастрофизация
- Чёрно-белое мышление
- Чтение мыслей
- Обобщение («всегда/никогда»)
- Обесценивание хорошего
- Долженствование («я должен»)
- Персонализация

ФОРМАТ ОТВЕТА:
🎯 Искажение: [название]
💭 Что происходит: [объясни простыми словами]
🔄 А что если наоборот: [контраргумент]
💜 Поддержка: [1 фраза]

Отвечай коротко, по-дружески, по-русски. Используй эмодзи.
''';

    try {
      final ai = AiService(apiKey: AppState.apiKey, prompt: detectorPrompt);
      final reply = await ai.chat([
        ChatMessage(role: 'user', content: text),
      ]);
      setState(() {
        _result = reply;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Ошибка: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text("🕵️  Детектор искажений",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
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
                    color: AppColors.primaryDark,
                    height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(14),
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        "Например: «Я провалил экзамен, значит я ничтожество»",
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purpleDeep,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _loading ? null : _analyze,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text("🧠  Найти искажение",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
              ),
              if (_result.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Text(_result,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.text, height: 1.5)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: () => setState(() {
                    _controller.clear();
                    _result = "";
                  }),
                  child: const Text("🔄 Ещё раз"),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.pastelYellow,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(14),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("💡 Все люди иногда искажают реальность.",
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text)),
                    SizedBox(height: 4),
                    Text(
                        "Это не «с тобой что-то не так». Это работа мозга. Мы просто учимся её замечать.",
                        style:
                            TextStyle(fontSize: 12, color: AppColors.text)),
                  ],
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
// 💬 CONVERSATION TRAINER SCREEN
// ==========================================
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
  bool _training = false;
  bool _loading = false;

  void _startTraining() {
    final scenario = _scenarioController.text.trim();
    if (scenario.isEmpty) return;

    setState(() {
      _training = true;
      _messages.clear();
      _messages.add(ChatMessage(
          role: 'assistant',
          content:
              '🎭 Начинаем. Ситуация: $scenario\n\nЯ — твой собеседник. Начинай разговор первым. Если захочешь остановиться и получить разбор — напиши «СТОП».'));
    });
  }

  Future<void> _send() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _loading) return;

    if (AppState.apiKey.isEmpty) {
      setState(() {
        _messages.add(ChatMessage(role: 'user', content: text));
        _messages.add(ChatMessage(
            role: 'assistant',
            content: '⚠ Ключ Groq не введён.'));
      });
      _replyController.clear();
      _scrollDown();
      return;
    }

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
    });
    _replyController.clear();
    _scrollDown();

    final trainerPrompt = '''
Ты — тренажёр сложных разговоров. Пользователь описал ситуацию: "${_scenarioController.text.trim()}".

Ты играешь роль собеседника из этой ситуации. Будь реалистичен: можешь давить, манипулировать. Отвечай коротко — 2-3 предложения. По-русски. Если пользователь пишет «СТОП» — дай полный разбор. Используй эмодзи.
''';

    try {
      final ai = AiService(apiKey: AppState.apiKey, prompt: trainerPrompt);
      final reply = await ai.chat(_messages);
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages
            .add(ChatMessage(role: 'assistant', content: 'Ошибка: $e'));
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
        title: const Text("💬  Тренажёр разговоров",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_training)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => setState(() {
                _training = false;
                _messages.clear();
                _scenarioController.clear();
              }),
            ),
        ],
      ),
      body: SafeArea(
        child: _training ? _chatView() : _setupView(),
      ),
    );
  }

  Widget _setupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Опиши ситуацию, к которой хочешь подготовиться",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 5),
          const Text(
            "Например: «Хочу попросить повышение у босса», «Хочу сказать маме о своих границах», «Хочу отказать подруге»",
            style: TextStyle(fontSize: 13, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: _scenarioController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Ситуация...",
                hintStyle: TextStyle(color: Colors.grey),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purpleDeep,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _startTraining,
            child: const Text("🎭  Начать тренировку",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: AppColors.pastelBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(14),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("💡 Это безопасное пространство.",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text)),
                SizedBox(height: 4),
                Text(
                    "ИИ играет роль собеседника. Он может быть неудобным — но это тренировка. Здесь можно ошибиться.",
                    style: TextStyle(fontSize: 12, color: AppColors.text)),
              ],
            ),
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
                    controller: _replyController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Твой ответ...',
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
    );
  }
}

// ==========================================
// 🔥 HEAT MAP SCREEN
// ==========================================
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

    final days = <DateTime>[];
    for (int i = 139; i >= 0; i--) {
      days.add(today.subtract(Duration(days: i)));
    }

    final weeks = <List<DateTime>>[];
    for (int i = 0; i < days.length; i += 7) {
      weeks.add(days.sublist(i, i + 7 > days.length ? days.length : i + 7));
    }

    final totalMarks = counts.values.fold<int>(0, (a, b) => a + b);
    final activeDays = counts.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text("🔥  Тепловая карта",
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
              const Text("Активность за последние 20 недель",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              const SizedBox(height: 5),
              const Text(
                "Каждая клетка — день. Чем темнее, тем больше отметок.",
                style: TextStyle(fontSize: 13, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: weeks.map((week) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Column(
                          children: week.map((day) {
                            final key =
                                "${day.year}-${day.month}-${day.day}";
                            final count = counts[key] ?? 0;
                            return Container(
                              width: 14,
                              height: 14,
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: _colorForCount(count),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                          borderRadius: BorderRadius.circular(3),
                        ),
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
                  borderRadius: BorderRadius.circular(16),
                ),
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
                            "${(activeDays / 140 * 100).toStringAsFixed(0)}%",
                            "Регулярность",
                            AppColors.purpleLight),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "💜 Ты строишь путь. Каждая клетка — день, когда ты заботился(ась) о себе.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primaryDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String c, String l, Color color) {
    return Column(
      children: [
        Text(c,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(l,
            style: const TextStyle(fontSize: 11, color: AppColors.primaryDark)),
      ],
    );
  }
}

// ==========================================
// 🎨 EMOTION MAP SCREEN — календарь эмоций
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
            color = const Color(0xFFFCA5A5);
            emoji = "😡";
            break;
          case "Грусть":
            color = const Color(0xFF93C5FD);
            emoji = "😢";
            break;
          case "Тревога":
            color = const Color(0xFFFCD34D);
            emoji = "😰";
            break;
          case "Апатия":
            color = const Color(0xFFD1D5DB);
            emoji = "😐";
            break;
          case "Нейтрально":
            color = const Color(0xFFFEF08A);
            emoji = "🙂";
            break;
          case "Радость":
            color = const Color(0xFF86EFAC);
            emoji = "😊";
            break;
          case "Счастье":
            color = const Color(0xFFFDA4AF);
            emoji = "😍";
            break;
        }
      }

      cells.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
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
        title: const Text("🎨  Календарь эмоций",
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
                      _month = DateTime(_month.year, _month.month - 1, 1);
                    }),
                  ),
                  Text("${_monthNames[_month.month - 1]} ${_month.year}",
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () {
                      final nxt = DateTime(_month.year, _month.month + 1, 1);
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
                  AppColors.pastelYellow,
                  () => _notice(context, "bookscafe.net")),
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