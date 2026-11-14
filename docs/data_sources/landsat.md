# Landsat Collection 2 (USGS)

Landsat is the joint NASA/USGS Earth-observation satellite series. Landsat 8 (OLI/TIRS, since 2013) and Landsat 9 (OLI-2/TIRS-2, since 2021) each revisit a WRS-2 path/row every 16 days (8 days combined). USGS Collection 2 Level-2 Science Products provide surface reflectance (SR, 30 m, bands B1-B7) and surface temperature (ST, band B10 resampled to 30 m), with per-pixel quality bands (QA_PIXEL, QA_RADSAT, SR_QA_AEROSOL). Level-2 scenes are typically available within days of acquisition (Tier 1 after final processing). The archive extends back to Landsat 4/5 TM (1982) and Landsat 7 ETM+ (1999). Access routes: USGS EarthExplorer (web, login for download), the USGS Machine-to-Machine (M2M) API (login token), the USGS LandsatLook STAC server (open search, open HTTPS asset links, requester-pays S3), and Microsoft Planetary Computer (open STAC search, signed Azure blob assets).

| | |
|---|---|
| Provider | U.S. Geological Survey (EROS) / NASA |
| Base URL | LandsatLook STAC: `https://landsatlook.usgs.gov/stac-server` ; Planetary Computer STAC: `https://planetarycomputer.microsoft.com/api/stac/v1` ; M2M: `https://m2m.cr.usgs.gov/api/api/json/stable/` ; EarthExplorer: `https://earthexplorer.usgs.gov/` |
| Auth | none for STAC search; M2M and EarthExplorer downloads need a USGS ERS account (https://ers.cr.usgs.gov/) and, for M2M, an application token; Planetary Computer assets need an anonymous SAS token; LandsatLook S3 alternate is requester-pays |
| Formats | STAC GeoJSON, Cloud Optimized GeoTIFF, MTL metadata (JSON/TXT/XML), JPEG browse |
| Coverage | Global land; reference point is WRS-2 path 029, rows 031 and 032 |
| Resolution | 30 m reflectance; thermal acquired at 100 m, delivered at 30 m |
| Cadence / latency | 16-day repeat per satellite; Level-2 product generated after acquisition (the captured 2025-07-29 scene was processed 2025-08-07) |
| Rate limits / quotas | not published for STAC; M2M limits are listed in its (login-only) documentation |
| Documentation | https://www.usgs.gov/landsat-missions/landsat-collection-2-level-2-science-products , https://landsatlook.usgs.gov/stac-server , https://m2m.cr.usgs.gov/ |

## Requests

### LandsatLook STAC search

Returns STAC items for Collection 2 scenes. Collections include `landsat-c2l2-sr` (surface reflectance), `landsat-c2l2-st` (surface temperature), `landsat-c2l1` (Level-1).

| Parameter | Required | Description | Example |
|---|---|---|---|
| `collections` | yes | Collection IDs | `["landsat-c2l2-sr"]` |
| `intersects` | one of `intersects`/`bbox` | GeoJSON geometry | `{"type":"Point","coordinates":[-97.5,40.95]}` |
| `bbox` | one of `intersects`/`bbox` | `[minx,miny,maxx,maxy]` | `[-97.51,40.94,-97.49,40.96]` |
| `datetime` | no | RFC 3339 interval | `2025-07-01T00:00:00Z/2025-07-31T23:59:59Z` |
| `query` | no | Property filter (query extension) | `{"eo:cloud_cover":{"lt":20}}`, `{"platform":{"in":["LANDSAT_8","LANDSAT_9"]}}` |
| `limit` | no | Page size | `5` |
| `next` | no | Paging key from the `next` link body | (from response) |

```
POST https://landsatlook.usgs.gov/stac-server/search
Content-Type: application/json

{"collections":["landsat-c2l2-sr"],
 "intersects":{"type":"Point","coordinates":[-97.5,40.95]},
 "datetime":"2025-07-01T00:00:00Z/2025-07-31T23:59:59Z",
 "query":{"eo:cloud_cover":{"lt":20}},
 "limit":5}
```

### Sample response (Captured 2026-11-14)

Trimmed: 4 of 5 features removed (listed below); in the kept feature, asset hrefs other than `red` and `qa_pixel` shortened to file names, `file:checksum` removed except on `red`, `qa_pixel` bitfields 2-7 and 10-15 removed (all listed in Fields), `qa_radsat` bitfields removed, `geometry` removed.

```json
{
  "type": "FeatureCollection",
  "numberMatched": 5,
  "numberReturned": 5,
  "features": [{
    "type": "Feature",
    "id": "LC08_L2SP_029032_20250729_20250807_02_T1_SR",
    "collection": "landsat-c2l2-sr",
    "bbox": [-99.37325165695276, 39.269620544917906, -96.69527210757502, 41.38353647634209],
    "properties": {
      "datetime": "2025-07-29T17:12:27.726722Z",
      "eo:cloud_cover": 0.52,
      "view:sun_azimuth": 133.29194071,
      "view:sun_elevation": 61.42199247,
      "platform": "LANDSAT_8",
      "instruments": ["OLI", "TIRS"],
      "view:off_nadir": 0,
      "landsat:cloud_cover_land": 0.52,
      "landsat:wrs_type": "2",
      "landsat:wrs_path": "029",
      "landsat:wrs_row": "032",
      "landsat:scene_id": "LC80290322025210LGN00",
      "landsat:collection_category": "T1",
      "landsat:collection_number": "02",
      "landsat:correction": "L2SP",
      "accuracy:geometric_x_bias": 0,
      "accuracy:geometric_y_bias": 0,
      "accuracy:geometric_x_stddev": 4.867,
      "accuracy:geometric_y_stddev": 4.958,
      "accuracy:geometric_rmse": 6.947,
      "proj:epsg": 32614,
      "proj:shape": [7821, 7691],
      "proj:transform": [30, 0, 466185, 0, -30, 4581915],
      "card4l:specification": "SR",
      "card4l:specification_version": "5.0",
      "created": "2026-01-17T23:17:56.136Z",
      "updated": "2026-02-03T14:47:56.128Z"
    },
    "assets": {
      "thumbnail": {"href": "..._thumb_small.jpeg", "type": "image/jpeg", "roles": ["thumbnail"]},
      "reduced_resolution_browse": {"href": "..._thumb_large.jpeg", "type": "image/jpeg", "roles": ["overview"]},
      "MTL.json": {"href": "..._MTL.json", "type": "application/json", "roles": ["metadata"]},
      "coastal": {"href": "..._SR_B1.TIF", "title": "Coastal/Aerosol Band (B1)"},
      "blue": {"href": "..._SR_B2.TIF", "title": "Blue Band (B2)"},
      "green": {"href": "..._SR_B3.TIF", "title": "Green Band (B3)"},
      "red": {
        "title": "Red Band (B4)",
        "description": "Collection 2 Level-2 Red Band (B4) Surface Reflectance",
        "type": "image/vnd.stac.geotiff; cloud-optimized=true",
        "roles": ["data"],
        "eo:bands": [{"name": "B4", "common_name": "red", "gsd": 30, "center_wavelength": 0.65}],
        "href": "https://landsatlook.usgs.gov/data/collection02/level-2/standard/oli-tirs/2025/029/032/LC08_L2SP_029032_20250729_20250807_02_T1/LC08_L2SP_029032_20250729_20250807_02_T1_SR_B4.TIF",
        "alternate": {"s3": {"storage:platform": "AWS", "storage:requester_pays": true,
          "href": "s3://usgs-landsat/collection02/level-2/standard/oli-tirs/2025/029/032/LC08_L2SP_029032_20250729_20250807_02_T1/LC08_L2SP_029032_20250729_20250807_02_T1_SR_B4.TIF"}},
        "file:checksum": "1340a6bf842d604610191db9c7ed7e0998601bed45665e55bab9f0ad86d33713d546fcbe27ada3b4e1232a30e0c9a23cf64d933e1ff6706db963dff36b7fe7d2b049"
      },
      "nir08": {"href": "..._SR_B5.TIF", "title": "Near Infrared Band 0.8 (B5)"},
      "swir16": {"href": "..._SR_B6.TIF", "title": "Short-wave Infrared Band 1.6 (B6)"},
      "swir22": {"href": "..._SR_B7.TIF", "title": "Short-wave Infrared Band 2.2 (B7)"},
      "qa_aerosol": {"href": "..._SR_QA_AEROSOL.TIF", "title": "Aerosol Quality Analysis Band"},
      "qa_pixel": {
        "title": "Pixel Quality Assessment Band",
        "description": "Collection 2 Level-2 Pixel Quality Assessment Band Surface Reflectance",
        "type": "image/vnd.stac.geotiff; cloud-optimized=true",
        "roles": ["cloud", "cloud-shadow", "snow-ice", "water-mask"],
        "href": "https://landsatlook.usgs.gov/data/collection02/level-2/standard/oli-tirs/2025/029/032/LC08_L2SP_029032_20250729_20250807_02_T1/LC08_L2SP_029032_20250729_20250807_02_T1_QA_PIXEL.TIF",
        "classification:bitfields": [
          {"name": "fill", "description": "Corresponding pixels in L1 image bands are fill", "offset": 0, "length": 1,
           "classes": [{"name": "not_fill", "value": 0}, {"name": "fill", "value": 1}]},
          {"name": "dilated", "description": "Dilated cloud", "offset": 1, "length": 1,
           "classes": [{"name": "not_dilated", "value": 0}, {"name": "dilated", "value": 1}]},
          {"name": "cloud_confidence", "description": "Cloud confidence levels", "offset": 8, "length": 2,
           "classes": [{"name": "not_set", "value": 0}, {"name": "low", "value": 1}, {"name": "medium", "value": 2}, {"name": "high", "value": 3}]}
        ]
      },
      "qa_radsat": {"href": "..._QA_RADSAT.TIF", "title": "Radiometric Saturation Quality Assessment Band", "roles": ["saturation"]},
      "ANG.txt": {"href": "..._ANG.txt"}, "MTL.txt": {"href": "..._MTL.txt"}, "MTL.xml": {"href": "..._MTL.xml"}
    },
    "links": [
      {"rel": "self", "href": "https://landsatlook.usgs.gov/stac-server/collections/landsat-c2l2-sr/items/LC08_L2SP_029032_20250729_20250807_02_T1_SR"},
      {"rel": "collection", "href": "https://landsatlook.usgs.gov/stac-server/collections/landsat-c2l2-sr"}
    ]
  }],
  "links": [{"rel": "next", "method": "POST", "href": "https://landsatlook.usgs.gov/stac-server/search",
    "body": {"collections": ["landsat-c2l2-sr"], "limit": 5, "next": "2025-07-05T17:12:18.058872Z,LC09_L2SP_029032_20250705_20250706_02_T1_SR,landsat-c2l2-sr"}}]
}
```

All 5 features (id, datetime, eo:cloud_cover, platform):

```
LC08_L2SP_029032_20250729_20250807_02_T1_SR  2025-07-29T17:12:27.726722Z   0.52  LANDSAT_8
LC08_L2SP_029031_20250729_20250807_02_T1_SR  2025-07-29T17:12:03.839918Z  15.12  LANDSAT_8
LC08_L2SP_029032_20250713_20250726_02_T1_SR  2025-07-13T17:12:23.037662Z   0.29  LANDSAT_8
LC08_L2SP_029031_20250713_20250726_02_T1_SR  2025-07-13T17:11:59.150857Z   2.14  LANDSAT_8
LC09_L2SP_029032_20250705_20250706_02_T1_SR  2025-07-05T17:12:18.058872Z   0.08  LANDSAT_9
```

### Planetary Computer STAC search (`landsat-c2-l2`)

Same STAC API search; one item per scene holds both SR and ST assets, with `raster:bands` scale/offset.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `collections` | yes | Collection ID | `["landsat-c2-l2"]` |
| `intersects` / `bbox` | one required | Geometry | `{"type":"Point","coordinates":[-97.5,40.95]}` |
| `datetime` | no | RFC 3339 interval | `2025-07-01T00:00:00Z/2025-07-31T23:59:59Z` |
| `query` | no | Property filter | `{"eo:cloud_cover":{"lt":20},"platform":{"in":["landsat-8","landsat-9"]}}` |
| `limit` | no | Page size | `5` |

```
POST https://planetarycomputer.microsoft.com/api/stac/v1/search
Content-Type: application/json

{"collections":["landsat-c2-l2"],
 "intersects":{"type":"Point","coordinates":[-97.5,40.95]},
 "datetime":"2025-07-01T00:00:00Z/2025-07-31T23:59:59Z",
 "query":{"eo:cloud_cover":{"lt":20}},
 "limit":5}
```

### Sample response (Captured 2026-11-14)

Trimmed to one feature's `id`, `properties`, and three assets (`red`, `lwir11`, `qa_pixel`); hrefs kept. The same five scenes were returned as from LandsatLook, with IDs without processing date and `_SR` suffix (e.g. `LC08_L2SP_029032_20250729_02_T1`).

```json
{
  "id": "LC08_L2SP_029032_20250729_02_T1",
  "collection": "landsat-c2-l2",
  "properties": {
    "gsd": 30,
    "created": "2025-08-12T09:15:24.084295Z",
    "sci:doi": "10.5066/P9OGBGM6",
    "datetime": "2025-07-29T17:12:27.726722Z",
    "platform": "landsat-8",
    "proj:epsg": 32614,
    "description": "Landsat Collection 2 Level-2",
    "instruments": ["oli", "tirs"],
    "eo:cloud_cover": 0.52,
    "view:off_nadir": 0,
    "landsat:wrs_row": "032",
    "landsat:scene_id": "LC80290322025210LGN00",
    "landsat:wrs_path": "029",
    "landsat:wrs_type": "2",
    "view:sun_azimuth": 133.29194071,
    "landsat:correction": "L2SP",
    "view:sun_elevation": 61.42199247,
    "landsat:cloud_cover_land": 0.52,
    "landsat:collection_number": "02",
    "landsat:collection_category": "T1"
  },
  "assets": {
    "red": {
      "href": "https://landsateuwest.blob.core.windows.net/landsat-c2/level-2/standard/oli-tirs/2025/029/032/LC08_L2SP_029032_20250729_20250807_02_T1/LC08_L2SP_029032_20250729_20250807_02_T1_SR_B4.TIF",
      "eo:bands": [{"name": "OLI_B4", "center_wavelength": 0.65, "full_width_half_max": 0.04, "common_name": "red", "description": "Visible red"}],
      "title": "Red Band",
      "roles": ["data", "reflectance"],
      "raster:bands": [{"scale": 2.75e-05, "nodata": 0, "offset": -0.2, "data_type": "uint16", "spatial_resolution": 30}]
    },
    "lwir11": {
      "href": "https://landsateuwest.blob.core.windows.net/landsat-c2/level-2/standard/oli-tirs/2025/029/032/LC08_L2SP_029032_20250729_20250807_02_T1/LC08_L2SP_029032_20250729_20250807_02_T1_ST_B10.TIF",
      "gsd": 100,
      "title": "Surface Temperature Band",
      "roles": ["data", "temperature"],
      "raster:bands": [{"unit": "kelvin", "scale": 0.00341802, "nodata": 0, "offset": 149, "data_type": "uint16", "spatial_resolution": 30}]
    },
    "qa_pixel": {
      "title": "Pixel Quality Assessment Band",
      "raster:bands": [{"unit": "bit index", "nodata": 1, "data_type": "uint16", "spatial_resolution": 30}]
    }
  }
}
```

Planetary Computer asset keys for an OLI/TIRS L2 item: `coastal`, `blue`, `green`, `red`, `nir08`, `swir16`, `swir22`, `lwir11`, `qa_pixel`, `qa_radsat`, `qa_aerosol`, `qa` (ST QA, kelvin, scale 0.01), `atran`, `cdist` (km, scale 0.01), `drad`, `urad`, `trad` (scale 0.001), `emis`, `emsd` (scale 0.0001), `ang`, `mtl.txt`, `mtl.xml`, `mtl.json`, `tilejson`, `rendered_preview`.

### USGS M2M API: login-token

Exchanges an ERS username and application token for an API key used in the `X-Auth-Token` header of later calls.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `username` | yes | ERS username | `<ers_username>` |
| `token` | yes | Application token generated in ERS (scope "M2M API") | `<application_token>` |

```
POST https://m2m.cr.usgs.gov/api/api/json/stable/login-token
Content-Type: application/json

{"username": "<ers_username>", "token": "<application_token>"}
```

### Sample response (Representative)

From the "M2M Application Token Documentation" (USGS, 2025-02-11): the API key is returned as `data`; `errorCode`/`errorMessage` are checked by the sample scripts. Other wrapper keys follow the M2M JSON response envelope.

```json
{"requestId": 123456789, "version": "stable", "data": "<api_key>", "errorCode": null, "errorMessage": null}
```

### USGS M2M API: scene-search

Searches a dataset by area, date and cloud cover; returns entity IDs used for `download-options` / `download-request`.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `X-Auth-Token` (header) | yes | API key from `login-token` | `<api_key>` |
| `datasetName` | yes | Dataset alias | `landsat_ot_c2_l2` (Landsat 8-9 OLI/TIRS C2 L2) |
| `sceneFilter.spatialFilter` | no | `{"filterType":"mbr","lowerLeft":{...},"upperRight":{...}}` or `{"filterType":"geojson","geoJson":{...}}` | see request |
| `sceneFilter.acquisitionFilter` | no | `{"start":"YYYY-MM-DD","end":"YYYY-MM-DD"}` | `{"start":"2025-07-01","end":"2025-07-31"}` |
| `sceneFilter.cloudCoverFilter` | no | `{"min":0,"max":20,"includeUnknown":false}` | see request |
| `maxResults` | no | Page size | `5` |
| `startingNumber` | no | 1-based offset for paging | `1` |

```
POST https://m2m.cr.usgs.gov/api/api/json/stable/scene-search
Content-Type: application/json
X-Auth-Token: <api_key>

{"datasetName": "landsat_ot_c2_l2",
 "maxResults": 5,
 "sceneFilter": {
   "spatialFilter": {"filterType": "mbr",
                     "lowerLeft": {"latitude": 40.94, "longitude": -97.51},
                     "upperRight": {"latitude": 40.96, "longitude": -97.49}},
   "acquisitionFilter": {"start": "2025-07-01", "end": "2025-07-31"},
   "cloudCoverFilter": {"min": 0, "max": 20, "includeUnknown": false}}}
```

### Sample response (Representative)

Built from the M2M JSON API reference structure; the scene values are copied from the captured STAC item for the same acquisition. Not captured (see Notes).

```json
{
  "requestId": 123456790,
  "version": "stable",
  "data": {
    "results": [{
      "entityId": "LC80290322025210LGN00",
      "displayId": "LC08_L2SP_029032_20250729_20250807_02_T1",
      "cloudCover": "0.52",
      "publishDate": "2025-08-07 00:00:00-05",
      "temporalCoverage": {"startDate": "2025-07-29 00:00:00-05", "endDate": "2025-07-29 00:00:00-05"},
      "spatialCoverage": {"type": "Polygon", "coordinates": [[[-99.37, 39.27], [-96.70, 39.27], [-96.70, 41.38], [-99.37, 41.38], [-99.37, 39.27]]]},
      "browse": [{"browsePath": "<url>", "thumbnailPath": "<url>"}],
      "options": {"bulk": true, "download": true, "order": false, "secondary": false}
    }],
    "recordsReturned": 1,
    "totalHits": 1,
    "startingNumber": 1,
    "nextRecord": 2
  },
  "errorCode": null,
  "errorMessage": null
}
```

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `id` | string | | LandsatLook: `<product id>_SR`; Planetary Computer: `LXSS_L2SP_PPPRRR_YYYYMMDD_CC_TX` |
| `properties.datetime` | string | UTC | Scene centre acquisition time |
| `properties.eo:cloud_cover` | number | % | Scene cloud cover |
| `properties.landsat:cloud_cover_land` | number | % | Cloud cover over land |
| `properties.platform` | string | | `LANDSAT_8` / `LANDSAT_9` (LandsatLook), `landsat-8` / `landsat-9` (Planetary Computer) |
| `properties.landsat:wrs_path`, `landsat:wrs_row` | string | | WRS-2 path and row |
| `properties.landsat:collection_category` | string | | `T1` Tier 1, `T2` Tier 2, `RT` real-time |
| `properties.landsat:correction` | string | | `L2SP` = SR and ST; `L2SR` = SR only |
| `properties.landsat:scene_id` | string | | Legacy scene ID (also M2M `entityId`) |
| `properties.view:sun_elevation`, `view:sun_azimuth` | number | degrees | Solar angles at scene centre |
| `properties.proj:epsg` | integer | | UTM zone EPSG (32614 = UTM 14N) |
| `accuracy:geometric_rmse` | number | m | Geometric accuracy (LandsatLook only) |
| SR bands B1-B7 (`coastal` 0.44, `blue` 0.48, `green` 0.56, `red` 0.65, `nir08` 0.86, `swir16` 1.6, `swir22` 2.2 um) | uint16 | reflectance after scaling | reflectance = DN x 0.0000275 - 0.2; nodata 0 |
| ST band B10 (`lwir11`) | uint16 | K after scaling | temperature = DN x 0.00341802 + 149.0; nodata 0 |
| `qa` (ST_QA) | int16 | K | ST uncertainty, scale 0.01, nodata -9999 |
| `qa_aerosol` | uint8 | bit flags | SR aerosol QA |
| `qa_radsat` | uint16 | bit flags | Bit n = band n saturated (bitfields `band1`...) |

QA_PIXEL bits (from the captured `classification:bitfields`):

| Bit(s) | Name | Values |
|---|---|---|
| 0 | fill | 0 not fill, 1 fill |
| 1 | dilated | 0 not dilated, 1 dilated cloud |
| 2 | cirrus | 0 no/low confidence cirrus, 1 high confidence cirrus |
| 3 | cloud | 0 not high confidence, 1 high confidence cloud |
| 4 | shadow | 0 not high confidence, 1 high confidence cloud shadow |
| 5 | snow | 0 not high confidence, 1 high confidence snow/ice |
| 6 | clear | 0 cloud or dilated cloud bits set, 1 cloud and dilated cloud bits not set |
| 7 | water | 0 land or cloud, 1 water |
| 8-9 | cloud_confidence | 0 not set, 1 low, 2 medium, 3 high |
| 10-11 | shadow_confidence | 0 not set, 1 low, 2 reserved, 3 high |
| 12-13 | snow_confidence | 0 not set, 1 low, 2 reserved, 3 high |
| 14-15 | cirrus_confidence | 0 not set, 1 low, 2 reserved, 3 high |

Planetary Computer declares QA_PIXEL `nodata: 1` (the fill bit). M2M `cloudCover` is returned as a string in the representative shape.

## Notes

- The reference point is covered by two WRS-2 rows (029/031 and 029/032) on the same overpass; scene-level `eo:cloud_cover` differs per row (0.52 vs 15.12 on 2025-07-29).
- Scale factors are not applied in the files; the Planetary Computer item carries them in `raster:bands`, LandsatLook items do not (they are in the MTL file and the USGS Level-2 product guide).
- LandsatLook HTTPS hrefs (`https://landsatlook.usgs.gov/data/...`) and Planetary Computer blob hrefs point to the same file names; the LandsatLook S3 alternate (`s3://usgs-landsat/...`) is marked `storage:requester_pays: true`.
- The LandsatLook item `created`/`updated` dates (2026) reflect catalogue reprocessing, not acquisition.
- Failure: the M2M documentation pages (`https://m2m.cr.usgs.gov/api/docs/json/`, `/api/docs/reference/`) redirect to the ERS login page; an unauthenticated `POST https://m2m.cr.usgs.gov/api/api/json/stable/dataset-search` returned HTTP 403 (HTML "403 - Forbidden" page). M2M samples are Representative; no credentials were used. The M2M token document states the password-based `login` endpoint was deprecated on 2025-02-26 in favour of `login-token`.
- EarthExplorer (`https://earthexplorer.usgs.gov/`) is a web UI; search is open, downloads require ERS login.

## Documentation

- Landsat Collection 2 Level-2 Science Products: https://www.usgs.gov/landsat-missions/landsat-collection-2-level-2-science-products
- Landsat 8-9 Collection 2 Level-2 Science Product Guide (LSDS-1619): https://www.usgs.gov/media/files/landsat-8-9-collection-2-level-2-science-product-guide
- Landsat Collection 2 QA bands: https://www.usgs.gov/landsat-missions/landsat-collection-2-quality-assessment-bands
- LandsatLook STAC server: https://landsatlook.usgs.gov/stac-server
- Planetary Computer landsat-c2-l2: https://planetarycomputer.microsoft.com/dataset/landsat-c2-l2
- M2M API: https://m2m.cr.usgs.gov/ ; token guide: https://www.usgs.gov/media/files/m2m-application-token-documentation
- ERS registration: https://ers.cr.usgs.gov/
- DOI (Collection 2 Level-2): https://doi.org/10.5066/P9OGBGM6
- Landsat data are public domain (USGS).
