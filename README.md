# Mantimento

Conhecimento e ferramentas, mesmo sem conexão.

Mantimento é um aplicativo local para guardar e usar recursos digitais: hoje, modelos
de IA e ferramentas de desenvolvimento; futuramente, outros acervos offline. Versão atual: macOS Apple Silicon,
SwiftUI, MLX e Qwen3.5. Histórico Git local na branch `main`.

## Interface 0.2.1 em avaliação

Navegação separada para Conversa, Modelos e Backup offline, com ajustes próprios,
temas e layout adaptável. Consulte [RELEASE-0.2.1.md](RELEASE-0.2.1.md).
Para revisão visual isolada: `python3 tests/layout_preview.py chat` ou `fresh`;
abra `dist/LayoutPreview.app`. O cenário usa uma pasta temporária e não conversa
com um servidor. A compilação do produto continua em `bash source/package.sh`.

## Catálogo e kit offline: 0.2.0

Catálogo de modelos MLX, gerenciamento de downloads e kit de recuperação offline.
Consulte [RELEASE-0.2.0.md](RELEASE-0.2.0.md) e o roteiro [TESTES-BETA.md](TESTES-BETA.md).
Relate problemas pelas [Issues](https://github.com/wilgnerschuertz/Mantimento/issues/new/choose).
Os modelos Llama/Phi do catálogo vêm da [MLX Community](https://huggingface.co/mlx-community);
a licença e as instruções de cada modelo estão no link Detalhes da interface.

## Distribuição de teste 0.1.1 — Mantimento

Consulte `RELEASE-0.1.1.md`. Gere o ZIP com `bash source/package.sh`.
O arquivo em `dist/` deve ser anexado aos Assets da release, separado do código-fonte.
A distribuição inicial é Apple Silicon, sem Developer ID/notarização.

## Desenvolvimento

- `bash source/build.sh`: compila o aplicativo macOS e aplica assinatura local.
- `python3 tests/run.py`: testes isolados do agente, sem modelo e sem tocar nos chats reais.
- `TEST_MODEL=1 python3 tests/run.py`: exige servidor MLX de teste em `127.0.0.1:12346`.
- `python3 tests/models.py`: cache, revisão fixa, espaço e remoção recuperável.
- `python3 tests/stream.py`: integridade e atualização de streaming.
- Consulte `LEIA-ME.txt` para instalação, uso, permissões e limites.

Modelos, conversas e ambientes ficam fora do repositório. O `.app` é um artefato
de compilação e não é versionado. GitHub Desktop pode abrir esta pasta como
repositório local. Publicação no GitHub é uma etapa separada.

## Prioridade atual: macOS nativo e preparação futura para iOS

Manter SwiftUI e MLX no Mac. Priorizar fluidez de interface, ferramentas locais,
medição e instalação offline. iOS exigirá motor nativo e permissões próprias;
o processo Python e o terminal do Mac não são portáveis diretamente ao iPhone.

## Proposta futura: macOS, Windows e Linux (adiada)

**Proposta adiada, ainda não implementada.** O aplicativo atual roda somente em macOS.
Um `.app` não pode ser executado diretamente em Windows ou Linux.

1. Interface compartilhada em Tauri, com instaladores próprios para cada sistema.
2. Contrato comum para motores locais, preservando MLX no Mac e adicionando
   `llama.cpp` com modelos GGUF para Windows/Linux e, opcionalmente, macOS.
3. Núcleo de ferramentas compartilhado com adaptadores por plataforma:
   terminal (zsh/bash/PowerShell), processos, caminhos, permissões e documentos.
4. Migração versionada das conversas e pastas existentes, sem perda dos dados.
5. Instalação, testes e empacotamento em cada sistema. Confirmar execução offline
   após reiniciar, com modelos e dependências previamente disponíveis.

A biblioteca PDFKit e a interface AppKit/SwiftUI atuais precisam de alternativas
portáveis. O executor Python atual depende de zsh e grupos POSIX: ainda não é um
executor Windows. A migração não consiste apenas em recompilar o código atual.

## Referências

- Tauri: https://tauri.app/start/prerequisites/
- llama.cpp: https://github.com/ggml-org/llama.cpp
- MLX: https://ml-explore.github.io/mlx/build/html/install.html

## Atualização de Qwen Local para Mantimento

O aplicativo agora se chama `Mantimento.app`, com bundle ID `local.mantimento.mac`.
A identidade do autor nas mensagens continua Qwen quando esse é o modelo utilizado.
Instalações novas usam `~/Library/Application Support/Mantimento/`. Instalações
existentes reaproveitam `~/Library/Application Support/QwenLocal/` se a pasta nova
não existir: ambientes Python não são movidos, e modelos não precisam ser baixados
novamente. Preferências de modelos do bundle antigo são importadas somente quando
não há uma configuração atual. Pastas de trabalho já escolhidas são preservadas.
A variável `MANTIMENTO_DATA` permite escolher a raiz de dados; `QWEN_LOCAL_DATA`
continua aceita por compatibilidade com scripts antigos.

O nome anterior permanece no histórico Git e nas notas arquivadas da versão 0.1.0.
