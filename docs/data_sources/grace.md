# GRACE / GRACE-FO (terrestrial water storage and GRACE-based drought indicators)

GRACE (2002-2017) and GRACE Follow-On (2018-present) measure month-to-month changes in Earth's gravity field, which over land reflect changes in total water storage (groundwater, soil moisture, snow, surface water). Level-3 mascon products give monthly anomalies of liquid water equivalent thickness (cm) relative to a 2004.0-2009.999 baseline. The JPL RL06.3 v04 mascon grid (0.5 degree sampling, 3 degree effective resolution) is distributed by NASA PO.DAAC (Earthdata Login required); the CSR RL06.3 mascon grid (0.25 degree sampling) is an open download from the University of Texas Center for Space Research. GRACE-based weekly drought indicators (groundwater, root zone and surface soil moisture percentiles, 0.125 degree, CONUS) are produced by NASA GSFC from GRACE data assimilation into the Catchment land surface model; they are archived at GES DISC (login) and published as open GeoTIFF/netCDF files by the National Drought Mitigation Center (NDMC).

| | |
|---|---|
| Provider | NASA JPL and PO.DAAC (JPL mascons); UT Austin CSR (CSR mascons); NASA GSFC HSL, GES DISC and NDMC University of Nebraska-Lincoln (drought indicators) |
| Base URL | PO.DAAC: `https://archive.podaac.earthdata.nasa.gov/` ; CSR: `https://download.csr.utexas.edu/outgoing/grace/RL0603_mascons/` ; NDMC: `https://nasagrace.unl.edu/data/` ; GES DISC: `https://data.gesdisc.earthdata.nasa.gov/data/GRACEDA/` |
| Auth | JPL mascons and GES DISC files: Earthdata Login account (https://urs.earthdata.nasa.gov). CSR mascons and NDMC files: none |
| Formats | netCDF4 (mascons, GRACEDADM), GeoTIFF, ERDAS IMG, PNG/PDF maps (NDMC) |
| Coverage | mascons: global. Drought indicators: CONUS (25N to 53N, 125W to 67W) for V4.0; a global 0.25 degree V3.0 product also exists |
| Resolution | JPL: 0.5 degree grid, 3 degree equal-area mascons. CSR: 0.25 degree grid. Drought indicators: 0.125 degree |
| Cadence / latency | mascons: monthly, single file per release containing the whole time series (JPL file on 2026-11-14 covered 2002-04 to 2026-09; CSR "Data Span: Apr 2002 to Sept 2026", updated 2026-11-11). Drought indicators: weekly (Mondays); NDMC latest folder on 2026-11-14: 20261109; GES DISC latest granule: 2026-08-31 |
| Rate limits / quotas | not published |
| Documentation | https://grace.jpl.nasa.gov/data/get-data/jpl_global_mascons/ ; https://www2.csr.utexas.edu/grace/RL06_mascons.html ; https://nasagrace.unl.edu/ ; https://docserver.gesdisc.eosdis.nasa.gov/public/project/hydrology/README_GRACEDADM4.pdf |

## What the app uses

`Grace::Client` reads the JPL CRI mascon file through PO.DAAC's open reference file (`..._virtual_https.json`, 1,527 keys, about 380 KB): `lwe_thickness` is chunked `[66, 90, 180]` (64 zlib chunks of about 175 KB), so one cell is four Range requests, plus the `scale_factor` chunk (`[1, 360, 720]`, the land scale factors to multiply by). OPeNDAP was tried first and answers 404 ("Failed to read the DMR++ from S3"). Bearer tokens come from `find_or_create_token` on Earthdata Login.

Checked on 2026-11-15 (last 12 months against 2004-2009, 10-year trend):

| Pin | Last 12 months | Trend | Lowest year |
|---|---|---|---|
| Buin, Chile (-33.60, -70.70) | -19.7 cm | -3.1 cm a decade | 2011 (-30.1 cm): the central Chile megadrought from 2010 |
| York, Nebraska (40.95, -97.50) | +4.5 cm | -44.5 cm a decade | 2006 (-12.7 cm); peak 2019 (+47 cm, the Midwest floods) |
| Alajuela, Costa Rica (10.03, -84.20) | -12.3 cm | -1.0 cm a decade | 2015 (-17.5 cm) |

## Requests

### JPL mascon granule discovery (CMR)

Open search; returns the single time-series file for the collection.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `short_name` | yes | `TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4` (CRI filtered) or `TELLUS_GRAC-GRFO_MASCON_GRID_RL06.3_V4` | `TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4` |
| `temporal` | no | ISO 8601 range | `2025-01-01T00:00:00Z,2025-12-31T23:59:59Z` |
| `point` | no | `lon,lat` | `-97.50,40.95` |

```
GET https://cmr.earthdata.nasa.gov/search/granules.json?short_name=TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4&temporal=2025-01-01T00:00:00Z,2025-12-31T23:59:59Z&point=-97.50,40.95&page_size=20
```

### Sample response (Captured 2026-11-14, trimmed)

`cmr-hits: 1`. Trimmed to `id`, `title`, start/end dates, size (MB) and a subset of links.

```
G4407658620-POCLOUD GRCTellus.JPL.200204_202609.GLO.RL06.3M.MSCNv04CRI 2002-04-16 2026-09-16 44.217355728149414
  https://archive.podaac.earthdata.nasa.gov/podaac-ops-cumulus-protected/TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4/GRCTellus.JPL.200204_202609.GLO.RL06.3M.MSCNv04CRI.nc
  https://archive.podaac.earthdata.nasa.gov/podaac-ops-cumulus-public/TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4/GRCTellus.JPL.200204_202609.GLO.RL06.3M.MSCNv04CRI.nc.md5
  s3://podaac-ops-cumulus-protected/TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4/GRCTellus.JPL.200204_202609.GLO.RL06.3M.MSCNv04CRI.nc
  https://archive.podaac.earthdata.nasa.gov/s3credentials
  https://opendap.earthdata.nasa.gov
  https://archive.podaac.earthdata.nasa.gov/podaac-ops-cumulus-public/virtual_collections/TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4/TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4_virtual_https.json
  https://archive.podaac.earthdata.nasa.gov/podaac-ops-cumulus-public/virtual_collections/TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4/TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4.icechunk_v2.https
  https://archive.podaac.earthdata.nasa.gov/podaac-ops-cumulus-protected/... (release notes, docs links omitted)
```

### JPL mascon file download

```
GET https://archive.podaac.earthdata.nasa.gov/podaac-ops-cumulus-protected/TELLUS_GRAC-GRFO_MASCON_CRI_GRID_RL06.3_V4/GRCTellus.JPL.200204_202609.GLO.RL06.3M.MSCNv04CRI.nc
Authorization: Bearer <EDL token>
```

### Sample response: file structure (Captured 2026-11-14, from the public virtual-collection reference file)

The netCDF file itself requires login. Its structure was read from the open reference file `..._virtual_https.json` (kerchunk/Zarr metadata). Trimmed: global attributes cut to the first keys; `GAD`, `lat_bounds`, `lon_bounds` attribute blocks shortened.

```
.zattrs  {"Conventions":"CF-1.6, ACDD-1.3, ISO 8601","title":"JPL GRACE and GRACE-FO MASCON RL06.3Mv04 CRI",
          "summary":"Monthly gravity solutions from GRACE and GRACE-FO as determined from the JPL RL06.3Mv04 mascon solution - with CRI filter applied", ...}
lwe_thickness  shape [260,360,720] float64 fill -99999.0
   {"units":"cm","long_name":"Liquid_Water_Equivalent_Thickness","coordinates":"time lat lon",
    "valid_min":-2285.196487044295,"valid_max":1275.7910765253473,"comment":"Coastline Resolution Improvement (CRI) filter is applied"}
uncertainty    shape [260,360,720] float64 fill -99999.0
   {"units":"cm","long_name":"uncertainty","comment":"1-sigma uncertainty: not for each 0.5 degree grid cell, but for each 3-degree mascon estimate"}
scale_factor   shape [260,360,720] float64 fill -99999.0
   {"units":"dimensionless","long_name":"Scale_Factor_CRI","description":"Gridded scale factors to be used with mascon solution that has the CRI filter applied; based on CLM data from 2002-2009"}
land_mask      shape [260,360,720] {"units":"binary","description":"Land Mask that was used with the CRI filter"}
mascon_ID      shape [260,360,720] {"valid_min":1.0,"valid_max":4551.0,"description":"Mascon identifier mapped to the grid"}
GAD            shape [260,360,720] {"units":"cm","long_name":"OCEAN_ATMOSPHERE_DEALIAS_MODEL_(GAD)"}
time           shape [260] {"units":"days since 2002-01-01T00:00:00Z","calendar":"gregorian","bounds":"time_bounds"}
time_bounds    shape [260,2] {"comment":"time bounds for each time value, i.e. the first day and last day included in the monthly solution"}
lat            shape [360] {"units":"degrees_north","valid_min":-89.75,"valid_max":89.75}
lon            shape [720] {"units":"degrees_east","valid_min":0.25,"valid_max":359.75}
```

### CSR mascon file download (open)

Single netCDF file with the full monthly time series and all corrections applied. Component files (GSU, C20, C30, degree-1, GIA, GAD, GAC) and land/ocean masks are separate files in the same directory.

| Parameter | Required | Description | Example |
|---|---|---|---|
| file name (path) | yes | `CSR_GRACE_GRACE-FO_RL0603_Mascons_all-corrections.nc` or a component file | `CSR_GRACE_GRACE-FO_RL0603_Mascons_all-corrections.nc` |
| `Range` header | no | Byte range (server sends `Accept-Ranges: bytes`) | `bytes=0-63` |

```
GET https://download.csr.utexas.edu/outgoing/grace/RL0603_mascons/CSR_GRACE_GRACE-FO_RL0603_Mascons_all-corrections.nc
```

### Sample response (Captured 2026-11-14, headers only)

Fetched with `Range: bytes=0-63`; the full file was not downloaded.

```
HTTP 206
Content-Type: application/x-netcdf
Content-Range: bytes 0-63/113954516
Last-Modified: Mon, 09 Nov 2026 17:45:36 GMT
Accept-Ranges: bytes

first bytes: 89 48 44 46 0d 0a 1a 0a  (HDF5 signature, i.e. netCDF-4)
```

Per the CSR page, variables are liquid water equivalent thickness anomalies on a 0.25 degree grid relative to the 2004.0000-2009.999 mean, corrected for C20/C30 (SLR), degree-1, GIA (ICE6G-D) and with GAD added back.

### GRACE-based drought indicators, NDMC weekly files (open)

One folder per weekly date (Monday). Folder list: `https://nasagrace.unl.edu/ConusData.aspx`; folder page: `https://nasagrace.unl.edu/ConusData.aspx?p=<YYYYMMDD>`; files: `https://nasagrace.unl.edu/data/<YYYYMMDD>/<file>`.

| Path element | Required | Description | Example |
|---|---|---|---|
| `<YYYYMMDD>` | yes | Weekly date (Mondays, 20020401 onward) | `20250707` |
| file | yes | `gws_perc_0125deg_US_<date>.tif` / `.img` (groundwater percentile), `rtzsm_perc_...` (root zone soil moisture), `sfsm_perc_...` (surface soil moisture), `GRACEDADM_CLSM0125US_7D.A<date>.030.nc4`, `GRACE_<GWS|RTZSM|SFSM>_<date>.png|pdf` | `gws_perc_0125deg_US_20250707.tif` |

```
GET https://nasagrace.unl.edu/data/20250707/gws_perc_0125deg_US_20250707.tif
GET https://nasagrace.unl.edu/data/20250707/rtzsm_perc_0125deg_US_20250707.tif
GET https://nasagrace.unl.edu/data/20250707/sfsm_perc_0125deg_US_20250707.tif
```

### Sample response (Captured 2026-11-14)

Folder `20250707` file listing (from the folder page):

```
GRACE_GWS_20250707.pdf, GRACE_GWS_20250707.png
GRACE_RTZSM_20250707.pdf, GRACE_RTZSM_20250707.png
GRACE_SFSM_20250707.pdf, GRACE_SFSM_20250707.png
GRACEDADM_CLSM0125US_7D.A20250707.030.nc4
gws_perc_0125deg_US_20250707.img, gws_perc_0125deg_US_20250707.tif
rtzsm_perc_0125deg_US_20250707.img, rtzsm_perc_0125deg_US_20250707.tif
sfsm_perc_0125deg_US_20250707.img, sfsm_perc_0125deg_US_20250707.tif
```

GeoTIFF properties (gws file, 319,695 bytes): 464 x 224 pixels, float32, LZW compression, 128 x 128 tiles, pixel size 0.125 degree, upper-left corner -125.0, 53.0, GCS WGS 1984, NoData `-999`.

Values at the reference point (row 96, col 220):

| File | Value |
|---|---|
| `gws_perc_0125deg_US_20250707.tif` | 9.4524 |
| `rtzsm_perc_0125deg_US_20250707.tif` | 61.5166 |
| `sfsm_perc_0125deg_US_20250707.tif` | 70.4172 |

### GRACE-DA drought indicators at GES DISC (login)

Collection `GRACEDADM_CLSM0125US_7D` version 4.0 (CMR concept `C1993409520-GES_DISC`). Discovery via CMR (open), files and Cloud OPeNDAP via Earthdata Login, point time series via the Giovanni time series API (variables `GRACEDADM_CLSM0125US_7D_4_0_gws_inst`, `..._rtzsm_inst`, `..._sfsm_inst`; see `nldas_gldas.md`).

```
GET https://cmr.earthdata.nasa.gov/search/granules.json?short_name=GRACEDADM_CLSM0125US_7D&version=4.0&temporal=2025-07-01T00:00:00Z,2025-07-20T23:59:59Z&point=-97.50,40.95&page_size=20&sort_key=start_date
```

### Sample response (Captured 2026-11-14, trimmed)

`cmr-hits: 3`. Trimmed to `id`, `title`, start/end, size (MB) and the last granule's data/OPeNDAP links.

```
G3742875556-GES_DISC GRACEDADM_CLSM0125US_7D.4.0:GRACEDADM_CLSM0125US_7D.A20250630.040.nc4 2025-06-30 2025-07-06 0.743000984191895
G3874466048-GES_DISC GRACEDADM_CLSM0125US_7D.4.0:GRACEDADM_CLSM0125US_7D.A20250707.040.nc4 2025-07-07 2025-07-13 0.746128082275391
G3874466268-GES_DISC GRACEDADM_CLSM0125US_7D.4.0:GRACEDADM_CLSM0125US_7D.A20250714.040.nc4 2025-07-14 2025-07-20 0.743422508239746
   https://data.gesdisc.earthdata.nasa.gov/data/GRACEDA/GRACEDADM_CLSM0125US_7D.4.0/2025/GRACEDADM_CLSM0125US_7D.A20250714.040.nc4
   https://opendap.earthdata.nasa.gov/collections/C1993409520-GES_DISC/granules/GRACEDADM_CLSM0125US_7D.4.0%3AGRACEDADM_CLSM0125US_7D.A20250714.040.nc4
```

## Fields

JPL mascon netCDF:

| Field | Type | Unit | Description |
|---|---|---|---|
| `lwe_thickness` | float64 (time, lat, lon) | cm | Liquid water equivalent thickness anomaly vs 2004.0-2009.999 mean |
| `uncertainty` | float64 | cm | 1-sigma uncertainty per 3 degree mascon (not per 0.5 degree cell) |
| `scale_factor` | float64 | dimensionless | Gain factors (CLM-based) for the CRI solution; not applied to `lwe_thickness` |
| `land_mask` | float64 | binary | Land mask used with the CRI filter |
| `mascon_ID` | float64 | | Mascon number 1 to 4551 |
| `GAD` | float64 | cm | Ocean/atmosphere de-aliasing model field |
| `time` | float64 | days since 2002-01-01T00:00:00Z | Month center |
| `time_bounds` | float64 | days since 2002-01-01 | First and last day included in each monthly solution |
| `lat`, `lon` | float64 | degrees | Cell centers; `lon` runs 0.25 to 359.75 (east) |

Fill value `-99999.0` for data variables.

GRACE-DA drought indicators (GRACEDADM V4.0 netCDF and NDMC GeoTIFFs):

| Field | Type | Unit | Description |
|---|---|---|---|
| `gws_inst` / `gws_perc` | float | % (percentile) | Groundwater storage percentile |
| `rtzsm_inst` / `rtzsm_perc` | float | % (percentile) | Root zone soil moisture percentile |
| `sfsm_inst` / `sfsm_perc` | float | % (percentile) | Surface soil moisture percentile |

Percentiles express the probability of occurrence within the 1948-2014 period of record (README). Grid: 224 (lat) x 464 (lon), cell centers 25.0625 to 52.9375 N and -124.9375 to -67.0625. Undefined value `-999`.

## Notes

- Mascon grids are anomalies relative to the 2004.0-2009.999 mean; comparing with other anomaly data needs the same baseline.
- JPL: the 0.5 degree grid represents 3 degree equal-area mascons; neighbouring 0.5 degree cells within one mascon share the same estimate. Longitudes are 0 to 360, so -97.50 corresponds to 262.50.
- JPL re-estimates all previous months with each new month (time correlation in the solution), with the largest changes in the last about 4 months; the file name changes with each release (for example `..._200204_202609...`).
- The PO.DAAC public virtual reference file fetched on 2026-11-14 still pointed to the previous file `GRCTellus.JPL.200204_202608...nc` (260 time steps) while CMR listed `..._200204_202609...`.
- Downloading the JPL mascon file without credentials on 2026-11-14 redirected to the Earthdata Login page (no data).
- Cloud OPeNDAP for the GRACEDADM granule (`...A20250714.040.nc4.dmr.xml`) without credentials redirected to Earthdata Login and returned HTTP 401.
- The CSR all-corrections file is HDF5-based netCDF-4 (113,954,516 bytes); reading it requires a netCDF4/HDF5 library.
- The NDMC folder `20250707` contains GRACEDADM file version `.030.nc4`, while GES DISC serves `.040.nc4` (V4.0) for the same date.
- The NDMC site HTML contains a commented-out banner stating weekly indicators are not updated during a federal funding lapse; it was not displayed on 2026-11-14 and the latest folder was `20261109`.
- The GES DISC README states a 3 to 6 month latency for GRACEDADM V4.0; on 2026-11-14 the latest GES DISC granule was 2026-08-31 and the NDMC folder list went to 2026-11-09.
- The values in the drought indicator GeoTIFFs at the reference point were read with a custom TIFF/LZW reader at the cell containing 40.95, -97.50.

## Documentation

- JPL mascons: https://grace.jpl.nasa.gov/data/get-data/jpl_global_mascons/
- PO.DAAC GRACE / GRACE-FO: https://podaac.jpl.nasa.gov/GRACE ; https://podaac.jpl.nasa.gov/GRACE-FO
- JPL mascon release notes: https://archive.podaac.earthdata.nasa.gov/podaac-ops-cumulus-docs/gracefo/open/docs/GRACE_GRACE-FO_ReleaseNotes_JPL_MASCON.txt
- CSR RL06.3 mascons: https://www2.csr.utexas.edu/grace/RL06_mascons.html
- GRACE-DA-DM U.S. V4.0 README: https://docserver.gesdisc.eosdis.nasa.gov/public/project/hydrology/README_GRACEDADM4.pdf ; DOI 10.5067/UH653SEZR9VQ
- GES DISC dataset page: https://disc.gsfc.nasa.gov/datacollection/GRACEDADM_CLSM0125US_7D_4.0.html
- NDMC GRACE drought indicators: https://nasagrace.unl.edu/ ; About: https://nasagrace.unl.edu/About.aspx
- Citations: Wiese et al. (JPL mascon CRI, doi:10.5067/TEMSC-3MJC6); Save 2020 (CSR mascons, doi:10.15781/cgq9-nh24); Houborg et al. 2012 (doi:10.1029/2011WR011291)
