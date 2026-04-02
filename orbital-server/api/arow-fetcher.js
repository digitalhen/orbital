const https = require("https");
const http = require("http");

/**
 * Fetches and computes telemetry from NASA AROW GCS bucket.
 * Ported from Swift AROWFetcher.
 */
class AROWFetcher {
  constructor(config) {
    this.configure(config);
    this.prevPosition = null;
    this.prevTimestamp = "";
    this.lastComputedSpeed = 0;
  }

  configure(config) {
    const tel = config.dataSources.telemetry;
    this.telemetryBaseURL = tel.url;
    this.positionParams = tel.positionParams;
    this.activityField = tel.activityField;
    this.earthRadius = config.trajectory?.earthRadius ?? 6371.0;
    this.mu = config.trajectory?.mu ?? 398600.4418;
    this.positionUnitToKm = AROWFetcher.unitConversion(tel.positionUnit);
  }

  static unitConversion(unit) {
    switch (unit) {
      case "feet":
        return 0.0003048;
      case "meters":
        return 0.001;
      case "km":
      case "kilometers":
        return 1.0;
      default:
        return 0.0003048;
    }
  }

  async fetch() {
    const separator = this.telemetryBaseURL.includes("?") ? "&" : "?";
    const cacheBust = Math.floor(Date.now() / 1000);
    const url = `${this.telemetryBaseURL}${separator}_=${cacheBust}`;

    try {
      const data = await this._httpGet(url, 15000);
      const json = JSON.parse(data);
      return this._parseTelemetry(json);
    } catch {
      return null;
    }
  }

  _parseTelemetry(json) {
    const result = {
      distanceFromEarthCenter: 0,
      distanceFromMoon: 0,
      speed: 0,
      isLive: false,
    };

    if (json.File && json.File.Activity) {
      result.isLive = json.File.Activity === this.activityField;
    }

    if (this.positionParams.length < 3) return null;

    const rawX = this._extractParam(json, this.positionParams[0]);
    const rawY = this._extractParam(json, this.positionParams[1]);
    const rawZ = this._extractParam(json, this.positionParams[2]);

    if (rawX === 0 && rawY === 0 && rawZ === 0) return null;

    const posX = rawX * this.positionUnitToKm;
    const posY = rawY * this.positionUnitToKm;
    const posZ = rawZ * this.positionUnitToKm;

    const distFromCenter = Math.sqrt(
      posX * posX + posY * posY + posZ * posZ
    );
    if (distFromCenter <= this.earthRadius) return null;

    result.distanceFromEarthCenter = distFromCenter;
    result.position = { x: posX, y: posY, z: posZ };

    // Speed from successive position samples
    const timestamp = this._extractTimestamp(json, this.positionParams[0]);
    if (this.prevPosition && this.prevTimestamp && timestamp !== this.prevTimestamp) {
      const dt = this._telemetryTimeDelta(this.prevTimestamp, timestamp);
      if (dt > 1 && dt < 600) {
        const dx = posX - this.prevPosition.x;
        const dy = posY - this.prevPosition.y;
        const dz = posZ - this.prevPosition.z;
        const posDelta = Math.sqrt(dx * dx + dy * dy + dz * dz);
        if (posDelta > 0.001) {
          this.lastComputedSpeed = posDelta / dt;
        }
      }
    }

    result.speed = this.lastComputedSpeed;
    this.prevPosition = { x: posX, y: posY, z: posZ };
    this.prevTimestamp = timestamp;

    return result;
  }

  _extractParam(json, number) {
    const key = `Parameter_${number}`;
    const param = json[key];
    if (!param || param.Status !== "Good") return 0;
    const value = parseFloat(param.Value);
    return isNaN(value) ? 0 : value;
  }

  _extractTimestamp(json, number) {
    const key = `Parameter_${number}`;
    const param = json[key];
    return param?.Time || "";
  }

  _telemetryTimeDelta(t1, t2) {
    function toSeconds(t) {
      const parts = t.split(":");
      if (parts.length < 5) return null;
      const year = parseFloat(parts[0]);
      const day = parseFloat(parts[1]);
      const hour = parseFloat(parts[2]);
      const min = parseFloat(parts[3]);
      const sec = parseFloat(parts[4]);
      if ([year, day, hour, min, sec].some(isNaN)) return null;
      return year * 366 * 86400 + day * 86400 + hour * 3600 + min * 60 + sec;
    }
    const s1 = toSeconds(t1);
    const s2 = toSeconds(t2);
    if (s1 === null || s2 === null) return 0;
    return s2 - s1;
  }

  _httpGet(url, timeout) {
    return new Promise((resolve, reject) => {
      const client = url.startsWith("https") ? https : http;
      const req = client.get(url, { timeout, headers: { "Cache-Control": "no-cache", "Pragma": "no-cache" } }, (res) => {
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

module.exports = AROWFetcher;
