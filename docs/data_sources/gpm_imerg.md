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

## What the app uses: IMERG through NASA POWER

NASA POWER serves the daily IMERG Final Run at a point as `IMERG_PRECTOT` (mm/day), with no account. It only exists in **UTC days**: in the default local solar time every value is -999 with the message "The IMERG Source Data is not available at the Local Solar Time (LST) standard."

```
GET https://power.larc.nasa.gov/api/temporal/daily/point?community=AG&latitude=-41.32&longitude=-72.98&format=JSON&parameters=IMERG_PRECTOT&start=20060101&end=20251231&time-standard=UTC
```

Twenty years (7,305 days, about 145 KB) answer in under 2 s, so `NasaPower::Client#imerg_daily` asks once per field and `Weather::RainExtremes.summarize` keeps only the summary (the `gpm_imerg` observation): heavy days (25 mm or more) and extreme days (50 mm or more) per year and per month, the 99th percentile of rainy days, the wettest day and the longest dry spell of each year. Values stop about two months before today (Final Run latency), so the window is the last 20 full calendar years.

Checked on 2026-11-15:

| Pin | Rain a year | 25 mm days | 50 mm days | Wettest day |
|---|---|---|---|---|
| Puerto Varas, Chile (-41.32, -72.98) | 1,874 mm | 22.2 | 4.7 | 97.9 mm, 2015-07-17 |
| Nebraska (40.95, -97.50) | 792 mm | 7.8 | 0.8 | 129.2 mm, 2021-03-14 |
| San José, Costa Rica (9.93, -84.08) | 4,538 mm | 40.5 | 2.9 | 130.7 mm, 2025-11-07 |

**Mountains.** The San José cell shows no dry season (175 mm in January 2024, against about 38 mm in POWER's MERRA-2 normal). The 0.1° cell (about 11 km) seems to blend the Central Valley with the wet Caribbean slope. In steep terrain, read IMERG as the wider area's storms, not the farm's own rain; the profile shows it with zone confidence.

The OPeNDAP access below stays documented for the Late and Early runs (recent days) and for whole-grid work.

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
