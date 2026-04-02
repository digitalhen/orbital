const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = process.env.PORT || 3847;
const CONFIG_PATH = path.join(__dirname, "missions", "active.json");

function loadConfig() {
  return JSON.parse(fs.readFileSync(CONFIG_PATH, "utf-8"));
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

  if ((url.pathname === "/space/api/v1/mission/active" || url.pathname === "/api/v1/mission/active") && req.method === "GET") {
    try {
      const config = loadConfig();
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify(config));
    } catch (err) {
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "Failed to load config" }));
    }
    return;
  }

  if ((url.pathname === "/space/api/v1/health" || url.pathname === "/api/v1/health") && req.method === "GET") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok" }));
    return;
  }

  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Not found" }));
});

server.listen(PORT, () => {
  console.log(`Mission Tracker API running on http://localhost:${PORT}`);
  console.log(`  GET /api/v1/mission/active`);
  console.log(`  GET /api/v1/health`);
  console.log(`  Config: ${CONFIG_PATH}`);
});
