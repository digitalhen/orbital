using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using Orbital.Models;
using Orbital.Services;
using WpfFontFamily = System.Windows.Media.FontFamily;
using WpfColor = System.Windows.Media.Color;
using WpfColors = System.Windows.Media.Colors;

namespace Orbital.Views;

public partial class TaskbarWidgetWindow : Window
{
    private readonly MissionDataService _service;
    private static readonly WpfFontFamily UiFont = new("Segoe UI");
    private static readonly WpfFontFamily UiBoldFont = new("Segoe UI Semibold");

    // Win32 interop for persistent overlay
    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_NOACTIVATE = 0x08000000;
    private const int WS_EX_TOOLWINDOW = 0x00000080;

    private const int WM_WINDOWPOSCHANGING = 0x0046;
    private const int SWP_NOSIZE = 0x0001;
    private const int SWP_NOMOVE = 0x0002;
    private const int SWP_HIDEWINDOW = 0x0080;

    [DllImport("user32.dll")]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [StructLayout(LayoutKind.Sequential)]
    private struct WINDOWPOS
    {
        public IntPtr hwnd, hwndInsertAfter;
        public int x, y, cx, cy, flags;
    }

    public event Action? WidgetClicked;

    public TaskbarWidgetWindow(MissionDataService service)
    {
        InitializeComponent();
        _service = service;

        Loaded += (_, _) =>
        {
            var hwnd = new WindowInteropHelper(this).Handle;
            var exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
            SetWindowLong(hwnd, GWL_EXSTYLE, exStyle | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW);

            // Hook into WndProc to prevent the window from being hidden
            var source = HwndSource.FromHwnd(hwnd);
            source?.AddHook(WndProc);

            // Render metrics first so we know the real width, then position
            UpdateMetrics();
            RestorePosition();
        };
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WM_WINDOWPOSCHANGING)
        {
            // Prevent any external attempt to hide this window (e.g., Show Desktop)
            var pos = Marshal.PtrToStructure<WINDOWPOS>(lParam);
            if ((pos.flags & SWP_HIDEWINDOW) != 0)
            {
                pos.flags &= ~SWP_HIDEWINDOW;
                Marshal.StructureToPtr(pos, lParam, false);
            }
        }
        return IntPtr.Zero;
    }

    public void UpdateMetrics()
    {
        MetricsBar.Children.Clear();

        var data = _service.Data;
        var units = _service.Units;
        var first = true;
        var count = 0;

        foreach (var metric in _service.Metrics)
        {
            if (!_service.IsMetricEnabled(metric.Id)) continue;
            count++;

            if (!first)
            {
                MetricsBar.Children.Add(new TextBlock
                {
                    Text = " \u2502 ",
                    FontSize = 11,
                    Foreground = new SolidColorBrush(WpfColor.FromArgb(80, 255, 255, 255)),
                    VerticalAlignment = VerticalAlignment.Center
                });
            }
            first = false;

            // Icon
            MetricsBar.Children.Add(new TextBlock
            {
                Text = IconMapper.GetIcon(metric.Icon),
                FontSize = 11,
                Foreground = new SolidColorBrush(WpfColor.FromArgb(180, 255, 255, 255)),
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 0, 3, 0)
            });

            // Short label
            if (!string.IsNullOrEmpty(metric.ShortLabel))
            {
                MetricsBar.Children.Add(new TextBlock
                {
                    Text = metric.ShortLabel,
                    FontSize = 10,
                    FontFamily = UiFont,
                    Foreground = new SolidColorBrush(WpfColor.FromArgb(120, 255, 255, 255)),
                    VerticalAlignment = VerticalAlignment.Center,
                    Margin = new Thickness(0, 0, 3, 0)
                });
            }

            // Value
            var valText = data.FormattedValue(metric, units);
            MetricsBar.Children.Add(new TextBlock
            {
                Text = valText,
                FontSize = 12,
                FontFamily = UiBoldFont,
                Foreground = new SolidColorBrush(WpfColors.White),
                VerticalAlignment = VerticalAlignment.Center
            });
        }

        // Force layout update so SizeToContent recalculates width
        InvalidateMeasure();
        InvalidateArrange();
        UpdateLayout();
    }

    // --- Drag vs Click ---

    private double _startLeft, _startTop;

    private void Widget_MouseDown(object sender, MouseButtonEventArgs e)
    {
        _startLeft = Left;
        _startTop = Top;
        DragMove();

        // DragMove blocks until mouse up — check if we actually moved
        if (Math.Abs(Left - _startLeft) < 5 && Math.Abs(Top - _startTop) < 5)
        {
            // Didn't move — treat as click
            Left = _startLeft;
            Top = _startTop;
            WidgetClicked?.Invoke();
        }
        else
        {
            // Moved — clamp to work area and save
            ClampToWorkArea();
            SavePosition();
        }
    }

    private void ClampToWorkArea()
    {
        var wa = SystemParameters.WorkArea;
        if (Left < wa.Left) Left = wa.Left;
        if (Top < wa.Top) Top = wa.Top;
        if (Left + ActualWidth > wa.Right) Left = wa.Right - ActualWidth;
        if (Top + Height > wa.Bottom) Top = wa.Bottom - Height;
    }

    // --- Position persistence ---

    private static readonly string PosFile = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Orbital", "widget-pos.txt");

    private void SavePosition()
    {
        try
        {
            var dir = Path.GetDirectoryName(PosFile)!;
            Directory.CreateDirectory(dir);
            File.WriteAllText(PosFile, $"{Left},{Top}");
        }
        catch { /* ignore */ }
    }

    private void RestorePosition()
    {
        try
        {
            if (File.Exists(PosFile))
            {
                var parts = File.ReadAllText(PosFile).Split(',');
                if (parts.Length == 2 &&
                    double.TryParse(parts[0], out var x) &&
                    double.TryParse(parts[1], out var y))
                {
                    // Clamp to screen
                    var workArea = SystemParameters.WorkArea;
                    Left = Math.Clamp(x, workArea.Left, workArea.Right - 100);
                    Top = Math.Clamp(y, workArea.Top, workArea.Bottom - 34);
                    return;
                }
            }
        }
        catch { /* ignore */ }

        // Default: bottom-right, clearly above taskbar
        var wa = SystemParameters.WorkArea;
        UpdateLayout();
        var w = ActualWidth > 0 ? ActualWidth : 350;
        Left = wa.Right - w - 16;
        Top = wa.Bottom - Height - 16;
    }
}
