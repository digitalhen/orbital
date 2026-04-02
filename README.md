# Orbital

A macOS menu bar app for tracking NASA missions in real-time. Currently tracking **Artemis II** — the first crewed lunar mission since 1972.

## Features

- **Real-time telemetry** from NASA's AROW (Artemis Real-time Orbit Website)
- **Multiple menu bar items** — show altitude, speed, elapsed time, moon distance, mission phase
- **Toggle metrics** — choose which values appear in your menu bar
- **Unit selector** — metric (km) or imperial (miles)
- **Launch at login**
- **Fully config-driven** — mission data, metrics, crew, and telemetry sources are served from a remote API. No app update needed to change missions or add new data.

## Install

Download the latest DMG from [Releases], open it, and drag Orbital to Applications.

## How It Works

Orbital pulls live spacecraft position data from NASA's public telemetry feed (the same data source that powers the official AROW tracker). It computes altitude, velocity, and distance to the Moon from the position vectors, and displays them in your menu bar.

Mission configuration (crew, phases, data sources, available metrics) is fetched from a central API, so the app can be updated for new missions without requiring a new build.

## Config API

The backend is a lightweight Node.js server that serves mission configuration as JSON.

```bash
cd server
docker compose up -d --build
```

Edit `server/missions/active.json` to update all connected clients.

### Endpoints

- `GET /space/api/v1/mission/active` — current mission config
- `GET /space/api/v1/health` — health check

## Build from Source

Requires Xcode 15+ and macOS 13+.

```bash
xcodebuild -project Artemis2MenuBar.xcodeproj -scheme Artemis2MenuBar -configuration Release build
```

## License

MIT
