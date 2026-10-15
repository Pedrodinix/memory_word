import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:io';
import 'dart:math';
import '../main.dart';

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
      version: 8,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE palavras (id INTEGER PRIMARY KEY AUTOINCREMENT, ingles TEXT NOT NULL, traducao TEXT NOT NULL, imagem TEXT, lingua TEXT NOT NULL DEFAULT 'Inglês', erros INTEGER DEFAULT 0)''');
        await db.execute('''CREATE TABLE configuracoes (chave TEXT PRIMARY KEY, valor TEXT)''');
        await db.execute('''CREATE TABLE estatisticas (data TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0)''');
        await db.execute('''CREATE TABLE estatisticas_mensais (mes TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0)''');

        await db.insert('configuracoes', {'chave': 'filtro', 'valor': 'todas'});
        await db.insert('configuracoes', {'chave': 'tema', 'valor': 'light'});
        await db.insert('configuracoes', {'chave': 'idioma_atual', 'valor': 'Inglês'});
        await db.insert('configuracoes', {'chave': 'idioma_nativo', 'valor': 'Português'});
        await db.insert('configuracoes', {'chave': 'feedback_ativo', 'valor': 'true'});
        await db.insert('configuracoes', {'chave': 'treino_inteligente', 'valor': 'false'});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) try { await db.execute("ALTER TABLE palavras ADD COLUMN lingua TEXT DEFAULT 'Inglês'"); } catch (_) {}
        if (oldVersion < 6) {
          await db.execute('''CREATE TABLE IF NOT EXISTS estatisticas (data TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0)''');
          await db.execute('''CREATE TABLE IF NOT EXISTS estatisticas_mensais (mes TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0)''');
        }
        if (oldVersion < 8) {
          try { await db.execute("ALTER TABLE palavras ADD COLUMN erros INTEGER DEFAULT 0"); } catch (_) {}
        }
      },
    );
  }

  Future<void> atualizarDificuldade(String ingles, String lingua, bool acertou) async {
    final db = await instance.database;
    final res = await db.rawQuery('SELECT MAX(erros) as erros FROM palavras WHERE ingles = ? COLLATE NOCASE AND lingua = ?', [ingles, lingua]);
    int errosAtuais = 0;
    if (res.isNotEmpty && res.first['erros'] != null) {
      errosAtuais = (res.first['erros'] as num).toInt();
    }

    if (acertou) {
      errosAtuais = max(0, errosAtuais - 1);
    } else {
      errosAtuais = min(6, errosAtuais + 1);
    }

    await db.execute('UPDATE palavras SET erros = ? WHERE ingles = ? COLLATE NOCASE AND lingua = ?', [errosAtuais, ingles, lingua]);
  }

  Future<void> registrarAtividade(String coluna, [int valor = 1]) async {
    final db = await instance.database;
    String hoje = DateTime.now().toIso8601String().substring(0, 10);
    String mes = hoje.substring(0, 7);
    await db.execute('INSERT OR IGNORE INTO estatisticas (data) VALUES (?)', [hoje]);
    await db.execute('INSERT OR IGNORE INTO estatisticas_mensais (mes) VALUES (?)', [mes]);
    await db.execute('UPDATE estatisticas SET $coluna = $coluna + ? WHERE data = ?', [valor, hoje]);
    await db.execute('UPDATE estatisticas_mensais SET $coluna = $coluna + ? WHERE mes = ?', [valor, mes]);
  }

  Future<void> limparDadosAntigos() async {
    final db = await instance.database;
    String limite = DateTime.now().subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
    await db.execute('DELETE FROM estatisticas WHERE data < ?', [limite]);
  }

  Future<Map<String, dynamic>> getEstatisticasHoje() async {
    final db = await instance.database;
    String hoje = DateTime.now().toIso8601String().substring(0, 10);
    final res = await db.query('estatisticas', where: 'data = ?', whereArgs: [hoje]);
    return res.isNotEmpty ? res.first : {'respondidas':0, 'acertos':0, 'erros':0, 'especiais':0, 'tempo_papagaio':0};
  }

  Future<Map<String, dynamic>> getEstatisticasSemana() async {
    final db = await instance.database;
    String limite = DateTime.now().subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);
    final res = await db.rawQuery('''SELECT SUM(respondidas) as respondidas, SUM(acertos) as acertos, SUM(erros) as erros, SUM(especiais) as especiais, SUM(tempo_papagaio) as tempo_papagaio FROM estatisticas WHERE data >= ?''', [limite]);
    if (res.isNotEmpty && res.first['respondidas'] != null) return res.first;
    return {'respondidas':0, 'acertos':0, 'erros':0, 'especiais':0, 'tempo_papagaio':0};
  }

  Future<List<Map<String, dynamic>>> getHistoricoMensal() async {
    final db = await instance.database;
    return await db.query('estatisticas_mensais', orderBy: 'mes DESC');
  }

  Future<String> getConfig(String chave) async {
    try {
      final db = await instance.database;
      final res = await db.query('configuracoes', where: 'chave = ?', whereArgs: [chave]);
      if (res.isNotEmpty) return res.first['valor'].toString();
    } catch (_) {} return '';
  }

  Future<void> updateConfig(String chave, String valor) async {
    final db = await instance.database;
    await db.insert('configuracoes', {'chave': chave, 'valor': valor}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertWord(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('palavras', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> fetchCustomWords(String linguaAtual, String filtro, String customVal) async {
    final db = await instance.database;
    int limit = -1;
    if (filtro != 'todas') { limit = filtro == 'custom' ? (int.tryParse(customVal) ?? -1) : (int.tryParse(filtro) ?? -1); }

    String orderBy = 'MAX(id) DESC';
    if (appTreinoInteligente.value) {
      orderBy = 'MAX(erros) DESC, RANDOM()';
    }

    String query = '''SELECT ingles, GROUP_CONCAT(traducao, '|') as traducoes, MAX(imagem) as imagem, MAX(erros) as erros FROM palavras WHERE lingua = ? GROUP BY ingles COLLATE NOCASE ORDER BY $orderBy''';
    if (limit > 0) query += ' LIMIT $limit';
    return await db.rawQuery(query, [linguaAtual]);
  }

  Future<List<Map<String, dynamic>>> fetchDistinctWords(String linguaAtual, [String query = '']) async {
    final db = await instance.database;
    if (query.isEmpty) { return await db.rawQuery('''SELECT ingles, MAX(imagem) as imagem, GROUP_CONCAT(traducao, ', ') as traducao, MAX(erros) as erros FROM palavras WHERE lingua = ? GROUP BY ingles COLLATE NOCASE ORDER BY ingles COLLATE NOCASE ASC''', [linguaAtual]);
    } else { return await db.rawQuery('''SELECT ingles, MAX(imagem) as imagem, GROUP_CONCAT(traducao, ', ') as traducao, MAX(erros) as erros FROM palavras WHERE lingua = ? AND (ingles LIKE ? OR traducao LIKE ?) GROUP BY ingles COLLATE NOCASE ORDER BY ingles COLLATE NOCASE ASC''', [linguaAtual, '%$query%', '%$query%']); }
  }

  Future<List<Map<String, dynamic>>> fetchMeanings(String ingles, String linguaAtual) async {
    final db = await instance.database;
    return await db.query('palavras', where: 'ingles = ? COLLATE NOCASE AND lingua = ?', whereArgs: [ingles, linguaAtual]);
  }

  Future<void> deleteAllMeanings(String ingles, String linguaAtual) async {
    final db = await instance.database;
    await db.delete('palavras', where: 'ingles = ? COLLATE NOCASE AND lingua = ?', whereArgs: [ingles, linguaAtual]);
  }

  // ==========================================
  // FUNÇÕES DE BACKUP (EXPORTAR E IMPORTAR)
  // ==========================================

  Future<void> exportarBackup() async {
    try {
      await instance.database;
      final dbPath = path.join(await getDatabasesPath(), 'dicionario.db');
      final file = File(dbPath);
      if (await file.exists()) {
        await Share.shareXFiles([XFile(dbPath)], text: 'Backup do Memory Word');
      }
    } catch (_) {}
  }

  Future<bool> importarBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        File backupFile = File(result.files.single.path!);

        // Validação de segurança: se o arquivo for menor que 1KB, não é um DB válido
        if (await backupFile.length() < 1024) {
          return false;
        }

        final dbPath = path.join(await getDatabasesPath(), 'dicionario.db');

        if (_database != null) {
          await _database!.close();
          _database = null;
        }

        await backupFile.copy(dbPath);

        try {
          final testDb = await openDatabase(dbPath);
          await testDb.rawQuery('SELECT COUNT(*) FROM palavras');
          await testDb.close();
        } catch (_) {
          return false;
        }

        await database;
        return true;
      }
    } catch (_) {}
    return false;
  }
}