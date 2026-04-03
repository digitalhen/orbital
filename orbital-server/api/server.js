const http = require("http");
const https = require("https");
const fs = require("fs");
const path = require("path");
const AROWFetcher = require("./arow-fetcher");
const MoonPositionService = require("./moon-position");

const PORT = process.env.PORT || 3847;
const CONFIG_PATH = path.join(__dirname, "missions", "active.json");

// GA4 Measurement Protocol
const GA_MEASUREMENT_ID = "G-GVZHZ4N315";
const GA_API_SECRET = process.env.GA_API_SECRET || "";

function loadConfig() {
  return JSON.parse(fs.readFileSync(CONFIG_PATH, "utf-8"));
}

function trackEvent(eventName, params = {}, clientId) {
  if (!GA_API_SECRET) return;

  const payload = JSON.stringify({
    client_id: clientId || "server",
    events: [{ name: eventName, params }],
  });

  const req = https.request({
    hostname: "www.google-analytics.com",
    path: `/mp/collect?measurement_id=${GA_MEASUREMENT_ID}&api_secret=${GA_API_SECRET}`,
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
  req.on("error", () => {});
  req.write(payload);
  req.end();
}

// --- Proxy helper ---
function proxyGet(fetchURL, res) {
  const client = fetchURL.startsWith("https") ? https : http;
  client
    .get(fetchURL, { timeout: 15000 }, (upstream) => {
      res.writeHead(upstream.statusCode, {
        "Content-Type": upstream.headers["content-type"] || "application/octet-stream",
        "Cache-Control": "no-cache, no-store",
      });
      upstream.pipe(res);
    })
    .on("error", () => {
      res.writeHead(502, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Upstream request failed" }));
    });
}

// --- Phase derivation from live telemetry ---
let prevPollData = null;

function waypointPhase(met, config) {
  const waypoints = config.trajectory?.waypoints;
  if (!waypoints || waypoints.length === 0) return null;

  // Before first waypoint
  if (met <= waypoints[0].met) return waypoints[0].phase;

  // After last waypoint
  if (met >= waypoints[waypoints.length - 1].met)
    return waypoints[waypoints.length - 1].phase;

  // Between waypoints — use the phase of the waypoint we've passed
  for (let i = waypoints.length - 2; i >= 0; i--) {
    if (met >= waypoints[i].met) return waypoints[i].phase;
  }

  return null;
}

function derivePhase(met, altitude, distanceToMoon, speed, missionDuration, config) {
  const moonApproaching =
    prevPollData &&
    distanceToMoon > 0 &&
    prevPollData.distanceToMoon > 0
      ? distanceToMoon < prevPollData.distanceToMoon
      : null;

  if (met < 0) return "prelaunch";
  if (met < 600) return "ascent";
  if (met >= missionDuration) return "missionComplete";

  // Splashdown — near surface, slow, late in mission
  if (altitude < 50 && speed < 0.5 && met > missionDuration * 0.9)
    return "splashdown";

  // Reentry — low altitude, high speed, late in mission
  if (altitude < 200 && speed > 3 && met > missionDuration * 0.8)
    return "reentry";

  // Lunar flyby — very close to Moon
  if (distanceToMoon > 0 && distanceToMoon < 10000) return "lunarFlyby";

  // Lunar approach — closing on Moon within 50k km
  if (distanceToMoon > 0 && distanceToMoon < 50000 && moonApproaching === true)
    return "lunarApproach";

  // Return coast — receding from Moon, past mid-mission
  if (moonApproaching === false && met > missionDuration * 0.4)
    return "returnCoast";

  // Outbound coast — heading toward Moon, well above low Earth orbit
  if (moonApproaching === true && altitude > 2000) return "outboundCoast";

  // TLI — high speed near Earth (brief burn, may not always be caught)
  if (speed > 10 && altitude < 2000 && altitude > 160)
    return "translunarInjection";

  // Fall back to config waypoint phase instead of guessing
  return waypointPhase(met, config) || "earthOrbit";
}

// --- Telemetry polling ---
let arowFetcher = null;
let moonService = null;
let latestTelemetry = null;
let telemetryPollTimer = null;

function getUpstreamConfig(config) {
  // Server uses _upstreamSources for the real NASA/JPL URLs,
  // while dataSources contains client-facing proxy URLs
  const upstream = config._upstreamSources || {};
  return {
    ...config,
    dataSources: {
      ...config.dataSources,
      telemetry: {
        ...config.dataSources.telemetry,
        url: upstream.telemetry || config.dataSources.telemetry.url,
      },
      moonPosition: config.dataSources.moonPosition
        ? {
            ...config.dataSources.moonPosition,
            horizonsURL: upstream.horizons || config.dataSources.moonPosition.horizonsURL,
          }
        : undefined,
    },
  };
}

function initTelemetry() {
  try {
    const config = loadConfig();
    const upstreamConfig = getUpstreamConfig(config);

    if (!upstreamConfig.dataSources?.telemetry?.url) {
      console.log("  Telemetry: no telemetry URL configured, polling disabled");
      return;
    }

    arowFetcher = new AROWFetcher(upstreamConfig);
    moonService = new MoonPositionService();

    if (upstreamConfig.dataSources.moonPosition) {
      moonService.configure(
        upstreamConfig.dataSources.moonPosition.horizonsURL,
        upstreamConfig.dataSources.moonPosition.refreshInterval
      );
    }

    const pollInterval = (config.dataSources.telemetry.pollInterval || 30) * 1000;
    console.log(`  Telemetry: polling every ${pollInterval / 1000}s`);

    // Initial fetch
    pollTelemetry();
    telemetryPollTimer = setInterval(pollTelemetry, pollInterval);
  } catch (err) {
    console.error("  Telemetry: failed to initialize:", err.message);
  }
}

async function pollTelemetry() {
  if (!arowFetcher) return;

  try {
    // Re-read config each poll so telemetry URL changes take effect
    const config = loadConfig();
    const upstreamConfig = getUpstreamConfig(config);
    arowFetcher.configure(upstreamConfig);

    const arow = await arowFetcher.fetch();
    if (!arow) return;

    const earthRadius = config.trajectory?.earthRadius ?? 6371.0;
    const altitude = arow.distanceFromEarthCenter - earthRadius;

    // Moon distance + position
    let distanceToMoon = 0;
    let moonPosition = null;
    if (arow.position && moonService) {
      distanceToMoon = await moonService.distanceToMoon(
        arow.position.x,
        arow.position.y,
        arow.position.z
      );
      const moonPos = await moonService.getPosition();
      moonPosition = {
        x: Math.round(moonPos.x * 100) / 100,
        y: Math.round(moonPos.y * 100) / 100,
        z: Math.round(moonPos.z * 100) / 100,
      };
    }

    // Derive phase from live telemetry
    let phase = null;
    if (config.mission?.launchDate) {
      const launchTime = new Date(config.mission.launchDate).getTime();
      const met = (Date.now() - launchTime) / 1000;
      const missionDuration = config.mission.missionDuration || 788400;
      phase = derivePhase(met, altitude, distanceToMoon, arow.speed, missionDuration, config);
    }

    prevPollData = { distanceToMoon, altitude, speed: arow.speed };

    latestTelemetry = {
      timestamp: new Date().toISOString(),
      altitude: Math.round(altitude * 100) / 100,
      speed: Math.round(arow.speed * 1000) / 1000,
      distanceFromEarthCenter: Math.round(arow.distanceFromEarthCenter * 100) / 100,
      distanceToMoon: Math.round(distanceToMoon * 100) / 100,
      moonPosition,
      spacecraftPosition: arow.position
        ? {
            x: Math.round(arow.position.x * 100) / 100,
            y: Math.round(arow.position.y * 100) / 100,
            z: Math.round(arow.position.z * 100) / 100,
          }
        : null,
      isLive: arow.isLive,
      phase,
    };
  } catch (err) {
    // Silently continue — telemetry is best-effort
  }
}

const server = http.createServer((req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);
  const ua = req.headers["user-agent"] || "";

  if (
    (url.pathname === "/space/api/v1/mission/active" ||
      url.pathname === "/api/v1/mission/active") &&
    req.method === "GET"
  ) {
    try {
      const config = loadConfig();
      // Strip internal upstream sources from client response
      const { _upstreamSources, ...clientConfig } = config;
      // Track config fetch with client identifier from user-agent
      const clientId = ua.includes("Orbital/")
        ? ua.replace(/[^a-zA-Z0-9._-]/g, "").slice(0, 64)
        : "api-client";
      trackEvent("config_fetch", { source: "api", user_agent: ua.slice(0, 100) }, clientId);
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify(clientConfig));
    } catch (err) {
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Failed to load config" }));
    }
    return;
  }

  if (
    (url.pathname === "/space/api/v1/mission/telemetry" ||
      url.pathname === "/api/v1/mission/telemetry") &&
    req.method === "GET"
  ) {
    if (latestTelemetry) {
      const clientId = ua.includes("Orbital/")
        ? ua.replace(/[^a-zA-Z0-9._-]/g, "").slice(0, 64)
        : "api-client";
      trackEvent("telemetry_fetch", { source: "api", user_agent: ua.slice(0, 100) }, clientId);
      res.writeHead(200, {
        "Content-Type": "application/json",
        "Cache-Control": "no-cache, no-store",
      });
      res.end(JSON.stringify(latestTelemetry));
    } else {
      res.writeHead(503, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Telemetry not yet available" }));
    }
    return;
  }

  // --- Proxy endpoints: forward raw data from upstream NASA/JPL sources ---
  if (
    (url.pathname === "/space/api/v1/proxy/telemetry" ||
      url.pathname === "/api/v1/proxy/telemetry") &&
    req.method === "GET"
  ) {
    try {
      const config = loadConfig();
      const upstreamURL = config._upstreamSources?.telemetry;
      if (!upstreamURL) {
        res.writeHead(503, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "No upstream telemetry source configured" }));
        return;
      }
      const separator = upstreamURL.includes("?") ? "&" : "?";
      const cacheBust = Math.floor(Date.now() / 1000);
      const fetchURL = `${upstreamURL}${separator}_=${cacheBust}`;
      proxyGet(fetchURL, res);
    } catch (err) {
      res.writeHead(502, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Proxy error" }));
    }
    return;
  }

  if (
    (url.pathname === "/space/api/v1/proxy/horizons" ||
      url.pathname === "/api/v1/proxy/horizons") &&
    req.method === "GET"
  ) {
    try {
      const config = loadConfig();
      const baseURL = config._upstreamSources?.horizons;
      if (!baseURL) {
        res.writeHead(503, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "No upstream horizons source configured" }));
        return;
      }
      // Forward query string from client to upstream
      const qs = url.search || "";
      const fetchURL = `${baseURL}${qs}`;
      proxyGet(fetchURL, res);
    } catch (err) {
      res.writeHead(502, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Proxy error" }));
    }
    return;
  }

  if (
    (url.pathname === "/space/api/v1/health" ||
      url.pathname === "/api/v1/health") &&
    req.method === "GET"
  ) {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok" }));
    return;
  }

  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Not found" }));
});

server.listen(PORT, () => {
  console.log(`Mission Tracker API running on http://localhost:${PORT}`);
  console.log(`  GA4: ${GA_API_SECRET ? "enabled" : "disabled (set GA_API_SECRET)"}`);
  initTelemetry();
});
