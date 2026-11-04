using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Mantimento.Core;

static void Check(bool value,string name){if(!value)throw new Exception("FALHOU: "+name);Console.WriteLine("PASSOU: "+name);}
static async Task Reject(Func<Task> action,string name){try{await action();}catch(Exception e)when(e is IOException or InvalidDataException or ArgumentException or UnauthorizedAccessException){Console.WriteLine("PASSOU: "+name);return;}throw new Exception("FALHOU: "+name);}
static JsonElement Args(object value)=>JsonSerializer.SerializeToElement(value);
var root=Path.Combine(Path.GetTempPath(),"mantimento-test-"+Guid.NewGuid());Directory.CreateDirectory(root);
try {
 var store=new LocalStore(root);var first=store.NewConversation();var second=store.NewConversation();Check(first.Workspace!=second.Workspace,"pastas por conversa");
 first.Messages.Add(new("assistant","Resposta","Qwen3.5 0.8B"));store.Save();var loaded=new LocalStore(root);Check(loaded.Conversations.Single(c=>c.Id==first.Id).Messages[0].ModelName=="Qwen3.5 0.8B","histórico e identificação do modelo");
 var external=Path.Combine(root,"export.json");LocalStore.AtomicWrite(external,JsonSerializer.Serialize(first,LocalStore.Json));var imported=store.ImportConversation(external);Check(imported.Id!=first.Id&&imported.Workspace!=first.Workspace,"importação isola a pasta de trabalho");
 var legacy=JsonSerializer.Deserialize<Conversation>("{\"id\":\"00000000-0000-0000-0000-000000000001\",\"title\":\"Mac\",\"messages\":[{\"id\":\"00000000-0000-0000-0000-000000000002\",\"role\":\"assistant\",\"content\":\"Oi\"}]}",LocalStore.Json);Check(legacy?.Messages[0].ModelName is null,"conversa antiga sem identificação");
 var workspace=store.Workspace(first);var accept=false;var tools=new WorkspaceTools(workspace,(_,_)=>Task.FromResult(accept));
 foreach(var path in new[]{"../escape","..\\escape","C:\\Windows\\x",".git/config","file.txt:stream","NUL.txt","test. ",".mantimento-backups/test"})await Reject(()=>Task.FromResult(tools.Resolve(path)),"bloqueia "+path);
 await tools.ExecuteAsync("write_file",Args(new{path="note.txt",content="primeiro"}),false,CancellationToken.None);Check(!File.Exists(Path.Combine(workspace,"note.txt")),"recusa não escreve");
 accept=true;await tools.ExecuteAsync("write_file",Args(new{path="note.txt",content="primeiro"}),false,CancellationToken.None);await tools.ExecuteAsync("write_file",Args(new{path="note.txt",content="segundo"}),false,CancellationToken.None);Check(tools.Read("note.txt").Contains("segundo"),"escrita e leitura");Check(Directory.GetFiles(Path.Combine(workspace,".mantimento-backups"),"*",SearchOption.AllDirectories).Any(p=>File.ReadAllText(p)=="primeiro"),"backup preserva versão anterior");
 var race=new WorkspaceTools(workspace,(_,_)=>{File.WriteAllText(Path.Combine(workspace,"note.txt"),"mudou");return Task.FromResult(true);});await Reject(()=>race.ExecuteAsync("write_file",Args(new{path="note.txt",content="não escrever"}),false,CancellationToken.None),"mudança durante revisão é recusada");
 var result=await WorkspaceTools.RunCommandAsync(OperatingSystem.IsWindows()?"Write-Output 'terminal-ok'":"printf terminal-ok",workspace,CancellationToken.None);Check(result.Contains("terminal-ok"),"comando local finito");
 var slow=OperatingSystem.IsWindows()?"Start-Sleep -Seconds 20":"sleep 20";var timeout=await WorkspaceTools.RunCommandAsync(slow,workspace,CancellationToken.None,1);Check(timeout.Contains("\"timeout\": true"),"timeout encerra comando");
 var bytes=Encoding.UTF8.GetBytes("GGUFdummy");var hash=Convert.ToHexString(SHA256.HashData(bytes));var model=new ModelEntry("test","Teste","org/repo","revision","test.gguf",bytes.Length,hash,"8 GB","teste");
 var part=store.ModelPath(model)+".partial";File.WriteAllBytes(part,bytes[..3]);
 using(var client=new HttpClient(new Handler(request=>{Check(request.Headers.Range?.Ranges.First().From==3,"download usa faixa para retomar");var response=new HttpResponseMessage(HttpStatusCode.PartialContent){Content=new ByteArrayContent(bytes[3..])};response.Content.Headers.ContentRange=new ContentRangeHeaderValue(3,bytes.Length-1,bytes.Length);return response;}))){await Downloads.DownloadAsync(store,model,null,CancellationToken.None,client);}
 Check(store.Installed(model)&&File.ReadAllBytes(store.ModelPath(model)).SequenceEqual(bytes),"download completo é verificado antes de instalar");
 var wrong=model with{File="wrong.gguf",Sha256=new string('0',64)};using(var client=new HttpClient(new Handler(_=>new HttpResponseMessage(HttpStatusCode.OK){Content=new ByteArrayContent(bytes)}))){await Reject(()=>Downloads.DownloadAsync(store,wrong,null,CancellationToken.None,client),"checksum incorreto não instala modelo");}Check(!store.Installed(wrong),"modelo inválido indisponível");
 var sse="data: {\"choices\":[{\"delta\":{\"content\":\"Olá á\"}}]}\n\ndata: [DONE]\n\n";using(var client=new HttpClient(new Handler(_=>new HttpResponseMessage(HttpStatusCode.OK){Content=new StringContent(sse)})){BaseAddress=new Uri("http://127.0.0.1:12345")}){var text="";await foreach(var delta in Chat.StreamAsync(client,new Conversation{Messages=[new("user","Oi")]},100,CancellationToken.None))text+=delta;Check(text=="Olá á","streaming UTF-8 sem perdas");}
 var reviews=0;var agentTools=new WorkspaceTools(workspace,(_,_)=>{reviews++;return Task.FromResult(false);});var calls=0;
 using(var client=new HttpClient(new Handler(_=>{calls++;var json=calls==1?"{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":null,\"tool_calls\":[{\"id\":\"one\",\"type\":\"function\",\"function\":{\"name\":\"write_file\",\"arguments\":\"{\\\"path\\\":\\\"agent.txt\\\",\\\"content\\\":\\\"x\\\"}\"}}]}}]}":"{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"Ação recusada.\"}}]}";return new HttpResponseMessage(HttpStatusCode.OK){Content=new StringContent(json)};})){BaseAddress=new Uri("http://127.0.0.1:12345")}){await Chat.AgentAsync(client,new Conversation{Messages=[new("user","Crie arquivo")]},agentTools,false,100,_=>{},CancellationToken.None);Check(reviews==1&&!File.Exists(Path.Combine(workspace,"agent.txt"))&&calls==2,"agente pede revisão e respeita recusa");}
 if(args.Contains("--engine")){
  var nativeStore=new LocalStore();var path=nativeStore.ModelPath(ModelEntry.Catalog[0]);if(!nativeStore.Installed(ModelEntry.Catalog[0])){Console.WriteLine("Baixando modelo mínimo para teste de inferência…");await Downloads.DownloadAsync(nativeStore,ModelEntry.Catalog[0],null,CancellationToken.None);}Check(File.Exists(path),"modelo de smoke test disponível");
  using var engine=new Engine();using var token=new CancellationTokenSource(TimeSpan.FromMinutes(8));await engine.StartAsync(path,"CPU",token.Token);Check(engine.Running&&engine.EffectiveCompute=="CPU","motor Windows por CPU iniciado");
  var text="";await foreach(var chunk in Chat.StreamAsync(engine.Client!,new Conversation{Messages=[new("user","Responda apenas com o número: quanto é 2 + 2?")]},64,token.Token))text+=chunk;
  Check(text.Contains('4')||text.Contains("quatro",StringComparison.OrdinalIgnoreCase),"inferência GGUF real: "+text);
  engine.Stop();Check(!engine.Running,"desligamento libera processo");
  await engine.StartAsync(path,"Automático",token.Token);Check(engine.Running,"Automático inicia GPU ou fallback CPU");Console.WriteLine("MODO AUTOMÁTICO: "+engine.EffectiveCompute);
 }
 Console.WriteLine("TODOS OS TESTES PASSARAM.");
}finally{Directory.Delete(root,true);}
sealed class Handler(Func<HttpRequestMessage,HttpResponseMessage> reply):HttpMessageHandler{protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken token){token.ThrowIfCancellationRequested();return Task.FromResult(reply(request));}}
