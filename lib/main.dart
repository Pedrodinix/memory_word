import 'package:flutter/material.dart';

// Importação das novas pastas modulares
import 'banco_de_dados/database_helper.dart';
import 'telas/tela_registro.dart';
import 'telas/tela_pratica.dart';
import 'telas/tela_biblioteca.dart';

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
final ValueNotifier<String> appLanguage = ValueNotifier('Inglês');
final ValueNotifier<String> appNativeLanguage = ValueNotifier('Português');
final ValueNotifier<bool> appFeedbackEnabled = ValueNotifier(true);
final ValueNotifier<bool> appTreinoInteligente = ValueNotifier(false);

// --- MOTOR DE TRADUÇÃO GLOBAL ---
String t(String text) {
  String code = supportedLanguages[appNativeLanguage.value]?.transCode ?? 'pt';
  if (code == 'pt') return text;

  const Map<String, Map<String, String>> dict = {
    'Inglês': {'en': 'English', 'de': 'Englisch', 'es': 'Inglés', 'fr': 'Anglais'},
    'Alemão': {'en': 'German', 'de': 'Deutsch', 'es': 'Alemán', 'fr': 'Allemand'},
    'Espanhol': {'en': 'Spanish', 'de': 'Spanisch', 'es': 'Español', 'fr': 'Espagnol'},
    'Português': {'en': 'Portuguese', 'de': 'Portugiesisch', 'es': 'Portugués', 'fr': 'Portugais'},
    'Francês': {'en': 'French', 'de': 'Französisch', 'es': 'Francés', 'fr': 'Français'},
    'Novo': {'en': 'New', 'de': 'Neu', 'es': 'Nuevo', 'fr': 'Nouveau'},
    'Praticar': {'en': 'Practice', 'de': 'Üben', 'es': 'Practicar', 'fr': 'Pratiquer'},
    'Biblioteca': {'en': 'Library', 'de': 'Bibliothek', 'es': 'Biblioteca', 'fr': 'Bibliothèque'},
    'Configurações': {'en': 'Settings', 'de': 'Einstellungen', 'es': 'Ajustes', 'fr': 'Paramètres'},
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
    'Registar Palavra': {'en': 'Register Word', 'de': 'Wort registrieren', 'es': 'Registrar Palabra', 'fr': 'Enregistrer le mot'},
    'Palavra em': {'en': 'Word in', 'de': 'Wort auf', 'es': 'Palabra en', 'fr': 'Mot en'},
    'Significado / Tradução': {'en': 'Meaning / Translation', 'de': 'Bedeutung / Übersetzung', 'es': 'Significado / Traducción', 'fr': 'Signification / Traduction'},
    'Câmera': {'en': 'Camera', 'de': 'Kamera', 'es': 'Cámara', 'fr': 'Caméra'},
    'Galeria': {'en': 'Gallery', 'de': 'Galerie', 'es': 'Galería', 'fr': 'Galerie'},
    'Confirmar': {'en': 'Confirm', 'de': 'Bestätigen', 'es': 'Confirmar', 'fr': 'Confirmer'},
    'Remover Foto': {'en': 'Remove Photo', 'de': 'Foto entfernen', 'es': 'Eliminar Foto', 'fr': 'Supprimer la photo'},
    'Preencha a palavra e a tradução antes de salvar.': {'en': 'Fill word and translation before saving.', 'de': 'Bitte Wort und Übersetzung eingeben.', 'es': 'Rellene palabra y traducción antes de guardar.', 'fr': 'Remplissez le mot et la traduction avant d\'enregistrer.'},
    'Palavra salva com sucesso!': {'en': 'Word saved successfully!', 'de': 'Wort erfolgreich gespeichert!', 'es': '¡Palabra guardada con éxito!', 'fr': 'Mot enregistré avec succès !'},
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
    'Língua Afiada': {'en': 'Sharp Tongue', 'de': 'Scharfe Zunge', 'es': 'Lengua Afilada', 'fr': 'Langue Pendue'},
    'Sortear Nova Palavra': {'en': 'Draw New Word', 'de': 'Neues Wort ziehen', 'es': 'Sortear Nueva Palabra', 'fr': 'Tirer un nouveau mot'},
    'Sorteie para começar': {'en': 'Draw to start', 'de': 'Ziehen um zu starten', 'es': 'Sortea para empezar', 'fr': 'Tirez pour commencer'},
    'Toque para falar': {'en': 'Tap to speak', 'de': 'Tippen zum Sprechen', 'es': 'Toca para hablar', 'fr': 'Appuyez pour parler'},
    'A escutar... Fale agora!': {'en': 'Listening... Speak now!', 'de': 'Höre zu... Sprich jetzt!', 'es': 'Escuchando... ¡Habla ahora!', 'fr': 'Écoute... Parlez maintenant !'},
    'Pronúncia Perfeita! 🎉': {'en': 'Perfect Pronunciation! 🎉', 'de': 'Perfekte Aussprache! 🎉', 'es': '¡Pronunciación Perfecta! 🎉', 'fr': 'Prononciation Parfaite ! 🎉'},
    'Entendemos:': {'en': 'We heard:', 'de': 'Wir haben verstanden:', 'es': 'Entendimos:', 'fr': 'Nous avons compris :'},
    'Seu Desempenho': {'en': 'Your Performance', 'de': 'Deine Leistung', 'es': 'Tu Rendimiento', 'fr': 'Votre Performance'},
    'Desempenho de Hoje': {'en': 'Performance Today', 'de': 'Leistung Heute', 'es': 'Rendimiento de Hoy', 'fr': "Performances d'aujourd'hui"},
    'Últimos 7 Dias': {'en': 'Last 7 Days', 'de': 'Letzte 7 Tage', 'es': 'Últimos 7 Días', 'fr': 'Les 7 Derniers Jours'},
    'Histórico Mensal': {'en': 'Monthly History', 'de': 'Monatlicher Verlauf', 'es': 'Historial Mensual', 'fr': 'Historique Mensuel'},
    'Perguntas Respondidas:': {'en': 'Questions Answered:', 'de': 'Beantwortete Fragen:', 'es': 'Preguntas Respondidas:', 'fr': 'Questions répondues :'},
    'Acertos / Erros:': {'en': 'Hits / Misses:', 'de': 'Treffer / Fehler:', 'es': 'Aciertos / Errores:', 'fr': 'Réussites / Échecs :'},
    'Combos Especiais 🎉:': {'en': 'Special Combos 🎉:', 'de': 'Spezielle Kombos 🎉:', 'es': 'Combos Especiales 🎉:', 'fr': 'Combos Spéciaux 🎉:'},
    'Tempo no Papagaio 🦜:': {'en': 'Parrot Time 🦜:', 'de': 'Papageienzeit 🦜:', 'es': 'Tiempo en Loro 🦜:', 'fr': 'Temps Perroquet 🦜:'},
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
    'Treino Inteligente': {'en': 'Smart Training', 'de': 'Intelligentes Training', 'es': 'Entrenamiento Inteligente', 'fr': 'Entraînement Intelligent'},
    'Priorizar as palavras que você mais erra': {'en': 'Prioritize the words you miss the most', 'de': 'Priorisiere Wörter, die du oft falsch machst', 'es': 'Priorizar las palabras que más fallas', 'fr': 'Privilégier les mots que vous ratez le plus'},
    'Bom (Verde)': {'en': 'Good (Green)', 'de': 'Gut (Grün)', 'es': 'Bueno (Verde)', 'fr': 'Bon (Vert)'},
    'Médio (Amarelo)': {'en': 'Medium (Yellow)', 'de': 'Mittel (Gelb)', 'es': 'Medio (Amarillo)', 'fr': 'Moyen (Jaune)'},
    'Ruim (Vermelho)': {'en': 'Bad (Red)', 'de': 'Schlecht (Rot)', 'es': 'Deficiente (Rojo)', 'fr': 'Mauvais (Rouge)'},
    'Dificuldade Atual:': {'en': 'Current Difficulty:', 'de': 'Aktuelle Schwierigkeit:', 'es': 'Dificultad Actual:', 'fr': 'Difficulté Actuelle :'},
    'Escrita Afiada': {'en': 'Sharp Writing', 'de': 'Scharfes Schreiben', 'es': 'Escritura Afilada', 'fr': 'Écriture Pointue'},
    'Escrita Perfeita! 🎉': {'en': 'Perfect Writing! 🎉', 'de': 'Perfektes Schreiben! 🎉', 'es': '¡Escritura Perfecta! 🎉', 'fr': 'Écriture Parfaite ! 🎉'},
    'Digite o que ouviu': {'en': 'Type what you heard', 'de': 'Tippe, was du gehört hast', 'es': 'Escribe lo que escuchaste', 'fr': 'Tapez ce que vous avez entendu'},
  };
  return dict[text]?[code] ?? text;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseHelper.instance;
  await db.limparDadosAntigos();

  String temaSalvo = await db.getConfig('tema');
  String idiomaSalvo = await db.getConfig('idioma_atual');
  String idiomaNativoSalvo = await db.getConfig('idioma_nativo');
  String feedbackSalvo = await db.getConfig('feedback_ativo');
  String treinoSalvo = await db.getConfig('treino_inteligente');

  appThemeMode.value = (temaSalvo == 'dark') ? ThemeMode.dark : ThemeMode.light;
  if (idiomaSalvo.isNotEmpty && supportedLanguages.containsKey(idiomaSalvo)) {
    appLanguage.value = idiomaSalvo;
  }
  if (idiomaNativoSalvo.isNotEmpty && supportedLanguages.containsKey(idiomaNativoSalvo)) {
    appNativeLanguage.value = idiomaNativoSalvo;
  }
  if (feedbackSalvo.isNotEmpty) {
    appFeedbackEnabled.value = (feedbackSalvo == 'true');
  }
  if (treinoSalvo.isNotEmpty) {
    appTreinoInteligente.value = (treinoSalvo == 'true');
  }

  runApp(const MemoryWordApp());
}

class MemoryWordApp extends StatelessWidget {
  const MemoryWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, currentMode, child) {
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

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
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
    } catch (_) {}
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
                key: ValueKey(_idiomaSelecionado),
                initialValue: _idiomaSelecionado,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                items: supportedLanguages.keys.map((lang) {
                  return DropdownMenuItem(value: lang, child: Text("${supportedLanguages[lang]!.flag} ${t('Aprender')} ${t(lang)}"));
                }).toList(),
                onChanged: (val) { if (val != null) setState(() => _idiomaSelecionado = val); },
              ),
              const SizedBox(height: 20),

              Text(t("Seu Idioma (Origem)"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey(_idiomaNativoSelecionado),
                initialValue: _idiomaNativoSelecionado,
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
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                key: ValueKey(_filtro),
                initialValue: _filtro,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                items: [
                  DropdownMenuItem(value: 'todas', child: Text(t("Todas as palavras"))),
                  DropdownMenuItem(value: '10', child: Text(t("Últimas 10"))),
                  DropdownMenuItem(value: '20', child: Text(t("Últimas 20"))),
                  DropdownMenuItem(value: '30', child: Text(t("Últimas 30"))),
                  DropdownMenuItem(value: 'custom', child: Text(t("Personalizado"))),
                ],
                onChanged: (val) { if (val != null) setState(() => _filtro = val); },
              ),

              if (_filtro == 'custom')
                Padding(
                  padding: const EdgeInsets.only(top: 10),
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