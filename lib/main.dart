import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para a Vibração (HapticFeedback)
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:translator/translator.dart' as tr;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart'; // Para o Som de Acerto
import 'dart:io';
import 'dart:math';

// ==========================================
// CONFIGURAÇÕES DE IDIOMAS SUPORTADOS
// ==========================================
class AppLanguage {
  final String name;
  final String flag;
  final String ttsCode;
  final String transCode;
  const AppLanguage(this.name, this.flag, this.ttsCode, this.transCode);
}

const Map<String, AppLanguage> supportedLanguages = {
  'Inglês': AppLanguage('Inglês', '🇺🇸', 'en-US', 'en'),
  'Alemão': AppLanguage('Alemão', '🇩🇪', 'de-DE', 'de'),
  'Espanhol': AppLanguage('Espanhol', '🇪🇸', 'es-ES', 'es'),
  'Português': AppLanguage('Português', '🇧🇷', 'pt-BR', 'pt'),
  'Francês': AppLanguage('Francês', '🇫🇷', 'fr-FR', 'fr'),
};

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);
final ValueNotifier<String> appLanguage = ValueNotifier('Inglês');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = DatabaseHelper.instance;
  String temaSalvo = await db.getConfig('tema');
  String idiomaSalvo = await db.getConfig('idioma_atual');

  appThemeMode.value = (temaSalvo == 'dark') ? ThemeMode.dark : ThemeMode.light;
  if (idiomaSalvo.isNotEmpty && supportedLanguages.containsKey(idiomaSalvo)) {
    appLanguage.value = idiomaSalvo;
  }

  runApp(const MemoryWordApp());
}

// ==========================================
// BANCO DE DADOS
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      await _checkAndUpgradeSchema(_database!);
      return _database!;
    }
    _database = await _initDB('dicionario.db');
    await _checkAndUpgradeSchema(_database!);
    return _database!;
  }

  Future<void> _checkAndUpgradeSchema(Database db) async {
    try {
      var tableInfo = await db.rawQuery("PRAGMA table_info(palavras)");
      bool hasLingua = tableInfo.any((col) => col['name'] == 'lingua');
      if (!hasLingua) {
        await db.execute("ALTER TABLE palavras ADD COLUMN lingua TEXT DEFAULT 'Inglês'");
      }

      List<String> configs = ['idioma_atual', 'papagaio_filtro', 'papagaio_custom_val', 'papagaio_nativo', 'papagaio_modo', 'papagaio_vel', 'afiada_filtro', 'afiada_custom_val'];
      for (String c in configs) {
        String defaultVal = '';
        if (c == 'idioma_atual' || c == 'papagaio_nativo') defaultVal = 'Português';
        if (c == 'papagaio_filtro' || c == 'afiada_filtro') defaultVal = 'todas';
        if (c == 'papagaio_modo') defaultVal = 'loop';
        if (c == 'papagaio_vel') defaultVal = '1.0';
        await db.insert('configuracoes', {'chave': c, 'valor': defaultVal}, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } catch (e) {
      debugPrint("Erro na verificação de schema: $e");
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, filePath);

    return await openDatabase(
      fullPath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE palavras (id INTEGER PRIMARY KEY AUTOINCREMENT, ingles TEXT NOT NULL, traducao TEXT NOT NULL, imagem TEXT, lingua TEXT NOT NULL DEFAULT 'Inglês')''');
        await db.execute('''CREATE TABLE configuracoes (chave TEXT PRIMARY KEY, valor TEXT)''');
        await db.insert('configuracoes', {'chave': 'filtro', 'valor': 'todas'});
        await db.insert('configuracoes', {'chave': 'custom_val', 'valor': ''});
        await db.insert('configuracoes', {'chave': 'tema', 'valor': 'light'});
        await db.insert('configuracoes', {'chave': 'idioma_atual', 'valor': 'Inglês'});
        await db.insert('configuracoes', {'chave': 'papagaio_filtro', 'valor': 'todas'});
        await db.insert('configuracoes', {'chave': 'papagaio_custom_val', 'valor': ''});
        await db.insert('configuracoes', {'chave': 'papagaio_nativo', 'valor': 'Português'});
        await db.insert('configuracoes', {'chave': 'papagaio_modo', 'valor': 'loop'});
        await db.insert('configuracoes', {'chave': 'papagaio_vel', 'valor': '1.0'});
        await db.insert('configuracoes', {'chave': 'afiada_filtro', 'valor': 'todas'});
        await db.insert('configuracoes', {'chave': 'afiada_custom_val', 'valor': ''});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('CREATE TABLE IF NOT EXISTS configuracoes (chave TEXT PRIMARY KEY, valor TEXT)');
          await db.insert('configuracoes', {'chave': 'filtro', 'valor': 'todas'}, conflictAlgorithm: ConflictAlgorithm.replace);
          await db.insert('configuracoes', {'chave': 'custom_val', 'valor': ''}, conflictAlgorithm: ConflictAlgorithm.replace);
          await db.insert('configuracoes', {'chave': 'tema', 'valor': 'light'}, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (oldVersion < 3) {
          try { await db.execute("ALTER TABLE palavras ADD COLUMN lingua TEXT DEFAULT 'Inglês'"); } catch (_) {}
          await db.insert('configuracoes', {'chave': 'idioma_atual', 'valor': 'Inglês'}, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (oldVersion < 4) {
          await db.insert('configuracoes', {'chave': 'papagaio_filtro', 'valor': 'todas'}, conflictAlgorithm: ConflictAlgorithm.ignore);
          await db.insert('configuracoes', {'chave': 'papagaio_custom_val', 'valor': ''}, conflictAlgorithm: ConflictAlgorithm.ignore);
          await db.insert('configuracoes', {'chave': 'papagaio_nativo', 'valor': 'Português'}, conflictAlgorithm: ConflictAlgorithm.ignore);
          await db.insert('configuracoes', {'chave': 'papagaio_modo', 'valor': 'loop'}, conflictAlgorithm: ConflictAlgorithm.ignore);
          await db.insert('configuracoes', {'chave': 'papagaio_vel', 'valor': '1.0'}, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        if (oldVersion < 5) {
          await db.insert('configuracoes', {'chave': 'afiada_filtro', 'valor': 'todas'}, conflictAlgorithm: ConflictAlgorithm.ignore);
          await db.insert('configuracoes', {'chave': 'afiada_custom_val', 'valor': ''}, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      },
    );
  }

  Future<String> getConfig(String chave) async {
    try {
      final db = await instance.database;
      final res = await db.query('configuracoes', where: 'chave = ?', whereArgs: [chave]);
      if (res.isNotEmpty) return res.first['valor'].toString();
    } catch (_) {}
    return '';
  }

  Future<void> updateConfig(String chave, String valor) async {
    final db = await instance.database;
    await db.insert('configuracoes', {'chave': chave, 'valor': valor}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertWord(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('palavras', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> fetchWordsForPractice(String linguaAtual) async {
    final db = await instance.database;
    String filtro = await getConfig('filtro');
    int limit = -1;
    if (filtro != 'todas') {
      limit = filtro == 'custom' ? (int.tryParse(await getConfig('custom_val')) ?? -1) : (int.tryParse(filtro) ?? -1);
    }
    String query = '''SELECT ingles, GROUP_CONCAT(traducao, '|') as traducoes, MAX(imagem) as imagem FROM palavras WHERE lingua = ? GROUP BY ingles COLLATE NOCASE ORDER BY MAX(id) DESC''';
    if (limit > 0) query += ' LIMIT $limit';
    return await db.rawQuery(query, [linguaAtual]);
  }

  Future<List<Map<String, dynamic>>> fetchCustomWords(String linguaAtual, String filtro, String customVal) async {
    final db = await instance.database;
    int limit = -1;
    if (filtro != 'todas') {
      limit = filtro == 'custom' ? (int.tryParse(customVal) ?? -1) : (int.tryParse(filtro) ?? -1);
    }
    String query = '''SELECT ingles, GROUP_CONCAT(traducao, '|') as traducoes, MAX(imagem) as imagem FROM palavras WHERE lingua = ? GROUP BY ingles COLLATE NOCASE ORDER BY MAX(id) DESC''';
    if (limit > 0) query += ' LIMIT $limit';
    return await db.rawQuery(query, [linguaAtual]);
  }

  Future<List<Map<String, dynamic>>> fetchDistinctWords(String linguaAtual, [String query = '']) async {
    final db = await instance.database;
    if (query.isEmpty) {
      return await db.rawQuery('''SELECT ingles, MAX(imagem) as imagem, GROUP_CONCAT(traducao, ', ') as traducao FROM palavras WHERE lingua = ? GROUP BY ingles COLLATE NOCASE ORDER BY ingles COLLATE NOCASE ASC''', [linguaAtual]);
    } else {
      return await db.rawQuery('''SELECT ingles, MAX(imagem) as imagem, GROUP_CONCAT(traducao, ', ') as traducao FROM palavras WHERE lingua = ? AND (ingles LIKE ? OR traducao LIKE ?) GROUP BY ingles COLLATE NOCASE ORDER BY ingles COLLATE NOCASE ASC''', [linguaAtual, '%$query%', '%$query%']);
    }
  }

  Future<List<Map<String, dynamic>>> fetchMeanings(String ingles, String linguaAtual) async {
    final db = await instance.database;
    return await db.query('palavras', where: 'ingles = ? COLLATE NOCASE AND lingua = ?', whereArgs: [ingles, linguaAtual]);
  }

  Future<void> deleteAllMeanings(String ingles, String linguaAtual) async {
    final db = await instance.database;
    await db.delete('palavras', where: 'ingles = ? COLLATE NOCASE AND lingua = ?', whereArgs: [ingles, linguaAtual]);
  }
}

// ==========================================
// APLICATIVO PRINCIPAL E NAVEGAÇÃO
// ==========================================
class MemoryWordApp extends StatelessWidget {
  const MemoryWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'MemoryWord',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: currentMode,
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1;
  late PageController _mainPageController;

  @override
  void initState() {
    super.initState();
    _mainPageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _mainPageController.dispose();
    super.dispose();
  }

  void _abrirConfiguracoes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: ValueListenableBuilder<String>(
          valueListenable: appLanguage,
          builder: (context, lang, child) {
            return Center(child: Text(supportedLanguages[lang]?.flag ?? '🌐', style: const TextStyle(fontSize: 26)));
          },
        ),
        title: const Text('MemoryWord'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.settings), tooltip: "Configurações", onPressed: _abrirConfiguracoes)
        ],
      ),
      body: ValueListenableBuilder<String>(
        valueListenable: appLanguage,
        builder: (context, currentLang, child) {
          return PageView(
            controller: _mainPageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: [
              RegisterTab(currentLang: currentLang),
              PracticeTab(currentLang: currentLang),
              LibraryTab(currentLang: currentLang),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _mainPageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Novo'),
          BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'Praticar'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Biblioteca'),
        ],
      ),
    );
  }
}

// ==========================================
// ABA 2: PRÁTICA (TRÊS NÍVEIS) COM FEEDBACK SONORO E TÁTIL
// ==========================================
class PracticeTab extends StatefulWidget {
  final String currentLang;
  const PracticeTab({super.key, required this.currentLang});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  final PageController _pageController = PageController(initialPage: 0);
  final FlutterTts _flutterTts = FlutterTts();
  late stt.SpeechToText _speech;

  // Toca o som de acerto
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Variáveis do Modo Normal
  Map<String, dynamic>? _currentWordNormal;
  final _answerCtrl = TextEditingController();
  String _resultTextNormal = '';
  Color _resultColorNormal = Colors.black;

  // Variáveis do Modo Papagaio
  String _parrotNativeLang = 'Português';
  String _parrotFilter = 'todas';
  String _parrotCustomVal = '';
  String _parrotMode = 'loop';
  double _parrotSpeed = 1.0;
  final TextEditingController _parrotCustomCtrl = TextEditingController();
  bool _isParrotPlaying = false;
  String _parrotCurrentWordDisplay = '';

  // Variáveis do Modo Língua Afiada 🗡️
  Map<String, dynamic>? _currentWordSharp;
  String _sharpFilter = 'todas';
  String _sharpCustomVal = '';
  final TextEditingController _sharpCustomCtrl = TextEditingController();
  bool _isListening = false;
  String _spokenText = '';
  String _sharpResultText = '';
  Color _sharpResultColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadParrotSettings();
    _loadSharpSettings();

    _parrotCustomCtrl.addListener(() {
      _parrotCustomVal = _parrotCustomCtrl.text.trim();
      _saveParrotSettings();
    });
    _sharpCustomCtrl.addListener(() {
      _sharpCustomVal = _sharpCustomCtrl.text.trim();
      _saveSharpSettings();
    });
  }

  @override
  void didUpdateWidget(PracticeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLang != widget.currentLang) {
      if (_isParrotPlaying) {
        _isParrotPlaying = false;
        _flutterTts.stop();
        if (mounted) setState(() {});
      }
      _currentWordNormal = null;
      _answerCtrl.clear();
      _resultTextNormal = '';
      _currentWordSharp = null;
      _sharpResultText = '';
      _spokenText = '';
    }
  }

  @override
  void dispose() {
    _isParrotPlaying = false;
    _flutterTts.stop();
    _audioPlayer.dispose(); // Limpa o leitor de som
    _pageController.dispose();
    _parrotCustomCtrl.dispose();
    _sharpCustomCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  // --- Função para tocar o Plim de Acerto ---
  Future<void> _playCorrectSound() async {
    try {
      await _audioPlayer.play(AssetSource('correct.mp3'));
    } catch (e) {
      debugPrint("Ficheiro de som correct.mp3 não encontrado na pasta assets.");
    }
  }

  Future<void> _falar(String texto, {double rate = 0.5}) async {
    AppLanguage langData = supportedLanguages[widget.currentLang]!;
    await _flutterTts.setLanguage(langData.ttsCode);
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.speak(texto);
  }

  Widget _buildMinimalArrow(IconData icon, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == Icons.keyboard_arrow_down) Icon(icon, color: Colors.grey, size: 20),
            Text(text, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
            if (icon == Icons.keyboard_arrow_up) Icon(icon, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // --- Funções do MODO NORMAL ---
  Future<void> _drawWordNormal() async {
    final words = await DatabaseHelper.instance.fetchWordsForPractice(widget.currentLang);
    if (words.isEmpty) {
      setState(() { _resultTextNormal = 'Sua biblioteca está vazia.'; _resultColorNormal = Colors.blue; });
      return;
    }
    setState(() {
      _currentWordNormal = words[Random().nextInt(words.length)];
      _answerCtrl.clear();
      _resultTextNormal = '';
    });
  }

  void _verifyAnswerNormal() {
    if (_currentWordNormal == null || _answerCtrl.text.isEmpty) return;
    final userAnswer = _answerCtrl.text.trim().toLowerCase();
    final List<String> correctAnswers = _currentWordNormal!['traducoes'].toString().split('|').map((e) => e.trim().toLowerCase()).toList();

    setState(() {
      if (correctAnswers.contains(userAnswer)) {
        _resultTextNormal = 'Resposta Correta! 🎉';
        _resultColorNormal = Colors.green;
        _playCorrectSound(); // Toca o Plim!
      } else {
        final displayCorrect = _currentWordNormal!['traducoes'].toString().replaceAll('|', ' ou ');
        _resultTextNormal = 'Incorreta. O correto é: $displayCorrect';
        _resultColorNormal = Colors.red;
        HapticFeedback.heavyImpact(); // Vibração de erro!
      }
    });
  }

  // --- Funções do MODO PAPAGAIO ---
  Future<void> _loadParrotSettings() async {
    final db = DatabaseHelper.instance;
    setState(() {
      db.getConfig('papagaio_nativo').then((v) { if (v.isNotEmpty) _parrotNativeLang = v; });
      db.getConfig('papagaio_filtro').then((v) { if (v.isNotEmpty) _parrotFilter = v; });
      db.getConfig('papagaio_custom_val').then((v) { _parrotCustomVal = v; _parrotCustomCtrl.text = v; });
      db.getConfig('papagaio_modo').then((v) { if (v.isNotEmpty) _parrotMode = v; });
      db.getConfig('papagaio_vel').then((v) { if (v.isNotEmpty) _parrotSpeed = double.tryParse(v) ?? 1.0; });
    });
  }

  void _saveParrotSettings() {
    final db = DatabaseHelper.instance;
    db.updateConfig('papagaio_nativo', _parrotNativeLang);
    db.updateConfig('papagaio_filtro', _parrotFilter);
    db.updateConfig('papagaio_custom_val', _parrotCustomVal);
    db.updateConfig('papagaio_modo', _parrotMode);
    db.updateConfig('papagaio_vel', _parrotSpeed.toString());
  }

  void _toggleParrot() async {
    if (_isParrotPlaying) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isParrotPlaying = false);
    } else {
      if (mounted) setState(() => _isParrotPlaying = true);
      _runParrotLoop();
    }
  }

  Future<void> _runParrotLoop() async {
    try {
      _flutterTts.awaitSpeakCompletion(true);
      if (Platform.isIOS) {
        _flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [IosTextToSpeechAudioCategoryOptions.mixWithOthers, IosTextToSpeechAudioCategoryOptions.allowBluetooth]);
      }

      while (_isParrotPlaying) {
        final rawWords = await DatabaseHelper.instance.fetchCustomWords(widget.currentLang, _parrotFilter, _parrotCustomVal);
        if (rawWords.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sua biblioteca está vazia!'), backgroundColor: Colors.orange));
            setState(() { _isParrotPlaying = false; _parrotCurrentWordDisplay = 'Biblioteca Vazia!'; });
          }
          break;
        }

        final words = List<Map<String, dynamic>>.from(rawWords);
        words.shuffle();

        for (var word in words) {
          if (!_isParrotPlaying) break;

          if (mounted) setState(() => _parrotCurrentWordDisplay = word['ingles']);
          AppLanguage studyLang = supportedLanguages[widget.currentLang]!;
          await _flutterTts.setLanguage(studyLang.ttsCode);
          await _flutterTts.setSpeechRate(0.5 * _parrotSpeed);
          await _flutterTts.speak(word['ingles']);

          if (!_isParrotPlaying) break;
          await Future.delayed(Duration(milliseconds: (1200 / _parrotSpeed).round()));

          if (!_isParrotPlaying) break;
          String trad = word['traducoes'].toString().replaceAll('|', ' ou ');
          if (mounted) setState(() => _parrotCurrentWordDisplay = trad);
          AppLanguage nativeLang = supportedLanguages[_parrotNativeLang] ?? supportedLanguages['Português']!;
          await _flutterTts.setLanguage(nativeLang.ttsCode);
          await _flutterTts.setSpeechRate(0.5 * _parrotSpeed);
          await _flutterTts.speak(trad);

          if (!_isParrotPlaying) break;
          await Future.delayed(Duration(milliseconds: (2000 / _parrotSpeed).round()));
        }
        if (_parrotMode == 'single' && _isParrotPlaying) {
          if (mounted) setState(() { _isParrotPlaying = false; _parrotCurrentWordDisplay = 'Sequência Concluída!'; });
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no motor de voz: $e'), backgroundColor: Colors.red));
        setState(() => _isParrotPlaying = false);
      }
    }
  }

  // --- Funções do MODO LÍNGUA AFIADA 🗡️ ---
  Future<void> _loadSharpSettings() async {
    final db = DatabaseHelper.instance;
    setState(() {
      db.getConfig('afiada_filtro').then((v) { if (v.isNotEmpty) _sharpFilter = v; });
      db.getConfig('afiada_custom_val').then((v) { _sharpCustomVal = v; _sharpCustomCtrl.text = v; });
    });
  }

  void _saveSharpSettings() {
    final db = DatabaseHelper.instance;
    db.updateConfig('afiada_filtro', _sharpFilter);
    db.updateConfig('afiada_custom_val', _sharpCustomVal);
  }

  Future<void> _drawWordSharp() async {
    final words = await DatabaseHelper.instance.fetchCustomWords(widget.currentLang, _sharpFilter, _sharpCustomVal);
    if (words.isEmpty) {
      setState(() { _sharpResultText = 'Nenhuma palavra encontrada.'; _sharpResultColor = Colors.blue; });
      return;
    }
    setState(() {
      _currentWordSharp = words[Random().nextInt(words.length)];
      _sharpResultText = '';
      _spokenText = '';
    });
    _falar(_currentWordSharp!['ingles']);
  }

  void _listenSharp() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'notListening' || val == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          setState(() => _isListening = false);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro do Microfone: ${val.errorMsg}')));
        },
      );
      if (available) {
        setState(() => _isListening = true);
        AppLanguage langData = supportedLanguages[widget.currentLang]!;
        _speech.listen(
          onResult: (val) {
            setState(() {
              _spokenText = val.recognizedWords;
              if (val.hasConfidenceRating && val.confidence > 0) {
                _verifySpeech();
              }
            });
          },
          localeId: langData.ttsCode,
        );
      } else {
        setState(() => _isListening = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reconhecimento indisponível. Conceda a permissão de Microfone no Manifest do Android!'))
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _verifySpeech();
    }
  }

  void _verifySpeech() {
    if (_currentWordSharp == null || _spokenText.isEmpty) return;

    String target = _currentWordSharp!['ingles'].toString().toLowerCase().replaceAll(RegExp(r'[^\w\s]+'), '');
    String spoken = _spokenText.toLowerCase().replaceAll(RegExp(r'[^\w\s]+'), '');

    setState(() {
      if (spoken == target || spoken.contains(target) || target.contains(spoken)) {
        _sharpResultText = 'Pronúncia Perfeita! 🎉';
        _sharpResultColor = Colors.green;
        _playCorrectSound(); // Toca o Plim!
      } else {
        _sharpResultText = 'Tente novamente. Entendemos: "$spoken"';
        _sharpResultColor = Colors.red;
        HapticFeedback.heavyImpact(); // Vibração de erro!
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      children: [
        _buildNormalPractice(),
        _buildParrotPractice(),
        _buildSharpPractice(),
      ],
    );
  }

  // --- Nível 1: Sorteio Normal ---
  Widget _buildNormalPractice() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              children: [
                FilledButton.icon(icon: const Icon(Icons.shuffle), label: const Text('Sortear Palavra'), onPressed: _drawWordNormal),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: Text(_currentWordNormal?['ingles'] ?? 'Clique acima para sortear', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    if (_currentWordNormal != null) IconButton(icon: const Icon(Icons.volume_up, color: Colors.blue, size: 28), tooltip: "Ouvir", onPressed: () => _falar(_currentWordNormal!['ingles'])),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(controller: _answerCtrl, enabled: _currentWordNormal != null, decoration: const InputDecoration(labelText: 'Sua Tradução', border: OutlineInputBorder()), onChanged: (v) => setState((){})),
                const SizedBox(height: 15),
                ElevatedButton(onPressed: (_currentWordNormal == null || _answerCtrl.text.isEmpty) ? null : _verifyAnswerNormal, child: const Text('Confirmar Resposta')),
                const SizedBox(height: 10),
                Text(_resultTextNormal, style: TextStyle(fontSize: 18, color: _resultColorNormal, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 10),

                if (_resultTextNormal.isNotEmpty && _currentWordNormal?['imagem'] != null && _currentWordNormal!['imagem'] != '')
                  Expanded(child: Image.file(File(_currentWordNormal!['imagem']), fit: BoxFit.contain))
              ],
            ),
          ),
        ),
        _buildMinimalArrow(Icons.keyboard_arrow_up, "Modo Papagaio", () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)),
      ],
    );
  }

  // --- Nível 2: Modo Papagaio ---
  Widget _buildParrotPractice() {
    return Column(
      children: [
        _buildMinimalArrow(Icons.keyboard_arrow_down, "Modo Sorteio", () => _pageController.animateToPage(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [ Text('🦜', style: TextStyle(fontSize: 30)), SizedBox(width: 10), Text('Modo Papagaio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)) ]),
                const Divider(height: 15),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Opacity(
                            opacity: _isParrotPlaying ? 0.5 : 1.0,
                            child: IgnorePointer(
                                ignoring: _isParrotPlaying,
                                child: Column(
                                  children: [
                                    DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Seu Idioma (Origem)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12)), value: _parrotNativeLang, items: supportedLanguages.keys.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(), onChanged: (v) { setState(() => _parrotNativeLang = v!); _saveParrotSettings(); }),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Filtro de Palavras', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12)), value: _parrotFilter, items: const [ DropdownMenuItem(value: 'todas', child: Text("Todas as palavras salvas")), DropdownMenuItem(value: '10', child: Text("Últimas 10 palavras")), DropdownMenuItem(value: '20', child: Text("Últimas 20 palavras")), DropdownMenuItem(value: '30', child: Text("Últimas 30 palavras")), DropdownMenuItem(value: 'custom', child: Text("Quantidade Personalizada...")) ], onChanged: (v) { setState(() => _parrotFilter = v!); _saveParrotSettings(); }),
                                    if (_parrotFilter == 'custom') Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: _parrotCustomCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Digite a quantidade (> 0)', border: OutlineInputBorder(), isDense: true))),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<double>(decoration: const InputDecoration(labelText: 'Velocidade da Voz', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12)), value: _parrotSpeed, items: const [ DropdownMenuItem(value: 0.5, child: Text("Lento (0.5x)")), DropdownMenuItem(value: 1.0, child: Text("Normal (1x)")), DropdownMenuItem(value: 1.5, child: Text("Rápido (1.5x)")), DropdownMenuItem(value: 2.0, child: Text("Turbo (2x)")) ], onChanged: (v) { setState(() => _parrotSpeed = v!); _saveParrotSettings(); }),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Modo de Repetição', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12)), value: _parrotMode, items: const [ DropdownMenuItem(value: 'loop', child: Text("🔁 Em Loop (Sorteio Infinito)")), DropdownMenuItem(value: 'single', child: Text("➡️ 1 Sequência (Parar no fim)")) ], onChanged: (v) { setState(() => _parrotMode = v!); _saveParrotSettings(); }),
                                  ],
                                )
                            )
                        ),
                        const SizedBox(height: 25),
                        Text(_parrotCurrentWordDisplay.isEmpty ? 'Pronto para voar!' : _parrotCurrentWordDisplay, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                SizedBox(width: double.infinity, height: 55, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _isParrotPlaying ? Colors.red.shade700 : Colors.green.shade700), onPressed: _toggleParrot, icon: Icon(_isParrotPlaying ? Icons.stop : Icons.play_arrow, size: 26), label: Text(_isParrotPlaying ? "Parar Papagaio" : "Iniciar Papagaio", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
        ),
        _buildMinimalArrow(Icons.keyboard_arrow_up, "Língua Afiada", () => _pageController.animateToPage(2, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)),
      ],
    );
  }

  // --- Nível 3: Modo Língua Afiada 🗡️ ---
  Widget _buildSharpPractice() {
    return Column(
      children: [
        _buildMinimalArrow(Icons.keyboard_arrow_down, "Modo Papagaio", () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [ Text('🗡️', style: TextStyle(fontSize: 30)), SizedBox(width: 10), Text('Língua Afiada', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)) ]),
                  const Divider(height: 15),

                  DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Filtro de Sorteio', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12), isDense: true),
                      value: _sharpFilter,
                      items: const [ DropdownMenuItem(value: 'todas', child: Text("Todas as palavras")), DropdownMenuItem(value: '10', child: Text("Últimas 10")), DropdownMenuItem(value: '20', child: Text("Últimas 20")), DropdownMenuItem(value: '30', child: Text("Últimas 30")), DropdownMenuItem(value: 'custom', child: Text("Personalizado")) ],
                      onChanged: (v) { setState(() => _sharpFilter = v!); _saveSharpSettings(); }
                  ),
                  if (_sharpFilter == 'custom')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(controller: _sharpCustomCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade Personalizada (>0)', border: OutlineInputBorder(), isDense: true)),
                    ),
                  const SizedBox(height: 20),

                  FilledButton.icon(icon: const Icon(Icons.shuffle), label: const Text('Sortear Nova Palavra'), onPressed: _drawWordSharp),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text(_currentWordSharp?['ingles'] ?? 'Sorteie para começar', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      if (_currentWordSharp != null) IconButton(icon: const Icon(Icons.volume_up, color: Colors.blue, size: 35), tooltip: "Ouvir Novamente", onPressed: () => _falar(_currentWordSharp!['ingles'])),
                    ],
                  ),

                  if (_currentWordSharp != null) ...[
                    const SizedBox(height: 10),
                    Text(_currentWordSharp!['traducoes'].toString().replaceAll('|', ' ou '), style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  ],

                  const SizedBox(height: 30),
                  Text(_sharpResultText, style: TextStyle(fontSize: 18, color: _sharpResultColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: _currentWordSharp == null ? null : _listenSharp,
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: _currentWordSharp == null ? Colors.grey : (_isListening ? Colors.red : Colors.blue),
                      child: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 35, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(_isListening ? "A escutar... Fale agora!" : (_currentWordSharp == null ? "" : "Toque para falar"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// MENU DE CONFIGURAÇÕES GLOBAIS
// ==========================================
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool _isDark = false;
  String _filtro = 'todas';
  String _idiomaSelecionado = 'Inglês';
  final _customCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = DatabaseHelper.instance;
    final tema = await db.getConfig('tema');
    final filtro = await db.getConfig('filtro');
    final customVal = await db.getConfig('custom_val');
    final idioma = await db.getConfig('idioma_atual');

    setState(() {
      _isDark = tema == 'dark';
      _filtro = filtro.isEmpty ? 'todas' : filtro;
      _customCtrl.text = customVal;
      _idiomaSelecionado = idioma.isEmpty ? 'Inglês' : idioma;
    });
  }

  Future<void> _salvar() async {
    if (_filtro == 'custom') {
      int? val = int.tryParse(_customCtrl.text.trim());
      if (val == null || val <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insira um número válido > 0')));
        return;
      }
    }

    try {
      final db = DatabaseHelper.instance;
      await db.updateConfig('tema', _isDark ? 'dark' : 'light');
      await db.updateConfig('filtro', _filtro);
      await db.updateConfig('custom_val', _customCtrl.text.trim());
      await db.updateConfig('idioma_atual', _idiomaSelecionado);

      appThemeMode.value = _isDark ? ThemeMode.dark : ThemeMode.light;
      appLanguage.value = _idiomaSelecionado;

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurações salvas!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Idioma de Estudo Principal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _idiomaSelecionado,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                items: supportedLanguages.keys.map((lang) {
                  return DropdownMenuItem(value: lang, child: Text("${supportedLanguages[lang]!.flag} Aprender $lang"));
                }).toList(),
                onChanged: (val) { if (val != null) setState(() => _idiomaSelecionado = val); },
              ),
              const Divider(height: 30),
              const Text("Aparência", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SwitchListTile(title: const Text("Modo Noturno"), value: _isDark, onChanged: (val) => setState(() => _isDark = val)),
              const Divider(height: 30),
              const Text("Filtro de Sorteio (Prática Normal)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              RadioListTile(title: const Text("Todas as palavras"), value: 'todas', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              RadioListTile(title: const Text("Últimas 10"), value: '10', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              RadioListTile(title: const Text("Últimas 20"), value: '20', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              RadioListTile(title: const Text("Últimas 30"), value: '30', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              RadioListTile(title: const Text("Personalizado"), value: 'custom', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              if (_filtro == 'custom')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: TextField(controller: _customCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Nº Personalizado (> 0)", border: OutlineInputBorder())),
                ),
              const Divider(),
              Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _salvar, child: const Text("Salvar"))),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ABA 1: REGISTRO
// ==========================================
class RegisterTab extends StatefulWidget {
  final String currentLang;
  const RegisterTab({super.key, required this.currentLang});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  final _inglesCtrl = TextEditingController();
  final _traducaoCtrl = TextEditingController();
  File? _imageFile;
  bool _isTranslating = false;
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _flutterTts = FlutterTts();

  Future<void> _falar(String texto) async {
    if (texto.isEmpty) return;
    AppLanguage langData = supportedLanguages[widget.currentLang]!;
    await _flutterTts.setLanguage(langData.ttsCode);
    await _flutterTts.speak(texto);
  }

  Future<void> _translateWord() async {
    if (_inglesCtrl.text.isEmpty) return;
    setState(() => _isTranslating = true);
    try {
      AppLanguage langData = supportedLanguages[widget.currentLang]!;
      final translator = tr.GoogleTranslator();
      final translation = await translator.translate(_inglesCtrl.text.trim(), from: langData.transCode, to: 'pt');
      setState(() => _traducaoCtrl.text = translation.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro de conexão ao traduzir.')));
    }
    setState(() => _isTranslating = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final String newPath = path.join((await getApplicationDocumentsDirectory()).path, 'img_${Random().nextInt(100000)}.jpg');
      final File savedImage = await File(pickedFile.path).copy(newPath);
      setState(() => _imageFile = savedImage);
    }
  }

  Future<void> _saveWord() async {
    if (_inglesCtrl.text.trim().isEmpty || _traducaoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha a palavra e a tradução antes de salvar.')));
      return;
    }
    try {
      final db = DatabaseHelper.instance;
      final ex = await db.fetchMeanings(_inglesCtrl.text.trim(), widget.currentLang);
      if (ex.isNotEmpty) {
        if (!mounted) return;
        bool? addAnother = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(title: const Text("Palavra Existente"), content: const Text("Esta palavra já existe na biblioteca desta língua. Deseja adicionar este novo significado a ela?"), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancelar")), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text("Sim"))])
        );
        if (addAnother != true) return;
      }
      await db.insertWord({'ingles': _inglesCtrl.text.trim(), 'traducao': _traducaoCtrl.text.trim(), 'imagem': _imageFile?.path ?? '', 'lingua': widget.currentLang});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Palavra salva com sucesso!'), backgroundColor: Colors.green));
      setState(() { _inglesCtrl.clear(); _traducaoCtrl.clear(); _imageFile = null; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro interno ao salvar: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Text("Registar Palavra", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: TextField(controller: _inglesCtrl, decoration: InputDecoration(labelText: 'Palavra em ${widget.currentLang}', border: const OutlineInputBorder()))),
              IconButton(icon: const Icon(Icons.volume_up, color: Colors.blue), tooltip: "Ouvir Pronúncia", onPressed: () => _falar(_inglesCtrl.text.trim())),
              IconButton(icon: _isTranslating ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.g_translate, color: Colors.blue), tooltip: "Traduzir", onPressed: _translateWord),
            ],
          ),
          const SizedBox(height: 15),
          TextField(controller: _traducaoCtrl, decoration: const InputDecoration(labelText: 'Significado / Tradução', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(icon: const Icon(Icons.camera_alt), label: const Text('Câmera'), onPressed: () => _pickImage(ImageSource.camera)),
              ElevatedButton.icon(icon: const Icon(Icons.photo_library), label: const Text('Galeria'), onPressed: () => _pickImage(ImageSource.gallery)),
            ],
          ),
          const SizedBox(height: 20),
          if (_imageFile != null) ...[
            Image.file(_imageFile!, height: 150, fit: BoxFit.cover),
            TextButton.icon(icon: const Icon(Icons.delete, color: Colors.red), label: const Text('Remover Foto', style: TextStyle(color: Colors.red)), onPressed: () => setState(() => _imageFile = null))
          ],
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: _saveWord, child: const Text('Confirmar', style: TextStyle(fontSize: 18))))
        ],
      ),
    );
  }
}

// ==========================================
// ABA 3: BIBLIOTECA
// ==========================================
class LibraryTab extends StatefulWidget {
  final String currentLang;
  const LibraryTab({super.key, required this.currentLang});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  List<Map<String, dynamic>> _distinctWords = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _loadWords(); }

  Future<void> _loadWords([String query = '']) async {
    final words = await DatabaseHelper.instance.fetchDistinctWords(widget.currentLang, query);
    setState(() => _distinctWords = words);
  }

  void _abrirDetalhes(String ingles) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => WordDetailsScreen(ingles: ingles, currentLang: widget.currentLang)));
    _loadWords(_searchCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        children: [
          Text("Sua Biblioteca em ${widget.currentLang}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(controller: _searchCtrl, decoration: const InputDecoration(labelText: 'Pesquisar...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (value) => _loadWords(value)),
          const SizedBox(height: 10),
          Expanded(
            child: _distinctWords.isEmpty
                ? const Center(child: Text("Nenhuma palavra encontrada.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              itemCount: _distinctWords.length,
              itemBuilder: (context, index) {
                final word = _distinctWords[index];
                final hasImage = word['imagem'] != null && word['imagem'].toString().isNotEmpty;
                return Card(
                  elevation: 2, margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: hasImage ? CircleAvatar(backgroundImage: FileImage(File(word['imagem']))) : const CircleAvatar(child: Icon(Icons.text_fields)),
                    title: Text(word['ingles'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text(word['traducao'] ?? ''),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => _abrirDetalhes(word['ingles']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WordDetailsScreen extends StatefulWidget {
  final String ingles;
  final String currentLang;
  const WordDetailsScreen({super.key, required this.ingles, required this.currentLang});
  @override
  State<WordDetailsScreen> createState() => _WordDetailsScreenState();
}

class _WordDetailsScreenState extends State<WordDetailsScreen> {
  List<Map<String, dynamic>> _meanings = [];

  @override
  void initState() { super.initState(); _loadMeanings(); }

  Future<void> _loadMeanings() async {
    final res = await DatabaseHelper.instance.fetchMeanings(widget.ingles, widget.currentLang);
    setState(() => _meanings = res);
  }

  void _irParaEdicao() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => EditWordScreen(ingles: widget.ingles, meanings: _meanings, currentLang: widget.currentLang)));
    final res = await DatabaseHelper.instance.fetchMeanings(widget.ingles, widget.currentLang);
    if (res.isEmpty && mounted) { Navigator.pop(context); } else { setState(() => _meanings = res); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.ingles), actions: [IconButton(icon: const Icon(Icons.edit), tooltip: "Editar", onPressed: _irParaEdicao)]),
      body: ListView.separated(
        padding: const EdgeInsets.all(20), itemCount: _meanings.length, separatorBuilder: (_, __) => const Divider(height: 40),
        itemBuilder: (context, index) {
          final sig = _meanings[index];
          final hasImg = sig['imagem'].toString().isNotEmpty;
          return Column(
            children: [
              Text("Significado ${index + 1}: ${sig['traducao']}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: index > 0 ? Colors.blue : null)),
              const SizedBox(height: 10),
              if (hasImg) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(sig['imagem']), height: 180, fit: BoxFit.contain))
            ],
          );
        },
      ),
    );
  }
}

class EditWordScreen extends StatefulWidget {
  final String ingles;
  final List<Map<String, dynamic>> meanings;
  final String currentLang;
  const EditWordScreen({super.key, required this.ingles, required this.meanings, required this.currentLang});
  @override
  State<EditWordScreen> createState() => _EditWordScreenState();
}

class _EditWordScreenState extends State<EditWordScreen> {
  late TextEditingController _inglesCtrl;
  final List<Map<String, dynamic>> _editMeanings = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _inglesCtrl = TextEditingController(text: widget.ingles);
    for (var m in widget.meanings) { _editMeanings.add({ 'id': m['id'], 'traducao': TextEditingController(text: m['traducao']), 'imagem': m['imagem'] }); }
  }

  void _addSignificado() { setState(() { _editMeanings.add({ 'id': null, 'traducao': TextEditingController(), 'imagem': '' }); }); }

  Future<void> _alterarFoto(int index, ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final String newPath = path.join((await getApplicationDocumentsDirectory()).path, 'img_${Random().nextInt(100000)}.jpg');
      final File savedImage = await File(pickedFile.path).copy(newPath);
      setState(() => _editMeanings[index]['imagem'] = savedImage.path);
    }
  }

  void _removerSignificado(int index) {
    if (_editMeanings.length <= 1) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uma palavra precisa ter pelo menos um significado.'))); return; }
    setState(() => _editMeanings.removeAt(index));
  }

  Future<void> _excluirPalavraToda() async {
    bool? conf = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text("Excluir Palavra?"), content: const Text("Deseja apagar esta palavra e TODOS os seus significados nesta língua?"), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancelar")), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text("Excluir"))]));
    if (conf == true) { await DatabaseHelper.instance.deleteAllMeanings(widget.ingles, widget.currentLang); if (!mounted) return; Navigator.pop(context); }
  }

  Future<void> _salvarAlteracoes() async {
    if (_inglesCtrl.text.isEmpty) return;
    try {
      final db = DatabaseHelper.instance;
      await db.deleteAllMeanings(widget.ingles, widget.currentLang);
      for (var m in _editMeanings) {
        String tradText = (m['traducao'] as TextEditingController).text.trim();
        if (tradText.isNotEmpty) await db.insertWord({ 'ingles': _inglesCtrl.text.trim(), 'traducao': tradText, 'imagem': m['imagem'], 'lingua': widget.currentLang });
      }
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alterações salvas!'))); Navigator.pop(context);
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editar Palavra")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              TextField(controller: _inglesCtrl, decoration: InputDecoration(labelText: "Palavra Principal (${widget.currentLang})", border: const OutlineInputBorder()), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              const Text("Significados Registados:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _editMeanings.length,
                  itemBuilder: (context, index) {
                    final m = _editMeanings[index];
                    final hasImg = m['imagem'].toString().isNotEmpty;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          children: [
                            Row(children: [Expanded(child: TextField(controller: m['traducao'], decoration: InputDecoration(labelText: "Significado ${index + 1}"))), IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removerSignificado(index))]),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (hasImg) Container(margin: const EdgeInsets.only(right: 10), child: Image.file(File(m['imagem']), width: 40, height: 40, fit: BoxFit.cover)),
                                TextButton.icon(
                                  icon: const Icon(Icons.image), label: Text(hasImg ? "Alterar Foto" : "Adicionar Foto"),
                                  onPressed: () { showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Wrap(children: [ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Câmera'), onTap: () { Navigator.pop(context); _alterarFoto(index, ImageSource.camera); }), ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeria'), onTap: () { Navigator.pop(context); _alterarFoto(index, ImageSource.gallery); }), if (hasImg) ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Remover Imagem', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); setState(() => m['imagem'] = ''); })])));},
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [OutlinedButton.icon(onPressed: _addSignificado, icon: const Icon(Icons.add), label: const Text("Significado")), TextButton.icon(onPressed: _excluirPalavraToda, icon: const Icon(Icons.delete_forever, color: Colors.red), label: const Text("Excluir Palavra", style: TextStyle(color: Colors.red)))]),
              const Divider(),
              SizedBox(width: double.infinity, height: 45, child: FilledButton.icon(onPressed: _salvarAlteracoes, icon: const Icon(Icons.save), label: const Text("Salvar Alterações")))
            ],
          ),
        ),
      ),
    );
  }
}