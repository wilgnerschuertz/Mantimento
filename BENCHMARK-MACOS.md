# Qwen3.5 9B no MacBook Air M4

Medição local em 4 de novembro de 2026, Apple M4 com 16 GiB de memória unificada. Modelo `mlx-community/Qwen3.5-9B-4bit`, snapshot `8b2b98c00a6b4d291155e4890773ca8f769aee53`. Runtime MLX 0.32.4, MLX Metal 0.32.4 e MLX-LM 0.32.2.

| Pedido | Primeiro texto | Total | Tokens gerados | Geração aproximada |
| --- | ---: | ---: | ---: | ---: |
| Primeiro pedido do processo | 3,41 s | 12,49 s | 160 | 17,50 tokens/s |
| Repetição com modelo carregado | 0,45 s | 9,26 s | 160 | 18,03 tokens/s |
| Exemplo de CRUD Python/SQLite | 0,58 s | 14,81 s | 256 | 17,91 tokens/s |

O primeiro pedido inclui o carregamento dos pesos pelo servidor. O cache de arquivos do macOS não foi limpo. Os dois pedidos seguintes reutilizaram o mesmo processo; o servidor reportou 19 tokens de prompt em cache. Todos terminaram no limite de tokens configurado: o pedido de CRUD mede geração de código, não valida um sistema completo ou código executável.

## Memória e encerramento

- Pico registrado pelo alocador MLX: **5,38 GB decimais (5,01 GiB)**, cumulativo durante o teste.
- Maior RSS observado no processo: **4,41 GB decimais (4,11 GiB)**.
- Essas medidas não devem ser somadas: memória unificada, residência e contabilização do MLX são conceitos diferentes. O pico MLX também não representa todo o consumo do aplicativo ou do sistema.
- `memory_pressure -Q`: indicador de memória livre passou de **67%** antes do teste para **28%** com o modelo carregado e **60%** após encerrar o processo. Outros aplicativos continuam usando memória; não é uma medida isolada de bytes liberados.
- Swap usado permaneceu em **0,25 MB** nos três pontos amostrados.
- O servidor encerrou em **0,13 s**, sem precisar forçar a finalização. O processo de teste não ficou rodando.

## Método e limites

Servidor exclusivo em porta local temporária, sem ler conversas pessoais. Pesos já disponíveis, com `HF_HUB_OFFLINE=1` e `TRANSFORMERS_OFFLINE=1`. Parâmetros iguais aos do runtime do aplicativo: prefill 512, um cache de prompt e concorrência 1. Temperatura 0 e thinking desabilitado. O teste adiciona `stream_options.include_usage` para obter contagens de tokens do servidor.

O tempo até o primeiro texto vai do início da requisição até o primeiro conteúdo SSE. A taxa aproximada usa `(tokens gerados − 1) / (tempo total − tempo do primeiro texto)`; inclui pequenas despesas de transporte e encerramento. MLX foi amostrado a cada 250 ms e RSS a cada 500 ms; picos amostrados podem perder variações mais curtas.

São três pedidos curtos em uma única sessão, sem avaliação térmica prolongada ou controle dos outros programas do Mac. Não é um teste A/B das mudanças de interface nem demonstra aceleração da inferência: o motor e os pesos não foram alterados. O teste de encerramento usa o mesmo mecanismo de término de processo, mas não espera os dez minutos do temporizador; as condições do temporizador têm testes separados.

## Reproduzir

```sh
python3 tests/benchmark.py "/caminho/dos/dados/Mantimento" dist/benchmark-m4-qwen35-9b.json
```

Use a pasta que contém `venv` e `cache`; instalações antigas podem continuar em `QwenLocal`. O script requer o Qwen3.5 9B baixado. Ele guarda os resultados e respostas sintéticas no JSON, encerra seu próprio servidor e não altera chats nem preferências. As métricas não incluem a renderização da janela SwiftUI.
