const http = require("http");
const https = require("https");
const fs = require("fs");
const path = require("path");

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
      // Track config fetch with client identifier from user-agent
      const clientId = ua.includes("Orbital/")
        ? ua.replace(/[^a-zA-Z0-9._-]/g, "").slice(0, 64)
        : "api-client";
      trackEvent("config_fetch", { source: "api", user_agent: ua.slice(0, 100) }, clientId);
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify(config));
    } catch (err) {
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Failed to load config" }));
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
});
