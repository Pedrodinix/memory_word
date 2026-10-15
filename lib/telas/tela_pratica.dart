import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:math';

import '../main.dart';
import '../banco_de_dados/database_helper.dart';

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

  // --- MODO CLÁSSICO ---
  Map<String, dynamic>? _currentWordNormal;
  final _answerCtrl = TextEditingController();
  String _resultTextNormal = '';
  Color _resultColorNormal = Colors.black;
  bool _hasAnsweredNormal = false;
  bool _isReversedNormal = false;
  List<Map<String, dynamic>> _allFetchedWordsNormal = [];
  String _questionToDisplay = '';
  List<String> _validAnswersNormal = [];

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
  bool _isSharpWriting = false;
  final _sharpAnswerCtrl = TextEditingController();

  // --- MODO DESAFIO VISUAL (Sorteio de Imagem - Idiomas e Estudo Livre) ---
  Map<String, dynamic>? _currentWordImage;
  final _imageAnswerCtrl = TextEditingController();
  String _imageResultText = '';
  Color _imageResultColor = Colors.black;
  bool _hasAnsweredImage = false;
  // No Estudo Livre, define se o usuário quer digitar o Objeto (false) ou a Explicação (true)
  bool _imageAskExplanationInFreeMode = false;
  List<String> _validAnswersImage = [];

  bool get _isFreeStudy => isCustomStudy(widget.currentLang);
  String get _displayTopic => getStudyDisplayName(widget.currentLang);

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadSettings();
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

  @override
  void didUpdateWidget(PracticeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLang != widget.currentLang) {
      if (_isParrotPlaying) _stopParrot();
      _currentWordNormal = null;
      _answerCtrl.clear();
      _resultTextNormal = '';
      _hasAnsweredNormal = false;
      _questionToDisplay = '';

      _currentWordSharp = null;
      _sharpResultText = '';
      _spokenText = '';
      _hasAnsweredSharp = false;
      _sharpAnswerCtrl.clear();

      _currentWordImage = null;
      _imageAnswerCtrl.clear();
      _imageResultText = '';
      _hasAnsweredImage = false;

      _streak = 0;
      _nextMilestone = 10;

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
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
    _sharpAnswerCtrl.dispose();
    _imageAnswerCtrl.dispose();
    super.dispose();
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
      _streak++;
      if (_streak == _nextMilestone) {
        DatabaseHelper.instance.registrarAtividade('especiais');
        _triggerSpecialOverlay(_nextMilestone);
        _nextMilestone = _nextMilestone < 30 ? _nextMilestone + 10 : _nextMilestone * 2;
      } else {
        _playCorrectSound();
      }
    } else {
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
  // LÓGICA: MODO CLÁSSICO
  // ==========================================
  Future<void> _drawWordNormal() async {
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

      if (!_isReversedNormal) {
        _questionToDisplay = _currentWordNormal!['ingles'];
        _validAnswersNormal = _currentWordNormal!['traducoes']
            .toString()
            .split('|')
            .map((e) => e.trim().toLowerCase())
            .toList();
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
    if (_currentWordNormal == null || _answerCtrl.text.trim().isEmpty || _hasAnsweredNormal) return;

    setState(() {
      _hasAnsweredNormal = true;
    });
    final userAnswer = _answerCtrl.text.trim().toLowerCase();
    bool acertou = _validAnswersNormal.contains(userAnswer);

    setState(() {
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
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted && _hasAnsweredNormal) {
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
    final words = await DatabaseHelper.instance.fetchCustomWords(widget.currentLang, _sharpFilter, _sharpCustomVal);
    if (!mounted) return;
    if (words.isEmpty) {
      setState(() {
        _sharpResultText = t('Nenhuma palavra encontrada.');
        _sharpResultColor = Colors.blue;
      });
      return;
    }
    setState(() {
      _currentWordSharp = words[Random().nextInt(words.length)];
      _sharpResultText = '';
      _spokenText = '';
      _hasAnsweredSharp = false;
      _sharpAnswerCtrl.clear();
    });
    _falar(_currentWordSharp!['ingles']);
  }

  void _listenSharp() async {
    if (_hasAnsweredSharp) return;

    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'notListening' || val == 'done') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (available) {
        setState(() => _isListening = true);
        AppLanguage langData = supportedLanguages[widget.currentLang] ?? supportedLanguages['Inglês']!;
        _speech.listen(
          onResult: (val) {
            setState(() {
              _spokenText = val.recognizedWords;
              if (val.hasConfidenceRating && val.confidence > 0) _verifySpeech();
            });
          },
          listenOptions: stt.SpeechListenOptions(localeId: langData.ttsCode),
        );
      } else {
        setState(() => _isListening = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('Reconhecimento indisponível no telemóvel.'))),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _verifySpeech();
    }
  }

  void _verifySpeech() async {
    if (_currentWordSharp == null || _spokenText.isEmpty || _hasAnsweredSharp) return;

    setState(() {
      _hasAnsweredSharp = true;
    });
    String target = _currentWordSharp!['ingles'].toString().toLowerCase().trim();
    String spoken = _spokenText.toLowerCase().trim();

    bool acertou = (spoken == target || spoken.contains(target) || target.contains(spoken));
    setState(() {
      if (acertou) {
        _sharpResultText = t('Pronúncia Perfeita! 🎉');
        _sharpResultColor = Colors.green;
      } else {
        _sharpResultText = '${t('Entendemos:')} "$spoken"';
        _sharpResultColor = Colors.red;
      }
    });

    _handleAnswer(acertou, _currentWordSharp!['ingles']);
    if (appAutoNext.value) {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted && _hasAnsweredSharp) {
        _drawWordSharp();
      }
    }
  }

  void _verifyAnswerSharpWriting() async {
    if (_currentWordSharp == null || _sharpAnswerCtrl.text.trim().isEmpty || _hasAnsweredSharp) return;

    setState(() {
      _hasAnsweredSharp = true;
    });
    String target = _currentWordSharp!['ingles'].toString().toLowerCase().trim();
    String userAnswer = _sharpAnswerCtrl.text.toLowerCase().trim();

    bool acertou = (target == userAnswer);
    setState(() {
      if (acertou) {
        _sharpResultText = t('Escrita Perfeita! 🎉');
        _sharpResultColor = Colors.green;
      } else {
        _sharpResultText = '${t('Incorreta. O correto é:')} $target';
        _sharpResultColor = Colors.red;
      }
    });

    _handleAnswer(acertou, _currentWordSharp!['ingles']);
    if (appAutoNext.value) {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted && _hasAnsweredSharp) {
        _drawWordSharp();
      }
    }
  }

  // ==========================================
  // LÓGICA: DESAFIO VISUAL (SORTEIO DE IMAGEM)
  // ==========================================
  Future<void> _drawWordImage() async {
    final db = DatabaseHelper.instance;
    final filtroGlobal = await db.getConfig('filtro');
    final customGlobal = await db.getConfig('custom_val');
    final allWords = await db.fetchCustomWords(
      widget.currentLang,
      filtroGlobal.isEmpty ? 'todas' : filtroGlobal,
      customGlobal,
    );

    // Filtra apenas itens que possuem arquivo de imagem válido salvo no dispositivo
    final wordsWithImages = allWords.where((w) {
      final p = w['imagem']?.toString() ?? '';
      return p.isNotEmpty && File(p).existsSync();
    }).toList();

    if (!mounted) return;
    if (wordsWithImages.isEmpty) {
      setState(() {
        _currentWordImage = null;
        _imageResultText = t(
          'Nenhum item com imagem encontrado nesta biblioteca! Adicione fotos aos seus registos para usar este modo.',
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
      _updateValidImageAnswers();
    });
  }

  void _updateValidImageAnswers() {
    if (_currentWordImage == null) return;
    if (!_isFreeStudy) {
      // No modo de Idiomas, o usuário vê a imagem e responde a palavra no idioma de estudo
      _validAnswersImage = [_currentWordImage!['ingles'].toString().trim().toLowerCase()];
    } else {
      // No modo de Estudo Livre, responde o Objeto de Estudo ou a Explicação conforme o seletor
      if (!_imageAskExplanationInFreeMode) {
        _validAnswersImage = [_currentWordImage!['ingles'].toString().trim().toLowerCase()];
      } else {
        _validAnswersImage = _currentWordImage!['traducoes']
            .toString()
            .split('|')
            .map((e) => e.trim().toLowerCase())
            .toList();
      }
    }
  }

  void _verifyAnswerImage() async {
    if (_currentWordImage == null || _imageAnswerCtrl.text.trim().isEmpty || _hasAnsweredImage) return;

    setState(() {
      _hasAnsweredImage = true;
    });

    final userAnswer = _imageAnswerCtrl.text.trim().toLowerCase();
    bool acertou = _validAnswersImage.contains(userAnswer);

    // No Estudo Livre, se o usuário digitou exatamente a explicação ou o objeto, também mostramos feedback claro
    setState(() {
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
      await Future.delayed(const Duration(milliseconds: 2500));
      if (mounted && _hasAnsweredImage) {
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
    final imgPath = _currentWordNormal?['imagem']?.toString() ?? '';
    final hasValidImage = imgPath.isNotEmpty && File(imgPath).existsSync();

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
                const SizedBox(height: 30),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: (_currentWordNormal == null || _answerCtrl.text.trim().isEmpty || _hasAnsweredNormal)
                          ? null
                          : _verifyAnswerNormal,
                      child: Text(t('Confirmar Resposta')),
                    ),
                    if (_hasAnsweredNormal && !appAutoNext.value) ...[
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(t('Próximo')),
                        onPressed: _drawWordNormal,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _resultTextNormal,
                  style: TextStyle(fontSize: 18, color: _resultColorNormal, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                if (_resultTextNormal.isNotEmpty && hasValidImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(imgPath), height: 160, fit: BoxFit.contain),
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
                          color: _isSharpWriting ? Colors.transparent : null,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: (_currentWordSharp == null || _sharpAnswerCtrl.text.trim().isEmpty || _hasAnsweredSharp)
                            ? null
                            : _verifyAnswerSharpWriting,
                        child: Text(t('Confirmar Resposta')),
                      ),
                      if (_hasAnsweredSharp && !appAutoNext.value) ...[
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(t('Próximo')),
                          onPressed: _drawWordSharp,
                        ),
                      ],
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

    final imgPath = _currentWordImage?['imagem']?.toString() ?? '';
    final hasValidImage = imgPath.isNotEmpty && File(imgPath).existsSync();

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

                if (hasValidImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(imgPath),
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _imageResultText.isNotEmpty ? _imageResultText : t('Clique acima para sortear'),
                          style: TextStyle(
                            fontSize: 16,
                            color: _imageResultText.isNotEmpty ? _imageResultColor : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: (_currentWordImage == null || _imageAnswerCtrl.text.trim().isEmpty || _hasAnsweredImage)
                          ? null
                          : _verifyAnswerImage,
                      child: Text(t('Confirmar Resposta')),
                    ),
                    if (_hasAnsweredImage && !appAutoNext.value) ...[
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(t('Próximo')),
                        onPressed: _drawWordImage,
                      ),
                    ],
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