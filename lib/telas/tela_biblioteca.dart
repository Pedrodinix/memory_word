import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
              Text(
                "($_totalWordsCount ${t('registradas')})",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
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
                final File? imgFile = DatabaseHelper.instance.getImageFile(word['imagem']?.toString());

                int erros = word['erros'] ?? 0;
                Color dotColor = erros >= 5 ? Colors.red : (erros >= 3 ? Colors.amber : Colors.green);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: imgFile != null
                        ? CircleAvatar(backgroundImage: FileImage(imgFile))
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
  List<Map<String, dynamic>> _allMeanings = [];

  bool get _isFreeStudy => isCustomStudy(widget.currentLang);

  @override
  void initState() {
    super.initState();
    _loadMeanings();
  }

  Future<void> _loadMeanings() async {
    final res = await DatabaseHelper.instance.fetchMeanings(widget.ingles, widget.currentLang);
    if (!mounted) return;
    setState(() => _allMeanings = res);
  }

  void _irParaEdicao() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditWordScreen(
          ingles: widget.ingles,
          meanings: _allMeanings,
          currentLang: widget.currentLang,
        ),
      ),
    );
    final res = await DatabaseHelper.instance.fetchMeanings(widget.ingles, widget.currentLang);
    if (!mounted) return;
    if (res.isEmpty) {
      Navigator.pop(context);
    } else {
      setState(() => _allMeanings = res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleMeanings = _allMeanings.where((m) => (m['oculto'] ?? 0) == 0).toList();
    int erros = _allMeanings.isNotEmpty ? (_allMeanings[0]['erros'] ?? 0) : 0;
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
              itemCount: visibleMeanings.length,
              separatorBuilder: (_, _) => const Divider(height: 40),
              itemBuilder: (context, index) {
                final sig = visibleMeanings[index];
                final File? imgFile = DatabaseHelper.instance.getImageFile(sig['imagem']?.toString());

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
                    if (imgFile != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(imgFile, height: 200, fit: BoxFit.contain),
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
  bool _showHiddenSection = false;

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
      final int isOculto = (m['oculto'] == 1 || m['oculto'] == true) ? 1 : 0;
      if (isOculto == 1) _showHiddenSection = true;
      _editMeanings.add({
        'id': m['id'],
        'traducao': TextEditingController(text: m['traducao']),
        'imagem': m['imagem'] ?? '',
        'oculto': isOculto,
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

  void _addSignificado({bool oculto = false}) {
    setState(() {
      _editMeanings.add({
        'id': null,
        'traducao': TextEditingController(),
        'imagem': '',
        'oculto': oculto ? 1 : 0,
      });
      if (oculto) _showHiddenSection = true;
    });
  }

  Future<void> _alterarFoto(int index, ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      final String fileName = await DatabaseHelper.instance.saveImageToAppDirectory(pickedFile.path);
      if (!mounted) return;
      setState(() => _editMeanings[index]['imagem'] = fileName);
    }
  }

  void _removerSignificado(int index) {
    final bool isHidden = _editMeanings[index]['oculto'] == 1;
    final int visibleCount = _editMeanings.where((m) => m['oculto'] != 1).length;
    if (!isHidden && visibleCount <= 1) return;

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
      await DatabaseHelper.instance.limparImagensOrfas();
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _salvarAlteracoes() async {
    final bool hasAtLeastOneVisibleMeaning = _editMeanings.any(
          (m) => m['oculto'] != 1 && (m['traducao'] as TextEditingController).text.trim().isNotEmpty,
    );

    if (_inglesCtrl.text.trim().isEmpty || !hasAtLeastOneVisibleMeaning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFreeStudy
                ? t('Preencha o objeto de estudo e a explicação antes de salvar.')
                : t('Preencha a palavra e a tradução antes de salvar.'),
          ),
        ),
      );
      return;
    }

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
            'oculto': m['oculto'] == 1 ? 1 : 0,
          });
        }
      }

      await db.limparImagensOrfas();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Alterações salvas!'))));
      Navigator.pop(context);
    } catch (_) {}
  }

  Widget _buildMeaningCard(int realIndex, int displayNum, String labelMeaning, {required bool isHidden}) {
    final m = _editMeanings[realIndex];
    final File? imgFile = DatabaseHelper.instance.getImageFile(m['imagem']?.toString());
    final bool hasImg = imgFile != null;
    final int visibleCount = _editMeanings.where((item) => item['oculto'] != 1).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isHidden ? Colors.grey.withValues(alpha: 0.12) : null,
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
                    decoration: InputDecoration(
                      labelText: isHidden
                          ? "${t('Oculto')} $displayNum"
                          : "$labelMeaning $displayNum",
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isHidden ? Icons.visibility_off : Icons.visibility,
                    color: isHidden ? Colors.orange : Colors.blueGrey,
                  ),
                  tooltip: t('Significados Ocultos'),
                  onPressed: () {
                    if (!isHidden && visibleCount <= 1) return;
                    setState(() {
                      m['oculto'] = isHidden ? 0 : 1;
                      if (m['oculto'] == 1) _showHiddenSection = true;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removerSignificado(realIndex),
                ),
              ],
            ),
            if (!isHidden) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (hasImg)
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: Image.file(imgFile, width: 40, height: 40, fit: BoxFit.cover),
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
                                  _alterarFoto(realIndex, ImageSource.camera);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: Text(t('Galeria')),
                                onTap: () {
                                  Navigator.pop(context);
                                  _alterarFoto(realIndex, ImageSource.gallery);
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String labelMeaning = _isFreeStudy ? t('Explicação') : t('Significado');
    final List<int> visibleIndices = [];
    final List<int> hiddenIndices = [];

    for (int i = 0; i < _editMeanings.length; i++) {
      if (_editMeanings[i]['oculto'] == 1) {
        hiddenIndices.add(i);
      } else {
        visibleIndices.add(i);
      }
    }

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
                child: ListView(
                  children: [
                    for (int vIdx = 0; vIdx < visibleIndices.length; vIdx++)
                      _buildMeaningCard(
                        visibleIndices[vIdx],
                        vIdx + 1,
                        labelMeaning,
                        isHidden: false,
                      ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _showHiddenSection = !_showHiddenSection),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _showHiddenSection ? Icons.visibility_off : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${t('Significados Ocultos')} (${hiddenIndices.length})",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                              ],
                            ),
                            Icon(
                              _showHiddenSection ? Icons.expand_less : Icons.expand_more,
                              color: Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showHiddenSection) ...[
                      if (hiddenIndices.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Text(
                            t('Nenhum significado oculto registrado.'),
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        for (int hIdx = 0; hIdx < hiddenIndices.length; hIdx++)
                          _buildMeaningCard(
                            hiddenIndices[hIdx],
                            hIdx + 1,
                            labelMeaning,
                            isHidden: true,
                          ),
                    ],
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _addSignificado(oculto: false),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(labelMeaning),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _addSignificado(oculto: true),
                    icon: const Icon(Icons.visibility_off_outlined, size: 18, color: Colors.orange),
                    label: Text(t("Adicionar Oculto")),
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