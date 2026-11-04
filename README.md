# Mantimento

**Conhecimento e ferramentas, mesmo sem conexão.**

Mantimento é um aplicativo para usar modelos de IA no próprio Mac, consultar documentos e trabalhar com arquivos locais. A proposta é manter ferramentas úteis disponíveis mesmo quando serviços online estiverem fora do ar.

O aplicativo Mac oferece conversa com IA, agente de arquivos e terminal e kit de recuperação offline. Uma prévia **Windows x64** está em validação, com interface nativa e seleção **CPU / GPU (Vulkan) / Automático**.

| Plataforma | Versão | Motor |
| --- | --- | --- |
| macOS Apple Silicon | [0.2.1](https://github.com/wilgnerschuertz/Mantimento/releases/tag/v0.2.1) | MLX · aplicativo SwiftUI |
| Windows 10/11 x64 | [Prévia Windows: instruções e estado](windows/README.md) | llama.cpp · CPU ou GPU Vulkan · aplicativo WPF |

Os pacotes são independentes. Um `.app` não executa no Windows, e os modelos MLX e GGUF têm formatos diferentes. Não há sincronização automática entre máquinas.

[Baixar a versão 0.2.1](https://github.com/wilgnerschuertz/Mantimento/releases/tag/v0.2.1) · [Novidades da versão](RELEASE-0.2.1.md) · [Relatar problema ou sugerir melhoria](https://github.com/wilgnerschuertz/Mantimento/issues/new/choose)

## Instalação no Mac

### Requisitos

| Item | Requisito |
| --- | --- |
| Computador | Mac com Apple Silicon: M1, M2, M3, M4 ou posterior |
| Sistema | Compilado para macOS 14 ou posterior; outras versões e máquinas ainda precisam de validação |
| Memória | 16 GB recomendados; o consumo depende do modelo e do tamanho da conversa |
| Armazenamento | Espaço para o aplicativo, ambiente e modelos; cada modelo ocupa vários GB |
| Internet | Necessária para o preparo inicial e os downloads; dispensável para conversar com modelos já instalados |

**Não é necessário instalar Python, Homebrew ou ferramentas de desenvolvimento para usar o aplicativo.** O Mantimento prepara seu próprio ambiente. O pacote macOS não funciona em Mac Intel, Windows, Linux ou iOS. Para Windows, veja as [instruções da prévia x64](windows/LEIA-ME-WINDOWS.md).

### Instalação

1. Abra a [release 0.2.1](https://github.com/wilgnerschuertz/Mantimento/releases/tag/v0.2.1).
2. Em **Assets**, baixe `Mantimento-0.2.1-macOS-arm64.zip`. Os arquivos **Source code** são o código-fonte, não o aplicativo pronto.
3. Descompacte o ZIP e arraste **Mantimento.app** para **Aplicativos**.
4. Abra o app e siga o guia **Preparar ambiente**.
5. Em **Modelos**, baixe um modelo. Para começar, sugerimos **Qwen3.5 2B**.
6. Clique em **Usar**, volte a **Conversa** e escolha **Iniciar modelo**.
7. Escreva sua mensagem e envie com **⌘ Return**.

O primeiro preparo e a primeira resposta podem demorar mais. Depois de baixar o modelo, teste uma conversa com o Wi-Fi desligado para confirmar que seu ambiente está pronto para uso offline.

### Primeira abertura no macOS

O aplicativo usa assinatura local **ad hoc**, sem Developer ID e sem notarização Apple. O macOS pode bloquear a abertura. Se você confiar na origem do download, siga a [orientação oficial da Apple](https://support.apple.com/102445) para permitir a abertura desse aplicativo em **Ajustes do Sistema → Privacidade e Segurança**. Não é necessário desativar as proteções do sistema globalmente.

## O que você pode fazer

| Área | Funcionalidades |
| --- | --- |
| **Conversa** | Respostas com streaming, histórico, busca e exportação de conversas; Markdown básico e cópia de código |
| **Modelos** | Catálogo MLX, busca, filtro por família, informações de tamanho/memória, download e remoção para a Lixeira |
| **Documentos** | Leitura de texto e PDF textual, pesquisa literal e criação/edição de arquivos pelo agente |
| **Agente** | Ferramentas de arquivos e terminal, pasta por conversa, revisão de propostas e backups de edições |
| **Backup offline** | Exportação de aplicativo, Python gerenciado, dependências e modelos para restauração sem internet |
| **Ajustes** | Temas Sistema/Claro/Escuro, tamanho da resposta, criatividade e registros separados |

A interface se adapta ao tamanho da janela, com barra lateral recolhível. Ao rolar uma resposta manualmente, o acompanhamento automático pausa; **Última mensagem** leva você de volta ao final. O campo de mensagem cresce até um limite para preservar a área de leitura.

## Escolha um modelo

O catálogo inclui modelos da [MLX Community no Hugging Face](https://huggingface.co/mlx-community). Os tamanhos são aproximados e podem mudar; a interface consulta o tamanho atual antes de baixar.

| Modelo | Download aproximado | Uso sugerido | Validação no Mantimento |
| --- | --- | --- | --- |
| Qwen3.5 2B · 4 bits | 1,8 GB | Consultas e tarefas curtas | Conversa testada |
| Qwen3.5 4B · 4 bits | 3,1 GB | Uso geral | Experimental |
| Qwen3.5 9B · 4 bits | 6,0 GB | Programação e ferramentas | Agente testado |
| Llama 3.2 3B · 4 bits | 1,8 GB | Conversa e escrita | Inferência offline testada; uso geral experimental |
| Phi-4 Mini · 4 bits | 2,2 GB | Texto e código | Inferência offline testada; uso geral experimental |

“Testado” descreve os cenários já verificados, não garante a qualidade de todas as respostas. A capacidade de usar ferramentas varia entre modelos. Um modelo fica carregado por vez.

Em **Adicionar outro modelo MLX**, informe `organização/modelo` do Hugging Face ou escolha uma pasta local. O modelo precisa ser compatível com **MLX-LM**; arquivos GGUF e modelos que exigem outros motores não são suportados. Confira os detalhes e a licença de cada modelo antes de redistribuí-lo.

## Trabalhe com seus arquivos

1. Abra uma conversa e escolha a pasta pelo menu de pasta no topo.
2. Selecione **Agente**.
3. Comece com **Revisar ações** e peça uma tarefa específica, por exemplo: “Leia os textos desta pasta e crie um resumo em resumo.md”.
4. Confira as propostas de arquivos e comandos antes de aprovar.

Cada conversa recebe uma pasta interna por padrão, que você pode trocar. A ferramenta de escrita mantém backups das edições em `.qwen-backups` dentro da pasta de trabalho.

**Controle total** permite executar arquivos e comandos sem aprovação, com as permissões do seu usuário. O terminal não tem sandbox e seus comandos podem acessar recursos fora da pasta da conversa. Os backups da ferramenta de escrita não cobrem alterações feitas pelo terminal. Esse modo não inclui controle visual de outros aplicativos.

## Prepare um kit offline

Uma instalação nova normalmente precisa de internet. Para poder restaurar o Mantimento sem conexão, prepare um kit antecipadamente:

1. Com internet, prepare o ambiente e baixe os modelos que deseja guardar.
2. Desligue o modelo e abra **Backup offline**.
3. Execute **Preparar pacotes**.
4. Escolha se deseja incluir conversas e documentos das pastas internas.
5. Clique em **Escolher destino e exportar…** e guarde a pasta gerada em um local com espaço suficiente.

O kit contém o aplicativo, Python gerenciado, pacotes, modelos e um manifesto SHA-256. Não inclui conversas por padrão, nem documentos de pastas externas. **O kit não é criptografado**; revise seu conteúdo antes de compartilhar e observe as licenças dos modelos.

Para restaurar em outro Mac Apple Silicon, abra o Terminal na pasta do kit e execute:

```sh
bash restaurar.sh
```

O destino padrão é `~/Library/Application Support/Mantimento` e precisa estar ausente. Para testar sem sobrescrever dados, informe uma pasta nova:

```sh
bash restaurar.sh "/caminho/novo/Mantimento"
```

A restauração verifica hashes e recria o ambiente com os pacotes locais. Depois, copie o aplicativo para Aplicativos. A interface usa a pasta padrão; um destino personalizado serve para testes ou execução do runtime com `MANTIMENTO_DATA`. Caminhos antigos de pastas de trabalho podem precisar ser selecionados novamente.

## Seus dados e a atualização do Qwen Local

A conversa com o modelo é processada no Mac. O preparo e os downloads acessam serviços externos; comandos executados pelo agente também podem acessar a rede.

Instalações novas guardam os dados em `~/Library/Application Support/Mantimento/`. Quem já usava Qwen Local continua usando `~/Library/Application Support/QwenLocal/` enquanto a pasta nova não existir. O app reaproveita conversas, modelos e ambiente, sem exigir que você mova o Python ou baixe os modelos outra vez.

Feche o aplicativo antigo antes de abrir o novo. Os dois podem compartilhar dados e a porta do servidor. As mensagens antigas sem identificação do modelo aparecem como **Assistente**; novas respostas preservam o nome do modelo utilizado.

## Limites atuais

- PDFs digitalizados exigem OCR externo. Sem edição nativa de Word ou planilhas.
- Pesquisa literal e contexto limitados; arquivos e saídas grandes podem ser truncados.
- Agente com até 12 etapas por solicitação e tempo limitado por comando. Não use o agente para manter servidores persistentes.
- Instalar novas dependências de um projeto pode exigir internet, mesmo com o modelo offline.
- Remover um modelo o move para a Lixeira; blobs compartilhados do cache podem permanecer.
- Testes em outro Mac e em versões mais antigas do macOS continuam necessários.

## Teste e contribua

Encontrou um problema? Use os [formulários de Issues](https://github.com/wilgnerschuertz/Mantimento/issues/new/choose) e informe versão do app, chip, RAM, macOS, modelo e passos para reproduzir. **Revise os registros antes de anexar:** eles podem conter caminhos, comandos e documentos privados.

Para ajudar com a avaliação inicial, siga o [roteiro de testes beta](TESTES-BETA.md). Sugestões e contribuições são bem-vindas. O foco é melhorar a experiência no Mac e no Windows e a disponibilidade offline. iOS e Linux continuam como possibilidades futuras, ainda sem pacote próprio.

### Desenvolvimento

Para compilar, use um Mac Apple Silicon com ferramentas de linha de comando Swift instaladas:

```sh
bash source/build.sh      # Compila o app com assinatura local
bash source/package.sh    # Gera ZIP e checksum em dist/
python3 tests/run.py      # Histórico, migração, arquivos e agente em pasta isolada
python3 tests/stream.py   # Integridade e agrupamento do streaming
python3 tests/models.py   # Cache, download e remoção recuperável
```

Para revisão visual isolada, execute `python3 tests/layout_preview.py chat` ou `fresh` e abra `dist/LayoutPreview.app`. Os testes de inferência/agente real e de restauração offline exigem modelos e ambiente já preparados; consulte [VALIDACAO-0.2.0.md](VALIDACAO-0.2.0.md).

O código usa SwiftUI/AppKit na interface e MLX-LM em um ambiente Python gerenciado para inferência. Modelos, ambientes, conversas, aplicativos compilados e arquivos de `dist/` ficam fora do Git.
