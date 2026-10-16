import 'package:flutter/material.dart';

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
  'Italiano': AppLanguage('Italiano', '🇮🇹', 'it-IT', 'it'),
  'Russo': AppLanguage('Russo', '🇷🇺', 'ru-RU', 'ru'),
  'Japonês': AppLanguage('Japonês', '🇯🇵', 'ja-JP', 'ja'),
  'Chinês Mandarim': AppLanguage('Chinês Mandarim', '🇨🇳', 'zh-CN', 'zh-cn'),
  'Coreano': AppLanguage('Coreano', '🇰🇷', 'ko-KR', 'ko'),
  'Hindi': AppLanguage('Hindi', '🇮🇳', 'hi-IN', 'hi'),
  'Árabe': AppLanguage('Árabe', '🇸🇦', 'ar-SA', 'ar'),
};

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);
final ValueNotifier<String> appLanguage = ValueNotifier('Inglês');
final ValueNotifier<String> appNativeLanguage = ValueNotifier('Português');
final ValueNotifier<bool> appFeedbackEnabled = ValueNotifier(true);
final ValueNotifier<bool> appTreinoInteligente = ValueNotifier(false);
final ValueNotifier<bool> appAutoNext = ValueNotifier(true);
final ValueNotifier<int> appDataVersion = ValueNotifier(0);

// Helpers para identificar se o usuário está estudando um Idioma ou um Tema Livre
bool isCustomStudy(String langKey) => langKey.startsWith('tema:');

String getStudyDisplayName(String langKey) {
  if (isCustomStudy(langKey)) {
    return langKey.substring(5);
  }
  return t(langKey);
}

String getStudyFlagOrIcon(String langKey) {
  if (isCustomStudy(langKey)) return '🎓';
  return supportedLanguages[langKey]?.flag ?? '🌐';
}

Future<void> carregarConfiguracoesGlobaisDoBanco() async {
  final db = DatabaseHelper.instance;
  String temaSalvo = await db.getConfig('tema');
  String idiomaSalvo = await db.getConfig('idioma_atual');
  String idiomaNativoSalvo = await db.getConfig('idioma_nativo');
  String feedbackSalvo = await db.getConfig('feedback_ativo');
  String treinoSalvo = await db.getConfig('treino_inteligente');
  String autoNextSalvo = await db.getConfig('avanco_automatico');

  appThemeMode.value = (temaSalvo == 'dark') ? ThemeMode.dark : ThemeMode.light;
  if (idiomaSalvo.isNotEmpty && (supportedLanguages.containsKey(idiomaSalvo) || isCustomStudy(idiomaSalvo))) {
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
  if (autoNextSalvo.isNotEmpty) {
    appAutoNext.value = (autoNextSalvo == 'true');
  }
  appDataVersion.value++;
}

// --- MOTOR DE TRADUÇÃO GLOBAL COMPLETO (12 IDIOMAS) ---
String t(String text) {
  String code = supportedLanguages[appNativeLanguage.value]?.transCode ?? 'pt';
  if (code == 'pt') return text;

  const Map<String, Map<String, String>> dict = {
    // --- NOMES DOS IDIOMAS ---
    'Inglês': {
      'en': 'English', 'de': 'Englisch', 'es': 'Inglés', 'fr': 'Anglais',
      'it': 'Inglese', 'ru': 'Английский', 'ja': '英語', 'zh-cn': '英语',
      'ko': '영어', 'hi': 'अंग्रेज़ी', 'ar': 'الإنجليزية'
    },
    'Alemão': {
      'en': 'German', 'de': 'Deutsch', 'es': 'Alemán', 'fr': 'Allemand',
      'it': 'Tedesco', 'ru': 'Немецкий', 'ja': 'ドイツ語', 'zh-cn': '德语',
      'ko': '독일어', 'hi': 'जर्मन', 'ar': 'الألمانية'
    },
    'Espanhol': {
      'en': 'Spanish', 'de': 'Spanisch', 'es': 'Español', 'fr': 'Espagnol',
      'it': 'Spagnolo', 'ru': 'Испанский', 'ja': 'スペイン語', 'zh-cn': '西班牙语',
      'ko': '스페인어', 'hi': 'स्पेनिश', 'ar': 'الإسبانية'
    },
    'Português': {
      'en': 'Portuguese', 'de': 'Portugiesisch', 'es': 'Portugués', 'fr': 'Portugais',
      'it': 'Portoghese', 'ru': 'Португальский', 'ja': 'ポルトガル語', 'zh-cn': '葡萄牙语',
      'ko': '포르투갈어', 'hi': 'पुर्तगाली', 'ar': 'البرتغالية'
    },
    'Francês': {
      'en': 'French', 'de': 'Französisch', 'es': 'Francés', 'fr': 'Français',
      'it': 'Francese', 'ru': 'Французский', 'ja': 'フランス語', 'zh-cn': '法语',
      'ko': '프랑스어', 'hi': 'फ़्रेंच', 'ar': 'الفرنسية'
    },
    'Italiano': {
      'en': 'Italian', 'de': 'Italienisch', 'es': 'Italiano', 'fr': 'Italien',
      'it': 'Italiano', 'ru': 'Итальянский', 'ja': 'イタリア語', 'zh-cn': '意大利语',
      'ko': '이탈리아어', 'hi': 'इतालवी', 'ar': 'الإيطالية'
    },
    'Russo': {
      'en': 'Russian', 'de': 'Russisch', 'es': 'Ruso', 'fr': 'Russe',
      'it': 'Russo', 'ru': 'Русский', 'ja': 'ロシア語', 'zh-cn': '俄语',
      'ko': '러시아어', 'hi': 'रूसी', 'ar': 'الروسية'
    },
    'Japonês': {
      'en': 'Japanese', 'de': 'Japanisch', 'es': 'Japonés', 'fr': 'Japonais',
      'it': 'Giapponese', 'ru': 'Японский', 'ja': '日本語', 'zh-cn': '日语',
      'ko': '일본어', 'hi': 'जापानी', 'ar': 'اليابانية'
    },
    'Chinês Mandarim': {
      'en': 'Mandarin Chinese', 'de': 'Mandarin-Chinesisch', 'es': 'Chino Mandarín', 'fr': 'Chinois Mandarin',
      'it': 'Cinese Mandarino', 'ru': 'Китайский (Мандарин)', 'ja': '中国語（標準語）', 'zh-cn': '普通话',
      'ko': '중국어(만다린)', 'hi': 'मंदारिन चीनी', 'ar': 'الصينية (الماندرين)'
    },
    'Coreano': {
      'en': 'Korean', 'de': 'Koreanisch', 'es': 'Coreano', 'fr': 'Coréen',
      'it': 'Coreano', 'ru': 'Корейский', 'ja': '韓国語', 'zh-cn': '韩语',
      'ko': '한국어', 'hi': 'कोरियाई', 'ar': 'الكورية'
    },
    'Hindi': {
      'en': 'Hindi', 'de': 'Hindi', 'es': 'Hindi', 'fr': 'Hindi',
      'it': 'Hindi', 'ru': 'Хинди', 'ja': 'ヒンディー語', 'zh-cn': '印地语',
      'ko': '힌디어', 'hi': 'हिन्दी', 'ar': 'الهندية'
    },
    'Árabe': {
      'en': 'Arabic', 'de': 'Arabisch', 'es': 'Árabe', 'fr': 'Arabe',
      'it': 'Arabo', 'ru': 'Арабский', 'ja': 'アラビア語', 'zh-cn': '阿拉伯语',
      'ko': '아랍어', 'hi': 'अरबी', 'ar': 'العربية'
    },

    // --- NAVEGAÇÃO E CONFIGURAÇÕES GERAIS ---
    'Novo': {
      'en': 'New', 'de': 'Neu', 'es': 'Nuevo', 'fr': 'Nouveau',
      'it': 'Nuovo', 'ru': 'Новое', 'ja': '新規', 'zh-cn': '新建',
      'ko': '추가', 'hi': 'नया', 'ar': 'جديد'
    },
    'Praticar': {
      'en': 'Practice', 'de': 'Üben', 'es': 'Practicar', 'fr': 'Pratiquer',
      'it': 'Pratica', 'ru': 'Практика', 'ja': '練習', 'zh-cn': '练习',
      'ko': '연습', 'hi': 'अभ्यास', 'ar': 'تدريب'
    },
    'Biblioteca': {
      'en': 'Library', 'de': 'Bibliothek', 'es': 'Biblioteca', 'fr': 'Bibliothèque',
      'it': 'Libreria', 'ru': 'Библиотека', 'ja': 'ライブラリ', 'zh-cn': '词库',
      'ko': '라이브러리', 'hi': 'लाइब्रेरी', 'ar': 'المكتبة'
    },
    'Configurações': {
      'en': 'Settings', 'de': 'Einstellungen', 'es': 'Ajustes', 'fr': 'Paramètres',
      'it': 'Impostazioni', 'ru': 'Настройки', 'ja': '設定', 'zh-cn': '设置',
      'ko': '설정', 'hi': 'सेटिंग्स', 'ar': 'الإعدادات'
    },
    'Categoria de Estudo': {
      'en': 'Study Category', 'de': 'Lernkategorie', 'es': 'Categoría de Estudio', 'fr': "Catégorie d'étude",
      'it': 'Categoria di Studio', 'ru': 'Категория обучения', 'ja': '学習カテゴリー', 'zh-cn': '学习类别',
      'ko': '학습 카테고리', 'hi': 'अध्ययन श्रेणी', 'ar': 'فئة الدراسة'
    },
    'Idiomas': {
      'en': 'Languages', 'de': 'Sprachen', 'es': 'Idiomas', 'fr': 'Langues',
      'it': 'Lingue', 'ru': 'Языки', 'ja': '言語', 'zh-cn': '语言',
      'ko': '언어', 'hi': 'भाषाएँ', 'ar': 'اللغات'
    },
    'Estudo Livre': {
      'en': 'Free Study', 'de': 'Freies Lernen', 'es': 'Estudio Libre', 'fr': 'Étude Libre',
      'it': 'Studio Libero', 'ru': 'Свободная тема', 'ja': '自由学習', 'zh-cn': '自由学习',
      'ko': '자유 학습', 'hi': 'मुक्त अध्ययन', 'ar': 'دراسة حرة'
    },
    'Tema de Estudo Personalizado': {
      'en': 'Custom Study Topic', 'de': 'Eigenes Lernthema', 'es': 'Tema de Estudio Personalizado', 'fr': "Sujet d'étude personnalisé",
      'it': 'Argomento Personalizzato', 'ru': 'Своя тема обучения', 'ja': 'カスタム学習テーマ', 'zh-cn': '自定义学习主题',
      'ko': '맞춤 학습 주제', 'hi': 'कस्टम अध्ययन विषय', 'ar': 'موضوع دراسة مخصص'
    },
    'Criar Tema': {
      'en': 'Create Topic', 'de': 'Thema erstellen', 'es': 'Crear Tema', 'fr': 'Créer un sujet',
      'it': 'Crea Argomento', 'ru': 'Создать тему', 'ja': 'テーマを作成', 'zh-cn': '创建主题',
      'ko': '주제 만들기', 'hi': 'विषय बनाएं', 'ar': 'إنشاء موضوع'
    },
    'Nome do Objeto / Assunto de Estudo': {
      'en': 'Study Object / Topic Name', 'de': 'Name des Lerngegenstands / Themas', 'es': 'Nombre del Objeto / Tema de Estudio', 'fr': 'Nom du sujet / objet d\'étude',
      'it': 'Nome dell\'Argomento di Studio', 'ru': 'Название предмета / темы', 'ja': '学習対象・テーマ名', 'zh-cn': '学习对象/主题名称',
      'ko': '학습 대상 / 주제 이름', 'hi': 'अध्ययन विषय का नाम', 'ar': 'اسم موضوع الدراسة'
    },
    'Ex: Anatomia, Direito, História...': {
      'en': 'Ex: Anatomy, Law, History...', 'de': 'z.B. Anatomie, Recht, Geschichte...', 'es': 'Ej: Anatomía, Derecho, Historia...', 'fr': 'Ex : Anatomie, Droit, Histoire...',
      'it': 'Es: Anatomia, Diritto, Storia...', 'ru': 'Напр.: Анатомия, Право, История...', 'ja': '例：解剖学、法律、歴史...', 'zh-cn': '例如：解剖学、法律、历史...',
      'ko': '예: 해부학, 법률, 역사...', 'hi': 'उदा: शरीर रचना, कानून, इतिहास...', 'ar': 'مثال: التشريح، القانون، التاريخ...'
    },
    'Renomear': {
      'en': 'Rename', 'de': 'Umbenennen', 'es': 'Renombrar', 'fr': 'Renommer',
      'it': 'Rinomina', 'ru': 'Переименовать', 'ja': '名前を変更', 'zh-cn': '重命名',
      'ko': '이름 변경', 'hi': 'नाम बदलें', 'ar': 'إعادة تسمية'
    },
    'Novo nome do tema': {
      'en': 'New topic name', 'de': 'Neuer Themenname', 'es': 'Nuevo nombre del tema', 'fr': 'Nouveau nom du sujet',
      'it': 'Nuovo nome argomento', 'ru': 'Новое название темы', 'ja': '新しいテーマ名', 'zh-cn': '新主题名称',
      'ko': '새 주제 이름', 'hi': 'नया विषय नाम', 'ar': 'اسم الموضوع الجديد'
    },
    'Deseja apagar este tema e todos os objetos de estudo registados nele?': {
      'en': 'Do you want to delete this topic and all study objects registered in it?',
      'de': 'Möchten Sie dieses Thema und alle darin gespeicherten Lernobjekte löschen?',
      'es': '¿Deseas eliminar este tema y todos los objetos de estudio registrados en él?',
      'fr': 'Voulez-vous supprimer ce sujet et tous les objets d\'étude associés ?',
      'it': 'Vuoi eliminare questo argomento e tutti gli oggetti di studio registrati?',
      'ru': 'Удалить эту тему и все сохраненные в ней объекты изучения?',
      'ja': 'このテーマと登録されているすべての学習項目を削除しますか？',
      'zh-cn': '确定要删除此主题及其包含的所有学习项目吗？',
      'ko': '이 주제와 등록된 모든 학습 항목을 삭제하시겠습니까?',
      'hi': 'क्या आप इस विषय और इसमें दर्ज सभी अध्ययन वस्तुओं को हटाना चाहते हैं?',
      'ar': 'هل تريد حذف هذا الموضوع وجميع عناصر الدراسة المسجلة فيه؟'
    },
    'Idioma de Estudo Principal': {
      'en': 'Main Study Language', 'de': 'Hauptlernsprache', 'es': 'Idioma de Estudio Principal', 'fr': "Langue d'étude principale",
      'it': 'Lingua di Studio Principale', 'ru': 'Основной изучаемый язык', 'ja': 'メインの学習言語', 'zh-cn': '主要学习语言',
      'ko': '주요 학습 언어', 'hi': 'मुख्य अध्ययन भाषा', 'ar': 'لغة الدراسة الرئيسية'
    },
    'Seu Idioma (Origem)': {
      'en': 'Your Native Language', 'de': 'Deine Muttersprache', 'es': 'Tu Idioma Nativo', 'fr': 'Votre Langue Maternelle',
      'it': 'La Tua Lingua Madre', 'ru': 'Ваш родной язык', 'ja': 'あなたの母国語', 'zh-cn': '您的母语',
      'ko': '모국어 (앱 언어)', 'hi': 'आपकी मातृभाषा', 'ar': 'لغتك الأم'
    },
    'Aprender': {
      'en': 'Learn', 'de': 'Lernen', 'es': 'Aprender', 'fr': 'Apprendre',
      'it': 'Impara', 'ru': 'Учить', 'ja': '学ぶ', 'zh-cn': '学习',
      'ko': '학습:', 'hi': 'सीखें', 'ar': 'تعلّم'
    },
    'Falar': {
      'en': 'Speak', 'de': 'Sprechen', 'es': 'Hablar', 'fr': 'Parler',
      'it': 'Parla', 'ru': 'Говорить', 'ja': '話す', 'zh-cn': '使用',
      'ko': '언어:', 'hi': 'बोलें', 'ar': 'تحدث'
    },
    'Preferências': {
      'en': 'Preferences', 'de': 'Präferenzen', 'es': 'Preferencias', 'fr': 'Préférences',
      'it': 'Preferenze', 'ru': 'Предпочтения', 'ja': '環境設定', 'zh-cn': '偏好设置',
      'ko': '환경설정', 'hi': 'प्राथमिकताएँ', 'ar': 'التفضيلات'
    },
    'Modo Noturno': {
      'en': 'Dark Mode', 'de': 'Nachtmodus', 'es': 'Modo Oscuro', 'fr': 'Mode Sombre',
      'it': 'Modalità Scura', 'ru': 'Ночной режим', 'ja': 'ダークモード', 'zh-cn': '深色模式',
      'ko': '다크 모드', 'hi': 'डार्क मोड', 'ar': 'الوضع الليلي'
    },
    'Som e Vibração': {
      'en': 'Sound & Vibration', 'de': 'Ton & Vibration', 'es': 'Sonido y Vibración', 'fr': 'Son et Vibration',
      'it': 'Suono e Vibrazione', 'ru': 'Звук и вибрация', 'ja': 'サウンドと振動', 'zh-cn': '声音与振动',
      'ko': '소리 및 진동', 'hi': 'ध्वनि और कंपन', 'ar': 'الصوت والاهتزاز'
    },
    'Sorteio Automático após Responder': {
      'en': 'Auto-Draw After Answering', 'de': 'Automatisch weiter nach Antwort', 'es': 'Sorteo Automático al Responder', 'fr': 'Tirage auto après réponse',
      'it': 'Avanzamento Automatico', 'ru': 'Автопереход после ответа', 'ja': '回答後に自動で次へ', 'zh-cn': '回答后自动抽取下一题',
      'ko': '답변 후 자동 다음 문제', 'hi': 'उत्तर के बाद स्वतः अगला प्रश्न', 'ar': 'سحب تلقائي بعد الإجابة'
    },
    'Desative para avançar manualmente no seu ritmo': {
      'en': 'Disable to advance manually at your own pace', 'de': 'Deaktivieren, um manuell fortzufahren', 'es': 'Desactiva para avanzar manualmente a tu ritmo', 'fr': 'Désactivez pour avancer manuellement',
      'it': 'Disattiva per avanzare manualmente', 'ru': 'Отключите для перехода вручную в своем темпе', 'ja': 'オフにすると自分のペースで手動で進みます', 'zh-cn': '关闭后可按自己的节奏手动前进',
      'ko': '비활성화하면 수동으로 다음 문제로 이동합니다', 'hi': 'अपनी गति से आगे बढ़ने के लिए इसे बंद करें', 'ar': 'قم بتعطيله للتقدم يدوياً بالسرعة التي تناسبك'
    },
    'Próximo': {
      'en': 'Next', 'de': 'Weiter', 'es': 'Siguiente', 'fr': 'Suivant',
      'it': 'Avanti', 'ru': 'Далее', 'ja': '次へ', 'zh-cn': '下一个',
      'ko': '다음', 'hi': 'अगला', 'ar': 'التالي'
    },
    'Filtro de Sorteio (Global)': {
      'en': 'Global Draw Filter', 'de': 'Globaler Ziehungsfilter', 'es': 'Filtro de Sorteo (Global)', 'fr': 'Filtre de Tirage (Global)',
      'it': 'Filtro di Estrazione (Globale)', 'ru': 'Фильтр выборки (Глобальный)', 'ja': '出題フィルター（全体）', 'zh-cn': '全局抽题筛选',
      'ko': '전체 출제 필터', 'hi': 'ग्लोबल ड्रॉ फ़िल्टर', 'ar': 'فلتر السحب (عام)'
    },
    'Todas as palavras': {
      'en': 'All items', 'de': 'Alle Einträge', 'es': 'Todos los elementos', 'fr': 'Tous les éléments',
      'it': 'Tutti gli elementi', 'ru': 'Все записи', 'ja': 'すべて', 'zh-cn': '全部项目',
      'ko': '모든 항목', 'hi': 'सभी शब्द/वस्तुएँ', 'ar': 'جميع العناصر'
    },
    'Últimas 10': {
      'en': 'Last 10', 'de': 'Letzte 10', 'es': 'Últimas 10', 'fr': 'Les 10 derniers',
      'it': 'Ultime 10', 'ru': 'Последние 10', 'ja': '最新10件', 'zh-cn': '最近 10 个',
      'ko': '최근 10개', 'hi': 'अंतिम 10', 'ar': 'آخر 10'
    },
    'Últimas 20': {
      'en': 'Last 20', 'de': 'Letzte 20', 'es': 'Últimas 20', 'fr': 'Les 20 derniers',
      'it': 'Ultime 20', 'ru': 'Последние 20', 'ja': '最新20件', 'zh-cn': '最近 20 个',
      'ko': '최근 20개', 'hi': 'अंतिम 20', 'ar': 'آخر 20'
    },
    'Últimas 30': {
      'en': 'Last 30', 'de': 'Letzte 30', 'es': 'Últimas 30', 'fr': 'Les 30 derniers',
      'it': 'Ultime 30', 'ru': 'Последние 30', 'ja': '最新30件', 'zh-cn': '最近 30 个',
      'ko': '최근 30개', 'hi': 'अंतिम 30', 'ar': 'آخر 30'
    },
    'Personalizado': {
      'en': 'Custom', 'de': 'Benutzerdefiniert', 'es': 'Personalizado', 'fr': 'Personnalisé',
      'it': 'Personalizzato', 'ru': 'Пользовательский', 'ja': 'カスタム', 'zh-cn': '自定义',
      'ko': '사용자 지정', 'hi': 'कस्टम', 'ar': 'مخصص'
    },
    'Nº Personalizado (> 0)': {
      'en': 'Custom Number (> 0)', 'de': 'Eigene Anzahl (> 0)', 'es': 'Nº Personalizado (> 0)', 'fr': 'Nombre personnalisé (> 0)',
      'it': 'Numero Personalizzato (> 0)', 'ru': 'Свое число (> 0)', 'ja': 'カスタム数 (> 0)', 'zh-cn': '自定义数量 (> 0)',
      'ko': '사용자 지정 개수 (> 0)', 'hi': 'कस्टम संख्या (> 0)', 'ar': 'عدد مخصص (> 0)'
    },
    'Salvar': {
      'en': 'Save', 'de': 'Speichern', 'es': 'Guardar', 'fr': 'Enregistrer',
      'it': 'Salva', 'ru': 'Сохранить', 'ja': '保存', 'zh-cn': '保存',
      'ko': '저장', 'hi': 'सहेजें', 'ar': 'حفظ'
    },
    'Configurações salvas!': {
      'en': 'Settings saved!', 'de': 'Einstellungen gespeichert!', 'es': '¡Ajustes guardados!', 'fr': 'Paramètres enregistrés !',
      'it': 'Impostazioni salvate!', 'ru': 'Настройки сохранены!', 'ja': '設定を保存しました！', 'zh-cn': '设置已保存！',
      'ko': '설정이 저장되었습니다!', 'hi': 'सेटिंग्स सहेजी गईं!', 'ar': 'تم حفظ الإعدادات!'
    },

    // --- TELA DE REGISTRO ---
    'Registrar Palavra': {
      'en': 'Register Word', 'de': 'Wort registrieren', 'es': 'Registrar Palabra', 'fr': 'Enregistrer le mot',
      'it': 'Registra Parola', 'ru': 'Добавить слово', 'ja': '単語を登録', 'zh-cn': '添加单词',
      'ko': '단어 등록', 'hi': 'शब्द दर्ज करें', 'ar': 'تسجيل كلمة'
    },
    'Registrar Objeto de Estudo': {
      'en': 'Register Study Object', 'de': 'Lernobjekt registrieren', 'es': 'Registrar Objeto de Estudio', 'fr': "Enregistrer l'objet d'étude",
      'it': 'Registra Oggetto di Studio', 'ru': 'Добавить объект изучения', 'ja': '学習項目を登録', 'zh-cn': '添加学习对象',
      'ko': '학습 항목 등록', 'hi': 'अध्ययन वस्तु दर्ज करें', 'ar': 'تسجيل عنصر دراسة'
    },
    'Objeto de Estudo / Conceito': {
      'en': 'Study Object / Concept', 'de': 'Lernobjekt / Konzept', 'es': 'Objeto de Estudio / Concepto', 'fr': "Objet d'étude / Concept",
      'it': 'Oggetto di Studio / Concetto', 'ru': 'Объект изучения / Понятие', 'ja': '学習対象 / コンセプト', 'zh-cn': '学习对象 / 概念',
      'ko': '학습 대상 / 개념', 'hi': 'अध्ययन वस्तु / अवधारणा', 'ar': 'موضوع الدراسة / المفهوم'
    },
    'Explicação / Definição': {
      'en': 'Explanation / Definition', 'de': 'Erklärung / Definition', 'es': 'Explicación / Definición', 'fr': 'Explication / Définition',
      'it': 'Spiegazione / Definizione', 'ru': 'Объяснение / Определение', 'ja': '説明 / 定義', 'zh-cn': '解释 / 定义',
      'ko': '설명 / 정의', 'hi': 'व्याख्या / परिभाषा', 'ar': 'الشرح / التعريف'
    },
    'Palavra em': {
      'en': 'Word in', 'de': 'Wort auf', 'es': 'Palabra en', 'fr': 'Mot en',
      'it': 'Parola in', 'ru': 'Слово на:', 'ja': '単語：', 'zh-cn': '单词语言：',
      'ko': '단어 언어:', 'hi': 'शब्द भाषा:', 'ar': 'الكلمة بـ'
    },
    'Significado / Tradução': {
      'en': 'Meaning / Translation', 'de': 'Bedeutung / Übersetzung', 'es': 'Significado / Traducción', 'fr': 'Signification / Traduction',
      'it': 'Significato / Traduzione', 'ru': 'Значение / Перевод', 'ja': '意味 / 翻訳', 'zh-cn': '含义 / 翻译',
      'ko': '의미 / 번역', 'hi': 'अर्थ / अनुवाद', 'ar': 'المعنى / الترجمة'
    },
    'Câmera': {
      'en': 'Camera', 'de': 'Kamera', 'es': 'Cámara', 'fr': 'Caméra',
      'it': 'Fotocamera', 'ru': 'Камера', 'ja': 'カメラ', 'zh-cn': '相机',
      'ko': '카메라', 'hi': 'कैमरा', 'ar': 'الكاميرا'
    },
    'Galeria': {
      'en': 'Gallery', 'de': 'Galerie', 'es': 'Galería', 'fr': 'Galerie',
      'it': 'Galleria', 'ru': 'Галерея', 'ja': 'ギャラリー', 'zh-cn': '图库',
      'ko': '갤러리', 'hi': 'गैलरी', 'ar': 'المعرض'
    },
    'Confirmar': {
      'en': 'Confirm', 'de': 'Bestätigen', 'es': 'Confirmar', 'fr': 'Confirmer',
      'it': 'Conferma', 'ru': 'Подтвердить', 'ja': '確定', 'zh-cn': '确认',
      'ko': '확인', 'hi': 'पुष्टि करें', 'ar': 'تأكيد'
    },
    'Remover Foto': {
      'en': 'Remove Photo', 'de': 'Foto entfernen', 'es': 'Eliminar Foto', 'fr': 'Supprimer la photo',
      'it': 'Rimuovi Foto', 'ru': 'Удалить фото', 'ja': '写真を削除', 'zh-cn': '移除照片',
      'ko': '사진 삭제', 'hi': 'फ़ोटो हटाएं', 'ar': 'إزالة الصورة'
    },
    'Preencha a palavra e a tradução antes de salvar.': {
      'en': 'Fill word and translation before saving.', 'de': 'Bitte Wort und Übersetzung eingeben.', 'es': 'Rellene palabra y traducción antes de guardar.', 'fr': 'Remplissez le mot et la traduction avant d\'enregistrer.',
      'it': 'Inserisci parola e traduzione prima di salvare.', 'ru': 'Введите слово и перевод перед сохранением.', 'ja': '保存する前に単語と翻訳を入力してください。', 'zh-cn': '保存前请填写单词和翻译。',
      'ko': '저장하기 전에 단어와 번역을 입력하세요.', 'hi': 'सहेजने से पहले शब्द और अनुवाद भरें।', 'ar': 'يرجى ملء الكلمة والترجمة قبل الحفظ.'
    },
    'Preencha o objeto de estudo e a explicação antes de salvar.': {
      'en': 'Fill the study object and explanation before saving.', 'de': 'Bitte Lernobjekt und Erklärung eingeben.', 'es': 'Rellene el objeto de estudio y la explicación antes de guardar.', 'fr': "Remplissez l'objet et l'explication avant d'enregistrer.",
      'it': 'Inserisci oggetto e spiegazione prima di salvare.', 'ru': 'Введите объект изучения и объяснение перед сохранением.', 'ja': '保存する前に学習対象と説明を入力してください。', 'zh-cn': '保存前请填写学习对象和解释。',
      'ko': '저장하기 전에 학습 대상과 설명을 입력하세요.', 'hi': 'सहेजने से पहले अध्ययन वस्तु और व्याख्या भरें।', 'ar': 'يرجى ملء عنصر الدراسة والشرح قبل الحفظ.'
    },
    'Objeto Existente': {
      'en': 'Existing Object', 'de': 'Vorhandenes Objekt', 'es': 'Objeto Existente', 'fr': 'Objet Existant',
      'it': 'Oggetto Esistente', 'ru': 'Объект уже существует', 'ja': '既存の項目', 'zh-cn': '项目已存在',
      'ko': '기존 항목', 'hi': 'मौजूदा वस्तु', 'ar': 'عنصر موجود'
    },
    'Palavra Existente': {
      'en': 'Existing Word', 'de': 'Vorhandenes Wort', 'es': 'Palavra Existente', 'fr': 'Mot Existant',
      'it': 'Parola Esistente', 'ru': 'Слово уже существует', 'ja': '既存の単語', 'zh-cn': '单词已存在',
      'ko': '기존 단어', 'hi': 'मौजूदा शब्द', 'ar': 'كلمة موجودة'
    },
    'Este objeto de estudo já existe nesta biblioteca. Deseja adicionar uma nova explicação a ele?': {
      'en': 'This study object already exists in this library. Do you want to add a new explanation to it?',
      'de': 'Dieses Lernobjekt existiert bereits. Möchten Sie eine weitere Erklärung hinzufügen?',
      'es': 'Este objeto de estudio ya existe en esta biblioteca. ¿Deseas añadirle una nueva explicación?',
      'fr': 'Cet objet d\'étude existe déjà. Voulez-vous lui ajouter une nouvelle explication ?',
      'it': 'Questo oggetto di studio esiste già. Vuoi aggiungere una nuova spiegazione?',
      'ru': 'Этот объект уже есть в библиотеке. Добавить к нему новое объяснение?',
      'ja': 'この学習項目は既に存在します。新しい説明を追加しますか？',
      'zh-cn': '此学习对象已存在。是否要为其添加新的解释？',
      'ko': '이 학습 항목은 이미 존재합니다. 새로운 설명을 추가하시겠습니까?',
      'hi': 'यह अध्ययन वस्तु पहले से मौजूद है। क्या आप इसमें नई व्याख्या जोड़ना चाहते हैं?',
      'ar': 'عنصر الدراسة هذا موجود بالفعل. هل تريد إضافة شرح جديد له؟'
    },
    'Esta palavra já existe na biblioteca desta língua. Deseja adicionar este novo significado a ela?': {
      'en': 'This word already exists in this language library. Do you want to add this new meaning to it?',
      'de': 'Dieses Wort existiert bereits. Möchten Sie diese neue Bedeutung hinzufügen?',
      'es': 'Esta palabra ya existe en la biblioteca. ¿Deseas añadirle este nuevo significado?',
      'fr': 'Ce mot existe déjà dans la bibliothèque. Voulez-vous lui ajouter cette nouvelle signification ?',
      'it': 'Questa parola esiste già nella libreria. Vuoi aggiungere questo nuovo significato?',
      'ru': 'Это слово уже есть в библиотеке. Добавить к нему новое значение?',
      'ja': 'この単語は既に存在します。新しい意味を追加しますか？',
      'zh-cn': '此单词已存在于词库中。是否要为其添加此新含义？',
      'ko': '이 단어는 이미 존재합니다. 새로운 의미를 추가하시겠습니까?',
      'hi': 'यह शब्द पहले से मौजूद है। क्या आप इसमें यह नया अर्थ जोड़ना चाहते हैं?',
      'ar': 'هذه الكلمة موجودة بالفعل في المكتبة. هل تريد إضافة هذا المعنى الجديد إليها؟'
    },
    'Palavra salva com sucesso!': {
      'en': 'Word saved successfully!', 'de': 'Wort erfolgreich gespeichert!', 'es': '¡Palabra guardada con éxito!', 'fr': 'Mot enregistré avec succès !',
      'it': 'Parola salvata con successo!', 'ru': 'Слово успешно сохранено!', 'ja': '単語を保存しました！', 'zh-cn': '单词保存成功！',
      'ko': '단어가 성공적으로 저장되었습니다!', 'hi': 'शब्द सफलतापूर्वक सहेजा गया!', 'ar': 'تم حفظ الكلمة بنجاح!'
    },
    'Objeto de estudo salvo com sucesso!': {
      'en': 'Study object saved successfully!', 'de': 'Lernobjekt erfolgreich gespeichert!', 'es': '¡Objeto de estudio guardado con éxito!', 'fr': "Objet d'étude enregistré avec succès !",
      'it': 'Oggetto di studio salvato con successo!', 'ru': 'Объект изучения сохранен!', 'ja': '学習項目を保存しました！', 'zh-cn': '学习对象保存成功！',
      'ko': '학습 항목이 성공적으로 저장되었습니다!', 'hi': 'अध्ययन वस्तु सफलतापूर्वक सहेजी गई!', 'ar': 'تم حفظ عنصر الدراسة بنجاح!'
    },

    // --- TELA DE PRÁTICA (CLÁSSICO, PAPAGAIO, AFIADA, VISUAL, DESEMPENHO) ---
    'Modo Clássico': {
      'en': 'Classic Mode', 'de': 'Klassischer Modus', 'es': 'Modo Clásico', 'fr': 'Mode Classique',
      'it': 'Modalità Classica', 'ru': 'Классический режим', 'ja': 'クラシックモード', 'zh-cn': '经典模式',
      'ko': '클래식 모드', 'hi': 'क्लासिक मोड', 'ar': 'الوضع الكلاسيكي'
    },
    'Inverter': {
      'en': 'Reverse', 'de': 'Umkehren', 'es': 'Invertir', 'fr': 'Inverser',
      'it': 'Inverti', 'ru': 'Поменять местами', 'ja': '反転', 'zh-cn': '反转方向',
      'ko': '반전', 'hi': 'उलटें', 'ar': 'عكس'
    },
    'Inverter Modo': {
      'en': 'Switch Mode', 'de': 'Modus wechseln', 'es': 'Cambiar Modo', 'fr': 'Changer de mode',
      'it': 'Cambia Modalità', 'ru': 'Сменить режим', 'ja': 'モード切替', 'zh-cn': '切换模式',
      'ko': '모드 전환', 'hi': 'मोड बदलें', 'ar': 'تبديل الوضع'
    },
    'Sortear Palavra': {
      'en': 'Draw Word', 'de': 'Wort ziehen', 'es': 'Sortear Palabra', 'fr': 'Tirer un mot',
      'it': 'Estrai Parola', 'ru': 'Выбрать слово', 'ja': '単語を引く', 'zh-cn': '抽取单词',
      'ko': '단어 뽑기', 'hi': 'शब्द चुनें', 'ar': 'سحب كلمة'
    },
    'Sortear Objeto de Estudo': {
      'en': 'Draw Study Object', 'de': 'Lernobjekt ziehen', 'es': 'Sortear Objeto de Estudio', 'fr': 'Tirer un objet d\'étude',
      'it': 'Estrai Oggetto di Studio', 'ru': 'Выбрать объект изучения', 'ja': '学習項目を引く', 'zh-cn': '抽取学习对象',
      'ko': '학습 항목 뽑기', 'hi': 'अध्ययन वस्तु चुनें', 'ar': 'سحب عنصر دراسة'
    },
    'Clique acima para sortear': {
      'en': 'Click above to draw', 'de': 'Oben klicken zum Ziehen', 'es': 'Haz clic arriba para sortear', 'fr': 'Cliquez ci-dessus pour tirer',
      'it': 'Clicca sopra per estrarre', 'ru': 'Нажмите выше для выбора', 'ja': '上のボタンを押して開始', 'zh-cn': '点击上方按钮抽取',
      'ko': '위 버튼을 눌러 뽑기', 'hi': 'चुनने के लिए ऊपर क्लिक करें', 'ar': 'اضغط أعلاه للسحب'
    },
    'Sua Tradução': {
      'en': 'Your Translation', 'de': 'Deine Übersetzung', 'es': 'Tu Traducción', 'fr': 'Votre Traduction',
      'it': 'La Tua Traduzione', 'ru': 'Ваш перевод', 'ja': 'あなたの翻訳', 'zh-cn': '您的翻译',
      'ko': '번역 입력', 'hi': 'आपका अनुवाद', 'ar': 'ترجمتك'
    },
    'Sua Explicação': {
      'en': 'Your Explanation', 'de': 'Deine Erklärung', 'es': 'Tu Explicación', 'fr': 'Votre Explication',
      'it': 'La Tua Spiegazione', 'ru': 'Ваше объяснение', 'ja': 'あなたの説明', 'zh-cn': '您的解释',
      'ko': '설명 입력', 'hi': 'आपकी व्याख्या', 'ar': 'شرحك'
    },
    'Qual é o Objeto de Estudo?': {
      'en': 'What is the Study Object?', 'de': 'Was ist das Lernobjekt?', 'es': '¿Cuál es el Objeto de Estudio?', 'fr': "Quel est l'objet d'étude ?",
      'it': 'Qual è l\'Oggetto di Studio?', 'ru': 'Что это за объект изучения?', 'ja': '学習対象は何ですか？', 'zh-cn': '对应的学习对象是什么？',
      'ko': '학습 대상은 무엇입니까?', 'hi': 'अध्ययन वस्तु क्या है?', 'ar': 'ما هو عنصر الدراسة؟'
    },
    'Responder em': {
      'en': 'Answer in', 'de': 'Antworten auf', 'es': 'Responder en', 'fr': 'Répondre en',
      'it': 'Rispondi in', 'ru': 'Ответить на:', 'ja': '次で回答：', 'zh-cn': '回答语言：',
      'ko': '다음 언어로 답변:', 'hi': 'इसमें उत्तर दें:', 'ar': 'أجب بـ'
    },
    'Confirmar Resposta': {
      'en': 'Confirm Answer', 'de': 'Antwort bestätigen', 'es': 'Confirmar Respuesta', 'fr': 'Confirmer la réponse',
      'it': 'Conferma Risposta', 'ru': 'Подтвердить ответ', 'ja': '回答を確認', 'zh-cn': '确认回答',
      'ko': '답변 확인', 'hi': 'उत्तर की पुष्टि करें', 'ar': 'تأكيد الإجابة'
    },
    'Resposta Correta! 🎉': {
      'en': 'Correct Answer! 🎉', 'de': 'Richtige Antwort! 🎉', 'es': '¡Respuesta Correcta! 🎉', 'fr': 'Bonne Réponse ! 🎉',
      'it': 'Risposta Corretta! 🎉', 'ru': 'Правильный ответ! 🎉', 'ja': '正解です！ 🎉', 'zh-cn': '回答正确！ 🎉',
      'ko': '정답입니다! 🎉', 'hi': 'सही उत्तर! 🎉', 'ar': 'إجابة صحيحة! 🎉'
    },
    'Incorreta. O correto é:': {
      'en': 'Incorrect. Correct is:', 'de': 'Falsch. Richtig ist:', 'es': 'Incorrecta. Lo correcto es:', 'fr': 'Incorrect. La bonne réponse est :',
      'it': 'Sbagliato. Corretto:', 'ru': 'Неверно. Правильный ответ:', 'ja': '不正解。正解は：', 'zh-cn': '不正确。正确答案是：',
      'ko': '오답입니다. 정답:', 'hi': 'गलत। सही उत्तर है:', 'ar': 'غير صحيح. الإجابة الصحيحة هي:'
    },
    'ou': {
      'en': 'or', 'de': 'oder', 'es': 'o', 'fr': 'ou',
      'it': 'o', 'ru': 'или', 'ja': 'または', 'zh-cn': '或',
      'ko': '또는', 'hi': 'या', 'ar': 'أو'
    },
    'Desempenho': {
      'en': 'Performance', 'de': 'Leistung', 'es': 'Rendimiento', 'fr': 'Performance',
      'it': 'Rendimento', 'ru': 'Статистика', 'ja': '成績', 'zh-cn': '学习表现',
      'ko': '성과', 'hi': 'प्रदर्शन', 'ar': 'الأداء'
    },
    'Modo Papagaio': {
      'en': 'Parrot Mode', 'de': 'Papageienmodus', 'es': 'Modo Loro', 'fr': 'Mode Perroquet',
      'it': 'Modalità Pappagallo', 'ru': 'Режим Попугая', 'ja': 'オウムモード', 'zh-cn': '鹦鹉模式',
      'ko': '앵무새 모드', 'hi': 'तोता मोड', 'ar': 'وضع الببغاء'
    },
    'Desafio Visual': {
      'en': 'Visual Challenge', 'de': 'Bild-Herausforderung', 'es': 'Desafío Visual', 'fr': 'Défi Visuel',
      'it': 'Sfida Visiva', 'ru': 'Визуальный вызов', 'ja': 'ビジュアルチャレンジ', 'zh-cn': '视觉挑战',
      'ko': '비주얼 챌린지', 'hi': 'दृश्य चुनौती', 'ar': 'التحدي البصري'
    },
    'Sortear Imagem': {
      'en': 'Draw Image', 'de': 'Bild ziehen', 'es': 'Sortear Imagen', 'fr': 'Tirer une image',
      'it': 'Estrai Immagine', 'ru': 'Выбрать картинку', 'ja': '画像を引く', 'zh-cn': '抽取图片',
      'ko': '이미지 뽑기', 'hi': 'चित्र चुनें', 'ar': 'سحب صورة'
    },
    'Nenhum item com imagem encontrado nesta biblioteca! Adicione fotos aos seus registos para usar este modo.': {
      'en': 'No items with images found in this library! Add photos to your records to use this mode.',
      'de': 'Keine Einträge mit Bild gefunden! Füge Fotos hinzu, um diesen Modus zu nutzen.',
      'es': '¡No hay elementos con imagen en esta biblioteca! Añade fotos a tus registros para usar este modo.',
      'fr': 'Aucun élément avec image trouvé ! Ajoutez des photos pour utiliser ce mode.',
      'it': 'Nessun elemento con immagine trovato! Aggiungi foto ai tuoi record per usare questa modalità.',
      'ru': 'В этой библиотеке нет записей с изображениями! Добавьте фото к записям, чтобы использовать этот режим.',
      'ja': '画像付きの項目が見つかりません！このモードを使うには項目に写真を追加してください。',
      'zh-cn': '此库中未找到带图片的项目！请先为记录添加照片以使用此模式。',
      'ko': '이미지가 있는 항목이 없습니다! 이 모드를 사용하려면 항목에 사진을 추가하세요.',
      'hi': 'इस लाइब्रेरी में चित्र वाला कोई आइटम नहीं मिला! इस मोड का उपयोग करने के लिए फ़ोटो जोड़ें।',
      'ar': 'لم يتم العثور على عناصر بصور في هذه المكتبة! أضف صوراً إلى سجلاتك لاستخدام هذا الوضع.'
    },
    'Responder: Objeto de Estudo': {
      'en': 'Answer: Study Object', 'de': 'Antwort: Lernobjekt', 'es': 'Responder: Objeto', 'fr': 'Répondre : Objet',
      'it': 'Rispondi: Oggetto', 'ru': 'Ответ: Объект изучения', 'ja': '回答形式：学習対象', 'zh-cn': '回答：学习对象',
      'ko': '답변 방식: 학습 대상', 'hi': 'उत्तर: अध्ययन वस्तु', 'ar': 'الإجابة: عنصر الدراسة'
    },
    'Responder: Explicação': {
      'en': 'Answer: Explanation', 'de': 'Antwort: Erklärung', 'es': 'Responder: Explicación', 'fr': 'Répondre : Explication',
      'it': 'Rispondi: Spiegazione', 'ru': 'Ответ: Объяснение', 'ja': '回答形式：説明', 'zh-cn': '回答：解释',
      'ko': '답변 방식: 설명', 'hi': 'उत्तर: व्याख्या', 'ar': 'الإجابة: الشرح'
    },
    'Filtro de Palavras': {
      'en': 'Words Filter', 'de': 'Wortfilter', 'es': 'Filtro de Palabras', 'fr': 'Filtre de Mots',
      'it': 'Filtro Parole', 'ru': 'Фильтр слов', 'ja': '単語フィルター', 'zh-cn': '词库筛选',
      'ko': '단어 필터', 'hi': 'शब्द फ़िल्टर', 'ar': 'فلتر الكلمات'
    },
    'Velocidade da Voz': {
      'en': 'Voice Speed', 'de': 'Sprachgeschwindigkeit', 'es': 'Velocidad de Voz', 'fr': 'Vitesse de la voix',
      'it': 'Velocità Voce', 'ru': 'Скорость голоса', 'ja': '音声の速度', 'zh-cn': '语音速度',
      'ko': '음성 속도', 'hi': 'आवाज़ की गति', 'ar': 'سرعة الصوت'
    },
    'Lento (0.5x)': {
      'en': 'Slow (0.5x)', 'de': 'Langsam (0.5x)', 'es': 'Lento (0.5x)', 'fr': 'Lent (0.5x)',
      'it': 'Lento (0.5x)', 'ru': 'Медленно (0.5x)', 'ja': 'ゆっくり (0.5x)', 'zh-cn': '慢速 (0.5x)',
      'ko': '느리게 (0.5x)', 'hi': 'धीमा (0.5x)', 'ar': 'بطيء (0.5x)'
    },
    'Normal (1x)': {
      'en': 'Normal (1x)', 'de': 'Normal (1x)', 'es': 'Normal (1x)', 'fr': 'Normal (1x)',
      'it': 'Normale (1x)', 'ru': 'Нормально (1x)', 'ja': '標準 (1x)', 'zh-cn': '正常 (1x)',
      'ko': '보통 (1x)', 'hi': 'सामान्य (1x)', 'ar': 'عادي (1x)'
    },
    'Rápido (1.5x)': {
      'en': 'Fast (1.5x)', 'de': 'Schnell (1.5x)', 'es': 'Rápido (1.5x)', 'fr': 'Rapide (1.5x)',
      'it': 'Veloce (1.5x)', 'ru': 'Быстро (1.5x)', 'ja': '速い (1.5x)', 'zh-cn': '快速 (1.5x)',
      'ko': '빠르게 (1.5x)', 'hi': 'तेज़ (1.5x)', 'ar': 'سريع (1.5x)'
    },
    'Turbo (2x)': {
      'en': 'Turbo (2x)', 'de': 'Turbo (2x)', 'es': 'Turbo (2x)', 'fr': 'Turbo (2x)',
      'it': 'Turbo (2x)', 'ru': 'Турбо (2x)', 'ja': 'ターボ (2x)', 'zh-cn': '极速 (2x)',
      'ko': '터보 (2x)', 'hi': 'टर्बो (2x)', 'ar': 'توربو (2x)'
    },
    'Modo de Repetição': {
      'en': 'Repeat Mode', 'de': 'Wiederholungsmodus', 'es': 'Modo de Repetición', 'fr': 'Mode de Répétition',
      'it': 'Modalità Ripetizione', 'ru': 'Режим повтора', 'ja': 'リピートモード', 'zh-cn': '重复模式',
      'ko': '반복 모드', 'hi': 'दोहराव मोड', 'ar': 'وضع التكرار'
    },
    'Em Loop (Sorteio Infinito)': {
      'en': 'In Loop (Infinite Draw)', 'de': 'In Schleife (Endlos)', 'es': 'En Bucle (Sorteo Infinito)', 'fr': 'En Boucle (Infini)',
      'it': 'In Loop (Infinito)', 'ru': 'В цикле (Бесконечно)', 'ja': 'ループ（無限）', 'zh-cn': '循环播放（无限）',
      'ko': '무한 반복', 'hi': 'लूप में (अनंत)', 'ar': 'حلقة مستمرة (لا نهائي)'
    },
    '1 Sequência (Parar no fim)': {
      'en': '1 Sequence (Stop at end)', 'de': '1 Durchgang (Am Ende stoppen)', 'es': '1 Secuencia (Parar al final)', 'fr': '1 Séquence (Arrêter à la fin)',
      'it': '1 Sequenza (Ferma alla fine)', 'ru': '1 круг (Остановить в конце)', 'ja': '1回のみ（最後まで）', 'zh-cn': '单次序列（播完即停）',
      'ko': '1회 반복 (끝나면 정지)', 'hi': '1 अनुक्रम (अंत में रुकें)', 'ar': 'تسلسل واحد (التوقف في النهاية)'
    },
    'Iniciar Papagaio': {
      'en': 'Start Parrot', 'de': 'Papagei starten', 'es': 'Iniciar Loro', 'fr': 'Démarrer le Perroquet',
      'it': 'Avvia Pappagallo', 'ru': 'Запустить Попугая', 'ja': 'オウムを開始', 'zh-cn': '启动鹦鹉模式',
      'ko': '앵무새 시작', 'hi': 'तोता मोड शुरू करें', 'ar': 'بدء وضع الببغاء'
    },
    'Parar Papagaio': {
      'en': 'Stop Parrot', 'de': 'Papagei stoppen', 'es': 'Detener Loro', 'fr': 'Arrêter le Perroquet',
      'it': 'Ferma Pappagallo', 'ru': 'Остановить Попугая', 'ja': 'オウムを停止', 'zh-cn': '停止鹦鹉模式',
      'ko': '앵무새 정지', 'hi': 'तोता मोड रोकें', 'ar': 'إيقاف وضع الببغاء'
    },
    'Pronto para voar!': {
      'en': 'Ready to fly!', 'de': 'Bereit zum Fliegen!', 'es': '¡Listo para volar!', 'fr': 'Prêt à voler !',
      'it': 'Pronto a volare!', 'ru': 'Готов к полету!', 'ja': '準備完了！', 'zh-cn': '准备起飞！',
      'ko': '출발 준비 완료!', 'hi': 'उड़ान के लिए तैयार!', 'ar': 'جاهز للطيران!'
    },
    'Sua biblioteca está vazia!': {
      'en': 'Your library is empty!', 'de': 'Deine Bibliothek ist leer!', 'es': '¡Tu biblioteca está vacía!', 'fr': 'Votre bibliothèque est vide !',
      'it': 'La tua libreria è vuota!', 'ru': 'Ваша библиотека пуста!', 'ja': 'ライブラリが空です！', 'zh-cn': '您的词库为空！',
      'ko': '라이브러리가 비어 있습니다!', 'hi': 'आपकी लाइब्रेरी खाली है!', 'ar': 'مكتبتك فارغة!'
    },
    'Sequência Concluída!': {
      'en': 'Sequence Completed!', 'de': 'Sequenz abgeschlossen!', 'es': '¡Secuencia Completada!', 'fr': 'Séquence Terminée !',
      'it': 'Sequenza Completata!', 'ru': 'Цикл завершен!', 'ja': 'シーケンス完了！', 'zh-cn': '序列已完成！',
      'ko': '시퀀스 완료!', 'hi': 'अनुक्रम पूरा हुआ!', 'ar': 'اكتمل التسلسل!'
    },
    'Língua Afiada': {
      'en': 'Sharp Tongue', 'de': 'Scharfe Zunge', 'es': 'Lengua Afilada', 'fr': 'Langue Pendue',
      'it': 'Lingua Sciolta', 'ru': 'Острый язычок', 'ja': '発音チャレンジ', 'zh-cn': '口语挑战',
      'ko': '발음 챌린지', 'hi': 'तेज़ ज़ुबान (उच्चारण)', 'ar': 'تحدي النطق'
    },
    'Escrita Afiada': {
      'en': 'Sharp Writing', 'de': 'Scharfes Schreiben', 'es': 'Escritura Afilada', 'fr': 'Écriture Pointue',
      'it': 'Scrittura Rapida', 'ru': 'Точное письмо', 'ja': 'ディクテーション', 'zh-cn': '听写挑战',
      'ko': '받아쓰기 챌린지', 'hi': 'लेखन चुनौती', 'ar': 'تحدي الإملاء'
    },
    'Sortear Nova Palavra': {
      'en': 'Draw New Word', 'de': 'Neues Wort ziehen', 'es': 'Sortear Nueva Palabra', 'fr': 'Tirer un nouveau mot',
      'it': 'Estrai Nuova Parola', 'ru': 'Новое слово', 'ja': '新しい単語を引く', 'zh-cn': '抽取新单词',
      'ko': '새 단어 뽑기', 'hi': 'नया शब्द चुनें', 'ar': 'سحب كلمة جديدة'
    },
    'Sorteie para começar': {
      'en': 'Draw to start', 'de': 'Ziehen um zu starten', 'es': 'Sortea para empezar', 'fr': 'Tirez pour commencer',
      'it': 'Estrai per iniziare', 'ru': 'Выберите слово, чтобы начать', 'ja': '単語を引いて開始', 'zh-cn': '抽取单词以开始',
      'ko': '단어를 뽑아 시작하세요', 'hi': 'शुरू करने के लिए चुनें', 'ar': 'اسحب للبدء'
    },
    'Toque para falar': {
      'en': 'Tap to speak', 'de': 'Tippen zum Sprechen', 'es': 'Toca para hablar', 'fr': 'Appuyez pour parler',
      'it': 'Tocca per parlare', 'ru': 'Нажмите, чтобы говорить', 'ja': 'タップして話す', 'zh-cn': '点击说话',
      'ko': '탭하여 말하기', 'hi': 'बोलने के लिए टैप करें', 'ar': 'اضغط للتحدث'
    },
    'A escutar... Fale agora!': {
      'en': 'Listening... Speak now!', 'de': 'Höre zu... Sprich jetzt!', 'es': 'Escuchando... ¡Habla ahora!', 'fr': 'Écoute... Parlez maintenant !',
      'it': 'In ascolto... Parla ora!', 'ru': 'Слушаю... Говорите!', 'ja': '聞き取り中... 話してください！', 'zh-cn': '正在倾听... 请说话！',
      'ko': '듣는 중... 지금 말하세요!', 'hi': 'सुन रहा हूँ... अब बोलें!', 'ar': 'جارٍ الاستماع... تحدث الآن!'
    },
    'Reconhecimento indisponível no telemóvel.': {
      'en': 'Speech recognition unavailable on this device.', 'de': 'Spracherkennung auf diesem Gerät nicht verfügbar.', 'es': 'Reconocimiento de voz no disponible en el dispositivo.', 'fr': 'Reconnaissance vocale indisponible sur cet appareil.',
      'it': 'Riconoscimento vocale non disponibile sul dispositivo.', 'ru': 'Распознавание речи недоступно на устройстве.', 'ja': 'この端末では音声認識を利用できません。', 'zh-cn': '此设备不支持语音识别。',
      'ko': '이 기기에서 음성 인식을 사용할 수 없습니다.', 'hi': 'इस डिवाइस पर वॉइस पहचान उपलब्ध नहीं है।', 'ar': 'التعرف على الصوت غير متاح على هذا الجهاز.'
    },
    'Pronúncia Perfeita! 🎉': {
      'en': 'Perfect Pronunciation! 🎉', 'de': 'Perfekte Aussprache! 🎉', 'es': '¡Pronunciación Perfecta! 🎉', 'fr': 'Prononciation Parfaite ! 🎉',
      'it': 'Pronuncia Perfetta! 🎉', 'ru': 'Идеальное произношение! 🎉', 'ja': '完璧な発音です！ 🎉', 'zh-cn': '发音完美！ 🎉',
      'ko': '완벽한 발음입니다! 🎉', 'hi': 'सटीक उच्चारण! 🎉', 'ar': 'نطق مثالي! 🎉'
    },
    'Escrita Perfeita! 🎉': {
      'en': 'Perfect Writing! 🎉', 'de': 'Perfektes Schreiben! 🎉', 'es': '¡Escritura Perfecta! 🎉', 'fr': 'Écriture Parfaite ! 🎉',
      'it': 'Scrittura Perfetta! 🎉', 'ru': 'Безупречное написание! 🎉', 'ja': '完璧な記述です！ 🎉', 'zh-cn': '拼写完美！ 🎉',
      'ko': '완벽한 받아쓰기입니다! 🎉', 'hi': 'सटीक लेखन! 🎉', 'ar': 'كتابة مثالية! 🎉'
    },
    'Digite o que ouviu': {
      'en': 'Type what you heard', 'de': 'Tippe, was du gehört hast', 'es': 'Escribe lo que escuchaste', 'fr': 'Tapez ce que vous avez entendu',
      'it': 'Scrivi ciò che hai sentito', 'ru': 'Введите услышанное', 'ja': '聞こえた通りに入力', 'zh-cn': '输入您听到的内容',
      'ko': '들린 내용을 입력하세요', 'hi': 'जो सुना वह टाइप करें', 'ar': 'اكتب ما سمعته'
    },
    'Entendemos:': {
      'en': 'We heard:', 'de': 'Verstanden:', 'es': 'Entendimos:', 'fr': 'Nous avons compris :',
      'it': 'Abbiamo capito:', 'ru': 'Распознано:', 'ja': '認識結果：', 'zh-cn': '识别为：',
      'ko': '인식된 내용:', 'hi': 'हमने सुना:', 'ar': 'سمعنا:'
    },
    'Seu Desempenho': {
      'en': 'Your Performance', 'de': 'Deine Leistung', 'es': 'Tu Rendimiento', 'fr': 'Votre Performance',
      'it': 'Il Tuo Rendimento', 'ru': 'Ваша статистика', 'ja': 'あなたの成績', 'zh-cn': '您的学习表现',
      'ko': '나의 학습 성과', 'hi': 'आपका प्रदर्शन', 'ar': 'أداؤك'
    },
    'Desempenho de Hoje': {
      'en': 'Performance Today', 'de': 'Leistung Heute', 'es': 'Rendimiento de Hoy', 'fr': "Performances d'aujourd'hui",
      'it': 'Rendimento di Oggi', 'ru': 'Статистика за сегодня', 'ja': '今日の成績', 'zh-cn': '今日表现',
      'ko': '오늘의 성과', 'hi': 'आज का प्रदर्शन', 'ar': 'أداء اليوم'
    },
    'Últimos 7 Dias': {
      'en': 'Last 7 Days', 'de': 'Letzte 7 Tage', 'es': 'Últimos 7 Días', 'fr': 'Les 7 Derniers Jours',
      'it': 'Ultimi 7 Giorni', 'ru': 'Последние 7 дней', 'ja': '過去7日間', 'zh-cn': '过去 7 天',
      'ko': '최근 7일', 'hi': 'पिछले 7 दिन', 'ar': 'آخر 7 أيام'
    },
    'Histórico Mensal': {
      'en': 'Monthly History', 'de': 'Monatlicher Verlauf', 'es': 'Historial Mensual', 'fr': 'Historique Mensuel',
      'it': 'Storico Mensile', 'ru': 'История по месяцам', 'ja': '月間履歴', 'zh-cn': '月度历史',
      'ko': '월간 기록', 'hi': 'मासिक इतिहास', 'ar': 'السجل الشهري'
    },
    'Nenhuma atividade.': {
      'en': 'No activity.', 'de': 'Keine Aktivität.', 'es': 'Sin actividad.', 'fr': 'Aucune activité.',
      'it': 'Nessuna attività.', 'ru': 'Нет активности.', 'ja': 'アクティビティなし。', 'zh-cn': '暂无记录。',
      'ko': '활동 내역이 없습니다.', 'hi': 'कोई गतिविधि नहीं।', 'ar': 'لا يوجد نشاط.'
    },
    'Nenhum dado mensal.': {
      'en': 'No monthly data.', 'de': 'Keine Monatsdaten.', 'es': 'Sin datos mensuales.', 'fr': 'Aucune donnée mensuelle.',
      'it': 'Nessun dato mensile.', 'ru': 'Нет месячных данных.', 'ja': '月間データなし。', 'zh-cn': '暂无月度数据。',
      'ko': '월간 데이터가 없습니다.', 'hi': 'कोई मासिक डेटा नहीं।', 'ar': 'لا توجد بيانات شهرية.'
    },
    'Perguntas Respondidas:': {
      'en': 'Questions Answered:', 'de': 'Beantwortete Fragen:', 'es': 'Preguntas Respondidas:', 'fr': 'Questions répondues :',
      'it': 'Domande Risposte:', 'ru': 'Отвечено вопросов:', 'ja': '回答数：', 'zh-cn': '已答问题：',
      'ko': '답변한 문제:', 'hi': 'उत्तर दिए गए प्रश्न:', 'ar': 'الأسئلة المجابة:'
    },
    'Acertos / Erros:': {
      'en': 'Hits / Misses:', 'de': 'Treffer / Fehler:', 'es': 'Aciertos / Errores:', 'fr': 'Réussites / Échecs :',
      'it': 'Corrette / Errori:', 'ru': 'Верно / Ошибки:', 'ja': '正解 / 不正解：', 'zh-cn': '正确 / 错误：',
      'ko': '정답 / 오답:', 'hi': 'सही / गलत:', 'ar': 'صحيحة / خاطئة:'
    },
    'Combos Especiais 🎉:': {
      'en': 'Special Combos 🎉:', 'de': 'Spezielle Kombos 🎉:', 'es': 'Combos Especiales 🎉:', 'fr': 'Combos Spéciaux 🎉 :',
      'it': 'Combo Speciali 🎉:', 'ru': 'Супер-комбо 🎉:', 'ja': 'スペシャルコンボ 🎉：', 'zh-cn': '特殊连击 🎉：',
      'ko': '스페셜 콤보 🎉:', 'hi': 'स्पेशल कॉम्बो 🎉:', 'ar': 'مجموعات خاصة 🎉:'
    },
    'Tempo no Papagaio 🦜:': {
      'en': 'Parrot Time 🦜:', 'de': 'Papageienzeit 🦜:', 'es': 'Tiempo en Loro 🦜:', 'fr': 'Temps Perroquet 🦜 :',
      'it': 'Tempo Pappagallo 🦜:', 'ru': 'Время в Попугае 🦜:', 'ja': 'オウムモード時間 🦜：', 'zh-cn': '鹦鹉模式时长 🦜：',
      'ko': '앵무새 모드 시간 🦜:', 'hi': 'तोता मोड समय 🦜:', 'ar': 'وقت الببغاء 🦜:'
    },

    // --- TELA DE BIBLIOTECA E EDIÇÃO ---
    'registradas': {
      'en': 'registered', 'de': 'registriert', 'es': 'registradas', 'fr': 'enregistrés',
      'it': 'registrate', 'ru': 'сохранено', 'ja': '件登録済み', 'zh-cn': '已记录',
      'ko': '개 등록됨', 'hi': 'दर्ज', 'ar': 'مسجلة'
    },
    'Pesquisar...': {
      'en': 'Search...', 'de': 'Suchen...', 'es': 'Buscar...', 'fr': 'Rechercher...',
      'it': 'Cerca...', 'ru': 'Поиск...', 'ja': '検索...', 'zh-cn': '搜索...',
      'ko': '검색...', 'hi': 'खोजें...', 'ar': 'بحث...'
    },
    'Nenhuma palavra encontrada.': {
      'en': 'No items found.', 'de': 'Keine Einträge gefunden.', 'es': 'No se encontraron elementos.', 'fr': 'Aucun élément trouvé.',
      'it': 'Nessun elemento trovato.', 'ru': 'Ничего не найдено.', 'ja': '項目が見つかりません。', 'zh-cn': '未找到相关项目。',
      'ko': '항목을 찾을 수 없습니다.', 'hi': 'कोई आइटम नहीं मिला।', 'ar': 'لم يتم العثور على عناصر.'
    },
    'Editar Palavra': {
      'en': 'Edit Word', 'de': 'Wort bearbeiten', 'es': 'Editar Palabra', 'fr': 'Modifier le mot',
      'it': 'Modifica Parola', 'ru': 'Редактировать слово', 'ja': '単語を編集', 'zh-cn': '编辑单词',
      'ko': '단어 편집', 'hi': 'शब्द संपादित करें', 'ar': 'تعديل الكلمة'
    },
    'Editar Objeto': {
      'en': 'Edit Object', 'de': 'Objekt bearbeiten', 'es': 'Editar Objeto', 'fr': "Modifier l'objet",
      'it': 'Modifica Oggetto', 'ru': 'Редактировать объект', 'ja': '項目を編集', 'zh-cn': '编辑对象',
      'ko': '항목 편집', 'hi': 'वस्तु संपादित करें', 'ar': 'تعديل العنصر'
    },
    'Salvar Alterações': {
      'en': 'Save Changes', 'de': 'Änderungen speichern', 'es': 'Guardar Cambios', 'fr': 'Enregistrer les modifications',
      'it': 'Salva Modifiche', 'ru': 'Сохранить изменения', 'ja': '変更を保存', 'zh-cn': '保存更改',
      'ko': '변경사항 저장', 'hi': 'परिवर्तन सहेजें', 'ar': 'حفظ التغييرات'
    },
    'Alterações salvas!': {
      'en': 'Changes saved!', 'de': 'Änderungen gespeichert!', 'es': '¡Cambios guardados!', 'fr': 'Modifications enregistrées !',
      'it': 'Modifiche salvate!', 'ru': 'Изменения сохранены!', 'ja': '変更を保存しました！', 'zh-cn': '更改已保存！',
      'ko': '변경사항이 저장되었습니다!', 'hi': 'परिवर्तन सहेजे गए!', 'ar': 'تم حفظ التغييرات!'
    },
    'Significado': {
      'en': 'Meaning', 'de': 'Bedeutung', 'es': 'Significado', 'fr': 'Signification',
      'it': 'Significato', 'ru': 'Значение', 'ja': '意味', 'zh-cn': '含义',
      'ko': '의미', 'hi': 'अर्थ', 'ar': 'المعنى'
    },
    'Explicação': {
      'en': 'Explanation', 'de': 'Erklärung', 'es': 'Explicación', 'fr': 'Explication',
      'it': 'Spiegazione', 'ru': 'Объяснение', 'ja': '説明', 'zh-cn': '解释',
      'ko': '설명', 'hi': 'व्याख्या', 'ar': 'الشرح'
    },
    'Palavra Principal': {
      'en': 'Main Word', 'de': 'Hauptwort', 'es': 'Palabra Principal', 'fr': 'Mot Principal',
      'it': 'Parola Principale', 'ru': 'Основное слово', 'ja': 'メインの単語', 'zh-cn': '主单词',
      'ko': '주요 단어', 'hi': 'मुख्य शब्द', 'ar': 'الكلمة الرئيسية'
    },
    'Objeto Principal': {
      'en': 'Main Object', 'de': 'Hauptobjekt', 'es': 'Objeto Principal', 'fr': 'Objet Principal',
      'it': 'Oggetto Principale', 'ru': 'Основной объект', 'ja': 'メイン項目', 'zh-cn': '主要对象',
      'ko': '주요 대상', 'hi': 'मुख्य वस्तु', 'ar': 'العنصر الرئيسي'
    },
    'Significados Registrados:': {
      'en': 'Registered Meanings:', 'de': 'Registrierte Bedeutungen:', 'es': 'Significados Registrados:', 'fr': 'Significations Enregistrées :',
      'it': 'Significati Registrati:', 'ru': 'Сохраненные значения:', 'ja': '登録された意味：', 'zh-cn': '已记录的含义：',
      'ko': '등록된 의미:', 'hi': 'दर्ज किए गए अर्थ:', 'ar': 'المعاني المسجلة:'
    },
    'Explicações Registradas:': {
      'en': 'Registered Explanations:', 'de': 'Registrierte Erklärungen:', 'es': 'Explicaciones Registradas:', 'fr': 'Explications Enregistrées :',
      'it': 'Spiegazioni Registrate:', 'ru': 'Сохраненные объяснения:', 'ja': '登録された説明：', 'zh-cn': '已记录的解释：',
      'ko': '등록된 설명:', 'hi': 'दर्ज की गई व्याख्याएँ:', 'ar': 'الشروحات المسجلة:'
    },
    'Alterar Foto': {
      'en': 'Change Photo', 'de': 'Foto ändern', 'es': 'Cambiar Foto', 'fr': 'Changer la photo',
      'it': 'Cambia Foto', 'ru': 'Изменить фото', 'ja': '写真を変更', 'zh-cn': '更换照片',
      'ko': '사진 변경', 'hi': 'फ़ोटो बदलें', 'ar': 'تغيير الصورة'
    },
    'Adicionar Foto': {
      'en': 'Add Photo', 'de': 'Foto hinzufügen', 'es': 'Añadir Foto', 'fr': 'Ajouter une photo',
      'it': 'Aggiungi Foto', 'ru': 'Добавить фото', 'ja': '写真を追加', 'zh-cn': '添加照片',
      'ko': '사진 추가', 'hi': 'फ़ोटो जोड़ें', 'ar': 'إضافة صورة'
    },
    'Remover Imagem': {
      'en': 'Remove Image', 'de': 'Bild entfernen', 'es': 'Eliminar Imagen', 'fr': 'Supprimer l\'image',
      'it': 'Rimuovi Immagine', 'ru': 'Удалить изображение', 'ja': '画像を削除', 'zh-cn': '移除图片',
      'ko': '이미지 삭제', 'hi': 'चित्र हटाएं', 'ar': 'إزالة الصورة'
    },
    'Excluir Palavra': {
      'en': 'Delete Word', 'de': 'Wort löschen', 'es': 'Eliminar Palabra', 'fr': 'Supprimer le mot',
      'it': 'Elimina Parola', 'ru': 'Удалить слово', 'ja': '単語を削除', 'zh-cn': '删除单词',
      'ko': '단어 삭제', 'hi': 'शब्द हटाएं', 'ar': 'حذف الكلمة'
    },
    'Excluir Palavra?': {
      'en': 'Delete Word?', 'de': 'Wort löschen?', 'es': '¿Eliminar Palabra?', 'fr': 'Supprimer le mot ?',
      'it': 'Eliminare Parola?', 'ru': 'Удалить слово?', 'ja': '単語を削除しますか？', 'zh-cn': '删除单词？',
      'ko': '단어를 삭제하시겠습니까?', 'hi': 'शब्द हटाएं?', 'ar': 'حذف الكلمة؟'
    },
    'Excluir Objeto': {
      'en': 'Delete Object', 'de': 'Objekt löschen', 'es': 'Eliminar Objeto', 'fr': "Supprimer l'objet",
      'it': 'Elimina Oggetto', 'ru': 'Удалить объект', 'ja': '項目を削除', 'zh-cn': '删除对象',
      'ko': '항목 삭제', 'hi': 'वस्तु हटाएं', 'ar': 'حذف العنصر'
    },
    'Excluir Objeto?': {
      'en': 'Delete Object?', 'de': 'Objekt löschen?', 'es': '¿Eliminar Objeto?', 'fr': "Supprimer l'objet ?",
      'it': 'Eliminare Oggetto?', 'ru': 'Удалить объект?', 'ja': '項目を削除しますか？', 'zh-cn': '删除对象？',
      'ko': '항목을 삭제하시겠습니까?', 'hi': 'वस्तु हटाएं?', 'ar': 'حذف العنصر؟'
    },
    'Deseja apagar este objeto de estudo e todas as suas explicações?': {
      'en': 'Do you want to delete this study object and all its explanations?',
      'de': 'Möchten Sie dieses Lernobjekt und alle zugehörigen Erklärungen löschen?',
      'es': '¿Deseas eliminar este objeto de estudio y todas sus explicaciones?',
      'fr': 'Voulez-vous supprimer cet objet d\'étude et toutes ses explications ?',
      'it': 'Vuoi eliminare questo oggetto di studio e tutte le sue spiegazioni?',
      'ru': 'Удалить этот объект изучения и все его объяснения?',
      'ja': 'この学習項目とすべての説明を削除しますか？',
      'zh-cn': '确定要删除此学习对象及其所有解释吗？',
      'ko': '이 학습 항목과 모든 설명을 삭제하시겠습니까?',
      'hi': 'क्या आप इस अध्ययन वस्तु और इसकी सभी व्याख्याओं को हटाना चाहते हैं?',
      'ar': 'هل تريد حذف عنصر الدراسة هذا وجميع شروحاته؟'
    },
    'Deseja apagar esta palavra e TODOS os seus significados nesta língua?': {
      'en': 'Do you want to delete this word and ALL its meanings in this language?',
      'de': 'Möchten Sie dieses Wort und ALLE seine Bedeutungen in dieser Sprache löschen?',
      'es': '¿Deseas eliminar esta palabra y TODOS sus significados en este idioma?',
      'fr': 'Voulez-vous supprimer ce mot et TOUTES ses significations dans cette langue ?',
      'it': 'Vuoi eliminare questa parola e TUTTI i suoi significati in questa lingua?',
      'ru': 'Удалить это слово и ВСЕ его значения на этом языке?',
      'ja': 'この言語でのこの単語とすべての意味を削除しますか？',
      'zh-cn': '确定要删除此语言中的该单词及其所有含义吗？',
      'ko': '이 언어에서 이 단어와 모든 의미를 삭제하시겠습니까?',
      'hi': 'क्या आप इस भाषा में इस शब्द और इसके सभी अर्थों को हटाना चाहते हैं?',
      'ar': 'هل تريد حذف هذه الكلمة وجميع معانيها في هذه اللغة؟'
    },
    'Cancelar': {
      'en': 'Cancel', 'de': 'Abbrechen', 'es': 'Cancelar', 'fr': 'Annuler',
      'it': 'Annulla', 'ru': 'Отмена', 'ja': 'キャンセル', 'zh-cn': '取消',
      'ko': '취소', 'hi': 'रद्द करें', 'ar': 'إلغاء'
    },
    'Sim': {
      'en': 'Yes', 'de': 'Ja', 'es': 'Sí', 'fr': 'Oui',
      'it': 'Sì', 'ru': 'Да', 'ja': 'はい', 'zh-cn': '是',
      'ko': '예', 'hi': 'हाँ', 'ar': 'نعم'
    },
    'Excluir': {
      'en': 'Delete', 'de': 'Löschen', 'es': 'Eliminar', 'fr': 'Supprimer',
      'it': 'Elimina', 'ru': 'Удалить', 'ja': '削除', 'zh-cn': '删除',
      'ko': '삭제', 'hi': 'हटाएं', 'ar': 'حذف'
    },
    'Treino Inteligente': {
      'en': 'Smart Training', 'de': 'Intelligentes Training', 'es': 'Entrenamiento Inteligente', 'fr': 'Entraînement Intelligent',
      'it': 'Allenamento Intelligente', 'ru': 'Умная тренировка', 'ja': 'スマートトレーニング', 'zh-cn': '智能训练',
      'ko': '스마트 트레이닝', 'hi': 'स्मार्ट प्रशिक्षण', 'ar': 'التدريب الذكي'
    },
    'Priorizar os itens que você mais erra': {
      'en': 'Prioritize the items you miss the most', 'de': 'Priorisiere Einträge, die du oft falsch machst', 'es': 'Priorizar los elementos que más fallas', 'fr': 'Privilégier les éléments que vous ratez le plus',
      'it': 'Dai priorità agli elementi che sbagli di più', 'ru': 'Приоритет словам, в которых вы чаще ошибаетесь', 'ja': '間違いやすい項目を優先して出題', 'zh-cn': '优先抽取您最常出错的项目',
      'ko': '자주 틀리는 항목 우선 출제', 'hi': 'उन वस्तुओं को प्राथमिकता दें जिनमें आप अधिक गलती करते हैं', 'ar': 'إعطاء الأولوية للعناصر التي تخطئ فيها كثيراً'
    },
    'Bom (Verde)': {
      'en': 'Good (Green)', 'de': 'Gut (Grün)', 'es': 'Bueno (Verde)', 'fr': 'Bon (Vert)',
      'it': 'Buono (Verde)', 'ru': 'Хорошо (Зеленый)', 'ja': '良好（緑）', 'zh-cn': '良好（绿色）',
      'ko': '좋음 (초록)', 'hi': 'अच्छा (हरा)', 'ar': 'جيد (أخضر)'
    },
    'Médio (Amarelo)': {
      'en': 'Medium (Yellow)', 'de': 'Mittel (Gelb)', 'es': 'Medio (Amarillo)', 'fr': 'Moyen (Jaune)',
      'it': 'Medio (Giallo)', 'ru': 'Средне (Желтый)', 'ja': '普通（黄）', 'zh-cn': '中等（黄色）',
      'ko': '보통 (노랑)', 'hi': 'मध्यम (पीला)', 'ar': 'متوسط (أصفر)'
    },
    'Ruim (Vermelho)': {
      'en': 'Bad (Red)', 'de': 'Schlecht (Rot)', 'es': 'Deficiente (Rojo)', 'fr': 'Mauvais (Rouge)',
      'it': 'Difficile (Rosso)', 'ru': 'Сложно (Красный)', 'ja': '苦手（赤）', 'zh-cn': '薄弱（红色）',
      'ko': '어려움 (빨강)', 'hi': 'कठिन (लाल)', 'ar': 'ضعيف (أحمر)'
    },
    'Dificuldade Atual:': {
      'en': 'Current Difficulty:', 'de': 'Aktuelle Schwierigkeit:', 'es': 'Dificultad Actual:', 'fr': 'Difficulté Actuelle :',
      'it': 'Difficoltà Attuale:', 'ru': 'Текущая сложность:', 'ja': '現在の難易度：', 'zh-cn': '当前难度：',
      'ko': '현재 난이도:', 'hi': 'वर्तमान कठिनाई:', 'ar': 'الصعوبة الحالية:'
    },

    // --- BACKUP E RESTAURO ---
    'Backup e Restauro': {
      'en': 'Backup and Restore', 'de': 'Sicherung & Wiederherstellung', 'es': 'Copia de Seguridad', 'fr': 'Sauvegarde et Restauration',
      'it': 'Backup e Ripristino', 'ru': 'Резервная копия', 'ja': 'バックアップと復元', 'zh-cn': '备份与恢复',
      'ko': '백업 및 복원', 'hi': 'बैकअप और रीस्टोर', 'ar': 'النسخ الاحتياطي والاستعادة'
    },
    'Exportar': {
      'en': 'Export', 'de': 'Exportieren', 'es': 'Exportar', 'fr': 'Exporter',
      'it': 'Esporta', 'ru': 'Экспорт', 'ja': 'エクスポート', 'zh-cn': '导出',
      'ko': '내보내기', 'hi': 'निर्यात करें', 'ar': 'تصدير'
    },
    'Importar': {
      'en': 'Import', 'de': 'Importieren', 'es': 'Importar', 'fr': 'Importer',
      'it': 'Importa', 'ru': 'Импорт', 'ja': 'インポート', 'zh-cn': '导入',
      'ko': '가져오기', 'hi': 'आयात करें', 'ar': 'استيراد'
    },
    'Backup importado com sucesso!': {
      'en': 'Backup imported successfully!',
      'de': 'Backup erfolgreich importiert!',
      'es': '¡Copia importada con éxito!',
      'fr': 'Sauvegarde importée avec succès !',
      'it': 'Backup importato con successo!',
      'ru': 'Резервная копия успешно импортирована!',
      'ja': 'バックアップをインポートしました！',
      'zh-cn': '备份导入成功！',
      'ko': '백업을 성공적으로 가져왔습니다!',
      'hi': 'बैकअप सफलतापूर्वक आयात किया गया!',
      'ar': 'تم استيراد النسخة الاحتياطية بنجاح!'
    },
    'Nenhum backup selecionado ou falha na importação.': {
      'en': 'No backup selected or import failed.',
      'de': 'Kein Backup ausgewählt oder Import fehlgeschlagen.',
      'es': 'Ninguna copia seleccionada o fallo en la importación.',
      'fr': 'Aucune sauvegarde sélectionnée ou échec de l\'importation.',
      'it': 'Nessun backup selezionato o importazione fallita.',
      'ru': 'Файл не выбран или ошибка импорта.',
      'ja': 'バックアップが選択されていないか、インポートに失敗しました。',
      'zh-cn': '未选择备份文件或导入失败。',
      'ko': '선택된 백업이 없거나 가져오기에 실패했습니다.',
      'hi': 'कोई बैकअप नहीं चुना गया या आयात विफल रहा।',
      'ar': 'لم يتم تحديد نسخة احتياطية أو فشل الاستيراد.'
    },
  };
  return dict[text]?[code] ?? text;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseHelper.instance;
  await db.initMediaDirectory();
  await db.limparDadosAntigos();
  await carregarConfiguracoesGlobaisDoBanco();

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
            final isRtl = supportedLanguages[currentNativeLang]?.transCode == 'ar';
            return MaterialApp(
              title: 'MemoryWord',
              debugShowCheckedModeBanner: false,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: currentMode,
              builder: (context, widgetChild) {
                return Directionality(
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  child: widgetChild ?? const SizedBox.shrink(),
                );
              },
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
          builder: (context, lang, child) {
            return Center(
              child: Text(getStudyFlagOrIcon(lang), style: const TextStyle(fontSize: 26)),
            );
          },
        ),
        title: ValueListenableBuilder<String>(
          valueListenable: appLanguage,
          builder: (context, lang, child) {
            if (isCustomStudy(lang)) {
              return Text(
                getStudyDisplayName(lang),
                overflow: TextOverflow.ellipsis,
              );
            }
            return const Text('MemoryWord');
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: t("Configurações"),
            onPressed: _abrirConfiguracoes,
          )
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: appDataVersion,
        builder: (context, dataVer, child) {
          return ValueListenableBuilder<String>(
            valueListenable: appLanguage,
            builder: (context, currentLang, child) {
              return PageView(
                key: ValueKey('pageview_$dataVer'),
                controller: _mainPageController,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                children: [
                  RegisterTab(currentLang: currentLang),
                  PracticeTab(currentLang: currentLang),
                  LibraryTab(currentLang: currentLang),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _mainPageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
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
  bool _isAutoNext = true;
  bool _isBusyBackup = false;
  String _filtro = 'todas';
  bool _modoTemaLivre = false;
  String _idiomaSelecionado = 'Inglês';
  String _temaLivreSelecionado = '';
  List<String> _temasLivres = [];
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
    final idiomaAtual = await db.getConfig('idioma_atual');
    final idiomaNativo = await db.getConfig('idioma_nativo');
    final feedback = await db.getConfig('feedback_ativo');
    final autoNext = await db.getConfig('avanco_automatico');
    final listaTemas = await db.getTemasLivres();

    if (!mounted) return;
    setState(() {
      _isDark = tema == 'dark';
      _filtro = filtro.isEmpty ? 'todas' : filtro;
      _customCtrl.text = customVal;
      _temasLivres = listaTemas;

      if (isCustomStudy(idiomaAtual)) {
        _modoTemaLivre = true;
        String nomeTema = getStudyDisplayName(idiomaAtual);
        if (!_temasLivres.contains(nomeTema)) {
          _temasLivres.add(nomeTema);
        }
        _temaLivreSelecionado = nomeTema;
      } else {
        _modoTemaLivre = false;
        _idiomaSelecionado = supportedLanguages.containsKey(idiomaAtual) ? idiomaAtual : 'Inglês';
        if (_temasLivres.isNotEmpty) {
          _temaLivreSelecionado = _temasLivres.first;
        }
      }

      _idiomaNativoSelecionado = supportedLanguages.containsKey(idiomaNativo) ? idiomaNativo : 'Português';
      _isFeedbackEnabled = (feedback.isEmpty || feedback == 'true');
      _isAutoNext = (autoNext.isEmpty || autoNext == 'true');
    });
  }

  Future<void> _criarNovoTemaDialog() async {
    final ctrl = TextEditingController();
    String? novoNome = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t("Criar Tema")),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: t("Nome do Objeto / Assunto de Estudo"),
            hintText: t("Ex: Anatomia, Direito, História..."),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t("Cancelar"))),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: Text(t("Confirmar")),
          ),
        ],
      ),
    );

    if (novoNome != null && novoNome.isNotEmpty) {
      String limpo = novoNome.replaceAll('|', '').replaceAll('tema:', '').trim();
      if (limpo.isEmpty) return;
      if (!_temasLivres.contains(limpo)) {
        setState(() {
          _temasLivres.add(limpo);
          _temaLivreSelecionado = limpo;
        });
        await DatabaseHelper.instance.salvarTemasLivres(_temasLivres);
      } else {
        setState(() => _temaLivreSelecionado = limpo);
      }
    }
  }

  Future<void> _renomearTemaDialog() async {
    if (_temaLivreSelecionado.isEmpty) return;
    final ctrl = TextEditingController(text: _temaLivreSelecionado);
    String? novoNome = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t("Renomear")),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: t("Novo nome do tema"),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t("Cancelar"))),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim()),
            child: Text(t("Salvar")),
          ),
        ],
      ),
    );

    if (novoNome != null && novoNome.isNotEmpty && novoNome != _temaLivreSelecionado) {
      String limpo = novoNome.replaceAll('|', '').replaceAll('tema:', '').trim();
      if (limpo.isEmpty) return;
      String antigo = _temaLivreSelecionado;
      await DatabaseHelper.instance.renomearTemaLivre(antigo, limpo);
      final atualizados = await DatabaseHelper.instance.getTemasLivres();
      if (!mounted) return;
      setState(() {
        _temasLivres = atualizados;
        _temaLivreSelecionado = limpo;
      });
      if (appLanguage.value == 'tema:$antigo') {
        appLanguage.value = 'tema:$limpo';
      }
    }
  }

  Future<void> _excluirTemaDialog() async {
    if (_temaLivreSelecionado.isEmpty) return;
    bool? conf = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("${t('Excluir')} '$_temaLivreSelecionado'?"),
        content: Text(t("Deseja apagar este tema e todos os objetos de estudo registados nele?")),
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
      String removido = _temaLivreSelecionado;
      await DatabaseHelper.instance.excluirTemaLivre(removido);
      final atualizados = await DatabaseHelper.instance.getTemasLivres();
      if (!mounted) return;
      setState(() {
        _temasLivres = atualizados;
        _temaLivreSelecionado = _temasLivres.isNotEmpty ? _temasLivres.first : '';
        if (_temaLivreSelecionado.isEmpty) {
          _modoTemaLivre = false;
        }
      });
      if (appLanguage.value == 'tema:$removido') {
        appLanguage.value = _temaLivreSelecionado.isNotEmpty ? 'tema:$_temaLivreSelecionado' : _idiomaSelecionado;
      }
    }
  }

  Future<void> _salvar() async {
    if (_filtro == 'custom') {
      int? val = int.tryParse(_customCtrl.text.trim());
      if (val == null || val <= 0) {
        return;
      }
    }

    if (_modoTemaLivre && _temaLivreSelecionado.trim().isEmpty) {
      await _criarNovoTemaDialog();
      if (_temaLivreSelecionado.trim().isEmpty) return;
    }

    String targetStudyKey = _modoTemaLivre ? 'tema:$_temaLivreSelecionado' : _idiomaSelecionado;

    try {
      final db = DatabaseHelper.instance;
      await db.updateConfig('tema', _isDark ? 'dark' : 'light');
      await db.updateConfig('filtro', _filtro);
      await db.updateConfig('custom_val', _customCtrl.text.trim());
      await db.updateConfig('idioma_atual', targetStudyKey);
      await db.updateConfig('idioma_nativo', _idiomaNativoSelecionado);
      await db.updateConfig('feedback_ativo', _isFeedbackEnabled ? 'true' : 'false');
      await db.updateConfig('avanco_automatico', _isAutoNext ? 'true' : 'false');

      appThemeMode.value = _isDark ? ThemeMode.dark : ThemeMode.light;
      appLanguage.value = targetStudyKey;
      appNativeLanguage.value = _idiomaNativoSelecionado;
      appFeedbackEnabled.value = _isFeedbackEnabled;
      appAutoNext.value = _isAutoNext;

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Configurações salvas!'))));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t("Categoria de Estudo"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment<bool>(
                      value: false,
                      icon: const Icon(Icons.translate),
                      label: Text(t("Idiomas")),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: const Icon(Icons.school),
                      label: Text(t("Estudo Livre")),
                    ),
                  ],
                  selected: {_modoTemaLivre},
                  onSelectionChanged: (Set<bool> newSelection) async {
                    bool isFree = newSelection.first;
                    setState(() => _modoTemaLivre = isFree);
                    if (isFree && _temasLivres.isEmpty) {
                      await _criarNovoTemaDialog();
                    }
                  },
                ),
              ),
              const SizedBox(height: 15),

              if (!_modoTemaLivre) ...[
                Text(t("Idioma de Estudo Principal"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey('lang_${_idiomaSelecionado}_$_idiomaNativoSelecionado'),
                  initialValue: _idiomaSelecionado,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  items: supportedLanguages.keys.map((lang) {
                    return DropdownMenuItem(
                      value: lang,
                      child: Text("${supportedLanguages[lang]!.flag} ${t('Aprender')} ${t(lang)}"),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _idiomaSelecionado = val);
                  },
                ),
              ] else ...[
                Text(t("Tema de Estudo Personalizado"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_temasLivres.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: ValueKey('topic_$_temaLivreSelecionado'),
                    initialValue: _temasLivres.contains(_temaLivreSelecionado) ? _temaLivreSelecionado : _temasLivres.first,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                    items: _temasLivres.map((tema) {
                      return DropdownMenuItem(
                        value: tema,
                        child: Text("🎓 $tema"),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _temaLivreSelecionado = val);
                    },
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(t("Criar Tema")),
                      onPressed: _criarNovoTemaDialog,
                    ),
                    if (_temaLivreSelecionado.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(t("Renomear")),
                        onPressed: _renomearTemaDialog,
                      ),
                    if (_temaLivreSelecionado.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: t("Excluir"),
                        onPressed: _excluirTemaDialog,
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 20),
              Text(t("Seu Idioma (Origem)"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('native_$_idiomaNativoSelecionado'),
                initialValue: _idiomaNativoSelecionado,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                ),
                items: supportedLanguages.keys.map((lang) {
                  return DropdownMenuItem(
                    value: lang,
                    child: Text("${supportedLanguages[lang]!.flag} ${t('Falar')} ${t(lang)}"),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _idiomaNativoSelecionado = val);
                    appNativeLanguage.value = val;
                  }
                },
              ),

              const Divider(height: 30),
              Text(t("Preferências"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t("Modo Noturno")),
                value: _isDark,
                onChanged: (val) => setState(() => _isDark = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t("Som e Vibração")),
                value: _isFeedbackEnabled,
                onChanged: (val) => setState(() => _isFeedbackEnabled = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t("Sorteio Automático após Responder")),
                subtitle: Text(t("Desative para avançar manualmente no seu ritmo"), style: const TextStyle(fontSize: 12)),
                value: _isAutoNext,
                onChanged: (val) => setState(() => _isAutoNext = val),
              ),

              const Divider(height: 30),
              Text(t("Filtro de Sorteio (Global)"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                key: ValueKey('filter_${_filtro}_$_idiomaNativoSelecionado'),
                initialValue: _filtro,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                ),
                items: [
                  DropdownMenuItem(value: 'todas', child: Text(t("Todas as palavras"))),
                  DropdownMenuItem(value: '10', child: Text(t("Últimas 10"))),
                  DropdownMenuItem(value: '20', child: Text(t("Últimas 20"))),
                  DropdownMenuItem(value: '30', child: Text(t("Últimas 30"))),
                  DropdownMenuItem(value: 'custom', child: Text(t("Personalizado"))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _filtro = val);
                },
              ),

              if (_filtro == 'custom')
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: _customCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t("Nº Personalizado (> 0)"),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),

              const Divider(height: 30),
              Text(t("Backup e Restauro"), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (_isBusyBackup)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: Text(t("Exportar")),
                      onPressed: () async {
                        setState(() => _isBusyBackup = true);
                        await DatabaseHelper.instance.exportarBackup();
                        if (mounted) setState(() => _isBusyBackup = false);
                      },
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: Text(t("Importar")),
                      onPressed: () async {
                        setState(() => _isBusyBackup = true);
                        bool sucesso = await DatabaseHelper.instance.importarBackup();
                        if (sucesso) {
                          await carregarConfiguracoesGlobaisDoBanco();
                        }
                        if (!context.mounted) return;
                        setState(() => _isBusyBackup = false);
                        if (sucesso) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t('Backup importado com sucesso!')),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pop(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t('Nenhum backup selecionado ou falha na importação.')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),

              const Divider(height: 30),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _salvar,
                  child: Text(t("Salvar")),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}