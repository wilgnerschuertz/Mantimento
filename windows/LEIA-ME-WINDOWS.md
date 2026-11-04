# Mantimento para Windows · 0.3.0-preview.1

Prévia nativa para Windows x64. O Mac continua usando o aplicativo SwiftUI/MLX da versão 0.2.1.

## Instalar e usar

1. Baixe o ZIP **Mantimento-0.3.0-preview.1-Windows-x64.zip** e extraia a pasta inteira.
2. Abra **Mantimento.exe** dentro da pasta extraída. Não copie só o executável: o runtime e os motores ficam ao lado dele.
3. Abra **Modelos** e baixe **Qwen3.5 0.8B** para um primeiro teste leve.
4. Clique em **Usar**, volte a **Conversa** e escolha **Iniciar modelo**.
5. Envie com **Ctrl+Enter**. Depois de baixar o modelo, teste com a internet desligada.

Não precisa instalar Python, .NET, Node, CUDA ou o SDK Vulkan para usar o pacote. O runtime .NET é incluído. O modo GPU precisa de driver Vulkan compatível fornecido pelo fabricante da sua placa. O SDK Vulkan é usado apenas na compilação.

O executável ainda não possui assinatura de distribuição Windows. O sistema pode exibir aviso de reputação. Confira origem e checksum do download; não desative proteções globalmente.

## CPU / GPU / Automático

- **CPU:** opção inicial mais compatível. O motor é compilado para x64 sem exigir AVX/AVX2. Não precisa de placa dedicada. Compatibilidade não significa velocidade igual em todas as máquinas.
- **GPU:** tenta descarregar o modelo via Vulkan. Pode funcionar com NVIDIA, AMD ou Intel, dependendo da placa, driver e memória. Se não houver GPU compatível, mostra erro em vez de afirmar que acelerou.
- **Automático:** tenta GPU; se a detecção ou a inicialização falhar, inicia por CPU e informa o modo efetivo.

Desligue o modelo antes de trocar o processamento. Aceleração GPU é experimental e precisa de testes em hardware real. O uso de memória continua dependendo do modelo e do contexto; o modo GPU não torna qualquer modelo adequado a qualquer computador.

## Requisitos

- Windows 10/11 em processador **x64**. Windows ARM64 não está incluído nesta prévia.
- Comece com 8 GB de RAM e o modelo 0.8B; 16 GB ou mais são recomendados para modelos maiores. Os downloads de 0.8B/2B/9B ocupam aproximadamente 0,53/1,28/5,68 GB; reserve espaço adicional para o app e a execução.
- Internet para baixar o modelo. A inferência usa um servidor privado em 127.0.0.1, com autenticação temporária.
- Windows 11 e versões do Windows 10 ainda suportadas pela Microsoft são preferíveis. Uma compilação x64 não garante suporte a toda edição/build antiga do Windows 10.

## Arquivos e agente

Cada conversa recebe uma pasta interna. Você pode escolher outra em **Pasta desta conversa**.

Ative **Agente de arquivos e terminal** para listar, ler, pesquisar e criar/editar textos UTF-8. Mantenha **Controle total** desmarcado para revisar escritas e comandos. O terminal usa PowerShell, com as permissões do usuário e sem sandbox. Não inicie servidores persistentes pelo agente. Backups de edições da ferramenta de escrita ficam em `.mantimento-backups`; comandos do terminal não são cobertos por esses backups.

Os modelos menores podem falhar ao usar ferramentas. O catálogo Windows usa GGUF, não os arquivos MLX do Mac. Compatibilidade e qualidade do agente com os modelos GGUF precisam de avaliação adicional.

## Dados e uso nas duas plataformas

Dados Windows: `%LOCALAPPDATA%\Mantimento`. O aplicativo não sincroniza nem envia conversas à nuvem. Os downloads acessam Hugging Face; comandos que você autorizar podem acessar a rede.

Em **Ajustes**, exporte/importe uma conversa JSON. A importação cria uma nova pasta de trabalho e preserva o nome do modelo no histórico. Não transfere documentos, ambientes ou modelos. O app Mac atual exporta texto pela interface; para importar uma conversa do Mac no Windows, use um objeto de conversa de `conversations.json`, preservando um backup do arquivo original. A interface de importação no Mac e sincronização automática são passos futuros.

Você pode guardar a pasta do aplicativo e os modelos já baixados para uso offline. O kit automatizado de restauração do Mac ainda não foi portado para a interface Windows.

## Limites desta prévia

- Sem leitura PDF/OCR, edição Word/planilhas e kit offline automatizado na interface Windows.
- Leitura de texto até 1 MB, escrita até 200 KB por ação; trechos e contexto limitados.
- Agente com até 12 etapas e comandos finitos de até 60 segundos.
- Sem instalador, assinatura Authenticode ou atualização automática nesta prévia.
- GPU ainda experimental. Testes automatizados em runner Windows não substituem o uso na sua máquina.

Relate problemas em https://github.com/wilgnerschuertz/Mantimento/issues/new/choose, informando Windows, RAM, CPU/GPU, driver, modo selecionado, modelo e passos. Revise registros antes de compartilhar: podem conter caminhos e documentos privados.
