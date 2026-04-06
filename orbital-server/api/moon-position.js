const https = require("https");
const http = require("http");

/**
 * Moon position service using JPL Horizons API with analytical fallback.
 * Ported from Swift MoonPositionService.
 */
class MoonPositionService {
  constructor() {
    this.cached = null;
    this.lastFetch = null;
    this.refreshInterval = 3600 * 1000; // ms
    this.horizonsBaseURL = "https://ssd.jpl.nasa.gov/api/horizons.api";
  }

  configure(horizonsURL, refreshInterval) {
    if (horizonsURL) this.horizonsBaseURL = horizonsURL;
    if (refreshInterval) this.refreshInterval = refreshInterval * 1000;
  }

  /** Returns Moon's J2000 geocentric position { x, y, z } in km */
  async getPosition() {
    if (
      this.cached &&
      this.lastFetch &&
      Date.now() - this.lastFetch < this.refreshInterval
    ) {
      return this.cached;
    }

    const fresh = await this._fetchFromHorizons();
    if (fresh) {
      this.cached = fresh;
      this.lastFetch = Date.now();
      return fresh;
    }

    const fallback = this._approximateMoonPosition();
    this.cached = fallback;
    // Cache fallback for only 5 minutes so we retry Horizons soon
    this.lastFetch = Date.now() - this.refreshInterval + 300000;
    return fallback;
  }

  /** Compute distance from a J2000 position (km) to the Moon */
  async distanceToMoon(x, y, z) {
    const moon = await this.getPosition();
    const dx = x - moon.x;
    const dy = y - moon.y;
    const dz = z - moon.z;
    return Math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  async _fetchFromHorizons() {
    try {
      const now = new Date();
      const soon = new Date(now.getTime() + 60000); // +1 minute
      // Use ISO timestamps with T separator (Horizons rejects spaces in URL params)
      const fmt = (d) => d.toISOString().slice(0, 16);
      const start = fmt(now);
      const stop = fmt(soon);

      const params = new URLSearchParams({
        format: "json",
        COMMAND: "301",
        OBJ_DATA: "NO",
        MAKE_EPHEM: "YES",
        EPHEM_TYPE: "VECTORS",
        CENTER: "500@399",
        REF_PLANE: "FRAME",
        START_TIME: start,
        STOP_TIME: stop,
        STEP_SIZE: "1d",
        VEC_TABLE: "1",
      });

      const url = `${this.horizonsBaseURL}?${params.toString()}`;
      const data = await this._httpGet(url, 15000);
      const json = JSON.parse(data);

      if (!json.result) return null;
      return this._parseHorizonsResponse(json.result);
    } catch {
      return null;
    }
  }

  _parseHorizonsResponse(result) {
    const lines = result.split("\n");
    let inData = false;

    for (const line of lines) {
      if (line.includes("$$SOE")) {
        inData = true;
        continue;
      }
      if (line.includes("$$EOE")) break;
      if (inData && line.includes("X =")) {
        return this._parseVectorLine(line);
      }
    }
    return null;
  }

  _parseVectorLine(line) {
    // Extract values using regex to handle both "X = 1.23" and "X =1.23" formats
    const xm = line.match(/X\s*=\s*([^\s]+)/);
    const ym = line.match(/Y\s*=\s*([^\s]+)/);
    const zm = line.match(/Z\s*=\s*([^\s]+)/);
    let x = xm ? parseFloat(xm[1]) : null;
    let y = ym ? parseFloat(ym[1]) : null;
    let z = zm ? parseFloat(zm[1]) : null;

    if (x === null || y === null || z === null) return null;
    const dist = Math.sqrt(x * x + y * y + z * z);
    if (dist <= 300000) return null;

    return { x, y, z };
  }

  /** Simple approximate Moon position when Horizons is unavailable. */
  _approximateMoonPosition() {
    const now = Date.now();
    const j2000 = 946728000000; // 2000-01-01 12:00:00 TT in ms
    const daysSinceJ2000 = (now - j2000) / 86400000;

    const meanLongDeg = 218.316 + 13.176396 * daysSinceJ2000;
    const meanAnomDeg = 134.963 + 13.064993 * daysSinceJ2000;
    const meanDistKm = 385000;

    const longRad = (meanLongDeg * Math.PI) / 180;
    const anomRad = (meanAnomDeg * Math.PI) / 180;

    const r = meanDistKm + 20900 * Math.cos(anomRad);
    const eclLon = longRad + ((6.289 * Math.PI) / 180) * Math.sin(anomRad);

    const obliquity = (23.44 * Math.PI) / 180;
    const x = r * Math.cos(eclLon);
    const y = r * Math.sin(eclLon) * Math.cos(obliquity);
    const z = r * Math.sin(eclLon) * Math.sin(obliquity);

    return { x, y, z };
  }

  _httpGet(url, timeout) {
    return new Promise((resolve, reject) => {
      const client = url.startsWith("https") ? https : http;
      const req = client.get(url, { timeout }, (res) => {
        if (res.statusCode !== 200) {
          res.resume();
          return reject(new Error(`HTTP ${res.statusCode}`));
        }
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => resolve(data));
      });
      req.on("error", reject);
      req.on("timeout", () => {
        req.destroy();
        reject(new Error("timeout"));
      });
    });
  }
}

module.exports = MoonPositionService;
