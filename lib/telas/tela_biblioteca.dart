import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:math';

import '../main.dart';
import '../banco_de_dados/database_helper.dart';

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

  bool get _isFreeStudy => isCustomStudy(widget.currentLang);
  String get _displayTopic => getStudyDisplayName(widget.currentLang);

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void didUpdateWidget(LibraryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLang != widget.currentLang) {
      _searchCtrl.clear();
      _loadWords();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWords([String query = '']) async {
    final words = await DatabaseHelper.instance.fetchDistinctWords(widget.currentLang, query);
    final totalWords = await DatabaseHelper.instance.fetchDistinctWords(widget.currentLang, '');
    if (!mounted) return;
    setState(() {
      _distinctWords = words;
      _totalWordsCount = totalWords.length;
    });
  }

  void _abrirDetalhes(String ingles) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordDetailsScreen(ingles: ingles, currentLang: widget.currentLang),
      ),
    );
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
              Flexible(
                child: Text(
                  "${t('Biblioteca')} ($_displayTopic)",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text("($_totalWordsCount ${t('registradas')})", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: t('Pesquisar...'),
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => _loadWords(value),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _distinctWords.isEmpty
                ? Center(child: Text(t("Nenhuma palavra encontrada."), style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
              itemCount: _distinctWords.length,
              itemBuilder: (context, index) {
                final word = _distinctWords[index];
                final imgPath = word['imagem']?.toString() ?? '';
                final hasImage = imgPath.isNotEmpty && File(imgPath).existsSync();

                int erros = word['erros'] ?? 0;
                Color dotColor = erros >= 5 ? Colors.red : (erros >= 3 ? Colors.amber : Colors.green);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: hasImage
                        ? CircleAvatar(backgroundImage: FileImage(File(imgPath)))
                        : CircleAvatar(child: Icon(_isFreeStudy ? Icons.menu_book : Icons.text_fields)),
                    title: Text(word['ingles'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text(
                      word['traducao'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
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

  bool get _isFreeStudy => isCustomStudy(widget.currentLang);

  @override
  void initState() {
    super.initState();
    _loadMeanings();
  }

  Future<void> _loadMeanings() async {
    final res = await DatabaseHelper.instance.fetchMeanings(widget.ingles, widget.currentLang);
    if (!mounted) return;
    setState(() => _meanings = res);
  }

  void _irParaEdicao() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditWordScreen(ingles: widget.ingles, meanings: _meanings, currentLang: widget.currentLang),
      ),
    );
    final res = await DatabaseHelper.instance.fetchMeanings(widget.ingles, widget.currentLang);
    if (!mounted) return;
    if (res.isEmpty) {
      Navigator.pop(context);
    } else {
      setState(() => _meanings = res);
    }
  }

  @override
  Widget build(BuildContext context) {
    int erros = _meanings.isNotEmpty ? (_meanings[0]['erros'] ?? 0) : 0;
    Color difColor = erros >= 5 ? Colors.red : (erros >= 3 ? Colors.amber : Colors.green);
    String difText = erros >= 5 ? t("Ruim (Vermelho)") : (erros >= 3 ? t("Médio (Amarelo)") : t("Bom (Verde)"));
    String labelItem = _isFreeStudy ? t('Explicação') : t('Significado');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ingles),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: _isFreeStudy ? t("Editar Objeto") : t("Editar Palavra"),
            onPressed: _irParaEdicao,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: difColor.withValues(alpha: 0.15),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 16, height: 16, decoration: BoxDecoration(color: difColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(
                  "${t('Dificuldade Atual:')} $difText",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: difColor == Colors.amber ? Colors.orange.shade700 : difColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _meanings.length,
              separatorBuilder: (_, _) => const Divider(height: 40),
              itemBuilder: (context, index) {
                final sig = _meanings[index];
                final imgPath = sig['imagem']?.toString() ?? '';
                final hasImg = imgPath.isNotEmpty && File(imgPath).existsSync();

                return Column(
                  children: [
                    Text(
                      "$labelItem ${index + 1}: ${sig['traducao']}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: index > 0 ? Colors.blue : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    if (hasImg)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(imgPath), height: 200, fit: BoxFit.contain),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
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
  int _currentErrors = 0;

  bool get _isFreeStudy => isCustomStudy(widget.currentLang);
  String get _displayTopic => getStudyDisplayName(widget.currentLang);

  @override
  void initState() {
    super.initState();
    _inglesCtrl = TextEditingController(text: widget.ingles);
    if (widget.meanings.isNotEmpty) {
      _currentErrors = widget.meanings[0]['erros'] ?? 0;
    }
    for (var m in widget.meanings) {
      _editMeanings.add({
        'id': m['id'],
        'traducao': TextEditingController(text: m['traducao']),
        'imagem': m['imagem'],
      });
    }
  }

  @override
  void dispose() {
    _inglesCtrl.dispose();
    for (var m in _editMeanings) {
      (m['traducao'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  void _addSignificado() {
    setState(() {
      _editMeanings.add({'id': null, 'traducao': TextEditingController(), 'imagem': ''});
    });
  }

  Future<void> _alterarFoto(int index, ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      final String newPath = path.join(
        (await getApplicationDocumentsDirectory()).path,
        'img_${Random().nextInt(100000)}.jpg',
      );
      final File savedImage = await File(pickedFile.path).copy(newPath);
      if (!mounted) return;
      setState(() => _editMeanings[index]['imagem'] = savedImage.path);
    }
  }

  void _removerSignificado(int index) {
    if (_editMeanings.length <= 1) return;
    setState(() {
      (_editMeanings[index]['traducao'] as TextEditingController).dispose();
      _editMeanings.removeAt(index);
    });
  }

  Future<void> _excluirPalavraToda() async {
    bool? conf = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_isFreeStudy ? t("Excluir Objeto?") : t("Excluir Palavra?")),
        content: Text(
          _isFreeStudy
              ? t("Deseja apagar este objeto de estudo e todas as suas explicações?")
              : t("Deseja apagar esta palavra e TODOS os seus significados nesta língua?"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t("Cancelar"))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: Text(t("Excluir")),
          ),
        ],
      ),
    );

    if (conf == true) {
      await DatabaseHelper.instance.deleteAllMeanings(widget.ingles, widget.currentLang);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _salvarAlteracoes() async {
    if (_inglesCtrl.text.trim().isEmpty) return;

    try {
      final db = DatabaseHelper.instance;
      await db.deleteAllMeanings(widget.ingles, widget.currentLang);

      for (var m in _editMeanings) {
        String tradText = (m['traducao'] as TextEditingController).text.trim();
        if (tradText.isNotEmpty) {
          await db.insertWord({
            'ingles': _inglesCtrl.text.trim(),
            'traducao': tradText,
            'imagem': m['imagem'],
            'lingua': widget.currentLang,
            'erros': _currentErrors,
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Alterações salvas!'))));
      Navigator.pop(context);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    String labelMeaning = _isFreeStudy ? t('Explicação') : t('Significado');

    return Scaffold(
      appBar: AppBar(title: Text(_isFreeStudy ? t("Editar Objeto") : t("Editar Palavra"))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              TextField(
                controller: _inglesCtrl,
                decoration: InputDecoration(
                  labelText: "${_isFreeStudy ? t('Objeto Principal') : t('Palavra Principal')} ($_displayTopic)",
                  border: const OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Text(
                _isFreeStudy ? t("Explicações Registradas:") : t("Significados Registrados:"),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _editMeanings.length,
                  itemBuilder: (context, index) {
                    final m = _editMeanings[index];
                    final imgPath = m['imagem']?.toString() ?? '';
                    final hasImg = imgPath.isNotEmpty && File(imgPath).existsSync();

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
                                    maxLines: _isFreeStudy ? 3 : 1,
                                    minLines: 1,
                                    decoration: InputDecoration(labelText: "$labelMeaning ${index + 1}"),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _removerSignificado(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (hasImg)
                                  Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    child: Image.file(File(imgPath), width: 40, height: 40, fit: BoxFit.cover),
                                  ),
                                TextButton.icon(
                                  icon: const Icon(Icons.image),
                                  label: Text(hasImg ? t("Alterar Foto") : t("Adicionar Foto")),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (_) => SafeArea(
                                        child: Wrap(
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.camera_alt),
                                              title: Text(t('Câmera')),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _alterarFoto(index, ImageSource.camera);
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.photo_library),
                                              title: Text(t('Galeria')),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _alterarFoto(index, ImageSource.gallery);
                                              },
                                            ),
                                            if (hasImg)
                                              ListTile(
                                                leading: const Icon(Icons.delete, color: Colors.red),
                                                title: Text(
                                                  t('Remover Imagem'),
                                                  style: const TextStyle(color: Colors.red),
                                                ),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  setState(() => m['imagem'] = '');
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
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
                  OutlinedButton.icon(
                    onPressed: _addSignificado,
                    icon: const Icon(Icons.add),
                    label: Text(labelMeaning),
                  ),
                  TextButton.icon(
                    onPressed: _excluirPalavraToda,
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: Text(
                      _isFreeStudy ? t("Excluir Objeto") : t("Excluir Palavra"),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
              const Divider(),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: FilledButton.icon(
                  onPressed: _salvarAlteracoes,
                  icon: const Icon(Icons.save),
                  label: Text(t("Salvar Alterações")),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}