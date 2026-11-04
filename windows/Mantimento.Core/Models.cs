using System.Text.Json;
using System.Text.Json.Serialization;

namespace Mantimento.Core;
public record Message(string Role, string Content, string? ModelName = null) { public Guid Id { get; init; } = Guid.NewGuid(); }
public record Conversation { public Guid Id { get; init; } = Guid.NewGuid(); public string Title { get; set; } = "Nova conversa"; public List<Message> Messages { get; set; } = []; public string? Workspace { get; set; } }
public record Preferences { public string ModelId { get; set; } = "qwen35-08"; public string Compute { get; set; } = "CPU"; public string Theme { get; set; } = "Sistema"; public int MaxTokens { get; set; } = 1024; }
public record ModelEntry(string Id,string Title,string Repo,string Revision,string File,long Size,string Sha256,string Memory,string Purpose) {
    public string Url => $"https://huggingface.co/{Repo}/resolve/{Revision}/{File}";
    public static readonly ModelEntry[] Catalog = [
        new("qwen35-08","Qwen3.5 0.8B","unsloth/Qwen3.5-0.8B-GGUF","6ab461498e2023f6e3c1baea90a8f0fe38ab64d0","Qwen3.5-0.8B-Q4_K_M.gguf",532517120,"bd258782e35f7f458f8aced1adc053e6e92e89bc735ba3be89d38a06121dc517","8 GB sugeridos","Consultas curtas · opção mais leve"),
        new("qwen35-2","Qwen3.5 2B","unsloth/Qwen3.5-2B-GGUF","f6d5376be1edb4d416d56da11e5397a961aca8ae","Qwen3.5-2B-Q4_K_M.gguf",1280835840,"aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223","8–16 GB sugeridos","Conversa e escrita · experimental"),
        new("qwen35-9","Qwen3.5 9B","unsloth/Qwen3.5-9B-GGUF","3885219b6810b007914f3a7950a8d1b469d598a5","Qwen3.5-9B-Q4_K_M.gguf",5680522464,"03b74727a860a56338e042c4420bb3f04b2fec5734175f4cb9fa853daf52b7e8","16 GB ou mais","Programação e ferramentas · experimental")
    ];
}
public sealed class LocalStore {
    public static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, PropertyNameCaseInsensitive = true, WriteIndented = true };
    public string Root { get; }
    public Preferences Preferences { get; private set; }
    public List<Conversation> Conversations { get; private set; }
    public LocalStore(string? root = null) {
        Root = Path.GetFullPath(root ?? Environment.GetEnvironmentVariable("MANTIMENTO_DATA") ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Mantimento"));
        Directory.CreateDirectory(Root); Directory.CreateDirectory(Path.Combine(Root,"models"));
        Preferences = Read<Preferences>("preferences.json") ?? new();
        Conversations = Read<List<Conversation>>("conversations.json") ?? [];
    }
    T? Read<T>(string name) {
        var file=Path.Combine(Root,name);
        if (!File.Exists(file)) return default;
        try { return JsonSerializer.Deserialize<T>(File.ReadAllText(file),Json); }
        catch (JsonException) { throw new InvalidDataException($"Arquivo {name} inválido. Ele foi preservado; restaure um backup antes de continuar."); }
    }
    public static void AtomicWrite(string file,string content) {
        Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        var temporary=file+"."+Guid.NewGuid()+".tmp";
        try { File.WriteAllText(temporary,content,new System.Text.UTF8Encoding(false)); File.Move(temporary,file,true); }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    public void Save() { AtomicWrite(Path.Combine(Root,"conversations.json"),JsonSerializer.Serialize(Conversations,Json)); AtomicWrite(Path.Combine(Root,"preferences.json"),JsonSerializer.Serialize(Preferences,Json)); }
    public Conversation NewConversation() { var chat=new Conversation(); chat.Workspace=Path.Combine(Root,"Workspaces",chat.Id.ToString()); Directory.CreateDirectory(chat.Workspace); Conversations.Insert(0,chat); Save(); return chat; }
    public string Workspace(Conversation chat) { chat.Workspace ??= Path.Combine(Root,"Workspaces",chat.Id.ToString()); Directory.CreateDirectory(chat.Workspace); return chat.Workspace; }
    public Conversation ImportConversation(string file) {
        var incoming=JsonSerializer.Deserialize<Conversation>(File.ReadAllText(file),Json) ?? throw new InvalidDataException("Conversa inválida.");
        if (incoming.Messages.Count>5000 || incoming.Messages.Sum(m=>m.Content.Length)>5_000_000) throw new InvalidDataException("Conversa muito grande.");
        var chat=NewConversation(); chat.Title=incoming.Title; chat.Messages=incoming.Messages.Where(m=>m.Role is "user" or "assistant").ToList(); Save(); return chat;
    }
    public string ModelPath(ModelEntry model)=>Path.Combine(Root,"models",model.File);
    public bool Installed(ModelEntry model) { var p=ModelPath(model);return File.Exists(p)&&new FileInfo(p).Length==model.Size&&File.Exists(p+".verified"); }
}
