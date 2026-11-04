using System.Windows;
using System.Windows.Controls;
using Mantimento.Core;
namespace Mantimento.Windows;

public sealed class ReviewWindow : Window
{
    public ReviewWindow(Proposal proposal)
    {
        Title = proposal.Title;
        Width = 820;
        Height = 540;
        MinWidth = 600;
        MinHeight = 420;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        var root = new DockPanel { Margin = new Thickness(20) };
        var title = new TextBlock { Text = proposal.Title, FontSize = 22, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 0, 0, 16) };
        DockPanel.SetDock(title, Dock.Top);
        root.Children.Add(title);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 14, 0, 0) };
        DockPanel.SetDock(buttons, Dock.Bottom);
        var no = new Button { Content = "Recusar", IsCancel = true };
        no.Click += (_, _) => { DialogResult = false; };
        var yes = new Button { Content = "Aprovar e executar" };
        yes.Click += (_, _) => { DialogResult = true; };
        buttons.Children.Add(no);
        buttons.Children.Add(yes);
        root.Children.Add(buttons);
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new());
        grid.ColumnDefinitions.Add(new());
        var before = Panel("Antes / contexto", proposal.Before);
        var after = Panel("Proposta", proposal.After);
        Grid.SetColumn(after, 1);
        grid.Children.Add(before);
        grid.Children.Add(after);
        root.Children.Add(grid);
        Content = root;
    }
    static FrameworkElement Panel(string title, string text)
    {
        var panel = new DockPanel { Margin = new Thickness(6) };
        var label = new TextBlock { Text = title, FontWeight = FontWeights.SemiBold, Margin = new Thickness(0, 0, 0, 8) };
        DockPanel.SetDock(label, Dock.Top);
        panel.Children.Add(label);
        panel.Children.Add(new TextBox { Text = text, IsReadOnly = true, AcceptsReturn = true, TextWrapping = TextWrapping.NoWrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, HorizontalScrollBarVisibility = ScrollBarVisibility.Auto, FontFamily = new System.Windows.Media.FontFamily("Consolas") });
        return panel;
    }
}
