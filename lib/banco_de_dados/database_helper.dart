import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'dart:convert';
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
  // INICIALIZAÇÃO DO BANCO SQLITE (VERSÃO 13)
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
      version: 13,
      onCreate: (db, version) async {
        await db.execute(
          '''CREATE TABLE palavras (id INTEGER PRIMARY KEY AUTOINCREMENT, ingles TEXT NOT NULL, traducao TEXT NOT NULL, imagem TEXT, lingua TEXT NOT NULL DEFAULT 'Inglês', erros INTEGER DEFAULT 0, oculto INTEGER DEFAULT 0)''',
        );
        await db.execute('''CREATE TABLE configuracoes (chave TEXT PRIMARY KEY, valor TEXT)''');
        await db.execute(
          '''CREATE TABLE estatisticas (data TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0, registradas INTEGER DEFAULT 0)''',
        );
        await db.execute(
          '''CREATE TABLE estatisticas_mensais (mes TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0, registradas INTEGER DEFAULT 0)''',
        );
        await db.execute(
          '''CREATE TABLE notificacoes (id INTEGER PRIMARY KEY AUTOINCREMENT, titulo TEXT NOT NULL, mensagem TEXT NOT NULL, data_hora TEXT NOT NULL, tipo TEXT NOT NULL DEFAULT 'lembrete', lida INTEGER DEFAULT 0)''',
        );

        await db.insert('configuracoes', {'chave': 'filtro', 'valor': 'todas'});
        await db.insert('configuracoes', {'chave': 'tema', 'valor': 'light'});
        await db.insert('configuracoes', {'chave': 'idioma_atual', 'valor': 'Inglês'});
        await db.insert('configuracoes', {'chave': 'idioma_nativo', 'valor': 'Português'});
        await db.insert('configuracoes', {'chave': 'feedback_ativo', 'valor': 'true'});
        await db.insert('configuracoes', {'chave': 'treino_inteligente', 'valor': 'false'});
        await db.insert('configuracoes', {'chave': 'avanco_automatico', 'valor': 'false'});
        await db.insert('configuracoes', {'chave': 'temas_livres', 'valor': ''});

        // Configurações de Tutorial (abre apenas na 1ª vez) e Lembretes/Notificações
        await db.insert('configuracoes', {'chave': 'tutorial_inicial_concluido', 'valor': 'false'});
        await db.insert('configuracoes', {'chave': 'notificacoes_silenciadas', 'valor': 'false'});
        await db.insert('configuracoes', {'chave': 'lembrete_ativo', 'valor': 'false'});
        await db.insert('configuracoes', {'chave': 'lembrete_dias', 'valor': '1,2,3,4,5'});
        await db.insert('configuracoes', {'chave': 'lembrete_horario', 'valor': '19:00'});
        await db.insert('configuracoes', {'chave': 'ultimo_lembrete_data', 'valor': ''});
        await db.insert('configuracoes', {'chave': 'ultimo_progresso_data', 'valor': ''});
        await db.insert('configuracoes', {'chave': 'ultimo_progresso_assinatura', 'valor': ''});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          try {
            await db.execute("ALTER TABLE palavras ADD COLUMN lingua TEXT DEFAULT 'Inglês'");
          } catch (_) {}
        }
        if (oldVersion < 6) {
          await db.execute(
            '''CREATE TABLE IF NOT EXISTS estatisticas (data TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0, registradas INTEGER DEFAULT 0)''',
          );
          await db.execute(
            '''CREATE TABLE IF NOT EXISTS estatisticas_mensais (mes TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0, registradas INTEGER DEFAULT 0)''',
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
            {'chave': 'avanco_automatico', 'valor': 'false'},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await db.insert(
            'configuracoes',
            {'chave': 'temas_livres', 'valor': ''},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        if (oldVersion < 11) {
          try {
            await db.execute("ALTER TABLE palavras ADD COLUMN oculto INTEGER DEFAULT 0");
          } catch (_) {}
        }
        if (oldVersion < 12) {
          await db.insert(
            'configuracoes',
            {'chave': 'avanco_automatico', 'valor': 'false'},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        if (oldVersion < 13) {
          try {
            await db.execute("ALTER TABLE estatisticas ADD COLUMN registradas INTEGER DEFAULT 0");
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE estatisticas_mensais ADD COLUMN registradas INTEGER DEFAULT 0");
          } catch (_) {}
          await db.execute(
            '''CREATE TABLE IF NOT EXISTS notificacoes (id INTEGER PRIMARY KEY AUTOINCREMENT, titulo TEXT NOT NULL, mensagem TEXT NOT NULL, data_hora TEXT NOT NULL, tipo TEXT NOT NULL DEFAULT 'lembrete', lida INTEGER DEFAULT 0)''',
          );
          await db.insert(
            'configuracoes',
            {'chave': 'tutorial_inicial_concluido', 'valor': 'false'},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await db.insert(
            'configuracoes',
            {'chave': 'notificacoes_silenciadas', 'valor': 'false'},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await db.insert(
            'configuracoes',
            {'chave': 'lembrete_ativo', 'valor': 'false'},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await db.insert(
            'configuracoes',
            {'chave': 'lembrete_dias', 'valor': '1,2,3,4,5'},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await db.insert(
            'configuracoes',
            {'chave': 'lembrete_horario', 'valor': '19:00'},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await db.insert(
            'configuracoes',
            {'chave': 'ultimo_lembrete_data', 'valor': ''},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await db.insert(
            'configuracoes',
            {'chave': 'ultimo_progresso_data', 'valor': ''},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await db.insert(
            'configuracoes',
            {'chave': 'ultimo_progresso_assinatura', 'valor': ''},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      },
    );
  }

  // ==========================================
  // GESTÃO DE NOTIFICAÇÕES E LEMBRETES
  // ==========================================
  Future<int> inserirNotificacao({
    required String titulo,
    required String mensagem,
    String tipo = 'lembrete',
  }) async {
    final db = await instance.database;
    final String agora = DateTime.now().toIso8601String();
    return await db.insert('notificacoes', {
      'titulo': titulo,
      'mensagem': mensagem,
      'data_hora': agora,
      'tipo': tipo,
      'lida': 0,
    });
  }

  Future<List<Map<String, dynamic>>> listarNotificacoes() async {
    final db = await instance.database;
    return await db.query('notificacoes', orderBy: 'id DESC', limit: 50);
  }

  Future<int> contarNotificacoesNaoLidas() async {
    final db = await instance.database;
    final res = await db.rawQuery('SELECT COUNT(*) as total FROM notificacoes WHERE lida = 0');
    if (res.isNotEmpty && res.first['total'] != null) {
      return (res.first['total'] as num).toInt();
    }
    return 0;
  }

  Future<void> marcarTodasNotificacoesComoLidas() async {
    final db = await instance.database;
    await db.update('notificacoes', {'lida': 1}, where: 'lida = 0');
  }

  Future<void> limparNotificacoes() async {
    final db = await instance.database;
    await db.delete('notificacoes');
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
  // DIFICULDADE, REIVINDICAÇÃO E ESTATÍSTICAS
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

  /// Reverte a penalidade de um erro quando o utilizador reivindica a resposta como correta
  Future<void> reverterErroParaAcerto(String ingles, String lingua, {bool gerouComboEspecial = false}) async {
    final db = await instance.database;
    String hoje = DateTime.now().toIso8601String().substring(0, 10);
    String mes = hoje.substring(0, 7);

    await db.execute(
      'UPDATE estatisticas SET erros = MAX(0, erros - 1), acertos = acertos + 1 WHERE data = ?',
      [hoje],
    );
    await db.execute(
      'UPDATE estatisticas_mensais SET erros = MAX(0, erros - 1), acertos = acertos + 1 WHERE mes = ?',
      [mes],
    );

    if (gerouComboEspecial) {
      await registrarAtividade('especiais', 1);
    }

    final res = await db.rawQuery(
      'SELECT MAX(erros) as erros FROM palavras WHERE ingles = ? COLLATE NOCASE AND lingua = ?',
      [ingles, lingua],
    );
    int errosAtuais = 0;
    if (res.isNotEmpty && res.first['erros'] != null) {
      errosAtuais = (res.first['erros'] as num).toInt();
    }
    int novoErro = max(0, errosAtuais - 2);
    await db.execute(
      'UPDATE palavras SET erros = ? WHERE ingles = ? COLLATE NOCASE AND lingua = ?',
      [novoErro, ingles, lingua],
    );
  }

  /// Adiciona um novo significado (visível ou oculto) a uma palavra existente sem duplicar
  Future<void> adicionarSignificadoReivindicado({
    required String ingles,
    required String novaTraducao,
    required String lingua,
    required bool oculto,
  }) async {
    final db = await instance.database;
    final String cleanIngles = ingles.trim();
    final String cleanTrad = novaTraducao.trim();
    if (cleanIngles.isEmpty || cleanTrad.isEmpty) return;

    final existingMeanings = await fetchMeanings(cleanIngles, lingua);
    int errosAtuais = 0;
    if (existingMeanings.isNotEmpty) {
      errosAtuais = (existingMeanings.first['erros'] as num?)?.toInt() ?? 0;
    }

    final String normNew = _normalizeText(cleanTrad);
    for (var m in existingMeanings) {
      final String mTrad = (m['traducao']?.toString() ?? '').trim();
      if (_normalizeText(mTrad) == normNew) {
        return;
      }
    }

    await db.insert('palavras', {
      'ingles': cleanIngles,
      'traducao': cleanTrad,
      'imagem': '',
      'lingua': lingua,
      'erros': errosAtuais,
      'oculto': oculto ? 1 : 0,
    });
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
        : {
      'respondidas': 0,
      'acertos': 0,
      'erros': 0,
      'especiais': 0,
      'tempo_papagaio': 0,
      'registradas': 0,
    };
  }

  Future<Map<String, dynamic>> getEstatisticasSemana() async {
    final db = await instance.database;
    String limite = DateTime.now().subtract(const Duration(days: 7)).toIso8601String().substring(0, 10);
    final res = await db.rawQuery(
      '''SELECT SUM(respondidas) as respondidas, SUM(acertos) as acertos, SUM(erros) as erros, SUM(especiais) as especiais, SUM(tempo_papagaio) as tempo_papagaio, SUM(registradas) as registradas FROM estatisticas WHERE data >= ?''',
      [limite],
    );
    if (res.isNotEmpty && res.first['respondidas'] != null) return res.first;
    return {
      'respondidas': 0,
      'acertos': 0,
      'erros': 0,
      'especiais': 0,
      'tempo_papagaio': 0,
      'registradas': 0,
    };
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
    cleanRow['oculto'] = (cleanRow['oculto'] == 1 || cleanRow['oculto'] == true) ? 1 : 0;
    await db.insert('palavras', cleanRow, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _normalizeText(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _insertWordIfNotExists(Database db, Map<String, dynamic> row) async {
    final String ingles = (row['ingles']?.toString() ?? '').trim();
    final String traducao = (row['traducao']?.toString() ?? '').trim();
    final String lingua = (row['lingua']?.toString() ?? 'Inglês').trim();
    if (ingles.isEmpty || traducao.isEmpty) return;

    String imgName = (row['imagem']?.toString() ?? '').trim();
    if (imgName.isNotEmpty) {
      imgName = path.basename(imgName);
    }
    final int importedErros = (row['erros'] is num) ? (row['erros'] as num).toInt() : 0;
    final int importedOculto = (row['oculto'] == 1 || row['oculto'] == true) ? 1 : 0;

    final existingWordRows = await db.query(
      'palavras',
      where: 'ingles = ? COLLATE NOCASE AND lingua = ?',
      whereArgs: [ingles, lingua],
    );

    if (existingWordRows.isEmpty) {
      await db.insert('palavras', {
        'ingles': ingles,
        'traducao': traducao,
        'imagem': imgName,
        'lingua': lingua,
        'erros': importedErros,
        'oculto': importedOculto,
      });
      return;
    }

    final String canonicalIngles = existingWordRows.first['ingles'].toString();
    final int currentErros = (existingWordRows.first['erros'] as num?)?.toInt() ?? importedErros;
    final String normImportedTrad = _normalizeText(traducao);

    Map<String, dynamic>? matchingMeaningRow;
    for (var existing in existingWordRows) {
      final String existingTrad = (existing['traducao']?.toString() ?? '').trim();
      if (existingTrad.toLowerCase() == traducao.toLowerCase() ||
          (normImportedTrad.isNotEmpty && _normalizeText(existingTrad) == normImportedTrad)) {
        matchingMeaningRow = existing;
        break;
      }
    }

    if (matchingMeaningRow != null) {
      final String localImg = (matchingMeaningRow['imagem']?.toString() ?? '').trim();
      if (localImg.isEmpty && imgName.isNotEmpty) {
        await db.update(
          'palavras',
          {'imagem': imgName},
          where: 'id = ?',
          whereArgs: [matchingMeaningRow['id']],
        );
      }
    } else {
      await db.insert('palavras', {
        'ingles': canonicalIngles,
        'traducao': traducao,
        'imagem': imgName,
        'lingua': lingua,
        'erros': currentErros,
        'oculto': importedOculto,
      });
    }
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

    String query = '''
      SELECT 
        ingles, 
        COALESCE(GROUP_CONCAT(CASE WHEN oculto = 0 OR oculto IS NULL THEN traducao END, '|'), '') as traducoes,
        COALESCE(GROUP_CONCAT(CASE WHEN oculto = 1 THEN traducao END, '|'), '') as traducoes_ocultas,
        MAX(CASE WHEN oculto = 0 OR oculto IS NULL THEN imagem ELSE '' END) as imagem, 
        MAX(erros) as erros 
      FROM palavras 
      WHERE lingua = ? 
      GROUP BY ingles COLLATE NOCASE 
      HAVING traducoes != ''
      ORDER BY $orderBy
    ''';
    if (limit > 0) query += ' LIMIT $limit';
    return await db.rawQuery(query, [linguaAtual]);
  }

  Future<List<Map<String, dynamic>>> fetchDistinctWords(String linguaAtual, [String query = '']) async {
    final db = await instance.database;
    if (query.isEmpty) {
      return await db.rawQuery(
        '''SELECT ingles, MAX(CASE WHEN oculto = 0 OR oculto IS NULL THEN imagem ELSE '' END) as imagem, GROUP_CONCAT(CASE WHEN oculto = 0 OR oculto IS NULL THEN traducao END, ', ') as traducao, MAX(erros) as erros FROM palavras WHERE lingua = ? GROUP BY ingles COLLATE NOCASE HAVING traducao IS NOT NULL AND traducao != '' ORDER BY ingles COLLATE NOCASE ASC''',
        [linguaAtual],
      );
    } else {
      return await db.rawQuery(
        '''SELECT ingles, MAX(CASE WHEN oculto = 0 OR oculto IS NULL THEN imagem ELSE '' END) as imagem, GROUP_CONCAT(CASE WHEN oculto = 0 OR oculto IS NULL THEN traducao END, ', ') as traducao, MAX(erros) as erros FROM palavras WHERE lingua = ? AND (ingles LIKE ? OR (traducao LIKE ? AND (oculto = 0 OR oculto IS NULL))) GROUP BY ingles COLLATE NOCASE HAVING traducao IS NOT NULL AND traducao != '' ORDER BY ingles COLLATE NOCASE ASC''',
        [linguaAtual, '%$query%', '%$query%'],
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchMeanings(String ingles, String linguaAtual) async {
    final db = await instance.database;
    return await db.query(
      'palavras',
      where: 'ingles = ? COLLATE NOCASE AND lingua = ?',
      whereArgs: [ingles, linguaAtual],
      orderBy: 'oculto ASC, id ASC',
    );
  }

  Future<void> deleteAllMeanings(String ingles, String linguaAtual) async {
    final db = await instance.database;
    await db.delete('palavras', where: 'ingles = ? COLLATE NOCASE AND lingua = ?', whereArgs: [ingles, linguaAtual]);
  }

  // ==========================================
  // BACKUP COMPLETO E COMPARTILHAMENTO DE DECKS
  // ==========================================
  Future<void> exportarBackup() async {
    try {
      await initMediaDirectory();
      final db = await database;
      try {
        await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      } catch (_) {}

      final dbPath = path.join(await getDatabasesPath(), 'dicionario.db');
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) return;

      final archive = Archive();

      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('dicionario.db', dbBytes.length, dbBytes));

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

      final zipBytes = ZipEncoder().encode(archive);
      final tempDir = await getTemporaryDirectory();
      final zipPath = path.join(tempDir.path, 'backup_memory_word.zip');
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipBytes, flush: true);

      await Share.shareXFiles([XFile(zipPath)], text: 'Backup Completo MemoryWord');
    } catch (_) {}
  }

  Future<bool> exportarTemaAtual(String linguaAtual) async {
    try {
      await initMediaDirectory();
      final db = await database;
      final rows = await db.query('palavras', where: 'lingua = ?', whereArgs: [linguaAtual]);
      if (rows.isEmpty) return false;

      final archive = Archive();
      final deckPayload = {
        'tipo': 'memory_word_deck',
        'lingua': linguaAtual,
        'palavras': rows,
      };
      final jsonBytes = utf8.encode(jsonEncode(deckPayload));
      archive.addFile(ArchiveFile('deck.json', jsonBytes.length, jsonBytes));

      final mediaDir = await mediaDirectoryPath;
      final Set<String> addedImages = {};
      for (var r in rows) {
        final String imgName = path.basename((r['imagem']?.toString() ?? '').trim());
        if (imgName.isNotEmpty && !addedImages.contains(imgName)) {
          final imgFile = File(path.join(mediaDir, imgName));
          if (await imgFile.exists()) {
            final imgBytes = await imgFile.readAsBytes();
            archive.addFile(ArchiveFile('media/$imgName', imgBytes.length, imgBytes));
            addedImages.add(imgName);
          }
        }
      }

      final zipBytes = ZipEncoder().encode(archive);
      final tempDir = await getTemporaryDirectory();
      final cleanTopic = getStudyDisplayName(linguaAtual)
          .replaceAll(RegExp(r'[^\p{L}\p{N}_\-]', unicode: true), '_')
          .toLowerCase();
      final zipPath = path.join(tempDir.path, 'deck_$cleanTopic.zip');
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipBytes, flush: true);

      await Share.shareXFiles([XFile(zipPath)], text: 'Deck MemoryWord: ${getStudyDisplayName(linguaAtual)}');
      return true;
    } catch (_) {
      return false;
    }
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

  Future<String> importarBackup({Future<bool?> Function()? escolherModoMesclar}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        return 'cancelado';
      }

      final selectedFile = File(result.files.single.path!);
      if (await selectedFile.length() < 120) {
        return 'erro';
      }

      final bytes = await selectedFile.readAsBytes();
      final dbPath = path.join(await getDatabasesPath(), 'dicionario.db');
      final tempDir = await getTemporaryDirectory();
      final mediaDir = await mediaDirectoryPath;

      final bool isZipPackage = bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;

      if (isZipPackage) {
        final archive = ZipDecoder().decodeBytes(bytes);

        ArchiveFile? dbEntry;
        ArchiveFile? deckJsonEntry;
        for (final file in archive) {
          if (file.isFile && path.basename(file.name) == 'dicionario.db') {
            dbEntry = file;
          } else if (file.isFile && path.basename(file.name) == 'deck.json') {
            deckJsonEntry = file;
          }
        }

        if (deckJsonEntry != null && dbEntry == null) {
          final String jsonStr = utf8.decode(List<int>.from(deckJsonEntry.content as Iterable<int>));
          final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final List<dynamic> palavrasList = (data['palavras'] as List<dynamic>?) ?? [];

          for (final file in archive) {
            if (file.isFile && file.name != deckJsonEntry.name) {
              final imgFileName = path.basename(file.name);
              if (imgFileName.isNotEmpty) {
                final outFile = File(path.join(mediaDir, imgFileName));
                if (!await outFile.exists()) {
                  final List<int> imgBytes = List<int>.from(file.content as Iterable<int>);
                  await outFile.writeAsBytes(imgBytes, flush: true);
                }
              }
            }
          }

          final db = await database;
          final Set<String> novosTemas = (await getTemasLivres()).toSet();

          for (var item in palavrasList) {
            if (item is Map) {
              final mapItem = Map<String, dynamic>.from(item);
              await _insertWordIfNotExists(db, mapItem);
              final String ling = mapItem['lingua']?.toString() ?? '';
              if (ling.startsWith('tema:') && ling.length > 5) {
                novosTemas.add(ling.substring(5));
              }
            }
          }

          await salvarTemasLivres(novosTemas.toList());
          if (data['lingua'] != null && data['lingua'].toString().isNotEmpty) {
            await updateConfig('idioma_atual', data['lingua'].toString());
          }
          await limparImagensOrfas();
          return 'deck_mesclado';
        }

        if (dbEntry == null) return 'erro';

        bool mesclar = false;
        if (escolherModoMesclar != null) {
          final bool? escolha = await escolherModoMesclar();
          if (escolha == null) return 'cancelado';
          mesclar = escolha;
        }

        final tempDbPath = path.join(tempDir.path, 'temp_validacao.db');
        final tempDbFile = File(tempDbPath);
        await _limparArquivosWalAuxiliares(tempDbPath);
        final List<int> dbBytes = List<int>.from(dbEntry.content as Iterable<int>);
        await tempDbFile.writeAsBytes(dbBytes, flush: true);

        List<Map<String, dynamic>> importedWords = [];
        try {
          final testDb = await openDatabase(tempDbPath);
          importedWords = await testDb.query('palavras');
          await testDb.close();
        } catch (_) {
          if (await tempDbFile.exists()) await tempDbFile.delete();
          await _limparArquivosWalAuxiliares(tempDbPath);
          return 'erro';
        }

        for (final file in archive) {
          if (file.isFile && file.name != dbEntry.name) {
            final imgFileName = path.basename(file.name);
            if (imgFileName.isNotEmpty) {
              final outFile = File(path.join(mediaDir, imgFileName));
              if (!mesclar || !await outFile.exists()) {
                final List<int> imgBytes = List<int>.from(file.content as Iterable<int>);
                await outFile.writeAsBytes(imgBytes, flush: true);
              }
            }
          }
        }

        if (mesclar) {
          if (await tempDbFile.exists()) await tempDbFile.delete();
          await _limparArquivosWalAuxiliares(tempDbPath);

          final db = await database;
          final Set<String> temasAtuais = (await getTemasLivres()).toSet();
          for (var w in importedWords) {
            await _insertWordIfNotExists(db, w);
            final String ling = w['lingua']?.toString() ?? '';
            if (ling.startsWith('tema:') && ling.length > 5) {
              temasAtuais.add(ling.substring(5));
            }
          }
          await salvarTemasLivres(temasAtuais.toList());
          await limparImagensOrfas();
          return 'deck_mesclado';
        } else {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
          await _limparArquivosWalAuxiliares(dbPath);
          await tempDbFile.copy(dbPath);
          if (await tempDbFile.exists()) await tempDbFile.delete();
          await _limparArquivosWalAuxiliares(tempDbPath);
        }
      } else {
        bool mesclar = false;
        if (escolherModoMesclar != null) {
          final bool? escolha = await escolherModoMesclar();
          if (escolha == null) return 'cancelado';
          mesclar = escolha;
        }

        final tempDbPath = path.join(tempDir.path, 'temp_validacao_legacy.db');
        final tempDbFile = File(tempDbPath);
        await _limparArquivosWalAuxiliares(tempDbPath);
        await selectedFile.copy(tempDbPath);

        List<Map<String, dynamic>> importedWords = [];
        try {
          final testDb = await openDatabase(tempDbPath);
          importedWords = await testDb.query('palavras');
          await testDb.close();
        } catch (_) {
          if (await tempDbFile.exists()) await tempDbFile.delete();
          await _limparArquivosWalAuxiliares(tempDbPath);
          return 'erro';
        }

        if (mesclar) {
          if (await tempDbFile.exists()) await tempDbFile.delete();
          await _limparArquivosWalAuxiliares(tempDbPath);

          final db = await database;
          final Set<String> temasAtuais = (await getTemasLivres()).toSet();
          for (var w in importedWords) {
            await _insertWordIfNotExists(db, w);
            final String ling = w['lingua']?.toString() ?? '';
            if (ling.startsWith('tema:') && ling.length > 5) {
              temasAtuais.add(ling.substring(5));
            }
          }
          await salvarTemasLivres(temasAtuais.toList());
          await limparImagensOrfas();
          return 'deck_mesclado';
        } else {
          if (_database != null) {
            await _database!.close();
            _database = null;
          }
          await _limparArquivosWalAuxiliares(dbPath);
          await tempDbFile.copy(dbPath);
          if (await tempDbFile.exists()) await tempDbFile.delete();
          await _limparArquivosWalAuxiliares(tempDbPath);
        }
      }

      await database;
      await updateConfig('tutorial_inicial_concluido', 'true');
      await _migrarCaminhosDeImagensAntigas();
      await limparImagensOrfas();
      return 'restaurado';
    } catch (_) {
      return 'erro';
    }
  }
}