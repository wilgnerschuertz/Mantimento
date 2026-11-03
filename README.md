# Qwen Local

Cliente local e agente de desenvolvimento offline. Versão atual: macOS Apple Silicon,
SwiftUI, MLX e Qwen3.5. Histórico Git local na branch `main`.

## Desenvolvimento

- `bash source/build.sh`: compila o aplicativo macOS e aplica assinatura local.
- `python3 tests/run.py`: testes isolados do agente, sem modelo e sem tocar nos chats reais.
- `TEST_MODEL=1 python3 tests/run.py`: exige servidor MLX de teste em `127.0.0.1:12346`.
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
