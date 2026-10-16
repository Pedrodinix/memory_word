import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../main.dart';
import '../banco_de_dados/database_helper.dart';

const MethodChannel _notifChannel = MethodChannel('com.pedrodiniz.memoryword/notifications');
Timer? _backgroundReminderTimer;
Timer? _progressDebounceTimer;

/// Solicita permissão de notificação no Android 13+
Future<void> solicitarPermissaoNotificacaoNativa() async {
  try {
    await _notifChannel.invokeMethod('requestPermission');
  } catch (_) {}
}

/// Dispara uma notificação real na barra de status do celular + grava no sino interno do app
Future<void> dispararNotificacaoCompleta({
  required int id,
  required String titulo,
  required String mensagem,
  required String tipo,
}) async {
  final db = DatabaseHelper.instance;
  final String silenciado = await db.getConfig('notificacoes_silenciadas');
  if (silenciado == 'true') return;

  await db.inserirNotificacao(titulo: titulo, mensagem: mensagem, tipo: tipo);
  final int naoLidas = await db.contarNotificacoesNaoLidas();
  appNotifCount.value = naoLidas;

  try {
    await _notifChannel.invokeMethod('showNotification', {
      'id': id,
      'title': titulo,
      'body': mensagem,
    });
  } catch (_) {}
}

/// Sincroniza o agendamento do alarme nativo do Android com as configurações salvas no SQLite
Future<void> sincronizarAlarmeNativoComBanco() async {
  try {
    final db = DatabaseHelper.instance;
    final bool ativo = (await db.getConfig('lembrete_ativo')) == 'true';
    final bool silenciado = (await db.getConfig('notificacoes_silenciadas')) == 'true';
    final String horario = await db.getConfig('lembrete_horario');
    final String dias = await db.getConfig('lembrete_dias');

    final parts = (horario.isEmpty ? '19:00' : horario).split(':');
    final int hour = int.tryParse(parts[0]) ?? 19;
    final int minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    await _notifChannel.invokeMethod('scheduleReminder', {
      'enabled': ativo,
      'silenced': silenciado,
      'hour': hour,
      'minute': minute,
      'days': dias.isEmpty ? '1,2,3,4,5' : dias,
      'title': '⏰ Hora de treinar!',
      'body': 'O seu momento de memorização diária chegou. Abra o MemoryWord e mantenha a sua sequência acesa 🔥!',
    });
  } catch (_) {}
}

/// Agenda a verificação automática de progresso 25 segundos após o usuário registrar palavras ou acertar questões
void agendarVerificacaoDeProgressoRecente() {
  _progressDebounceTimer?.cancel();
  _progressDebounceTimer = Timer(const Duration(seconds: 25), () async {
    await _verificarNotificacaoProgressoDiario();
  });
}

Future<void> _verificarNotificacaoProgressoDiario() async {
  try {
    final db = DatabaseHelper.instance;
    final String silenciado = await db.getConfig('notificacoes_silenciadas');
    if (silenciado == 'true') return;

    final hojeStr = DateTime.now().toIso8601String().substring(0, 10);
    final hojeStats = await db.getEstatisticasHoje();
    final int acertosHoje = (hojeStats['acertos'] as num?)?.toInt() ?? 0;
    final int registradasHoje = (hojeStats['registradas'] as num?)?.toInt() ?? 0;

    if (acertosHoje == 0 && registradasHoje == 0) return;

    final String assinaturaAtual = '${hojeStr}_${acertosHoje}_$registradasHoje';
    final String ultimaAssinatura = await db.getConfig('ultimo_progresso_assinatura');

    // Dispara no primeiro progresso do dia ou quando atinge novos marcos (múltiplos de 5 acertos ou novas palavras)
    final bool atingiuMarco = (acertosHoje == 1 && registradasHoje == 0) ||
        (registradasHoje == 1 && acertosHoje == 0) ||
        (acertosHoje > 0 && acertosHoje % 5 == 0) ||
        (registradasHoje > 0 && registradasHoje % 3 == 0);

    final String ultimoProgressoData = await db.getConfig('ultimo_progresso_data');

    if ((ultimoProgressoData != hojeStr || atingiuMarco) && ultimaAssinatura != assinaturaAtual) {
      String detalhe = '';
      if (acertosHoje > 0 && registradasHoje > 0) {
        detalhe = 'Você já conquistou $acertosHoje acertos e registrou $registradasHoje novos itens hoje!';
      } else if (acertosHoje > 0) {
        detalhe = 'Você já conquistou $acertosHoje acertos nos treinos de hoje!';
      } else {
        detalhe = 'Você já registrou $registradasHoje novos itens na sua biblioteca hoje!';
      }

      await dispararNotificacaoCompleta(
        id: 202,
        titulo: '🎉 Parabéns pelo seu progresso!',
        mensagem: '$detalhe Continue assim!',
        tipo: 'progresso',
      );
      await db.updateConfig('ultimo_progresso_data', hojeStr);
      await db.updateConfig('ultimo_progresso_assinatura', assinaturaAtual);
    }
  } catch (_) {}
}

/// Inicia o monitor contínuo que verifica a cada 20 segundos se chegou o horário do lembrete
Future<void> verificarEProcessarNotificacoesBackground(BuildContext context) async {
  await sincronizarAlarmeNativoComBanco();
  await _checarHorarioLembreteAgora();

  _backgroundReminderTimer?.cancel();
  _backgroundReminderTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
    await _checarHorarioLembreteAgora();
  });
}

Future<void> _checarHorarioLembreteAgora() async {
  try {
    final db = DatabaseHelper.instance;
    final String silenciado = await db.getConfig('notificacoes_silenciadas');
    if (silenciado == 'true') return;

    final String lembreteAtivo = await db.getConfig('lembrete_ativo');
    if (lembreteAtivo != 'true') return;

    final agora = DateTime.now();
    final String hojeStr = agora.toIso8601String().substring(0, 10);
    final String diasConfig = await db.getConfig('lembrete_dias');
    final List<int> diasPermitidos = diasConfig
        .split(',')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .toList();

    if (!diasPermitidos.contains(agora.weekday)) return;

    final String horarioConfig = await db.getConfig('lembrete_horario');
    final parts = (horarioConfig.isEmpty ? '19:00' : horarioConfig).split(':');
    final int targetHour = int.tryParse(parts[0]) ?? 19;
    final int targetMinute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    final int minutosAgora = agora.hour * 60 + agora.minute;
    final int minutosAlvo = targetHour * 60 + targetMinute;

    // Chave única combinando data + horário configurado (permite testar novos horários no mesmo dia)
    final String chaveDisparo = '${hojeStr}_$horarioConfig';
    final String ultimoDisparo = await db.getConfig('ultimo_lembrete_data');

    if (minutosAgora >= minutosAlvo && minutosAgora <= minutosAlvo + 15 && ultimoDisparo != chaveDisparo) {
      await db.updateConfig('ultimo_lembrete_data', chaveDisparo);
      await dispararNotificacaoCompleta(
        id: 777,
        titulo: '⏰ Hora de treinar!',
        mensagem: 'O seu momento de memorização diária chegou. Abra o MemoryWord e mantenha a sua sequência acesa 🔥!',
        tipo: 'lembrete',
      );
    }
  } catch (_) {}
}

// =========================================================================
// ECRÃ DE BOAS-VINDAS (1ª INSTALAÇÃO)
// =========================================================================
class TelaTutorialInicial extends StatefulWidget {
  final VoidCallback onConcluido;
  const TelaTutorialInicial({super.key, required this.onConcluido});

  @override
  State<TelaTutorialInicial> createState() => _TelaTutorialInicialState();
}

class _TelaTutorialInicialState extends State<TelaTutorialInicial> {
  String _idiomaOrigemTemp = appNativeLanguage.value;

  Future<void> _finalizar({required bool iniciarTourGuiado}) async {
    appNativeLanguage.value = _idiomaOrigemTemp;
    await DatabaseHelper.instance.updateConfig('idioma_nativo', _idiomaOrigemTemp);
    await DatabaseHelper.instance.updateConfig('tutorial_inicial_concluido', 'true');
    await solicitarPermissaoNotificacaoNativa();

    if (iniciarTourGuiado) {
      // Inicia o passo a passo interativo sobre as telas reais do app
      appActiveTutorialSection.value = 'completo';
    } else {
      appActiveTutorialSection.value = null;
    }

    if (mounted) widget.onConcluido();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 15),
              const Text('🌍🎓', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 10),
              const Text(
                'Bem-vindo ao MemoryWord!',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Antes de começar, escolha o seu idioma nativo. Depois, você pode seguir o nosso tour passo a passo pelas telas do app ou pular direto para o uso.',
                style: TextStyle(fontSize: 13.5, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1º Passo — Seu Idioma Nativo (Origem):',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: supportedLanguages.containsKey(_idiomaOrigemTemp) ? _idiomaOrigemTemp : 'Português',
                      dropdownColor: Colors.blueGrey.shade800,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white12,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: supportedLanguages.keys.map((lang) {
                        return DropdownMenuItem(
                          value: lang,
                          child: Text(
                            "${supportedLanguages[lang]!.flag} $lang",
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _idiomaOrigemTemp = val);
                          appNativeLanguage.value = val;
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildPreviewRow(
                        Icons.touch_app,
                        'Tour Interativo Passo a Passo',
                        'Ao clicar em "Seguir Tutorial", o aplicativo vai abrir cada aba e deslizar pelos 5 modos de prática mostrando na prática onde clicar e como arrastar.',
                      ),
                      _buildPreviewRow(
                        Icons.swipe_up,
                        'Gestos e Modos de Prática',
                        'Aprenda a usar o Modo Clássico, Modo Papagaio 🦜, Língua/Escrita Afiada 🗡️✍️, Desafio Visual 🖼️ e Reivindicação de Respostas ⚖️.',
                      ),
                      _buildPreviewRow(
                        Icons.notifications_active,
                        'Lembretes e Metas Diárias',
                        'Configure dias e horários nas Configurações para receber avisos no celular e relatórios do seu progresso.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _finalizar(iniciarTourGuiado: false),
                      child: const Text('Pular Tutorial', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Seguir Tutorial', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _finalizar(iniciarTourGuiado: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
            child: Icon(icon, color: Colors.lightBlueAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// OVERLAY DE TUTORIAL GUIADO PASSO A PASSO (NAVEGA PELO APP EM TEMPO REAL)
// =========================================================================
class TutorialStepData {
  final String badge;
  final String title;
  final String description;
  final String gestureHint;
  final IconData icon;
  final int targetTab;
  final int? targetPracticePage;
  final bool showAtTop;

  const TutorialStepData({
    required this.badge,
    required this.title,
    required this.description,
    required this.gestureHint,
    required this.icon,
    required this.targetTab,
    this.targetPracticePage,
    this.showAtTop = false,
  });
}

class TutorialGuiadoOverlay extends StatefulWidget {
  final String section;
  final VoidCallback onClose;

  const TutorialGuiadoOverlay({
    super.key,
    required this.section,
    required this.onClose,
  });

  @override
  State<TutorialGuiadoOverlay> createState() => _TutorialGuiadoOverlayState();
}

class _TutorialGuiadoOverlayState extends State<TutorialGuiadoOverlay> {
  int _currentStep = 0;
  late List<TutorialStepData> _steps;

  @override
  void initState() {
    super.initState();
    _steps = _buildStepsForSection(widget.section);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScreenWithStep(0);
    });
  }

  List<TutorialStepData> _buildStepsForSection(String sec) {
    final bool isFree = isCustomStudy(appLanguage.value);

    final List<TutorialStepData> novoSteps = [
      const TutorialStepData(
        badge: 'ABA 1 • NOVO (REGISTRO)',
        title: '📝 Cadastrar Palavras ou Conceitos',
        description:
        'Aqui na aba "Novo" você alimenta a sua biblioteca:\n'
            '• Digite a palavra no idioma de estudo e toque no ícone do Google Tradutor (🌐) à direita do campo para preencher a tradução automaticamente.\n'
            '• Se estiver no modo "Estudo Livre" (ex: Anatomia, Direito), você cadastra o Objeto de Estudo e a sua Explicação detalhada.',
        gestureHint: '💡 Dica: Se cadastrar uma palavra que já existe, o app pergunta se deseja adicionar um novo significado a ela!',
        icon: Icons.add_circle_outline,
        targetTab: 0,
      ),
      const TutorialStepData(
        badge: 'ABA 1 • MEMÓRIA VISUAL',
        title: '📷 Associar Fotos da Câmera ou Galeria',
        description:
        'Você pode anexar uma foto da Câmera ou da Galeria em qualquer registro.\n'
            '• As fotos aparecem quando você responde no Modo Clássico.\n'
            '• Além disso, todos os itens com foto entram automaticamente no modo "Desafio Visual"!',
        gestureHint: '👉 Toque em "Confirmar" após preencher para salvar na sua Biblioteca.',
        icon: Icons.camera_alt_outlined,
        targetTab: 0,
      ),
    ];

    final List<TutorialStepData> praticarSteps = [
      const TutorialStepData(
        badge: 'ABA 2 • PRATICAR (1/6)',
        title: '🎯 Modo Clássico e Treino Inteligente',
        description:
        'Este é o Modo Clássico de perguntas e respostas:\n'
            '• 🧠 Treino Inteligente: Ative no topo para o app priorizar automaticamente as palavras que você mais erra.\n'
            '• 🔄 Inverter: Alterna entre perguntar no idioma de estudo ou no seu idioma nativo.\n'
            '• 🔊 Áudio: Toque no alto-falante azul para ouvir a pronúncia.',
        gestureHint: '🔥 Cada acerto seguido aumenta seu Combo! Ao atingir 10, 20, 30... você ganha um Combo Especial!',
        icon: Icons.quiz_outlined,
        targetTab: 1,
        targetPracticePage: 0,
      ),
      const TutorialStepData(
        badge: 'ABA 2 • PRATICAR (2/6)',
        title: '👁️ Espiar Resposta e ⚖️ Reivindicar',
        description:
        'Duas ferramentas exclusivas para o seu estudo:\n'
            '• 👁️ Olho (Espiar Resposta): Fica no topo do modo. Revela a resposta na hora sem contar como erro nem acerto, mas bloqueia a digitação para evitar trapaça e pede um novo sorteio.\n'
            '• ⚖️ Reivindicar Resposta: Aparece quando você erra! Permite validar sua resposta como correta e até salvá-la como "Significado Visível" ou "Significado Oculto".',
        gestureHint: '👆 COMO MUDAR DE MODO: Arraste a tela para cima (ou toque na seta no rodapé) para abrir o Modo Papagaio!',
        icon: Icons.visibility_outlined,
        targetTab: 1,
        targetPracticePage: 0,
      ),
      const TutorialStepData(
        badge: 'ABA 2 • PRATICAR (3/6)',
        title: '🦜 Modo Papagaio (Treino Auditivo)',
        description:
        'Arrastando para cima, você chega ao Modo Papagaio!\n'
            '• Ideal para estudar sem usar as mãos (caminhando, no trânsito ou descansando).\n'
            '• O app fala a palavra no idioma de estudo, dá uma pausa para você pensar e fala a tradução em seguida.\n'
            '• Controle a velocidade da voz (0.5x até Turbo 2x) e escolha entre Loop Infinito ou 1 Sequência.',
        gestureHint: '👆 Arraste para cima novamente para conhecer o próximo modo de prática!',
        icon: Icons.record_voice_over,
        targetTab: 1,
        targetPracticePage: 1,
      ),
      if (!isFree)
        const TutorialStepData(
          badge: 'ABA 2 • PRATICAR (4/6)',
          title: '🗡️ Língua Afiada & ✍️ Escrita Afiada',
          description:
          'Arrastando mais uma vez para cima, temos 2 modos em 1:\n'
              '• 🗡️ Língua Afiada (Voz): Sorteie a palavra, toque no microfone azul e fale em voz alta para testar sua pronúncia!\n'
              '• ✍️ Escrita Afiada (Ditado): Toque nas setas azuis (🔄) ao lado do título no topo para inverter! A palavra ficará oculta, você ouvirá apenas o som e deverá digitar o que ouviu.',
          gestureHint: '👆 Arraste para cima para abrir o Desafio Visual!',
          icon: Icons.mic,
          targetTab: 1,
          targetPracticePage: 2,
        ),
      TutorialStepData(
        badge: 'ABA 2 • PRATICAR (5/6)',
        title: '🖼️ Desafio Visual (Sorteio de Imagens)',
        description:
        'Neste modo, o aplicativo sorteia exclusivamente as fotos que você cadastrou!\n'
            '• Veja a imagem na tela e digite qual é a palavra ou conceito correspondente.\n'
            '• No modo Estudo Livre, você ainda pode alternar se deseja responder o Nome do Objeto ou a Explicação.',
        gestureHint: '👆 Arraste para cima mais uma vez para abrir o painel de Desempenho!',
        icon: Icons.image_search,
        targetTab: 1,
        targetPracticePage: isFree ? 2 : 3,
      ),
      TutorialStepData(
        badge: 'ABA 2 • PRATICAR (6/6)',
        title: '📈 Painel de Desempenho',
        description:
        'No último andar da aba Praticar fica o seu histórico completo:\n'
            '• Acompanhe Perguntas Respondidas, Acertos/Erros, Combos Especiais 🎉 e Tempo no Papagaio 🦜.\n'
            '• Veja métricas de Hoje, dos Últimos 7 Dias e o Histórico Mensal consolidado.',
        gestureHint: '👇 Arraste para baixo quando quiser voltar aos modos de treino.',
        icon: Icons.insights,
        targetTab: 1,
        targetPracticePage: isFree ? 3 : 4,
        showAtTop: true,
      ),
    ];

    final List<TutorialStepData> bibliotecaSteps = [
      const TutorialStepData(
        badge: 'ABA 3 • BIBLIOTECA (1/2)',
        title: '📚 Sua Biblioteca e Indicador de Cores',
        description:
        'Na aba Biblioteca ficam todas as palavras ou conceitos do idioma/tema atual:\n'
            '• 🟢 Bolinha Verde: Item dominado (poucos erros).\n'
            '• 🟡 Bolinha Amarela: Atenção média (3 a 4 erros).\n'
            '• 🔴 Bolinha Vermelha: Alta dificuldade (5+ erros — priorizado no Treino Inteligente!).',
        gestureHint: '🔍 Use a barra de pesquisa no topo para achar qualquer palavra ou tradução instantaneamente.',
        icon: Icons.library_books_outlined,
        targetTab: 2,
      ),
      const TutorialStepData(
        badge: 'ABA 3 • BIBLIOTECA (2/2)',
        title: '✏️ Edição, Múltiplos Significados e Ocultos',
        description:
        'Ao tocar em uma palavra da lista e clicar no lápis de edição (✏️):\n'
            '• Você pode adicionar vários significados e fotos diferentes para a mesma palavra.\n'
            '• 🙈 Significados Ocultos: Você pode cadastrar sinônimos ocultos (que são aceitos como resposta certa quando você digita no treino, mas não aparecem na lista nem são falados no Modo Papagaio).',
        gestureHint: '⚙️ No topo direito do app ficam o Sino de Notificações (🔔) e as Configurações (⚙️) com Lembretes e Backup!',
        icon: Icons.edit_note,
        targetTab: 2,
      ),
    ];

    if (sec == 'novo') return novoSteps;
    if (sec == 'praticar') return praticarSteps;
    if (sec == 'biblioteca') return bibliotecaSteps;

    return [
      ...novoSteps,
      ...praticarSteps,
      ...bibliotecaSteps,
    ];
  }

  void _syncScreenWithStep(int index) {
    if (index < 0 || index >= _steps.length) return;
    final step = _steps[index];
    appNavigateToTab.value = step.targetTab;
    if (step.targetPracticePage != null) {
      Future.delayed(const Duration(milliseconds: 220), () {
        appNavigateToPracticePage.value = step.targetPracticePage;
      });
    }
  }

  void _avancar() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _syncScreenWithStep(_currentStep);
    } else {
      widget.onClose();
    }
  }

  void _voltar() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _syncScreenWithStep(_currentStep);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final bool isLast = _currentStep == _steps.length - 1;

    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: SafeArea(
        child: Stack(
          children: [
            // Permite fechar tocando no botão Pular, mas mantém a visualização clara da tela atrás
            Align(
              alignment: step.showAtTop ? Alignment.topCenter : Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.lightBlueAccent, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${step.badge}  •  Passo ${_currentStep + 1}/${_steps.length}',
                            style: const TextStyle(
                              color: Colors.lightBlueAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: Colors.white70,
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Fechar', style: TextStyle(fontSize: 12)),
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(step.icon, color: Colors.orangeAccent, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            step.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      step.description,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        step.gestureHint,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentStep > 0)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                            ),
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: const Text('Anterior'),
                            onPressed: _voltar,
                          )
                        else
                          const SizedBox.shrink(),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isLast ? Colors.green.shade600 : Colors.blueAccent,
                          ),
                          icon: Icon(isLast ? Icons.check_circle : Icons.arrow_forward, size: 18),
                          label: Text(
                            isLast ? 'Concluir Tour!' : 'Próximo Passo',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: _avancar,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// DIÁLOGO NAS CONFIGURAÇÕES PARA ESCOLHER QUAL TUTORIAL GUIADO ABRIR
// =========================================================================
class DialogoTutorialAbas extends StatelessWidget {
  final BuildContext? parentSheetContext;
  const DialogoTutorialAbas({super.key, this.parentSheetContext});

  void _iniciarSecao(BuildContext dialogContext, String secao) {
    Navigator.pop(dialogContext);
    if (parentSheetContext != null && Navigator.canPop(parentSheetContext!)) {
      Navigator.pop(parentSheetContext!);
    }
    appActiveTutorialSection.value = secao;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.school, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Tutoriais Guiados Passo a Passo')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Escolha qual tutorial interativo deseja iniciar. O aplicativo irá navegar pelas telas mostrando cada função passo a passo:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.play_circle_fill, color: Colors.orange, size: 30),
                title: const Text('Tour Completo do App', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Passa por todas as abas e desliza por todos os modos de prática.'),
                onTap: () => _iniciarSecao(context, 'completo'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.blue),
                title: const Text('Tutorial: Aba Novo (Registro)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Como cadastrar palavras, tradução automática e fotos.'),
                onTap: () => _iniciarSecao(context, 'novo'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.quiz, color: Colors.purple),
                title: const Text('Tutorial: Aba Praticar (Todos os Modos)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Como arrastar para cima, Modo Clássico, Papagaio, Afiada, Visual e Desempenho.'),
                onTap: () => _iniciarSecao(context, 'praticar'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.library_books, color: Colors.green),
                title: const Text('Tutorial: Aba Biblioteca', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Indicadores de dificuldade, edição e significados ocultos.'),
                onTap: () => _iniciarSecao(context, 'biblioteca'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('Cancelar')),
        ),
      ],
    );
  }
}

// =========================================================================
// ECRÃ DA CENTRAL DO SINO DE NOTIFICAÇÕES (🔔)
// =========================================================================
class TelaNotificacoes extends StatefulWidget {
  const TelaNotificacoes({super.key});

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  List<Map<String, dynamic>> _notificacoes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarNotificacoes();
  }

  Future<void> _carregarNotificacoes() async {
    final db = DatabaseHelper.instance;
    final lista = await db.listarNotificacoes();
    await db.marcarTodasNotificacoesComoLidas();
    appNotifCount.value = 0;
    if (!mounted) return;
    setState(() {
      _notificacoes = lista;
      _isLoading = false;
    });
  }

  Future<void> _limparTudo() async {
    await DatabaseHelper.instance.limparNotificacoes();
    setState(() => _notificacoes = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 Notificações e Avisos'),
        actions: [
          if (_notificacoes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Limpar Notificações',
              onPressed: _limparTudo,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notificacoes.isEmpty
          ? const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text('Nenhuma notificação por enquanto.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _notificacoes.length,
        itemBuilder: (context, index) {
          final notif = _notificacoes[index];
          final String tipo = notif['tipo'] ?? 'lembrete';
          IconData icone = tipo == 'progresso' ? Icons.celebration : Icons.alarm;
          Color corIcone = tipo == 'progresso' ? Colors.green : Colors.orange;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: corIcone.withValues(alpha: 0.2),
                child: Icon(icone, color: corIcone),
              ),
              title: Text(notif['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(notif['mensagem'] ?? ''),
                  const SizedBox(height: 4),
                  Text(
                    notif['data_hora'].toString().substring(0, 16).replaceAll('T', ' às '),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}

// =========================================================================
// WIDGET DE CONFIGURAÇÃO DE LEMBRETES E COMPROMISSO DE TREINO
// =========================================================================
class LembreteConfigWidget extends StatefulWidget {
  const LembreteConfigWidget({super.key});

  @override
  State<LembreteConfigWidget> createState() => _LembreteConfigWidgetState();
}

class _LembreteConfigWidgetState extends State<LembreteConfigWidget> {
  bool _lembreteAtivo = false;
  bool _notifSilenciadas = false;
  String _horarioSelecionado = '19:00';
  List<int> _diasSelecionados = [1, 2, 3, 4, 5];

  final List<String> _nomesDias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    _carregarConfigs();
  }

  Future<void> _carregarConfigs() async {
    final db = DatabaseHelper.instance;
    final ativo = await db.getConfig('lembrete_ativo');
    final silenciado = await db.getConfig('notificacoes_silenciadas');
    final horario = await db.getConfig('lembrete_horario');
    final dias = await db.getConfig('lembrete_dias');

    if (!mounted) return;
    setState(() {
      _lembreteAtivo = ativo == 'true';
      _notifSilenciadas = silenciado == 'true';
      if (horario.isNotEmpty) _horarioSelecionado = horario;
      if (dias.isNotEmpty) {
        _diasSelecionados = dias
            .split(',')
            .map((e) => int.tryParse(e.trim()) ?? 0)
            .where((e) => e > 0)
            .toList();
      }
    });
  }

  Future<void> _salvarConfigs() async {
    final db = DatabaseHelper.instance;
    await db.updateConfig('lembrete_ativo', _lembreteAtivo.toString());
    await db.updateConfig('notificacoes_silenciadas', _notifSilenciadas.toString());
    await db.updateConfig('lembrete_horario', _horarioSelecionado);
    await db.updateConfig('lembrete_dias', _diasSelecionados.join(','));
    // Reseta trava caso o usuário tenha mudado de horário para testar no mesmo dia
    await db.updateConfig('ultimo_lembrete_data', '');

    if (_lembreteAtivo && !_notifSilenciadas) {
      await solicitarPermissaoNotificacaoNativa();
    }
    await sincronizarAlarmeNativoComBanco();
  }

  Future<void> _selecionarHora(BuildContext context) async {
    final parts = _horarioSelecionado.split(':');
    TimeOfDay initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 19,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      final formatted = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      setState(() => _horarioSelecionado = formatted);
      await _salvarConfigs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 30),
        const Text(
          "Notificações e Lembretes de Treino",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Silenciar Notificações 🔕'),
          subtitle: const Text(
            'Desativa todos os avisos e lembretes do aparelho',
            style: TextStyle(fontSize: 12),
          ),
          value: _notifSilenciadas,
          onChanged: (val) async {
            setState(() => _notifSilenciadas = val);
            await _salvarConfigs();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Compromisso de Treino ⏰'),
          subtitle: const Text(
            'Receba a notificação "Hora de treinar!" no celular nos dias e horário escolhidos',
            style: TextStyle(fontSize: 12),
          ),
          value: _lembreteAtivo,
          onChanged: (val) async {
            setState(() => _lembreteAtivo = val);
            await _salvarConfigs();
          },
        ),
        if (_lembreteAtivo) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Horário do Lembrete:', style: TextStyle(fontWeight: FontWeight.bold)),
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time),
                label: Text(
                  _horarioSelecionado,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _selecionarHora(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Dias da Semana (Seg a Dom):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: List.generate(7, (index) {
              int diaId = index + 1;
              bool selecionado = _diasSelecionados.contains(diaId);
              return FilterChip(
                label: Text(_nomesDias[index]),
                selected: selecionado,
                onSelected: (bool selected) async {
                  setState(() {
                    if (selected) {
                      _diasSelecionados.add(diaId);
                    } else if (_diasSelecionados.length > 1) {
                      _diasSelecionados.remove(diaId);
                    }
                  });
                  await _salvarConfigs();
                },
              );
            }),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.notifications_active, size: 18),
              label: const Text('Testar Notificação no Celular Agora'),
              onPressed: () async {
                await solicitarPermissaoNotificacaoNativa();
                await dispararNotificacaoCompleta(
                  id: 999,
                  titulo: '⏰ Hora de treinar!',
                  mensagem: 'Teste de lembrete ativo! Suas notificações estão funcionando perfeitamente no aparelho 🔥.',
                  tipo: 'lembrete',
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notificação enviada! Verifique a barra superior do seu celular 🔔.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}