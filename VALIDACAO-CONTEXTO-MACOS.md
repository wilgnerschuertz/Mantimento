# Validação de contexto e continuidade no macOS

Build de desenvolvimento de 4 de novembro de 2026. Ainda não integra a release macOS 0.2.1.

## Comportamento validado

- Orçamento de texto UTF-8 compartilhado entre conversa e início de tarefas do agente, preservando mensagens e rascunho quando o pedido excede o limite.
- Divisão do histórico em partes de até 8.000 bytes sem perda de acentos, caracteres multibyte ou emojis. Mensagens que cabem em uma parte são mantidas inteiras; mensagens maiores são divididas em partes equilibradas para evitar um fragmento final minúsculo.
- Resumo local em partes, com revisão editável antes de criar a continuação.
- Histórico original intacto, vínculo de origem persistido no arquivo de conversas e compatibilidade com arquivos antigos sem esse campo.
- Mesma pasta de trabalho e rascunho preservados; controle total desativado na continuação.
- Cancelamento, erro HTTP, resposta truncada ou excessiva e falha de gravação não criam uma continuação inválida.
- Interface verificada em janela compacta: revisão, criação da continuação, aviso de contexto e retorno ao chat original.

Os testes determinísticos usam dados isolados e um servidor local simulado. O teste de streaming preservou 200 trechos Unicode com menos de 20 atualizações da interface. A compilação otimizada do aplicativo e a assinatura local concluíram sem erros.

## Reproduzir

```sh
python3 tests/stream.py
python3 tests/layout_preview.py summary
# Abrir dist/LayoutPreview.app para a revisão visual isolada.
python3 tests/context_inference.py "/caminho/dos/dados/Mantimento"
python3 tests/benchmark.py "/caminho/dos/dados/Mantimento" dist/benchmark-long-m4.json --minutes 15
```

O teste real exige Qwen3.5 9B já instalado. Ele usa uma porta local exclusiva e dados de teste; não lê chats pessoais. Execute a carga contínua e o teste de resumo real sequencialmente para não carregar dois modelos ao mesmo tempo.

## Limites

Um resumo pode omitir ou interpretar incorretamente detalhes; revisão humana e releitura dos arquivos continuam necessárias. O orçamento em bytes não é uma contagem exata de tokens ou garantia de consumo de RAM. O agente interrompe a próxima inferência ao exceder o orçamento; ações já executadas não são desfeitas.

## Carga contínua no M4 com 16 GiB

Qwen3.5 9B 4-bit, MLX 0.32.4 e MLX-LM 0.32.2. O ensaio solicitado de 15 minutos concluiu o ciclo em andamento: **18 pedidos de conversa e dois resumos**, totalizando **1.019 s de requisições** (aproximadamente 17 minutos, além da preparação e amostragem).

| Momento | Texto enviado* | Primeiro texto | Geração aproximada |
| --- | ---: | ---: | ---: |
| Pedido 2 | 1,69 KB | 2,41 s | 17,96 tokens/s |
| Pedido 9, antes do primeiro resumo | 11,56 KB | 35,24 s | 12,13 tokens/s |
| Pedido 10, depois do primeiro resumo | 2,33 KB | 9,93 s | 8,72 tokens/s |
| Pedido 17, antes do segundo resumo | 12,22 KB | 54,52 s | 7,97 tokens/s |
| Pedido 18, depois do segundo resumo | 2,33 KB | 8,95 s | 10,60 tokens/s |

\* Tamanho UTF-8 do JSON de mensagens do teste, sem o system prompt. Não equivale à contagem do orçamento da interface.

- Pico reportado por `mlx.core.get_peak_memory`: **6,01 GB decimais**. Pico de buffers em cache amostrado separadamente: **0,81 GB**. Esses máximos podem ocorrer em instantes distintos; não somá-los para calcular um pico total.
- Maior RSS amostrado do servidor: **4,47 GB**. RSS e memória MLX não devem ser somados.
- Geração dos pedidos de conversa: **6,77 a 17,96 tokens/s**, mediana **10,47 tokens/s**.
- Swap global passou de **0,25 MB para 1.211,56 MB**. Portanto, este ensaio não sustenta uma afirmação de execução prolongada sem swap.
- Indicador de memória livre do sistema: **64% antes, 36% ao fim com o modelo carregado e 69% após encerrar**. O servidor saiu em **0,13 s**; swap não retorna necessariamente a zero assim que um processo encerra.

Os dois resumos reduziram a espera inicial nos pedidos seguintes, mas não mantiveram a velocidade do teste curto. Esse é um teste de carga do servidor, com histórico sintético crescente; não é uma comparação A/B isolada. Houve compilação e testes Swift na primeira parte e outros aplicativos permaneceram abertos. Não foi medida temperatura em graus; consultas a `pmset -g therm` não retornaram alertas registrados, o que não descarta limitação térmica ou outros fatores.

No script de carga, os pedidos chegaram aos limites de 256 tokens e os resumos aos de 512 tokens. Isso serve para comparar carga e tempos, não para validar fidelidade ou completude. O fluxo do app usa resumos em partes, permite até 1.024 tokens por parte e rejeita respostas encerradas por limite. Sua integração real é verificada separadamente.

Medições brutas locais: `dist/benchmark-long-m4.json`. O script encerrou seu servidor; não foram usados chats ou documentos pessoais.

## Integração com o modelo real

`tests/context_inference.py` passou com Qwen3.5 9B após a correção da divisão entre mensagens. O teste executa os métodos reais do `Store`, resume em partes um histórico sintético de 60 registros e verifica a preservação de `SQLite` e `tarefas.db`, a revisão antes da continuação e a integridade do histórico de origem. O resumo retornado também distinguiu a pendência de testar restauração de backups de ações efetivamente executadas.

Isso é uma verificação pontual, não uma garantia geral de fidelidade. O modelo acrescentou interpretações sobre a repetição dos registros e sugestões de prioridade; por isso a revisão editável permanece obrigatória. O servidor desse teste foi encerrado ao concluir. Resultado local: `dist/context-inference-result.txt`.
