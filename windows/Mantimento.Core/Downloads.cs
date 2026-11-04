using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;

namespace Mantimento.Core;
public static class Downloads {
    public static async Task<string> DownloadAsync(LocalStore store,ModelEntry model,IProgress<(long Received,long Total)>? progress,CancellationToken token,HttpClient? client=null) {
        using var owned = client is null ? new HttpClient(new HttpClientHandler { AllowAutoRedirect=true }) { Timeout=Timeout.InfiniteTimeSpan } : null;
        client ??= owned!;
        var target=store.ModelPath(model); var part=target+".partial";
        var offset=File.Exists(part)?new FileInfo(part).Length:0;
        if (offset>model.Size) { File.Delete(part); offset=0; }
        var drive=new DriveInfo(Path.GetPathRoot(target)!);
        if(drive.AvailableFreeSpace<model.Size-offset+256L*1024*1024) throw new IOException("Espaço insuficiente para baixar este modelo.");
        if(offset<model.Size) {
            using var request=new HttpRequestMessage(HttpMethod.Get,model.Url);
            if(offset>0) request.Headers.Range=new RangeHeaderValue(offset,null);
            using var response=await client.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,token);
            response.EnsureSuccessStatusCode();
            if(response.StatusCode==HttpStatusCode.PartialContent) {
                if(response.Content.Headers.ContentRange?.From!=offset) throw new IOException("Servidor retornou uma faixa de download incorreta.");
            } else { offset=0; }
            await using var output=new FileStream(part,offset>0?FileMode.Append:FileMode.Create,FileAccess.Write,FileShare.Read,1024*1024,true);
            await using var input=await response.Content.ReadAsStreamAsync(token);
            var buffer=new byte[1024*1024]; int read;
            while((read=await input.ReadAsync(buffer,token))>0) {
                if(offset+read>model.Size) throw new IOException("Download excedeu o tamanho esperado.");
                await output.WriteAsync(buffer.AsMemory(0,read),token); offset+=read; progress?.Report((offset,model.Size));
            }
        }
        if(new FileInfo(part).Length!=model.Size) throw new IOException("Download incompleto; tente novamente para retomar.");
        progress?.Report((model.Size,model.Size));
        await VerifyAsync(part,model.Sha256,token);
        File.Move(part,target,true); LocalStore.AtomicWrite(target+".verified",model.Sha256);
        return target;
    }
    public static async Task VerifyAsync(string file,string expected,CancellationToken token) {
        string hash;
        await using(var stream=File.OpenRead(file)) hash=Convert.ToHexString(await SHA256.HashDataAsync(stream,token));
        if(!hash.Equals(expected,StringComparison.OrdinalIgnoreCase)) {
            if(file.EndsWith(".partial",StringComparison.Ordinal)) File.Delete(file);
            throw new InvalidDataException("SHA-256 não confere. O arquivo não será executado/carregado; baixe novamente.");
        }
    }
}
