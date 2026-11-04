# Validação da candidata 0.2.0

Executado no Mac de desenvolvimento Apple Silicon em 2026-11-04.

- Compilação Swift otimizada, assinatura ad hoc verificada e ZIP extraído/verificado.
- Testes isolados do Store/agente: confinamento, symlinks, revisão, backup, leitura, pesquisa, terminal, migração e pastas por conversa.
- Streaming: 200 trechos UTF-8 preservados em 7 publicações de mensagens.
- Gerenciamento de modelos: identificadores inválidos, symlink externo, falta de espaço, revisão fixa e remoção recuperável com blob compartilhado preservado.
- Downloads reais de Llama 3.2 3B e Phi-4 Mini completos.
- Inferência dos dois modelos com HF_HUB_OFFLINE, TRANSFORMERS_OFFLINE e sandbox do macOS negando rede. Ambos responderam 2+2 corretamente em português. É um teste mínimo de carga e texto, não uma avaliação de qualidade ou de ferramentas.
- Interface: catálogo renderizado; busca por Llama mostrou somente o resultado correspondente; controles de kit e Issues presentes.
- Kit: wheels de todas as dependências preparados, exportação sem conversas/tokens, hashes conferidos, restauração em pasta nova com espaços no caminho, ambiente recriado sem rede e inferência dos dois modelos restaurados.
- Destino existente recusado; arquivo adulterado deve impedir restauração antes da criação do destino.

Para repetir a integração offline, use um ambiente preparado com os dois modelos e rode:

```sh
"/caminho/dados/venv/bin/python" tests/offline.py "/caminho/dados" "/caminho/Mantimento.app"
```

O teste usa uma pasta temporária e nega rede ao restaurar e gerar respostas. Pode ocupar mais de 8 GB temporários. Não altera o ambiente de origem nem os chats reais.

Ainda necessário: TESTES-BETA.md em outro Mac, versões antigas do macOS, interrupção durante download real e avaliação do agente com modelos além do Qwen3.5 9B. Llama e Phi continuam experimentais no catálogo. Sem assinatura Developer ID/notarização.
