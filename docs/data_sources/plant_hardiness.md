# USDA Plant Hardiness Zone Map

The USDA Plant Hardiness Zone Map (PHZM) classifies locations by the 1991-2020 mean annual extreme minimum winter temperature, in 10 degF zones split into 5 degF half zones (for example 5b = -15 to -10 degF). The official 2023 map is published by USDA Agricultural Research Service (ARS); the underlying GIS data were produced by the PRISM Group at Oregon State University at 800 m (CONUS, Alaska) and 400 m (Hawaii, Puerto Rico). USDA does not publish a documented lookup API: the official site offers an interactive map with ZIP search, and PRISM/OSU publishes downloadable grids, shapefiles, KML and a ZIP code table. A third-party static JSON API (phzmapi.org) republishes the ZIP table. The dataset is static (released 2023).

| | |
|---|---|
| Provider | USDA ARS (official map); PRISM Group, Oregon State University (GIS data) |
| Base URL | `https://prism.oregonstate.edu/phzm/data/2023/` (downloads); `https://planthardiness.ars.usda.gov/` (interactive map); `https://phzmapi.org/` (third party) |
| Auth | none |
| Formats | CSV (ZIP code table), BIL grid in zip, shapefile zip, KML zip; JSON (phzmapi.org) |
| Coverage | CONUS (`us`), Alaska (`ak`), Hawaii (`hi`), Puerto Rico (`pr`) |
| Resolution | 30 arc-second (about 800 m) for CONUS and Alaska; 15 arc-second (about 400 m) for Hawaii and Puerto Rico; ZIP table: one zone per ZIP code |
| Cadence / latency | static, 2023 release (1991-2020 climate) |
| Rate limits / quotas | not published |
| Documentation | https://prism.oregonstate.edu/phzm/ ; https://planthardiness.ars.usda.gov/ |

## Requests

### ZIP code table (PRISM/OSU)

One CSV per region listing every ZIP code with its zone.

| Parameter | Required | Description | Example |
|---|---|---|---|
| region (file name) | yes | `us`, `ak`, `hi`, `pr` | `us` |

```
GET https://prism.oregonstate.edu/phzm/data/2023/phzm_us_zipcode_2023.csv
```

### Sample response (Captured 2026-11-14, trimmed)

Trimmed: header, first 2 rows, and the ZIP codes 68460 to 68467 kept (file size 1,244,727 bytes).

```
zipcode,zone,trange,zonetitle
00501,7b,5 to 10,7b: 5 to 10
00544,7b,5 to 10,7b: 5 to 10
68460,5b,-15 to -10,5b: -15 to -10
68461,6a,-10 to -5,6a: -10 to -5
68462,5b,-15 to -10,5b: -15 to -10
68463,6a,-10 to -5,6a: -10 to -5
68464,6a,-10 to -5,6a: -10 to -5
68465,6a,-10 to -5,6a: -10 to -5
68466,6a,-10 to -5,6a: -10 to -5
68467,5b,-15 to -10,5b: -15 to -10
```

### Temperature grid (PRISM/OSU)

Mean annual extreme minimum temperature grid, BIL format in a zip.

| Parameter | Required | Description | Example |
|---|---|---|---|
| region (file name) | yes | `us`, `ak`, `hi`, `pr` | `us` |

```
GET https://prism.oregonstate.edu/phzm/data/2023/phzm_us_grid_2023.zip
```

### Sample response (Captured 2026-11-14)

Zip (41,068,950 bytes, `Content-Type: application/zip`) listing (bytes):

```
phzm_terms_of_use.txt          830
phzm_us_grid_2023.aux.xml     2198
phzm_us_grid_2023.bil     87250500
phzm_us_grid_2023.hdr          319
phzm_us_grid_2023.prj          166
phzm_us_grid_2023.stx           59
phzm_us_grid_2023.xml         7753
```

`.hdr` (not trimmed):

```
BYTEORDER      I
LAYOUT         BIL
NROWS          3105
NCOLS          7025
NBANDS         1
NBITS          32
BANDROWBYTES   28100
TOTALROWBYTES  28100
PIXELTYPE      FLOAT
ULXMAP         -125.016666666666
ULYMAP         49.933333333333
XDIM           0.008333333333
YDIM           0.008333333333
NODATA         -9999
```

`.stx`: `1 -39.1486015320 53.0806999207 -1.3578606752 16.3535987400` (band, min, max, mean, std dev in degF).

Value at the reference point 40.95, -97.50 (row 1078, col 3302): `-11.2218` degF, which falls in half zone 5b (-15 to -10 degF).

### Shapefile and KML (PRISM/OSU)

Half-zone polygons.

```
GET https://prism.oregonstate.edu/phzm/data/2023/phzm_us_zones_shp_2023.zip
GET https://prism.oregonstate.edu/phzm/data/2023/phzm_us_zones_kml_2023.zip
```

### Sample response (Representative)

Per the PRISM PHZM page: a zipped Esri shapefile (and a zipped KML) of half-zone polygons with FGDC metadata; zone attributes correspond to the `zone` / `trange` values in the ZIP table. Not downloaded.

### Third-party ZIP lookup API (phzmapi.org)

Static JSON files, one per ZIP code, generated from the PRISM 2023 ZIP table. Not operated by USDA or OSU (MIT-licensed project `waldoj/frostline`).

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{zipcode}` (path) | yes | 5-digit ZIP code | `68467` |

Other files: `/all.json`, `/all.csv`, `/manifest.json`.

```
GET https://phzmapi.org/68467.json
```

### Sample response (Captured 2026-11-14)

Not trimmed.

```json
{"zone": "5b", "temperature_range": "-15 to -10", "coordinates": {"lat": "40.865237", "lon": "-97.58884"}}
```

`/manifest.json` (trimmed to the first keys):

```json
{"source": "USDA Plant Hardiness Zone Map, via PRISM Climate Group", "source_url": "https://prism.oregonstate.edu/phzm/", "source_vintage": "2023", "generated": "2026-08-24T14:48:58Z", "license": "MIT", "repository": "https://github.com/waldoj/frostline", ...}
```

Unknown ZIP (`/99999.json`): HTTP 404 with `{"error": "ZIP code not included in PHZM data"}`.

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `zipcode` | string (5 digits, leading zeros) | | ZIP code |
| `zone` | string | | Half zone, `1a` to `13b` |
| `trange` / `temperature_range` | string | degF | Zone temperature range, `low to high` |
| `zonetitle` | string | | `zone: trange` label |
| `coordinates.lat`, `coordinates.lon` (phzmapi) | string | degrees | ZIP point used by the third-party API |
| grid cell value | float32 | degF | 1991-2020 mean annual extreme minimum temperature |

Grid NoData: `-9999`. Grid CRS from `.prj`: geographic, GCS North American 1983 (NAD83). Zone from temperature: zone number n covers [-60 + 10(n-1), -50 + 10(n-1)) degF; half zone `a` is the colder 5 degF, `b` the warmer.

## Notes

- Units are degrees Fahrenheit (grid metadata `attrunit`: Degrees Fahrenheit).
- The official USDA site (https://planthardiness.ars.usda.gov/) embeds an ArcGIS Experience app (`https://experience.arcgis.com/experience/b1d1fd9b284e46dcaa43959bec439b44/`) with a ZIP search; no documented public API for it was found, so it is not documented here as an endpoint.
- `https://prism.oregonstate.edu/projects/plant_hardiness_zones.php` returned HTTP 404 on 2026-11-14; the current PHZM data page is `https://prism.oregonstate.edu/phzm/`.
- The ZIP table gives one zone per ZIP; the ZIP for the reference point (68467, York) is 5b, and the 800 m grid cell at 40.95, -97.50 (-11.22 degF) is also 5b, while some neighbouring ZIPs are 6a.
- Terms of use (in the zip): OSU owns the GIS datasets; redistribution is allowed if the USDA-ARS and OSU logos are displayed, and altered data must carry a disclaimer that it is not the official USDA map and drop both logos.
- Prior 2012 map data: https://prism.oregonstate.edu/phzm/phzm_2012.php

## Documentation

- PRISM PHZM 2023 GIS datasets: https://prism.oregonstate.edu/phzm/
- USDA ARS Plant Hardiness Zone Map: https://planthardiness.ars.usda.gov/
- Method paper: Daly, C., et al. 2012. Development of a new USDA plant hardiness zone map for the United States. J. Appl. Meteor. Climatol. 51(2): 242-264. doi:10.1175/2010JAMC2536.1
- Third-party API: https://www.phzmapi.org/ (source https://github.com/waldoj/frostline)
