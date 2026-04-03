using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;
using Orbital.Models;
using Orbital.Services;
using WpfBrushes = System.Windows.Media.Brushes;
using WpfFontFamily = System.Windows.Media.FontFamily;
using WpfApplication = System.Windows.Application;
using WpfCheckBox = System.Windows.Controls.CheckBox;
using WpfOrientation = System.Windows.Controls.Orientation;
using WpfSystemColors = System.Windows.SystemColors;

namespace Orbital.Views;

public partial class TrayPopupWindow : Window
{
    private readonly MissionDataService _service;
    private bool _suppressUnitChange;
    private string? _updateUrl;

    public event Action<bool>? FloatingWidgetToggled;

    public bool IsFloatingWidgetVisible { get; set; }

    public TrayPopupWindow(MissionDataService service)
    {
        InitializeComponent();
        _service = service;

        // Units combo
        _suppressUnitChange = true;
        UnitsCombo.Items.Add("Metric (km, km/h)");
        UnitsCombo.Items.Add("Imperial (mi, mph)");
        UnitsCombo.SelectedIndex = _service.Units == UnitSystem.Imperial ? 1 : 0;
        _suppressUnitChange = false;

        // Launch at login
        LaunchAtLoginCheck.IsChecked = IsLaunchAtLoginEnabled();
        FloatingWidgetCheck.IsChecked = IsFloatingWidgetVisible;

        BuildMetricToggles();
        UpdateUI();
    }

    public void UpdateUI()
    {
        var data = _service.Data;

        // Header
        MissionNameText.Text = data.MissionName;
        MissionSubtitleText.Text = data.MissionSubtitle;

        var status = _service.Data.MissionElapsedTime > 0 ? "ACTIVE" : "PENDING";
        var statusColor = _service.Data.MissionElapsedTime > 0 ? WpfBrushes.Green : WpfBrushes.Orange;
        LiveIndicator.Fill = statusColor;
        LiveText.Text = status;
        LiveText.Foreground = statusColor;

        // Phase
        PhaseIcon.Text = IconMapper.GetIcon(data.Phase.Icon);
        PhaseName.Text = data.Phase.Name;
        PhaseDescription.Text = data.Phase.Description;

        // Metrics
        MetricsPanel.Children.Clear();
        foreach (var metric in _service.Metrics)
        {
            var row = new Grid { Margin = new Thickness(0, 2, 0, 2) };
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(20) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var icon = new TextBlock
            {
                Text = IconMapper.GetIcon(metric.Icon),
                FontSize = 12,
                Foreground = WpfSystemColors.GrayTextBrush,
                VerticalAlignment = VerticalAlignment.Center
            };
            Grid.SetColumn(icon, 0);

            var label = new TextBlock
            {
                Text = metric.Label,
                FontSize = 13,
                Foreground = WpfSystemColors.GrayTextBrush,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(4, 0, 0, 0)
            };
            Grid.SetColumn(label, 1);

            var value = new TextBlock
            {
                Text = data.FormattedDetailValue(metric, _service.Units),
                FontSize = 13,
                FontWeight = FontWeights.Medium,
                FontFamily = new WpfFontFamily("Consolas"),
                VerticalAlignment = VerticalAlignment.Center
            };
            Grid.SetColumn(value, 2);

            row.Children.Add(icon);
            row.Children.Add(label);
            row.Children.Add(value);
            MetricsPanel.Children.Add(row);
        }

        // Crew
        while (CrewPanel.Children.Count > 1)
            CrewPanel.Children.RemoveAt(CrewPanel.Children.Count - 1);

        foreach (var member in data.CrewMembers)
        {
            var sp = new StackPanel { Orientation = WpfOrientation.Horizontal, Margin = new Thickness(0, 1, 0, 1) };
            sp.Children.Add(new TextBlock
            {
                Text = IconMapper.GetIcon("person.fill"),
                FontSize = 11,
                Foreground = WpfSystemColors.GrayTextBrush,
                Margin = new Thickness(0, 0, 6, 0)
            });
            sp.Children.Add(new TextBlock { Text = member, FontSize = 13 });
            CrewPanel.Children.Add(sp);
        }

        // Footer
        FooterText.Text = "Data from API";
    }

    public void BuildMetricToggles()
    {
        MetricTogglesPanel.Children.Clear();
        foreach (var metric in _service.Metrics)
        {
            var cb = new WpfCheckBox
            {
                IsChecked = _service.IsMetricEnabled(metric.Id),
                Margin = new Thickness(0, 2, 0, 2),
                Tag = metric.Id
            };

            var sp = new StackPanel { Orientation = WpfOrientation.Horizontal };
            sp.Children.Add(new TextBlock
            {
                Text = IconMapper.GetIcon(metric.Icon),
                FontSize = 12,
                Foreground = WpfSystemColors.GrayTextBrush,
                Width = 20,
                VerticalAlignment = VerticalAlignment.Center
            });
            sp.Children.Add(new TextBlock
            {
                Text = metric.Label,
                FontSize = 13,
                VerticalAlignment = VerticalAlignment.Center
            });

            cb.Content = sp;
            cb.Click += MetricToggle_Click;
            MetricTogglesPanel.Children.Add(cb);
        }
    }

    private void MetricToggle_Click(object sender, RoutedEventArgs e)
    {
        if (sender is WpfCheckBox cb && cb.Tag is string id)
        {
            _service.ToggleMetric(id);
            cb.IsChecked = _service.IsMetricEnabled(id);
        }
    }

    private void UnitsCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressUnitChange) return;
        _service.Units = UnitsCombo.SelectedIndex == 1 ? UnitSystem.Imperial : UnitSystem.Metric;
        _service.SaveSettings();
        UpdateUI();
    }

    private void FloatingWidget_Click(object sender, RoutedEventArgs e)
    {
        var enabled = FloatingWidgetCheck.IsChecked == true;
        IsFloatingWidgetVisible = enabled;
        FloatingWidgetToggled?.Invoke(enabled);
    }

    private void LaunchAtLogin_Click(object sender, RoutedEventArgs e)
    {
        var enabled = LaunchAtLoginCheck.IsChecked == true;
        SetLaunchAtLogin(enabled);
    }

    private void TipButton_Click(object sender, RoutedEventArgs e)
    {
        Process.Start(new ProcessStartInfo("https://buymeacoffee.com/digitalhen") { UseShellExecute = true });
    }

    public void ShowUpdateBanner(string updateUrl)
    {
        _updateUrl = updateUrl;
        UpdateBanner.Visibility = Visibility.Visible;
    }

    private void UpdateBanner_Click(object sender, System.Windows.Input.MouseButtonEventArgs e)
    {
        if (_updateUrl != null)
            Process.Start(new ProcessStartInfo(_updateUrl) { UseShellExecute = true });
    }

    private void QuitButton_Click(object sender, RoutedEventArgs e)
    {
        WpfApplication.Current.Shutdown();
    }

    private void Window_Deactivated(object sender, EventArgs e)
    {
        Hide();
    }

    private static bool IsLaunchAtLoginEnabled()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", false);
            return key?.GetValue("Orbital") != null;
        }
        catch { return false; }
    }

    private static void SetLaunchAtLogin(bool enabled)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true);
            if (key == null) return;

            if (enabled)
            {
                var exePath = Process.GetCurrentProcess().MainModule?.FileName;
                if (exePath != null)
                    key.SetValue("Orbital", $"\"{exePath}\"");
            }
            else
            {
                key.DeleteValue("Orbital", false);
            }
        }
        catch { /* ignore */ }
    }
}
