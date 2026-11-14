#!/usr/bin/env python3
"""Query several no-login agricultural datasets for one point and normalize
everything into a single long-format schema:

    source | variable | value | unit | date | lat | lon

Usage:  python3 farm_data.py LAT LON [START YYYYMMDD] [END YYYYMMDD]
Writes farm_data_<lat>_<lon>.csv and .json next to this script.
Stdlib only (no pip installs).
"""
import csv, json, math, os, re, sys, time, urllib.parse, urllib.request
from datetime import date, timedelta

UA = {"User-Agent": "farm-data-demo/0.1"}


def get(url, data=None, timeout=60, retries=3):
    req = urllib.request.Request(url, data=data, headers={**UA, **({"Content-Type": "application/json"} if data else {})})
    for i in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read().decode()
        except Exception:
            if i == retries - 1:
                raise
            time.sleep(2 * (i + 1))


def rec(source, variable, value, unit, when, lat, lon):
    return {"source": source, "variable": variable, "value": value, "unit": unit,
            "date": when, "lat": lat, "lon": lon}


# ---------- NASA POWER (daily agroclimatology) ----------
POWER_VARS = {  # POWER code -> (normalized name, unit)
    "T2M": ("air_temp_mean", "degC"),
    "T2M_MAX": ("air_temp_max", "degC"),
    "T2M_MIN": ("air_temp_min", "degC"),
    "PRECTOTCORR": ("precipitation", "mm/day"),
    "RH2M": ("relative_humidity", "%"),
    "ALLSKY_SFC_SW_DWN": ("solar_radiation", "MJ/m2/day"),
    "GWETROOT": ("root_zone_soil_wetness", "fraction 0-1"),
}


def nasa_power(lat, lon, start, end):
    q = urllib.parse.urlencode({
        "parameters": ",".join(POWER_VARS), "community": "AG",
        "latitude": lat, "longitude": lon, "start": start, "end": end, "format": "JSON"})
    js = json.loads(get("https://power.larc.nasa.gov/api/temporal/daily/point?" + q))
    out = []
    for code, series in js["properties"]["parameter"].items():
        name, unit = POWER_VARS[code]
        for d, v in series.items():
            if v == -999:  # POWER fill value
                continue
            out.append(rec("NASA POWER", name, v, unit, f"{d[:4]}-{d[4:6]}-{d[6:]}", lat, lon))
    return out


# ---------- USGS 3DEP elevation (EPQS) ----------
def epqs(lat, lon, tries=4):
    """EPQS sometimes answers 200 with an empty body; retry those too."""
    for i in range(tries):
        try:
            return float(json.loads(get(f"https://epqs.nationalmap.gov/v1/json?x={lon}&y={lat}&units=Meters&wkid=4326"))["value"])
        except (ValueError, KeyError):
            if i == tries - 1:
                raise
            time.sleep(2 * (i + 1))


def usgs_elevation(lat, lon):
    return [rec("USGS 3DEP", "elevation", epqs(lat, lon), "m", None, lat, lon)]


def slope_from_elevation(lat, lon, d=30.0):
    """Approximate slope (%) from 4 neighbouring 3DEP samples ~d metres away."""
    dlat = d / 111_320
    dlon = d / (111_320 * math.cos(math.radians(lat)))
    e = epqs
    dzdx = (e(lat, lon + dlon) - e(lat, lon - dlon)) / (2 * d)
    dzdy = (e(lat + dlat, lon) - e(lat - dlat, lon)) / (2 * d)
    return [rec("USGS 3DEP (derived)", "slope", round(100 * math.hypot(dzdx, dzdy), 2), "%", None, lat, lon)]


# ---------- USDA NRCS SSURGO via Soil Data Access ----------
def ssurgo(lat, lon):
    sql = f"""
    SELECT mu.muname, c.compname, c.comppct_r, c.hydgrp, c.drainagecl,
           c.slope_r, h.om_r, h.sandtotal_r, h.claytotal_r, h.awc_r
    FROM SDA_Get_Mukey_from_intersection_with_WktWgs84('point({lon} {lat})') k
    JOIN mapunit mu ON mu.mukey = k.mukey
    JOIN component c ON c.mukey = mu.mukey AND c.majcompflag = 'Yes'
    LEFT JOIN chorizon h ON h.cokey = c.cokey AND h.hzdept_r = 0
    ORDER BY c.comppct_r DESC"""
    body = json.dumps({"query": sql, "format": "JSON+COLUMNNAME"}).encode()
    js = json.loads(get("https://sdmdataaccess.sc.egov.usda.gov/Tabular/post.rest", data=body))
    rows = js.get("Table", [])
    if len(rows) < 2:
        return []
    cols, top = rows[0], dict(zip(rows[0], rows[1]))  # dominant major component
    units = {"comppct_r": "%", "slope_r": "%", "om_r": "% organic matter (topsoil)",
             "sandtotal_r": "% sand (topsoil)", "claytotal_r": "% clay (topsoil)",
             "awc_r": "cm/cm available water capacity"}
    names = {"muname": "soil_map_unit", "compname": "soil_component", "comppct_r": "component_share",
             "hydgrp": "hydrologic_soil_group", "drainagecl": "drainage_class", "slope_r": "mapped_slope",
             "om_r": "organic_matter", "sandtotal_r": "sand", "claytotal_r": "clay",
             "awc_r": "available_water_capacity"}
    out = []
    for c in cols:
        v = top[c]
        if v in (None, ""):
            continue
        try:
            v = float(v)
        except ValueError:
            pass
        out.append(rec("USDA SSURGO", names[c], v, units.get(c, "class"), None, lat, lon))
    return out


# ---------- USDA NASS Cropland Data Layer (CropScape) ----------
def to_albers_5070(lat, lon):
    """WGS84/NAD83 lat/lon -> CONUS Albers Equal Area (EPSG:5070), GRS80 ellipsoid."""
    a, f = 6378137.0, 1 / 298.257222101
    e2 = f * (2 - f); e = math.sqrt(e2)
    p1, p2, p0, l0 = map(math.radians, (29.5, 45.5, 23.0, -96.0))
    m = lambda p: math.cos(p) / math.sqrt(1 - e2 * math.sin(p) ** 2)
    q = lambda p: (1 - e2) * (math.sin(p) / (1 - e2 * math.sin(p) ** 2)
                              - (1 / (2 * e)) * math.log((1 - e * math.sin(p)) / (1 + e * math.sin(p))))
    m1, m2, q0, q1, q2 = m(p1), m(p2), q(p0), q(p1), q(p2)
    n = (m1 ** 2 - m2 ** 2) / (q2 - q1)
    C = m1 ** 2 + n * q1
    rho = lambda qq: a * math.sqrt(C - n * qq) / n
    th = n * (math.radians(lon) - l0)
    r = rho(q(math.radians(lat)))
    return r * math.sin(th), rho(q0) - r * math.cos(th)


def cropland_history(lat, lon, years):
    x, y = to_albers_5070(lat, lon)
    out = []
    for yr in years:
        try:
            txt = get(f"https://nassgeodata.gmu.edu/axis2/services/CDLService/GetCDLValue?year={yr}&x={x:.1f}&y={y:.1f}")
        except Exception as ex:
            print(f"  CDL {yr}: {ex}", file=sys.stderr)
            continue
        m = re.search(r'category:\s*"?([^",}]+)', txt)
        if m:
            out.append(rec("USDA CDL", "crop_type", m.group(1).strip(), "class", f"{yr}", lat, lon))
    return out


# ---------- USGS NWIS: nearest active streamflow gauge ----------
def nwis_streamflow(lat, lon, box=0.25):
    bbox = f"{lon-box:.4f},{lat-box:.4f},{lon+box:.4f},{lat+box:.4f}"
    js = json.loads(get(f"https://waterservices.usgs.gov/nwis/iv/?format=json&bBox={bbox}"
                        f"&parameterCd=00060&siteStatus=active"))
    best = None
    for ts in js["value"]["timeSeries"]:
        g = ts["sourceInfo"]["geoLocation"]["geogLocation"]
        dist = math.hypot(g["latitude"] - lat, (g["longitude"] - lon) * math.cos(math.radians(lat))) * 111.32
        vals = ts["values"][0]["value"]
        if vals and (best is None or dist < best[0]):
            best = (dist, ts["sourceInfo"]["siteName"], vals[-1])
    if not best:
        return []
    dist, site, v = best
    cfs = float(v["value"])
    return [rec("USGS NWIS", "streamflow_nearest_gauge", round(cfs * 0.0283168, 3), "m3/s", v["dateTime"][:10], lat, lon),
            rec("USGS NWIS", "nearest_gauge", f"{site} ({dist:.1f} km)", "label", None, lat, lon)]


# ---------- summary features (what a rotation model would actually consume) ----------
def summarize(records):
    by = {}
    for r in records:
        if r["source"] == "NASA POWER":
            by.setdefault(r["variable"], []).append(r["value"])
    s = {}
    if "precipitation" in by: s["precip_total_mm"] = round(sum(by["precipitation"]), 1)
    if "air_temp_mean" in by:
        s["temp_mean_c"] = round(sum(by["air_temp_mean"]) / len(by["air_temp_mean"]), 2)
        s["growing_degree_days_base10"] = round(sum(max(0, t - 10) for t in by["air_temp_mean"]), 0)
    if "air_temp_min" in by: s["frost_days"] = sum(t <= 0 for t in by["air_temp_min"])
    if "air_temp_max" in by: s["heat_stress_days_gt32c"] = sum(t > 32 for t in by["air_temp_max"])
    if "root_zone_soil_wetness" in by:
        w = by["root_zone_soil_wetness"]
        s["root_zone_wetness_mean"] = round(sum(w) / len(w), 3)
    return s


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    lat, lon = float(args[0]), float(args[1])
    end = args[3] if len(args) > 3 else (date.today() - timedelta(days=10)).strftime("%Y%m%d")
    start = args[2] if len(args) > 2 else f"{int(end[:4]) - 1}{end[4:]}"
    this_year = date.today().year

    jobs = [
        ("NASA POWER", lambda: nasa_power(lat, lon, start, end)),
        ("USGS elevation", lambda: usgs_elevation(lat, lon)),
        ("USGS slope", lambda: slope_from_elevation(lat, lon)),
        ("SSURGO soils", lambda: ssurgo(lat, lon)),
        ("Cropland Data Layer", lambda: cropland_history(lat, lon, range(this_year - 6, this_year))),
        ("USGS NWIS", lambda: nwis_streamflow(lat, lon)),
    ]
    records = []
    for name, fn in jobs:
        try:
            got = fn()
            print(f"OK   {name:20s} {len(got):5d} records", file=sys.stderr)
            records += got
        except Exception as ex:
            print(f"FAIL {name:20s} {type(ex).__name__}: {ex}", file=sys.stderr)

    # ---- sources that need an account (skipped cleanly when credentials are absent)
    if "--open-only" not in sys.argv:
        import login_sources as ls
        ctx = {"records": records}
        try:
            ctx["county"] = ls.county_of(lat, lon)
        except Exception:
            pass
        for name, fn in ls.SOURCES:
            try:
                got = fn(lat, lon, start, end, ctx)
                print(f"OK   {name:20s} {len(got):5d} records", file=sys.stderr)
                records += got
            except ls.MissingCredentials as ex:
                print(f"SKIP {name:20s} {ex}", file=sys.stderr)
            except Exception as ex:
                print(f"FAIL {name:20s} {type(ex).__name__}: {ex}", file=sys.stderr)

    base = os.path.join(os.path.dirname(os.path.abspath(__file__)), f"farm_data_{lat}_{lon}")
    with open(base + ".csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(records[0])); w.writeheader(); w.writerows(records)
    summary = summarize(records)
    static = {r["variable"]: r["value"] for r in records if r["date"] is None}
    static.update({f"crop_{r['date']}": r["value"] for r in records if r["source"] == "USDA CDL"})
    # one comparable line per (source, variable) time series, e.g. IMERG vs POWER vs ERA5 rainfall
    series = {}
    for r in records:
        if r["date"] and isinstance(r["value"], (int, float)) and r["source"] not in ("USDA CDL",):
            series.setdefault(f"{r['source']} | {r['variable']} ({r['unit']})", []).append(r["value"])
    by_series = {k: {"n": len(v), "mean": round(sum(v) / len(v), 4), "min": min(v), "max": max(v),
                     **({"total": round(sum(v), 1)} if "/day" in k or "/month" in k else {})}
                 for k, v in sorted(series.items())}
    out = {"location": {"lat": lat, "lon": lon}, "period": [start, end],
           "climate_summary": summary, "site_attributes": static, "time_series_summary": by_series}
    with open(base + ".json", "w") as fh:
        json.dump(out, fh, indent=2)
    print(json.dumps(out, indent=2))
    print(f"\nWrote {len(records)} normalized rows -> {base}.csv / .json", file=sys.stderr)


if __name__ == "__main__":
    main()
