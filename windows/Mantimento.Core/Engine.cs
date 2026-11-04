using System.Diagnostics;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text.Json;

namespace Mantimento.Core;
public sealed class Engine:IDisposable {
    private Process? process;
    private readonly object logLock=new(); private string log="";
    public string Logs { get { lock(logLock) return log; } }
    public string EffectiveCompute { get; private set; }="Desligado";
    public HttpClient? Client { get; private set; }
    public bool Running=>process is { HasExited:false } && Client is not null;
    public event Action<string>? Notice;
    private static string Executable(string folder)=>Path.Combine(AppContext.BaseDirectory,"engine",folder,OperatingSystem.IsWindows()?"llama-server.exe":"llama-server");
    private void Append(string? line) { if(line is null)return; lock(logLock) { log += line+"\n"; if(log.Length>18000)log=log[^18000..]; } }
    public async Task StartAsync(string model,string compute,CancellationToken token) {
        if(process is not null) throw new InvalidOperationException("Desligue o modelo atual primeiro.");
        if(!File.Exists(model))throw new FileNotFoundException("Baixe o modelo antes de iniciar.");
        if(compute is not ("CPU" or "GPU" or "Automático"))throw new ArgumentException("Modo de processamento inválido.");
        if(compute!="CPU") {
            try { await StartBackendAsync(model,"vulkan",token); EffectiveCompute="GPU · Vulkan"; return; }
            catch(Exception e) when(compute=="Automático" && (e is not OperationCanceledException || !token.IsCancellationRequested)) { Stop(); Append("GPU indisponível: "+e.Message); Notice?.Invoke("GPU indisponível. Iniciando por CPU…"); }
        }
        await StartBackendAsync(model,"cpu",token); EffectiveCompute="CPU";
    }
    private async Task StartBackendAsync(string model,string backend,CancellationToken token) {
        try {
            var exe=Executable(backend);
            if(!File.Exists(exe))throw new FileNotFoundException("Motor "+backend+" ausente. Extraia o ZIP completo.");
            await VerifyBundleAsync(Path.GetDirectoryName(exe)!,token);
            if(backend=="vulkan") {
                using var probe=new Process { StartInfo=new ProcessStartInfo(exe) { UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true } };
                probe.StartInfo.ArgumentList.Add("--list-devices"); probe.Start();
                using var timeout=CancellationTokenSource.CreateLinkedTokenSource(token);timeout.CancelAfter(TimeSpan.FromSeconds(25));
                var stdout=probe.StandardOutput.ReadToEndAsync(timeout.Token);var stderr=probe.StandardError.ReadToEndAsync(timeout.Token);
                try { await probe.WaitForExitAsync(timeout.Token); }
                catch { if(!probe.HasExited)probe.Kill(true); throw; }
                var devices=await stdout+await stderr;Append(devices);
                if(probe.ExitCode!=0 || !System.Text.RegularExpressions.Regex.IsMatch(devices,@"(?im)^\s*Vulkan\d+\s*:")) throw new InvalidOperationException("Nenhuma GPU Vulkan compatível encontrada. Atualize o driver ou use CPU.");
            }
            var listener=new TcpListener(IPAddress.Loopback,0); listener.Start();var port=((IPEndPoint)listener.LocalEndpoint).Port;listener.Stop();
            var secret=Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            var info=new ProcessStartInfo(exe) { UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true,WorkingDirectory=Path.GetDirectoryName(exe)! };
            foreach(var arg in new[]{"--model",model,"--host","127.0.0.1","--port",port.ToString(),"--ctx-size","4096","--parallel","1","--threads",Math.Clamp(Environment.ProcessorCount-1,1,8).ToString(),"--n-gpu-layers",backend=="cpu"?"0":"99","--jinja","--no-webui","--alias","mantimento"}) info.ArgumentList.Add(arg);
            info.Environment["LLAMA_API_KEY"]=secret;
            process=new Process { StartInfo=info,EnableRaisingEvents=true };process.OutputDataReceived+=(_,e)=>Append(e.Data);process.ErrorDataReceived+=(_,e)=>Append(e.Data);
            process.Start();process.BeginOutputReadLine();process.BeginErrorReadLine();
            Client=new HttpClient { BaseAddress=new Uri($"http://127.0.0.1:{port}/"),Timeout=TimeSpan.FromMinutes(10) };
            Client.DefaultRequestHeaders.Authorization=new AuthenticationHeaderValue("Bearer",secret);
            for(var n=0;n<600;n++) {
                token.ThrowIfCancellationRequested();
                if(process.HasExited)throw new InvalidOperationException("O motor encerrou durante a carga. Consulte os registros; tente um modelo menor ou CPU.");
                try { using var ready=new CancellationTokenSource(TimeSpan.FromSeconds(1));using var linked=CancellationTokenSource.CreateLinkedTokenSource(token,ready.Token);using var response=await Client.GetAsync("v1/models",linked.Token); if(response.IsSuccessStatusCode)return; }
                catch(HttpRequestException){} catch(OperationCanceledException)when(!token.IsCancellationRequested){}
                await Task.Delay(500,token);
            }
            throw new TimeoutException("Carga demorou mais de cinco minutos; tente um modelo menor.");
        } catch { Stop(); throw; }
    }
    public static async Task VerifyBundleAsync(string directory,CancellationToken token) {
        var path=Path.Combine(directory,"manifest.json");
        var files=JsonSerializer.Deserialize<Dictionary<string,string>>(await File.ReadAllTextAsync(path,token)) ?? throw new InvalidDataException("Manifesto do motor inválido.");
        if(!files.ContainsKey("llama-server.exe") && OperatingSystem.IsWindows())throw new InvalidDataException("Motor sem verificação.");
        foreach(var (name,sha) in files) { if(Path.GetFileName(name)!=name)throw new InvalidDataException("Nome inválido no manifesto.");await Downloads.VerifyAsync(Path.Combine(directory,name),sha,token); }
    }
    public void Stop() { Client?.Dispose();Client=null;var p=process;process=null;if(p is not null){try{if(!p.HasExited)p.Kill(true);}catch(InvalidOperationException){}finally{p.Dispose();}}EffectiveCompute="Desligado"; }
    public void Dispose()=>Stop();
}
