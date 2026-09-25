import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:translator/translator.dart' as tr;
import 'dart:io';
import 'dart:math';

// Variável global para controlar o tema em tempo real
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // LER A CONFIGURAÇÃO SALVA ANTES DE INICIAR O APP
  String temaSalvo = await DatabaseHelper.instance.getConfig('tema');
  if (temaSalvo == 'dark') {
    appThemeMode.value = ThemeMode.dark;
  } else {
    appThemeMode.value = ThemeMode.light;
  }

  runApp(const MemoryWordApp());
}

// ==========================================
// BANCO DE DADOS (Com Migração Versão 2)
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dicionario.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, filePath);

    return await openDatabase(
      fullPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE palavras (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ingles TEXT NOT NULL,
            traducao TEXT NOT NULL,
            imagem TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE configuracoes (
            chave TEXT PRIMARY KEY,
            valor TEXT
          )
        ''');
        await db.insert('configuracoes', {'chave': 'filtro', 'valor': 'todas'}, conflictAlgorithm: ConflictAlgorithm.replace);
        await db.insert('configuracoes', {'chave': 'custom_val', 'valor': ''}, conflictAlgorithm: ConflictAlgorithm.replace);
        await db.insert('configuracoes', {'chave': 'tema', 'valor': 'light'}, conflictAlgorithm: ConflictAlgorithm.replace);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS configuracoes (
              chave TEXT PRIMARY KEY,
              valor TEXT
            )
          ''');
          await db.insert('configuracoes', {'chave': 'filtro', 'valor': 'todas'}, conflictAlgorithm: ConflictAlgorithm.replace);
          await db.insert('configuracoes', {'chave': 'custom_val', 'valor': ''}, conflictAlgorithm: ConflictAlgorithm.replace);
          await db.insert('configuracoes', {'chave': 'tema', 'valor': 'light'}, conflictAlgorithm: ConflictAlgorithm.replace);
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
    await db.insert(
      'configuracoes',
      {'chave': chave, 'valor': valor},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertWord(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('palavras', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> fetchWordsForPractice() async {
    final db = await instance.database;
    String filtro = await getConfig('filtro');

    int limit = -1;
    if (filtro != 'todas') {
      if (filtro == 'custom') {
        String customVal = await getConfig('custom_val');
        limit = int.tryParse(customVal) ?? -1;
      } else {
        limit = int.tryParse(filtro) ?? -1;
      }
    }

    String query = '''
      SELECT ingles, 
             GROUP_CONCAT(traducao, '|') as traducoes, 
             MAX(imagem) as imagem
      FROM palavras
      GROUP BY ingles COLLATE NOCASE
      ORDER BY MAX(id) DESC
    ''';

    if (limit > 0) {
      query += ' LIMIT $limit';
    }

    return await db.rawQuery(query);
  }

  Future<List<Map<String, dynamic>>> fetchDistinctWords([String query = '']) async {
    final db = await instance.database;
    if (query.isEmpty) {
      return await db.rawQuery('''
        SELECT ingles, 
               MAX(imagem) as imagem, 
               GROUP_CONCAT(traducao, ', ') as traducao 
        FROM palavras 
        GROUP BY ingles COLLATE NOCASE 
        ORDER BY ingles COLLATE NOCASE ASC
      ''');
    } else {
      return await db.rawQuery('''
        SELECT ingles, 
               MAX(imagem) as imagem, 
               GROUP_CONCAT(traducao, ', ') as traducao 
        FROM palavras 
        WHERE ingles LIKE ? OR traducao LIKE ? 
        GROUP BY ingles COLLATE NOCASE 
        ORDER BY ingles COLLATE NOCASE ASC
      ''', ['%$query%', '%$query%']);
    }
  }

  Future<List<Map<String, dynamic>>> fetchMeanings(String ingles) async {
    final db = await instance.database;
    return await db.query('palavras', where: 'ingles = ? COLLATE NOCASE', whereArgs: [ingles]);
  }

  Future<void> deleteAllMeanings(String ingles) async {
    final db = await instance.database;
    await db.delete('palavras', where: 'ingles = ? COLLATE NOCASE', whereArgs: [ingles]);
  }
}

// ==========================================
// APLICATIVO PRINCIPAL E TEMA
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
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const RegisterTab(),
    const PracticeTab(),
    const LibraryTab(),
  ];

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
        title: const Text('MemoryWord'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Configurações",
            onPressed: _abrirConfiguracoes,
          )
        ],
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
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
// MENU DE CONFIGURAÇÕES
// ==========================================
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool _isDark = false;
  String _filtro = 'todas';
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

    setState(() {
      _isDark = tema == 'dark';
      _filtro = filtro.isEmpty ? 'todas' : filtro;
      _customCtrl.text = customVal;
    });
  }

  Future<void> _salvar() async {
    if (_filtro == 'custom') {
      int? val = int.tryParse(_customCtrl.text.trim());
      if (val == null || val <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Insira um número válido maior que 0 para o filtro personalizado.'))
        );
        return;
      }
    }

    try {
      final db = DatabaseHelper.instance;
      String novoTema = _isDark ? 'dark' : 'light';

      await db.updateConfig('tema', novoTema);
      await db.updateConfig('filtro', _filtro);
      await db.updateConfig('custom_val', _customCtrl.text.trim());

      appThemeMode.value = _isDark ? ThemeMode.dark : ThemeMode.light;

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurações salvas!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Aparência", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SwitchListTile(
                title: const Text("Modo Noturno"),
                value: _isDark,
                onChanged: (val) => setState(() => _isDark = val),
              ),
              const Divider(),
              const Text("Filtro de Sorteio (Prática)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              RadioListTile(title: const Text("Todas as palavras"), value: 'todas', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              RadioListTile(title: const Text("Últimas 10 registadas"), value: '10', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              RadioListTile(title: const Text("Últimas 20 registadas"), value: '20', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              RadioListTile(title: const Text("Últimas 30 registadas"), value: '30', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              RadioListTile(title: const Text("Personalizado"), value: 'custom', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              if (_filtro == 'custom')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: TextField(
                    controller: _customCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Nº Personalizado (> 0)", border: OutlineInputBorder()),
                  ),
                ),
              const Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: _salvar, child: const Text("Salvar")),
              ),
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
  const RegisterTab({super.key});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  final _inglesCtrl = TextEditingController();
  final _traducaoCtrl = TextEditingController();
  File? _imageFile;
  bool _isTranslating = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _translateWord() async {
    if (_inglesCtrl.text.isEmpty) return;
    setState(() => _isTranslating = true);
    try {
      final translator = tr.GoogleTranslator();
      final translation = await translator.translate(_inglesCtrl.text.trim(), from: 'en', to: 'pt');
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
      final directory = await getApplicationDocumentsDirectory();
      final String newPath = path.join(directory.path, 'img_${Random().nextInt(100000)}.jpg');
      final File savedImage = await File(pickedFile.path).copy(newPath);
      setState(() => _imageFile = savedImage);
    }
  }

  Future<void> _saveWord() async {
    if (_inglesCtrl.text.isEmpty || _traducaoCtrl.text.isEmpty) return;

    final db = DatabaseHelper.instance;
    final ex = await db.fetchMeanings(_inglesCtrl.text.trim());

    if (ex.isNotEmpty) {
      if (!mounted) return;
      bool? addAnother = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Palavra Existente"),
            content: const Text("Esta palavra já existe na biblioteca. Deseja adicionar este novo significado a ela?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancelar")),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text("Sim")),
            ],
          )
      );
      if (addAnother != true) return;
    }

    await db.insertWord({
      'ingles': _inglesCtrl.text.trim(),
      'traducao': _traducaoCtrl.text.trim(),
      'imagem': _imageFile?.path ?? '',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Palavra salva com sucesso!')));
    setState(() {
      _inglesCtrl.clear();
      _traducaoCtrl.clear();
      _imageFile = null;
    });
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
              Expanded(
                child: TextField(controller: _inglesCtrl, decoration: const InputDecoration(labelText: 'Palavra em Inglês', border: OutlineInputBorder())),
              ),
              IconButton(icon: _isTranslating ? const CircularProgressIndicator() : const Icon(Icons.g_translate, color: Colors.blue), onPressed: _translateWord),
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
// ABA 2: PRÁTICA (MODIFICADA PARA MÚLTIPLOS SIGNIFICADOS)
// ==========================================
class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  Map<String, dynamic>? _currentWord;
  final _answerCtrl = TextEditingController();
  String _resultText = '';
  Color _resultColor = Colors.black;

  Future<void> _drawWord() async {
    final words = await DatabaseHelper.instance.fetchWordsForPractice();
    if (words.isEmpty) {
      setState(() {
        _resultText = 'Nenhuma palavra atende ao filtro atual.';
        _resultColor = Colors.orange;
      });
      return;
    }
    setState(() {
      _currentWord = words[Random().nextInt(words.length)];
      _answerCtrl.clear();
      _resultText = '';
    });
  }

  void _verifyAnswer() {
    if (_currentWord == null || _answerCtrl.text.isEmpty) return;

    final userAnswer = _answerCtrl.text.trim().toLowerCase();

    // Extrai todas as respostas válidas que foram agrupadas no banco
    final List<String> correctAnswers = _currentWord!['traducoes']
        .toString()
        .split('|')
        .map((e) => e.trim().toLowerCase())
        .toList();

    setState(() {
      if (correctAnswers.contains(userAnswer)) {
        _resultText = 'Resposta Correta! 🎉';
        _resultColor = Colors.green;
      } else {
        // Exibe todas as opções corretas de forma amigável se o usuário errar
        final displayCorrect = _currentWord!['traducoes'].toString().replaceAll('|', ' ou ');
        _resultText = 'Incorreta. O correto é: $displayCorrect';
        _resultColor = Colors.red;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          FilledButton.icon(icon: const Icon(Icons.shuffle), label: const Text('Sortear Palavra'), onPressed: _drawWord),
          const SizedBox(height: 30),
          Text(_currentWord?['ingles'] ?? 'Clique acima para sortear', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextField(
            controller: _answerCtrl,
            enabled: _currentWord != null,
            decoration: const InputDecoration(labelText: 'Sua Tradução', border: OutlineInputBorder()),
            onChanged: (v) => setState((){}),
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: (_currentWord == null || _answerCtrl.text.isEmpty) ? null : _verifyAnswer,
            child: const Text('Confirmar Resposta'),
          ),
          const SizedBox(height: 20),
          Text(_resultText, style: TextStyle(fontSize: 18, color: _resultColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (_resultText.isNotEmpty && _currentWord?['imagem'] != null && _currentWord!['imagem'] != '')
            Expanded(child: Image.file(File(_currentWord!['imagem']), fit: BoxFit.contain)),
        ],
      ),
    );
  }
}

// ==========================================
// ABA 3: BIBLIOTECA
// ==========================================
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  List<Map<String, dynamic>> _distinctWords = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords([String query = '']) async {
    final words = await DatabaseHelper.instance.fetchDistinctWords(query);
    setState(() => _distinctWords = words);
  }

  void _abrirDetalhes(String ingles) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => WordDetailsScreen(ingles: ingles)));
    _loadWords(_searchCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        children: [
          const Text("Sua Biblioteca", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(labelText: 'Pesquisar...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
            onChanged: (value) => _loadWords(value),
          ),
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
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: hasImage
                        ? CircleAvatar(backgroundImage: FileImage(File(word['imagem'])))
                        : const CircleAvatar(child: Icon(Icons.text_fields)),
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

// ==========================================
// TELA DE DETALHES
// ==========================================
class WordDetailsScreen extends StatefulWidget {
  final String ingles;
  const WordDetailsScreen({super.key, required this.ingles});

  @override
  State<WordDetailsScreen> createState() => _WordDetailsScreenState();
}

class _WordDetailsScreenState extends State<WordDetailsScreen> {
  List<Map<String, dynamic>> _meanings = [];

  @override
  void initState() {
    super.initState();
    _loadMeanings();
  }

  Future<void> _loadMeanings() async {
    final res = await DatabaseHelper.instance.fetchMeanings(widget.ingles);
    setState(() => _meanings = res);
  }

  void _irParaEdicao() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => EditWordScreen(ingles: widget.ingles, meanings: _meanings)));
    final res = await DatabaseHelper.instance.fetchMeanings(widget.ingles);
    if (res.isEmpty && mounted) {
      Navigator.pop(context);
    } else {
      setState(() => _meanings = res);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ingles),
        actions: [
          IconButton(icon: const Icon(Icons.edit), tooltip: "Editar", onPressed: _irParaEdicao),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _meanings.length,
        separatorBuilder: (_, __) => const Divider(height: 40),
        itemBuilder: (context, index) {
          final sig = _meanings[index];
          final hasImg = sig['imagem'].toString().isNotEmpty;
          return Column(
            children: [
              Text("Significado ${index + 1}: ${sig['traducao']}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: index > 0 ? Colors.blue : null)),
              const SizedBox(height: 10),
              if (hasImg)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(sig['imagem']), height: 180, fit: BoxFit.contain),
                )
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// TELA DE EDIÇÃO MULTINÍVEL
// ==========================================
class EditWordScreen extends StatefulWidget {
  final String ingles;
  final List<Map<String, dynamic>> meanings;

  const EditWordScreen({super.key, required this.ingles, required this.meanings});

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
    for (var m in widget.meanings) {
      _editMeanings.add({
        'id': m['id'],
        'traducao': TextEditingController(text: m['traducao']),
        'imagem': m['imagem'],
      });
    }
  }

  void _addSignificado() {
    setState(() {
      _editMeanings.add({
        'id': null,
        'traducao': TextEditingController(),
        'imagem': '',
      });
    });
  }

  Future<void> _alterarFoto(int index, ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      final String newPath = path.join(directory.path, 'img_${Random().nextInt(100000)}.jpg');
      final File savedImage = await File(pickedFile.path).copy(newPath);
      setState(() => _editMeanings[index]['imagem'] = savedImage.path);
    }
  }

  void _removerSignificado(int index) {
    if (_editMeanings.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uma palavra precisa ter pelo menos um significado.')));
      return;
    }
    setState(() => _editMeanings.removeAt(index));
  }

  Future<void> _excluirPalavraToda() async {
    bool? conf = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Excluir Palavra?"),
          content: const Text("Deseja apagar esta palavra e TODOS os seus significados?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancelar")),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(c, true),
                child: const Text("Excluir")
            ),
          ],
        )
    );

    if (conf == true) {
      await DatabaseHelper.instance.deleteAllMeanings(widget.ingles);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _salvarAlteracoes() async {
    if (_inglesCtrl.text.isEmpty) return;

    final db = DatabaseHelper.instance;
    await db.deleteAllMeanings(widget.ingles);

    for (var m in _editMeanings) {
      String tradText = (m['traducao'] as TextEditingController).text.trim();
      if (tradText.isNotEmpty) {
        await db.insertWord({
          'ingles': _inglesCtrl.text.trim(),
          'traducao': tradText,
          'imagem': m['imagem'],
        });
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alterações salvas!')));
    Navigator.pop(context);
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
              TextField(
                controller: _inglesCtrl,
                decoration: const InputDecoration(labelText: "Palavra Principal (Inglês)", border: OutlineInputBorder()),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
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
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: m['traducao'],
                                    decoration: InputDecoration(labelText: "Significado ${index + 1}"),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _removerSignificado(index),
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (hasImg)
                                  Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    child: Image.file(File(m['imagem']), width: 40, height: 40, fit: BoxFit.cover),
                                  ),
                                TextButton.icon(
                                  icon: const Icon(Icons.image),
                                  label: Text(hasImg ? "Alterar Foto" : "Adicionar Foto"),
                                  onPressed: () {
                                    showModalBottomSheet(context: context, builder: (_) => SafeArea(
                                      child: Wrap(
                                        children: [
                                          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Câmera'), onTap: () { Navigator.pop(context); _alterarFoto(index, ImageSource.camera); }),
                                          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeria'), onTap: () { Navigator.pop(context); _alterarFoto(index, ImageSource.gallery); }),
                                          if (hasImg)
                                            ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Remover Imagem', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); setState(() => m['imagem'] = ''); }),
                                        ],
                                      ),
                                    ));
                                  },
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(onPressed: _addSignificado, icon: const Icon(Icons.add), label: const Text("Significado")),
                  TextButton.icon(onPressed: _excluirPalavraToda, icon: const Icon(Icons.delete_forever, color: Colors.red), label: const Text("Excluir Palavra", style: TextStyle(color: Colors.red))),
                ],
              ),
              const Divider(),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: FilledButton.icon(onPressed: _salvarAlteracoes, icon: const Icon(Icons.save), label: const Text("Salvar Alterações")),
              )
            ],
          ),
        ),
      ),
    );
  }
}