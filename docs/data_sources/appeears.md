# NASA AppEEARS (access layer)

Application for Extracting and Exploring Analysis Ready Samples. One API that extracts values at points (or areas) from 193 NASA and USGS products, applies scale factors, decodes quality bits, and returns CSV. Products available include **SMAP, MODIS, ECOSTRESS, HLS (Landsat + Sentinel-2), SRTM/NASADEM and Daymet**; values are returned without downloading the source HDF5 or GeoTIFF files.

The datasets themselves are documented in `smap.md`, `vegetation_indices.md`, `ecostress.md` and `terrain.md`. This file covers the request lifecycle that all of them share.

| | |
|---|---|
| Base URL | `https://appeears.earthdatacloud.nasa.gov/api` |
| Auth | Earthdata username and password (`EARTHDATA_USERNAME`, `EARTHDATA_PASSWORD`) exchanged for a bearer token (48 h) |
| Model | asynchronous: submit a task, poll its status, download the bundle |
| Typical wait | 2-15 minutes for one point and a year of 4-5 layers; longer when the queue is busy |
| Public endpoints (no token) | `GET /product`, `GET /product/{ProductAndVersion}` (catalog and layer metadata) |
| Docs | https://appeears.earthdatacloud.nasa.gov/api/ |

Requests are asynchronous: submit a task, poll its status, then download the result files.

## 1. Log in

```
POST /api/login
Authorization: Basic base64(EARTHDATA_USERNAME:EARTHDATA_PASSWORD)
Content-Length: 0
```

Representative response:

```json
{ "token_type": "Bearer", "token": "kJ9x...redacted...Qw", "expiration": "2026-11-16T21:50:12Z" }
```

The token is valid until `expiration`; `POST /api/logout` revokes it.

## 2. Submit a point task

```
POST /api/task
Authorization: Bearer <token>
Content-Type: application/json
```

```json
{
  "task_type": "point",
  "task_name": "field-1842-2025",
  "params": {
    "dates": [{ "startDate": "01-01-2025", "endDate": "10-31-2025" }],
    "layers": [
      { "product": "SPL3SMP_E.006",   "layer": "Soil_Moisture_Retrieval_Data_AM_soil_moisture" },
      { "product": "SPL4SMGP.008",    "layer": "Geophysical_Data_sm_rootzone" },
      { "product": "SPL4SMGP.008",    "layer": "Geophysical_Data_sm_rootzone_pctl" },
      { "product": "MOD13Q1.061",     "layer": "_250m_16_days_NDVI" },
      { "product": "MOD16A2GF.061",   "layer": "ET_500m" },
      { "product": "MOD16A2GF.061",   "layer": "PET_500m" },
      { "product": "ECO_L3T_JET.002", "layer": "ETdaily" },
      { "product": "ECO_L2T_LSTE.002","layer": "LST" }
    ],
    "coordinates": [
      { "id": "field-1842", "category": "York NE", "latitude": 40.95, "longitude": -97.50 }
    ]
  }
}
```

Dates are `MM-DD-YYYY`. Add `"recurring": true, "yearRange": [2016, 2025]` to a date entry to get the same window across many years (useful for "this year vs. normal" NDVI). Many fields can share one task: add one `coordinates` entry per field; `id` comes back in every CSV row.

Representative response: `{ "task_id": "3f6b2c1e-8a4d-4c55-9a77-1f0e2b7d9c10", "status": "pending" }`

## 3. Poll

```
GET /api/task/{task_id}         # full record, including "status"
GET /api/status/{task_id}       # lighter: progress while processing
```

Statuses: `pending` → `queued` → `processing` → `done` (or `error`). Representative:

```json
{ "task_id": "3f6b2c1e-...", "status": "processing", "progress": { "summary": 62 }, "updated": "2026-11-14T22:03:41.118Z" }
```

## 4. List and download the bundle

```
GET /api/bundle/{task_id}
```

Representative response:

```json
{
  "task_id": "3f6b2c1e-...",
  "files": [
    { "file_id": "a1...", "file_name": "field-1842-2025-SPL3SMP-E-006-results.csv",  "file_type": "csv",  "file_size": 41822 },
    { "file_id": "b2...", "file_name": "field-1842-2025-SPL4SMGP-008-results.csv",   "file_type": "csv",  "file_size": 88140 },
    { "file_id": "c3...", "file_name": "field-1842-2025-MOD13Q1-061-results.csv",    "file_type": "csv",  "file_size": 9210 },
    { "file_id": "d4...", "file_name": "field-1842-2025-MOD16A2GF-061-results.csv",  "file_type": "csv",  "file_size": 12904 },
    { "file_id": "e5...", "file_name": "field-1842-2025-ECO-L3T-JET-002-results.csv","file_type": "csv",  "file_size": 6031 },
    { "file_id": "f6...", "file_name": "field-1842-2025-ECO-L2T-LSTE-002-results.csv","file_type": "csv", "file_size": 7712 },
    { "file_id": "g7...", "file_name": "field-1842-2025-granule-list.txt",           "file_type": "txt",  "file_size": 30212 },
    { "file_id": "h8...", "file_name": "field-1842-2025-request.json",               "file_type": "json", "file_size": 1180 },
    { "file_id": "i9...", "file_name": "field-1842-2025-README.md",                  "file_type": "txt",  "file_size": 18765 }
  ]
}
```

```
GET /api/bundle/{task_id}/{file_id}      # follows a redirect to the file
```

There is **one results CSV per product**. `request.json` echoes the submitted task and `granule-list.txt` lists the source granules used.

## Results CSV shape

Every product CSV shares leading columns, then per-layer value columns named `{PRODUCT}_{VERSION}_{layer}`, then decoded QA columns. Values are **already scaled** (NDVI comes back as 0.82, not 8200).

```
ID,Category,Latitude,Longitude,Date,MODIS_Tile,MOD13Q1_061_Line_Y_250m,MOD13Q1_061_Sample_X_250m,MOD13Q1_061__250m_16_days_NDVI,MOD13Q1_061__250m_16_days_VI_Quality,MOD13Q1_061__250m_16_days_VI_Quality_MODLAND_Description,MOD13Q1_061__250m_16_days_VI_Quality_VI_Usefulness_Description,...
field-1842,York NE,40.95,-97.5,2025-07-12,h10v04,1650,1240,0.8714,2116,VI produced with good quality,Highest quality,...
```

Each value column may be followed by decoded QA columns ending in `_Description` (the quality strings per product are listed in each dataset file).

## Products in the catalog (selection)

Captured from `GET /api/product` on 2026-11-14 (193 products in total; platforms include SMAP, Terra/Aqua/Combined MODIS, Suomi NPP / NOAA-20 / NOAA-21 VIIRS, ECOSTRESS, HLS, Landsat ARD, SRTM, NASADEM, ASTER GDEM, Daymet, EMIT).

| ProductAndVersion | Description | Resolution | Cadence | Since |
|---|---|---|---|---|
| `SPL3SMP_E.006` | Enhanced L3 Radiometer Soil Moisture | 9 km | daily | 2015-03-31 |
| `SPL4SMGP.008` | Surface and Root Zone Soil Moisture (model + SMAP) | 9 km | 3-hourly (daily in point output) | 2015-03-31 |
| `MOD13Q1.061` | Vegetation Indices (NDVI and EVI) | 250 m | 16 day | 2000-02-18 |
| `MOD16A2GF.061` | Net Evapotranspiration Gap-Filled (ET and PET) | 500 m | 8 day | 2000-01-01 |
| `MOD11A2.061` | Land Surface Temperature and Emissivity | 1 km | 8 day | 2000-02-18 |
| `ECO_L3T_JET.002` | ECOSTRESS evapotranspiration, instantaneous and daytime | 70 m | ISS-dependent | 2018-07-10 |
| `ECO_L2T_LSTE.002` | ECOSTRESS land surface temperature and emissivity | 70 m | ISS-dependent | 2018-07-09 |
| `HLSL30.020` / `HLSS30.020` | Harmonized Landsat / Sentinel-2 surface reflectance | 30 m | 2-3 days combined | 2013-04-11 (L30), 2015-11-28 (S30) |
| `HLSL30_VI.020` / `HLSS30_VI.020` | Same, with NDVI/EVI and other indices precomputed | 30 m | 2-3 days combined | as above |
| `MCD15A3H.061` | Leaf Area Index and FPAR | 500 m | 4 day | 2002-07-04 |
| `MCD12Q2.061` | Land Cover Dynamics (green-up, peak, senescence dates) | 500 m | yearly | 2001 |
| `SRTMGL1_NC.003`, `NASADEM_NC.001` | Elevation | 30 m | static | 2000-02-11 |
| `DAYMET.004` | Daily surface weather for North America | 1 km | daily | 1950-01-01 |

## Errors

| Status | Meaning | Notes |
|---|---|---|
| 401 on `/login` | wrong Earthdata credentials | |
| 400 on `/task` | bad product/layer name or date format | the response `message` names the problem; valid names come from `GET /product/{id}` |
| 429 | too many requests | |
| task `error` | upstream processing failed | |

## Documentation

- API reference: https://appeears.earthdatacloud.nasa.gov/api/
- User guide: https://appeears.earthdatacloud.nasa.gov/help
- Product list: https://appeears.earthdatacloud.nasa.gov/products
