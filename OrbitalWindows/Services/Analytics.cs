namespace Orbital.Services;

public class Analytics
{
    public static readonly Analytics Shared = new();

    private const string MeasurementId = "G-GVZHZ4N315";
    private readonly string _clientId;
    private readonly HttpClient _http = new();

    private Analytics()
    {
        var settingsDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Orbital");
        Directory.CreateDirectory(settingsDir);
        var clientIdFile = Path.Combine(settingsDir, "client-id");

        try
        {
            if (File.Exists(clientIdFile))
                _clientId = File.ReadAllText(clientIdFile).Trim();
            else
            {
                _clientId = Guid.NewGuid().ToString();
                File.WriteAllText(clientIdFile, _clientId);
            }
        }
        catch
        {
            _clientId = Guid.NewGuid().ToString();
        }
    }

    public void Track(string eventName, Dictionary<string, string>? parameters = null)
    {
        // Analytics only active if API secret is configured
        // For now this is a no-op placeholder matching the macOS version's pattern
        // The secret would be baked in at build time via an environment variable or config
    }
}
