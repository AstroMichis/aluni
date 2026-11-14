"""Data sources that need a (free) account. Every function returns rows in the
same normalized shape as farm_data.py:  source | variable | value | unit | date | lat | lon

Credentials are read only from environment variables or the standard config
files (~/.netrc, ~/.cdsapirc). Nothing is hard-coded. If a source's credentials
are missing it raises MissingCredentials and the run continues without it.
See SETUP.md for how to get each one.
"""
import base64, csv, http.cookiejar, io, json, math, netrc, os, re, time, zipfile
import urllib.error, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta

UA = "farm-data-demo/0.1"


class MissingCredentials(Exception):
    pass


def rec(source, variable, value, unit, when, lat, lon):
    return {"source": source, "variable": variable, "value": value, "unit": unit,
            "date": when, "lat": lat, "lon": lon}


def ymd(s):  # "20250101" -> date
    return datetime.strptime(s, "%Y%m%d").date()


def http(url, data=None, headers=None, opener=None, timeout=120, method=None):
    h = {"User-Agent": UA, **(headers or {})}
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    with (opener or urllib.request.build_opener()).open(req, timeout=timeout) as r:
        return r.read()


# ====================================================================== Earthdata
def earthdata_creds():
    u, p = os.environ.get("EARTHDATA_USERNAME"), os.environ.get("EARTHDATA_PASSWORD")
    if u and p:
        return u, p
    try:
        auth = netrc.netrc().authenticators("urs.earthdata.nasa.gov")
        if auth:
            return auth[0], auth[2]
    except (FileNotFoundError, netrc.NetrcParseError):
        pass
    raise MissingCredentials("set EARTHDATA_USERNAME/EARTHDATA_PASSWORD or add urs.earthdata.nasa.gov to ~/.netrc")


def earthdata_opener():
    """urllib opener that follows the Earthdata Login redirect dance (basic auth + cookies)."""
    u, p = earthdata_creds()
    pm = urllib.request.HTTPPasswordMgrWithDefaultRealm()
    pm.add_password(None, "https://urs.earthdata.nasa.gov", u, p)
    return urllib.request.build_opener(urllib.request.HTTPBasicAuthHandler(pm),
                                       urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))


# ---- AppEEARS: SMAP soil moisture, MODIS NDVI, ECOSTRESS ET in one point request
APPEEARS = "https://appeears.earthdatacloud.nasa.gov/api"
APPEEARS_LAYERS = {  # (product, layer) -> (source label, normalized name, unit)
    ("SPL3SMP_E.006", "Soil_Moisture_Retrieval_Data_AM_soil_moisture"): ("NASA SMAP L3", "surface_soil_moisture", "m3/m3"),
    ("SPL4SMGP.008", "Geophysical_Data_sm_rootzone"): ("NASA SMAP L4", "root_zone_soil_moisture", "m3/m3"),
    ("SPL4SMGP.008", "Geophysical_Data_sm_surface"): ("NASA SMAP L4", "surface_soil_moisture_model", "m3/m3"),
    ("MOD13Q1.061", "_250m_16_days_NDVI"): ("NASA MODIS", "ndvi", "index -1..1"),
    ("ECO_L3T_JET.002", "ETdaily"): ("NASA ECOSTRESS", "evapotranspiration_daily", "mm/day"),
}


def appeears(lat, lon, start, end, ctx, poll_every=30, max_wait=3600):
    u, p = earthdata_creds()
    basic = base64.b64encode(f"{u}:{p}".encode()).decode()
    token = json.loads(http(f"{APPEEARS}/login", data=b"", method="POST",
                            headers={"Authorization": f"Basic {basic}",
                                     "Content-Type": "application/x-www-form-urlencoded"}))["token"]
    auth = {"Authorization": f"Bearer {token}"}
    try:
        task = {
            "task_type": "point",
            "task_name": f"farm_{lat}_{lon}_{start}_{end}",
            "params": {
                "dates": [{"startDate": ymd(start).strftime("%m-%d-%Y"), "endDate": ymd(end).strftime("%m-%d-%Y")}],
                "layers": [{"product": pr, "layer": ly} for pr, ly in APPEEARS_LAYERS],
                "coordinates": [{"latitude": lat, "longitude": lon, "id": "field"}],
            },
        }
        tid = json.loads(http(f"{APPEEARS}/task", data=json.dumps(task).encode(),
                              headers={**auth, "Content-Type": "application/json"}))["task_id"]
        print(f"  AppEEARS task {tid} submitted; waiting (usually 2-15 min)...", flush=True)
        waited = 0
        while True:
            st = json.loads(http(f"{APPEEARS}/task/{tid}", headers=auth))["status"]
            if st == "done":
                break
            if st == "error" or waited > max_wait:
                raise RuntimeError(f"AppEEARS task {tid} status={st} after {waited}s")
            time.sleep(poll_every); waited += poll_every

        bundle = json.loads(http(f"{APPEEARS}/bundle/{tid}", headers=auth))
        out = []
        for f in bundle["files"]:
            if not f["file_name"].endswith("-results.csv"):
                continue
            rows = csv.DictReader(io.StringIO(http(f"{APPEEARS}/bundle/{tid}/{f['file_id']}", headers=auth).decode()))
            for row in rows:
                for (prod, layer), (src, name, unit) in APPEEARS_LAYERS.items():
                    col = f"{prod.replace('.', '_')}_{layer}"
                    v = row.get(col)
                    if v in (None, ""):
                        continue
                    # skip pixels AppEEARS flags as fill / bad quality
                    try:
                        v = float(v)
                    except ValueError:
                        continue
                    if v <= -999 or (name == "ndvi" and not -1 <= v <= 1):
                        continue
                    out.append(rec(src, name, v, unit, row["Date"][:10], lat, lon))
        return out
    finally:
        try:
            http(f"{APPEEARS}/logout", data=b"", headers=auth, method="POST")
        except Exception:
            pass


# ---- GPM IMERG daily precipitation via GES DISC OPeNDAP (one tiny request per day)
IMERG = ("https://gpm1.gesdisc.eosdis.nasa.gov/opendap/GPM_L3/GPM_3IMERGDF.07/"
         "{y}/{m:02d}/3B-DAY.MS.MRG.3IMERG.{y}{m:02d}{d:02d}-S000000-E235959.V07B.nc4.ascii?precipitation[0][{i}][{j}]")


def imerg_daily(lat, lon, start, end, ctx, workers=8):
    opener = earthdata_opener()
    i = min(3599, max(0, round((lon + 179.95) / 0.1)))  # IMERG grid: 0.1 deg, dims [time][lon][lat]
    j = min(1799, max(0, round((lat + 89.95) / 0.1)))
    d0, d1 = ymd(start), min(ymd(end), date.today() - timedelta(days=4))  # final run lags a few days
    days = [d0 + timedelta(n) for n in range((d1 - d0).days + 1)]

    def one(d):
        url = IMERG.format(y=d.year, m=d.month, d=d.day, i=i, j=j)
        try:
            txt = http(url, opener=opener).decode()
        except urllib.error.HTTPError as e:
            if e.code == 401:
                raise MissingCredentials("Earthdata login rejected, or the 'NASA GESDISC DATA ARCHIVE' app isn't approved in your Earthdata profile")
            if e.code == 404:  # day not yet processed
                return None
            raise
        m = re.search(r"\]\s*,\s*(-?[\d.]+(?:[eE][-+]?\d+)?)\s*$", txt.split("precipitation.lon")[0].strip(), re.M)
        if not m or float(m.group(1)) < 0:
            return None
        return rec("NASA GPM IMERG", "precipitation", round(float(m.group(1)), 2), "mm/day", d.isoformat(), lat, lon)

    with ThreadPoolExecutor(workers) as ex:
        return [r for r in ex.map(one, days) if r]


# ====================================================================== Copernicus
def sentinel2_ndvi(lat, lon, start, end, ctx, half_size_m=30):
    """Copernicus Data Space (Sentinel Hub) Statistical API: cloud-masked NDVI over a ~60 m box."""
    cid, sec = os.environ.get("CDSE_CLIENT_ID"), os.environ.get("CDSE_CLIENT_SECRET")
    if not (cid and sec):
        raise MissingCredentials("set CDSE_CLIENT_ID and CDSE_CLIENT_SECRET (Copernicus Data Space OAuth client)")
    tok = json.loads(http(
        "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token",
        data=urllib.parse.urlencode({"grant_type": "client_credentials", "client_id": cid, "client_secret": sec}).encode(),
        headers={"Content-Type": "application/x-www-form-urlencoded"}))["access_token"]
    dlat = half_size_m / 111_320
    dlon = half_size_m / (111_320 * math.cos(math.radians(lat)))
    poly = [[lon - dlon, lat - dlat], [lon + dlon, lat - dlat], [lon + dlon, lat + dlat], [lon - dlon, lat + dlat], [lon - dlon, lat - dlat]]
    evalscript = """//VERSION=3
function setup(){return{input:[{bands:["B04","B08","SCL","dataMask"]}],
  output:[{id:"ndvi",bands:1,sampleType:"FLOAT32"},{id:"dataMask",bands:1}]};}
function evaluatePixel(s){
  var bad=[0,1,3,8,9,10,11].indexOf(s.SCL)>=0;   // no-data, saturated, shadow, cloud, cirrus, snow
  return {ndvi:[(s.B08-s.B04)/(s.B08+s.B04)], dataMask:[s.dataMask && !bad ? 1 : 0]};}"""
    body = {
        "input": {"bounds": {"geometry": {"type": "Polygon", "coordinates": [poly]},
                             "properties": {"crs": "http://www.opengis.net/def/crs/OGC/1.3/CRS84"}},
                  "data": [{"type": "sentinel-2-l2a", "dataFilter": {"maxCloudCoverage": 80}}]},
        "aggregation": {"timeRange": {"from": f"{ymd(start)}T00:00:00Z", "to": f"{ymd(end)}T23:59:59Z"},
                        "aggregationInterval": {"of": "P1D"}, "evalscript": evalscript,
                        "resx": 0.0001, "resy": 0.0001},
        "calculations": {"default": {}},
    }
    js = json.loads(http("https://sh.dataspace.copernicus.eu/api/v1/statistics", data=json.dumps(body).encode(),
                         headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"}))
    out = []
    for item in js.get("data", []):
        st = item["outputs"]["ndvi"]["bands"]["B0"]["stats"]
        n_ok = st.get("sampleCount", 0) - st.get("noDataCount", 0)
        try:
            mean = float(st["mean"])
        except (KeyError, TypeError, ValueError):
            continue
        if n_ok > 0 and not math.isnan(mean):
            out.append(rec("ESA Sentinel-2", "ndvi", round(mean, 4), "index -1..1", item["interval"]["from"][:10], lat, lon))
    return out


def era5_daily(lat, lon, start, end, ctx):
    """ERA5 point time series (hourly) from the Climate Data Store, aggregated to daily."""
    try:
        import cdsapi
    except ImportError:
        raise MissingCredentials("pip install 'cdsapi>=0.7.2' (and create ~/.cdsapirc with your CDS key)")
    if not (os.path.exists(os.path.expanduser("~/.cdsapirc")) or os.environ.get("CDSAPI_KEY")):
        raise MissingCredentials("create ~/.cdsapirc (or set CDSAPI_URL/CDSAPI_KEY) with your CDS API key")
    tmp = os.path.join(os.path.dirname(os.path.abspath(__file__)), f".era5_{lat}_{lon}_{start}_{end}.download")
    cdsapi.Client(quiet=True).retrieve("reanalysis-era5-single-levels-timeseries", {
        "variable": ["2m_temperature", "total_precipitation", "surface_solar_radiation_downwards",
                     "2m_dewpoint_temperature"],
        "location": {"longitude": lon, "latitude": lat},
        "date": [f"{ymd(start)}/{ymd(end)}"],
        "data_format": "csv",
    }, tmp)
    raw = open(tmp, "rb").read()
    os.remove(tmp)
    if raw[:2] == b"PK":  # sometimes delivered zipped
        z = zipfile.ZipFile(io.BytesIO(raw))
        raw = z.read(next(n for n in z.namelist() if n.endswith(".csv")))
    daily = {}
    for row in csv.DictReader(io.StringIO(raw.decode())):
        d = (row.get("valid_time") or row.get("time"))[:10]
        a = daily.setdefault(d, {"t": [], "tp": 0.0, "ssrd": 0.0, "d2m": []})
        if row.get("t2m"): a["t"].append(float(row["t2m"]) - 273.15)
        if row.get("tp"): a["tp"] += float(row["tp"]) * 1000          # m -> mm
        if row.get("ssrd"): a["ssrd"] += float(row["ssrd"]) / 1e6     # J/m2 -> MJ/m2
        if row.get("d2m"): a["d2m"].append(float(row["d2m"]) - 273.15)
    out = []
    for d, a in sorted(daily.items()):
        if a["t"]:
            out += [rec("ECMWF ERA5", "air_temp_mean", round(sum(a["t"]) / len(a["t"]), 2), "degC", d, lat, lon),
                    rec("ECMWF ERA5", "air_temp_max", round(max(a["t"]), 2), "degC", d, lat, lon),
                    rec("ECMWF ERA5", "air_temp_min", round(min(a["t"]), 2), "degC", d, lat, lon)]
        out += [rec("ECMWF ERA5", "precipitation", round(a["tp"], 2), "mm/day", d, lat, lon),
                rec("ECMWF ERA5", "solar_radiation", round(a["ssrd"], 2), "MJ/m2/day", d, lat, lon)]
        if a["d2m"]:
            out.append(rec("ECMWF ERA5", "dewpoint_mean", round(sum(a["d2m"]) / len(a["d2m"]), 2), "degC", d, lat, lon))
    return out


# ====================================================================== USDA
def county_of(lat, lon):
    js = json.loads(http(f"https://geo.fcc.gov/api/census/block/find?latitude={lat}&longitude={lon}&format=json"))
    return {"state": js["State"]["code"], "county_fips": js["County"]["FIPS"], "county_name": js["County"]["name"]}


CDL_TO_NASS = {  # Cropland Data Layer class -> (NASS commodity, yield unit, extra filter on short_desc)
    "Corn": ("CORN", "BU / ACRE", "GRAIN"), "Soybeans": ("SOYBEANS", "BU / ACRE", None),
    "Winter Wheat": ("WHEAT", "BU / ACRE", "WINTER"), "Spring Wheat": ("WHEAT", "BU / ACRE", "SPRING"),
    "Cotton": ("COTTON", "LB / ACRE", "UPLAND"), "Sorghum": ("SORGHUM", "BU / ACRE", "GRAIN"),
    "Alfalfa": ("HAY", "TONS / ACRE", "ALFALFA"), "Oats": ("OATS", "BU / ACRE", None),
    "Barley": ("BARLEY", "BU / ACRE", None), "Rice": ("RICE", "LB / ACRE", None),
}


def nass_county_yields(lat, lon, start, end, ctx, years_back=10):
    key = os.environ.get("NASS_API_KEY")
    if not key:
        raise MissingCredentials("set NASS_API_KEY (free key from quickstats.nass.usda.gov/api)")
    c = ctx.get("county") or county_of(lat, lon)
    crops = sorted({r["value"] for r in ctx.get("records", []) if r["source"] == "USDA CDL"} & set(CDL_TO_NASS)) \
        or ["Corn", "Soybeans"]
    out, y1 = [], ymd(end).year
    for crop in crops:
        commodity, unit, flt = CDL_TO_NASS[crop]
        q = urllib.parse.urlencode({
            "key": key, "source_desc": "SURVEY", "commodity_desc": commodity, "statisticcat_desc": "YIELD",
            "agg_level_desc": "COUNTY", "state_alpha": c["state"], "county_ansi": c["county_fips"][-3:],
            "year__GE": y1 - years_back, "format": "JSON"})
        try:
            rows = json.loads(http("https://quickstats.nass.usda.gov/api/api_GET/?" + q))["data"]
        except urllib.error.HTTPError as e:
            if e.code == 400:  # NASS returns 400 when the query matches nothing
                continue
            raise
        seen = set()
        for r in rows:
            sd = r["short_desc"]
            if not sd.endswith(unit) or (flt and flt not in sd) or "IRRIGATED" in sd or r["year"] in seen:
                continue
            try:
                v = float(r["Value"].replace(",", ""))
            except ValueError:  # "(D)" = withheld
                continue
            seen.add(r["year"])
            out.append(rec("USDA NASS", f"county_yield_{crop.lower().replace(' ', '_')}", v, unit.lower(),
                           str(r["year"]), lat, lon))
    return out


# ====================================================================== OpenET
OPENET_STATES = {"AZ", "CA", "CO", "ID", "KS", "MT", "NE", "NV", "NM", "ND", "OK", "OR", "SD", "TX", "UT", "WA", "WY"}


def openet_monthly(lat, lon, start, end, ctx):
    key = os.environ.get("OPENET_API_KEY")
    if not key:
        raise MissingCredentials("set OPENET_API_KEY (free key from account.etdata.org)")
    st = (ctx.get("county") or county_of(lat, lon))["state"]
    if st not in OPENET_STATES:
        raise MissingCredentials(f"OpenET only covers the 17 western states; this point is in {st}")
    body = {"date_range": [str(ymd(start)), str(ymd(end))], "interval": "monthly", "geometry": [lon, lat],
            "model": "Ensemble", "variable": "ET", "reference_et": "gridMET", "units": "mm", "file_format": "JSON"}
    js = json.loads(http("https://openet-api.org/raster/timeseries/point", data=json.dumps(body).encode(),
                         headers={"Authorization": key, "Content-Type": "application/json"}))
    out = []
    for row in js if isinstance(js, list) else js.get("data", []):
        d = row.get("time") or row.get("date")
        v = row.get("et", row.get("ET"))
        if d and v is not None:
            out.append(rec("OpenET Ensemble", "evapotranspiration_monthly", float(v), "mm/month", str(d)[:10], lat, lon))
    return out


# ====================================================================== registry
SOURCES = [  # (label, function) – run in this order after the open sources
    ("AppEEARS (SMAP/MODIS/ECOSTRESS)", appeears),
    ("GPM IMERG", imerg_daily),
    ("Sentinel-2 NDVI", sentinel2_ndvi),
    ("ERA5", era5_daily),
    ("NASS county yields", nass_county_yields),
    ("OpenET", openet_monthly),
]
