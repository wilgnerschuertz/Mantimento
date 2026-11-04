# Mantimento para Windows — 0.3.0 Preview 1

Primeira prévia nativa para **Windows x64**, com seleção **CPU / GPU / Automático**. O aplicativo Mac continua disponível na [versão 0.2.1](https://github.com/wilgnerschuertz/Mantimento/releases/tag/v0.2.1), com SwiftUI e MLX.

## Download e instalação

Baixe **Mantimento-0.3.0-preview.1-Windows-x64.zip** em **Assets** e extraia a pasta inteira. Abra **Mantimento.exe** dentro dela. Não copie apenas o executável: o pacote inclui o runtime .NET e os motores de inferência.

Não é necessário instalar Python, .NET, Node, CUDA ou SDK Vulkan para usar o aplicativo. A opção GPU precisa de um driver Vulkan compatível do fabricante da placa.

O ZIP não inclui modelos. Abra **Modelos**, baixe **Qwen3.5 0.8B**, selecione **Usar** e clique em **Iniciar modelo**. Envie sua mensagem com **Ctrl+Enter**. Depois do download, teste uma conversa sem internet.

## Escolha o processamento

| Modo | Comportamento |
| --- | --- |
| **CPU** | Opção inicial mais compatível; não precisa de placa dedicada. Motor compilado sem exigir AVX/AVX2. |
| **GPU** | Usa Vulkan quando existe uma GPU/driver compatível. Falha com mensagem clara se a inicialização não funcionar. |
| **Automático** | Tenta GPU e volta para CPU se a detecção ou inicialização falhar. |

O aplicativo informa o modo efetivo. Desligue o modelo antes de trocar. GPU permanece **experimental**: não foi validada em placas físicas NVIDIA, AMD e Intel. VRAM, RAM, drivers e o tamanho do modelo determinam o que pode rodar; “x64” não garante que qualquer modelo tenha memória ou velocidade suficientes.

## Funcionalidades

- Interface Windows nativa, conversa com streaming, histórico, busca e cópia de respostas.
- Catálogo GGUF com Qwen3.5 **0.8B, 2B e 9B**, aproximadamente **0,53 / 1,28 / 5,68 GB**.
- Download com retomada, verificação de espaço e SHA-256 antes de instalar.
- Importação de GGUF local e remoção recuperável dos modelos do catálogo pela Lixeira.
- Pasta por conversa; agente com leitura, pesquisa e criação/edição de texto UTF-8.
- Revisão de arquivos e comandos PowerShell, backups de escrita e interrupção de tarefas.
- Temas claro, escuro e do sistema; importação/exportação de uma conversa JSON.
- Servidor restrito a 127.0.0.1 com autenticação temporária. O chat não envia conversas a um serviço de IA externo.

## Requisitos

Windows 10/11 em processador **x64**. Comece com **8 GB de RAM** e o modelo 0.8B; prefira **16 GB ou mais** para modelos maiores. Reserve espaço adicional para o app, modelos e execução.

Windows ARM64, 32 bits, versões antigas do Windows e GPUs sem Vulkan compatível não fazem parte desta prévia. A possibilidade de executar não equivale a suporte da Microsoft a toda edição/build do Windows 10; prefira sistemas atualizados e suportados.

O pacote ainda não tem assinatura Authenticode. O Windows pode mostrar um aviso de reputação: confira a origem e o checksum. Não é necessário desativar as proteções globalmente.

Para conferir o ZIP no PowerShell:

```powershell
Get-FileHash .\Mantimento-0.3.0-preview.1-Windows-x64.zip -Algorithm SHA256
```

Compare o resultado com o arquivo `.zip.sha256` anexado.

## Dados, documentos e permissões

Dados ficam em `%LOCALAPPDATA%\Mantimento`. Não há sincronização automática entre Windows e Mac. As conversas JSON importadas recebem uma nova pasta de trabalho; documentos e modelos não são transferidos.

Os modelos Windows usam **GGUF**, enquanto o app Mac usa **MLX**. Não copie os pesos de um formato esperando carregá-los no outro.

Mantenha **Controle total desmarcado** para revisar escritas e comandos. O terminal tem as permissões do usuário e não possui sandbox; seus comandos podem acessar outros locais e a rede. Os backups de escrita não cobrem alterações feitas por comandos de terminal.

## Diferenças para o Mac

Esta primeira versão Windows ainda não tem leitura PDF/OCR, edição Word/planilhas nem a tela de exportação do kit offline do Mac. O agente tem contexto limitado, até 12 etapas e comandos finitos de até 60 segundos. O uso de ferramentas varia com o modelo; pesos GGUF e GPU precisam de avaliação adicional.

## Testes e relatos

A distribuição passa por compilação Windows, testes do núcleo, snapshots de interface, inferência GGUF por CPU e tentativa do modo Automático. Esses testes não substituem a avaliação na sua máquina e não são um teste de aceleração em GPU física.

Use os [formulários de Issues](https://github.com/wilgnerschuertz/Mantimento/issues/new/choose) para informar Windows, CPU, RAM, GPU/driver, modo, modelo e passos para reproduzir. Revise os registros antes de anexar: podem conter caminhos e conteúdo privado.
