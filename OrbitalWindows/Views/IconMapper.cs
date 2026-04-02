namespace Orbital.Views;

/// <summary>
/// Maps SF Symbols names (from macOS config) to Unicode/Segoe MDL2 characters for Windows.
/// </summary>
public static class IconMapper
{
    // Map SF Symbols to Segoe Fluent Icons / Segoe MDL2 Assets codepoints
    // or fallback to Unicode emoji when no glyph is available
    private static readonly Dictionary<string, string> Map = new()
    {
        ["moon.stars"] = "\U0001F319",        // crescent moon emoji
        ["clock"] = "\u23F0",                  // alarm clock
        ["globe.americas"] = "\U0001F30E",    // globe emoji
        ["moon"] = "\U0001F311",              // new moon
        ["speedometer"] = "\u26A1",            // lightning bolt (speed)
        ["flame"] = "\U0001F525",             // fire
        ["arrow.up.right.circle"] = "\u2197",  // arrow
        ["arrow.right"] = "\u27A1",            // right arrow
        ["moon.circle"] = "\U0001F315",       // full moon
        ["arrow.left"] = "\u2B05",             // left arrow
        ["flame.circle"] = "\U0001F525",      // fire
        ["water.waves"] = "\U0001F30A",       // wave
        ["checkmark.circle"] = "\u2705",       // check mark
        ["person.fill"] = "\U0001F464",       // person silhouette
        ["questionmark.circle"] = "\u2753",    // question mark
    };

    public static string GetIcon(string sfSymbolName)
    {
        return Map.TryGetValue(sfSymbolName, out var icon) ? icon : "\u2022"; // bullet fallback
    }
}
