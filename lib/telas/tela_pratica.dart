import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:math';

import '../main.dart';
import '../banco_de_dados/database_helper.dart';
import 'tela_tutorial.dart';

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
  int _streakBeforeLastError = 0;
  int _milestoneBeforeLastError = 10;
  bool _showSpecialOverlay = false;
  int _overlayPoints = 0;

  int _normalTimerToken = 0;
  int _sharpTimerToken = 0;
  int _imageTimerToken = 0;

  // --- MODO CLÁSSICO ---
  Map<String, dynamic>? _currentWordNormal;
  final _answerCtrl = TextEditingController();
  String _resultTextNormal = '';
  Color _resultColorNormal = Colors.black;
  bool _hasAnsweredNormal = false;
  bool _hasPeekedNormal = false;
  bool _lastAnswerWasWrongNormal = false;
  bool _isReversedNormal = false;
  List<Map<String, dynamic>> _allFetchedWordsNormal = [];
  String _questionToDisplay = '';
  List<String> _validAnswersNormal = [];
  List<String> _acceptedAnswersNormal = [];

  // --- MODO PAPAGAIO ---
  String _parrotFilter = 'todas';
  String _parrotCustomVal = '';
  String _parrotMode = 'loop';
  double _parrotSpeed = 1.0;
  final TextEditingController _parrotCustomCtrl = TextEditingController();
  bool _isParrotPlaying = false;
  String _parrotCurrentWordDisplay = '';

  // --- MODO LÍNGUA AFIADA / ESCRITA AFIADA (Apenas Idiomas) ---
  Map<String, dynamic>? _currentWordSharp;
  String _sharpFilter = 'todas';
  String _sharpCustomVal = '';
  final TextEditingController _sharpCustomCtrl = TextEditingController();
  bool _isListening = false;
  String _spokenText = '';
  String _sharpResultText = '';
  Color _sharpResultColor = Colors.black;
  bool _hasAnsweredSharp = false;
  bool _hasPeekedSharp = false;
  bool _lastAnswerWasWrongSharp = false;
  bool _isSharpWriting = false;
  final _sharpAnswerCtrl = TextEditingController();

  // --- MODO DESAFIO VISUAL (Sorteio de Imagem - Idiomas e Estudo Livre) ---
  Map<String, dynamic>? _currentWordImage;
  final _imageAnswerCtrl = TextEditingController();
  String _imageResultText = '';
  Color _imageResultColor = Colors.black;
  bool _hasAnsweredImage = false;
  bool _hasPeekedImage = false;
  bool _lastAnswerWasWrongImage = false;
  bool _imageAskExplanationInFreeMode = false;
  List<String> _validAnswersImage = [];
  List<String> _acceptedAnswersImage = [];

  bool get _isFreeStudy => isCustomStudy(widget.currentLang);
  String get _displayTopic => getStudyDisplayName(widget.currentLang);

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadSettings();
    appNavigateToPracticePage.addListener(_onExternalPracticePageRequest);

    _parrotCustomCtrl.addListener(() {
      _parrotCustomVal = _parrotCustomCtrl.text.trim();
      _saveSettings();
    });
    _sharpCustomCtrl.addListener(() {
      _sharpCustomVal = _sharpCustomCtrl.text.trim();
      _saveSettings();
    });

    _audioCorrect.setSource(AssetSource('correct.mp3'));
    _audioSpecial.setSource(AssetSource('special.mp3'));
    _audioWrong.setSource(AssetSource('wrong.mp3'));
  }

  void _onExternalPracticePageRequest() {
    final target = appNavigateToPracticePage.value;
    if (target != null && _pageController.hasClients) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
      appNavigateToPracticePage.value = null;
    }
  }

  @override
  void didUpdateWidget(PracticeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLang != widget.currentLang) {
      _normalTimerToken++;
      _sharpTimerToken++;
      _imageTimerToken++;
      if (_isParrotPlaying) _stopParrot();
      _currentWordNormal = null;
      _answerCtrl.clear();
      _resultTextNormal = '';
      _hasAnsweredNormal = false;
      _hasPeekedNormal = false;
      _lastAnswerWasWrongNormal = false;
      _questionToDisplay = '';

      _currentWordSharp = null;
      _sharpResultText = '';
      _spokenText = '';
      _hasAnsweredSharp = false;
      _hasPeekedSharp = false;
      _lastAnswerWasWrongSharp = false;
      _sharpAnswerCtrl.clear();

      _currentWordImage = null;
      _imageAnswerCtrl.clear();
      _imageResultText = '';
      _hasAnsweredImage = false;
      _hasPeekedImage = false;
      _lastAnswerWasWrongImage = false;

      _streak = 0;
      _nextMilestone = 10;

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    appNavigateToPracticePage.removeListener(_onExternalPracticePageRequest);
    _normalTimerToken++;
    _sharpTimerToken++;
    _imageTimerToken++;
    _stopParrot();
    _flutterTts.stop();
    _audioCorrect.dispose();
    _audioSpecial.dispose();
    _audioWrong.dispose();
    _pageController.dispose();
    _parrotCustomCtrl.dispose();
    _sharpCustomCtrl.dispose();
    _answerCtrl.dispose();
    _sharpAnswerCtrl.dispose();
    _imageAnswerCtrl.dispose();
    super.dispose();
  }

  String _normalizeForComparison(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _matchesAnyValidAnswer(String rawUserInput, List<String> validList) {
    final String rawClean = rawUserInput.trim().toLowerCase();
    final String normUser = _normalizeForComparison(rawUserInput);
    for (final valid in validList) {
      if (valid.trim().toLowerCase() == rawClean) return true;
      final String normValid = _normalizeForComparison(valid);
      if (normValid.isNotEmpty && normValid == normUser) return true;
    }
    return false;
  }

  void _playCorrectSound() async {
    if (!appFeedbackEnabled.value) return;
    try {
      await _audioCorrect.stop();
      await _audioCorrect.play(AssetSource('correct.mp3'));
    } catch (_) {}
  }

  void _playSpecialSound() async {
    if (!appFeedbackEnabled.value) return;
    try {
      await _audioSpecial.stop();
      await _audioSpecial.play(AssetSource('special.mp3'));
    } catch (_) {}
  }

  void _playWrongSound() async {
    if (!appFeedbackEnabled.value) return;
    try {
      await _audioWrong.stop();
      await _audioWrong.play(AssetSource('wrong.mp3'));
    } catch (_) {}
  }

  void _handleAnswer(bool isCorrect, String wordIngles) {
    DatabaseHelper.instance.registrarAtividade('respondidas');
    DatabaseHelper.instance.atualizarDificuldade(wordIngles, widget.currentLang, isCorrect);

    if (isCorrect) {
      DatabaseHelper.instance.registrarAtividade('acertos');
      agendarVerificacaoDeProgressoRecente();
      _streak++;
      if (_streak == _nextMilestone) {
        DatabaseHelper.instance.registrarAtividade('especiais');
        _triggerSpecialOverlay(_nextMilestone);
        _nextMilestone = _nextMilestone < 30 ? _nextMilestone + 10 : _nextMilestone * 2;
      } else {
        _playCorrectSound();
      }
    } else {
      _streakBeforeLastError = _streak;
      _milestoneBeforeLastError = _nextMilestone;
      DatabaseHelper.instance.registrarAtividade('erros');
      _streak = 0;
      _nextMilestone = 10;
      _playWrongSound();
      if (appFeedbackEnabled.value) HapticFeedback.vibrate();
    }
  }

  void _triggerSpecialOverlay(int points) {
    _playSpecialSound();
    setState(() {
      _overlayPoints = points;
      _showSpecialOverlay = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSpecialOverlay = false);
    });
  }

  Future<void> _abrirDialogoReivindicacao({
    required String wordIngles,
    required String currentMeaningsDisplay,
    required String userTypedAnswer,
    required bool allowAddingMeaningToDb,
    required VoidCallback onClaimedSuccess,
  }) async {
    _normalTimerToken++;
    _sharpTimerToken++;
    _imageTimerToken++;

    final String? acao = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.gavel, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(t('Reivindicar Resposta'))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${t('Palavra / Objeto:')} $wordIngles", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("${t('Significados Atuais:')} $currentMeaningsDisplay"),
              const SizedBox(height: 6),
              Text(
                "${t('Sua Resposta:')} $userTypedAnswer",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const Divider(height: 24),
              Text(
                t('Como deseja validar esta resposta como correta?'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (allowAddingMeaningToDb) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.visibility_off, color: Colors.orange),
                    title: Text(
                      t('Adicionar como Significado Oculto'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      t('Aceita no futuro, mas não aparece na Biblioteca nem no Modo Papagaio.'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(c, 'oculto'),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.visibility, color: Colors.green),
                    title: Text(
                      t('Adicionar como Significado Visível'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      t('Aparecerá normalmente na Biblioteca e no Modo Papagaio.'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(c, 'visivel'),
                  ),
                ),
              ],
              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: Colors.blue),
                  title: Text(
                    t('Apenas validar acerto desta vez'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onTap: () => Navigator.pop(c, 'apenas_validar'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, null),
            child: Text(t('Cancelar')),
          ),
        ],
      ),
    );

    if (acao == null) return;

    if (acao == 'oculto' || acao == 'visivel') {
      await DatabaseHelper.instance.adicionarSignificadoReivindicado(
        ingles: wordIngles,
        novaTraducao: userTypedAnswer,
        lingua: widget.currentLang,
        oculto: acao == 'oculto',
      );
    }

    final int restoredStreak = _streakBeforeLastError + 1;
    final int restoredMilestone = _milestoneBeforeLastError;
    final bool hitCombo = restoredStreak == restoredMilestone;

    await DatabaseHelper.instance.reverterErroParaAcerto(
      wordIngles,
      widget.currentLang,
      gerouComboEspecial: hitCombo,
    );
    agendarVerificacaoDeProgressoRecente();

    if (!mounted) return;
    setState(() {
      _streak = restoredStreak;
      if (hitCombo) {
        _triggerSpecialOverlay(restoredMilestone);
        _nextMilestone = restoredMilestone < 30 ? restoredMilestone + 10 : restoredMilestone * 2;
      } else {
        _nextMilestone = restoredMilestone;
        _playCorrectSound();
      }
    });

    onClaimedSuccess();
  }

  Future<void> _falar(String texto, {double rate = 0.5, bool forceNative = false}) async {
    AppLanguage langData = (_isFreeStudy || forceNative)
        ? (supportedLanguages[appNativeLanguage.value] ?? supportedLanguages['Português']!)
        : (supportedLanguages[widget.currentLang] ?? supportedLanguages['Inglês']!);
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

  Widget _buildEmptyLibraryActionButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.add_circle_outline),
        label: Text(t('Cadastrar Primeiro Item')),
        onPressed: () {
          appNavigateToTab.value = 0;
        },
      ),
    );
  }

  Widget _buildSmartTrainingToggle() {
    return ValueListenableBuilder<bool>(
      valueListenable: appTreinoInteligente,
      builder: (context, isSmart, child) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        Color? cardColor = isSmart ? (isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50) : null;

        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isSmart ? Colors.blue : Colors.transparent, width: 2),
          ),
          child: SwitchListTile(
            secondary: const Text('🧠', style: TextStyle(fontSize: 24)),
            title: Text(t("Treino Inteligente"), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(t("Priorizar os itens que você mais erra"), style: const TextStyle(fontSize: 12)),
            value: isSmart,
            onChanged: (val) {
              appTreinoInteligente.value = val;
              DatabaseHelper.instance.updateConfig('treino_inteligente', val.toString());
              if (!_isParrotPlaying && !_isListening) {
                final page = _pageController.hasClients ? (_pageController.page?.round() ?? 0) : 0;
                if (page == 0) _drawWordNormal();
              }
            },
          ),
        );
      },
    );
  }

  // ==========================================
  // LÓGICA: MODO CLÁSSICO E ESPIAR RESPOSTA
  // ==========================================
  Future<void> _drawWordNormal() async {
    _normalTimerToken++;
    final db = DatabaseHelper.instance;
    final filtroGlobal = await db.getConfig('filtro');
    final customGlobal = await db.getConfig('custom_val');
    final words = await db.fetchCustomWords(
      widget.currentLang,
      filtroGlobal.isEmpty ? 'todas' : filtroGlobal,
      customGlobal,
    );

    if (!mounted) return;
    if (words.isEmpty) {
      setState(() {
        _currentWordNormal = null;
        _questionToDisplay = '';
        _resultTextNormal = t('Sua biblioteca está vazia!');
        _resultColorNormal = Colors.blue;
      });
      return;
    }

    setState(() {
      _allFetchedWordsNormal = words;
      _currentWordNormal = words[Random().nextInt(words.length)];
      _answerCtrl.clear();
      _resultTextNormal = '';
      _hasAnsweredNormal = false;
      _hasPeekedNormal = false;
      _lastAnswerWasWrongNormal = false;

      if (!_isReversedNormal) {
        _questionToDisplay = _currentWordNormal!['ingles'];
        _validAnswersNormal = _currentWordNormal!['traducoes']
            .toString()
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        final hiddenList = (_currentWordNormal!['traducoes_ocultas']?.toString() ?? '')
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        _acceptedAnswersNormal = [..._validAnswersNormal, ...hiddenList];
      } else {
        final meanings = _currentWordNormal!['traducoes']
            .toString()
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        _questionToDisplay = meanings[Random().nextInt(meanings.length)];
        _validAnswersNormal = [];
        for (var w in _allFetchedWordsNormal) {
          final wMeanings = w['traducoes'].toString().split('|').map((e) => e.trim().toLowerCase()).toList();
          final wHidden = (w['traducoes_ocultas']?.toString() ?? '')
              .split('|')
              .map((e) => e.trim().toLowerCase())
              .toList();
          if (wMeanings.contains(_questionToDisplay.toLowerCase()) ||
              wHidden.contains(_questionToDisplay.toLowerCase())) {
            _validAnswersNormal.add(w['ingles'].toString());
          }
        }
        _acceptedAnswersNormal = List<String>.from(_validAnswersNormal);
      }
    });
  }

  void _peekAnswerNormal() {
    if (_currentWordNormal == null || _hasAnsweredNormal) return;
    _normalTimerToken++;
    setState(() {
      _hasAnsweredNormal = true;
      _hasPeekedNormal = true;
      _lastAnswerWasWrongNormal = false;
      final displayCorrect = _validAnswersNormal.join(' ${t('ou')} ');
      _resultTextNormal = '${t('Resposta revelada (não contabilizada):')} $displayCorrect';
      _resultColorNormal = Colors.orange.shade800;
    });
  }

  void _verifyAnswerNormal() async {
    if (_currentWordNormal == null || _answerCtrl.text.trim().isEmpty || _hasAnsweredNormal) return;

    final int currentToken = ++_normalTimerToken;
    bool acertou = _matchesAnyValidAnswer(_answerCtrl.text, _acceptedAnswersNormal);

    setState(() {
      _hasAnsweredNormal = true;
      _hasPeekedNormal = false;
      _lastAnswerWasWrongNormal = !acertou;
      if (acertou) {
        _resultTextNormal = t('Resposta Correta! 🎉');
        _resultColorNormal = Colors.green;
      } else {
        final displayCorrect = _validAnswersNormal.join(' ${t('ou')} ');
        _resultTextNormal = '${t('Incorreta. O correto é:')} $displayCorrect';
        _resultColorNormal = Colors.red;
      }
    });

    _handleAnswer(acertou, _currentWordNormal!['ingles']);

    if (appAutoNext.value) {
      await Future.delayed(Duration(milliseconds: acertou ? 2000 : 3200));
      if (mounted && _hasAnsweredNormal && _normalTimerToken == currentToken) {
        _drawWordNormal();
      }
    }
  }

  // ==========================================
  // LÓGICA: CONFIGURAÇÕES E MODO PAPAGAIO
  // ==========================================
  Future<void> _loadSettings() async {
    final db = DatabaseHelper.instance;
    final pFiltro = await db.getConfig('papagaio_filtro');
    final pCustom = await db.getConfig('papagaio_custom_val');
    final pModo = await db.getConfig('papagaio_modo');
    final pVel = await db.getConfig('papagaio_vel');
    final aFiltro = await db.getConfig('afiada_filtro');
    final aCustom = await db.getConfig('afiada_custom_val');

    if (!mounted) return;
    setState(() {
      if (pFiltro.isNotEmpty) _parrotFilter = pFiltro;
      _parrotCustomVal = pCustom;
      if (_parrotCustomCtrl.text != pCustom) _parrotCustomCtrl.text = pCustom;
      if (pModo.isNotEmpty) _parrotMode = pModo;
      if (pVel.isNotEmpty) _parrotSpeed = double.tryParse(pVel) ?? 1.0;
      if (aFiltro.isNotEmpty) _sharpFilter = aFiltro;
      _sharpCustomVal = aCustom;
      if (_sharpCustomCtrl.text != aCustom) _sharpCustomCtrl.text = aCustom;
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
      await _flutterTts.awaitSpeakCompletion(true);
      if (Platform.isIOS) {
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.mixWithOthers, IosTextToSpeechAudioCategoryOptions.allowBluetooth],
        );
      }

      while (_isParrotPlaying) {
        final rawWords = await DatabaseHelper.instance.fetchCustomWords(
          widget.currentLang,
          _parrotFilter,
          _parrotCustomVal,
        );
        if (rawWords.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('Sua biblioteca está vazia!')), backgroundColor: Colors.orange),
            );
            setState(() {
              _stopParrot();
              _parrotCurrentWordDisplay = t('Sua biblioteca está vazia!');
            });
          }
          break;
        }

        final words = List<Map<String, dynamic>>.from(rawWords)..shuffle();
        AppLanguage nativeLang = supportedLanguages[appNativeLanguage.value] ?? supportedLanguages['Português']!;
        AppLanguage studyLang = _isFreeStudy
            ? nativeLang
            : (supportedLanguages[widget.currentLang] ?? supportedLanguages['Inglês']!);

        for (var word in words) {
          if (!_isParrotPlaying) break;

          if (mounted) setState(() => _parrotCurrentWordDisplay = word['ingles']);
          await _flutterTts.setLanguage(studyLang.ttsCode);
          await _flutterTts.setSpeechRate(0.5 * _parrotSpeed);
          await _flutterTts.speak(word['ingles']);

          if (!_isParrotPlaying) break;
          await Future.delayed(Duration(milliseconds: (1200 / _parrotSpeed).round()));
          if (!_isParrotPlaying) break;

          String trad = word['traducoes'].toString().replaceAll('|', ' ${t('ou')} ');
          if (mounted) setState(() => _parrotCurrentWordDisplay = trad);
          await _flutterTts.setLanguage(nativeLang.ttsCode);
          await _flutterTts.setSpeechRate(0.5 * _parrotSpeed);
          await _flutterTts.speak(trad);

          if (!_isParrotPlaying) break;
          await Future.delayed(Duration(milliseconds: (2000 / _parrotSpeed).round()));
        }
        if (_parrotMode == 'single' && _isParrotPlaying) {
          if (mounted) {
            setState(() {
              _stopParrot();
              _parrotCurrentWordDisplay = t('Sequência Concluída!');
            });
          }
          break;
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _stopParrot());
      }
    }
  }

  // ==========================================
  // LÓGICA: LÍNGUA AFIADA E ESCRITA AFIADA
  // ==========================================
  Future<void> _drawWordSharp() async {
    _sharpTimerToken++;
    final words = await DatabaseHelper.instance.fetchCustomWords(widget.currentLang, _sharpFilter, _sharpCustomVal);
    if (!mounted) return;
    if (words.isEmpty) {
      setState(() {
        _currentWordSharp = null;
        _sharpResultText = t('Sua biblioteca está vazia!');
        _sharpResultColor = Colors.blue;
      });
      return;
    }
    setState(() {
      _currentWordSharp = words[Random().nextInt(words.length)];
      _sharpResultText = '';
      _spokenText = '';
      _hasAnsweredSharp = false;
      _hasPeekedSharp = false;
      _lastAnswerWasWrongSharp = false;
      _sharpAnswerCtrl.clear();
    });
    _falar(_currentWordSharp!['ingles']);
  }

  void _peekAnswerSharp() {
    if (_currentWordSharp == null || _hasAnsweredSharp) return;
    _sharpTimerToken++;
    setState(() {
      _hasAnsweredSharp = true;
      _hasPeekedSharp = true;
      _isListening = false;
      _lastAnswerWasWrongSharp = false;
      final String rawTarget = _currentWordSharp!['ingles'].toString().trim();
      _sharpResultText = '${t('Resposta revelada (não contabilizada):')} $rawTarget';
      _sharpResultColor = Colors.orange.shade800;
    });
  }

  void _listenSharp() async {
    if (_hasAnsweredSharp) return;

    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'notListening' || val == 'done') {
            if (mounted) setState(() => _isListening = false);
            if (_spokenText.trim().isNotEmpty && !_hasAnsweredSharp) {
              _verifySpeech();
            }
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (available) {
        setState(() {
          _spokenText = '';
          _isListening = true;
        });
        AppLanguage langData = supportedLanguages[widget.currentLang] ?? supportedLanguages['Inglês']!;
        _speech.listen(
          onResult: (val) {
            if (!mounted) return;
            setState(() {
              _spokenText = val.recognizedWords;
            });
            if (val.finalResult) {
              _speech.stop();
              setState(() => _isListening = false);
              _verifySpeech();
            }
          },
          listenOptions: stt.SpeechListenOptions(localeId: langData.ttsCode),
        );
      } else {
        setState(() => _isListening = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('Reconhecimento de voz indisponível no celular.'))),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
      _verifySpeech();
    }
  }

  void _verifySpeech() async {
    if (_currentWordSharp == null || _spokenText.trim().isEmpty || _hasAnsweredSharp) return;

    final int currentToken = ++_sharpTimerToken;
    String target = _normalizeForComparison(_currentWordSharp!['ingles'].toString());
    String spoken = _normalizeForComparison(_spokenText);

    bool acertou = target.isNotEmpty && (spoken == target || spoken.contains(target));
    setState(() {
      _hasAnsweredSharp = true;
      _isListening = false;
      _lastAnswerWasWrongSharp = !acertou;
      if (acertou) {
        _sharpResultText = t('Pronúncia Perfeita! 🎉');
        _sharpResultColor = Colors.green;
      } else {
        _sharpResultText = '${t('Entendemos:')} "${_spokenText.trim()}"';
        _sharpResultColor = Colors.red;
      }
    });

    _handleAnswer(acertou, _currentWordSharp!['ingles']);
    if (appAutoNext.value) {
      await Future.delayed(Duration(milliseconds: acertou ? 2000 : 3200));
      if (mounted && _hasAnsweredSharp && _sharpTimerToken == currentToken) {
        _drawWordSharp();
      }
    }
  }

  void _verifyAnswerSharpWriting() async {
    if (_currentWordSharp == null || _sharpAnswerCtrl.text.trim().isEmpty || _hasAnsweredSharp) return;

    final int currentToken = ++_sharpTimerToken;
    String rawTarget = _currentWordSharp!['ingles'].toString().trim();
    bool acertou = _matchesAnyValidAnswer(_sharpAnswerCtrl.text, [rawTarget]);

    setState(() {
      _hasAnsweredSharp = true;
      _hasPeekedSharp = false;
      _lastAnswerWasWrongSharp = !acertou;
      if (acertou) {
        _sharpResultText = t('Escrita Perfeita! 🎉');
        _sharpResultColor = Colors.green;
      } else {
        _sharpResultText = '${t('Incorreta. O correto é:')} $rawTarget';
        _sharpResultColor = Colors.red;
      }
    });

    _handleAnswer(acertou, _currentWordSharp!['ingles']);
    if (appAutoNext.value) {
      await Future.delayed(Duration(milliseconds: acertou ? 2000 : 3200));
      if (mounted && _hasAnsweredSharp && _sharpTimerToken == currentToken) {
        _drawWordSharp();
      }
    }
  }

  // ==========================================
  // LÓGICA: DESAFIO VISUAL (SORTEIO DE IMAGEM)
  // ==========================================
  Future<void> _drawWordImage() async {
    _imageTimerToken++;
    final db = DatabaseHelper.instance;
    final filtroGlobal = await db.getConfig('filtro');
    final customGlobal = await db.getConfig('custom_val');
    final allWords = await db.fetchCustomWords(
      widget.currentLang,
      filtroGlobal.isEmpty ? 'todas' : filtroGlobal,
      customGlobal,
    );

    final wordsWithImages = allWords.where((w) {
      return db.getImageFile(w['imagem']?.toString()) != null;
    }).toList();

    if (!mounted) return;
    if (wordsWithImages.isEmpty) {
      setState(() {
        _currentWordImage = null;
        _imageResultText = t(
          'Nenhum item com imagem encontrado nesta biblioteca! Adicione fotos aos seus registros para usar este modo.',
        );
        _imageResultColor = Colors.orange.shade800;
      });
      return;
    }

    setState(() {
      _currentWordImage = wordsWithImages[Random().nextInt(wordsWithImages.length)];
      _imageAnswerCtrl.clear();
      _imageResultText = '';
      _hasAnsweredImage = false;
      _hasPeekedImage = false;
      _lastAnswerWasWrongImage = false;
      _updateValidImageAnswers();
    });
  }

  void _updateValidImageAnswers() {
    if (_currentWordImage == null) return;
    if (!_isFreeStudy || !_imageAskExplanationInFreeMode) {
      _validAnswersImage = [_currentWordImage!['ingles'].toString().trim()];
      _acceptedAnswersImage = List<String>.from(_validAnswersImage);
    } else {
      _validAnswersImage = _currentWordImage!['traducoes']
          .toString()
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final hiddenList = (_currentWordImage!['traducoes_ocultas']?.toString() ?? '')
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      _acceptedAnswersImage = [..._validAnswersImage, ...hiddenList];
    }
  }

  void _peekAnswerImage() {
    if (_currentWordImage == null || _hasAnsweredImage) return;
    _imageTimerToken++;
    setState(() {
      _hasAnsweredImage = true;
      _hasPeekedImage = true;
      _lastAnswerWasWrongImage = false;
      final displayCorrect = _validAnswersImage.join(' ${t('ou')} ');
      _imageResultText = '${t('Resposta revelada (não contabilizada):')} $displayCorrect';
      _imageResultColor = Colors.orange.shade800;
    });
  }

  void _verifyAnswerImage() async {
    if (_currentWordImage == null || _imageAnswerCtrl.text.trim().isEmpty || _hasAnsweredImage) return;

    final int currentToken = ++_imageTimerToken;
    bool acertou = _matchesAnyValidAnswer(_imageAnswerCtrl.text, _acceptedAnswersImage);

    setState(() {
      _hasAnsweredImage = true;
      _hasPeekedImage = false;
      _lastAnswerWasWrongImage = !acertou;
      if (acertou) {
        _imageResultText = t('Resposta Correta! 🎉');
        _imageResultColor = Colors.green;
      } else {
        final displayCorrect = _validAnswersImage.join(' ${t('ou')} ');
        _imageResultText = '${t('Incorreta. O correto é:')} $displayCorrect';
        _imageResultColor = Colors.red;
      }
    });

    _handleAnswer(acertou, _currentWordImage!['ingles']);

    if (appAutoNext.value) {
      await Future.delayed(Duration(milliseconds: acertou ? 2000 : 3200));
      if (mounted && _hasAnsweredImage && _imageTimerToken == currentToken) {
        _drawWordImage();
      }
    }
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
    final pages = _isFreeStudy
        ? [
      _buildNormalPractice(),
      _buildParrotPractice(),
      _buildImagePractice(),
      _buildDesempenhoPractice(),
    ]
        : [
      _buildNormalPractice(),
      _buildParrotPractice(),
      _buildSharpPractice(),
      _buildImagePractice(),
      _buildDesempenhoPractice(),
    ];

    return Stack(
      children: [
        PageView(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          children: pages,
        ),
        if (_showSpecialOverlay)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
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
                            Text(
                              t("Combos Especiais 🎉:").replaceAll(':', '!'),
                              style: const TextStyle(
                                fontSize: 32,
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "+$_overlayPoints",
                              style: const TextStyle(
                                fontSize: 100,
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // UI: 1. MODO CLÁSSICO
  // ==========================================
  Widget _buildNormalPractice() {
    final File? imgFile = DatabaseHelper.instance.getImageFile(_currentWordNormal?['imagem']?.toString());

    String inputLabel;
    if (_isFreeStudy) {
      inputLabel = _isReversedNormal ? t('Qual é o Objeto de Estudo?') : t('Sua Explicação');
    } else {
      inputLabel = _isReversedNormal ? "${t('Responder em')} $_displayTopic" : t('Sua Tradução');
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              children: [
                _buildSmartTrainingToggle(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          t("Modo Clássico"),
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.sync_alt, color: Colors.blue, size: 20),
                          tooltip: t("Inverter"),
                          onPressed: () {
                            setState(() {
                              _isReversedNormal = !_isReversedNormal;
                            });
                            _drawWordNormal();
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _hasPeekedNormal ? Icons.visibility : Icons.visibility_outlined,
                            color: (_currentWordNormal != null && !_hasAnsweredNormal)
                                ? Colors.deepPurple
                                : Colors.grey,
                            size: 22,
                          ),
                          tooltip: t("Espiar Resposta"),
                          onPressed: (_currentWordNormal != null && !_hasAnsweredNormal)
                              ? _peekAnswerNormal
                              : null,
                        ),
                      ],
                    ),
                    Text(
                      "🔥 $_streak",
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  icon: const Icon(Icons.shuffle),
                  label: Text(_isFreeStudy ? t('Sortear Objeto de Estudo') : t('Sortear Palavra')),
                  onPressed: _drawWordNormal,
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _questionToDisplay.isEmpty ? t('Clique acima para sortear') : _questionToDisplay,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_currentWordNormal != null)
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: Colors.blue, size: 28),
                        tooltip: t("Falar"),
                        onPressed: () => _falar(
                          _questionToDisplay,
                          forceNative: _isFreeStudy || _isReversedNormal,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _answerCtrl,
                  enabled: _currentWordNormal != null && !_hasAnsweredNormal,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verifyAnswerNormal(),
                  decoration: InputDecoration(
                    labelText: inputLabel,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() {}),
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: (_currentWordNormal == null || _answerCtrl.text.trim().isEmpty || _hasAnsweredNormal)
                          ? null
                          : _verifyAnswerNormal,
                      child: Text(t('Confirmar Resposta')),
                    ),
                    if (_hasAnsweredNormal && (!appAutoNext.value || _hasPeekedNormal))
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(t('Próximo')),
                        onPressed: _drawWordNormal,
                      ),
                    if (_hasAnsweredNormal && _lastAnswerWasWrongNormal && !_hasPeekedNormal && _currentWordNormal != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.gavel, color: Colors.orange, size: 18),
                        label: Text(t('Reivindicar Resposta')),
                        onPressed: () {
                          _abrirDialogoReivindicacao(
                            wordIngles: _currentWordNormal!['ingles'].toString(),
                            currentMeaningsDisplay: _validAnswersNormal.join(' / '),
                            userTypedAnswer: _answerCtrl.text.trim(),
                            allowAddingMeaningToDb: !_isReversedNormal,
                            onClaimedSuccess: () async {
                              final int token = ++_normalTimerToken;
                              setState(() {
                                _lastAnswerWasWrongNormal = false;
                                _resultTextNormal = t('Resposta reivindicada com sucesso! 🎉');
                                _resultColorNormal = Colors.green;
                              });
                              if (appAutoNext.value) {
                                await Future.delayed(const Duration(milliseconds: 1800));
                                if (mounted && _normalTimerToken == token) {
                                  _drawWordNormal();
                                }
                              }
                            },
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _resultTextNormal,
                  style: TextStyle(fontSize: 18, color: _resultColorNormal, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (_currentWordNormal == null && _resultTextNormal == t('Sua biblioteca está vazia!'))
                  _buildEmptyLibraryActionButton(),
                const SizedBox(height: 10),
                if (_resultTextNormal.isNotEmpty && imgFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(imgFile, height: 160, fit: BoxFit.contain),
                  ),
              ],
            ),
          ),
        ),
        _buildMinimalArrow(
          Icons.keyboard_arrow_up,
          t("Modo Papagaio"),
              () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
        ),
      ],
    );
  }

  // ==========================================
  // UI: 2. MODO PAPAGAIO
  // ==========================================
  Widget _buildParrotPractice() {
    final nextTitle = _isFreeStudy ? t("Desafio Visual") : t("Língua Afiada");

    return Column(
      children: [
        _buildMinimalArrow(
          Icons.keyboard_arrow_down,
          t("Modo Clássico"),
              () => _pageController.animateToPage(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🦜', style: TextStyle(fontSize: 30)),
                    const SizedBox(width: 10),
                    Text(t('Modo Papagaio'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
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
                                DropdownButtonFormField<String>(
                                  key: ValueKey(_parrotFilter),
                                  decoration: InputDecoration(
                                    labelText: t('Filtro de Palavras'),
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                                  ),
                                  initialValue: _parrotFilter,
                                  items: [
                                    DropdownMenuItem(value: 'todas', child: Text(t("Todas as palavras"))),
                                    DropdownMenuItem(value: '10', child: Text(t("Últimas 10"))),
                                    DropdownMenuItem(value: '20', child: Text(t("Últimas 20"))),
                                    DropdownMenuItem(value: '30', child: Text(t("Últimas 30"))),
                                    DropdownMenuItem(value: 'custom', child: Text(t("Personalizado"))),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _parrotFilter = v!);
                                    _saveSettings();
                                  },
                                ),
                                if (_parrotFilter == 'custom')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: TextField(
                                      controller: _parrotCustomCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: t('Nº Personalizado (> 0)'),
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<double>(
                                  key: ValueKey(_parrotSpeed),
                                  decoration: InputDecoration(
                                    labelText: t('Velocidade da Voz'),
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                                  ),
                                  initialValue: _parrotSpeed,
                                  items: [
                                    DropdownMenuItem(value: 0.5, child: Text(t('Lento (0.5x)'))),
                                    DropdownMenuItem(value: 1.0, child: Text(t('Normal (1x)'))),
                                    DropdownMenuItem(value: 1.5, child: Text(t('Rápido (1.5x)'))),
                                    DropdownMenuItem(value: 2.0, child: Text(t('Turbo (2x)'))),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _parrotSpeed = v!);
                                    _saveSettings();
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  key: ValueKey(_parrotMode),
                                  decoration: InputDecoration(
                                    labelText: t('Modo de Repetição'),
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                                  ),
                                  initialValue: _parrotMode,
                                  items: [
                                    DropdownMenuItem(value: 'loop', child: Text("🔁 ${t('Em Loop (Sorteio Infinito)')}")),
                                    DropdownMenuItem(value: 'single', child: Text("➡️ ${t('1 Sequência (Parar no fim)')}")),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _parrotMode = v!);
                                    _saveSettings();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        Text(
                          _parrotCurrentWordDisplay.isEmpty ? t('Pronto para voar!') : _parrotCurrentWordDisplay,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                        if (_parrotCurrentWordDisplay == t('Sua biblioteca está vazia!'))
                          _buildEmptyLibraryActionButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _isParrotPlaying ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                    onPressed: _toggleParrot,
                    icon: Icon(_isParrotPlaying ? Icons.stop : Icons.play_arrow, size: 26),
                    label: Text(
                      _isParrotPlaying ? t("Parar Papagaio") : t("Iniciar Papagaio"),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildMinimalArrow(
          Icons.keyboard_arrow_up,
          nextTitle,
              () => _pageController.animateToPage(2, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
        ),
      ],
    );
  }

  // ==========================================
  // UI: 3. LÍNGUA AFIADA / ESCRITA AFIADA (Apenas Idiomas)
  // ==========================================
  Widget _buildSharpPractice() {
    return Column(
      children: [
        _buildMinimalArrow(
          Icons.keyboard_arrow_down,
          t("Modo Papagaio"),
              () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          _isSharpWriting ? t("Escrita Afiada") : t("Língua Afiada"),
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.sync_alt, color: Colors.blue, size: 20),
                          tooltip: t("Inverter Modo"),
                          onPressed: () {
                            setState(() {
                              _isSharpWriting = !_isSharpWriting;
                            });
                            _drawWordSharp();
                          },
                        ),
                        if (_isSharpWriting)
                          IconButton(
                            icon: Icon(
                              _hasPeekedSharp ? Icons.visibility : Icons.visibility_outlined,
                              color: (_currentWordSharp != null && !_hasAnsweredSharp)
                                  ? Colors.deepPurple
                                  : Colors.grey,
                              size: 22,
                            ),
                            tooltip: t("Espiar Resposta"),
                            onPressed: (_currentWordSharp != null && !_hasAnsweredSharp)
                                ? _peekAnswerSharp
                                : null,
                          ),
                      ],
                    ),
                    Text(
                      "🔥 $_streak",
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_isSharpWriting ? '✍️' : '🗡️', style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 10),
                    Text(
                      _isSharpWriting ? t('Escrita Afiada') : t('Língua Afiada'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 15),
                DropdownButtonFormField<String>(
                  key: ValueKey(_sharpFilter),
                  decoration: InputDecoration(
                    labelText: t('Filtro de Sorteio (Global)'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    isDense: true,
                  ),
                  initialValue: _sharpFilter,
                  items: [
                    DropdownMenuItem(value: 'todas', child: Text(t("Todas as palavras"))),
                    DropdownMenuItem(value: '10', child: Text(t("Últimas 10"))),
                    DropdownMenuItem(value: '20', child: Text(t("Últimas 20"))),
                    DropdownMenuItem(value: '30', child: Text(t("Últimas 30"))),
                    DropdownMenuItem(value: 'custom', child: Text(t("Personalizado"))),
                  ],
                  onChanged: (v) {
                    setState(() => _sharpFilter = v!);
                    _saveSettings();
                  },
                ),
                if (_sharpFilter == 'custom')
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: _sharpCustomCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t('Nº Personalizado (> 0)'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.shuffle),
                  label: Text(t('Sortear Nova Palavra')),
                  onPressed: _drawWordSharp,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _currentWordSharp?['ingles'] ?? t('Sorteie para começar'),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: (_isSharpWriting && !_hasPeekedSharp) ? Colors.transparent : null,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_currentWordSharp != null)
                      IconButton(
                        icon: const Icon(Icons.volume_up, color: Colors.blue, size: 45),
                        tooltip: t("Falar"),
                        onPressed: () => _falar(_currentWordSharp!['ingles']),
                      ),
                  ],
                ),
                if (_currentWordSharp != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _currentWordSharp!['traducoes'].toString().replaceAll('|', ' ${t('ou')} '),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 30),
                Text(
                  _sharpResultText,
                  style: TextStyle(fontSize: 18, color: _sharpResultColor, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (_currentWordSharp == null && _sharpResultText == t('Sua biblioteca está vazia!'))
                  _buildEmptyLibraryActionButton(),
                const SizedBox(height: 20),
                if (!_isSharpWriting) ...[
                  GestureDetector(
                    onTap: (_currentWordSharp == null || _hasAnsweredSharp) ? null : _listenSharp,
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: (_currentWordSharp == null || _hasAnsweredSharp)
                          ? Colors.grey.shade300
                          : (_isListening ? Colors.red : Colors.blue),
                      child: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 35, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isListening ? t("A escutar... Fale agora!") : (_currentWordSharp == null ? "" : t("Toque para falar")),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (_hasAnsweredSharp && !appAutoNext.value) ...[
                    const SizedBox(height: 15),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(t('Próximo')),
                      onPressed: _drawWordSharp,
                    ),
                  ],
                  const SizedBox(height: 20),
                ] else ...[
                  TextField(
                    controller: _sharpAnswerCtrl,
                    enabled: _currentWordSharp != null && !_hasAnsweredSharp,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _verifyAnswerSharpWriting(),
                    decoration: InputDecoration(
                      labelText: t('Digite o que ouviu'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() {}),
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: (_currentWordSharp == null || _sharpAnswerCtrl.text.trim().isEmpty || _hasAnsweredSharp)
                            ? null
                            : _verifyAnswerSharpWriting,
                        child: Text(t('Confirmar Resposta')),
                      ),
                      if (_hasAnsweredSharp && (!appAutoNext.value || _hasPeekedSharp))
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(t('Próximo')),
                          onPressed: _drawWordSharp,
                        ),
                      if (_hasAnsweredSharp && _lastAnswerWasWrongSharp && !_hasPeekedSharp && _currentWordSharp != null)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.gavel, color: Colors.orange, size: 18),
                          label: Text(t('Reivindicar Resposta')),
                          onPressed: () {
                            _abrirDialogoReivindicacao(
                              wordIngles: _currentWordSharp!['ingles'].toString(),
                              currentMeaningsDisplay: _currentWordSharp!['traducoes'].toString().replaceAll('|', ' / '),
                              userTypedAnswer: _sharpAnswerCtrl.text.trim(),
                              allowAddingMeaningToDb: false,
                              onClaimedSuccess: () async {
                                final int token = ++_sharpTimerToken;
                                setState(() {
                                  _lastAnswerWasWrongSharp = false;
                                  _sharpResultText = t('Resposta reivindicada com sucesso! 🎉');
                                  _sharpResultColor = Colors.green;
                                });
                                if (appAutoNext.value) {
                                  await Future.delayed(const Duration(milliseconds: 1800));
                                  if (mounted && _sharpTimerToken == token) {
                                    _drawWordSharp();
                                  }
                                }
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        _buildMinimalArrow(
          Icons.keyboard_arrow_up,
          t("Desafio Visual"),
              () => _pageController.animateToPage(3, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
        ),
      ],
    );
  }

  // ==========================================
  // UI: 4. DESAFIO VISUAL (SORTEIO DE IMAGEM)
  // ==========================================
  Widget _buildImagePractice() {
    final int prevPageIndex = _isFreeStudy ? 1 : 2;
    final String prevPageTitle = _isFreeStudy ? t("Modo Papagaio") : t("Língua Afiada");
    final int nextPageIndex = _isFreeStudy ? 3 : 4;

    final File? imgFile = DatabaseHelper.instance.getImageFile(_currentWordImage?['imagem']?.toString());

    String fieldLabel;
    if (!_isFreeStudy) {
      fieldLabel = "${t('Responder em')} $_displayTopic";
    } else {
      fieldLabel = _imageAskExplanationInFreeMode ? t('Sua Explicação') : t('Qual é o Objeto de Estudo?');
    }

    return Column(
      children: [
        _buildMinimalArrow(
          Icons.keyboard_arrow_down,
          prevPageTitle,
              () => _pageController.animateToPage(
            prevPageIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('🖼️', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Text(
                          t("Desafio Visual"),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(
                            _hasPeekedImage ? Icons.visibility : Icons.visibility_outlined,
                            color: (_currentWordImage != null && !_hasAnsweredImage)
                                ? Colors.deepPurple
                                : Colors.grey,
                            size: 22,
                          ),
                          tooltip: t("Espiar Resposta"),
                          onPressed: (_currentWordImage != null && !_hasAnsweredImage)
                              ? _peekAnswerImage
                              : null,
                        ),
                      ],
                    ),
                    Text(
                      "🔥 $_streak",
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
                const Divider(height: 15),

                if (_isFreeStudy) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: Text(
                        _imageAskExplanationInFreeMode
                            ? t("Responder: Explicação")
                            : t("Responder: Objeto de Estudo"),
                      ),
                      onPressed: () {
                        setState(() {
                          _imageAskExplanationInFreeMode = !_imageAskExplanationInFreeMode;
                          _updateValidImageAnswers();
                        });
                      },
                    ),
                  ),
                ],

                FilledButton.icon(
                  icon: const Icon(Icons.image_search),
                  label: Text(t('Sortear Imagem')),
                  onPressed: _drawWordImage,
                ),
                const SizedBox(height: 20),

                if (imgFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      imgFile,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _imageResultText.isNotEmpty ? _imageResultText : t('Clique acima para sortear'),
                          style: TextStyle(
                            fontSize: 16,
                            color: _imageResultText.isNotEmpty ? _imageResultColor : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_imageResultText.isNotEmpty) _buildEmptyLibraryActionButton(),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
                TextField(
                  controller: _imageAnswerCtrl,
                  enabled: _currentWordImage != null && !_hasAnsweredImage,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verifyAnswerImage(),
                  decoration: InputDecoration(
                    labelText: fieldLabel,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() {}),
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: (_currentWordImage == null || _imageAnswerCtrl.text.trim().isEmpty || _hasAnsweredImage)
                          ? null
                          : _verifyAnswerImage,
                      child: Text(t('Confirmar Resposta')),
                    ),
                    if (_hasAnsweredImage && (!appAutoNext.value || _hasPeekedImage))
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(t('Próximo')),
                        onPressed: _drawWordImage,
                      ),
                    if (_hasAnsweredImage && _lastAnswerWasWrongImage && !_hasPeekedImage && _currentWordImage != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.gavel, color: Colors.orange, size: 18),
                        label: Text(t('Reivindicar Resposta')),
                        onPressed: () {
                          _abrirDialogoReivindicacao(
                            wordIngles: _currentWordImage!['ingles'].toString(),
                            currentMeaningsDisplay: _validAnswersImage.join(' / '),
                            userTypedAnswer: _imageAnswerCtrl.text.trim(),
                            allowAddingMeaningToDb: _isFreeStudy && _imageAskExplanationInFreeMode,
                            onClaimedSuccess: () async {
                              final int token = ++_imageTimerToken;
                              setState(() {
                                _lastAnswerWasWrongImage = false;
                                _imageResultText = t('Resposta reivindicada com sucesso! 🎉');
                                _imageResultColor = Colors.green;
                              });
                              if (appAutoNext.value) {
                                await Future.delayed(const Duration(milliseconds: 1800));
                                if (mounted && _imageTimerToken == token) {
                                  _drawWordImage();
                                }
                              }
                            },
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_currentWordImage != null && _imageResultText.isNotEmpty) ...[
                  Text(
                    _imageResultText,
                    style: TextStyle(fontSize: 18, color: _imageResultColor, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${_currentWordImage!['ingles']} — ${_currentWordImage!['traducoes'].toString().replaceAll('|', ' / ')}",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        _buildMinimalArrow(
          Icons.keyboard_arrow_up,
          t("Desempenho"),
              () => _pageController.animateToPage(
            nextPageIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // UI: 5. DESEMPENHO
  // ==========================================
  Widget _buildDesempenhoPractice() {
    final int prevPageIndex = _isFreeStudy ? 2 : 3;

    return Column(
      children: [
        _buildMinimalArrow(
          Icons.keyboard_arrow_down,
          t("Desafio Visual"),
              () => _pageController.animateToPage(
            prevPageIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: Future.wait([
              DatabaseHelper.instance.getEstatisticasHoje(),
              DatabaseHelper.instance.getEstatisticasSemana(),
              DatabaseHelper.instance.getHistoricoMensal(),
            ]),
            builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                return Center(child: Text(t("Nenhuma atividade."), style: const TextStyle(color: Colors.grey)));
              }

              final hoje = snapshot.data![0] as Map<String, dynamic>? ?? {};
              final semana = snapshot.data![1] as Map<String, dynamic>? ?? {};
              final meses = snapshot.data![2] as List<Map<String, dynamic>>? ?? [];

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📈', style: TextStyle(fontSize: 30)),
                        const SizedBox(width: 10),
                        Text(t('Seu Desempenho'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 15),
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t("Desempenho de Hoje"),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t("Perguntas Respondidas:")),
                                Text("${hoje['respondidas'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t("Acertos / Erros:")),
                                Text(
                                  "${hoje['acertos'] ?? 0} / ${hoje['erros'] ?? 0}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t("Combos Especiais 🎉:")),
                                Text(
                                  "${hoje['especiais'] ?? 0}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t("Tempo no Papagaio 🦜:")),
                                Text(
                                  _formatTime(hoje['tempo_papagaio'] ?? 0),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
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
                            Text(
                              t("Últimos 7 Dias"),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t("Perguntas Respondidas:")),
                                Text(
                                  "${semana['respondidas'] ?? 0}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t("Acertos / Erros:")),
                                Text(
                                  "${semana['acertos'] ?? 0} / ${semana['erros'] ?? 0}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t("Combos Especiais 🎉:")),
                                Text(
                                  "${semana['especiais'] ?? 0}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t("Tempo no Papagaio 🦜:")),
                                Text(
                                  _formatTime(semana['tempo_papagaio'] ?? 0),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        " ${t('Histórico Mensal')}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
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
                            subtitle: Text(
                              "${t('Perguntas Respondidas:')} ${mes['respondidas'] ?? 0} | ${t('Acertos / Erros:')} ${mes['acertos'] ?? 0}\n${t('Combos Especiais 🎉:')} ${mes['especiais'] ?? 0} | ${t('Tempo no Papagaio 🦜:')} ${_formatTime(mes['tempo_papagaio'] ?? 0)}",
                            ),
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