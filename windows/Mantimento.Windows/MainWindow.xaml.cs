using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Mantimento.Core;
using Microsoft.Win32;

namespace Mantimento.Windows;

public sealed class DisplayMessage(string author, string content) : INotifyPropertyChanged
{
    public string Author { get; } = author; private string content = content; public string Content
    {
        get => content; set
        {
            content = value;
            PropertyChanged?.Invoke(this, new(nameof(Content)));
        }
    }
    public event PropertyChangedEventHandler? PropertyChanged;
}
public record ModelCard(ModelEntry Model, string Title, string Description, string Installed);
public partial class MainWindow : Window
{
    readonly LocalStore store; readonly Engine engine = new(); readonly ObservableCollection<DisplayMessage> messages = [];
    Conversation current; CancellationTokenSource? operation; bool busy, initializing = true, follow = true; bool sidebarHidden;
    public ICommand NewChatCommand
    {
        get;
    }
    public MainWindow()
    {
        store = new LocalStore();
        current = store.Conversations.FirstOrDefault() ?? store.NewConversation();
        NewChatCommand = new SimpleCommand(() => NewChatClick(this, new()), () => !busy);
        InitializeComponent();
        DataContext = this;
        MessagesList.ItemsSource = messages;
        ComputeBox.SelectedIndex = Array.IndexOf(new[] { "CPU", "GPU", "Automático" }, store.Preferences.Compute);
        if (ComputeBox.SelectedIndex < 0)
            ComputeBox.SelectedIndex = 0;
        ThemeBox.SelectedIndex = Array.IndexOf(new[] { "Sistema", "Claro", "Escuro" }, store.Preferences.Theme);
        if (ThemeBox.SelectedIndex < 0)
            ThemeBox.SelectedIndex = 0;
        TokensBox.SelectedIndex = Array.IndexOf(new[] { 512, 1024, 2048 }, store.Preferences.MaxTokens);
        if (TokensBox.SelectedIndex < 0)
            TokensBox.SelectedIndex = 1;
        engine.Notice += s => Dispatcher.Invoke(() => StatusLabel.Text = s);
        initializing = false;
        ApplyTheme();
        RefreshHistory();
        ShowConversation();
        RefreshModels();
        UpdateControls();
        StatusLabel.Text = "Baixe ou selecione um modelo e clique em Iniciar modelo.";
    }
    string ModelPath
    {
        get
        {
            if (store.Preferences.ModelId.StartsWith("local:", StringComparison.Ordinal))
            {
                var name = store.Preferences.ModelId[6..];
                if (Path.GetFileName(name) != name)
                    throw new IOException("Modelo local inválido.");
                return Path.Combine(store.Root, "models", name);
            }
            return store.ModelPath(SelectedModel);
        }
    }
    ModelEntry SelectedModel => ModelEntry.Catalog.FirstOrDefault(m => m.Id == store.Preferences.ModelId) ?? ModelEntry.Catalog[0];
    string ModelName => store.Preferences.ModelId.StartsWith("local:") ? Path.GetFileNameWithoutExtension(ModelPath) : SelectedModel.Title;
    void RefreshHistory()
    {
        HistoryList.ItemsSource = store.Conversations.Where(c => c.Title.Contains(SearchBox.Text ?? "", StringComparison.OrdinalIgnoreCase)).ToList();
        HistoryList.SelectedItem = current;
    }
    void RefreshModels()
    {
        ModelsList.ItemsSource = ModelEntry.Catalog.Select(m => new ModelCard(m, m.Title, $"{m.Purpose}\n{m.Size / 1e9:0.0} GB · GGUF Q4_K_M · {m.Memory}", store.Installed(m) ? "No seu computador" : "Ainda não baixado")).ToList();
        ModelLabel.Text = ModelName + " · " + engine.EffectiveCompute;
    }
    void ShowConversation()
    {
        messages.Clear();
        foreach (var m in current.Messages)
            messages.Add(new(m.Role == "user" ? "Você" : m.ModelName ?? "Assistente", m.Content));
        ChatTitle.Text = current.Title;
        FullControlBox.IsChecked = false;
        follow = true;
        LatestButton.Visibility = Visibility.Collapsed;
        Dispatcher.BeginInvoke(() => ChatScroll.ScrollToEnd());
    }
    void UpdateControls()
    {
        StartButton.IsEnabled = !busy && !engine.Running;
        StopModelButton.IsEnabled = engine.Running;
        ComputeBox.IsEnabled = !busy && !engine.Running;
        NewChatButton.IsEnabled = !busy;
        HistoryList.IsEnabled = !busy;
        FolderButton.IsEnabled = !busy;
        AgentBox.IsEnabled = !busy;
        FullControlBox.IsEnabled = !busy;
        SendButton.IsEnabled = !busy && engine.Running;
        InputBox.IsReadOnly = busy;
        CommandManager.InvalidateRequerySuggested();
    }
    void Status(string text) => StatusLabel.Text = text;
    async Task RunOperation(Func<CancellationToken, Task> action, bool progress = false)
    {
        if (busy)
            return;
        busy = true;
        operation = new CancellationTokenSource();
        UpdateControls();
        CancelOperationButton.Visibility = Visibility.Visible;
        ProgressBar.Visibility = progress ? Visibility.Visible : Visibility.Collapsed;
        ProgressBar.Value = 0;
        try
        {
            await action(operation.Token);
        }
        catch (OperationCanceledException) { Status(progress ? "Download interrompido. Você pode retomar depois." : "Tarefa interrompida. O conteúdo já recebido foi preservado."); }
        catch (Exception e) { Status("Não foi possível concluir: " + e.Message); }
        finally { busy = false; operation.Dispose(); operation = null; CancelOperationButton.Visibility = Visibility.Collapsed; ProgressBar.Visibility = Visibility.Collapsed; RefreshModels(); UpdateControls(); }
    }
    void Page(UIElement selected)
    {
        ChatPage.Visibility = ModelsPage.Visibility = SettingsPage.Visibility = Visibility.Collapsed;
        selected.Visibility = Visibility.Visible;
    }
    void ChatPageClick(object sender, RoutedEventArgs e) => Page(ChatPage);
    void ModelsPageClick(object sender, RoutedEventArgs e)
    {
        Page(ModelsPage);
        RefreshModels();
    }
    void SettingsPageClick(object sender, RoutedEventArgs e) => Page(SettingsPage);
    void ToggleSidebar(object sender, RoutedEventArgs e)
    {
        sidebarHidden = !sidebarHidden;
        SidebarColumn.Width = new GridLength(sidebarHidden ? 0 : 228);
    }
    void WindowSizeChanged(object sender, SizeChangedEventArgs e)
    {
        if (SidebarColumn is not null && e.NewSize.Width < 980 && e.PreviousSize.Width >= 980)
        {
            sidebarHidden = true;
            SidebarColumn.Width = new GridLength(0);
        }
    }
    void NewChatClick(object sender, RoutedEventArgs e)
    {
        if (busy)
            return;
        current = store.NewConversation();
        InputBox.Clear();
        RefreshHistory();
        ShowConversation();
        Page(ChatPage);
    }
    void SearchChanged(object sender, TextChangedEventArgs e)
    {
        if (!initializing)
            RefreshHistory();
    }
    void HistoryChanged(object sender, SelectionChangedEventArgs e)
    {
        if (initializing || busy || HistoryList.SelectedItem is not Conversation c || c == current)
            return;
        current = c;
        InputBox.Clear();
        ShowConversation();
        Page(ChatPage);
    }
    async void StartClick(object sender, RoutedEventArgs e) => await RunOperation(async token => { Status("Carregando " + ModelName + "… Isso pode levar alguns minutos na primeira vez."); await engine.StartAsync(ModelPath, store.Preferences.Compute, token); Status("Pronto · " + engine.EffectiveCompute + " · no seu computador"); });
    void StopModelClick(object sender, RoutedEventArgs e)
    {
        operation?.Cancel();
        engine.Stop();
        Status("Modelo desligado. Memória liberada.");
        UpdateControls();
    }
    void CancelClick(object sender, RoutedEventArgs e) => operation?.Cancel();
    void ComputeChanged(object sender, SelectionChangedEventArgs e)
    {
        if (initializing)
            return;
        store.Preferences.Compute = ((ComboBoxItem)ComputeBox.SelectedItem).Content.ToString()!;
        store.Save();
    }
    async void DownloadClick(object sender, RoutedEventArgs e)
    {
        if (busy || sender is not Button { Tag: ModelEntry model })
            return;
        await RunOperation(async token => { Status("Baixando " + model.Title + "…"); var progress = new Progress<(long Received, long Total)>(p => { ProgressBar.Value = (double)p.Received / p.Total; Status(p.Received == p.Total ? "Verificando SHA-256…" : $"Baixando {model.Title}: {p.Received / 1e9:0.00} / {p.Total / 1e9:0.00} GB"); }); await Downloads.DownloadAsync(store, model, progress, token); Status("Modelo verificado. Clique em Usar para selecioná-lo."); }, true);
    }
    void UseModelClick(object sender, RoutedEventArgs e)
    {
        if (busy)
            return;
        if (engine.Running)
        {
            Status("Desligue o modelo atual antes de selecionar outro.");
            return;
        }
        if (sender is Button { Tag: ModelEntry model })
        {
            if (!store.Installed(model))
            {
                Status("Baixe o modelo antes de selecionar.");
                return;
            }
            store.Preferences.ModelId = model.Id;
            store.Save();
            RefreshModels();
            Status(model.Title + " selecionado. Volte a Conversa e inicie o modelo.");
        }
    }
    void RemoveModelClick(object sender, RoutedEventArgs e)
    {
        if (busy || engine.Running)
            return;
        if (sender is Button { Tag: ModelEntry model } && store.Installed(model) && MessageBox.Show("Remover o modelo baixado? Ele será movido para a Lixeira. As conversas serão preservadas.", "Remover modelo", MessageBoxButton.OKCancel, MessageBoxImage.Question) == MessageBoxResult.OK)
        {
            try
            {
                Microsoft.VisualBasic.FileIO.FileSystem.DeleteFile(store.ModelPath(model), Microsoft.VisualBasic.FileIO.UIOption.OnlyErrorDialogs, Microsoft.VisualBasic.FileIO.RecycleOption.SendToRecycleBin);
                File.Delete(store.ModelPath(model) + ".verified");
                RefreshModels();
                Status("Modelo movido para a Lixeira.");
            }
            catch (Exception ex) { Status(ex.Message); }
        }
    }
    void ModelDetailsClick(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: ModelEntry model })
            OpenUrl("https://huggingface.co/" + model.Repo);
    }
    async void ImportModelClick(object sender, RoutedEventArgs e)
    {
        if (busy || engine.Running)
            return;
        var picker = new OpenFileDialog { Filter = "Modelo GGUF|*.gguf", Title = "Escolher modelo GGUF de texto" };
        if (picker.ShowDialog(this) != true)
            return;
        await RunOperation(async token => { await using (var input = File.OpenRead(picker.FileName)) { var magic = new byte[4]; if (await input.ReadAsync(magic, token) != 4 || System.Text.Encoding.ASCII.GetString(magic) != "GGUF") throw new IOException("Arquivo GGUF inválido."); } var name = "local-" + Guid.NewGuid() + ".gguf"; var destination = Path.Combine(store.Root, "models", name); try { await using var source = File.OpenRead(picker.FileName); await using var output = File.Create(destination); await source.CopyToAsync(output, token); } catch { if (File.Exists(destination)) File.Delete(destination); throw; } store.Preferences.ModelId = "local:" + name; store.Save(); Status("Modelo importado. A compatibilidade será verificada ao carregar."); });
    }
    void FolderClick(object sender, RoutedEventArgs e)
    {
        if (busy)
            return;
        var picker = new OpenFolderDialog { Title = "Pasta desta conversa", InitialDirectory = store.Workspace(current) };
        if (picker.ShowDialog(this) == true)
        {
            current.Workspace = picker.FolderName;
            store.Save();
            FolderButton.ToolTip = picker.FolderName;
            FolderButton.Content = "Pasta: " + Path.GetFileName(picker.FolderName);
            FullControlBox.IsChecked = false;
        }
    }
    void AgentChanged(object sender, RoutedEventArgs e)
    {
        if (FullControlBox is not null)
        {
            FullControlBox.Visibility = AgentBox.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
            FullControlBox.IsChecked = false;
        }
    }
    async void SendClick(object sender, RoutedEventArgs e)
    {
        var input = InputBox.Text.Trim();
        if (busy || !engine.Running || input.Length == 0)
            return;
        current.Messages.Add(new("user", input));
        if (current.Messages.Count(m => m.Role == "user") == 1)
            current.Title = input[..Math.Min(input.Length, 44)];
        messages.Add(new("Você", input));
        InputBox.Clear();
        store.Save();
        RefreshHistory();
        var agent = AgentBox.IsChecked == true;
        var full = FullControlBox.IsChecked == true;
        follow = true;
        LatestButton.Visibility = Visibility.Collapsed;
        await RunOperation(async token =>
        {
            CancelButton.Visibility = Visibility.Visible;
            SendButton.Visibility = Visibility.Collapsed;
            Status(agent ? "Agente trabalhando…" : "Respondendo…");
            try
            {
                if (agent)
                {
                    var tools = new WorkspaceTools(store.Workspace(current), ReviewAsync);
                    await Chat.AgentAsync(engine.Client!, current, tools, full, store.Preferences.MaxTokens, m => { var named = m with { ModelName = ModelName }; current.Messages.Add(named); messages.Add(new(ModelName, named.Content)); if (follow) ChatScroll.ScrollToEnd(); store.Save(); }, token);
                }
                else
                {
                    var display = new DisplayMessage(ModelName, "");
                    var text = new System.Text.StringBuilder();
                    var last = Stopwatch.StartNew();
                    var answer = new Message("assistant", "", ModelName);
                    current.Messages.Add(answer);
                    messages.Add(display);
                    try
                    {
                        await foreach (var delta in Chat.StreamAsync(engine.Client!, current with
                        {
                            Messages = current.Messages.Where(m => m.Id != answer.Id).ToList()
                        }, store.Preferences.MaxTokens, token))
                        {
                            text.Append(delta);
                            if (last.ElapsedMilliseconds >= 80)
                            {
                                display.Content = text.ToString();
                                current.Messages[^1] = answer with
                                {
                                    Content = display.Content
                                };
                                if (follow)
                                    ChatScroll.ScrollToEnd();
                                last.Restart();
                            }
                        }
                    }
                    finally { display.Content = text.ToString(); current.Messages[^1] = answer with { Content = display.Content }; if (follow) ChatScroll.ScrollToEnd(); }
                }
                Status("Resposta concluída · " + engine.EffectiveCompute);
            }
            finally { store.Save(); CancelButton.Visibility = Visibility.Collapsed; SendButton.Visibility = Visibility.Visible; }
        });
    }
    Task<bool> ReviewAsync(Proposal proposal, CancellationToken token)
    {
        token.ThrowIfCancellationRequested();
        var dialog = new ReviewWindow(proposal) { Owner = this };
        using var registration = token.Register(() => Dispatcher.BeginInvoke(() => dialog.Close()));
        return Task.FromResult(dialog.ShowDialog() == true);
    }
    void InputKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter && Keyboard.Modifiers.HasFlag(ModifierKeys.Control))
        {
            e.Handled = true;
            SendClick(sender, new());
        }
    }
    void ChatMouseWheel(object sender, MouseWheelEventArgs e)
    {
        if (e.Delta > 0)
        {
            follow = false;
            LatestButton.Visibility = Visibility.Visible;
        }
    }
    void LatestClick(object sender, RoutedEventArgs e)
    {
        follow = true;
        LatestButton.Visibility = Visibility.Collapsed;
        ChatScroll.ScrollToEnd();
    }
    void CopyMessageClick(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: string text })
            try
            {
                Clipboard.SetText(text);
            }
            catch (System.Runtime.InteropServices.ExternalException) { Status("Área de transferência ocupada; tente novamente."); }
    }
    void ThemeChanged(object sender, SelectionChangedEventArgs e)
    {
        if (initializing)
            return;
        store.Preferences.Theme = ((ComboBoxItem)ThemeBox.SelectedItem).Content.ToString()!;
        store.Save();
        ApplyTheme();
    }
    static bool SystemUsesLightTheme()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return key?.GetValue("AppsUseLightTheme") is not int setting || setting != 0;
        }
        catch (System.Security.SecurityException) { return true; }
    }
    void ApplyTheme()
    {
        var dark = store.Preferences.Theme == "Escuro" || (store.Preferences.Theme == "Sistema" && !SystemUsesLightTheme());
        var colors = dark ? new[] { "#151C29", "#1D2737", "#ECF1FA", "#B6C3D8", "#35445B", "#3979DC" } : new[] { "#F8FAFC", "#FFFFFF", "#182235", "#596579", "#DBE3EE", "#2164CE" };
        var keys = new[] { "WindowBrush", "PanelBrush", "TextBrush", "MutedBrush", "LineBrush", "AccentBrush" };
        for (var i = 0; i < keys.Length; i++)
            Application.Current.Resources[keys[i]] = new SolidColorBrush((Color)ColorConverter.ConvertFromString(colors[i]));
    }
    void TokensChanged(object sender, SelectionChangedEventArgs e)
    {
        if (initializing)
            return;
        store.Preferences.MaxTokens = int.Parse(((ComboBoxItem)TokensBox.SelectedItem).Content.ToString()!);
        store.Save();
    }
    void ExportClick(object sender, RoutedEventArgs e)
    {
        if (busy)
            return;
        var save = new SaveFileDialog { Filter = "Conversa JSON|*.json", FileName = "conversa-mantimento.json" };
        if (save.ShowDialog(this) == true)
            try
            {
                var export = current with
                {
                    Workspace = null
                };
                LocalStore.AtomicWrite(save.FileName, JsonSerializer.Serialize(export, LocalStore.Json));
                Status("Conversa exportada. Pode conter dados pessoais.");
            }
            catch (Exception ex) { Status(ex.Message); }
    }
    void ImportChatClick(object sender, RoutedEventArgs e)
    {
        if (busy)
            return;
        var open = new OpenFileDialog { Filter = "Conversa JSON|*.json" };
        if (open.ShowDialog(this) == true)
            try
            {
                if (new FileInfo(open.FileName).Length > 10_000_000)
                    throw new IOException("Arquivo muito grande.");
                current = store.ImportConversation(open.FileName);
                RefreshHistory();
                ShowConversation();
                Page(ChatPage);
            }
            catch (Exception ex) { Status(ex.Message); }
    }
    void OpenDataClick(object sender, RoutedEventArgs e) => Process.Start(new ProcessStartInfo(store.Root) { UseShellExecute = true });
    static void OpenUrl(string url) => Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
    void IssuesClick(object sender, RoutedEventArgs e) => OpenUrl("https://github.com/wilgnerschuertz/Mantimento/issues/new/choose");
    void LogsClick(object sender, RoutedEventArgs e)
    {
        var text = new TextBox { Text = engine.Logs.Length == 0 ? "Sem registros." : engine.Logs, IsReadOnly = true, AcceptsReturn = true, TextWrapping = TextWrapping.NoWrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, HorizontalScrollBarVisibility = ScrollBarVisibility.Auto, Margin = new Thickness(16) };
        new Window { Owner = this, Title = "Registros · revise antes de compartilhar", Content = text, Width = 700, Height = 450, MinWidth = 450, MinHeight = 300 }.ShowDialog();
    }
    void WindowClosing(object? sender, CancelEventArgs e)
    {
        operation?.Cancel();
        store.Save();
        engine.Dispose();
    }
    public async Task SmokeAsync()
    {
        await Dispatcher.InvokeAsync(() => { }, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
        var folder = Environment.GetEnvironmentVariable("MANTIMENTO_SMOKE_OUTPUT") ?? Path.Combine(store.Root, "screenshots");
        Directory.CreateDirectory(folder);
        current.Title = "Uma conversa com um título muito longo para verificar os limites da interface e a navegação";
        current.Messages = [new("user", "Leia os documentos desta pasta e explique como organizar um projeto local."), new("assistant", string.Join("\n\n", Enumerable.Range(1, 15).Select(n => $"Etapa {n}: revise os arquivos e mantenha uma cópia do conteúdo antes de editar.")), "Qwen3.5 0.8B")];
        ShowConversation();
        InputBox.Text = string.Join("\n", Enumerable.Repeat("Uma mensagem longa para conferir a área de leitura.", 8));
        AgentBox.IsChecked = true;
        foreach (var size in new[] { (W: 800d, H: 640d), (W: 1120d, H: 800d) })
        foreach (var dark in new[] { false, true })
        foreach (var scene in new[] { "models", "chat", "settings" })
        {
            Width = size.W;
            Height = size.H;
            sidebarHidden = size.W < 980;
            SidebarColumn.Width = new GridLength(sidebarHidden ? 0 : 228);
            store.Preferences.Theme = dark ? "Escuro" : "Claro";
            ApplyTheme();
            Page(scene == "models" ? ModelsPage : scene == "chat" ? ChatPage : SettingsPage);
            UpdateLayout();
            await Dispatcher.InvokeAsync(() => { }, System.Windows.Threading.DispatcherPriority.ApplicationIdle);
            var visual=(FrameworkElement)Content;
            var image = new RenderTargetBitmap((int)Math.Ceiling(visual.ActualWidth), (int)Math.Ceiling(visual.ActualHeight), 96, 96, PixelFormats.Pbgra32);
            image.Render(visual);
            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(image));
            using var file = File.Create(Path.Combine(folder, $"{scene}-{size.W}-{(dark ? "dark" : "light")}.png"));
            encoder.Save(file);
            if (StatusLabel.ActualHeight < 1 || StartButton.ActualWidth < 1)
                throw new InvalidOperationException("Controles não renderizados.");
        }
        Close();
    }
}
public sealed class SimpleCommand(Action action, Func<bool> enabled) : ICommand
{
    public bool CanExecute(object? parameter) => enabled(); public void Execute(object? parameter) => action(); public event EventHandler? CanExecuteChanged { add => CommandManager.RequerySuggested += value; remove => CommandManager.RequerySuggested -= value; }
}
