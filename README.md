# MemoryWord 📱🌍🎓

O **MemoryWord** é um aplicativo móvel de alta performance desenvolvido de raiz em **Flutter (Dart)** e integrado com uma base de dados local SQLite. O que começou como uma ferramenta para estudantes de inglês evoluiu para um **compêndio dinâmico e inteligente focado na memorização de 12 idiomas e qualquer outro campo de estudo** (Anatomia, Direito, História, etc.). Ele ajuda a testar, memorizar e organizar vocabulário ou conceitos de forma altamente interativa.

---

## 🚀 Funcionalidades Principais

* 🌍 **Suporte a Múltiplos Idiomas e RTL:** 
  * Aprenda e traduza entre 12 idiomas: Inglês, Alemão, Espanhol, Português, Francês, Italiano, Russo, Japonês, Chinês (Mandarim), Coreano, Hindi e Árabe.
  * Suporte nativo e automático para layout RTL (Right-to-Left) quando o idioma de origem for o Árabe.
* 🎓 **Modo de Estudo Livre (Categorias Personalizadas):** 
  * Crie e gira bibliotecas independentes para aprender qualquer assunto (ex: Direito, Programação, Anatomia).
  * O sistema adapta a interface dinamicamente: em vez de pedir "Traduções", pede "Explicações/Definições" e oculta o tradutor automático.
* 📝 **Registo Inteligente e Multimédia:** 
  * **Tradução Automática:** Botão integrado com a API do Google Translate para preenchimento rápido (modo Idiomas).
  * **Imagens:** Adicione fotos da **Câmera** ou da **Galeria** para reforçar a memória visual.
  * **Múltiplos Significados:** Associe várias definições ou traduções ao mesmo registo.
* 🧠 **Treino Inteligente (Smart Training):** 
  * Algoritmo integrado que prioriza os itens que você mais erra, garantindo uma curva de aprendizagem eficiente baseada em repetição espaçada.
* 🎮 **Modos de Prática Dinâmicos:**
  * **Modo Clássico:** Teste escrito tradicional com respostas validadas em tempo real. Avanço manual ou automático.
  * **Modo Papagaio (Parrot Mode):** Treino auditivo "mãos livres" com Text-to-Speech (TTS). Lê o termo e a resposta em loop ou sequência, com velocidade de voz controlável.
  * **Desafio Visual:** Sorteia exclusivamente as imagens cadastradas para que o utilizador adivinhe a palavra ou conceito correspondente.
  * **Língua Afiada:** Teste de pronúncia avaliado através de reconhecimento de voz nativo (Speech-to-Text).
  * **Escrita Afiada:** Teste de ditado para treinar a audição e escrita (Listen & Type).
* 📊 **Dashboard de Desempenho:**
  * Acompanhe estatísticas diárias, dos últimos 7 dias e o histórico mensal.
  * Monitorize perguntas respondidas, acertos/erros, tempo gasto no Modo Papagaio e "Combos Especiais".
* 💾 **Backup e Restauro:**
  * Exporte ou importe toda a sua base de dados `.db` de forma 100% offline e segura, garantindo que nunca perde o seu progresso ou registos ao trocar de dispositivo.
* ⚙️ **Customização:** 
  * Modo Claro e Modo Noturno (Dark Mode).
  * Filtros de sorteio customizáveis (todas, últimas 10/20/30 ou limite livre).
  * Controlo absoluto sobre feedback sonoro e vibração (Haptic Feedback).

---

## 🛠️ Tecnologias Utilizadas

* **Dart & Flutter:** Linguagem principal e framework de interface nativa e fluida.
* **SQLite (`sqflite`):** Base de dados relacional e armazenamento local super rápido.
* **`flutter_tts`:** Motor avançado de Text-to-Speech (Síntese de voz) para múltiplos idiomas.
* **`speech_to_text`:** Integração com os sistemas de reconhecimento vocal do iOS e Android.
* **`translator`:** Tradução assíncrona automática via Google Translate.
* **`audioplayers`:** Execução responsiva de efeitos sonoros (acertos, erros, combos).
* **`image_picker` & `path_provider`:** Acesso e gestão otimizada do sistema de arquivos para imagens locais.
* **`file_picker` & `share_plus`:** Gestão nativa para extração e injeção do ficheiro de Backup SQLite.

---
