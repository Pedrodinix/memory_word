import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:translator/translator.dart' as tr;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:math';

import '../main.dart';
import '../banco_de_dados/database_helper.dart';

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

  @override
  void dispose() {
    _inglesCtrl.dispose();
    _traducaoCtrl.dispose();
    _flutterTts.stop();
    super.dispose();
  }

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
      String targetLangCode = supportedLanguages[appNativeLanguage.value]!.transCode;
      final translation = await translator.translate(_inglesCtrl.text.trim(), from: langData.transCode, to: targetLangCode);
      setState(() => _traducaoCtrl.text = translation.text);
    } catch (_) {}
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
    } catch (_) {}
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
              Expanded(child: TextField(
                  controller: _inglesCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: "${t('Palavra em')} ${t(widget.currentLang)}", border: const OutlineInputBorder())
              )),
              IconButton(icon: const Icon(Icons.volume_up, color: Colors.blue), tooltip: t("Falar"), onPressed: () => _falar(_inglesCtrl.text.trim())),
              IconButton(
                icon: _isTranslating
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.g_translate, color: Colors.blue),
                onPressed: _translateWord,
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
              controller: _traducaoCtrl,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveWord(),
              decoration: InputDecoration(labelText: t('Significado / Tradução'), border: const OutlineInputBorder())
          ),
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