# Navegador e API na rede local

Módulo macOS em desenvolvimento, ainda não incluído na release 0.2.1. O servidor e a página estão dentro do aplicativo SwiftUI; os clientes só precisam de um navegador. O processamento usa o modelo instalado no Mac.

## Conectar

1. Abra o Mantimento e inicie um modelo.
2. Em **Ajustes → Acesso pela rede**, clique em ativar.
3. Copie o endereço exibido (por exemplo, `http://192.168.1.20:8765`) e a chave.
4. Em outro dispositivo da mesma rede, abra esse endereço e informe a chave.

A opção de iniciar o acesso junto com o app é persistida, mas não inicia o modelo automaticamente. Uma nova chave é gerada a cada ativação; conexões anteriores precisam dela novamente. Sem endereço de rede disponível, `127.0.0.1` funciona apenas no próprio Mac. Mudanças de Wi-Fi/IP podem exigir desativar e reativar o serviço para atualizar os endereços exibidos.

O Mac precisa permanecer ligado, acordado e com o aplicativo aberto. Se o modelo for descarregado por inatividade, inicie-o novamente no Mac. Permita rede local/firewall para o app quando o macOS solicitar. Redes de convidados podem impedir comunicação entre dispositivos.

**HTTP não criptografa a chave nem as conversas. Use somente uma rede confiável. Não encaminhe a porta no roteador nem exponha o serviço à internet.** O serviço aceita IPv4 privado e loopback. Não há suporte a IPv6, HTTPS ou acesso público nesta etapa.

## Comportamento

- Uma geração por vez, compartilhada entre chat nativo, agente e clientes web/API. Pedidos concorrentes recebem 409.
- Chat remoto somente de texto, sem ferramentas, arquivos, terminal ou acesso ao histórico do aplicativo.
- Histórico do navegador em memória: recarregar ou fechar a página apaga a conversa. A chave também não é salva pelo app web.
- A resposta aparece completa, sem streaming. “Parar espera” interrompe a espera no navegador; o processamento pode continuar e ocupar o modelo até terminar.
- Desativar o serviço durante uma geração remota interrompe também o servidor do modelo. Será necessário iniciar o modelo novamente.
- Limites: 16.000 bytes de contexto (incluindo 64 bytes por mensagem), 100 mensagens, corpo HTTP de 64 KiB, 2.048 tokens de saída e 60 pedidos por minuto por IP.

## API

Todas as rotas abaixo exigem `Authorization: Bearer SUA_CHAVE`:

| Método e rota | Resultado |
| --- | --- |
| `GET /api/status` | `ready`, `busy` e alias `model` |
| `GET /v1/models` | Lista contendo `mantimento` quando o modelo está ativo |
| `POST /v1/chat/completions` | Resposta de texto no formato básico de chat completions |

Exemplo com curl; substitua endereço e chave pelos valores exibidos no Mac:

```sh
curl http://192.168.1.20:8765/v1/chat/completions \
  -H 'Authorization: Bearer SUA_CHAVE' \
  -H 'Content-Type: application/json' \
  -d '{"model":"mantimento","messages":[{"role":"user","content":"Explique como conservar alimentos secos."}],"max_tokens":512,"temperature":0.6,"stream":false}'
```

São aceitos somente `model`, `messages`, `max_tokens`, `temperature` e `stream`. As mensagens usam `system`, `user` ou `assistant` com `content` textual. `temperature` deve ficar entre 0 e 1; `max_tokens`, entre 1 e 2.048. `stream:true`, ferramentas e outros parâmetros são rejeitados. Esta é uma implementação parcial do formato, não compatibilidade completa com qualquer SDK.

Erros: 400 pedido inválido; 401 chave inválida; 403 origem/host inválido; 409 ocupado; 415 conteúdo não JSON; 429 limite de pedidos; 503 modelo indisponível/interrompido; 504 falha ou tempo de espera. O motor permanece restrito a `127.0.0.1:12345`; somente o gateway em `8765` atende a rede.

## Validação

`python3 tests/lan.py` verifica autenticação, origem/host, limites, recursos offline, HTTP malformado, exclusão mútua local/remota, desconexão e sanitização com um modelo simulado. `python3 tests/lan.py --real /caminho/dos/dados` testa uma resposta do Qwen3.5 9B instalado, sempre em loopback. Execute esses testes separadamente dos demais testes que usam a porta 12346.

Ainda é necessário validar acesso de um segundo dispositivo físico, incluindo permissões/firewall e isolamento da rede Wi-Fi.
