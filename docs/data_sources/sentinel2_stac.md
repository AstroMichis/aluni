# Copernicus Sentinel-2 L2A (open catalogue search)

Sentinel-2 is the European Union Copernicus optical mission (satellites Sentinel-2A, 2B and 2C) carrying the MultiSpectral Instrument (MSI) with 13 bands at 10, 20 and 60 m. Level-2A products are bottom-of-atmosphere surface reflectance with a Scene Classification Layer (SCL), distributed as 110 x 110 km MGRS tiles. Combined revisit is about 5 days at the equator and shorter at mid latitudes (the reference point had acquisitions on 2025-07-02, 05, 15, 20 and 22). Archive starts June 2015; L2A is produced within about 24 hours (`product:timeliness` `PT24H` in the captured item). This page covers open, no-login catalogue search: the Copernicus Data Space Ecosystem (CDSE) STAC API and OData catalogue, and Element 84 Earth Search on AWS. Authenticated Sentinel Hub processing is documented separately in `copernicus.md`.

| | |
|---|---|
| Provider | European Commission / ESA (Copernicus); CDSE operated for ESA; Earth Search operated by Element 84 on the AWS Registry of Open Data |
| Base URL | CDSE STAC: `https://stac.dataspace.copernicus.eu/v1` ; CDSE OData: `https://catalogue.dataspace.copernicus.eu/odata/v1` ; Earth Search: `https://earth-search.aws.element84.com/v1` |
| Auth | none for search; CDSE asset download needs a CDSE account (OIDC token) or CDSE S3 keys; Earth Search COGs are public on `sentinel-cogs.s3.us-west-2.amazonaws.com` |
| Formats | STAC GeoJSON, OData JSON; data in JPEG 2000 inside SAFE (CDSE) or COG GeoTIFF (Earth Search) |
| Coverage | Global land and coastal waters, 56 S to 84 N |
| Resolution | 10 m (B02, B03, B04, B08), 20 m (B05, B06, B07, B8A, B11, B12, SCL), 60 m (B01, B09) |
| Cadence / latency | about 5-day revisit; L2A NRT within 24 h |
| Rate limits / quotas | CDSE publishes per-user quotas for authenticated APIs; open search limits not published; Earth Search not published |
| Documentation | https://documentation.dataspace.copernicus.eu/APIs/STAC.html , https://documentation.dataspace.copernicus.eu/APIs/OData.html , https://element84.com/earth-search/ |

## Requests

### CDSE STAC search

| Parameter | Required | Description | Example |
|---|---|---|---|
| `collections` | yes | Collection ID | `["sentinel-2-l2a"]` |
| `intersects` / `bbox` | one required | GeoJSON geometry or `[minx,miny,maxx,maxy]` | `{"type":"Point","coordinates":[-97.5,40.95]}` |
| `datetime` | no | RFC 3339 interval | `2025-07-01T00:00:00Z/2025-07-31T23:59:59Z` |
| `sortby` | no | Sort; CDSE uses `properties.` prefixed field names | `[{"field":"properties.eo:cloud_cover","direction":"asc"}]` |
| `filter` / `filter-lang` | no | CQL2 filter (e.g. `eo:cloud_cover < 20`) | `{"op":"<","args":[{"property":"eo:cloud_cover"},20]}` with `cql2-json` |
| `limit` | no | Page size | `5` |

```
POST https://stac.dataspace.copernicus.eu/v1/search
Content-Type: application/json

{"collections":["sentinel-2-l2a"],
 "intersects":{"type":"Point","coordinates":[-97.5,40.95]},
 "datetime":"2025-07-01T00:00:00Z/2025-07-31T23:59:59Z",
 "limit":5,
 "sortby":[{"field":"properties.eo:cloud_cover","direction":"asc"}]}
```

### Sample response (Captured 2026-11-14)

Trimmed: 4 of 5 features removed (listed below); in the kept feature only assets `B04_10m` and `SCL_20m` kept (asset key list below), `geometry`, `links`, `bbox` and `stac_extensions` removed.

```json
{
  "type": "FeatureCollection",
  "numberReturned": 5,
  "features": [{
    "id": "S2A_MSIL2A_20250702T172721_N0511_R012_T14TPL_20250702T224101",
    "collection": "sentinel-2-l2a",
    "properties": {
      "gsd": 10,
      "created": "2025-07-02T23:31:56.000000Z",
      "updated": "2025-07-02T23:38:04.468637Z",
      "datetime": "2025-07-02T17:27:21.024Z",
      "platform": "sentinel-2a",
      "grid:code": "MGRS-14TPL",
      "published": "2025-07-02T23:38:04.468637Z",
      "statistics": {"water": 0.512812, "nodata": 0.0, "dark_area": 0.04426, "vegetation": 91.507107, "thin_cirrus": 0.022014,
                     "cloud_shadow": 0.702071, "unclassified": 0.382733, "not_vegetated": 4.876185, "high_proba_clouds": 0.903484,
                     "medium_proba_clouds": 1.049333, "saturated_defective": 0.0},
      "instruments": ["msi"],
      "auth:schemes": {"s3": {"type": "s3"}, "oidc": {"type": "openIdConnect", "openIdConnectUrl": "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/.well-known/openid-configuration"}},
      "end_datetime": "2025-07-02T17:27:21.024Z",
      "product:type": "S2MSI2A",
      "view:azimuth": 285.51808168202024,
      "constellation": "sentinel-2",
      "eo:snow_cover": 0.0,
      "eo:cloud_cover": 1.974831,
      "start_datetime": "2025-07-02T17:27:21.024Z",
      "sat:orbit_state": "descending",
      "eopf:datatake_id": "GS2A_20250702T172721_052376_N05.11",
      "processing:level": "L2",
      "view:sun_azimuth": 140.512980254067,
      "processing:version": "05.11",
      "product:timeliness": "PT24H",
      "sat:absolute_orbit": 52376,
      "sat:relative_orbit": 12,
      "view:sun_elevation": 67.9675051673748,
      "view:incidence_angle": 6.461747110189488,
      "product:timeliness_category": "NRT"
    },
    "assets": {
      "B04_10m": {
        "href": "s3://eodata/Sentinel-2/MSI/L2A/2025/07/02/S2A_MSIL2A_20250702T172721_N0511_R012_T14TPL_20250702T224101.SAFE/GRANULE/L2A_T14TPL_A052376_20250702T172723/IMG_DATA/R10m/T14TPL_20250702T172721_B04_10m.jp2",
        "alternate": {"https": {
          "href": "https://zipper.dataspace.copernicus.eu/odata/v1/Products(a6ddc254-680f-4c1a-85db-da12e46f218b)/Nodes(S2A_MSIL2A_20250702T172721_N0511_R012_T14TPL_20250702T224101.SAFE)/Nodes(GRANULE)/Nodes(L2A_T14TPL_A052376_20250702T172723)/Nodes(IMG_DATA)/Nodes(R10m)/Nodes(T14TPL_20250702T172721_B04_10m.jp2)/$value",
          "auth:refs": ["oidc"]}},
        "bands": [{"name": "B04", "description": "Red (band 4)", "eo:common_name": "red", "eo:center_wavelength": 0.665, "eo:full_width_half_max": 0.342}],
        "type": "image/jp2",
        "roles": ["data", "reflectance", "sampling:original", "gsd:10m"],
        "gsd": 10,
        "nodata": 0,
        "data_type": "uint16",
        "raster:scale": 0.0001,
        "raster:offset": -0.1,
        "proj:code": "EPSG:32614",
        "proj:shape": [10980, 10980],
        "proj:bbox": [600000, 4490220, 709800, 4600020],
        "file:size": 108129137,
        "auth:refs": ["s3"],
        "storage:refs": ["cdse-s3", "creodias-s3"]
      },
      "SCL_20m": {
        "href": "s3://eodata/Sentinel-2/MSI/L2A/2025/07/02/S2A_MSIL2A_20250702T172721_N0511_R012_T14TPL_20250702T224101.SAFE/GRANULE/L2A_T14TPL_A052376_20250702T172723/IMG_DATA/R20m/T14TPL_20250702T172721_SCL_20m.jp2",
        "title": "Scene classification map (SCL) - 20m",
        "type": "image/jp2",
        "gsd": 20,
        "nodata": 0,
        "data_type": "uint8",
        "classification:classes": [
          {"value": 0, "name": "no_data", "nodata": true, "percentage": 0.0},
          {"value": 1, "name": "saturated_or_defective", "percentage": 0.0},
          {"value": 2, "name": "dark_area_pixels", "percentage": 0.04426},
          {"value": 3, "name": "cloud_shadows", "percentage": 0.702071},
          {"value": 4, "name": "vegetation", "percentage": 91.507107},
          {"value": 5, "name": "not_vegetated", "percentage": 4.876185},
          {"value": 6, "name": "water", "percentage": 0.512812},
          {"value": 7, "name": "unclassified", "percentage": 0.382733},
          {"value": 8, "name": "cloud_medium_probability", "percentage": 1.049333},
          {"value": 9, "name": "cloud_high_probability", "percentage": 0.903484},
          {"value": 10, "name": "thin_cirrus", "percentage": 0.022014},
          {"value": 11, "name": "snow", "percentage": 0.0}
        ]
      }
    }
  }],
  "links": [{"rel": "next"}, {"rel": "root"}, {"rel": "self"}]
}
```

All 5 features (id, datetime, eo:cloud_cover):

```
S2A_MSIL2A_20250702T172721_N0511_R012_T14TPL_20250702T224101  2025-07-02T17:27:21.024Z   1.974831
S2C_MSIL2A_20250720T171921_N0511_R012_T14TPL_20250720T221316  2025-07-20T17:19:21.025Z   6.733511
S2B_MSIL2A_20250705T171859_N0511_R012_T14TPL_20250705T205335  2025-07-05T17:18:59.024Z   8.685502
S2B_MSIL2A_20250715T171859_N0511_R012_T14TPL_20250715T205353  2025-07-15T17:18:59.024Z  15.341257
S2A_MSIL2A_20250722T172731_N0511_R012_T14TPL_20250722T222519  2025-07-22T17:27:31.024Z  74.652439
```

CDSE asset keys: `AOT_10m/20m/60m`, `B01_20m/60m`, `B02_10m/20m/60m`, `B03_10m/20m/60m`, `B04_10m/20m/60m`, `B05_20m/60m`, `B06_20m/60m`, `B07_20m/60m`, `B08_10m`, `B8A_20m/60m`, `B09_60m`, `B11_20m/60m`, `B12_20m/60m`, `SCL_20m/60m`, `TCI_10m/20m/60m`, `WVP_10m/20m/60m`, `Product`, `thumbnail`, `safe_manifest`, `granule_metadata`, `inspire_metadata`, `product_metadata`, `datastrip_metadata`.

### CDSE OData catalogue query

| Parameter | Required | Description | Example |
|---|---|---|---|
| `$filter` | yes | OData filter: collection, attributes, geography, dates | see request |
| `$orderby` | no | Sort | `ContentDate/Start asc` |
| `$top` | no | Max results (page size) | `3` |
| `$skip` | no | Offset | `0` |
| `$expand` | no | `Attributes` to include product attributes | `Attributes` |
| `$count` | no | `True` to include total count | `True` |

Filter clauses used: `Collection/Name eq 'SENTINEL-2'`; `Attributes/OData.CSC.StringAttribute/any(att:att/Name eq 'productType' and att/OData.CSC.StringAttribute/Value eq 'S2MSI2A')`; `OData.CSC.Intersects(area=geography'SRID=4326;POINT(-97.5 40.95)')`; `ContentDate/Start gt 2025-07-01T00:00:00.000Z and ContentDate/Start lt 2025-08-01T00:00:00.000Z`; `Attributes/OData.CSC.DoubleAttribute/any(att:att/Name eq 'cloudCover' and att/OData.CSC.DoubleAttribute/Value le 20.00)`.

```
GET https://catalogue.dataspace.copernicus.eu/odata/v1/Products?$filter=Collection/Name%20eq%20'SENTINEL-2'%20and%20Attributes/OData.CSC.StringAttribute/any(att:att/Name%20eq%20'productType'%20and%20att/OData.CSC.StringAttribute/Value%20eq%20'S2MSI2A')%20and%20OData.CSC.Intersects(area%3Dgeography'SRID%3D4326%3BPOINT(-97.5%2040.95)')%20and%20ContentDate/Start%20gt%202025-07-01T00:00:00.000Z%20and%20ContentDate/Start%20lt%202025-08-01T00:00:00.000Z%20and%20Attributes/OData.CSC.DoubleAttribute/any(att:att/Name%20eq%20'cloudCover'%20and%20att/OData.CSC.DoubleAttribute/Value%20le%2020.00)&$orderby=ContentDate/Start%20asc&$top=3&$expand=Attributes
```

### Sample response (Captured 2026-11-14)

Trimmed: 2 of 3 products removed, `@odata.context` and `@odata.nextLink` shortened, `Attributes` objects reduced to `Name`/`Value` pairs (each also carries `@odata.type` and `ValueType`).

```json
{
  "@odata.context": "$metadata#Products(Attributes())",
  "value": [{
    "@odata.mediaContentType": "application/octet-stream",
    "Id": "a6ddc254-680f-4c1a-85db-da12e46f218b",
    "Name": "S2A_MSIL2A_20250702T172721_N0511_R012_T14TPL_20250702T224101.SAFE",
    "ContentType": "application/octet-stream",
    "ContentLength": 1132027354,
    "OriginDate": "2025-07-02T23:31:56.000000Z",
    "PublicationDate": "2025-07-02T23:38:04.468637Z",
    "ModificationDate": "2025-07-02T23:38:04.468637Z",
    "Online": true,
    "EvictionDate": "9999-12-31T23:59:59.999999Z",
    "S3Path": "/eodata/Sentinel-2/MSI/L2A/2025/07/02/S2A_MSIL2A_20250702T172721_N0511_R012_T14TPL_20250702T224101.SAFE",
    "Checksum": [
      {"Value": "170d65e8881e5a7e88a88d2a4cd3a10d", "Algorithm": "MD5", "ChecksumDate": "2025-07-02T23:38:01.431928Z"},
      {"Value": "4031baf336e4005e7196367aa5ab90f3f21e3f2adb4f3fa4e850ec94e8cf096d", "Algorithm": "BLAKE3", "ChecksumDate": "2025-07-02T23:38:03.449662Z"}
    ],
    "ContentDate": {"Start": "2025-07-02T17:27:21.024000Z", "End": "2025-07-02T17:27:21.024000Z"},
    "Footprint": "geography'SRID=4326;POLYGON ((-97.8010303852103 41.545593768972765, -97.81885207154318 40.55671174263467, -96.52280187838811 40.536185528423594, -96.48546160940654 41.52434469691515, -97.8010303852103 41.545593768972765))'",
    "GeoFootprint": {"type": "Polygon", "coordinates": [[[-97.8010303852103, 41.545593768972765], [-97.81885207154318, 40.55671174263467], [-96.52280187838811, 40.536185528423594], [-96.48546160940654, 41.52434469691515], [-97.8010303852103, 41.545593768972765]]]},
    "Attributes": [
      {"Name": "origin", "Value": "ESA"},
      {"Name": "tileId", "Value": "14TPL"},
      {"Name": "cloudCover", "Value": 1.974831},
      {"Name": "orbitNumber", "Value": 52376},
      {"Name": "relativeOrbitNumber", "Value": 12},
      {"Name": "processingDate", "Value": "2025-07-02T22:41:01.000000Z"},
      {"Name": "productGroupId", "Value": "GS2A_20250702T172721_052376_N05.11"},
      {"Name": "operationalMode", "Value": "INS-NOBS"},
      {"Name": "processingLevel", "Value": "S2MSI2A"},
      {"Name": "processorVersion", "Value": "05.11"},
      {"Name": "granuleIdentifier", "Value": "S2A_OPER_MSI_L2A_TL_2APS_20250702T224101_A052376_T14TPL_N05.11"},
      {"Name": "datastripId", "Value": "S2A_OPER_MSI_L2A_DS_2APS_20250702T224101_S20250702T172723_N05.11"},
      {"Name": "platformShortName", "Value": "SENTINEL-2"},
      {"Name": "instrumentShortName", "Value": "MSI"},
      {"Name": "platformSerialIdentifier", "Value": "A"},
      {"Name": "productType", "Value": "S2MSI2A"},
      {"Name": "beginningDateTime", "Value": "2025-07-02T17:27:21.024000Z"},
      {"Name": "endingDateTime", "Value": "2025-07-02T17:27:21.024000Z"}
    ]
  }],
  "@odata.nextLink": "https://catalogue.dataspace.copernicus.eu/odata/v1/Products?...&$skip=3"
}
```

Product download (`https://zipper.dataspace.copernicus.eu/odata/v1/Products(<Id>)/$value`) requires a CDSE access token.

### Earth Search STAC search

| Parameter | Required | Description | Example |
|---|---|---|---|
| `collections` | yes | Collection ID | `["sentinel-2-l2a"]` (also `sentinel-2-c1-l2a`) |
| `intersects` / `bbox` | one required | Geometry | `{"type":"Point","coordinates":[-97.5,40.95]}` |
| `datetime` | no | RFC 3339 interval | `2025-07-01T00:00:00Z/2025-07-31T23:59:59Z` |
| `query` | no | Property filter | `{"eo:cloud_cover":{"lt":20}}` |
| `limit` | no | Page size | `5` |

```
POST https://earth-search.aws.element84.com/v1/search
Content-Type: application/json

{"collections":["sentinel-2-l2a"],
 "intersects":{"type":"Point","coordinates":[-97.5,40.95]},
 "datetime":"2025-07-01T00:00:00Z/2025-07-31T23:59:59Z",
 "query":{"eo:cloud_cover":{"lt":20}},
 "limit":5}
```

### Sample response (Captured 2026-11-14)

Trimmed: 3 of 4 features removed (listed below); in the kept feature only assets `red` and `scl` kept (asset key list below), `geometry`, `bbox`, `links` removed.

```json
{
  "type": "FeatureCollection",
  "context": {"limit": 5, "matched": 4, "returned": 4},
  "numberMatched": 4,
  "numberReturned": 4,
  "features": [{
    "id": "S2A_14TPL_20250702_1_L2A",
    "collection": "sentinel-2-l2a",
    "properties": {
      "created": "2025-07-03T00:09:49.710Z",
      "platform": "sentinel-2a",
      "constellation": "sentinel-2",
      "instruments": ["msi"],
      "eo:cloud_cover": 1.974831,
      "proj:epsg": 32614,
      "proj:centroid": {"lat": 41.04194, "lon": -97.15705},
      "mgrs:utm_zone": 14,
      "mgrs:latitude_band": "T",
      "mgrs:grid_square": "PL",
      "grid:code": "MGRS-14TPL",
      "view:azimuth": 285.4866898202937,
      "view:incidence_angle": 6.4553943253445185,
      "view:sun_azimuth": 140.512980254067,
      "view:sun_elevation": 67.9675051673748,
      "s2:tile_id": "S2A_OPER_MSI_L2A_TL_2APS_20250702T224101_A052376_T14TPL_N05.11",
      "s2:degraded_msi_data_percentage": 0.0225,
      "s2:nodata_pixel_percentage": 0,
      "s2:saturated_defective_pixel_percentage": 0,
      "s2:cloud_shadow_percentage": 0.702071,
      "s2:vegetation_percentage": 91.507107,
      "s2:not_vegetated_percentage": 4.876185,
      "s2:water_percentage": 0.512812,
      "s2:unclassified_percentage": 0.382733,
      "s2:medium_proba_clouds_percentage": 1.049333,
      "s2:high_proba_clouds_percentage": 0.903484,
      "s2:thin_cirrus_percentage": 0.022014,
      "s2:snow_ice_percentage": 0,
      "s2:product_type": "S2MSI2A",
      "s2:processing_baseline": "05.11",
      "s2:product_uri": "S2A_MSIL2A_20250702T172721_N0511_R012_T14TPL_20250702T224101.SAFE",
      "s2:generation_time": "2025-07-02T22:41:01.000000Z",
      "s2:datatake_id": "GS2A_20250702T172721_052376_N05.11",
      "s2:datatake_type": "INS-NOBS",
      "s2:reflectance_conversion_factor": 0.967532641120893,
      "datetime": "2025-07-02T17:32:43.590000Z",
      "s2:sequence": "1",
      "earthsearch:s3_path": "s3://sentinel-cogs/sentinel-s2-l2a-cogs/14/T/PL/2025/7/S2A_14TPL_20250702_1_L2A",
      "earthsearch:boa_offset_applied": true,
      "updated": "2025-07-03T00:09:49.710Z"
    },
    "assets": {
      "red": {
        "href": "https://sentinel-cogs.s3.us-west-2.amazonaws.com/sentinel-s2-l2a-cogs/14/T/PL/2025/7/S2A_14TPL_20250702_1_L2A/B04.tif",
        "type": "image/tiff; application=geotiff; profile=cloud-optimized",
        "title": "Red - 10m",
        "eo:bands": [{"name": "B04", "common_name": "red", "center_wavelength": 0.665, "full_width_half_max": 0.038}],
        "gsd": 10,
        "proj:shape": [10980, 10980],
        "proj:transform": [10, 0, 600000, 0, -10, 4600020],
        "raster:bands": [{"nodata": 0, "data_type": "uint16", "spatial_resolution": 10, "scale": 0.0001, "offset": -0.1}],
        "roles": ["data", "reflectance"]
      },
      "scl": {
        "href": "https://sentinel-cogs.s3.us-west-2.amazonaws.com/sentinel-s2-l2a-cogs/14/T/PL/2025/7/S2A_14TPL_20250702_1_L2A/SCL.tif",
        "type": "image/tiff; application=geotiff; profile=cloud-optimized",
        "title": "Scene classification map (SCL)",
        "gsd": 20,
        "raster:bands": [{"nodata": 0, "data_type": "uint8", "spatial_resolution": 20}],
        "roles": ["data"]
      }
    }
  }]
}
```

All 4 features (id, datetime, eo:cloud_cover):

```
S2C_14TPL_20250720_0_L2A  2025-07-20T17:32:49.050000Z   6.733511
S2B_14TPL_20250715_0_L2A  2025-07-15T17:32:29.369000Z  15.341257
S2B_14TPL_20250705_0_L2A  2025-07-05T17:32:29.397000Z   8.685502
S2A_14TPL_20250702_1_L2A  2025-07-02T17:32:43.590000Z   1.974831
```

Earth Search asset keys: `coastal`, `blue`, `green`, `red`, `rededge1`, `rededge2`, `rededge3`, `nir`, `nir08`, `nir09`, `swir16`, `swir22`, `aot`, `wvp`, `scl`, `cloud`, `snow`, `visual`, `thumbnail`, `granule_metadata`, `product_metadata`, `tileinfo_metadata`, and `-jp2` variants of each band.

### Microsoft Planetary Computer: STAC search and point values

No account or key. Search with the STAC API, then read values at a point from the data API (TiTiler), which computes band expressions server side. Imagery is never downloaded. Asset hrefs on `sentinel2l2a01.blob.core.windows.net` would need an anonymous SAS token (`/api/sas/v1/token/sentinel-2-l2a`), but the point endpoint does not.

```
POST https://planetarycomputer.microsoft.com/api/stac/v1/search
Content-Type: application/json

{"collections": ["sentinel-2-l2a"],
 "intersects": {"type": "Point", "coordinates": [-97.50, 40.95]},
 "datetime": "2025-07-01T00:00:00Z/2025-08-31T23:59:59Z",
 "query": {"eo:cloud_cover": {"lt": 30}},
 "sortby": [{"field": "properties.eo:cloud_cover", "direction": "asc"}],
 "limit": 8}
```

```
GET https://planetarycomputer.microsoft.com/api/data/v1/item/point/{lon},{lat}
    ?collection=sentinel-2-l2a&item={item id}&expression={band math}&asset_as_band=false
```

Expressions name bands as `<asset>_b1`: NDVI is `(B08_b1-B04_b1)/(B08_b1+B04_b1)`, and the scene classification at the pixel is `SCL_b1`. Values are raw digital numbers unless `unscale=true`; NDVI is a ratio, so the L2A offset mostly cancels.

### Sample responses (Captured 2026-11-15)

STAC search over the reference point with a GET bbox (`bbox=-97.5005,40.9495,-97.4995,40.9505`, no cloud filter, `limit=5`). Only id, datetime and `eo:cloud_cover` are shown:

| id | datetime | eo:cloud_cover |
|---|---|---|
| S2A_MSIL2A_20250831T172721_R012_T14TPL_20250831T223114 | 2025-08-31T17:27:21.024000Z | 99.92 |
| S2C_MSIL2A_20250829T171911_R012_T14TPL_20250829T223813 | 2025-08-29T17:19:11.025000Z | 73.95 |
| S2B_MSIL2A_20250824T171859_R012_T14TPL_20250824T211839 | 2025-08-24T17:18:59.024000Z | 81.19 |
| S2C_MSIL2A_20250819T171911_R012_T14TPL_20250819T222514 | 2025-08-19T17:19:11.025000Z | 26.67 |
| S2B_MSIL2A_20250814T171859_R012_T14TPL_20250814T205709 | 2025-08-14T17:18:59.024000Z | 13.75 |

Item assets: `AOT, B01, B02, B03, B04, B05, B06, B07, B08, B09, B11, B12, B8A, SCL, WVP, visual`, metadata files, `tilejson`, `rendered_preview`.

NDVI at the point on the 2025-08-14 scene (complete response):

```json
{"coordinates":[-97.5,40.95],"values":[0.6402918872513951],"band_names":["(B08_b1-B04_b1)/(B08_b1+B04_b1)"]}
```

Implemented in the app as `PlanetaryComputer::Client` (`docs/INTEGRATIONS.md`). Its NDVI series reads `SCL_b1` first and keeps only clear pixels (4 vegetation, 5 not vegetated, 6 water).

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `id` | string | | CDSE: ESA product name `S2X_MSIL2A_<sensing>_N<baseline>_R<rel orbit>_T<tile>_<generation>`; Earth Search: `S2X_<tile>_<date>_<seq>_L2A` |
| `properties.datetime` | string | UTC | CDSE: datatake sensing start; Earth Search: tile sensing time |
| `properties.eo:cloud_cover` | number | % | Tile cloud cover (identical in both catalogues) |
| `properties.grid:code` | string | | MGRS tile (`MGRS-14TPL`) |
| `properties.processing:version` / `s2:processing_baseline` | string | | ESA processing baseline (`05.11`) |
| `properties.statistics` (CDSE) / `s2:*_percentage` (Earth Search) | number | % | SCL class shares over the tile |
| `properties.sat:relative_orbit` | integer | | Relative orbit (12 for this tile) |
| `properties.view:sun_elevation`, `view:sun_azimuth` | number | degrees | Solar angles |
| `properties.s2:reflectance_conversion_factor` | number | | Earth-Sun distance correction applied by ESA |
| `properties.earthsearch:boa_offset_applied` | boolean | | Earth Search flag on BOA offset handling |
| band asset `raster:scale` / `raster:offset` | number | | reflectance = DN x 0.0001 + (-0.1) as declared in both catalogues for baseline 05.11 |
| band asset `nodata` | integer | | 0 |
| band asset `data_type` | string | | `uint16` (bands), `uint8` (SCL) |
| OData `Id` | string (UUID) | | Product ID used in download URLs |
| OData `ContentLength` | integer | bytes | SAFE product size |
| OData `Online` | boolean | | Product available online |
| OData `S3Path` | string | | Path on CDSE `eodata` S3 |
| OData `Attributes[]` | array | | `Name`/`Value` pairs (`cloudCover`, `tileId`, `relativeOrbitNumber`, `processorVersion`, ...) |

SCL classes: 0 no_data, 1 saturated_or_defective, 2 dark_area_pixels, 3 cloud_shadows, 4 vegetation, 5 not_vegetated, 6 water, 7 unclassified, 8 cloud_medium_probability, 9 cloud_high_probability, 10 thin_cirrus, 11 snow.

Band centre wavelengths (um, from captured items): B01 0.443, B02 0.490, B03 0.560, B04 0.665, B05 0.705, B06 0.740, B07 0.783, B08 0.842, B8A 0.865, B09 0.945, B11 1.610, B12 2.190.

## Notes

- Since processing baseline 04.00 (January 2022), ESA L2A digital numbers include a +1000 offset (`BOA_ADD_OFFSET`); both catalogues express this as `offset: -0.1` with `scale: 0.0001`.
- The same acquisition has different `datetime` values in the two catalogues (CDSE 17:27:21, Earth Search 17:32:43) because CDSE uses datatake start and Earth Search uses tile sensing time.
- Earth Search's cloud-cover filter excluded the 2025-07-22 scene (74.65%); CDSE returned it because no cloud filter was set in that request.
- Earth Search `numberMatched` was 4 but the response still carried a `next` link.
- The CDSE STAC `sortby` field must be prefixed with `properties.`.
- CDSE asset `href` values are `s3://eodata/...` (CDSE S3, credentials needed); the HTTPS alternate on `zipper.dataspace.copernicus.eu` requires an OIDC token (`auth:refs: ["oidc"]`).
- The reference point is in MGRS tile 14TPL, relative orbit 12; no other tile was returned.

## Documentation

- CDSE STAC API: https://documentation.dataspace.copernicus.eu/APIs/STAC.html
- CDSE OData API: https://documentation.dataspace.copernicus.eu/APIs/OData.html
- CDSE S3 access: https://documentation.dataspace.copernicus.eu/APIs/S3.html
- Earth Search: https://element84.com/earth-search/ ; STAC root: https://earth-search.aws.element84.com/v1
- AWS Registry, Sentinel-2 COGs: https://registry.opendata.aws/sentinel-2-l2a-cogs/
- Sentinel-2 L2A product description (ESA SentiWiki): https://sentiwiki.copernicus.eu/web/s2-processing
- Planetary Computer Sentinel-2 L2A: https://planetarycomputer.microsoft.com/dataset/sentinel-2-l2a ; data API (TiTiler) reference: https://planetarycomputer.microsoft.com/api/data/v1/docs
- Copernicus data licence (free, full and open): https://sentinels.copernicus.eu/documents/247904/690755/Sentinel_Data_Legal_Notice
