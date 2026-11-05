'use strict';
const $ = id => document.getElementById(id);
let key = '', history = [], controller = null, active = false;
function status(text) { $('status').textContent = text; }
function setBusy(value) {
  active = value;
  for (const id of ['send','new','disconnect','prompt']) $(id).disabled = value;
  $('cancel').hidden = !value;
}
async function api(path, body, signal) {
  const response = await fetch(path, { method: body ? 'POST' : 'GET', headers: { Authorization: 'Bearer ' + key, ...(body ? {'Content-Type':'application/json'} : {}) }, body: body ? JSON.stringify(body) : undefined, signal, cache:'no-store', credentials:'omit' });
  const result = await response.json();
  if (!response.ok) throw new Error(result.error?.message || 'Pedido recusado pelo Mac.');
  return result;
}
function bubble(role, text) {
  const node = document.createElement('div'); node.className = 'message ' + role;
  const author = document.createElement('span'); author.className = 'author'; author.textContent = role === 'user' ? 'VOCÊ' : 'MANTIMENTO';
  node.append(author,document.createTextNode(text)); $('messages').append(node); $('empty').hidden = true;
  return node;
}
$('loginForm').addEventListener('submit', async event => {
  event.preventDefault(); key = $('key').value.trim(); $('connect').disabled = true; status('Conectando ao Mac…');
  try {
    const result = await api('/api/status'); $('key').value = ''; $('login').hidden = true; $('chat').hidden = false; $('disconnect').hidden = false;
    $('modelStatus').textContent = result.ready ? 'Modelo local disponível' : 'Modelo desligado no Mac';
    status(result.ready ? 'Conectado. Um pedido é processado por vez.' : 'Conectado. Inicie o modelo no Mantimento deste Mac para conversar.'); $('prompt').focus();
  } catch (error) { key = ''; status(error.message); }
  finally { $('connect').disabled = false; }
});
$('composer').addEventListener('submit', async event => {
  event.preventDefault(); if (active) return;
  const text = $('prompt').value.trim(); if (!text) return;
  const messages = [...history,{role:'user',content:text}];
  const bytes = messages.reduce((sum,m) => sum + new TextEncoder().encode(m.content).length + 64,0);
  if (bytes > 16000) { status('Conversa extensa. Inicie uma nova conversa ou reduza a mensagem. Seu texto foi mantido.'); return; }
  controller = new AbortController(); setBusy(true); const node = bubble('user',text); $('prompt').value = '';
  status('Gerando no Mac… A primeira resposta pode demorar enquanto o modelo carrega.');
  try {
    const result = await api('/v1/chat/completions',{model:'mantimento',messages,max_tokens:1024,temperature:0.6,stream:false},controller.signal);
    const answer = result.choices?.[0]?.message?.content;
    if (typeof answer !== 'string') throw new Error('Resposta inválida do modelo.');
    history = [...messages,{role:'assistant',content:answer}]; bubble('assistant',answer);
    status(result.choices[0].finish_reason === 'length' ? 'A resposta atingiu o limite de tamanho. Peça para continuar.' : 'Resposta recebida.');
  } catch (error) {
    node.remove(); $('empty').hidden = history.length > 0; $('prompt').value = text;
    status(error.name === 'AbortError' ? 'Você parou de esperar. O Mac pode continuar ocupado até concluir o pedido. Seu texto foi mantido.' : error.message);
  } finally { controller = null; setBusy(false); $('prompt').focus(); }
});
$('prompt').addEventListener('keydown',event => { if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') { event.preventDefault(); $('composer').requestSubmit(); } });
$('cancel').addEventListener('click',() => controller?.abort());
$('new').addEventListener('click',() => { history = []; $('messages').replaceChildren(); $('empty').hidden = false; status('Nova conversa.'); $('prompt').focus(); });
$('disconnect').addEventListener('click',() => { key = ''; history = []; $('messages').replaceChildren(); $('prompt').value = ''; $('chat').hidden = true; $('login').hidden = false; $('disconnect').hidden = true; $('empty').hidden = false; status('Desconectado.'); $('key').focus(); });
