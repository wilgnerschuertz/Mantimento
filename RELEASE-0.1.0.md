# Qwen Local 0.1.0 — teste inicial para macOS Apple Silicon

Primeira versão distribuída para testes. Os números 0.2–0.4 usados nos registros
anteriores eram etapas internas de desenvolvimento; esta é a versão pública de
avaliação 0.1.0, build 1.

## Download correto

Baixe **QwenLocal-0.1.0-macOS-arm64.zip** em Assets. Os arquivos “Source code”
gerados pelo GitHub não são o aplicativo pronto para uso.

## Requisitos e instalação

- Mac Apple Silicon: M1, M2, M3, M4 ou posterior; **não funciona em Macs Intel**.
- Target de compilação macOS 14 ou posterior. Validado no Mac do desenvolvedor;
  outras versões de macOS ainda precisam de teste.
- Recomendados 16 GB de memória. Comece com Qwen3.5 2B para uma avaliação leve.
- Internet para preparar o ambiente e baixar modelos. Modelos não estão incluídos
  no ZIP; os downloads ocupam vários GB.

1. Descompacte o ZIP e arraste **Qwen Local.app** para **Aplicativos**.
2. Abra o aplicativo e vá a **Modelos e ajustes → Preparar ambiente**.
3. Baixe um dos modelos, selecione **Usar**, feche os ajustes e clique **Iniciar**.
4. Envie uma mensagem. Depois do preparo e download, a inferência é local/offline.

O ambiente é instalado na pasta do usuário, sem exigir Homebrew, Python prévio
ou Command Line Tools. Dados e modelos ficam em
`~/Library/Application Support/QwenLocal/`.

## Aviso de desenvolvedor no macOS

O aplicativo tem assinatura ad hoc, **sem Developer ID e sem notarização Apple**.
O macOS pode bloquear a primeira abertura. Se você confiar na origem deste
aplicativo, siga a orientação oficial da Apple em Ajustes do Sistema →
Privacidade e Segurança para permitir a abertura deste app específico:
https://support.apple.com/102445
Não é necessário desativar o Gatekeeper globalmente. Gerenciamento corporativo
pode impedir a abertura. Distribuição sem esses avisos exige assinatura Developer
ID e notarização, ainda não configuradas.

## Funcionalidades para testar

- Chat com streaming, histórico, busca de conversas e exportação.
- Qwen3.5 2B, 4B e 9B em MLX 4 bits, com download pela interface.
- Pastas por conversa; leitura de texto e PDF textual, escrita e busca local.
- Agente de arquivos e terminal com revisão de ações ou controle total.
- Backups das edições feitas pela ferramenta de escrita.

Comece com **Conversa**. Ao testar o agente, use uma pasta descartável e mantenha
**Revisar ações**. Controle total permite comandos com as permissões do usuário;
não existe sandbox de terminal nem controle visual de aplicativos.

## Limites conhecidos

- Sem suporte Windows, Linux, Intel Mac ou iOS nesta versão.
- PDFs digitalizados precisam de OCR externo. Sem edição de Word ou planilhas.
- Busca literal limitada; documentos e saídas de comandos podem ser truncados.
- Até 12 etapas por pedido de agente e 60 segundos por comando.
- Não inicie servidores persistentes pelo agente.
- Configurar dependências novas pode exigir internet. Não é um kit de recuperação
  de instalação totalmente offline.
- Tool calling validado com Qwen3.5 9B; comportamento varia com modelos menores.

## Como relatar problemas

Informe chip, memória, versão do macOS, modelo selecionado, passos para reproduzir
e mensagem de erro. Verifique os registros antes de compartilhar: podem conter
caminhos, comandos e conteúdo dos seus documentos. Nunca publique chaves ou dados
pessoais. A interface de registros pode ser aberta pelo ícone de terminal no chat.
