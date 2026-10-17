import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';

import '../main.dart';
import '../banco_de_dados/database_helper.dart';
import 'tela_tutorial.dart';

class RegisterTab extends StatefulWidget {
  final String currentLang;
  const RegisterTab({super.key, required this.currentLang});

  @override
  State<RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<RegisterTab> {
  final _inglesCtrl = TextEditingController();
  final _traducaoCtrl = TextEditingController();
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  final GoogleTranslator _translator = GoogleTranslator();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isTranslating = false;

  bool get _isFreeStudy => isCustomStudy(widget.currentLang);
  String get _displayTopic => getStudyDisplayName(widget.currentLang);

  @override
  void dispose() {
    _flutterTts.stop();
    _inglesCtrl.dispose();
    _traducaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _falarPalavra() async {
    final texto = _inglesCtrl.text.trim();
    if (texto.isEmpty) return;

    AppLanguage langData = _isFreeStudy
        ? (supportedLanguages[appNativeLanguage.value] ?? supportedLanguages['Português']!)
        : (supportedLanguages[widget.currentLang] ?? supportedLanguages['Inglês']!);

    await _flutterTts.setLanguage(langData.ttsCode);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.speak(texto);
  }

  Future<void> _autoTraduzir() async {
    if (_isFreeStudy || _inglesCtrl.text.trim().isEmpty) return;

    setState(() => _isTranslating = true);
    try {
      String fromCode = supportedLanguages[widget.currentLang]?.transCode ?? 'en';
      String toCode = supportedLanguages[appNativeLanguage.value]?.transCode ?? 'pt';

      if (fromCode == toCode) {
        if (mounted) setState(() => _isTranslating = false);
        return;
      }

      var translation = await _translator
          .translate(_inglesCtrl.text.trim(), from: fromCode, to: toCode)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _traducaoCtrl.text = translation.text;
      });
    } catch (_) {
      // Se estiver offline, o utilizador pode digitar manualmente sem bloqueios
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      final String savedFileName = await DatabaseHelper.instance.saveImageToAppDirectory(pickedFile.path);
      if (!mounted) return;
      setState(() => _imagePath = savedFileName);
    }
  }

  Future<void> _saveWord() async {
    final inglesText = _inglesCtrl.text.trim();
    final traducaoText = _traducaoCtrl.text.trim();

    if (inglesText.isEmpty || traducaoText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFreeStudy
                ? t('Preencha o objeto de estudo e a explicação antes de salvar.')
                : t('Preencha a palavra e a tradução antes de salvar.'),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    try {
      final db = DatabaseHelper.instance;
      final existing = await db.fetchMeanings(inglesText, widget.currentLang);
      int errosExistentes = 0;

      if (existing.isNotEmpty) {
        errosExistentes = existing.first['erros'] ?? 0;
        if (!mounted) return;
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(_isFreeStudy ? t("Objeto Existente") : t("Palavra Existente")),
            content: Text(
              _isFreeStudy
                  ? t("Este objeto de estudo já existe nesta biblioteca. Deseja adicionar uma nova explicação a ele?")
                  : t("Esta palavra já existe na biblioteca desta língua. Deseja adicionar este novo significado a ela?"),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t("Cancelar"))),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t("Sim"))),
            ],
          ),
        );
        if (confirm != true) return;
      }

      await db.insertWord({
        'ingles': inglesText,
        'traducao': traducaoText,
        'imagem': _imagePath ?? '',
        'lingua': widget.currentLang,
        'erros': errosExistentes,
        'oculto': 0,
      });

      await db.registrarAtividade('registradas', 1);
      agendarVerificacaoDeProgressoRecente();

      _inglesCtrl.clear();
      _traducaoCtrl.clear();
      setState(() => _imagePath = null);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFreeStudy ? t('Objeto de estudo salvo com sucesso!') : t('Palavra salva com sucesso!'),
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final File? previewFile = DatabaseHelper.instance.getImageFile(_imagePath);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Text(
            _isFreeStudy
                ? "${t('Registrar Objeto de Estudo')} ($_displayTopic)"
                : "${t('Registrar Palavra')} ($_displayTopic)",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _inglesCtrl,
            decoration: InputDecoration(
              labelText: _isFreeStudy
                  ? t('Objeto de Estudo / Conceito')
                  : "${t('Palavra em')} $_displayTopic",
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.blue),
                    tooltip: t("Falar"),
                    onPressed: _falarPalavra,
                  ),
                  if (!_isFreeStudy)
                    _isTranslating
                        ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                        : IconButton(
                      icon: const Icon(Icons.g_translate, color: Colors.blue),
                      tooltip: t("Significado / Tradução"),
                      onPressed: _autoTraduzir,
                    ),
                ],
              ),
            ),
            onSubmitted: (_) {
              if (!_isFreeStudy) _autoTraduzir();
            },
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _traducaoCtrl,
            maxLines: _isFreeStudy ? 3 : 1,
            minLines: 1,
            decoration: InputDecoration(
              labelText: _isFreeStudy
                  ? t('Explicação / Definição')
                  : "${t('Significado / Tradução')} (${t(appNativeLanguage.value)})",
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: Text(t('Câmera')),
                onPressed: () => _pickImage(ImageSource.camera),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: Text(t('Galeria')),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
          if (previewFile != null) ...[
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(previewFile, height: 150, fit: BoxFit.contain),
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete, color: Colors.red),
              label: Text(t("Remover Foto"), style: const TextStyle(color: Colors.red)),
              onPressed: () => setState(() => _imagePath = null),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _saveWord,
              child: Text(t('Confirmar')),
            ),
          ),
        ],
      ),
    );
  }
}