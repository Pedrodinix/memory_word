import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:translator/translator.dart' as tr;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:math';

// ==========================================
// CONFIGURAÇÕES GLOBAIS E TRADUÇÃO DO APP
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
final ValueNotifier<String> appLanguage = ValueNotifier('Inglês'); // Idioma a ESTUDAR
final ValueNotifier<String> appNativeLanguage = ValueNotifier('Português'); // Idioma NATIVO da interface
final ValueNotifier<bool> appFeedbackEnabled = ValueNotifier(true);

// --- MOTOR DE TRADUÇÃO GLOBAL ---
String t(String text) {
  String code = supportedLanguages[appNativeLanguage.value]?.transCode ?? 'pt';
  if (code == 'pt') return text; // Se for português, retorna o texto original

  const Map<String, Map<String, String>> dict = {
    // Idiomas
    'Inglês': {'en': 'English', 'de': 'Englisch', 'es': 'Inglés', 'fr': 'Anglais'},
    'Alemão': {'en': 'German', 'de': 'Deutsch', 'es': 'Alemán', 'fr': 'Allemand'},
    'Espanhol': {'en': 'Spanish', 'de': 'Spanisch', 'es': 'Español', 'fr': 'Espagnol'},
    'Português': {'en': 'Portuguese', 'de': 'Portugiesisch', 'es': 'Portugués', 'fr': 'Portugais'},
    'Francês': {'en': 'French', 'de': 'Französisch', 'es': 'Francés', 'fr': 'Français'},

    // Abas e Menus
    'Novo': {'en': 'New', 'de': 'Neu', 'es': 'Nuevo', 'fr': 'Nouveau'},
    'Praticar': {'en': 'Practice', 'de': 'Üben', 'es': 'Practicar', 'fr': 'Pratiquer'},
    'Biblioteca': {'en': 'Library', 'de': 'Bibliothek', 'es': 'Biblioteca', 'fr': 'Bibliothèque'},
    'Configurações': {'en': 'Settings', 'de': 'Einstellungen', 'es': 'Ajustes', 'fr': 'Paramètres'},

    // Tela Configurações
    'Idioma de Estudo Principal': {'en': 'Main Study Language', 'de': 'Hauptlernsprache', 'es': 'Idioma de Estudio', 'fr': "Langue d'étude principale"},
    'Seu Idioma (Origem)': {'en': 'Your Native Language', 'de': 'Deine Muttersprache', 'es': 'Tu Idioma Nativo', 'fr': 'Votre Langue Maternelle'},
    'Aprender': {'en': 'Learn', 'de': 'Lernen', 'es': 'Aprender', 'fr': 'Apprendre'},
    'Falar': {'en': 'Speak', 'de': 'Sprechen', 'es': 'Hablar', 'fr': 'Parler'},
    'Preferências': {'en': 'Preferences', 'de': 'Präferenzen', 'es': 'Preferencias', 'fr': 'Préférences'},
    'Modo Noturno': {'en': 'Dark Mode', 'de': 'Nachtmodus', 'es': 'Modo Oscuro', 'fr': 'Mode Sombre'},
    'Som e Vibração': {'en': 'Sound & Vibration', 'de': 'Ton & Vibration', 'es': 'Sonido y Vibración', 'fr': 'Son et Vibration'},
    'Filtro de Sorteio (Global)': {'en': 'Global Draw Filter', 'de': 'Globaler Ziehungsfilter', 'es': 'Filtro de Sorteo (Global)', 'fr': 'Filtre de Tirage'},
    'Todas as palavras': {'en': 'All words', 'de': 'Alle Wörter', 'es': 'Todas las palabras', 'fr': 'Tous les mots'},
    'Últimas 10': {'en': 'Last 10', 'de': 'Letzte 10', 'es': 'Últimas 10', 'fr': 'Les 10 derniers'},
    'Últimas 20': {'en': 'Last 20', 'de': 'Letzte 20', 'es': 'Últimas 20', 'fr': 'Les 20 derniers'},
    'Últimas 30': {'en': 'Last 30', 'de': 'Letzte 30', 'es': 'Últimas 30', 'fr': 'Les 30 derniers'},
    'Personalizado': {'en': 'Custom', 'de': 'Benutzerdef.', 'es': 'Personalizado', 'fr': 'Personnalisé'},
    'Salvar': {'en': 'Save', 'de': 'Speichern', 'es': 'Guardar', 'fr': 'Enregistrer'},
    'Configurações salvas!': {'en': 'Settings saved!', 'de': 'Gespeichert!', 'es': '¡Ajustes guardados!', 'fr': 'Paramètres enregistrés !'},

    // Registro
    'Registar Palavra': {'en': 'Register Word', 'de': 'Wort registrieren', 'es': 'Registrar Palabra', 'fr': 'Enregistrer le mot'},
    'Palavra em': {'en': 'Word in', 'de': 'Wort auf', 'es': 'Palabra en', 'fr': 'Mot en'},
    'Significado / Tradução': {'en': 'Meaning / Translation', 'de': 'Bedeutung / Übersetzung', 'es': 'Significado / Traducción', 'fr': 'Signification / Traduction'},
    'Câmera': {'en': 'Camera', 'de': 'Kamera', 'es': 'Cámara', 'fr': 'Caméra'},
    'Galeria': {'en': 'Gallery', 'de': 'Galerie', 'es': 'Galería', 'fr': 'Galerie'},
    'Confirmar': {'en': 'Confirm', 'de': 'Bestätigen', 'es': 'Confirmar', 'fr': 'Confirmer'},
    'Remover Foto': {'en': 'Remove Photo', 'de': 'Foto entfernen', 'es': 'Eliminar Foto', 'fr': 'Supprimer la photo'},
    'Preencha a palavra e a tradução antes de salvar.': {'en': 'Fill word and translation before saving.', 'de': 'Bitte Wort und Übersetzung eingeben.', 'es': 'Rellene palabra y traducción antes de guardar.', 'fr': 'Remplissez le mot et la traduction avant d\'enregistrer.'},
    'Palavra salva com sucesso!': {'en': 'Word saved successfully!', 'de': 'Wort erfolgreich gespeichert!', 'es': '¡Palabra guardada con éxito!', 'fr': 'Mot enregistré avec succès !'},

    // Prática (Clássico & Comum)
    'Modo Clássico': {'en': 'Classic Mode', 'de': 'Klassischer Modus', 'es': 'Modo Clásico', 'fr': 'Mode Classique'},
    'Sortear Palavra': {'en': 'Draw Word', 'de': 'Wort ziehen', 'es': 'Sortear Palabra', 'fr': 'Tirer un mot'},
    'Clique acima para sortear': {'en': 'Click above to draw', 'de': 'Klicken um zu ziehen', 'es': 'Haz clic arriba para sortear', 'fr': 'Cliquez ci-dessus pour tirer'},
    'Sua Tradução': {'en': 'Your Translation', 'de': 'Deine Übersetzung', 'es': 'Tu Traducción', 'fr': 'Votre Traduction'},
    'Responder em': {'en': 'Answer in', 'de': 'Antworten auf', 'es': 'Responder en', 'fr': 'Répondre en'},
    'Confirmar Resposta': {'en': 'Confirm Answer', 'de': 'Antwort bestätigen', 'es': 'Confirmar Respuesta', 'fr': 'Confirmer la réponse'},
    'Resposta Correta! 🎉': {'en': 'Correct Answer! 🎉', 'de': 'Richtige Antwort! 🎉', 'es': '¡Respuesta Correcta! 🎉', 'fr': 'Bonne Réponse ! 🎉'},
    'Incorreta. O correto é:': {'en': 'Incorrect. Correct is:', 'de': 'Falsch. Richtig ist:', 'es': 'Incorrecta. Lo correcto es:', 'fr': 'Incorrect. La bonne réponse est :'},
    'ou': {'en': 'or', 'de': 'oder', 'es': 'o', 'fr': 'ou'},
    'Desempenho': {'en': 'Performance', 'de': 'Leistung', 'es': 'Rendimiento', 'fr': 'Performance'},

    // Papagaio
    'Modo Papagaio': {'en': 'Parrot Mode', 'de': 'Papageienmodus', 'es': 'Modo Loro', 'fr': 'Mode Perroquet'},
    'Filtro de Palavras': {'en': 'Words Filter', 'de': 'Wortfilter', 'es': 'Filtro de Palabras', 'fr': 'Filtre de Mots'},
    'Velocidade da Voz': {'en': 'Voice Speed', 'de': 'Sprachgeschwindigkeit', 'es': 'Velocidad de Voz', 'fr': 'Vitesse de la voix'},
    'Modo de Repetição': {'en': 'Repeat Mode', 'de': 'Wiederholungsmodus', 'es': 'Modo de Repetición', 'fr': 'Mode de Répétition'},
    'Em Loop (Sorteio Infinito)': {'en': 'In Loop (Infinite Draw)', 'de': 'In Schleife', 'es': 'En Bucle (Sorteo Infinito)', 'fr': 'En Boucle'},
    '1 Sequência (Parar no fim)': {'en': '1 Sequence (Stop at end)', 'de': '1 Sequenz', 'es': '1 Secuencia', 'fr': '1 Séquence'},
    'Iniciar Papagaio': {'en': 'Start Parrot', 'de': 'Papagei starten', 'es': 'Iniciar Loro', 'fr': 'Démarrer le Perroquet'},
    'Parar Papagaio': {'en': 'Stop Parrot', 'de': 'Papagei stoppen', 'es': 'Detener Loro', 'fr': 'Arrêter le Perroquet'},
    'Pronto para voar!': {'en': 'Ready to fly!', 'de': 'Bereit zum Fliegen!', 'es': '¡Listo para volar!', 'fr': 'Prêt à voler !'},
    'Sua biblioteca está vazia!': {'en': 'Your library is empty!', 'de': 'Deine Bibliothek ist leer!', 'es': '¡Tu biblioteca está vacía!', 'fr': 'Votre bibliothèque est vide !'},
    'Sequência Concluída!': {'en': 'Sequence Completed!', 'de': 'Sequenz abgeschlossen!', 'es': '¡Secuencia Completada!', 'fr': 'Séquence Terminée !'},

    // Língua Afiada
    'Língua Afiada': {'en': 'Sharp Tongue', 'de': 'Scharfe Zunge', 'es': 'Lengua Afilada', 'fr': 'Langue Pendue'},
    'Sortear Nova Palavra': {'en': 'Draw New Word', 'de': 'Neues Wort ziehen', 'es': 'Sortear Nueva Palabra', 'fr': 'Tirer un nouveau mot'},
    'Sorteie para começar': {'en': 'Draw to start', 'de': 'Ziehen um zu starten', 'es': 'Sortea para empezar', 'fr': 'Tirez pour commencer'},
    'Toque para falar': {'en': 'Tap to speak', 'de': 'Tippen zum Sprechen', 'es': 'Toca para hablar', 'fr': 'Appuyez pour parler'},
    'A escutar... Fale agora!': {'en': 'Listening... Speak now!', 'de': 'Höre zu... Sprich jetzt!', 'es': 'Escuchando... ¡Habla ahora!', 'fr': 'Écoute... Parlez maintenant !'},
    'Pronúncia Perfeita! 🎉': {'en': 'Perfect Pronunciation! 🎉', 'de': 'Perfekte Aussprache! 🎉', 'es': '¡Pronunciación Perfecta! 🎉', 'fr': 'Prononciation Parfaite ! 🎉'},
    'Entendemos:': {'en': 'We heard:', 'de': 'Wir haben verstanden:', 'es': 'Entendimos:', 'fr': 'Nous avons compris :'},

    // Desempenho
    'Seu Desempenho': {'en': 'Your Performance', 'de': 'Deine Leistung', 'es': 'Tu Rendimiento', 'fr': 'Votre Performance'},
    'Desempenho de Hoje': {'en': 'Performance Today', 'de': 'Leistung Heute', 'es': 'Rendimiento de Hoy', 'fr': "Performances d'aujourd'hui"},
    'Últimos 7 Dias': {'en': 'Last 7 Days', 'de': 'Letzte 7 Tage', 'es': 'Últimos 7 Días', 'fr': 'Les 7 Derniers Jours'},
    'Histórico Mensal': {'en': 'Monthly History', 'de': 'Monatlicher Verlauf', 'es': 'Historial Mensual', 'fr': 'Historique Mensuel'},
    'Perguntas Respondidas:': {'en': 'Questions Answered:', 'de': 'Beantwortete Fragen:', 'es': 'Preguntas Respondidas:', 'fr': 'Questions répondues :'},
    'Acertos / Erros:': {'en': 'Hits / Misses:', 'de': 'Treffer / Fehler:', 'es': 'Aciertos / Errores:', 'fr': 'Réussites / Échecs :'},
    'Combos Especiais 🎉:': {'en': 'Special Combos 🎉:', 'de': 'Spezielle Kombos 🎉:', 'es': 'Combos Especiales 🎉:', 'fr': 'Combos Spéciaux 🎉:'},
    'Tempo no Papagaio 🦜:': {'en': 'Parrot Time 🦜:', 'de': 'Papageienzeit 🦜:', 'es': 'Tiempo en Loro 🦜:', 'fr': 'Temps Perroquet 🦜:'},

    // Biblioteca
    'Sua Biblioteca em': {'en': 'Your Library in', 'de': 'Deine Bibliothek in', 'es': 'Tu Biblioteca en', 'fr': 'Votre Bibliothèque en'},
    'registradas': {'en': 'registered', 'de': 'registriert', 'es': 'registradas', 'fr': 'enregistrées'},
    'Pesquisar...': {'en': 'Search...', 'de': 'Suchen...', 'es': 'Buscar...', 'fr': 'Rechercher...'},
    'Nenhuma palavra encontrada.': {'en': 'No words found.', 'de': 'Keine Wörter gefunden.', 'es': 'No se encontraron palabras.', 'fr': 'Aucun mot trouvé.'},
    'Editar Palavra': {'en': 'Edit Word', 'de': 'Wort bearbeiten', 'es': 'Editar Palabra', 'fr': 'Modifier le mot'},
    'Salvar Alterações': {'en': 'Save Changes', 'de': 'Änderungen speichern', 'es': 'Guardar Cambios', 'fr': 'Enregistrer les modifications'},
    'Significado': {'en': 'Meaning', 'de': 'Bedeutung', 'es': 'Significado', 'fr': 'Signification'},
    'Palavra Principal': {'en': 'Main Word', 'de': 'Hauptwort', 'es': 'Palabra Principal', 'fr': 'Mot Principal'},
    'Significados Registados:': {'en': 'Registered Meanings:', 'de': 'Registrierte Bedeutungen:', 'es': 'Significados Registrados:', 'fr': 'Significations Enregistrées :'},
    'Alterar Foto': {'en': 'Change Photo', 'de': 'Foto ändern', 'es': 'Cambiar Foto', 'fr': 'Changer la photo'},
    'Adicionar Foto': {'en': 'Add Photo', 'de': 'Foto hinzufügen', 'es': 'Añadir Foto', 'fr': 'Ajouter une photo'},
    'Remover Imagem': {'en': 'Remove Image', 'de': 'Bild entfernen', 'es': 'Eliminar Imagen', 'fr': 'Supprimer l\'image'},
    'Excluir Palavra': {'en': 'Delete Word', 'de': 'Wort löschen', 'es': 'Eliminar Palabra', 'fr': 'Supprimer le mot'},
    'Cancelar': {'en': 'Cancel', 'de': 'Abbrechen', 'es': 'Cancelar', 'fr': 'Annuler'},
    'Sim': {'en': 'Yes', 'de': 'Ja', 'es': 'Sí', 'fr': 'Oui'},
    'Excluir': {'en': 'Delete', 'de': 'Löschen', 'es': 'Eliminar', 'fr': 'Supprimer'},
  };
  return dict[text]?[code] ?? text;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseHelper.instance;
  await db.limparDadosAntigos();

  String temaSalvo = await db.getConfig('tema');
  String idiomaSalvo = await db.getConfig('idioma_atual');
  String idiomaNativoSalvo = await db.getConfig('idioma_nativo'); // Novo
  String feedbackSalvo = await db.getConfig('feedback_ativo');

  appThemeMode.value = (temaSalvo == 'dark') ? ThemeMode.dark : ThemeMode.light;
  if (idiomaSalvo.isNotEmpty && supportedLanguages.containsKey(idiomaSalvo)) {
    appLanguage.value = idiomaSalvo;
  }
  if (idiomaNativoSalvo.isNotEmpty && supportedLanguages.containsKey(idiomaNativoSalvo)) {
    appNativeLanguage.value = idiomaNativoSalvo; // Novo
  }
  if (feedbackSalvo.isNotEmpty) {
    appFeedbackEnabled.value = (feedbackSalvo == 'true');
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
    if (_database != null) return _database!;
    _database = await _initDB('dicionario.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, filePath);

    return await openDatabase(
      fullPath,
      version: 7,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE palavras (id INTEGER PRIMARY KEY AUTOINCREMENT, ingles TEXT NOT NULL, traducao TEXT NOT NULL, imagem TEXT, lingua TEXT NOT NULL DEFAULT 'Inglês')''');
        await db.execute('''CREATE TABLE configuracoes (chave TEXT PRIMARY KEY, valor TEXT)''');
        await db.execute('''CREATE TABLE estatisticas (data TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0)''');
        await db.execute('''CREATE TABLE estatisticas_mensais (mes TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0)''');

        await db.insert('configuracoes', {'chave': 'filtro', 'valor': 'todas'});
        await db.insert('configuracoes', {'chave': 'tema', 'valor': 'light'});
        await db.insert('configuracoes', {'chave': 'idioma_atual', 'valor': 'Inglês'});
        await db.insert('configuracoes', {'chave': 'idioma_nativo', 'valor': 'Português'}); // Inserido padrão nativo
        await db.insert('configuracoes', {'chave': 'feedback_ativo', 'valor': 'true'});
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) try { await db.execute("ALTER TABLE palavras ADD COLUMN lingua TEXT DEFAULT 'Inglês'"); } catch (_) {}
        if (oldVersion < 6) {
          await db.execute('''CREATE TABLE IF NOT EXISTS estatisticas (data TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0)''');
          await db.execute('''CREATE TABLE IF NOT EXISTS estatisticas_mensais (mes TEXT PRIMARY KEY, respondidas INTEGER DEFAULT 0, acertos INTEGER DEFAULT 0, erros INTEGER DEFAULT 0, especiais INTEGER DEFAULT 0, tempo_papagaio INTEGER DEFAULT 0)''');
        }
      },
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
    String query = '''SELECT ingles, GROUP_CONCAT(traducao, '|') as traducoes, MAX(imagem) as imagem FROM palavras WHERE lingua = ? GROUP BY ingles COLLATE NOCASE ORDER BY MAX(id) DESC''';
    if (limit > 0) query += ' LIMIT $limit';
    return await db.rawQuery(query, [linguaAtual]);
  }

  Future<List<Map<String, dynamic>>> fetchDistinctWords(String linguaAtual, [String query = '']) async {
    final db = await instance.database;
    if (query.isEmpty) { return await db.rawQuery('''SELECT ingles, MAX(imagem) as imagem, GROUP_CONCAT(traducao, ', ') as traducao FROM palavras WHERE lingua = ? GROUP BY ingles COLLATE NOCASE ORDER BY ingles COLLATE NOCASE ASC''', [linguaAtual]);
    } else { return await db.rawQuery('''SELECT ingles, MAX(imagem) as imagem, GROUP_CONCAT(traducao, ', ') as traducao FROM palavras WHERE lingua = ? AND (ingles LIKE ? OR traducao LIKE ?) GROUP BY ingles COLLATE NOCASE ORDER BY ingles COLLATE NOCASE ASC''', [linguaAtual, '%$query%', '%$query%']); }
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
        // Envolvemos toda a app para reconstruir a UI quando o idioma Nativo muda
        return ValueListenableBuilder<String>(
          valueListenable: appNativeLanguage,
          builder: (context, currentNativeLang, child) {
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
          builder: (context, lang, child) { return Center(child: Text(supportedLanguages[lang]?.flag ?? '🌐', style: const TextStyle(fontSize: 26))); },
        ),
        title: const Text('MemoryWord'), centerTitle: true,
        actions: [ IconButton(icon: const Icon(Icons.settings), tooltip: t("Configurações"), onPressed: _abrirConfiguracoes) ],
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
        onTap: (index) { _mainPageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.add), label: t('Novo')),
          BottomNavigationBarItem(icon: const Icon(Icons.quiz), label: t('Praticar')),
          BottomNavigationBarItem(icon: const Icon(Icons.library_books), label: t('Biblioteca')),
        ],
      ),
    );
  }
}

// ==========================================
// ABA 2: PRÁTICA
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

  final AudioPlayer _audioCorrect = AudioPlayer();
  final AudioPlayer _audioSpecial = AudioPlayer();
  final AudioPlayer _audioWrong = AudioPlayer();

  final Stopwatch _parrotStopwatch = Stopwatch();

  int _streak = 0;
  int _nextMilestone = 10;
  bool _showSpecialOverlay = false;
  int _overlayPoints = 0;

  Map<String, dynamic>? _currentWordNormal;
  final _answerCtrl = TextEditingController();
  String _resultTextNormal = '';
  Color _resultColorNormal = Colors.black;
  bool _hasAnsweredNormal = false;

  bool _isReversedNormal = false;
  List<Map<String, dynamic>> _allFetchedWordsNormal = [];
  String _questionToDisplay = '';
  List<String> _validAnswersNormal = [];

  String _parrotFilter = 'todas';
  String _parrotCustomVal = '';
  String _parrotMode = 'loop';
  double _parrotSpeed = 1.0;
  final TextEditingController _parrotCustomCtrl = TextEditingController();
  bool _isParrotPlaying = false;
  String _parrotCurrentWordDisplay = '';

  Map<String, dynamic>? _currentWordSharp;
  String _sharpFilter = 'todas';
  String _sharpCustomVal = '';
  final TextEditingController _sharpCustomCtrl = TextEditingController();
  bool _isListening = false;
  String _spokenText = '';
  String _sharpResultText = '';
  Color _sharpResultColor = Colors.black;
  bool _hasAnsweredSharp = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadSettings();
    _parrotCustomCtrl.addListener(() { _parrotCustomVal = _parrotCustomCtrl.text.trim(); _saveSettings(); });
    _sharpCustomCtrl.addListener(() { _sharpCustomVal = _sharpCustomCtrl.text.trim(); _saveSettings(); });

    _audioCorrect.setSource(AssetSource('correct.mp3'));
    _audioSpecial.setSource(AssetSource('special.mp3'));
    _audioWrong.setSource(AssetSource('wrong.mp3'));
  }

  @override
  void didUpdateWidget(PracticeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLang != widget.currentLang) {
      if (_isParrotPlaying) _stopParrot();
      _currentWordNormal = null; _answerCtrl.clear(); _resultTextNormal = ''; _hasAnsweredNormal = false;
      _currentWordSharp = null; _sharpResultText = ''; _spokenText = ''; _hasAnsweredSharp = false;
      _streak = 0; _nextMilestone = 10;
    }
  }

  @override
  void dispose() {
    _stopParrot();
    _flutterTts.stop();
    _audioCorrect.dispose();
    _audioSpecial.dispose();
    _audioWrong.dispose();
    _pageController.dispose();
    _parrotCustomCtrl.dispose();
    _sharpCustomCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  void _playCorrectSound() async { if (!appFeedbackEnabled.value) return; try { await _audioCorrect.stop(); await _audioCorrect.play(AssetSource('correct.mp3')); } catch (e) {} }
  void _playSpecialSound() async { if (!appFeedbackEnabled.value) return; try { await _audioSpecial.stop(); await _audioSpecial.play(AssetSource('special.mp3')); } catch (e) {} }
  void _playWrongSound() async { if (!appFeedbackEnabled.value) return; try { await _audioWrong.stop(); await _audioWrong.play(AssetSource('wrong.mp3')); } catch (e) {} }

  void _handleAnswer(bool isCorrect) {
    DatabaseHelper.instance.registrarAtividade('respondidas');
    if (isCorrect) {
      DatabaseHelper.instance.registrarAtividade('acertos');
      _streak++;
      if (_streak == _nextMilestone) {
        DatabaseHelper.instance.registrarAtividade('especiais');
        _triggerSpecialOverlay(_nextMilestone);
        _nextMilestone = _nextMilestone < 30 ? _nextMilestone + 10 : _nextMilestone * 2;
      } else { _playCorrectSound(); }
    } else {
      DatabaseHelper.instance.registrarAtividade('erros');
      _streak = 0; _nextMilestone = 10;
      _playWrongSound();
      if (appFeedbackEnabled.value) HapticFeedback.vibrate();
    }
  }

  void _triggerSpecialOverlay(int points) {
    _playSpecialSound();
    setState(() { _overlayPoints = points; _showSpecialOverlay = true; });
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _showSpecialOverlay = false); });
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

  Future<void> _drawWordNormal() async {
    final words = await DatabaseHelper.instance.fetchCustomWords(widget.currentLang, 'todas', '');
    if (words.isEmpty) { setState(() { _resultTextNormal = t('Sua biblioteca está vazia!'); _resultColorNormal = Colors.blue; }); return; }

    setState(() {
      _allFetchedWordsNormal = words;
      _currentWordNormal = words[Random().nextInt(words.length)];
      _answerCtrl.clear();
      _resultTextNormal = '';
      _hasAnsweredNormal = false;

      if (!_isReversedNormal) {
        _questionToDisplay = _currentWordNormal!['ingles'];
        _validAnswersNormal = _currentWordNormal!['traducoes'].toString().split('|').map((e) => e.trim().toLowerCase()).toList();
      } else {
        final meanings = _currentWordNormal!['traducoes'].toString().split('|').map((e) => e.trim()).toList();
        _questionToDisplay = meanings[Random().nextInt(meanings.length)];
        _validAnswersNormal = [];
        for (var w in _allFetchedWordsNormal) {
          final wMeanings = w['traducoes'].toString().split('|').map((e) => e.trim().toLowerCase()).toList();
          if (wMeanings.contains(_questionToDisplay.toLowerCase())) {
            _validAnswersNormal.add(w['ingles'].toString().toLowerCase());
          }
        }
      }
    });
  }

  void _verifyAnswerNormal() async {
    if (_currentWordNormal == null || _answerCtrl.text.isEmpty || _hasAnsweredNormal) return;

    setState(() { _hasAnsweredNormal = true; });
    final userAnswer = _answerCtrl.text.trim().toLowerCase();
    bool acertou = _validAnswersNormal.contains(userAnswer);

    setState(() {
      if (acertou) {
        _resultTextNormal = t('Resposta Correta! 🎉'); _resultColorNormal = Colors.green;
      } else {
        final displayCorrect = _validAnswersNormal.join(' ${t('ou')} ');
        _resultTextNormal = '${t('Incorreta. O correto é:')} $displayCorrect'; _resultColorNormal = Colors.red;
      }
    });

    _handleAnswer(acertou);
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted && _hasAnsweredNormal) { _drawWordNormal(); }
  }

  Future<void> _loadSettings() async {
    final db = DatabaseHelper.instance;
    setState(() {
      db.getConfig('papagaio_filtro').then((v) { if (v.isNotEmpty) _parrotFilter = v; });
      db.getConfig('papagaio_custom_val').then((v) { _parrotCustomVal = v; _parrotCustomCtrl.text = v; });
      db.getConfig('papagaio_modo').then((v) { if (v.isNotEmpty) _parrotMode = v; });
      db.getConfig('papagaio_vel').then((v) { if (v.isNotEmpty) _parrotSpeed = double.tryParse(v) ?? 1.0; });
      db.getConfig('afiada_filtro').then((v) { if (v.isNotEmpty) _sharpFilter = v; });
      db.getConfig('afiada_custom_val').then((v) { _sharpCustomVal = v; _sharpCustomCtrl.text = v; });
    });
  }

  void _saveSettings() {
    final db = DatabaseHelper.instance;
    db.updateConfig('papagaio_filtro', _parrotFilter);
    db.updateConfig('papagaio_custom_val', _parrotCustomVal);
    db.updateConfig('papagaio_modo', _parrotMode);
    db.updateConfig('papagaio_vel', _parrotSpeed.toString());
    db.updateConfig('afiada_filtro', _sharpFilter);
    db.updateConfig('afiada_custom_val', _sharpCustomVal);
  }

  void _stopParrot() {
    _isParrotPlaying = false;
    _flutterTts.stop();
    _parrotStopwatch.stop();
    int secs = _parrotStopwatch.elapsed.inSeconds;
    if (secs > 0) DatabaseHelper.instance.registrarAtividade('tempo_papagaio', secs);
    _parrotStopwatch.reset();
  }

  void _toggleParrot() async {
    if (_isParrotPlaying) {
      _stopParrot();
      if (mounted) setState(() {});
    } else {
      if (mounted) setState(() => _isParrotPlaying = true);
      _parrotStopwatch.start();
      _runParrotLoop();
    }
  }

  Future<void> _runParrotLoop() async {
    try {
      _flutterTts.awaitSpeakCompletion(true);
      if (Platform.isIOS) _flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [IosTextToSpeechAudioCategoryOptions.mixWithOthers, IosTextToSpeechAudioCategoryOptions.allowBluetooth]);

      while (_isParrotPlaying) {
        final rawWords = await DatabaseHelper.instance.fetchCustomWords(widget.currentLang, _parrotFilter, _parrotCustomVal);
        if (rawWords.isEmpty) {
          if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Sua biblioteca está vazia!')), backgroundColor: Colors.orange)); setState(() { _stopParrot(); _parrotCurrentWordDisplay = t('Sua biblioteca está vazia!'); }); }
          break;
        }

        final words = List<Map<String, dynamic>>.from(rawWords)..shuffle();

        for (var word in words) {
          if (!_isParrotPlaying) break;

          if (mounted) setState(() => _parrotCurrentWordDisplay = word['ingles']);
          AppLanguage studyLang = supportedLanguages[widget.currentLang]!;
          await _flutterTts.setLanguage(studyLang.ttsCode); await _flutterTts.setSpeechRate(0.5 * _parrotSpeed); await _flutterTts.speak(word['ingles']);

          if (!_isParrotPlaying) break; await Future.delayed(Duration(milliseconds: (1200 / _parrotSpeed).round()));
          if (!_isParrotPlaying) break;

          String trad = word['traducoes'].toString().replaceAll('|', ' ${t('ou')} ');
          if (mounted) setState(() => _parrotCurrentWordDisplay = trad);
          // Usa DIRETAMENTE o idioma nativo global (Sem a barrinha individual)
          AppLanguage nativeLang = supportedLanguages[appNativeLanguage.value] ?? supportedLanguages['Português']!;
          await _flutterTts.setLanguage(nativeLang.ttsCode); await _flutterTts.setSpeechRate(0.5 * _parrotSpeed); await _flutterTts.speak(trad);

          if (!_isParrotPlaying) break; await Future.delayed(Duration(milliseconds: (2000 / _parrotSpeed).round()));
        }
        if (_parrotMode == 'single' && _isParrotPlaying) {
          if (mounted) setState(() { _stopParrot(); _parrotCurrentWordDisplay = t('Sequência Concluída!'); });
          break;
        }
      }
    } catch (e) {
      if (mounted) { setState(() => _stopParrot()); }
    }
  }

  Future<void> _drawWordSharp() async {
    final words = await DatabaseHelper.instance.fetchCustomWords(widget.currentLang, _sharpFilter, _sharpCustomVal);
    if (words.isEmpty) { setState(() { _sharpResultText = t('Nenhuma palavra encontrada.'); _sharpResultColor = Colors.blue; }); return; }
    setState(() {
      _currentWordSharp = words[Random().nextInt(words.length)];
      _sharpResultText = ''; _spokenText = ''; _hasAnsweredSharp = false;
    });
    _falar(_currentWordSharp!['ingles']);
  }

  void _listenSharp() async {
    if (_hasAnsweredSharp) return;

    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) { if (val == 'notListening' || val == 'done') setState(() => _isListening = false); },
        onError: (val) { setState(() => _isListening = false); },
      );
      if (available) {
        setState(() => _isListening = true);
        AppLanguage langData = supportedLanguages[widget.currentLang]!;
        _speech.listen(
          onResult: (val) {
            setState(() {
              _spokenText = val.recognizedWords;
              if (val.hasConfidenceRating && val.confidence > 0) _verifySpeech();
            });
          }, localeId: langData.ttsCode,
        );
      } else {
        setState(() => _isListening = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Reconhecimento indisponível no telemóvel.'))));
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _verifySpeech();
    }
  }

  void _verifySpeech() async {
    if (_currentWordSharp == null || _spokenText.isEmpty || _hasAnsweredSharp) return;

    setState(() { _hasAnsweredSharp = true; });
    String target = _currentWordSharp!['ingles'].toString().toLowerCase().replaceAll(RegExp(r'[^\w\s]+'), '');
    String spoken = _spokenText.toLowerCase().replaceAll(RegExp(r'[^\w\s]+'), '');

    bool acertou = (spoken == target || spoken.contains(target) || target.contains(spoken));
    setState(() {
      if (acertou) {
        _sharpResultText = t('Pronúncia Perfeita! 🎉'); _sharpResultColor = Colors.green;
      } else {
        _sharpResultText = '${t('Entendemos:')} "$spoken"'; _sharpResultColor = Colors.red;
      }
    });

    _handleAnswer(acertou);
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted && _hasAnsweredSharp) { _drawWordSharp(); }
  }

  String _formatTime(int totalSeconds) {
    if (totalSeconds < 60) return "${totalSeconds}s";
    int m = totalSeconds ~/ 60;
    if (m < 60) return "${m}m ${totalSeconds % 60}s";
    int h = m ~/ 60;
    return "${h}h ${m % 60}m";
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          children: [
            _buildNormalPractice(),
            _buildParrotPractice(),
            _buildSharpPractice(),
            _buildDesempenhoPractice(),
          ],
        ),

        if (_showSpecialOverlay)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.2, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(t("Combos Especiais 🎉:").replaceAll(':', '!'), style: const TextStyle(fontSize: 32, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                            Text("+$_overlayPoints", style: const TextStyle(fontSize: 100, color: Colors.greenAccent, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 10)])),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          )
      ],
    );
  }

  Widget _buildNormalPractice() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(
                    children: [
                      Text(t("Modo Clássico"), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.sync_alt, color: Colors.blue, size: 20),
                        tooltip: t("Inverter Idioma"),
                        onPressed: () {
                          setState(() { _isReversedNormal = !_isReversedNormal; });
                          _drawWordNormal();
                        },
                      ),
                    ],
                  ),
                  Text("🔥 $_streak", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
                const SizedBox(height: 10),
                FilledButton.icon(icon: const Icon(Icons.shuffle), label: Text(t('Sortear Palavra')), onPressed: _drawWordNormal),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: Text(_questionToDisplay.isEmpty ? t('Clique acima para sortear') : _questionToDisplay, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    if (_currentWordNormal != null && !_isReversedNormal)
                      IconButton(icon: const Icon(Icons.volume_up, color: Colors.blue, size: 28), tooltip: t("Falar"), onPressed: () => _falar(_currentWordNormal!['ingles'])),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                    controller: _answerCtrl,
                    enabled: _currentWordNormal != null && !_hasAnsweredNormal,
                    decoration: InputDecoration(
                        labelText: _isReversedNormal ? "${t('Responder em')} ${t(widget.currentLang)}" : t('Sua Tradução'),
                        border: const OutlineInputBorder()
                    ),
                    onChanged: (v) => setState((){})
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                    onPressed: (_currentWordNormal == null || _answerCtrl.text.isEmpty || _hasAnsweredNormal) ? null : _verifyAnswerNormal,
                    child: Text(t('Confirmar Resposta'))
                ),
                const SizedBox(height: 10),
                Text(_resultTextNormal, style: TextStyle(fontSize: 18, color: _resultColorNormal, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                if (_resultTextNormal.isNotEmpty && _currentWordNormal?['imagem'] != null && _currentWordNormal!['imagem'] != '')
                  Expanded(child: Image.file(File(_currentWordNormal!['imagem']), fit: BoxFit.contain))
              ],
            ),
          ),
        ),
        _buildMinimalArrow(Icons.keyboard_arrow_up, t("Modo Papagaio"), () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)),
      ],
    );
  }

  Widget _buildParrotPractice() {
    return Column(
      children: [
        _buildMinimalArrow(Icons.keyboard_arrow_down, t("Modo Clássico"), () => _pageController.animateToPage(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [ const Text('🦜', style: TextStyle(fontSize: 30)), const SizedBox(width: 10), Text(t('Modo Papagaio'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)) ]),
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
                                    DropdownButtonFormField<String>(decoration: InputDecoration(labelText: t('Filtro de Palavras'), border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12)), value: _parrotFilter, items: [ DropdownMenuItem(value: 'todas', child: Text(t("Todas as palavras salvas"))), DropdownMenuItem(value: '10', child: Text(t("Últimas 10 palavras"))), DropdownMenuItem(value: '20', child: Text(t("Últimas 20 palavras"))), DropdownMenuItem(value: '30', child: Text(t("Últimas 30 palavras"))), DropdownMenuItem(value: 'custom', child: Text(t("Quantidade Personalizada..."))) ], onChanged: (v) { setState(() => _parrotFilter = v!); _saveSettings(); }),
                                    if (_parrotFilter == 'custom') Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: _parrotCustomCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('Nº Personalizado (> 0)'), border: const OutlineInputBorder(), isDense: true))),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<double>(decoration: InputDecoration(labelText: t('Velocidade da Voz'), border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12)), value: _parrotSpeed, items: [ DropdownMenuItem(value: 0.5, child: Text("${t('Lento (0.5x)')}")), DropdownMenuItem(value: 1.0, child: Text("${t('Normal (1x)')}")), DropdownMenuItem(value: 1.5, child: Text("${t('Rápido (1.5x)')}")), DropdownMenuItem(value: 2.0, child: Text("${t('Turbo (2x)')}")) ], onChanged: (v) { setState(() => _parrotSpeed = v!); _saveSettings(); }),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(decoration: InputDecoration(labelText: t('Modo de Repetição'), border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12)), value: _parrotMode, items: [ DropdownMenuItem(value: 'loop', child: Text("🔁 ${t('Em Loop (Sorteio Infinito)')}")), DropdownMenuItem(value: 'single', child: Text("➡️ ${t('1 Sequência (Parar no fim)')}")) ], onChanged: (v) { setState(() => _parrotMode = v!); _saveSettings(); }),
                                  ],
                                )
                            )
                        ),
                        const SizedBox(height: 25),
                        Text(_parrotCurrentWordDisplay.isEmpty ? t('Pronto para voar!') : _parrotCurrentWordDisplay, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                SizedBox(width: double.infinity, height: 55, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _isParrotPlaying ? Colors.red.shade700 : Colors.green.shade700), onPressed: _toggleParrot, icon: Icon(_isParrotPlaying ? Icons.stop : Icons.play_arrow, size: 26), label: Text(_isParrotPlaying ? t("Parar Papagaio") : t("Iniciar Papagaio"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
        ),
        _buildMinimalArrow(Icons.keyboard_arrow_up, t("Língua Afiada"), () => _pageController.animateToPage(2, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)),
      ],
    );
  }

  Widget _buildSharpPractice() {
    return Column(
      children: [
        _buildMinimalArrow(Icons.keyboard_arrow_down, t("Modo Papagaio"), () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text(""), Text("🔥 $_streak", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [ const Text('🗡️', style: TextStyle(fontSize: 30)), const SizedBox(width: 10), Text(t('Língua Afiada'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)) ]),
                  const Divider(height: 15),

                  DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: t('Filtro de Sorteio (Global)'), border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), isDense: true),
                      value: _sharpFilter,
                      items: [ DropdownMenuItem(value: 'todas', child: Text(t("Todas as palavras"))), DropdownMenuItem(value: '10', child: Text(t("Últimas 10"))), DropdownMenuItem(value: '20', child: Text(t("Últimas 20"))), DropdownMenuItem(value: '30', child: Text(t("Últimas 30"))), DropdownMenuItem(value: 'custom', child: Text(t("Personalizado"))) ],
                      onChanged: (v) { setState(() => _sharpFilter = v!); _saveSettings(); }
                  ),
                  if (_sharpFilter == 'custom')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(controller: _sharpCustomCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('Nº Personalizado (> 0)'), border: const OutlineInputBorder(), isDense: true)),
                    ),
                  const SizedBox(height: 20),

                  FilledButton.icon(icon: const Icon(Icons.shuffle), label: Text(t('Sortear Nova Palavra')), onPressed: _drawWordSharp),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text(_currentWordSharp?['ingles'] ?? t('Sorteie para começar'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      if (_currentWordSharp != null) IconButton(icon: const Icon(Icons.volume_up, color: Colors.blue, size: 35), tooltip: t("Falar"), onPressed: () => _falar(_currentWordSharp!['ingles'])),
                    ],
                  ),

                  if (_currentWordSharp != null) ...[
                    const SizedBox(height: 10),
                    Text(_currentWordSharp!['traducoes'].toString().replaceAll('|', ' ${t('ou')} '), style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  ],

                  const SizedBox(height: 30),
                  Text(_sharpResultText, style: TextStyle(fontSize: 18, color: _sharpResultColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: (_currentWordSharp == null || _hasAnsweredSharp) ? null : _listenSharp,
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: (_currentWordSharp == null || _hasAnsweredSharp) ? Colors.grey.shade300 : (_isListening ? Colors.red : Colors.blue),
                      child: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 35, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(_isListening ? t("A escutar... Fale agora!") : (_currentWordSharp == null ? "" : t("Toque para falar")), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        _buildMinimalArrow(Icons.keyboard_arrow_up, t("Desempenho"), () => _pageController.animateToPage(3, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)),
      ],
    );
  }

  Widget _buildDesempenhoPractice() {
    return Column(
      children: [
        _buildMinimalArrow(Icons.keyboard_arrow_down, t("Língua Afiada"), () => _pageController.animateToPage(2, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)),
        Expanded(
          child: FutureBuilder(
            future: Future.wait([ DatabaseHelper.instance.getEstatisticasHoje(), DatabaseHelper.instance.getEstatisticasSemana(), DatabaseHelper.instance.getHistoricoMensal() ]),
            builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) return Center(child: Text(t("Nenhuma atividade."), style: const TextStyle(color: Colors.grey)));

              final hoje = snapshot.data![0] as Map<String, dynamic>? ?? {};
              final semana = snapshot.data![1] as Map<String, dynamic>? ?? {};
              final meses = snapshot.data![2] as List<Map<String, dynamic>>? ?? [];

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [ const Text('📈', style: TextStyle(fontSize: 30)), const SizedBox(width: 10), Text(t('Seu Desempenho'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)) ]),
                    const Divider(height: 15),

                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t("Desempenho de Hoje"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                            const SizedBox(height: 10),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t("Perguntas Respondidas:")), Text("${hoje['respondidas'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t("Acertos / Erros:")), Text("${hoje['acertos'] ?? 0} / ${hoje['erros'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t("Combos Especiais 🎉:")), Text("${hoje['especiais'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t("Tempo no Papagaio 🦜:")), Text(_formatTime(hoje['tempo_papagaio'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold))]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t("Últimos 7 Dias"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)),
                            const SizedBox(height: 10),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t("Perguntas Respondidas:")), Text("${semana['respondidas'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t("Acertos / Erros:")), Text("${semana['acertos'] ?? 0} / ${semana['erros'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t("Combos Especiais 🎉:")), Text("${semana['especiais'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t("Tempo no Papagaio 🦜:")), Text(_formatTime(semana['tempo_papagaio'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold))]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    Align(alignment: Alignment.centerLeft, child: Text(" ${t('Histórico Mensal')}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 10),
                    meses.isEmpty
                        ? Text(t("Nenhum dado mensal."), style: const TextStyle(color: Colors.grey))
                        : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: meses.length,
                      itemBuilder: (context, index) {
                        final mes = meses[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.calendar_month, color: Colors.grey),
                            title: Text(mes['mes'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${t('Perguntas Respondidas:')} ${mes['respondidas'] ?? 0} | ${t('Acertos / Erros:')} ${mes['acertos'] ?? 0}\n${t('Combos Especiais 🎉:')} ${mes['especiais'] ?? 0} | ${t('Tempo no Papagaio 🦜:')} ${_formatTime(mes['tempo_papagaio'] ?? 0)}"),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
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
  bool _isFeedbackEnabled = true;
  String _filtro = 'todas';
  String _idiomaSelecionado = 'Inglês';
  String _idiomaNativoSelecionado = 'Português';
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
    final idiomaNativo = await db.getConfig('idioma_nativo');
    final feedback = await db.getConfig('feedback_ativo');

    setState(() {
      _isDark = tema == 'dark';
      _filtro = filtro.isEmpty ? 'todas' : filtro;
      _customCtrl.text = customVal;
      _idiomaSelecionado = idioma.isEmpty ? 'Inglês' : idioma;
      _idiomaNativoSelecionado = idiomaNativo.isEmpty ? 'Português' : idiomaNativo;
      _isFeedbackEnabled = (feedback.isEmpty || feedback == 'true');
    });
  }

  Future<void> _salvar() async {
    if (_filtro == 'custom') {
      int? val = int.tryParse(_customCtrl.text.trim());
      if (val == null || val <= 0) {
        return;
      }
    }

    try {
      final db = DatabaseHelper.instance;
      await db.updateConfig('tema', _isDark ? 'dark' : 'light');
      await db.updateConfig('filtro', _filtro);
      await db.updateConfig('custom_val', _customCtrl.text.trim());
      await db.updateConfig('idioma_atual', _idiomaSelecionado);
      await db.updateConfig('idioma_nativo', _idiomaNativoSelecionado);
      await db.updateConfig('feedback_ativo', _isFeedbackEnabled ? 'true' : 'false');

      appThemeMode.value = _isDark ? ThemeMode.dark : ThemeMode.light;
      appLanguage.value = _idiomaSelecionado;
      appNativeLanguage.value = _idiomaNativoSelecionado;
      appFeedbackEnabled.value = _isFeedbackEnabled;

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Configurações salvas!'))));
    } catch (e) {
      if (!mounted) return;
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
              Text(t("Idioma de Estudo Principal"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _idiomaSelecionado,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                items: supportedLanguages.keys.map((lang) {
                  return DropdownMenuItem(value: lang, child: Text("${supportedLanguages[lang]!.flag} ${t('Aprender')} ${t(lang)}"));
                }).toList(),
                onChanged: (val) { if (val != null) setState(() => _idiomaSelecionado = val); },
              ),
              const SizedBox(height: 20),

              // --- NOVA ABA DE IDIOMA NATIVO ---
              Text(t("Seu Idioma (Origem)"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _idiomaNativoSelecionado,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                items: supportedLanguages.keys.map((lang) {
                  return DropdownMenuItem(value: lang, child: Text("${supportedLanguages[lang]!.flag} ${t('Falar')} ${t(lang)}"));
                }).toList(),
                onChanged: (val) { if (val != null) setState(() => _idiomaNativoSelecionado = val); },
              ),

              const Divider(height: 30),
              Text(t("Preferências"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SwitchListTile(title: Text(t("Modo Noturno")), value: _isDark, onChanged: (val) => setState(() => _isDark = val)),
              SwitchListTile(title: Text(t("Som e Vibração")), value: _isFeedbackEnabled, onChanged: (val) => setState(() => _isFeedbackEnabled = val)),

              const Divider(height: 30),
              Text(t("Filtro de Sorteio (Global)"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              RadioListTile(title: Text(t("Todas as palavras")), value: 'todas', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              RadioListTile(title: Text(t("Últimas 10")), value: '10', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              RadioListTile(title: Text(t("Últimas 20")), value: '20', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              RadioListTile(title: Text(t("Últimas 30")), value: '30', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              RadioListTile(title: Text(t("Personalizado")), value: 'custom', groupValue: _filtro, onChanged: (v) => setState(() => _filtro = v.toString())),
              if (_filtro == 'custom')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: TextField(controller: _customCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t("Nº Personalizado (> 0)"), border: const OutlineInputBorder())),
                ),
              const Divider(),
              Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: _salvar, child: Text(t("Salvar")))),
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
      // O Tradutor agora envia os dados para a sua LÍNGUA DE ORIGEM Global
      String targetLangCode = supportedLanguages[appNativeLanguage.value]!.transCode;
      final translation = await translator.translate(_inglesCtrl.text.trim(), from: langData.transCode, to: targetLangCode);
      setState(() => _traducaoCtrl.text = translation.text);
    } catch (e) {
      if (!mounted) return;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Preencha a palavra e a tradução antes de salvar.'))));
      return;
    }
    try {
      final db = DatabaseHelper.instance;
      final ex = await db.fetchMeanings(_inglesCtrl.text.trim(), widget.currentLang);
      if (ex.isNotEmpty) {
        if (!mounted) return;
        bool? addAnother = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
                title: Text(t("Palavra Existente")),
                content: Text(t("Esta palavra já existe na biblioteca desta língua. Deseja adicionar este novo significado a ela?")),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t("Cancelar"))),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t("Sim")))
                ]
            )
        );
        if (addAnother != true) return;
      }
      await db.insertWord({'ingles': _inglesCtrl.text.trim(), 'traducao': _traducaoCtrl.text.trim(), 'imagem': _imageFile?.path ?? '', 'lingua': widget.currentLang});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Palavra salva com sucesso!')), backgroundColor: Colors.green));
      setState(() { _inglesCtrl.clear(); _traducaoCtrl.clear(); _imageFile = null; });
    } catch (e) {
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Text(t("Registar Palavra"), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: TextField(controller: _inglesCtrl, decoration: InputDecoration(labelText: "${t('Palavra em')} ${t(widget.currentLang)}", border: const OutlineInputBorder()))),
              IconButton(icon: const Icon(Icons.volume_up, color: Colors.blue), tooltip: t("Falar"), onPressed: () => _falar(_inglesCtrl.text.trim())),
              IconButton(icon: _isTranslating ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.g_translate, color: Colors.blue), onPressed: _translateWord),
            ],
          ),
          const SizedBox(height: 15),
          TextField(controller: _traducaoCtrl, decoration: InputDecoration(labelText: t('Significado / Tradução'), border: const OutlineInputBorder())),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(icon: const Icon(Icons.camera_alt), label: Text(t('Câmera')), onPressed: () => _pickImage(ImageSource.camera)),
              ElevatedButton.icon(icon: const Icon(Icons.photo_library), label: Text(t('Galeria')), onPressed: () => _pickImage(ImageSource.gallery)),
            ],
          ),
          const SizedBox(height: 20),
          if (_imageFile != null) ...[
            Image.file(_imageFile!, height: 150, fit: BoxFit.cover),
            TextButton.icon(icon: const Icon(Icons.delete, color: Colors.red), label: Text(t('Remover Foto'), style: const TextStyle(color: Colors.red)), onPressed: () => setState(() => _imageFile = null))
          ],
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: _saveWord, child: Text(t('Confirmar'), style: const TextStyle(fontSize: 18))))
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
  int _totalWordsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords([String query = '']) async {
    final words = await DatabaseHelper.instance.fetchDistinctWords(widget.currentLang, query);
    final totalWords = await DatabaseHelper.instance.fetchDistinctWords(widget.currentLang, '');
    setState(() {
      _distinctWords = words;
      _totalWordsCount = totalWords.length;
    });
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text("${t('Sua Biblioteca em')} ${t(widget.currentLang)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text("($_totalWordsCount ${t('registradas')})", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(labelText: t('Pesquisar...'), prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder()),
              onChanged: (value) => _loadWords(value)
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _distinctWords.isEmpty
                ? Center(child: Text(t("Nenhuma palavra encontrada."), style: const TextStyle(color: Colors.grey)))
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
  void initState() {
    super.initState();
    _loadMeanings();
  }

  Future<void> _loadMeanings() async {
    final res = await DatabaseHelper.instance.fetchMeanings(widget.ingles, widget.currentLang);
    setState(() => _meanings = res);
  }

  void _irParaEdicao() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => EditWordScreen(ingles: widget.ingles, meanings: _meanings, currentLang: widget.currentLang)));
    final res = await DatabaseHelper.instance.fetchMeanings(widget.ingles, widget.currentLang);
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
          actions: [IconButton(icon: const Icon(Icons.edit), tooltip: t("Editar Palavra"), onPressed: _irParaEdicao)]
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
              Text("${t('Significado')} ${index + 1}: ${sig['traducao']}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: index > 0 ? Colors.blue : null)),
              const SizedBox(height: 10),
              if (hasImg)
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(sig['imagem']), height: 180, fit: BoxFit.contain))
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
    for (var m in widget.meanings) {
      _editMeanings.add({ 'id': m['id'], 'traducao': TextEditingController(text: m['traducao']), 'imagem': m['imagem'] });
    }
  }

  void _addSignificado() {
    setState(() { _editMeanings.add({ 'id': null, 'traducao': TextEditingController(), 'imagem': '' }); });
  }

  Future<void> _alterarFoto(int index, ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final String newPath = path.join((await getApplicationDocumentsDirectory()).path, 'img_${Random().nextInt(100000)}.jpg');
      final File savedImage = await File(pickedFile.path).copy(newPath);
      setState(() => _editMeanings[index]['imagem'] = savedImage.path);
    }
  }

  void _removerSignificado(int index) {
    if (_editMeanings.length <= 1) return;
    setState(() => _editMeanings.removeAt(index));
  }

  Future<void> _excluirPalavraToda() async {
    bool? conf = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
            title: Text(t("Excluir Palavra?")),
            content: Text(t("Deseja apagar esta palavra e TODOS os seus significados nesta língua?")),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t("Cancelar"))),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: Text(t("Excluir")))
            ]
        )
    );

    if (conf == true) {
      await DatabaseHelper.instance.deleteAllMeanings(widget.ingles, widget.currentLang);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _salvarAlteracoes() async {
    if (_inglesCtrl.text.isEmpty) return;

    try {
      final db = DatabaseHelper.instance;
      await db.deleteAllMeanings(widget.ingles, widget.currentLang);

      for (var m in _editMeanings) {
        String tradText = (m['traducao'] as TextEditingController).text.trim();
        if (tradText.isNotEmpty) {
          await db.insertWord({ 'ingles': _inglesCtrl.text.trim(), 'traducao': tradText, 'imagem': m['imagem'], 'lingua': widget.currentLang });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Alterações salvas!'))));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t("Editar Palavra"))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              TextField(
                  controller: _inglesCtrl,
                  decoration: InputDecoration(labelText: "${t('Palavra Principal')} (${t(widget.currentLang)})", border: const OutlineInputBorder()),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 15),
              Text(t("Significados Registados:"), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                  Expanded(child: TextField(controller: m['traducao'], decoration: InputDecoration(labelText: "${t('Significado')} ${index + 1}"))),
                                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removerSignificado(index))
                                ]
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (hasImg)
                                  Container(margin: const EdgeInsets.only(right: 10), child: Image.file(File(m['imagem']), width: 40, height: 40, fit: BoxFit.cover)),
                                TextButton.icon(
                                  icon: const Icon(Icons.image),
                                  label: Text(hasImg ? t("Alterar Foto") : t("Adicionar Foto")),
                                  onPressed: () {
                                    showModalBottomSheet(
                                        context: context,
                                        builder: (_) => SafeArea(
                                            child: Wrap(
                                                children: [
                                                  ListTile(leading: const Icon(Icons.camera_alt), title: Text(t('Câmera')), onTap: () { Navigator.pop(context); _alterarFoto(index, ImageSource.camera); }),
                                                  ListTile(leading: const Icon(Icons.photo_library), title: Text(t('Galeria')), onTap: () { Navigator.pop(context); _alterarFoto(index, ImageSource.gallery); }),
                                                  if (hasImg)
                                                    ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: Text(t('Remover Imagem'), style: const TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); setState(() => m['imagem'] = ''); })
                                                ]
                                            )
                                        )
                                    );
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
                    OutlinedButton.icon(onPressed: _addSignificado, icon: const Icon(Icons.add), label: Text(t("Significado"))),
                    TextButton.icon(onPressed: _excluirPalavraToda, icon: const Icon(Icons.delete_forever, color: Colors.red), label: Text(t("Excluir Palavra"), style: const TextStyle(color: Colors.red)))
                  ]
              ),
              const Divider(),
              SizedBox(width: double.infinity, height: 45, child: FilledButton.icon(onPressed: _salvarAlteracoes, icon: const Icon(Icons.save), label: Text(t("Salvar Alterações"))))
            ],
          ),
        ),
      ),
    );
  }
}