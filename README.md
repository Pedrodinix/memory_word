# MemoryWord 📱🇬🇧

O **MemoryWord** é um aplicativo móvel de alta performance desenvolvido de raiz em **Flutter (Dart)** e integrado com uma base de dados local SQLite. Foi concebido especificamente para funcionar como um compêndio dinâmico e inteligente para estudantes de inglês, ajudando a memorizar, testar e organizar vocabulário novo de forma interativa.

---

## 🚀 Funcionalidades Principais

* 📝 **Novo (Registo de Palavras):** 
  * Permite inserir uma palavra em inglês e o respetivo significado.
  * **Tradução Automática:** Botão integrado com tradutor online para preencher a tradução instantaneamente.
  * **Captura Multimédia:** Adiciona imagens associadas diretamente da **Câmara** ou da **Galeria** para reforçar a aprendizagem visual.
  * **Gestão de Significados:** Suporte para adicionar múltiplos significados à mesma palavra caso já exista na biblioteca.
* 🧠 **Praticar (Randomizador / Quiz):** 
  * Ferramenta de treino interativa que sorteia aleatoriamente as palavras guardadas com base em filtros personalizáveis (todas, últimas 10/20/30 ou limite personalizado).
  * O utilizador escreve a tradução e o aplicativo valida a resposta em tempo real, revelando o resultado e a imagem associada em caso de erro ou acerto.
* 📚 **Biblioteca (Pesquisa Dinâmica e Gestão):** 
  * Repositório completo que reúne todas as palavras e imagens guardadas.
  * **Pesquisa em Tempo Real:** Barra de pesquisa integrada que filtra instantaneamente por texto em inglês ou tradução.
  * Opções avançadas para visualizar detalhes, editar significados, alterar imagens ou eliminar registos.
* ⚙️ **Configurações e Temas:** 
  * Alternância dinâmica entre **Modo Claro e Modo Noturno (Dark Mode)** em tempo real.
  * Definição de filtros de sorteio personalizados para o treino.

---

## 🛠️ Tecnologias Utilizadas

* **Dart** (Linguagem de programação principal)
* **Flutter** (Framework de interface gráfica nativa)
* **SQLite (`sqflite`)** (Base de dados local otimizada)
* **`image_picker`** (Acesso nativo a câmara e galeria)
* **`google_translator`** (Integração com tradução online)
* **`path_provider`** (Gestão de diretórios locais para armazenamento de imagens)

---

## 📥 Como Executar o Projeto

1. Certifica-te de que tens o **Flutter SDK** e o **Android Studio** instalados no teu computador.
2. Clona este repositório:
   ```bash
   git clone [https://github.com/Pedrodinix/memory_word.git](https://github.com/Pedrodinix/memory_word.git)