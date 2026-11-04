using System.Windows;
namespace Mantimento.Windows;
public partial class App:Application {
 protected override async void OnStartup(StartupEventArgs e) {
  base.OnStartup(e);
  try { var window=new MainWindow();MainWindow=window;window.Show();if(e.Args.Contains("--ui-smoke")){await window.SmokeAsync();Shutdown(0);} }
  catch(Exception ex){if(e.Args.Contains("--ui-smoke")){System.IO.File.WriteAllText("ui-smoke-error.txt",ex.ToString());Shutdown(1);}else{MessageBox.Show(ex.Message,"Mantimento · não foi possível abrir",MessageBoxButton.OK,MessageBoxImage.Error);Shutdown(1);}}
 }
}
