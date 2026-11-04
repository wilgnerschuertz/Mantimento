# Mantimento 0.2.1 — navegação e leitura

Candidata local para testes, ainda não publicada como release.

- Navegação nativa com Conversa, Modelos e Backup offline; barra lateral recolhível.
- Janela mínima de 720 × 560 pontos, catálogo adaptável e controles do agente que se reorganizam quando falta espaço.
- Ajustes separados para aparência, tamanho de resposta, criatividade e diagnóstico.
- Temas Sistema, Claro e Escuro, sem mudar a aparência global do macOS.
- Preparação inicial guiada e estados de tarefas com tentativa novamente em caso de falha.
- Campo de mensagem expansível, com limite menor em janelas baixas; interrupção da resposta sem desligar o servidor.
- Rolagem manual pausa o acompanhamento; botão Última mensagem retoma a leitura no final.
- Nome do modelo salvo em cada resposta e preservado após trocar de modelo. Mensagens antigas sem essa informação aparecem como Assistente.
- Revisão de ações em duas colunas ou painéis verticais conforme o espaço.
- Registros em painel separado, para preservar a área de leitura do chat.

## Verificação

Compilação otimizada e testes de histórico, agente e streaming. Revisão visual no Mac de desenvolvimento com janelas pequena, média e maximizada, temas claro/escuro, nomes longos, código horizontal e texto extenso. `tests/layout_preview.py` cria um aplicativo de revisão visual isolado, sem usar os chats reais.

Ainda é necessário validar em outros Macs e versões do macOS. Permanecem os requisitos e limites da 0.2.0: Apple Silicon, macOS 14+, assinatura ad hoc e sem notarização. A release 0.1.1 publicada não é alterada.
