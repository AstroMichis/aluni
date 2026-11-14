# NASA Earthdata CMR Search API

The Common Metadata Repository (CMR) is NASA's catalog of Earth science metadata for all EOSDIS data centers (and some partners). Its Search API returns metadata records for collections (datasets) and granules (individual files), including download links (HTTPS and S3), OPeNDAP links and service associations. Searching is open with no login; downloading the files listed in the results usually requires an Earthdata Login account. The catalog is updated continuously as providers ingest granules.

| | |
|---|---|
| Provider | NASA Earth Science Data and Information System (ESDIS) |
| Base URL | `https://cmr.earthdata.nasa.gov/search/` |
| Auth | none for public metadata; an Earthdata Login bearer token (`Authorization` header) is used only for restricted collections. Data files linked from results generally require an Earthdata Login account (https://urs.earthdata.nasa.gov) |
| Formats | JSON (`.json`), UMM JSON (`.umm_json`), Atom, ECHO10, ISO 19115, DIF, CSV, KML, STAC, HTML (by extension or `Accept` header) |
| Coverage | all EOSDIS collections, global |
| Resolution | not applicable (metadata) |
| Cadence / latency | metadata updated as providers ingest |
| Rate limits / quotas | throttling rules exist; exceeding them returns HTTP 429 with a `retry-after` header. Numeric limits not published |
| Documentation | https://cmr.earthdata.nasa.gov/search/site/docs/search/api.html |

## Requests

### Collection search

Returns collection (dataset) records matching the filters.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `short_name` | no | Collection short name | `SPL3SMP_E` |
| `version` | no | Collection version | `006` |
| `concept_id` | no | CMR collection concept ID | `C2938664763-NSIDC_CPRD` |
| `provider` | no | Provider ID | `GES_DISC` |
| `keyword` | no | Free-text keyword search | `IMERG daily` |
| `point` | no | `lon,lat` | `-97.50,40.95` |
| `bounding_box` | no | `west,south,east,north` | `-97.6,40.9,-97.4,41.0` |
| `circle` | no | `lon,lat,radius_m` | `-97.50,40.95,1000` |
| `temporal` | no | `start,end` ISO 8601; either end may be empty | `2025-07-01T00:00:00Z,2025-07-31T23:59:59Z` |
| `cloud_hosted` | no | `true` for Earthdata Cloud collections | `true` |
| `has_granules` | no | Only collections with granules | `true` |
| `include_granule_counts` | no | Add granule counts matching spatial/temporal filters | `true` |
| `page_size` | no | Results per page, default 10, max 2000 | `5` |
| `page_num` | no (deprecated) | Page number | `1` |
| `sort_key` | no | Sort field, prefix `-` for descending | `-start_date` |

Request headers: `Client-Id` (optional, identifies the client), `CMR-Search-After` (paging, see below).

```
GET https://cmr.earthdata.nasa.gov/search/collections.json?short_name=SPL3SMP_E&page_size=5
```

### Sample response: collection search (Captured 2026-11-14, trimmed)

Trimmed: `associations` and `association_details` (about 200 variable IDs plus service, tool and citation IDs) removed, `summary` cut after 220 characters, `links` cut to the first 3 of 11. Response headers included `cmr-hits: 1`, `cmr-took: 11`, `cmr-search-after: [0.0,9200.0,"SPL3SMP_E","6",2938664763,54]`.

```json
{
 "feed": {
  "updated": "2026-11-14T22:58:18.833Z",
  "id": "https://cmr.earthdata.nasa.gov:443/search/collections.json?short_name=SPL3SMP_E&page_size=5",
  "title": "ECHO dataset metadata",
  "entry": [
   {
    "processing_level_id": "3",
    "cloud_hosted": true,
    "boxes": ["-85.044 -180 90 180"],
    "has_combine": false,
    "time_start": "2015-03-31T00:00:00.000Z",
    "version_id": "006",
    "dataset_id": "SMAP Enhanced L3 Radiometer Global and Polar Grid Daily 9 km EASE-Grid Soil Moisture V006",
    "entry_id": "SPL3SMP_E_006",
    "has_spatial_subsetting": true,
    "has_transforms": true,
    "has_variables": true,
    "data_center": "NSIDC_CPRD",
    "short_name": "SPL3SMP_E",
    "organizations": ["NASA NSIDC DAAC", "NASA/JPL/SMAP"],
    "title": "SMAP Enhanced L3 Radiometer Global and Polar Grid Daily 9 km EASE-Grid Soil Moisture V006",
    "coordinate_system": "CARTESIAN",
    "summary": "This enhanced Level-3 (L3) soil moisture product provides a composite of daily estimates of global land surface conditions retrieved by the Soil Moisture Active Passive (SMAP) radiometer. This product is a daily composit...",
    "service_features": {
     "harmony": {"has_formats": true, "has_variables": true, "has_transforms": true, "has_combine": false, "has_spatial_subsetting": true, "has_temporal_subsetting": false},
     "opendap": {"has_formats": false, "has_variables": false, "has_transforms": false, "has_combine": false, "has_spatial_subsetting": false, "has_temporal_subsetting": false},
     "esi": {"has_formats": false, "has_variables": false, "has_transforms": false, "has_combine": false, "has_spatial_subsetting": false, "has_temporal_subsetting": false}
    },
    "orbit_parameters": {},
    "id": "C2938664763-NSIDC_CPRD",
    "has_formats": true,
    "consortiums": ["GEOSS", "EOSDIS"],
    "original_format": "ISO19115",
    "archive_center": "NASA NSIDC DAAC",
    "has_temporal_subsetting": false,
    "browse_flag": true,
    "platforms": ["SMAP"],
    "online_access_flag": true,
    "links": [
     {"length": "0.0KB", "rel": "http://esipfed.org/ns/fedsearch/1.1/data#", "hreflang": "en-US", "href": "https://search.earthdata.nasa.gov/search/granules?p=C2938664763-NSIDC_CPRD"},
     {"length": "0.0KB", "rel": "http://esipfed.org/ns/fedsearch/1.1/data#", "hreflang": "en-US", "href": "https://cmr.earthdata.nasa.gov/virtual-directory/collections/C2938664763-NSIDC_CPRD"},
     {"length": "0.0KB", "rel": "http://esipfed.org/ns/fedsearch/1.1/data#", "hreflang": "en-US", "href": "https://nsidc.org/data/data-access-tool/SPL3SMP_E/versions/6/"}
    ]
   }
  ]
 }
}
```

### Collection keyword search

```
GET https://cmr.earthdata.nasa.gov/search/collections.json?keyword=IMERG%20daily&provider=GES_DISC&page_size=20
```

### Sample response (Captured 2026-11-14, trimmed)

`cmr-hits: 8`. Trimmed to `id`, `short_name`, `version_id`, `time_start`, `time_end`, `title` per entry (all 8 entries shown).

```
C2211141201-GES_DISC  GPCPDAY            3.2  2000-06-01  2021-09-30  GPCP Precipitation Level 3 Daily 0.5-Degree V3.2 (GPCPDAY)
C3405928682-GES_DISC  GPCPDAY            3.3  1998-01-01  2025-12-31  GPCP Precipitation Level 3 Daily 0.5-Degree V3.3 (GPCPDAY)
C2723754859-GES_DISC  GPM_3IMERGDL       07   1998-01-01  (open)      GPM IMERG Late Precipitation L3 1 day 0.1 degree x 0.1 degree V07 (GPM_3IMERGDL)
C2723754864-GES_DISC  GPM_3IMERGDF       07   1998-01-01  2025-09-30  GPM IMERG Final Precipitation L3 1 day 0.1 degree x 0.1 degree V07 (GPM_3IMERGDF)
C2723754850-GES_DISC  GPM_3IMERGDE       07   1998-01-01  (open)      GPM IMERG Early Precipitation L3 1 day 0.1 degree x 0.1 degree V07 (GPM_3IMERGDE)
C1239536905-GES_DISC  TRMM_3B42_Daily    7    1998-01-01  2019-12-31  TRMM (TMPA) Precipitation L3 1 day 0.25 degree x 0.25 degree V7 (TRMM_3B42_Daily)
C1276795284-GES_DISC  TRMM_3B42RT_Daily  7    2000-03-01  2020-01-01  TRMM (TMPA-RT) Near Real-Time Precipitation L3 1 day 0.25 degree x 0.25 degree V7 (TRMM_3B
C2670410720-GES_DISC  Global_Landslide_Exposure_Maps 1.0 2001-01-01 (open) IMERG and LHASA Global Landslide Exposure Maps 1.0
```

### Granule search

Returns granule (file) records. A collection filter (`short_name`, `collection_concept_id`, `concept_id` of a collection, or `provider`) is expected.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `short_name` + `version` | one collection filter required | Collection short name and version | `SPL3SMP_E`, `006` |
| `collection_concept_id` | alternative | Collection concept ID | `C2723754864-GES_DISC` |
| `concept_id` | no | Granule concept ID (single record) | `G3891027605-GES_DISC` |
| `point` | no | `lon,lat` | `-97.50,40.95` |
| `bounding_box`, `polygon`, `circle` | no | Spatial filters | `-97.6,40.9,-97.4,41.0` |
| `temporal` | no | `start,end` ISO 8601 | `2025-07-01T00:00:00Z,2025-07-03T23:59:59Z` |
| `readable_granule_name` | no | Granule name, wildcards with `options[readable_granule_name][pattern]=true` | `*20250701*` |
| `page_size` | no | Default 10, max 2000 | `10` |
| `sort_key` | no | For example `start_date`, `-start_date` | `start_date` |

```
GET https://cmr.earthdata.nasa.gov/search/granules.json?short_name=SPL3SMP_E&version=006&point=-97.50,40.95&temporal=2025-07-01T00:00:00Z,2025-07-03T23:59:59Z&page_size=10&sort_key=start_date
```

### Sample response: SMAP granules (Captured 2026-11-14, trimmed)

`cmr-hits: 3`. Trimmed: first granule shown in full except `links` cut to 4 of 18; the other two granules reduced to `title` and `id`.

```json
{
 "feed": {
  "updated": "2026-11-14T22:58:43.604Z",
  "id": "https://cmr.earthdata.nasa.gov:443/search/granules.json?short_name=SPL3SMP_E&version=006&point=-97.50,40.95&temporal=2025-07-01T00:00:00Z,2025-07-03T23:59:59Z&page_size=10&sort_key=start_date",
  "title": "ECHO granule metadata",
  "entry": [
   {
    "producer_granule_id": "SMAP_L3_SM_P_E_20250701_R19240_001.h5",
    "boxes": ["-85.0445023 -180 85.0445023 180"],
    "time_start": "2025-07-01T00:00:00.000Z",
    "updated": "2025-12-19T00:53:19.766Z",
    "dataset_id": "SMAP Enhanced L3 Radiometer Global and Polar Grid Daily 9 km EASE-Grid Soil Moisture V006",
    "data_center": "NSIDC_CPRD",
    "title": "SMAP_L3_SM_P_E_20250701_R19240_001.h5",
    "coordinate_system": "CARTESIAN",
    "day_night_flag": "UNSPECIFIED",
    "time_end": "2025-07-01T23:59:59.999Z",
    "id": "G3589003945-NSIDC_CPRD",
    "original_format": "UMM_JSON",
    "granule_size": "655.1109342575073",
    "browse_flag": false,
    "collection_concept_id": "C2938664763-NSIDC_CPRD",
    "online_access_flag": true,
    "links": [
     {"rel": "http://esipfed.org/ns/fedsearch/1.1/data#", "title": "Download SMAP_L3_SM_P_E_20250701_R19240_001.h5", "hreflang": "en-US",
      "href": "https://data.nsidc.earthdatacloud.nasa.gov/nsidc-cumulus-prod-protected/SMAP/SPL3SMP_E/006/2025/07/01/SMAP_L3_SM_P_E_20250701_R19240_001.h5"},
     {"rel": "http://esipfed.org/ns/fedsearch/1.1/metadata#", "title": "Download SMAP_L3_SM_P_E_20250701_R19240_001.h5.iso.xml", "hreflang": "en-US",
      "href": "https://data.nsidc.earthdatacloud.nasa.gov/nsidc-cumulus-prod-public/SMAP/SPL3SMP_E/006/2025/07/01/SMAP_L3_SM_P_E_20250701_R19240_001.h5.iso.xml"},
     {"rel": "http://esipfed.org/ns/fedsearch/1.1/metadata#", "title": "Download SMAP_L3_SM_P_E_20250701_R19240_001.qa", "hreflang": "en-US",
      "href": "https://data.nsidc.earthdatacloud.nasa.gov/nsidc-cumulus-prod-protected/SMAP/SPL3SMP_E/006/2025/07/01/SMAP_L3_SM_P_E_20250701_R19240_001.qa"},
     {"rel": "http://esipfed.org/ns/fedsearch/1.1/s3#", "title": "This link provides direct download access via S3 to the granule", "hreflang": "en-US",
      "href": "s3://nsidc-cumulus-prod-protected/SMAP/SPL3SMP_E/006/2025/07/01/SMAP_L3_SM_P_E_20250701_R19240_001.h5"}
    ]
   },
   {"title": "SMAP_L3_SM_P_E_20250702_R19240_002.h5", "id": "G3596281780-NSIDC_CPRD"},
   {"title": "SMAP_L3_SM_P_E_20250703_R19240_001.h5", "id": "..."}
  ]
 }
}
```

### Granule search: GPM IMERG Final daily

```
GET https://cmr.earthdata.nasa.gov/search/granules.json?short_name=GPM_3IMERGDF&version=07&point=-97.50,40.95&temporal=2025-07-01T00:00:00Z,2025-07-03T23:59:59Z&page_size=10
```

### Sample response (Captured 2026-11-14, trimmed)

`cmr-hits: 3`. Trimmed to `id`, `title`, `time_start`, `time_end`, `granule_size` (MB) and the first 4 link `href` values per entry.

```
G3891027605-GES_DISC  GPM_3IMERGDF.07:3B-DAY.MS.MRG.3IMERG.20250701-S000000-E235959.V07B.nc4  2025-07-01T00:00:00.000Z  2025-07-01T23:59:59.999Z  29.9336748123169
   https://data.gesdisc.earthdata.nasa.gov/data/GPM_L3/GPM_3IMERGDF.07/2025/07/3B-DAY.MS.MRG.3IMERG.20250701-S000000-E235959.V07B.nc4
   s3://gesdisc-cumulus-prod-protected/GPM_L3/GPM_3IMERGDF.07/2025/07/3B-DAY.MS.MRG.3IMERG.20250701-S000000-E235959.V07B.nc4
   https://data.gesdisc.earthdata.nasa.gov/s3credentials
   https://opendap.earthdata.nasa.gov/collections/C2723754864-GES_DISC/granules/GPM_3IMERGDF.07%3A3B-DAY.MS.MRG.3IMERG.20250701-S000000-E235959.V07B.nc4
G3891028685-GES_DISC  GPM_3IMERGDF.07:3B-DAY.MS.MRG.3IMERG.20250702-S000000-E235959.V07B.nc4  2025-07-02T00:00:00.000Z  2025-07-02T23:59:59.999Z  30.8157472610474
G3891027531-GES_DISC  GPM_3IMERGDF.07:3B-DAY.MS.MRG.3IMERG.20250703-S000000-E235959.V07B.nc4  2025-07-03T00:00:00.000Z  2025-07-03T23:59:59.999Z  31.0789775848389
```

### Granule record in UMM JSON

```
GET https://cmr.earthdata.nasa.gov/search/granules.umm_json?concept_id=G3891027605-GES_DISC
```

### Sample response (Captured 2026-11-14, trimmed)

Trimmed: `RelatedUrls` cut to 3 of 4.

```json
{
 "hits": 1,
 "took": 29,
 "items": [
  {
   "meta": {
    "concept-type": "granule",
    "concept-id": "G3891027605-GES_DISC",
    "revision-id": 2,
    "native-id": "GPM_3IMERGDF.07:3B-DAY.MS.MRG.3IMERG.20250701-S000000-E235959.V07B.nc4",
    "collection-concept-id": "C2723754864-GES_DISC",
    "provider-id": "GES_DISC",
    "format": "application/echo10+xml",
    "revision-date": "2026-05-11T17:56:30.146Z"
   },
   "umm": {
    "RelatedUrls": [
     {"URL": "https://data.gesdisc.earthdata.nasa.gov/data/GPM_L3/GPM_3IMERGDF.07/2025/07/3B-DAY.MS.MRG.3IMERG.20250701-S000000-E235959.V07B.nc4", "Type": "GET DATA", "Description": "Download 3B-DAY.MS.MRG.3IMERG.20250701-S000000-E235959.V07B.nc4"},
     {"URL": "s3://gesdisc-cumulus-prod-protected/GPM_L3/GPM_3IMERGDF.07/2025/07/3B-DAY.MS.MRG.3IMERG.20250701-S000000-E235959.V07B.nc4", "Type": "GET DATA VIA DIRECT ACCESS", "Description": "This link provides direct download access via S3 to the granule"},
     {"URL": "https://data.gesdisc.earthdata.nasa.gov/s3credentials", "Type": "VIEW RELATED INFORMATION", "Description": "api endpoint to retrieve temporary credentials valid for same-region direct s3 access"}
    ],
    "SpatialExtent": {"HorizontalSpatialDomain": {"Geometry": {"BoundingRectangles": [
      {"WestBoundingCoordinate": -180.0, "EastBoundingCoordinate": 180.0, "NorthBoundingCoordinate": 90.0, "SouthBoundingCoordinate": -90.0}]}}},
    "ProviderDates": [{"Date": "2025-12-01T23:01:57.000Z", "Type": "Insert"}, {"Date": "2025-12-01T23:01:57.000Z", "Type": "Update"}],
    "CollectionReference": {"ShortName": "GPM_3IMERGDF", "Version": "07"},
    "DataGranule": {
     "DayNightFlag": "Unspecified",
     "Identifiers": [{"Identifier": "3B-DAY.MS.MRG.3IMERG.20250701-S000000-E235959.V07B.nc4", "IdentifierType": "ProducerGranuleId"}],
     "ProductionDateTime": "2025-12-01T23:01:57.000Z",
     "ArchiveAndDistributionInformation": [{"Name": "Not provided", "Size": 29.9336748123169, "SizeUnit": "MB"}]
    },
    "TemporalExtent": {"RangeDateTime": {"BeginningDateTime": "2025-07-01T00:00:00.000Z", "EndingDateTime": "2025-07-01T23:59:59.999Z"}},
    "GranuleUR": "GPM_3IMERGDF.07:3B-DAY.MS.MRG.3IMERG.20250701-S000000-E235959.V07B.nc4",
    "MetadataSpecification": {"URL": "https://cdn.earthdata.nasa.gov/umm/granule/v1.6.7", "Name": "UMM-G", "Version": "1.6.7"}
   }
  }
 ]
}
```

### Paging with CMR-Search-After

When more results exist than `page_size`, the response carries a `CMR-Search-After` header. Repeat the identical query with that value in a `CMR-Search-After` request header to get the next page; an empty result set with no header marks the end.

```
GET https://cmr.earthdata.nasa.gov/search/granules.json?short_name=SPL3SMP_E&version=006&point=-97.50,40.95&temporal=2025-01-01T00:00:00Z,2025-12-31T23:59:59Z&page_size=200
CMR-Search-After: ["aaa", 123, 456]
```

### Sample response (Representative)

Same body shape as the granule search above; the response headers include `CMR-Hits` (total matches) and a new `CMR-Search-After` value while more pages remain (per the CMR API documentation).

## Fields

Collection entries (`collections.json`):

| Field | Type | Unit | Description |
|---|---|---|---|
| `id` | string | | Collection concept ID (`C...-PROVIDER`) |
| `short_name`, `version_id` | string | | Collection short name and version |
| `title`, `dataset_id` | string | | Long name |
| `summary` | string | | Abstract |
| `time_start`, `time_end` | ISO 8601 | | Temporal extent (`time_end` absent for ongoing collections) |
| `boxes` | string[] | degrees | Bounding boxes as `"south west north east"` |
| `data_center`, `archive_center`, `organizations` | string | | Provider and organizations |
| `processing_level_id` | string | | Processing level |
| `cloud_hosted` | boolean | | Data in Earthdata Cloud |
| `online_access_flag`, `browse_flag` | boolean | | Online data / browse images available |
| `service_features` | object | | Harmony / OPeNDAP / ESI capabilities (subsetting, formats, variables) |
| `has_variables`, `has_formats`, `has_transforms`, `has_spatial_subsetting`, `has_temporal_subsetting` | boolean | | Service capability flags |
| `platforms` | string[] | | Platforms |
| `links[].href`, `links[].rel` | string | | Related URLs (rel `.../data#`, `.../metadata#`, `.../documentation#`, `.../s3#`, `.../service#`) |
| `associations` | object | | Associated variable, service, tool, citation concept IDs |

Granule entries (`granules.json`):

| Field | Type | Unit | Description |
|---|---|---|---|
| `id` | string | | Granule concept ID (`G...-PROVIDER`) |
| `title`, `producer_granule_id` | string | | Granule name / file name |
| `collection_concept_id` | string | | Parent collection |
| `time_start`, `time_end` | ISO 8601 | UTC | Temporal coverage of the file |
| `updated` | ISO 8601 | | Last metadata update |
| `granule_size` | string/number | MB | File size |
| `boxes` / `polygons` | string[] | degrees | Spatial footprint |
| `day_night_flag` | string | | Day/night indicator |
| `links[]` | object[] | | HTTPS download (`.../data#`), S3 (`.../s3#`), OPeNDAP (`.../service#` or opendap host), metadata links |

Response headers: `CMR-Hits` (total matches), `CMR-Took` (ms), `CMR-Request-Id`, `CMR-Search-After`.

## Notes

- `point` and `bounding_box` take longitude first (`lon,lat`).
- Global granules (SMAP L3, IMERG daily) match any point, so a point filter does not reduce the result count for them.
- `page_num` and `offset` are deprecated; paging past the 1,000,000th item is not supported, and granule queries not limited to collections are limited to the first 10,000 items.
- Opening a data link without credentials on 2026-11-14 (`https://data.gesdisc.earthdata.nasa.gov/data/GPM_L3/GPM_3IMERGDF.07/2025/07/3B-DAY...V07B.nc4`) redirected to the Earthdata Login page (`urs.earthdata.nasa.gov/oauth/authorize`); no data were returned.
- `GPM_3IMERGDF` (Final) had `time_end` 2025-09-30 in the collection record on 2026-11-14; `GPM_3IMERGDL` (Late) and `GPM_3IMERGDE` (Early) were open-ended.
- STAC output is available at `https://cmr.earthdata.nasa.gov/stac` (per the CMR docs); not captured here.

## Documentation

- CMR Search API: https://cmr.earthdata.nasa.gov/search/site/docs/search/api.html
- Earthdata Login: https://urs.earthdata.nasa.gov
- Earthdata Search (web UI over CMR): https://search.earthdata.nasa.gov
- UMM-G specification: https://cdn.earthdata.nasa.gov/umm/granule/v1.6.7
