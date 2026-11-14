# Daymet (ORNL DAAC single-pixel API)

Daymet Version 4 R1 provides daily gridded surface weather estimates (minimum and maximum temperature, precipitation, shortwave radiation, vapor pressure, snow water equivalent, day length) interpolated from ground stations on a 1 km x 1 km grid covering continental North America, Hawaii and Puerto Rico. The record starts 1980-01-01 and is extended one full calendar year at a time (the 2025 year was available on 2026-11-14). The single-pixel API returns the time series for the 1 km cell that contains a latitude/longitude point, as CSV or JSON, without a login. Gridded subsets (netCDF) are served separately through THREDDS/OPeNDAP.

| | |
|---|---|
| Provider | Oak Ridge National Laboratory Distributed Active Archive Center (ORNL DAAC), NASA |
| Base URL | `https://daymet.ornl.gov/single-pixel/api/data` |
| Auth | none for the single-pixel API; Earthdata Login account (https://urs.earthdata.nasa.gov) for the THREDDS/OPeNDAP gridded subsets |
| Formats | CSV (default), JSON |
| Coverage | North America (single-pixel docs: latitude 14.5N to 52.0N, longitude -131.0 to -53.0), Hawaii, Puerto Rico |
| Resolution | 1 km x 1 km, Lambert Conformal Conic projection |
| Cadence / latency | daily values; published once per year for the previous full calendar year |
| Rate limits / quotas | not published |
| Documentation | https://daymet.ornl.gov/web_services ; OpenAPI UI https://daymet.ornl.gov/single-pixel/api |

## Requests

### Single-pixel data download

Returns the daily time series for the 1 km cell containing the point, as a file attachment (CSV or JSON).

| Parameter | Required | Description | Example |
|---|---|---|---|
| `lat` | yes | Latitude, decimal degrees | `40.95` |
| `lon` | yes | Longitude, decimal degrees (west negative) | `-97.50` |
| `vars` | no | Comma-separated variables: `tmax`, `tmin`, `srad`, `vp`, `swe`, `prcp`, `dayl`. All variables when omitted | `tmax,tmin,prcp,srad,vp,swe,dayl` |
| `years` | no | Comma-separated years. Takes precedence over `start`/`end` | `2025` |
| `start` | no | Start date, `YYYY-MM-DD` | `2025-07-01` |
| `end` | no | End date, `YYYY-MM-DD` | `2025-07-05` |
| `format` | listed as required in the OpenAPI spec (`csv` or `json`); CSV is returned when omitted | Output format | `json` |

```
GET https://daymet.ornl.gov/single-pixel/api/data?lat=40.95&lon=-97.50&vars=tmax,tmin,prcp,srad,vp,swe,dayl&start=2025-07-01&end=2025-07-05
```

### Sample response: CSV (Captured 2026-11-14)

Not trimmed.

```
Latitude: 40.95  Longitude: -97.5
X & Y on Lambert Conformal Conic: 200845.61 -161203.74
Tile: 11742
Elevation: 496 meters
All years; all variables; Daymet Software Version 4.0
How to cite: Thornton; M.M.; R. Shrestha; Y. Wei; P.E. Thornton; S-C. Kao; and B.E. Wilson. 2022. Daymet: Daily Surface Weather Data on a 1-km Grid for North America; Version 4 R1. ORNL DAAC; Oak Ridge; Tennessee; USA. https://doi.org/10.3334/ORNLDAAC/2129
year,yday,dayl (s),prcp (mm/day),srad (W/m^2),swe (kg/m^2),tmax (deg c),tmin (deg c),vp (Pa)
2025,182,53631.56,6.44,372.44,0.00,30.38,14.15,1612.95
2025,183,53594.06,0.00,486.46,0.00,32.62,16.68,1782.77
2025,184,53553.01,0.00,427.62,0.00,32.52,19.22,2183.62
2025,185,53508.45,9.04,272.86,0.00,30.84,20.34,2387.04
2025,186,53460.40,0.00,354.85,0.00,31.39,21.06,2494.76
```

Response headers included `Content-Type: text/csv; charset=utf-8` and `Content-Disposition: attachment; filename=11742_lat_40.95_lon_-97.5_2026-11-14_175057.csv`.

### Single-pixel data download, JSON

Same endpoint with `format=json`.

```
GET https://daymet.ornl.gov/single-pixel/api/data?lat=40.95&lon=-97.50&vars=tmax,tmin,prcp&start=2025-07-01&end=2025-07-03&format=json
```

### Sample response: JSON (Captured 2026-11-14)

Not trimmed.

```json
{"loc": [40.95, -97.5], "Tile": "11742", "Elevation": "496 m", "LCC": [200845.61, -161203.74],
 "citation": "Thornton; M.M.; R. Shrestha; Y. Wei; P.E. Thornton; S-C. Kao; and B.E. Wilson. 2022. Daymet: Daily Surface Weather Data on a 1-km Grid for North America; Version 4 R1. ORNL DAAC; Oak Ridge; Tennessee; USA. https://doi.org/10.3334/ORNLDAAC/2129",
 "data": {"year": [2025.0, 2025.0, 2025.0],
          "yday": [182.0, 183.0, 184.0],
          "prcp (mm/day)": [6.440000057220459, 0.0, 0.0],
          "tmax (deg c)": [30.3799991607666, 32.619998931884766, 32.52000045776367],
          "tmin (deg c)": [14.149999618530273, 16.68000030517578, 19.219999313354492]}}
```

### Full year request

```
GET https://daymet.ornl.gov/single-pixel/api/data?lat=40.95&lon=-97.50&vars=prcp&years=2025&format=csv
```

### Sample response: full year (Captured 2026-11-14, trimmed)

Trimmed: header block (same as above) and days 1 to 362 removed. The file was 5,482 bytes with 365 data rows.

```
year,yday,prcp (mm/day)
2025,363,0.00
2025,364,0.00
2025,365,0.00
```

### Gridded subset via THREDDS NetCDF Subset Service (NCSS)

The web services page documents NCSS URLs of the form below for gridded (bounding-box) netCDF subsets of dataset 1840/2129. Listed for completeness; see Notes for what happened when tried.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `var` | yes | Variable name (repeatable) | `prcp` |
| `north`, `south`, `east`, `west` | yes for a box | Bounding box, decimal degrees | `41.0`, `40.9`, `-97.4`, `-97.6` |
| `time_start`, `time_end` | yes | ISO 8601 times | `2025-07-01T12:00:00Z` |
| `accept` | no | Output format | `netcdf` |

```
GET https://thredds.daac.ornl.gov/thredds/ncss/grid/ornldaac/2129/daymet_v4_daily_na_prcp_2025.nc?var=prcp&north=41.0&west=-97.6&east=-97.4&south=40.9&time_start=2025-07-01T12:00:00Z&time_end=2025-07-05T12:00:00Z&accept=netcdf
```

### Sample response (Representative)

A CF-compliant netCDF file with dimensions `time`, `y`, `x` (Lambert Conformal Conic), coordinate variables `lat`, `lon`, `time`, and the requested variable (for example `prcp(time, y, x)` in mm/day), per the Daymet web services page.

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `year` | integer (float in JSON) | year | Calendar year |
| `yday` | integer (float in JSON) | day of year | Day of year, 1 to 365 |
| `dayl (s)` | float | s/day | Day length (duration of daylight) |
| `prcp (mm/day)` | float | mm/day | Daily total precipitation |
| `srad (W/m^2)` | float | W/m2 | Incident shortwave radiation flux density, averaged over the daylight period |
| `swe (kg/m^2)` | float | kg/m2 | Snow water equivalent |
| `tmax (deg c)` | float | degC | Daily maximum 2 m air temperature |
| `tmin (deg c)` | float | degC | Daily minimum 2 m air temperature |
| `vp (Pa)` | float | Pa | Daily average water vapor partial pressure |
| `Latitude`, `Longitude` / `loc` | float | degrees | Requested point (echoed) |
| `X & Y on Lambert Conformal Conic` / `LCC` | float | m | Projected coordinates of the point |
| `Tile` | string | | Daymet 2 x 2 degree tile ID containing the point |
| `Elevation` | string/number | m | Elevation of the 1 km cell |

No fill values appeared in the captured responses. CSV values are rounded to 2 decimals; JSON values are full float precision.

## Notes

- Daymet uses a 365-day calendar: in leap years December 31 is dropped, so `yday` never exceeds 365.
- `srad` is averaged over the daylight period only, not over 24 hours; the daily total energy is `srad * dayl`.
- A date range outside the published record (tested `start=2026-07-01&end=2026-07-03` on 2026-11-14) did not return an error: it returned HTTP 200 with the full record for the requested variables (1980 through 2025, 231,719 bytes).
- A point outside the Daymet tiles (tested `lat=60&lon=10`) returned HTTP 400 with `{"message":"Daymet Tile was not found with input lat and lon: ..."}`.
- The OpenAPI description text says `years` covers `[1980..2019]`; the 2025 year was returned on 2026-11-14, so that text is out of date.
- The web services page still shows the THREDDS host `thredds.daac.ornl.gov`. On 2026-11-14 the catalog URL `https://thredds.daac.ornl.gov/thredds/catalog/ornldaac/2129/catalog.xml` redirected to `https://opendap.earthdata.nasa.gov/...` and returned HTTP 400 (Hyrax Bad Request); the NCSS point URL redirected to Earthdata Login and returned HTTP 401 without credentials. The NCSS sample above is therefore Representative.
- Responses are sent with `Content-Disposition: attachment`; the filename embeds the tile ID and request timestamp.

## Documentation

- Web services overview: https://daymet.ornl.gov/web_services
- Single-pixel OpenAPI (Swagger UI): https://daymet.ornl.gov/single-pixel/api ; spec JSON: https://daymet.ornl.gov/single-pixel/static/swagger.json
- Dataset (V4 R1 daily): https://doi.org/10.3334/ORNLDAAC/2129
- Single Pixel Extraction Tool citation: https://doi.org/10.3334/ORNLDAAC/2361
