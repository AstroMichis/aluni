# GPM IMERG precipitation

The Global Precipitation Measurement mission's IMERG product merges radar, microwave and infrared satellite data with rain gauges into rainfall estimates on a 0.1° grid (about 11 km x 8 km at this latitude).

| | |
|---|---|
| Product | `GPM_3IMERGDF.07`: daily, Final run, version 07 (gauge-calibrated) |
| Access | GES DISC OPeNDAP, one tiny request per day for one grid cell |
| Auth | Earthdata login (`EARTHDATA_USERNAME`, `EARTHDATA_PASSWORD`), redirect through `urs.earthdata.nasa.gov` with cookies; the **NASA GESDISC DATA ARCHIVE** app must be approved in the Earthdata profile |
| Resolution | 0.1° |
| Latency | Final: ~3.5 months. For recent days use the Late run (`GPM_3IMERGDL.07`, ~14 h) or Early run (`GPM_3IMERGDE.07`, ~4 h); same layout |
| Record | June 2000 onward |
| Docs | https://gpm.nasa.gov/data/imerg |

## Grid indexing

The daily file holds `precipitation[time=1][lon=3600][lat=1800]` (Captured from the dataset's `.dds`). Note the order: **longitude before latitude**.

```
lon_index = floor((lon + 180) / 0.1)    # -97.50 -> 824 (cell center -97.55)
lat_index = floor((lat +  90) / 0.1)    #  40.95 -> 1309 (cell center 40.95)
```

A point exactly on a cell edge (like -97.50) belongs to one cell only; floor makes the choice deterministic. Clamp to 0..3599 and 0..1799.

## Request

```
GET https://gpm1.gesdisc.eosdis.nasa.gov/opendap/GPM_L3/GPM_3IMERGDF.07/2025/07/
    3B-DAY.MS.MRG.3IMERG.20250704-S000000-E235959.V07B.nc4.ascii?precipitation[0][824][1309]
```

File naming (Captured from the directory listing): `3B-DAY.MS.MRG.3IMERG.YYYYMMDD-S000000-E235959.V07B.nc4`. The version suffix (`V07B`) changes when NASA reprocesses; each month directory has a `contents.html` listing the current file names.

Without a login the server answers `401 Unauthorized` (Captured).

## Sample response (Representative)

```
Dataset: 3B-DAY.MS.MRG.3IMERG.20250704-S000000-E235959.V07B.nc4
precipitation.precipitation, [1][1][1]
[0][0], 21.385
precipitation.time, 20273
precipitation.lon, -97.55
precipitation.lat, 40.95
```

The value after `[0][0],` is **mm/day** for that grid cell. `lon`/`lat` are the cell center. Negative values are fill.

Other variables in the same file (append to the query with commas): `precipitation_cnt` (number of half-hour samples that went into the day), `randomError` (mm/day uncertainty), `probabilityLiquidPrecipitation` (rain vs. snow, %).

## Alternatives for longer windows

- **Monthly**: `GPM_3IMERGM.07`, one request per month (mm/hour average; x hours in month for a total).
- **Half-hourly**: `GPM_3IMERGHH.07` (mm/hour), 48 files per day.
- **Worldview images**: for a visual layer only, not for numbers.

## Notes

- Daily files are in **UTC**, so a 7 p.m. thunderstorm in Nebraska lands on the next day's file. Fine for weekly totals, wrong for "it rained on the day I planted".
- IMERG underestimates light drizzle and can miss short convective storms that fall between satellite passes. It is good for totals and patterns, not single-event precision.
- 0.1° is still ~90 km² per cell: one value for a whole neighbourhood of fields.
- Daily data is one request per day per grid cell (~365 per year); nearby points share grid cells.

## Documentation

- IMERG: https://gpm.nasa.gov/data/imerg
- GES DISC dataset page: https://disc.gsfc.nasa.gov/datasets/GPM_3IMERGDF_07/summary
- OPeNDAP Hyrax constraint syntax: https://opendap.github.io/hyrax_guide/Master_Hyrax_Guide.html
- Earthdata Login app approval: https://urs.earthdata.nasa.gov/profile
