# Orbital — NASA Mission Tracker

## Project Structure

- `Artemis2MenuBar/` — macOS menu bar app (Swift/SwiftUI, Xcode project)
- `server/` — Config API backend (Node.js, Docker)
- `icon.svg` — App icon source

## Architecture

The app is fully config-driven. All mission data, metrics, phases, telemetry sources, and crew info come from a remote JSON config API. The bundled `default-config.json` is the offline fallback.

### Config flow
1. App launches → loads disk cache or bundled default
2. Fetches from `https://api.cleartextlabs.com/space/api/v1/mission/active`
3. Refreshes periodically (interval defined in config)
4. Config updates propagate to all components via Combine

### Live telemetry
- Position from NASA AROW GCS bucket (configurable URL + parameter IDs)
- Position is in feet (JSC convention), converted to km
- Speed computed from successive position samples using GCS telemetry timestamps
- Moon distance computed using JPL Horizons Moon position
- All data source URLs, parameter IDs, and units are in the config

### Metrics are fully dynamic
- Defined in the `metrics` array in the config JSON
- Each metric has: id, label, shortLabel, icon (SF Symbol), format type, data source
- User toggle state is keyed by metric ID (survives renames)
- The app computes built-in sources: met, altitude, moonDistance, speed, phase
- New metrics can be added via config without app updates

## Build

```bash
xcodebuild -project Artemis2MenuBar.xcodeproj -scheme Artemis2MenuBar -configuration Release build
```

## Server

```bash
cd server && docker compose up -d --build
```

Edit `server/missions/active.json` to update all clients. The server reads from disk on every request.

## DMG

```bash
# After building Release:
rm -rf dmg_staging && mkdir dmg_staging
cp -R ~/Library/Developer/Xcode/DerivedData/Artemis2MenuBar-*/Build/Products/Release/Orbital.app dmg_staging/
ln -s /Applications dmg_staging/Applications
hdiutil create -volname "Orbital" -srcfolder dmg_staging -ov -format UDZO Orbital-1.0.dmg
```

## Key files

- `MissionConfig.swift` / `MissionConfigService.swift` — config model + remote fetch/cache
- `MissionDataService.swift` — orchestrator, merges simulation + live AROW data
- `AROWFetcher.swift` — fetches from NASA GCS bucket, computes altitude/speed/moon distance
- `TrajectorySimulator.swift` — simulation fallback from config waypoints
- `MoonPosition.swift` — Moon position from JPL Horizons with analytical fallback
- `StatusBarController.swift` — multiple NSStatusItems, one per enabled metric
- `MenuBarDetailView.swift` — popover UI, all sections driven by config/metrics
- `MetricType.swift` — Metric and MetricValue types (dynamic, not an enum)
- `server/missions/active.json` — the live config served to all clients
