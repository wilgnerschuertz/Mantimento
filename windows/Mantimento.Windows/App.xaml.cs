using System.Windows;
namespace Mantimento.Windows;

public partial class App : Application
{
    Mutex? instance;
    protected override void OnExit(ExitEventArgs e)
    {
        instance?.Dispose();
        base.OnExit(e);
    }
    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        if (e.Args.Contains("--ui-smoke"))
            Environment.SetEnvironmentVariable("MANTIMENTO_DATA", System.IO.Path.Combine(System.IO.Path.GetTempPath(), "Mantimento-UI-" + Guid.NewGuid()));
        var root = Environment.GetEnvironmentVariable("MANTIMENTO_DATA") ?? System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Mantimento");
        var id = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(root.ToUpperInvariant())));
        instance = new Mutex(true, "Local\\Mantimento-" + id, out var created);
        if (!created)
        {
            MessageBox.Show("O Mantimento já está aberto para esta pasta de dados.", "Mantimento");
            Shutdown(0);
            return;
        }
        try
        {
            var window = new MainWindow();
            MainWindow = window;
            window.Show();
            if (e.Args.Contains("--ui-smoke"))
            {
                await window.SmokeAsync();
                Shutdown(0);
            }
        }
        catch (Exception ex) { if (e.Args.Contains("--ui-smoke")) { System.IO.File.WriteAllText("ui-smoke-error.txt", ex.ToString()); Shutdown(1); } else { MessageBox.Show(ex.Message, "Mantimento · não foi possível abrir", MessageBoxButton.OK, MessageBoxImage.Error); Shutdown(1); } }
    }
}
