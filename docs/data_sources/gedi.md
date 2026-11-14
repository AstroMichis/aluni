# GEDI (Global Ecosystem Dynamics Investigation) canopy and biomass

GEDI is a NASA full-waveform lidar on the International Space Station that samples vegetation structure in footprints of about 25 m diameter along 8 ground tracks (4 full-power, 4 coverage beams), between about 51.6 N and 51.6 S. It does not map wall to wall: footprints are spaced about 60 m along track and tracks about 600 m apart. Footprint products are delivered per orbit segment in HDF5: L2A (ground elevation and relative height metrics, LP DAAC), L2B (canopy cover, plant area index, vertical profiles, LP DAAC), L4A (aboveground biomass density per footprint, ORNL DAAC). L4B is a 1 km gridded mean biomass product (ORNL DAAC). CMR lists L2A/L2B/L4A granules from April 2019 to July 2025 and L4B from April 2019 to March 2023 (version 2.1).

| | |
|---|---|
| Provider | NASA; University of Maryland science team; distributed by LP DAAC (L1B, L2A, L2B) and ORNL DAAC (L4A, L4B, L4C) |
| Base URL | CMR search: `https://cmr.earthdata.nasa.gov/search/` ; data: `https://data.lpdaac.earthdatacloud.nasa.gov/` , `https://data.ornldaac.earthdata.nasa.gov/` ; subsetter: NASA MAAP DPS (`api.maap-project.org`) |
| Auth | none for CMR search; NASA Earthdata Login (https://urs.earthdata.nasa.gov/) for file download; MAAP account for the GEDI Subsetter |
| Formats | HDF5 (footprint products), GeoTIFF (L4B), JSON/UMM/ECHO10 (CMR); subsetter output GeoPackage, FlatGeobuf or GeoParquet |
| Coverage | about 51.6 N to 51.6 S; the reference point (40.95 N) is inside |
| Resolution | about 25 m footprints (L2A/L2B/L4A); 1 km grid (L4B) |
| Cadence / latency | irregular sampling; repeat footprints at a given field are not guaranteed |
| Rate limits / quotas | CMR: not published for anonymous search (page size max 2000); DAAC downloads: not published |
| Documentation | https://daac.ornl.gov/GEDI/guides/GEDI_L4A_AGB_Density_V2_1.html , https://lpdaac.usgs.gov/products/gedi02_av002/ , https://cmr.earthdata.nasa.gov/search/site/docs/search/api.html |

Collections (from CMR, captured 2026-11-14):

| Product | short_name / version | Concept ID | DAAC | time_start | time_end |
|---|---|---|---|---|---|
| L2A Elevation and Height Metrics | `GEDI02_A` / `002` | `C2142771958-LPCLOUD` | LPCLOUD | 2019-04-04 | 2025-07-10 |
| L2B Canopy Cover and Vertical Profile | `GEDI02_B` / `002` | `C2142776747-LPCLOUD` | LPCLOUD | 2019-04-04 | 2025-07-10 |
| L4A Footprint Aboveground Biomass Density | `GEDI_L4A_AGB_Density_V2_1_2056` / `2.1` | `C2237824918-ORNL_CLOUD` | ORNL_CLOUD | 2019-04-17 | 2025-07-09 |
| L4B Gridded Aboveground Biomass Density | `GEDI_L4B_Gridded_Biomass_V2_1_2299` / `2.1` | `C2792577683-ORNL_CLOUD` | ORNL_CLOUD | 2019-04-18 | 2023-03-16 |

## Requests

### CMR granule search

Returns granule (file) records whose spatial extent intersects a box or point.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `short_name` | one of `short_name`/`collection_concept_id` | Collection short name | `GEDI02_A` |
| `version` | no | Collection version | `002` |
| `collection_concept_id` | one of `short_name`/`collection_concept_id` | Concept ID | `C2237824918-ORNL_CLOUD` |
| `bounding_box` | no | `W,S,E,N` | `-97.52,40.93,-97.48,40.97` |
| `point` | no | `lon,lat` | `-97.5,40.95` |
| `temporal` | no | `start,end` ISO 8601 | `2024-01-01T00:00:00Z,2024-12-31T23:59:59Z` |
| `page_size` | no | Results per page (max 2000) | `5` |
| `page_num` | no | Page number | `1` |
| `sort_key` | no | Sort; `-` prefix for descending | `-start_date` |

```
GET https://cmr.earthdata.nasa.gov/search/granules.json
  ?short_name=GEDI02_A&version=002
  &bounding_box=-97.52,40.93,-97.48,40.97
  &temporal=2024-01-01T00:00:00Z,2024-12-31T23:59:59Z
  &page_size=5&sort_key=-start_date
```

### Sample response (Captured 2026-11-14)

Trimmed: 4 of 5 entries removed (listed below); `polygons` coordinate string cut; `links` reduced to data, S3, browse and two inherited links (the entry also has metadata `.cmr.xml` links and an S3 credentials link).

```json
{"feed": {
  "updated": "2026-11-14T23:08:41.588Z",
  "id": "https://cmr.earthdata.nasa.gov:443/search/granules.json?short_name=GEDI02_A&version=002&bounding_box=-97.52,40.93,-97.48,40.97&temporal=2024-01-01T00:00:00Z,2024-12-31T23:59:59Z&page_size=5&sort_key=-start_date",
  "title": "ECHO granule metadata",
  "entry": [{
    "producer_granule_id": "GEDI02_A_2024319004209_O33548_02_T09947_02_004_02_V002",
    "time_start": "2024-11-14T00:42:09.000Z",
    "time_end": "2024-11-14T02:15:00.000Z",
    "updated": "2025-02-05T05:16:08.440Z",
    "orbit_calculated_spatial_domains": [{"start_orbit_number": "33548", "stop_orbit_number": "33548"}],
    "dataset_id": "GEDI L2A Elevation and Height Metrics Data Global Footprint Level V002",
    "data_center": "LPCLOUD",
    "title": "GEDI02_A_2024319004209_O33548_02_T09947_02_004_02_V002",
    "coordinate_system": "GEODETIC",
    "day_night_flag": "UNSPECIFIED",
    "id": "G3394552508-LPCLOUD",
    "original_format": "ECHO10",
    "granule_size": "2160.2",
    "browse_flag": true,
    "polygons": [["11.0565987 -129.0296741 14.0391024 -126.7609916 17.0174969 -124.4251765 ..."]],
    "collection_concept_id": "C2142771958-LPCLOUD",
    "online_access_flag": true,
    "links": [
      {"rel": "http://esipfed.org/ns/fedsearch/1.1/data#", "title": "Download GEDI02_A_2024319004209_O33548_02_T09947_02_004_02_V002.h5",
       "href": "https://data.lpdaac.earthdatacloud.nasa.gov/lp-prod-protected/GEDI02_A.002/GEDI02_A_2024319004209_O33548_02_T09947_02_004_02_V002/GEDI02_A_2024319004209_O33548_02_T09947_02_004_02_V002.h5"},
      {"rel": "http://esipfed.org/ns/fedsearch/1.1/s3#",
       "href": "s3://lp-prod-protected/GEDI02_A.002/GEDI02_A_2024319004209_O33548_02_T09947_02_004_02_V002/GEDI02_A_2024319004209_O33548_02_T09947_02_004_02_V002.h5"},
      {"rel": "http://esipfed.org/ns/fedsearch/1.1/browse#",
       "href": "https://data.lpdaac.earthdatacloud.nasa.gov/lp-prod-public/GEDI02_A.002/GEDI02_A_2024319004209_O33548_02_T09947_02_004_02_V002/GEDI02_A_2024319004209_O33548_02_T09947_02_004_02_V002.1.png"},
      {"inherited": true, "rel": "http://esipfed.org/ns/fedsearch/1.1/metadata#", "href": "https://doi.org/10.5067/GEDI/GEDI02_A.002"},
      {"inherited": true, "rel": "http://esipfed.org/ns/fedsearch/1.1/documentation#", "href": "https://lpdaac.usgs.gov/documents/982/gedi_l2a_dictionary_P003_v2..."}
    ]
  }]
}}
```

All 5 L2A entries (producer_granule_id, time_start, granule_size MB):

```
GEDI02_A_2024319004209_O33548_02_T09947_02_004_02_V002  2024-11-14T00:42:09.000Z  2160.2
GEDI02_A_2024281153052_O32968_02_T04408_02_004_02_V002  2024-10-07T15:30:52.000Z  2176.89
GEDI02_A_2024275000622_O32865_03_T04320_02_004_02_V002  2024-10-01T00:06:22.000Z  2667.59
GEDI02_A_2024220213112_O32026_03_T05743_02_004_03_V002  2024-08-07T21:31:12.000Z  2695.09
GEDI02_A_2024197005948_O31656_02_T00139_02_004_03_V002  2024-07-15T00:59:48.000Z  2026.27
```

Same search for L4A (`short_name=GEDI_L4A_AGB_Density_V2_1_2056`, no version), captured 2026-11-14; first entry trimmed in the same way:

```json
{"feed": {"entry": [{
  "title": "GEDI_L4A_AGB_Density_V2_1.GEDI04_A_2024319004209_O33548_02_T09947_02_004_01_V002.h5",
  "time_start": "2024-11-14T01:08:48.000Z",
  "time_end": "2024-11-14T01:28:12.000Z",
  "updated": "2026-04-23T12:19:05.000Z",
  "dataset_id": "GEDI L4A Footprint Level Aboveground Biomass Density, Version 2.1",
  "data_center": "ORNL_CLOUD",
  "id": "G3498167365-ORNL_CLOUD",
  "granule_size": "292.499642",
  "day_night_flag": "BOTH",
  "collection_concept_id": "C2237824918-ORNL_CLOUD",
  "online_access_flag": true,
  "links": [
    {"rel": "http://esipfed.org/ns/fedsearch/1.1/data#", "href": "https://data.ornldaac.earthdata.nasa.gov/protected/gedi/GEDI_L4A_AGB_Density_V2_1/data/GEDI04_A_2024319004209_O33548_02_T09947_02_004_01_V002.h5"},
    {"rel": "http://esipfed.org/ns/fedsearch/1.1/s3#", "href": "s3://ornl-cumulus-prod-protected/gedi/GEDI_L4A_AGB_Density_V2_1/data/GEDI04_A_2024319004209_O33548_02_T09947_02_004_01_V002.h5"},
    {"rel": "http://esipfed.org/ns/fedsearch/1.1/metadata#", "title": "ORNL DAAC Data Set Documentation (USER'S GUIDE)", "href": "https://daac.ornl.gov/GEDI/guides/GEDI_L4A_AGB_Density_V2_1.html"},
    {"rel": "http://esipfed.org/ns/fedsearch/1.1/metadata#", "title": "Data Set Documentation (GENERAL DOCUMENTATION)", "href": "https://data.ornldaac.earthdata.nasa.gov/public/gedi/GEDI_L4A_AGB_Density_V2_1/comp/GEDI_L4A_V2_Product_Data_Dictionary.pdf"}
  ]
}]}}
```

L4A entries returned (title suffix, time_start, granule_size MB): `GEDI04_A_2024319004209_O33548_...` 2024-11-14 292.5; `GEDI04_A_2024281153052_O32968_...` 2024-10-07 275.3; `GEDI04_A_2024275000622_O32865_...` 2024-10-01 351.2; `GEDI04_A_2024220213112_O32026_...` 2024-08-07 349.6; `GEDI04_A_2024197005948_O31656_...` 2024-07-15 274.9. These are the same orbits as the L2A results.

### Granule file download

| Parameter | Required | Description | Example |
|---|---|---|---|
| URL | yes | `data#` link from CMR | see request |
| Earthdata Login | yes | Bearer token or Earthdata Login redirect cookie | (not used here) |

```
GET https://data.ornldaac.earthdata.nasa.gov/protected/gedi/GEDI_L4A_AGB_Density_V2_1/data/GEDI04_A_2024319004209_O33548_02_T09947_02_004_01_V002.h5
Authorization: Bearer <earthdata_token>
```

### Sample response (Representative)

HDF5 structure from the ORNL DAAC L4A user guide and product data dictionary (one group per beam; arrays are one value per footprint). Values are placeholders; no file was downloaded.

```
/ANCILLARY/                       model and PFT lookup tables
/METADATA/DatasetIdentification   product attributes
/BEAM0000 ... /BEAM1011/          8 beam groups (BEAM0000, 0001, 0010, 0011 coverage; 0101, 0110, 1000, 1011 full power)
    shot_number        uint64   [n]
    delta_time         float64  [n]   seconds since 2018-01-01T00:00:00Z
    lat_lowestmode     float64  [n]   degrees
    lon_lowestmode     float64  [n]   degrees
    elev_lowestmode    float32  [n]   m
    agbd               float32  [n]   Mg/ha       e.g. -9999 (fill) or a positive value
    agbd_se            float32  [n]   Mg/ha
    agbd_pi_lower      float32  [n]   Mg/ha
    agbd_pi_upper      float32  [n]   Mg/ha
    l2_quality_flag    uint8    [n]   0/1
    l4_quality_flag    uint8    [n]   0/1
    degrade_flag       uint8    [n]
    sensitivity        float32  [n]   0-1
    predictor_limit_flag  uint8 [n]   0 in range, 1 below, 2 above
    response_limit_flag   uint8 [n]   0 in range, 1 below, 2 above
    land_cover_data/pft_class   uint8 [n]
    land_cover_data/region_class uint8 [n]
    geolocation/sensitivity_a2  float32 [n]
```

### GEDI Subsetter (NASA MAAP DPS job `gedi-subset`)

Clips GEDI footprint granules to an AOI and writes one table. Runs as a MAAP Data Processing System job; inputs from the MAAP usage guide.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `aoi` | yes | URL to a GeoJSON AOI | `https://<host>/york_ne_field.geojson` |
| `doi` | yes | Logical name (`L1B`, `L2A`, `L2B`, `L4A`, `L4C`), DOI, or collection concept ID | `L4A` |
| `lat` | yes | Latitude dataset name | `lat_lowestmode` |
| `lon` | yes | Longitude dataset name | `lon_lowestmode` |
| `columns` | yes | Comma-separated dataset names to output; 2D slices like `rh[:10]` allowed | `agbd, agbd_se, sensitivity, geolocation/sensitivity_a2` |
| `query` | no | Row filter expression | ``l2_quality_flag == 1 and l4_quality_flag == 1 and sensitivity > 0.95 and `geolocation/sensitivity_a2` > 0.95`` |
| `beams` | no | `all` (default), `coverage`, `power`, or list like `BEAM0101,BEAM0110` | `all` |
| `temporal` | no | CMR temporal range | `2024-01-01T00:00:00Z,2024-12-31T23:59:59Z` |
| `limit` | no | Max granules (default 100000; 0 = no limit) | `0` |
| `output` | no | Output file name; extension sets format `.gpkg`, `.fgb`, `.parquet` | `york_l4a_2024.gpkg` |
| `tolerated-failure-percentage` | no | Percent of granule failures tolerated (default 0) | `0` |
| `fsspec-kwargs`, `processes` | no | Advanced tuning | (omitted) |

```python
from maap.maap import MAAP
maap = MAAP(maap_host="api.maap-project.org")
result = maap.submitJob(
    identifier="york-l4a-2024",
    algo_id="gedi-subset",
    version="<VERSION>",
    queue="maap-dps-worker-32vcpu-64gb",
    username="<EARTHDATA_USERNAME>",
    aoi="<AOI GeoJSON URL>",
    doi="L4A",
    lat="lat_lowestmode",
    lon="lon_lowestmode",
    columns="agbd, agbd_se, sensitivity, geolocation/sensitivity_a2",
    query="l2_quality_flag == 1 and l4_quality_flag == 1 and sensitivity > 0.95 and `geolocation/sensitivity_a2` > 0.95",
    temporal="2024-01-01T00:00:00Z,2024-12-31T23:59:59Z",
    limit=0,
    output="york_l4a_2024.gpkg",
)
```

### Sample response (Representative)

From the MAAP usage guide: `submitJob` returns a dict with `job_id`; status values are `Accepted`, `Running`, `Succeeded`, `Failed`. Output rows (placeholder values) as read with geopandas; a `filename` column is added automatically.

```
{"job_id": "<uuid>", ...}

filename                                                    agbd   agbd_se  sensitivity  geolocation/sensitivity_a2  geometry
GEDI04_A_2024197005948_O31656_02_T00139_02_004_02_V002.h5   <f4>   <f4>     <f4>         <f4>                        POINT (<lon> <lat>)
```

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `producer_granule_id` / `title` | string | | `GEDI0X_Y_<YYYYDDDHHMMSS>_O<orbit>_<sub-orbit>_T<track>_<PPDS>_<gen>_<version>` (L4A title prefixed with collection name) |
| `time_start`, `time_end` | string | UTC | Orbit segment time range |
| `granule_size` | string | MB | File size |
| `polygons` | array of strings | lat lon pairs | Orbit-segment footprint polygon (coarse) |
| `links[].rel` `data#` / `s3#` / `browse#` / `metadata#` | string | | HTTPS download, S3 path, PNG browse, docs |
| `orbit_calculated_spatial_domains` | array | | ISS orbit number |
| L2A `rh` | float32 [n,101] | m | Relative height percentiles 0-100 of waveform energy above ground |
| L2A `quality_flag` | uint8 | | 1 = passes L2A quality tests |
| L2A `lat_lowestmode`, `lon_lowestmode`, `elev_lowestmode` | float | deg, m | Ground (lowest mode) location and elevation |
| L2B `cover` | float32 | 0-1 | Total canopy cover |
| L2B `pai` | float32 | m2/m2 | Total plant area index |
| L2B `fhd_normal` | float32 | | Foliage height diversity |
| L2B `cover_z`, `pavd_z` | float32 [n,30] | per 5 m bin | Cumulative cover and plant area volume density profiles |
| L2B `rh100` | int16 | cm | Height of highest return |
| L2B `l2a_quality_flag`, `l2b_quality_flag` | uint8 | | Quality flags |
| L4A `agbd` | float32 | Mg/ha | Aboveground biomass density |
| L4A `agbd_se` | float32 | Mg/ha | Standard error of `agbd` |
| L4A `agbd_pi_lower`, `agbd_pi_upper` | float32 | Mg/ha | Prediction interval bounds |
| L4A `l2_quality_flag` | uint8 | | 1 when algorithm_run_flag = 1, surface_flag = 1, stale_return_flag = 0, sensitivity > 0.9, rx_maxamp > 8 x sd_corrected |
| L4A `l4_quality_flag` | uint8 | | 1 when l2_quality_flag = 1, sensitivity > 0.95, landsat_water_persistence < 10, urban_proportion < 50 (plus leaf-off rule in deciduous strata) |
| L4A `predictor_limit_flag`, `response_limit_flag` | uint8 | | 0 inside training range, 1 below, 2 above |
| `sensitivity` | float32 | 0-1 | Beam sensitivity (max canopy cover penetrable) |
| `delta_time` | float64 | s | Seconds since the GEDI epoch (2018-01-01T00:00:00Z) |
| `shot_number` | uint64 | | Unique footprint ID |

Fill value `-9999` for float variables in L4A (user guide). L4B: 1 km GeoTIFF layers of mean AGBD and its uncertainty (see L4B user guide); L4B v2.1 ends 2023-03-16 in CMR.

## Notes

- CMR spatial matching uses the orbit-segment polygon (thousands of km long), so a granule hit does not guarantee a footprint within the bounding box; footprints have to be filtered by `lat_lowestmode`/`lon_lowestmode` after reading the file or via the subsetter.
- L2A granules are about 2 GB each, L4A about 0.3 GB each (captured `granule_size`).
- `point=` and `bounding_box=` both work in CMR; the captured request used `bounding_box`.
- A CMR request with an `application/json` `Content-Type` header on GET returned HTTP 400 `{"errors":["Parameter [short_name] was not recognized."]}`; without that header the same URL returned 200.
- L4A `predictor_limit_flag`/`response_limit_flag` record when inputs or predictions fall outside the range of the model training data; they do not change `l4_quality_flag` (user guide).
- Downloads were not attempted (Earthdata Login required); file structure samples are Representative.
- The GEDI Subsetter requires a MAAP account and runs inside MAAP; not run here.

## Documentation

- CMR Search API: https://cmr.earthdata.nasa.gov/search/site/docs/search/api.html
- GEDI L4A V2.1 user guide: https://daac.ornl.gov/GEDI/guides/GEDI_L4A_AGB_Density_V2_1.html ; DOI https://doi.org/10.3334/ORNLDAAC/2056
- GEDI L4A data dictionary: https://data.ornldaac.earthdata.nasa.gov/public/gedi/GEDI_L4A_AGB_Density_V2_1/comp/GEDI_L4A_V2_Product_Data_Dictionary.pdf
- GEDI L4B V2.1: https://doi.org/10.3334/ORNLDAAC/2299
- GEDI L2A V002: https://doi.org/10.5067/GEDI/GEDI02_A.002 ; L2B V002: https://doi.org/10.5067/GEDI/GEDI02_B.002
- LP DAAC GEDI L2A dictionary: https://lpdaac.usgs.gov/products/gedi02_av002/
- GEDI Subsetter: https://github.com/MAAP-Project/gedi-subsetter (usage: docs/MAAP_USAGE.md)
- Earthdata Login: https://urs.earthdata.nasa.gov/
- NASA data are openly licensed with no restrictions on use.
