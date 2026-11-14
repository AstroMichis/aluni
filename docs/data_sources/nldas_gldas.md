# NLDAS and GLDAS (Land Data Assimilation Systems)

NLDAS-2 (North American Land Data Assimilation System, phase 2) and GLDAS-2 (Global LDAS, version 2) are NASA GSFC land surface model products distributed by the GES DISC. NLDAS-2 provides hourly meteorological forcing (precipitation, temperature, humidity, radiation, wind, pressure, potential evaporation) and land surface model output (Noah, Mosaic, VIC: soil moisture by layer, evapotranspiration, runoff, snow, soil temperature) on a 0.125 degree grid over central North America (25N to 53N, 125W to 67W) from January 1979, updated daily with a lag of a few days. GLDAS-2.1 Noah provides 3-hourly and monthly global land output at 0.25 and 1.0 degree from 2000, with a lag of about 1 to 4 months; GLDAS-2.0 covers 1948 to 2014; GLDAS-2.2 includes GRACE data assimilation. Files are netCDF (NLDAS v2.0, GLDAS) in Earthdata Cloud; access to files, OPeNDAP and the point time series API requires an Earthdata Login account.

| | |
|---|---|
| Provider | NASA GSFC Hydrological Sciences Laboratory (producer); NASA GES DISC (distribution) |
| Base URL | files: `https://data.gesdisc.earthdata.nasa.gov/data/` ; Cloud OPeNDAP: `https://opendap.earthdata.nasa.gov/collections/<concept-id>/granules/<granule-ur>` ; point time series: `https://api.giovanni.earthdata.nasa.gov/timeseries` ; discovery: CMR (see `earthdata_cmr.md`) |
| Auth | Earthdata Login account (free, https://urs.earthdata.nasa.gov) for all data access; CMR search and the Giovanni `configured-variables` list are open |
| Formats | netCDF4 (`.nc`, `.nc4`); CSV from the Giovanni time series service; DAP4 / netCDF4 subsets from OPeNDAP |
| Coverage | NLDAS: 25N to 53N, 125W to 67W. GLDAS: global land, 60S to 90N |
| Resolution | NLDAS: 0.125 degree, hourly and monthly. GLDAS Noah: 0.25 and 1.0 degree, 3-hourly and monthly |
| Cadence / latency | NLDAS_FORA0125_H 2.0 latest granule on 2026-11-14: 2026-11-11T12:00Z. GLDAS_NOAH025_3H 2.1 latest granule: 2026-07-31T21:00Z |
| Rate limits / quotas | not published |
| Documentation | https://disc.gsfc.nasa.gov/datasets/NLDAS_FORA0125_H_2.0/summary ; https://disc.gsfc.nasa.gov/datasets/GLDAS_NOAH025_3H_2.1/summary ; https://ldas.gsfc.nasa.gov/ |

## Requests

### Granule discovery (CMR)

Returns file records with HTTPS, S3 and Cloud OPeNDAP links. Open (no login). Parameters as in `earthdata_cmr.md`.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `short_name` | yes | Collection | `NLDAS_FORA0125_H` |
| `version` | yes | Version | `2.0` |
| `temporal` | no | ISO 8601 range | `2025-07-01T00:00:00Z,2025-07-01T01:59:59Z` |
| `point` | no | `lon,lat` | `-97.50,40.95` |
| `page_size` | no | Max 2000 | `5` |

```
GET https://cmr.earthdata.nasa.gov/search/granules.json?short_name=NLDAS_FORA0125_H&version=2.0&temporal=2025-07-01T00:00:00Z,2025-07-01T01:59:59Z&point=-97.50,40.95&page_size=5
```

### Sample response (Captured 2026-11-14, trimmed)

Trimmed to `id`, `collection_concept_id`, `title`, `time_start`, `time_end`, `granule_size` (MB) and the data/OPeNDAP links. Second and third blocks are the same query for `NLDAS_NOAH0125_H` 2.0 and `GLDAS_NOAH025_3H` 2.1.

```
G3591020467-GES_DISC C2033151148-GES_DISC NLDAS_FORA0125_H.2.0:NLDAS_FORA0125_H.A20250701.0000.020.nc 2025-07-01T00:00:00.000Z 2025-07-01T00:00:00.000Z 1.954907417297363
   https://data.gesdisc.earthdata.nasa.gov/data/NLDAS/NLDAS_FORA0125_H.2.0/2025/182/NLDAS_FORA0125_H.A20250701.0000.020.nc
   s3://gesdisc-cumulus-prod-protected/NLDAS/NLDAS_FORA0125_H.2.0/2025/182/NLDAS_FORA0125_H.A20250701.0000.020.nc
   https://opendap.earthdata.nasa.gov/collections/C2033151148-GES_DISC/granules/NLDAS_FORA0125_H.2.0%3ANLDAS_FORA0125_H.A20250701.0000.020.nc
G3591020393-GES_DISC C2033151148-GES_DISC NLDAS_FORA0125_H.2.0:NLDAS_FORA0125_H.A20250701.0100.020.nc 2025-07-01T01:00:00.000Z 2025-07-01T01:00:00.000Z 1.931145668029785

G3592167504-GES_DISC C2069246977-GES_DISC NLDAS_NOAH0125_H.2.0:NLDAS_NOAH0125_H.A20250701.0000.020.nc 2025-07-01T00:00:00.000Z 2025-07-01T00:00:00.000Z 7.122549057006836
   https://opendap.earthdata.nasa.gov/collections/C2069246977-GES_DISC/granules/NLDAS_NOAH0125_H.2.0%3ANLDAS_NOAH0125_H.A20250701.0000.020.nc

G3874388483-GES_DISC C1342986035-GES_DISC GLDAS_NOAH025_3H.2.1:GLDAS_NOAH025_3H.A20250701.0000.021.nc4 2025-07-01T00:00:00.000Z 2025-07-01T00:00:00.000Z 21.5852165222168
   https://data.gesdisc.earthdata.nasa.gov/data/GLDAS/GLDAS_NOAH025_3H.2.1/2025/182/GLDAS_NOAH025_3H.A20250701.0000.021.nc4
   https://opendap.earthdata.nasa.gov/collections/C1342986035-GES_DISC/granules/GLDAS_NOAH025_3H.2.1%3AGLDAS_NOAH025_3H.A20250701.0000.021.nc4
G3874383519-GES_DISC C1342986035-GES_DISC GLDAS_NOAH025_3H.2.1:GLDAS_NOAH025_3H.A20250701.0300.021.nc4 2025-07-01T03:00:00.000Z 2025-07-01T03:00:00.000Z 21.6325750350952
```

### Point time series: Giovanni in the Cloud Time Series Service

Returns a CSV time series of one variable at one point. This is the GES DISC replacement for the Hydrology Data Rods service. Requires an Earthdata Login bearer token (or `.netrc`/cookie login).

| Parameter | Required | Description | Example |
|---|---|---|---|
| `data` | yes | Variable ID `<SHORTNAME>_<version with underscores>_<variable>` (list at `/configured-variables/`) | `NLDAS_FORA0125_H_2_0_Rainf` |
| `location` | yes | `[lat,lon]`, URL-encoded when sent from a script | `%5B40.95%2C-97.50%5D` |
| `time` | yes | `start/end` ISO 8601, URL-encoded | `2025-07-01T00%3A00%3A00%2F2025-07-05T23%3A00%3A00` |
| `version` | listed in the documented example URLs | Collection version | `2.0` |
| `Authorization` header | yes (scripts) | `Bearer <Earthdata Login token>` | |

Endpoints: `/timeseries` for scripts; `/proxy-timeseries` for browsers (redirects to Earthdata Login, then to `/timeseries`).

```
GET https://api.giovanni.earthdata.nasa.gov/timeseries?data=NLDAS_FORA0125_H_2_0_Rainf&location=%5B40.95%2C-97.50%5D&time=2025-07-01T00%3A00%3A00%2F2025-07-05T23%3A00%3A00&version=2.0
Authorization: Bearer <EDL token>
```

### Sample response (Representative)

Per the GES DISC how-to "Giovanni In The Cloud: Time Series Service", the response is a CSV file for one variable at the grid cell containing the point, covering the requested time range at the variable's native time step (hourly for NLDAS_FORA0125_H). The how-to shows the CSV only as a screenshot, so the exact header lines are not reproduced here. Structure as described there: metadata lines about the product, variable and location, followed by rows of UTC timestamp and value. Fill values are not plotted in the companion web tool.

```
<metadata header lines: product, variable, units, location, time range>
<timestamp UTC>,<value>
2025-07-01T00:00:00,<Rainf value, kg/m2>
2025-07-01T01:00:00,<Rainf value, kg/m2>
...
```

### Configured variables list (open)

Returns every variable ID the time series service supports.

```
GET https://api.giovanni.earthdata.nasa.gov/configured-variables/
```

### Sample response (Captured 2026-11-14, trimmed)

867 IDs in total. Trimmed: only the first 3 IDs and a selection of NLDAS/GLDAS/GRACE IDs shown.

```json
{"configured_variables": ["AIRS3STD_006_CloudFrc_A", "AIRS3STD_006_CloudFrc_D", "AIRS3STD_006_CloudTopPres_A",
 "GLDAS_NOAH025_3H_2_1_Rainf_f_tavg", "GLDAS_NOAH025_3H_2_1_RootMoist_inst", "GLDAS_NOAH025_3H_2_1_SoilMoi0_10cm_inst",
 "GLDAS_NOAH025_3H_2_1_SoilMoi10_40cm_inst", "GLDAS_NOAH025_3H_2_1_SoilMoi40_100cm_inst", "GLDAS_NOAH025_3H_2_1_SoilMoi100_200cm_inst",
 "GLDAS_NOAH025_3H_2_1_Evap_tavg", "GLDAS_NOAH025_3H_2_1_PotEvap_tavg", "GLDAS_NOAH025_3H_2_1_Tair_f_inst",
 "GLDAS_NOAH025_M_2_1_SoilMoi0_10cm_inst", "GLDAS_CLSM025_DA1_D_2_2_GWS_tavg", "GLDAS_CLSM025_DA1_D_2_2_SoilMoist_RZ_tavg",
 "GRACEDADM_CLSM0125US_7D_4_0_gws_inst", "GRACEDADM_CLSM0125US_7D_4_0_rtzsm_inst", "GRACEDADM_CLSM0125US_7D_4_0_sfsm_inst",
 "NLDAS_FORA0125_H_2_0_Rainf", "NLDAS_FORA0125_H_2_0_Tair", "NLDAS_FORA0125_H_2_0_SWdown", "NLDAS_FORA0125_H_2_0_PotEvap",
 "NLDAS_FORA0125_H_2_0_Qair", "NLDAS_FORA0125_H_2_0_Wind_E", "NLDAS_FORA0125_H_2_0_Wind_N",
 "NLDAS_NOAH0125_H_2_0_SoilM_0_10cm", "NLDAS_NOAH0125_H_2_0_SoilM_10_40cm", "NLDAS_NOAH0125_H_2_0_SoilM_40_100cm",
 "NLDAS_NOAH0125_H_2_0_SoilM_100_200cm", "NLDAS_NOAH0125_H_2_0_RootMoist", "NLDAS_NOAH0125_H_2_0_Evap",
 "NLDAS_NOAH0125_H_2_0_SMAvail_0_100cm", "NLDAS_NOAH0125_M_2_0_SoilM_0_100cm", "NLDAS_VIC0125_H_2_0_SoilM_total",
 "SMERGE_RZSM0_40CM_2_0_RZSM"]}
```

### Cloud OPeNDAP subset of one granule

Returns selected variables and index ranges from one granule (DAP4). Requires Earthdata Login.

| Parameter | Required | Description | Example |
|---|---|---|---|
| collection concept ID (path) | yes | From CMR | `C2033151148-GES_DISC` |
| granule UR (path, URL-encoded) | yes | From CMR `title` | `NLDAS_FORA0125_H.2.0%3ANLDAS_FORA0125_H.A20250701.0000.020.nc` |
| suffix | yes | Response encoding: `.dap.nc4` (netCDF4), `.dmr.xml` (metadata), `.dap.csv` | `.dap.nc4` |
| `dap4.ce` | no | DAP4 constraint expression: variables and `[start:stride:stop]` index ranges | `/Rainf[0][127][219];/Tair[0][127][219]` |

```
GET https://opendap.earthdata.nasa.gov/collections/C2033151148-GES_DISC/granules/NLDAS_FORA0125_H.2.0%3ANLDAS_FORA0125_H.A20250701.0000.020.nc.dap.nc4?dap4.ce=/Rainf[0][127][219];/Tair[0][127][219];/lat[127];/lon[219]
Authorization: Bearer <EDL token>
```

Index arithmetic (NLDAS 0.125 degree grid, cell centers from 25.0625N and -124.9375): lat index = round((40.95 - 25.0625) / 0.125) = 127 (center 40.9375); lon index = (-97.50 + 124.9375) / 0.125 = 219.5, so the point falls on the boundary between index 219 (center -97.5625) and 220 (center -97.4375).

### Sample response (Representative)

A netCDF4 file containing `Rainf(time=1, lat=1, lon=1)`, `Tair(time=1, lat=1, lon=1)`, `lat(1)`, `lon(1)` with their CF attributes (per the GES DISC "OPeNDAP In The Cloud" how-to and the NLDAS-2 README).

### HTTPS file download

```
GET https://data.gesdisc.earthdata.nasa.gov/data/NLDAS/NLDAS_FORA0125_H.2.0/2025/182/NLDAS_FORA0125_H.A20250701.0000.020.nc
GET https://data.gesdisc.earthdata.nasa.gov/data/GLDAS/GLDAS_NOAH025_3H.2.1/2025/182/GLDAS_NOAH025_3H.A20250701.0000.021.nc4
```

Path pattern: `/data/<PROJECT>/<SHORTNAME>.<version>/<YYYY>/<DOY>/<file>`. NLDAS file: one hour, whole grid (about 2 MB FORA, 7 MB NOAH). GLDAS 0.25 degree 3-hourly file: about 21.6 MB, global.

### Sample response (Representative)

netCDF4 file, dimensions `time` (1), `lat`, `lon` (NLDAS 224 x 464; GLDAS 0.25 degree 600 x 1440), one variable per field listed below, with `units`, `long_name`, `_FillValue` attributes (per the NLDAS-2 and GLDAS-2 READMEs).

## Fields

NLDAS_FORA0125_H 2.0 (hourly forcing):

| Field | Type | Unit | Description |
|---|---|---|---|
| `Tair` | float | K | 2 m air temperature |
| `Qair` | float | kg/kg | 2 m specific humidity |
| `PSurf` | float | Pa | Surface pressure |
| `Wind_E`, `Wind_N` | float | m/s | 10 m eastward / northward wind |
| `LWdown`, `SWdown` | float | W/m2 | Downward longwave / shortwave radiation |
| `Rainf` | float | kg/m2 (= mm per hour) | Hourly total precipitation |
| `CRainf_frac` | float | fraction | Fraction of precipitation that is convective |
| `CAPE` | float | J/kg | Convective available potential energy |
| `PotEvap` | float | kg/m2 | Potential evaporation |

NLDAS_NOAH0125_H 2.0 (selected):

| Field | Type | Unit | Description |
|---|---|---|---|
| `SoilM_0_10cm`, `SoilM_10_40cm`, `SoilM_40_100cm`, `SoilM_100_200cm` | float | kg/m2 | Soil moisture content per layer |
| `SoilM_0_100cm`, `SoilM_0_200cm` | float | kg/m2 | Column soil moisture |
| `SMAvail_0_100cm`, `SMAvail_0_200cm` | float | % | Soil moisture availability |
| `RootMoist` | float | kg/m2 | Root zone soil moisture |
| `Evap` | float | kg/m2 | Total evapotranspiration |
| `Qs`, `Qsb` | float | kg/m2 | Surface runoff, subsurface runoff |
| `SoilT_0_10cm` ... | float | K | Soil temperature per layer |
| `SWE`, `SnowDepth` | float | kg/m2, m | Snow water equivalent, snow depth |

GLDAS_NOAH025_3H 2.1 (selected):

| Field | Type | Unit | Description |
|---|---|---|---|
| `SoilMoi0_10cm_inst`, `SoilMoi10_40cm_inst`, `SoilMoi40_100cm_inst`, `SoilMoi100_200cm_inst` | float | kg/m2 | Soil moisture per layer, instantaneous |
| `RootMoist_inst` | float | kg/m2 | Root zone soil moisture |
| `Rainf_f_tavg` | float | kg/m2/s | Total precipitation rate, 3 h average |
| `Evap_tavg`, `PotEvap_tavg` | float | kg/m2/s, W/m2 | Evapotranspiration, potential evaporation |
| `Tair_f_inst` | float | K | Air temperature |
| `Qs_acc`, `Qsb_acc` | float | kg/m2 | Storm surface / baseflow runoff accumulated over 3 h |

Fill value: `_FillValue` attribute in each file (GLDAS-2 and NLDAS v2.0 netCDF use `-9999` per their READMEs). Units differ between NLDAS (hourly totals in kg/m2) and GLDAS (rates in kg/m2/s for `_tavg` fluxes).

## Notes

- Hydrology Data Rods (`https://hydro1.gesdisc.eosdis.nasa.gov/daac-bin/access/timeseries.cgi?...`) on 2026-11-14 redirected (HTTP 200 after redirect) to the GES DISC alert page "The Hydrology Data Rods service will be discontinued no earlier than October 31, 2025 and transitioned to a new data access method". No data returned.
- The alert names the replacements: the Hydrology Time Series web tool (point time series plot plus PNG/CSV export, no login needed for the UI) and the Giovanni in the Cloud Time Series Service API. Supported collections listed: GLDAS_NOAH025_3H 2.0 and 2.1, GPM_3IMERGHH 07, GRACEDADM_CLSM0125US_7D 4.0, MERRA-2 M2I1NXLFO/M2T1NXFLX/M2T1NXLFO/M2T1NXSLV 5.12.4, NLDAS_FORA0125_H/NLDAS_MOS0125_H/NLDAS_NOAH0125_H/NLDAS_VIC0125_H 2.0, SMERGE_RZSM0_40CM 2.0.
- The old on-premises OPeNDAP path returned HTTP 410 Gone on 2026-11-14, both for a granule (`https://hydro1.gesdisc.eosdis.nasa.gov/opendap/NLDAS/NLDAS_FORA0125_H.2.0/2025/182/NLDAS_FORA.A20250701.0000.020.nc.html`) and for the root `https://hydro1.gesdisc.eosdis.nasa.gov/opendap/`. A GES DISC alert dated 2026-06-16 states OPeNDAP for 27 hydrology collections was migrated to Earthdata Cloud (June 10 to 17, 2026). The replacement is Cloud OPeNDAP at `opendap.earthdata.nasa.gov`, whose links appear in CMR granule records.
- Cloud OPeNDAP differences (from the "OPeNDAP In The Cloud" how-to): URLs use the CMR collection concept ID and granule UR instead of directory paths; directory/THREDDS catalogs are not available; DAP4 constraint syntax `.dap.nc4?dap4.ce=/VAR1;/VAR2` replaces `.nc4?VAR1,VAR2`.
- The `hydro1.gesdisc.eosdis.nasa.gov/data/` directory listing still loaded on 2026-11-14 and showed the banner "Access to this server (and all other GES DISC data servers) will end no earlier than September 30th 2026"; downloading a file from it without credentials returned HTTP 401 from Earthdata Login.
- Giovanni time series API without a token: `https://api.giovanni.earthdata.nasa.gov/timeseries?...` returned HTTP 403 with body `{"code": "401", "message": "Bad or missing token", ...}`; `/proxy-timeseries` redirected to the Earthdata Login page; the API root returned HTTP 403 `{"message":"Missing Authentication Token"}`. The time series sample above is therefore Representative.
- Cloud OPeNDAP without credentials (tested on a GRACEDADM granule `.dmr.xml`) redirected to Earthdata Login and returned HTTP 401.
- GES DISC alerts (2025-11-10 and 2026-04-02) reported spurious blocks of zeros in Cloud Giovanni time series for GLDAS_NOAH025_3H 2.1, NLDAS FORA/NOAH/MOS/VIC 2.0, several MERRA-2 collections and GRACEDADM_CLSM0125US 4 for data up to 2024-01-01; the 2026-04-02 alert states the bug was fixed as of 2026-03-26.
- NLDAS version 002 (GRIB-1) files stopped updating after 2024-08-01 23Z; the netCDF v2.0 collections are the continuing ones.
- NLDAS file times are UTC; the hourly file labelled `0000` is the hour starting at 00Z.

## Documentation

- NLDAS-2 forcing dataset page: https://disc.gsfc.nasa.gov/datasets/NLDAS_FORA0125_H_2.0/summary
- NLDAS-2 Noah dataset page: https://disc.gsfc.nasa.gov/datasets/NLDAS_NOAH0125_H_2.0/summary
- GLDAS-2.1 Noah 3-hourly: https://disc.gsfc.nasa.gov/datasets/GLDAS_NOAH025_3H_2.1/summary
- GES DISC alerts (JSON): https://disc.gsfc.nasa.gov/api/alerts
- Giovanni In The Cloud: Time Series Service: https://disc.gsfc.nasa.gov/information/howto?title=Giovanni%20In%20The%20Cloud:%20Time%20Series%20Service
- OPeNDAP In The Cloud: https://disc.gsfc.nasa.gov/information/howto?title=OPeNDAP%20In%20The%20Cloud
- Hydrology Time Series User Guide: https://disc.gsfc.nasa.gov/information/documents?title=Hydrology%20Time%20Series%20User%20Guide
- LDAS project: https://ldas.gsfc.nasa.gov/
- Earthdata Login: https://urs.earthdata.nasa.gov
