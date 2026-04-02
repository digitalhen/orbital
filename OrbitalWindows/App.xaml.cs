using System.Windows;
using Orbital.Services;
using Orbital.Views;

namespace Orbital;

public partial class App : System.Windows.Application
{
    private TrayIconManager? _trayManager;
    private Mutex? _singleInstanceMutex;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Single-instance check
        _singleInstanceMutex = new Mutex(true, "Orbital-NASAMissionTracker", out var isNew);
        if (!isNew)
        {
            System.Windows.MessageBox.Show("Orbital is already running.", "Orbital", MessageBoxButton.OK, MessageBoxImage.Information);
            Shutdown();
            return;
        }

        // No main window — tray-only app
        var service = new MissionDataService();
        _trayManager = new TrayIconManager(service);

        Analytics.Shared.Track("app_launch");
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _trayManager?.Dispose();
        _singleInstanceMutex?.ReleaseMutex();
        _singleInstanceMutex?.Dispose();
        base.OnExit(e);
    }
}
