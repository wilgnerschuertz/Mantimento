using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace Mantimento.Core;
public record Proposal(string Title,string Before,string After);
public sealed class WorkspaceTools(string workspace,Func<Proposal,CancellationToken,Task<bool>> review) {
    public string Root { get; }=Path.GetFullPath(workspace);
    private static readonly StringComparison Paths=OperatingSystem.IsWindows()?StringComparison.OrdinalIgnoreCase:StringComparison.Ordinal;
    public string Resolve(string relative) {
        if(string.IsNullOrWhiteSpace(relative)||Path.IsPathRooted(relative)||relative.Contains(':')||relative.IndexOfAny(['\0','\r','\n'])>=0)throw new IOException("Use um caminho relativo à pasta escolhida.");
        var parts=relative.Replace('\\','/').Split('/');
        if(parts.Any(p=>p is ".." or ".git" or ".mantimento-backups" or ".qwen-backups"||p.EndsWith(' ')||p.EndsWith('.')))throw new IOException("Caminho reservado ou fora da pasta.");
        if(parts.Any(p=>System.Text.RegularExpressions.Regex.IsMatch(p,@"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)",System.Text.RegularExpressions.RegexOptions.IgnoreCase)))throw new IOException("Nome reservado pelo Windows.");
        var file=Path.GetFullPath(Path.Combine(Root,Path.Combine(parts)));
        if(!file.StartsWith(Root.TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar,Paths))throw new IOException("Caminho fora da pasta.");
        var ancestor=file;
        while(true) {
            if((File.Exists(ancestor)||Directory.Exists(ancestor)) && (File.GetAttributes(ancestor)&FileAttributes.ReparsePoint)!=0)throw new IOException("Links, junctions e reparse points não são permitidos.");
            if(ancestor.Equals(Root,Paths))break;
            ancestor=Path.GetDirectoryName(ancestor)??throw new IOException("Caminho inválido.");
        }
        return file;
    }
    public List<string> Files() {
        var result=new List<string>();var queue=new Queue<string>();queue.Enqueue(Root);var visited=0;
        while(queue.Count>0 && result.Count<500 && visited++<2000) {
            var dir=queue.Dequeue();
            foreach(var item in Directory.EnumerateFileSystemEntries(dir)) {
                var name=Path.GetFileName(item);
                if(name.StartsWith('.')||name is "node_modules" or "venv" or "bin" or "obj" or "dist" or "build")continue;
                var attrs=File.GetAttributes(item);if((attrs&FileAttributes.ReparsePoint)!=0)continue;
                if((attrs&FileAttributes.Directory)!=0)queue.Enqueue(item);else result.Add(Path.GetRelativePath(Root,item));
                if(result.Count>=500)break;
            }
        }
        return result;
    }
    public string Read(string relative) {
        var file=Resolve(relative);if(new FileInfo(file).Length>1_000_000)throw new IOException("Leitura limitada a texto UTF-8 de até 1 MB.");
        var content=new UTF8Encoding(false,true).GetString(File.ReadAllBytes(file));
        if(content.Contains('\0'))throw new IOException("Arquivo binário. Esta versão Windows lê arquivos de texto UTF-8.");
        return "Fonte: "+relative+"\n"+(content.Length>16000?content[..16000]+"\n[Conteúdo truncado]":content);
    }
    public async Task<string> ExecuteAsync(string name,JsonElement args,bool fullControl,CancellationToken token) {
        string Value(string key)=>args.TryGetProperty(key,out var v)?v.GetString()??"":"";
        token.ThrowIfCancellationRequested();
        switch(name) {
            case "list_files":return await Task.Run(()=>string.Join('\n',Files()),token);
            case "read_file":return await Task.Run(()=>Read(Value("path")),token);
            case "search_files":return await Task.Run(()=>{
                var query=Value("query");if(string.IsNullOrWhiteSpace(query))throw new IOException("Pesquisa vazia.");
                var output=new StringBuilder();
                foreach(var file in Files().Take(120)){token.ThrowIfCancellationRequested();try{var lines=Read(file).Split('\n');for(var i=0;i<lines.Length;i++)if(lines[i].Contains(query,StringComparison.OrdinalIgnoreCase)){output.AppendLine($"{file} (linha extraída {i+1}): {lines[i][..Math.Min(500,lines[i].Length)]}");if(output.Length>12000)return output.ToString()[..12000];}}catch(IOException){}}
                return output.Length==0?"Sem resultados nos primeiros 120 arquivos e trechos lidos.":output.ToString();
            },token);
            case "write_file": {
                var relative=Value("path");var content=Value("content");var path=Resolve(relative);
                if(Encoding.UTF8.GetByteCount(content)>200000)throw new IOException("Escrita limitada a 200 KB por ação.");
                var exists=File.Exists(path);if(exists&&new FileInfo(path).Length>1_000_000)throw new IOException("Edição limitada a arquivos de 1 MB.");
                var oldBytes=exists?await File.ReadAllBytesAsync(path,token):[];
                var old=new UTF8Encoding(false,true).GetString(oldBytes).TrimStart('\ufeff');
                if(!fullControl&&!await review(new("Salvar "+relative,exists?old:"[Arquivo novo]",content),token))return "Usuário recusou a alteração.";
                token.ThrowIfCancellationRequested();if(Resolve(relative)!=path)throw new IOException("Caminho mudou durante revisão.");
                if(File.Exists(path)!=exists || (exists&&!(await File.ReadAllBytesAsync(path,token)).SequenceEqual(oldBytes)))throw new IOException("Arquivo mudou durante revisão. Leia novamente.");
                if(exists) { var backup=Path.Combine(Root,".mantimento-backups",Guid.NewGuid().ToString(),Path.GetFileName(path));Directory.CreateDirectory(Path.GetDirectoryName(backup)!);await File.WriteAllBytesAsync(backup,oldBytes,token); }
                LocalStore.AtomicWrite(path,content);return "Salvo: "+relative+". Edição anterior preservada quando existente.";
            }
            case "run_command": {
                var command=Value("command");if(string.IsNullOrWhiteSpace(command))throw new IOException("Comando vazio.");
                if(!fullControl&&!await review(new("Executar PowerShell","Pasta: "+Root+"\nO terminal tem as permissões do seu usuário e pode acessar outros locais.",command),token))return "Usuário recusou o comando.";
                token.ThrowIfCancellationRequested();return await RunCommandAsync(command,Root,token);
            }
            default:throw new IOException("Ferramenta desconhecida.");
        }
    }
    public static async Task<string> RunCommandAsync(string command,string workspace,CancellationToken token,int seconds=60) {
        var windows=OperatingSystem.IsWindows();
        var exe=windows?Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"WindowsPowerShell","v1.0","powershell.exe"):"/bin/sh";
        var info=new ProcessStartInfo(exe){WorkingDirectory=workspace,UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true,StandardOutputEncoding=Encoding.UTF8,StandardErrorEncoding=Encoding.UTF8};
        if(windows){foreach(var arg in new[]{"-NoLogo","-NoProfile","-NonInteractive","-EncodedCommand",Convert.ToBase64String(Encoding.Unicode.GetBytes("[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; "+command))})info.ArgumentList.Add(arg);}else{info.ArgumentList.Add("-c");info.ArgumentList.Add(command);}
        using var process=new Process{StartInfo=info};process.Start();
        using var job=OperatingSystem.IsWindows()?WindowsJob.Attach(process):null;
        var output=new StringBuilder();var outputLock=new object();
        async Task Drain(StreamReader reader){var chars=new char[2048];int count;while((count=await reader.ReadAsync(chars))>0){lock(outputLock){var available=16000-output.Length;if(available>0)output.Append(chars,0,Math.Min(count,available));}}}
        var readers=Task.WhenAll(Drain(process.StandardOutput),Drain(process.StandardError));
        using var timeout=CancellationTokenSource.CreateLinkedTokenSource(token);timeout.CancelAfter(TimeSpan.FromSeconds(Math.Clamp(seconds,1,120)));
        var timedOut=false;
        try{await process.WaitForExitAsync(timeout.Token);}catch(OperationCanceledException){timedOut=!token.IsCancellationRequested;try{process.Kill(true);}catch(InvalidOperationException){}await process.WaitForExitAsync(CancellationToken.None);}
        finally{job?.Dispose();}
        await Task.WhenAny(readers,Task.Delay(2000,CancellationToken.None));token.ThrowIfCancellationRequested();
        lock(outputLock)return JsonSerializer.Serialize(new{exit_code=process.ExitCode,timeout=timedOut,output=output.ToString()},LocalStore.Json);
    }
    public static readonly object[] Definitions = [
        Schema("list_files","Lista os arquivos da pasta de trabalho",[],[]),
        Schema("read_file","Lê texto UTF-8 local de até 1 MB",["path"],["path"]),
        Schema("search_files","Pesquisa texto literal nos arquivos locais",["query"],["query"]),
        Schema("write_file","Cria ou substitui arquivo de texto completo",["path","content"],["path","content"]),
        Schema("run_command","Executa PowerShell por até 60 segundos; não inicie serviços persistentes",["command"],["command"])
    ];
    static object Schema(string name,string description,string[] fields,string[] required)=>new{type="function",function=new{name,description,parameters=new{type="object",properties=fields.ToDictionary(f=>f,f=>new{type="string"}),required,additionalProperties=false}}};
}
