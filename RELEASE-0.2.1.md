# Mantimento 0.2.1 — uma experiência mais simples, pronta para ficar offline

Esta pré-release reúne a nova navegação, o catálogo ampliado de modelos e o kit de recuperação offline. O objetivo é facilitar a instalação e o uso diário do Mantimento no Mac.

## Baixe o aplicativo

Em **Assets**, escolha **Mantimento-0.2.1-macOS-arm64.zip**. O ZIP contém **Mantimento.app**. Os arquivos **Source code** são o código-fonte, não o aplicativo pronto para usar.

Também está disponível o arquivo `.zip.sha256` para conferir a integridade. Na pasta dos downloads, execute:

```sh
shasum -a 256 -c Mantimento-0.2.1-macOS-arm64.zip.sha256
```

SHA-256 do ZIP:

```text
b0b1289552c15eb42bdc5793372af7e50661e7c52963d40b13535ce7603c3542
```

## Novidades desde a 0.1.1

### Uma interface mais organizada

- **Conversa, Modelos e Backup offline** com navegação própria e barra lateral recolhível.
- Catálogo em cartões que se adaptam ao espaço da janela; ações secundárias ficam no menu de cada modelo.
- Ajustes separados para aparência, tamanho das respostas, criatividade e diagnóstico.
- Temas **Sistema, Claro e Escuro**, sem alterar a aparência global do macOS.
- Guia inicial para preparar o ambiente, baixar um modelo e começar a conversar.

### Mais conforto para conversar e trabalhar

- Campo de mensagem expansível, com limite de altura para preservar a leitura.
- Ao rolar manualmente, o acompanhamento pausa; **Última mensagem** volta ao final.
- Interrupção da resposta sem precisar desligar o modelo.
- Nome do modelo salvo em cada nova resposta, mesmo depois de trocar de modelo.
- Controles do agente e painéis de revisão se reorganizam quando falta espaço.
- Registros em painel separado e estados de tarefas mais claros, com tentativa novamente em caso de falha.

### Mais modelos e recuperação offline

- Catálogo com **Qwen3.5 2B, 4B e 9B**, **Llama 3.2 3B** e **Phi-4 Mini**, em MLX 4 bits.
- Busca, filtro por família, tamanho aproximado, memória sugerida e indicação da validação de cada modelo.
- Download com verificação de espaço, progresso dos bytes no cache e aproveitamento do cache ao tentar novamente.
- Remoção recuperável pela Lixeira; arquivos compartilhados por outros modelos são preservados.
- Kit com aplicativo, Python gerenciado, dependências e modelos para restauração sem internet.
- Formulários de bugs e sugestões no GitHub e um roteiro para testes em outros Macs.

## Requisitos

- **Mac Apple Silicon**: M1, M2, M3, M4 ou posterior. Não funciona em Mac Intel.
- Compilado para **macOS 14 ou posterior**; testes em outras máquinas e versões ainda são necessários.
- **16 GB de RAM recomendados**; o uso varia com o modelo e o tamanho da conversa.
- Espaço livre para ambiente e modelos: downloads do catálogo variam aproximadamente de **1,8 a 6 GB por modelo**.
- Internet para preparar o ambiente e baixar modelos. **Modelos não estão incluídos no ZIP.**

Não é necessário ter Python, Homebrew ou ferramentas de desenvolvimento instalados para usar o app. O ambiente é preparado na pasta do usuário.

## Como instalar e começar

1. Descompacte o ZIP e arraste **Mantimento.app** para **Aplicativos**.
2. Abra o app e siga **Preparar ambiente**.
3. Vá a **Modelos** e baixe um modelo. Comece pelo **Qwen3.5 2B** se quiser um teste leve.
4. Clique em **Usar**, volte a **Conversa** e escolha **Iniciar modelo**.
5. Envie uma mensagem com **⌘ Return**.
6. Depois do preparo, teste com o Wi-Fi desligado para confirmar o funcionamento offline.

O aplicativo tem assinatura **ad hoc**, sem Developer ID e sem notarização Apple. Se o macOS bloquear a abertura e você confiar na origem do download, siga a [orientação oficial da Apple](https://support.apple.com/102445) em **Ajustes do Sistema → Privacidade e Segurança** para permitir esse aplicativo. Não é necessário desativar as proteções globalmente.

## Atualizando uma instalação existente

Feche o Mantimento ou Qwen Local antes de substituir o aplicativo. **Não é necessário apagar dados ou baixar os modelos novamente.**

Instalações novas usam `~/Library/Application Support/Mantimento/`. Instalações antigas reaproveitam `~/Library/Application Support/QwenLocal/` quando a pasta nova não existe. Não mova o ambiente Python manualmente. Mensagens antigas sem registro do modelo são exibidas como **Assistente**.

## Guarde um kit offline

Com internet, prepare o ambiente e baixe os modelos que deseja guardar. Desligue o modelo, abra **Backup offline**, execute **Preparar pacotes** e escolha **Escolher destino e exportar…**.

Conversas e pastas internas são opcionais e ficam excluídas por padrão. Documentos de pastas externas não entram no kit. O kit não é criptografado e pode ocupar vários GB; revise antes de compartilhar e observe as licenças dos modelos.

No Mac de destino Apple Silicon, abra o Terminal na pasta do kit e execute `bash restaurar.sh`. O destino padrão precisa estar ausente: o script recusa sobrescrever dados existentes. Ele verifica os hashes e recria o ambiente a partir dos pacotes locais. Veja o [README](https://github.com/wilgnerschuertz/Mantimento#prepare-um-kit-offline) para instruções completas.

## O que foi verificado

- Compilação otimizada, assinatura local e integridade do ZIP.
- Histórico e migração, confinamento das ferramentas de arquivos, aprovação/recusa, backups, leitura, pesquisa e terminal.
- Streaming com preservação de 200 trechos UTF-8 e atualizações agrupadas.
- Interrupção da resposta preservando o processo do servidor e identificação do modelo no histórico.
- Interface no Mac de desenvolvimento em janelas pequena, média e maximizada, temas claro/escuro e textos extensos.
- Inferência de Llama e Phi com rede bloqueada e restauração de kit em pasta nova com espaços no caminho, sem acesso à rede.
- Detecção de kit adulterado e proteção contra sobrescrever um destino existente.

Esses testes não substituem a avaliação em outro Mac nem garantem a qualidade de todas as respostas. Llama e Phi continuam experimentais no catálogo; o agente foi validado com Qwen3.5 9B.

## Limites conhecidos

- Sem suporte a Intel, Windows, Linux ou iOS.
- PDF textual e arquivos de texto; sem OCR integrado ou edição nativa de Word/planilhas.
- Contexto, pesquisa, saídas de comandos e etapas do agente têm limites.
- **Controle total** executa comandos com suas permissões, sem sandbox de terminal. Use **Revisar ações** e uma pasta descartável ao testar o agente.
- Backups da ferramenta de escrita não cobrem alterações feitas pelo terminal.
- Novas dependências de projetos podem exigir internet, mesmo com o modelo offline.
- Remover modelos não limpa automaticamente todos os blobs compartilhados do cache.

## Ajude a testar

Siga o [roteiro beta](https://github.com/wilgnerschuertz/Mantimento/blob/main/TESTES-BETA.md) e abra uma [Issue](https://github.com/wilgnerschuertz/Mantimento/issues/new/choose) com versão do app, chip, memória, macOS, modelo e passos para reproduzir. Revise os registros antes de anexar: eles podem conter caminhos, comandos e documentos privados.
