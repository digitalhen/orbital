using System.Drawing;
using System.Text.Json;
using System.Windows;
using System.Windows.Threading;
using Orbital.Models;
using Orbital.Services;
using WinForms = System.Windows.Forms;
using WpfApplication = System.Windows.Application;

namespace Orbital.Views;

public class TrayIconManager : IDisposable
{
    private readonly MissionDataService _service;
    private readonly WinForms.NotifyIcon _trayIcon;
    private readonly TaskbarWidgetWindow _widget;
    private TrayPopupWindow? _popup;
    private readonly DispatcherTimer _uiTimer;
    private bool _widgetEnabled;

    private static readonly string WidgetSettingsFile = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Orbital", "widget-visible.txt");

    public TrayIconManager(MissionDataService service)
    {
        _service = service;
        _widgetEnabled = LoadWidgetVisible();

        // Tray icon — primary interaction point
        _trayIcon = new WinForms.NotifyIcon
        {
            Text = "Orbital \u2014 NASA Mission Tracker",
            Visible = true,
            Icon = CreateTrayIcon()
        };

        var menu = new WinForms.ContextMenuStrip();
        menu.Items.Add("Show Floating Widget", null, (_, _) => SetWidgetVisible(true));
        menu.Items.Add(new WinForms.ToolStripSeparator());
        menu.Items.Add("Quit Orbital", null, (_, _) => WpfApplication.Current.Shutdown());
        _trayIcon.ContextMenuStrip = menu;
        _trayIcon.MouseClick += (_, e) =>
        {
            if (e.Button == WinForms.MouseButtons.Left)
                TogglePopup();
        };

        // Floating widget window
        _widget = new TaskbarWidgetWindow(service);
        _widget.WidgetClicked += TogglePopup;
        if (_widgetEnabled)
            _widget.Show();

        // 1Hz UI update
        _uiTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _uiTimer.Tick += (_, _) => OnTick();
        _uiTimer.Start();

        _service.MetricsChanged += () =>
        {
            WpfApplication.Current?.Dispatcher.Invoke(() =>
            {
                _widget.UpdateMetrics();
                _popup?.BuildMetricToggles();
            });
        };

        // Show popup on first run
        if (IsFirstRun())
        {
            // Small delay so the widget is positioned first
            var firstRunTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(500) };
            firstRunTimer.Tick += (_, _) =>
            {
                firstRunTimer.Stop();
                TogglePopup();
            };
            firstRunTimer.Start();
        }
    }

    private static readonly string FirstRunFile = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Orbital", "launched");

    private static bool IsFirstRun()
    {
        if (File.Exists(FirstRunFile)) return false;
        try
        {
            var dir = Path.GetDirectoryName(FirstRunFile)!;
            Directory.CreateDirectory(dir);
            File.WriteAllText(FirstRunFile, "1");
        }
        catch { /* ignore */ }
        return true;
    }

    private static Icon CreateTrayIcon()
    {
        // Load the app icon from embedded resource
        var assembly = System.Reflection.Assembly.GetExecutingAssembly();
        var resourceName = assembly.GetManifestResourceNames()
            .FirstOrDefault(n => n.EndsWith("orbital.ico"));

        if (resourceName != null)
        {
            using var stream = assembly.GetManifestResourceStream(resourceName)!;
            return new Icon(stream, 32, 32);
        }

        // Fallback: simple programmatic icon
        using var bmp = new Bitmap(32, 32);
        using var g = Graphics.FromImage(bmp);
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        g.Clear(Color.Transparent);
        using var orbitPen = new Pen(Color.White, 2f);
        g.DrawEllipse(orbitPen, 3, 3, 25, 25);
        using var dotBrush = new SolidBrush(Color.FromArgb(0, 120, 215));
        g.FillEllipse(dotBrush, 21, 2, 8, 8);
        return Icon.FromHandle(bmp.GetHicon());
    }

    private void OnTick()
    {
        UpdateTooltip();
        if (_widgetEnabled)
        {
            if (!_widget.IsVisible)
                _widget.Show();
            _widget.UpdateMetrics();
        }
        if (_popup?.IsVisible == true)
            _popup.UpdateUI();
    }

    private void UpdateTooltip()
    {
        var data = _service.Data;
        var units = _service.Units;

        var parts = new List<string>();
        foreach (var metric in _service.Metrics)
        {
            if (!_service.IsMetricEnabled(metric.Id)) continue;
            var val = data.FormattedValue(metric, units);
            var label = string.IsNullOrEmpty(metric.ShortLabel) ? metric.Label : metric.ShortLabel;
            parts.Add($"{label}: {val}");
        }

        var tooltip = $"Orbital \u2014 {data.MissionName}\n{string.Join(" | ", parts)}";
        if (tooltip.Length > 63) tooltip = tooltip[..63];
        _trayIcon.Text = tooltip;
    }

    private void SetWidgetVisible(bool visible)
    {
        _widgetEnabled = visible;
        if (visible)
        {
            _widget.UpdateMetrics();
            _widget.Show();
        }
        else
        {
            _widget.Hide();
        }
        SaveWidgetVisible(visible);

        // Update popup checkbox if open
        if (_popup != null)
        {
            _popup.IsFloatingWidgetVisible = visible;
            _popup.FloatingWidgetCheck.IsChecked = visible;
        }

        // Update right-click menu text
        _trayIcon.ContextMenuStrip!.Items[0].Text = visible ? "Hide Floating Widget" : "Show Floating Widget";
    }

    private void TogglePopup()
    {
        if (_popup?.IsVisible == true)
        {
            _popup.Hide();
            return;
        }

        if (_popup == null)
        {
            _popup = new TrayPopupWindow(_service)
            {
                IsFloatingWidgetVisible = _widgetEnabled
            };
            _popup.FloatingWidgetCheck.IsChecked = _widgetEnabled;
            _popup.FloatingWidgetToggled += SetWidgetVisible;
        }

        _popup.UpdateUI();
        PositionPopup();
        _popup.Show();
        _popup.Activate();
    }

    private void PositionPopup()
    {
        if (_popup == null) return;

        _popup.Measure(new System.Windows.Size(double.PositiveInfinity, double.PositiveInfinity));
        _popup.Arrange(new Rect(_popup.DesiredSize));
        _popup.UpdateLayout();

        var workArea = SystemParameters.WorkArea;
        var popupWidth = _popup.ActualWidth > 0 ? _popup.ActualWidth : 348;
        var popupHeight = _popup.ActualHeight > 0 ? _popup.ActualHeight : 600;

        // Position near cursor (above taskbar)
        var cursorPos = WinForms.Cursor.Position;
        var dpi = System.Windows.PresentationSource.FromVisual(_popup)?.CompositionTarget?.TransformFromDevice.M11 ?? 1.0;

        var left = cursorPos.X * dpi - popupWidth / 2;
        var top = workArea.Bottom - popupHeight - 8;

        if (left + popupWidth > workArea.Right) left = workArea.Right - popupWidth - 8;
        if (left < workArea.Left) left = workArea.Left + 8;
        if (top < workArea.Top) top = workArea.Top + 8;

        _popup.Left = left;
        _popup.Top = top;
    }

    private static bool LoadWidgetVisible()
    {
        try
        {
            if (File.Exists(WidgetSettingsFile))
                return File.ReadAllText(WidgetSettingsFile).Trim() == "true";
        }
        catch { /* ignore */ }
        return true; // visible by default
    }

    private static void SaveWidgetVisible(bool visible)
    {
        try
        {
            var dir = Path.GetDirectoryName(WidgetSettingsFile)!;
            Directory.CreateDirectory(dir);
            File.WriteAllText(WidgetSettingsFile, visible ? "true" : "false");
        }
        catch { /* ignore */ }
    }

    public void Dispose()
    {
        _uiTimer.Stop();
        _trayIcon.Visible = false;
        _trayIcon.Dispose();
        _widget.Close();
        _popup?.Close();
    }
}
