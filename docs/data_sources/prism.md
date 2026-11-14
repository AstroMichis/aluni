# PRISM Climate Data (Oregon State University)

The PRISM Group at Oregon State University produces gridded climate data for the conterminous United States from station observations, using the PRISM interpolation method that accounts for elevation and terrain. Variables are precipitation, minimum/maximum/mean temperature, mean dewpoint and minimum/maximum vapor pressure deficit. Time series grids are daily (1981 to present), monthly and annual (1895 to present) at 4 km and 800 m; 30-year normals (1991-2020) are separate downloads. Daily grids are re-released up to 8 times and monthly grids up to 7 times over about six months before they are considered stable. There is no documented point-query API: data are delivered one grid per request as a zip package.

| | |
|---|---|
| Provider | PRISM Group, Northwest Alliance for Computational Science and Engineering (NACSE), Oregon State University |
| Base URL | `https://services.nacse.org/prism/data/get/` (web service); `https://data.prism.oregonstate.edu/` (HTTPS/FTP directory) |
| Auth | none |
| Formats | zip package containing COG GeoTIFF (default), netCDF (`?format=nc`) or BIL (`?format=bil`), plus metadata and station files |
| Coverage | CONUS (region `us`); Alaska, Hawaii, Puerto Rico listed as "not yet implemented" in the web service document |
| Resolution | 4 km (2.5 arc-minute, `25m` in filenames), 800 m (30 arc-second, `30s`); 400 m (`15s`) not yet implemented |
| Cadence / latency | daily grid for day D covers the 24 h ending 12:00 UTC on D; monthly and annual grids; data older than 6 months are stable |
| Rate limits / quotas | a file downloaded twice in 24 h cannot be downloaded again in that period; excessive activity may lead to IP blocking |
| Documentation | https://prism.oregonstate.edu/documents/PRISM_downloads_web_service.pdf ; https://prism.oregonstate.edu/downloads/ |

## Requests

### Time series grid download

Returns one grid (daily, monthly or annual) for CONUS as a zip file.

`https://services.nacse.org/prism/data/get/<region>/<res>/<element>/<date>[/lt][?format=nc|bil]`

| Parameter | Required | Description | Example |
|---|---|---|---|
| `<region>` (path) | yes | `us` (CONUS). `hi`, `ak`, `pr` not yet implemented | `us` |
| `<res>` (path) | yes | `4km` or `800m` (`400m` not yet implemented) | `4km` |
| `<element>` (path) | yes | `ppt`, `tmin`, `tmax`, `tmean`, `tdmean`, `vpdmin`, `vpdmax` | `ppt` |
| `<date>` (path) | yes | `YYYYMMDD` daily (from 19810101), `YYYYMM` monthly (from 189501), `YYYY` annual (from 1895) | `20250704` |
| `/lt` (path suffix) | no | Long-term (LT) 800 m monthly dataset instead of the default AN (all networks) | `/lt` |
| `format` (query) | no | `nc` (netCDF) or `bil`. Default is COG GeoTIFF | `bil` |

```
GET https://services.nacse.org/prism/data/get/us/4km/ppt/20250704
GET https://services.nacse.org/prism/data/get/us/4km/ppt/20250704?format=bil
GET https://services.nacse.org/prism/data/get/us/4km/tmax/202507?format=nc
```

### Sample response: zip package contents (Captured 2026-11-14)

Default (COG) request for `us/4km/ppt/20250704`. Response headers: `Content-Type: application/zip`, `Content-Disposition: filename="prism_ppt_us_25m_20250704.zip"`. Zip listing (bytes):

```
prism_ppt_us_25m_20250704.info.txt        809
prism_ppt_us_25m_20250704.prj             166
prism_ppt_us_25m_20250704.stn.csv     1583595
prism_ppt_us_25m_20250704.stx              33
prism_ppt_us_25m_20250704.tif         1158068
prism_ppt_us_25m_20250704.tif.aux.xml     548
prism_ppt_us_25m_20250704.xml            9306
```

With `?format=bil` the `.tif`/`.tif.aux.xml` pair is replaced by `.bil` (3,490,020 bytes), `.bil.aux.xml` and `.hdr`. With `?format=nc` (tested on `us/4km/tmax/202507`) it is replaced by `.nc` and `.nc.aux.xml`.

`info.txt` (not trimmed):

```
PRISM_DATASET_FILENAME: prism_ppt_us_25m_20250704.tif
PRISM_DATASET_CREATE_DATE: 20260119-0418
PRISM_SOURCE_FILENAME: adj_best_ppt_us_us_30s_20250704.bil
PRISM_SOURCE_CREATE_DATE: 20260116-1213
PRISM_DATASET_TYPE: an91/r2112
PRISM_DATASET_VERSION: D2
PRISM_CODE_VERSION: 16.2-20250715-1813
PRISM_DATASET_RELEASE_NUMBER: 8
PRISM_DATASET_REMARKS: This grid was developed in three steps: (1) precipitation data were modeled with PRISM at 30-arc-second (~800m) resolution to produce the source grid(s) listed under PRISM_SOURCE_FILENAME, on the date(s) listed under PRISM_SOURCE_CREATE_DATE; (2) The source grid was adjusted as needed to ensure that the sum of the daily grids equals the monthly modeled grid; and (3) This source grid was then upscaled to 2.5-arc-minute(~ 4km) resolution with a Gaussian filter.
```

`.hdr` from the BIL package (not trimmed):

```
BYTEORDER      I
LAYOUT         BIL
NROWS          621
NCOLS          1405
NBANDS         1
NBITS          32
BANDROWBYTES   5620
TOTALROWBYTES  5620
PIXELTYPE      FLOAT
ULXMAP         -125.000000000000
ULYMAP         49.916666666667
XDIM           0.041666666667
YDIM           0.041666666667
NODATA         -9999
```

`.prj`: `GEOGCS["GCS_North_American_1983",DATUM["D_North_American_1983",SPHEROID["GRS_1980",6378137,298.257222101]],PRIMEM["Greenwich",0],UNIT["Degree",0.017453292519943295]]`

`.stn.csv` (trimmed: first line and header kept, then only the stations within about 0.3 degrees of the reference point; the file has 24,609 lines):

```
This file contains a list of stations that provided input data to the PRISM run that produced the grid associated with this stn.csv file.
Station,Name,Longitude,Latitude,Elevation(m),Network,station_id
"253461","GRESHAM 3 W",-97.4694,41.0308,497,"COOP","21460"
"YORK002","YORK 1.0 E",-97.5740,40.8683,503,"COCORAHS","113430"
"YORK005","YORK 3.3 N",-97.5985,40.9156,493,"COCORAHS","113465"
"YORK019","WACO 3.6 E",-97.3948,40.8868,490,"COCORAHS","113506"
"YORK023","STROMSBURG 6",-97.5205,41.0357,503,"COCORAHS","113637"
"NEYRK01","YORK 2W",-97.6333,40.8667,490,"HPRCC","203242"
```

`.tif.aux.xml` statistics (not trimmed): `NoDataValue -9999`, `STATISTICS_MINIMUM .0000`, `STATISTICS_MAXIMUM 342.6410`, `STATISTICS_MEAN 7.0749`, `STATISTICS_STDDEV 16.3382`.

### Sample values at the reference point (Captured 2026-11-14)

Read from the downloaded grids at 40.95, -97.50 (4 km cell row 215, col 660, cell center 40.9583, -97.5000). COG and BIL values matched.

| Grid request | Value |
|---|---|
| `us/4km/ppt/20250701` | 1.753 mm |
| `us/4km/ppt/20250702` | 7.786 mm |
| `us/4km/ppt/20250703` | 0.0 mm |
| `us/4km/ppt/20250704` | 0.0 mm |
| `us/4km/ppt/20250705` | 11.716 mm |
| `us/4km/ppt/202507` | 122.992 mm |
| `us/4km/tmax/202507` | 30.185 degC |

### Release date service

Returns, per grid, the data date, release date, element, grid count (update number) and data URL. Tab-delimited by default, JSON with `?json=true`.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `<region>`, `<res>`, `<element>` (path) | yes | As in the data service | `us/4km/ppt` |
| `<date>` (path) | yes | Single date | `20250704` |
| `<end date>` (path) | no | Second date for a range | `20250705` |
| `json` (query) | no | `true` for JSON output | `true` |

```
GET https://services.nacse.org/prism/data/get/releaseDate/us/4km/ppt/20250701/20250705?json=true
```

### Sample response (Captured 2026-11-14)

Not trimmed.

```json
[["2025-07-01", "2026-01-20", "ppt", "8", "https://services.nacse.org/prism/data/get/us/4km/ppt/20250701"],
 ["2025-07-02", "2026-01-19", "ppt", "8", "https://services.nacse.org/prism/data/get/us/4km/ppt/20250702"],
 ["2025-07-03", "2026-01-19", "ppt", "8", "https://services.nacse.org/prism/data/get/us/4km/ppt/20250703"],
 ["2025-07-04", "2026-01-19", "ppt", "8", "https://services.nacse.org/prism/data/get/us/4km/ppt/20250704"],
 ["2025-07-05", "2026-01-19", "ppt", "8", "https://services.nacse.org/prism/data/get/us/4km/ppt/20250705"]]
```

Without `?json=true` (`.../ppt/20250701/20250703`), the same columns are returned as tab-separated lines:

```
2025-07-01	2026-01-20	ppt	8	https://services.nacse.org/prism/data/get/us/4km/ppt/20250701
2025-07-02	2026-01-19	ppt	8	https://services.nacse.org/prism/data/get/us/4km/ppt/20250702
2025-07-03	2026-01-19	ppt	8	https://services.nacse.org/prism/data/get/us/4km/ppt/20250703
```

### Grid count service

Returns a single integer, the update number (1 to 8 for daily, 1 to 7 for monthly). Identical across resolutions.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `<region>` (path) | yes | Region | `us` |
| `<element>` (path) | yes | Element | `ppt` |
| `<date>` (path) | yes | `YYYYMMDD` or `YYYYMM` | `20250704` |

```
GET https://services.nacse.org/prism/data/get/gridCount/us/ppt/20250704
```

### Sample response (Captured 2026-11-14)

```
8
```

### 30-year normals (1991-2020), directory download

Normals are not available from the web service; they are files in the data directory.

URL pattern: `https://data.prism.oregonstate.edu/normals/<region>/<res>/<element>/<monthly|daily>/prism_<element>_<region>_<res code>_<YYYYMM|YYYY>_avg_30y.zip`, where the monthly files use `2020MM` (month MM) and `2020` (annual), and `<res code>` is `25m` (4 km) or `30s` (800 m).

| Path element | Required | Description | Example |
|---|---|---|---|
| region | yes | `us`, `ak` | `us` |
| resolution | yes | `4km`, `800m` | `4km` |
| element | yes | `ppt`, `tdmean`, `tmax`, `tmean`, `tmin`, `vpdmax`, `vpdmin` | `ppt` |
| temporal | yes | `monthly`, `daily` | `monthly` |

```
GET https://data.prism.oregonstate.edu/normals/us/4km/ppt/monthly/prism_ppt_us_25m_202007_avg_30y.zip
```

### Sample response (Captured 2026-11-14)

Zip listing (bytes): `.info.txt` 510, `.prj` 166, `.stn.csv` 1,397,703, `.stx` 34, `.tif` 2,782,786, `.tif.aux.xml` 385, `.xml` 8,823. The `.tif` is a COG (LZW compression, 512 x 512 tiles, 1405 x 621 pixels, NoData `-9999`). `info.txt` (trimmed: remarks line removed):

```
PRISM_DATASET_FILENAME: dem_ppt_us_us_30s_912007.bil
PRISM_DATASET_CREATE_DATE: 20221129-1501
PRISM_DATASET_TYPE: an91/r2207d, normals/9120.a
PRISM_DATASET_VERSION: M4
PRISM_CODE_VERSION: 16.1-20220830-1154
```

Value at the reference point (row 215, col 660): July 1991-2020 normal precipitation 87.1654 mm.

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `ppt` grid value | float32 | mm | Total precipitation (rain plus melted snow) for the day, month or year |
| `tmin`, `tmax`, `tmean` grid value | float32 | degC | Minimum, maximum, mean air temperature |
| `tdmean` grid value | float32 | degC | Mean dewpoint temperature |
| `vpdmin`, `vpdmax` grid value | float32 | hPa | Minimum, maximum vapor pressure deficit |
| `PRISM_DATASET_TYPE` (info.txt) | string | | `an...` = AN (all networks) dataset; `lt` = long-term dataset; `normals/...` for normals |
| `PRISM_DATASET_RELEASE_NUMBER` (info.txt) | integer | | Update number of this grid (same as grid count) |
| `PRISM_DATASET_VERSION` (info.txt) | string | | Dataset version code (for example `D2` daily, `M4` normals) |
| stn.csv `Station`, `Name`, `Longitude`, `Latitude`, `Elevation(m)`, `Network`, `station_id` | mixed | deg, m | Stations used in the model run for that grid |
| releaseDate columns | strings | | Data date, release date, element, grid count, data URL |

NoData value: `-9999` (in `.hdr`, `.aux.xml`, and the GeoTIFF NoData tag). Grids are geographic NAD83. In the BIL `.hdr`, `ULXMAP`/`ULYMAP` are the center of the upper-left cell; the COG GeoTIFF tie point (-125.0208, 49.9375) is the outer corner.

## Notes

- A PRISM "day" is the 24 hours ending at 12:00 GMT (7:00 am EST) on the labeled date, not a local calendar day.
- `?format=asc` is listed in the web service PDF (dated 26 Mar 2025) but on 2026-11-14 returned HTTP 200 with the text body `Invalid data format requested (asc) -- please use one of the following: nc,bil`.
- The old service path (`https://services.nacse.org/prism/data/public/4km/ppt/20250704`) returned HTTP 200 with an HTML notice that services were centralized, pointing to the new `/prism/data/get/` syntax; no data.
- The data directory readme states the FTP layout with `daily`, `monthly`, `normals_bil` and BIL `..._provisional_4kmD2_...` names was to be deprecated on 30 September 2025, replaced by `time_series/` and `normals/` with COG files and internal names (for example `time_series/us/an/4km/ppt/daily/2025/prism_ppt_us_25m_20250101.zip`).
- No documented point-query API was found. The PRISM Data Explorer (https://prism.oregonstate.edu/explorer/) is an interactive web page that returns 4 km cell time series for a location (with an optional inverse-distance interpolation) and offers a multi-location upload; its backend calls are not documented.
- Data stability per the Explorer page: dates older than 6 months are "stable", 1 to 6 months "provisional", current month "early".
- The download limit is per file: requesting the same grid twice in 24 hours blocks further downloads of that file for the period. During capture, `us/4km/ppt/20250704` was downloaded twice (COG and BIL) without an error.
- The web service PDF lists CONUS as the only region currently served.

## Documentation

- Web service document: https://prism.oregonstate.edu/documents/PRISM_downloads_web_service.pdf
- Bulk download information: https://prism.oregonstate.edu/downloads/
- Data directory and readme: https://data.prism.oregonstate.edu/ ; https://data.prism.oregonstate.edu/readme.txt
- PRISM datasets description: https://prism.oregonstate.edu/documents/PRISM_datasets.pdf
- Update schedule: https://prism.oregonstate.edu/documents/PRISM_update_schedule.pdf
- Data Explorer: https://prism.oregonstate.edu/explorer/
