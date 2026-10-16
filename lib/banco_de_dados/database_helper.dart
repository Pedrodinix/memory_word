import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'dart:io';
import 'dart:math';
import '../main.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String? _mediaDirPath;

  DatabaseHelper._init();

  // ==========================================
  // DIRETÓRIO DEDICADO DE IMAGENS DO APP
  // ==========================================
  Future<String> get mediaDirectoryPath async {
    if (_mediaDirPath != null) return _mediaDirPath!;
    final docsDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(path.join(docsDir.path, 'media_memory_word'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    _mediaDirPath = mediaDir.path;
    return _mediaDirPath!;
  }

  /// Inicializa a pasta dedicada de imagens e migra caminhos antigos se existirem
  Future<void> initMediaDirectory() async {
    await mediaDirectoryPath;
    await _migrarCaminhosDeImagensAntigas();
    await limparImagensOrfas();
  }

  /// Resolve o nome do arquivo salvo no banco para o arquivo físico na pasta do app
  File? getImageFile(String? imageRef) {
    if (imageRef == null || imageRef.trim().isEmpty || _mediaDirPath == null) {
      return null;
    }
    final cleanName = path.basename(imageRef.trim());
    final dedicatedFile = File(path.join(_mediaDirPath!, cleanName));
    if (dedicatedFile.existsSync()) {
      return dedicatedFile;
    }
    final legacyFile = File(imageRef.trim());
    if (legacyFile.existsSync()) {
      return legacyFile;
    }
    return null;
  }

  /// Copia uma imagem capturada para a pasta dedicada do app e retorna APENAS o nome do arquivo
  Future<String> saveImageToAppDirectory(String sourceFilePath) async {
    final mediaDir = await mediaDirectoryPath;
    final ext = path.extension(sourceFilePath).isNotEmpty ? path.extension(sourceFilePath) : '.jpg';
    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}$ext';
    final destinationPath = path.join(mediaDir, fileName);
    await File(sourceFilePath).copy(destinationPath);
    return fileName;
  }

  /// Converte caminhos absolutos antigos no banco para apenas o nome do arquivo e move a foto para a pasta dedicada
  Future<void> _migrarCaminhosDeImagensAntigas() async {
    try {
      final db = await database;
      final mediaDir = await mediaDirectoryPath;
      final rows = await db.query('palavras', columns: ['id', 'imagem'], where: "imagem IS NOT NULL AND imagem != ''");

      for (var row in rows) {
        final int id = row['id'] as int;
        final String rawImg = row['imagem']?.toString() ?? '';
        if (rawImg.isEmpty) continue;

        final String fileName = path.basename(rawImg);
        final String targetPath = path.join(mediaDir, fileName);

        if (rawImg != fileName) {
          final oldFile = File(rawImg);
          final newFile = File(targetPath);
          if (await oldFile.exists() && !await newFile.exists()) {
            try {
              await oldFile.copy(targetPath);
              await oldFile.delete();
            } catch (_) {}
          }
          await db.update('palavras', {'imagem': fileName}, where: 'id = ?', whereArgs: [id]);
        }
      }
    } catch (_) {}
  }

  /// Remove imagens físicas da pasta dedicada que não pertencem mais a nenhuma palavra do banco
  Future<void> limparImagensOrfas() async {
    try {
      final db = await database;
      final mediaDir = Directory(await mediaDirectoryPath);
      if (!await mediaDir.exists()) return;

      final rows = await db.rawQuery("SELECT DISTINCT imagem FROM palavras WHERE imagem IS NOT NULL AND imagem != ''");
      final Set<String> activeFiles = rows
          .map((r) => path.basename(r['imagem'].toString().trim()))
          .where((name) => name.isNotEmpty)
          .toSet();

      await for (var entity in mediaDir.list()) {
        if (entity is File) {
          final name = path.basename(entity.path);
          if (!activeFiles.contains(name)) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  // ==========================================
  // INICIALIZAÇÃO DO BANCO SQLITE
  // ==========================================
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
      version: 10,
      onCreate: (db, version) async {
        await db.execute(
          '''CREATE TABLE palavras (id INTEGER PRIMARY KEY AUTOINCREMENT, ingles TEXT NOT NULL, traducao TEXT NOT NULL, imagem TEXT, lingua TEXT NOT NULL DEFAULT 'Inglês', erros INTEGER DEFAULT 0)''',
        );
        await db.execute('''CREATE TABLE configuracoes (chave TEXT PRIMARY KEY, valor TEXT)''');
        await db.execute(
          '''CREATE TABLE estatisticas (data TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0)''',
        );
        await db.execute(
          '''CREATE TABLE estatisticas_mensais (mes TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0)''',
        );

        await db.insert('configuracoes', {'chave': 'filtro', 'valor': 'todas'});
        await db.insert('configuracoes', {'chave': 'tema', 'valor': 'light'});
        await db.insert('configuracoes', {'chave': 'idioma_atual', 'valor': 'Inglês'});
        await db.insert('configuracoes', {'chave': 'idioma_nativo', 'valor': 'Português'});
        await db.insert('configuracoes', {'chave': 'feedback_ativo', 'valor': 'true'});
        await db.insert('configuracoes', {'chave': 'treino_inteligente', 'valor': 'false'});
        await db.insert('configuracoes', {'chave': 'avanco_automatico', 'valor': 'true'});
        await db.insert('configuracoes', {'chave': 'temas_livres', 'valor': ''});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          try {
            await db.execute("ALTER TABLE palavras ADD COLUMN lingua TEXT DEFAULT 'Inglês'");
          } catch (_) {}
        }
        if (oldVersion < 6) {
          await db.execute(
            '''CREATE TABLE IF NOT EXISTS estatisticas (data TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0)''',
          );
          await db.execute(
            '''CREATE TABLE IF NOT EXISTS estatisticas_mensais (mes TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0)''',
          );
        }
        if (oldVersion < 8) {
          try {
            await db.execute("ALTER TABLE palavras ADD COLUMN erros INTEGER DEFAULT 0");
          } catch (_) {}
        }
        if (oldVersion < 9) {
          await db.insert(
            'configuracoes',
            {'chave': 'avanco_automatico', 'valor': 'true'},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await db.insert(
            'configuracoes',
            {'chave': 'temas_livres', 'valor': ''},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      },
    );
  }

  // ==========================================
  // GESTÃO DE BIBLIOTECAS DE TEMAS LIVRES
  // ==========================================
  Future<List<String>> getTemasLivres() async {
    String raw = await getConfig('temas_livres');
    final Set<String> temas = {};
    if (raw.isNotEmpty) {
      for (var item in raw.split('|')) {
        if (item.trim().isNotEmpty) temas.add(item.trim());
      }
    }
    final db = await instance.database;
    final rows = await db.rawQuery("SELECT DISTINCT lingua FROM palavras WHERE lingua LIKE 'tema:%'");
    for (var r in rows) {
      String l = r['lingua']?.toString() ?? '';
      if (l.startsWith('tema:') && l.length > 5) {
        temas.add(l.substring(5));
      }
    }
    return temas.toList();
  }

  Future<void> salvarTemasLivres(List<String> temas) async {
    final limpos = temas.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    await updateConfig('temas_livres', limpos.join('|'));
  }

  Future<void> renomearTemaLivre(String nomeAntigo, String nomeNovo) async {
    final db = await instance.database;
    await db.execute(
      'UPDATE palavras SET lingua = ? WHERE lingua = ?',
      ['tema:$nomeNovo', 'tema:$nomeAntigo'],
    );
    final atuais = await getTemasLivres();
    final idx = atuais.indexOf(nomeAntigo);
    if (idx != -1) {
      atuais[idx] = nomeNovo;
    } else {
      atuais.add(nomeNovo);
    }
    await salvarTemasLivres(atuais);

    String idiomaAtual = await getConfig('idioma_atual');
    if (idiomaAtual == 'tema:$nomeAntigo') {
      await updateConfig('idioma_atual', 'tema:$nomeNovo');
    }
  }

  Future<void> excluirTemaLivre(String nomeTema) async {
    final db = await instance.database;
    await db.delete('palavras', where: 'lingua = ?', whereArgs: ['tema:$nomeTema']);
    final atuais = await getTemasLivres();
    atuais.remove(nomeTema);
    await salvarTemasLivres(atuais);
    await limparImagensOrfas();
  }

  // ==========================================
  // DIFICULDADE E ESTATÍSTICAS
  // ==========================================
  Future<void> atualizarDificuldade(String ingles, String lingua, bool acertou) async {
    final db = await instance.database;
    final res = await db.rawQuery(
      'SELECT MAX(erros) as erros FROM palavras WHERE ingles = ? COLLATE NOCASE AND lingua = ?',
      [ingles, lingua],
    );
    int errosAtuais = 0;
    if (res.isNotEmpty && res.first['erros'] != null) {
      errosAtuais = (res.first['erros'] as num).toInt();
    }

    if (acertou) {
      errosAtuais = max(0, errosAtuais - 1);
    } else {
      errosAtuais = min(6, errosAtuais + 1);
    }

    await db.execute(
      'UPDATE palavras SET erros = ? WHERE ingles = ? COLLATE NOCASE AND lingua = ?',
      [errosAtuais, ingles, lingua],
    );
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
    return res.isNotEmpty
        ? res.first
        : {'respondidas': 0, 'acertos': 0, 'erros': 0, 'especiais': 0, 'tempo_papagaio': 0};
  }

  Future<Map<String, dynamic>> getEstatisticasSemana() async {
    final db = await instance.database;
    String limite = DateTime.now().subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);
    final res = await db.rawQuery(
      '''SELECT SUM(respondidas) as respondidas, SUM(acertos) as acertos, SUM(erros) as erros, SUM(especiais) as especiais, SUM(tempo_papagaio) as tempo_papagaio FROM estatisticas WHERE data >= ?''',
      [limite],
    );
    if (res.isNotEmpty && res.first['respondidas'] != null) return res.first;
    return {'respondidas': 0, 'acertos': 0, 'erros': 0, 'especiais': 0, 'tempo_papagaio': 0};
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
    final cleanRow = Map<String, dynamic>.from(row);
    if (cleanRow['imagem'] != null && cleanRow['imagem'].toString().isNotEmpty) {
      cleanRow['imagem'] = path.basename(cleanRow['imagem'].toString().trim());
    }
    await db.insert('palavras', cleanRow, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> fetchCustomWords(String linguaAtual, String filtro, String customVal) async {
    final db = await instance.database;
    int limit = -1;
    if (filtro != 'todas') {
      limit = filtro == 'custom' ? (int.tryParse(customVal) ?? -1) : (int.tryParse(filtro) ?? -1);
    }

    String orderBy = 'MAX(id) DESC';
    if (appTreinoInteligente.value) {
      orderBy = 'MAX(erros) DESC, RANDOM()';
    }

    String query =
    '''SELECT ingles, GROUP_CONCAT(traducao, '|') as traducoes, MAX(imagem) as imagem, MAX(erros) as erros FROM palavras WHERE lingua = ? GROUP BY ingles COLLATE NOCASE ORDER BY $orderBy''';
    if (limit > 0) query += ' LIMIT $limit';
    return await db.rawQuery(query, [linguaAtual]);
  }

  Future<List<Map<String, dynamic>>> fetchDistinctWords(String linguaAtual, [String query = '']) async {
    final db = await instance.database;
    if (query.isEmpty) {
      return await db.rawQuery(
        '''SELECT ingles, MAX(imagem) as imagem, GROUP_CONCAT(traducao, ', ') as traducao, MAX(erros) as erros FROM palavras WHERE lingua = ? GROUP BY ingles COLLATE NOCASE ORDER BY ingles COLLATE NOCASE ASC''',
        [linguaAtual],
      );
    } else {
      return await db.rawQuery(
        '''SELECT ingles, MAX(imagem) as imagem, GROUP_CONCAT(traducao, ', ') as traducao, MAX(erros) as erros FROM palavras WHERE lingua = ? AND (ingles LIKE ? OR traducao LIKE ?) GROUP BY ingles COLLATE NOCASE ORDER BY ingles COLLATE NOCASE ASC''',
        [linguaAtual, '%$query%', '%$query%'],
      );
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

  // ==========================================
  // BACKUP COMPLETO (.ZIP COM BANCO + IMAGENS)
  // ==========================================
  Future<void> exportarBackup() async {
    try {
      await initMediaDirectory();
      final db = await database;
      // Garante que todos os dados em cache WAL sejam gravados no arquivo físico antes de ler os bytes
      try {
        await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      } catch (_) {}

      final dbPath = path.join(await getDatabasesPath(), 'dicionario.db');
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) return;

      final archive = Archive();

      // 1. Adiciona o banco de dados SQLite ao pacote
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('dicionario.db', dbBytes.length, dbBytes));

      // 2. Adiciona todas as imagens ativas da pasta dedicada dentro de 'media/'
      final mediaDir = Directory(await mediaDirectoryPath);
      if (await mediaDir.exists()) {
        await for (var entity in mediaDir.list()) {
          if (entity is File) {
            final fileName = path.basename(entity.path);
            final imgBytes = await entity.readAsBytes();
            archive.addFile(ArchiveFile('media/$fileName', imgBytes.length, imgBytes));
          }
        }
      }

      // 3. Codifica o pacote .zip em diretório temporário e abre o menu de compartilhamento
      final zipBytes = ZipEncoder().encode(archive);
      final tempDir = await getTemporaryDirectory();
      final zipPath = path.join(tempDir.path, 'backup_memory_word.zip');
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipBytes, flush: true);

      await Share.shareXFiles([XFile(zipPath)], text: 'Backup Completo MemoryWord');
    } catch (_) {}
  }

  Future<void> _limparArquivosWalAuxiliares(String dbPath) async {
    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');
    try {
      if (await walFile.exists()) await walFile.delete();
    } catch (_) {}
    try {
      if (await shmFile.exists()) await shmFile.delete();
    } catch (_) {}
  }

  Future<bool> importarBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final selectedFile = File(result.files.single.path!);
      if (await selectedFile.length() < 512) {
        return false;
      }

      final bytes = await selectedFile.readAsBytes();
      final dbPath = path.join(await getDatabasesPath(), 'dicionario.db');
      final tempDir = await getTemporaryDirectory();
      final mediaDir = await mediaDirectoryPath;

      // Verifica pelos primeiros bytes se é um pacote .ZIP ('PK' -> 0x50, 0x4B)
      final bool isZipPackage = bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;

      if (isZipPackage) {
        final archive = ZipDecoder().decodeBytes(bytes);

        ArchiveFile? dbEntry;
        for (final file in archive) {
          if (file.isFile && path.basename(file.name) == 'dicionario.db') {
            dbEntry = file;
            break;
          }
        }

        if (dbEntry == null) return false;

        // Testa integridade do banco antes de substituir o atual
        final tempDbPath = path.join(tempDir.path, 'temp_validacao.db');
        final tempDbFile = File(tempDbPath);
        await _limparArquivosWalAuxiliares(tempDbPath);
        final List<int> dbBytes = List<int>.from(dbEntry.content as Iterable<int>);
        await tempDbFile.writeAsBytes(dbBytes, flush: true);

        try {
          final testDb = await openDatabase(tempDbPath);
          await testDb.rawQuery('SELECT COUNT(*) FROM palavras');
          await testDb.close();
        } catch (_) {
          if (await tempDbFile.exists()) await tempDbFile.delete();
          await _limparArquivosWalAuxiliares(tempDbPath);
          return false;
        }

        // Fecha o banco ativo, remove resíduos WAL/SHM e substitui pelo banco do backup
        if (_database != null) {
          await _database!.close();
          _database = null;
        }
        await _limparArquivosWalAuxiliares(dbPath);
        await tempDbFile.copy(dbPath);
        if (await tempDbFile.exists()) await tempDbFile.delete();
        await _limparArquivosWalAuxiliares(tempDbPath);

        // Extrai todas as imagens do pacote diretamente para a pasta dedicada do aplicativo
        for (final file in archive) {
          if (file.isFile && file.name != dbEntry.name) {
            final imgFileName = path.basename(file.name);
            if (imgFileName.isNotEmpty) {
              final outFile = File(path.join(mediaDir, imgFileName));
              final List<int> imgBytes = List<int>.from(file.content as Iterable<int>);
              await outFile.writeAsBytes(imgBytes, flush: true);
            }
          }
        }
      } else {
        // Suporte retrocompatível para arquivos .db antigos
        final tempDbPath = path.join(tempDir.path, 'temp_validacao_legacy.db');
        final tempDbFile = File(tempDbPath);
        await _limparArquivosWalAuxiliares(tempDbPath);
        await selectedFile.copy(tempDbPath);

        try {
          final testDb = await openDatabase(tempDbPath);
          await testDb.rawQuery('SELECT COUNT(*) FROM palavras');
          await testDb.close();
        } catch (_) {
          if (await tempDbFile.exists()) await tempDbFile.delete();
          await _limparArquivosWalAuxiliares(tempDbPath);
          return false;
        }

        if (_database != null) {
          await _database!.close();
          _database = null;
        }
        await _limparArquivosWalAuxiliares(dbPath);
        await tempDbFile.copy(dbPath);
        if (await tempDbFile.exists()) await tempDbFile.delete();
        await _limparArquivosWalAuxiliares(tempDbPath);
      }

      // Reabre o banco, normaliza eventuais caminhos antigos e limpa imagens órfãs
      await database;
      await _migrarCaminhosDeImagensAntigas();
      await limparImagensOrfas();
      return true;
    } catch (_) {
      return false;
    }
  }
}