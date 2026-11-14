# NAIP aerial imagery (National Agriculture Imagery Program)

NAIP is leaf-on aerial orthoimagery of the conterminous United States acquired during the agricultural growing season by the USDA Farm Service Agency (FSA) and distributed by the USDA Aerial Photography Field Office (APFO). Current acquisitions are 4-band (red, green, blue, near-infrared), 8-bit, at 0.6 m (older years 1 m; some states 0.3 m), delivered as Digital Ortho Quarter Quad (DOQQ) tiles in UTM/NAD83. Each state is flown on a cycle of about two to three years. Access for a point is through ArcGIS ImageServer services (USDA APFO and USGS The National Map NAIP Plus) and through the Microsoft Planetary Computer STAC API, which indexes NAIP as Cloud Optimized GeoTIFFs from 2010.

| | |
|---|---|
| Provider | USDA FSA / APFO (producer); mirrors by USGS The National Map and Microsoft Planetary Computer |
| Base URL | APFO: `https://gis.apfo.usda.gov/arcgis/rest/services/NAIP/` ; USGS: `https://imagery.nationalmap.gov/arcgis/rest/services/USGSNAIPPlus/ImageServer` ; STAC: `https://planetarycomputer.microsoft.com/api/stac/v1` |
| Auth | none for search and ImageServer; Planetary Computer blob assets need a SAS token from an anonymous token endpoint |
| Formats | JSON (ArcGIS REST, STAC GeoJSON), COG GeoTIFF (Planetary Computer), JPEG 2000 / GeoTIFF downloads (EarthExplorer) |
| Coverage | Conterminous U.S. (Planetary Computer collection bbox also includes Hawaii, Puerto Rico, U.S. Virgin Islands) |
| Resolution | 0.6 m (2016 onward at the reference point), 1 m (2014 at the reference point); collection `gsd` summary: 0.3, 0.6, 1 |
| Cadence / latency | one acquisition per state every 2 to 3 years; Planetary Computer temporal extent 2010-01-01 to 2025-12-31 |
| Rate limits / quotas | not published |
| Documentation | https://www.fsa.usda.gov/programs-and-services/aerial-photography/imagery-programs/naip-imagery/ , https://planetarycomputer.microsoft.com/dataset/naip |

## Requests

### Planetary Computer STAC search

Returns STAC items (one per DOQQ tile and acquisition) intersecting a geometry.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `collections` | yes | Collection ID | `["naip"]` |
| `intersects` | one of `intersects`/`bbox` | GeoJSON geometry | `{"type":"Point","coordinates":[-97.5,40.95]}` |
| `bbox` | one of `intersects`/`bbox` | `[minx,miny,maxx,maxy]` | `[-97.51,40.94,-97.49,40.96]` |
| `datetime` | no | RFC 3339 instant or interval | `2020-01-01T00:00:00Z/2025-12-31T23:59:59Z` |
| `query` | no | Property filter (STAC query extension) | `{"naip:year":{"eq":2022}}` |
| `sortby` | no | Sort fields | `[{"field":"datetime","direction":"desc"}]` |
| `limit` | no | Page size | `10` |
| `token` | no | Paging token taken from the `next` link body | `next:naip:...` |

```
POST https://planetarycomputer.microsoft.com/api/stac/v1/search
Content-Type: application/json

{"collections":["naip"],
 "intersects":{"type":"Point","coordinates":[-97.5,40.95]},
 "limit":10,
 "sortby":[{"field":"datetime","direction":"desc"}]}
```

### Sample response (Captured 2026-11-14)

Trimmed: 9 of 10 features removed (listed below), `geometry` coordinates kept, `_msft:etag` kept.

```json
{
  "type": "FeatureCollection",
  "numberReturned": 10,
  "features": [{
    "id": "ne_m_4009705_nw_14_060_20220804",
    "bbox": [-97.505024, 40.934411, -97.431906, 41.00358],
    "type": "Feature",
    "collection": "naip",
    "geometry": {"type": "Polygon", "coordinates": [[[-97.43352,40.934411],[-97.431906,41.002628],[-97.503483,41.00358],[-97.505024,40.93536],[-97.43352,40.934411]]]},
    "properties": {
      "gsd": 0.6,
      "datetime": "2022-08-04T16:00:00Z",
      "naip:year": 2022,
      "naip:state": "ne",
      "proj:bbox": [625854.6, 4532657.4, 631876.2, 4540233.0],
      "proj:epsg": 26914,
      "proj:shape": [12626, 10036],
      "proj:centroid": {"lat": 40.969, "lon": -97.46848},
      "proj:transform": [0.6, 0.0, 625854.6, 0.0, -0.6, 4540233.0, 0.0, 0.0, 1.0],
      "providers": [{"url": "https://www.fsa.usda.gov/programs-and-services/aerial-photography/imagery-programs/naip-imagery/", "name": "USDA Farm Service Agency", "roles": ["producer", "licensor"]}]
    },
    "assets": {
      "image": {
        "href": "https://naipeuwest.blob.core.windows.net/naip/v002/ne/2022/ne_060cm_2022/40097/m_4009705_nw_14_060_20220804.tif",
        "type": "image/tiff; application=geotiff; profile=cloud-optimized",
        "roles": ["data"],
        "title": "RGBIR COG tile",
        "eo:bands": [
          {"name": "Red", "common_name": "red"},
          {"name": "Green", "common_name": "green"},
          {"name": "Blue", "common_name": "blue"},
          {"name": "NIR", "common_name": "nir", "description": "near-infrared"}
        ]
      },
      "tilejson": {"href": "https://planetarycomputer.microsoft.com/api/data/v1/item/tilejson.json?collection=naip&item=ne_m_4009705_nw_14_060_20220804&assets=image&asset_bidx=image%7C1%2C2%2C3", "type": "application/json", "roles": ["tiles"]},
      "thumbnail": {"href": "https://naipeuwest.blob.core.windows.net/naip/v002/ne/2022/ne_060cm_2022/40097/m_4009705_nw_14_060_20220804.200.jpg", "type": "image/jpeg", "roles": ["thumbnail"]},
      "rendered_preview": {"href": "https://planetarycomputer.microsoft.com/api/data/v1/item/preview.png?collection=naip&item=ne_m_4009705_nw_14_060_20220804&assets=image&asset_bidx=image%7C1%2C2%2C3", "type": "image/png", "roles": ["overview"]}
    },
    "links": [
      {"rel": "self", "href": "https://planetarycomputer.microsoft.com/api/stac/v1/collections/naip/items/ne_m_4009705_nw_14_060_20220804"},
      {"rel": "preview", "href": "https://planetarycomputer.microsoft.com/api/data/v1/item/map?collection=naip&item=ne_m_4009705_nw_14_060_20220804", "type": "text/html"}
    ],
    "stac_version": "1.0.0",
    "stac_extensions": ["https://stac-extensions.github.io/eo/v1.0.0/schema.json", "https://stac-extensions.github.io/projection/v1.0.0/schema.json"]
  }],
  "links": [
    {"rel": "next", "method": "POST", "href": "https://planetarycomputer.microsoft.com/api/stac/v1/search?collections=naip",
     "body": {"collections": ["naip"], "intersects": {"type": "Point", "coordinates": [-97.5, 40.95]}, "limit": 10,
              "sortby": [{"field": "datetime", "direction": "desc"}], "token": "next:naip:ne_m_4009704_ne_14_1_20140813_20141028"}}
  ]
}
```

All 10 item IDs returned (id, datetime, gsd):

```
ne_m_4009705_nw_14_060_20220804            2022-08-04T16:00:00Z  0.6
ne_m_4009704_ne_14_060_20220804            2022-08-04T16:00:00Z  0.6
ne_m_4009705_nw_14_060_20200712            2020-07-12T00:00:00Z  0.6
ne_m_4009704_ne_14_060_20200712            2020-07-12T00:00:00Z  0.6
ne_m_4009705_nw_14_060_20180709_20181210   2018-07-09T00:00:00Z  0.6
ne_m_4009704_ne_14_060_20180709_20181210   2018-07-09T00:00:00Z  0.6
ne_m_4009704_ne_14_.6_20160813_20161019    2016-08-13T00:00:00Z  0.6
ne_m_4009705_nw_14_.6_20160720_20161019    2016-07-20T00:00:00Z  0.6000000000000046
ne_m_4009705_nw_14_1_20140813_20141028     2014-08-13T00:00:00Z  1.0
ne_m_4009704_ne_14_1_20140813_20141028     2014-08-13T00:00:00Z  1.0
```

### Planetary Computer SAS token

Returns a short-lived read token to append to `naipeuwest.blob.core.windows.net` asset URLs.

| Parameter | Required | Description | Example |
|---|---|---|---|
| collection (path) | yes | Collection ID | `naip` |

```
GET https://planetarycomputer.microsoft.com/api/sas/v1/token/naip
```

### Sample response (Captured 2026-11-14)

Token value redacted.

```json
{"msft:expiry": "2026-11-14T23:18:30Z", "token": "st=2026-11-13T23%3A0...<redacted>"}
```

### USGS NAIP Plus ImageServer catalog query

Returns catalog records (tile name, state, year, acquisition date, resolution, EarthExplorer download link) for tiles under a point.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `where` | no | SQL filter; `Category=1` selects primary images (excludes overviews) | `Category=1` |
| `geometry` | yes | ArcGIS JSON point | `{"x":-97.5,"y":40.95,"spatialReference":{"wkid":4326}}` |
| `geometryType` | yes | Geometry type | `esriGeometryPoint` |
| `inSR` | no | Input spatial reference | `4326` |
| `spatialRel` | no | Spatial relationship | `esriSpatialRelIntersects` |
| `outFields` | no | Fields to return | `Name,State,Year,acquisition_date,resolution_value,resolution_units,band_count,sensor_type,download_url,projection_zone` |
| `returnGeometry` | no | Include footprints | `false` |
| `orderByFields` | no | Sort | `Year DESC` |
| `f` | yes | Format | `json` |

```
GET https://imagery.nationalmap.gov/arcgis/rest/services/USGSNAIPPlus/ImageServer/query
  ?where=Category%3D1
  &geometry=%7B%22x%22%3A-97.5%2C%22y%22%3A40.95%2C%22spatialReference%22%3A%7B%22wkid%22%3A4326%7D%7D
  &geometryType=esriGeometryPoint&inSR=4326&spatialRel=esriSpatialRelIntersects
  &outFields=Name,State,Year,acquisition_date,resolution_value,resolution_units,band_count,sensor_type,download_url,projection_zone
  &returnGeometry=false&orderByFields=Year%20DESC&f=json
```

### Sample response (Captured 2026-11-14)

Trimmed: `fields` array removed.

```json
{
  "objectIdFieldName": "OBJECTID",
  "features": [
    {"attributes": {"OBJECTID": 119388, "Name": "m_4009704_ne_14_060_20220804", "State": "NE", "Year": 2022, "acquisition_date": 1659571200000, "resolution_value": 0.6, "resolution_units": "METER", "band_count": 4, "sensor_type": "CNIR", "download_url": "https://earthexplorer.usgs.gov/download/options/naip/3253976", "projection_zone": "14N"}},
    {"attributes": {"OBJECTID": 119393, "Name": "m_4009705_nw_14_060_20220804", "State": "NE", "Year": 2022, "acquisition_date": 1659571200000, "resolution_value": 0.6, "resolution_units": "METER", "band_count": 4, "sensor_type": "CNIR", "download_url": "https://earthexplorer.usgs.gov/download/options/naip/3253981", "projection_zone": "14N"}}
  ]
}
```

### USGS NAIP Plus ImageServer identify (pixel values)

Returns the 4-band pixel value at the point and the catalog items that cover it.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `geometry` | yes | ArcGIS JSON point | `{"x":-97.5,"y":40.95,"spatialReference":{"wkid":4326}}` |
| `geometryType` | yes | Geometry type | `esriGeometryPoint` |
| `returnGeometry` | no | Include geometry | `false` |
| `returnCatalogItems` | no | Include catalog items | `true` |
| `f` | yes | Format | `json` |

```
GET https://imagery.nationalmap.gov/arcgis/rest/services/USGSNAIPPlus/ImageServer/identify
  ?geometry=%7B%22x%22%3A-97.5%2C%22y%22%3A40.95%2C%22spatialReference%22%3A%7B%22wkid%22%3A4326%7D%7D
  &geometryType=esriGeometryPoint&returnGeometry=false&returnCatalogItems=true&f=json
```

### Sample response (Captured 2026-11-14)

Trimmed: catalog items reduced to the first primary item and one overview item (response held 2 primary and several overview items).

```json
{
  "objectId": 0,
  "name": "Pixel",
  "value": "66, 91, 75, 134",
  "location": {"x": -10853650.352344174, "y": 5004969.4702303847, "spatialReference": {"wkid": 102100, "latestWkid": 3857}},
  "properties": {"Values": ["66 91 75 134", "70 91 74 139", "74 95 78 133", "73 95 78 137", "73 93 75 140", "85 105 85 134", "109 124 102 117", "108 126 101 113", "96 114 90 125", "80 101 80 138", "80 100 81 147", "83 104 85 153", "79 100 80 156", "85 107 88 150"]},
  "catalogItems": {"objectIdFieldName": "OBJECTID", "features": [
    {"attributes": {"OBJECTID": 119388, "Name": "m_4009704_ne_14_060_20220804", "MinPS": 0, "MaxPS": 19.1, "Category": 1, "State": "NE", "Year": 2022, "raster_name": "m_4009704_ne_14_060_20220804", "download_url": "https://earthexplorer.usgs.gov/download/options/naip/3253976", "acquisition_date": 1659571200000, "agency": "USDA", "vendor": "USDA-FSA-APFO", "resolution_value": 0.6, "resolution_units": "METER", "band_count": 4, "sensor_type": "CNIR", "projection_name": "UTM", "projection_zone": "14N", "datum": "NAD83"}},
    {"attributes": {"OBJECTID": 124678, "Name": "Ov_i02_L01_R00000168_C0000005D.tif", "MinPS": 19.1, "MaxPS": 38.2, "Category": 2, "State": "NE", "Year": 2022, "raster_name": null, "download_url": null, "acquisition_date": null}}
  ]}
}
```

### USDA APFO NAIP ImageServer identify

The APFO services (folder `NAIP`, e.g. the CONUS service `USDA_CONUS_PRIME`) use the same ArcGIS ImageServer `identify` and `query` operations and parameters as above.

```
GET https://gis.apfo.usda.gov/arcgis/rest/services/NAIP/USDA_CONUS_PRIME/ImageServer/identify
  ?geometry=%7B%22x%22%3A-97.5%2C%22y%22%3A40.95%2C%22spatialReference%22%3A%7B%22wkid%22%3A4326%7D%7D
  &geometryType=esriGeometryPoint&returnGeometry=false&returnCatalogItems=true&f=json
```

### Sample response (Representative)

Shape from the Esri ArcGIS REST API "Identify (Image Service)" reference. Pixel values and catalog attribute names are placeholders: the APFO service could not be reached to confirm its catalog fields.

```json
{
  "objectId": 0,
  "name": "Pixel",
  "value": "<band1>, <band2>, <band3>, <band4>",
  "location": {"x": -97.5, "y": 40.95, "spatialReference": {"wkid": 4326}},
  "properties": {"Values": ["<band1> <band2> <band3> <band4>"]},
  "catalogItems": {"objectIdFieldName": "OBJECTID", "features": [{"attributes": {"OBJECTID": 0, "Name": "<raster name>"}}]},
  "catalogItemVisibilities": [1]
}
```

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `id` (STAC) | string | | `<state>_m_<DOQQ id>_<quadrant>_<UTM zone>_<gsd code>_<acq date>[_<processing date>]` |
| `properties.datetime` | string (ISO 8601) | UTC | Acquisition date (time component is nominal) |
| `properties.naip:year` | integer | year | NAIP program year |
| `properties.naip:state` | string | | Two-letter state code, lower case |
| `properties.gsd` | number | m | Ground sample distance |
| `properties.proj:epsg` | integer | | CRS of the COG (26914 = NAD83 / UTM 14N) |
| `properties.proj:shape` | [int,int] | pixels | Rows, columns |
| `properties.proj:transform` | array | m | Affine transform |
| `properties.proj:bbox` | array | m | Footprint bounds in `proj:epsg` |
| `assets.image.href` | string (URL) | | 4-band COG (Red, Green, Blue, NIR), 8-bit |
| `assets.image.eo:bands` | array | | Band order: 1 Red, 2 Green, 3 Blue, 4 NIR |
| `assets.tilejson.href`, `rendered_preview.href` | string (URL) | | Planetary Computer tiler endpoints (RGB bands 1,2,3 by default) |
| `msft:expiry` / `token` (SAS) | string | | Token expiry time and query string to append to blob URLs |
| `value` (identify) | string | DN (0-255) | Comma-separated band values for the top mosaic item |
| `properties.Values` (identify) | array of strings | DN | Values from each overlapping raster / resolution level |
| `Name` / `raster_name` | string | | DOQQ tile name |
| `Year` | integer | year | Acquisition year |
| `acquisition_date` | integer | ms since Unix epoch, UTC | 1659571200000 = 2022-08-04 |
| `resolution_value`, `resolution_units` | number, string | | Pixel size |
| `band_count` | integer | | 4 for CNIR |
| `sensor_type` | string | | `CNIR` (colour plus near-infrared) |
| `download_url` | string (URL) | | EarthExplorer download options page for the tile |
| `Category` | integer | | 1 Primary, 2 Overview (coded value domain) |
| `MinPS`, `MaxPS` | number | m | Pixel-size range at which the item is displayed |
| `projection_name`, `projection_zone`, `datum` | string | | Source projection of the tile |

Pixel values are 8-bit digital numbers (0-255), not reflectance; NAIP has no published radiometric calibration to surface reflectance.

## Notes

- The reference point lies on the boundary of two DOQQ quarter-quads (`m_4009704_ne` and `m_4009705_nw`); STAC and ImageServer both return two tiles per year.
- The latest NAIP year returned for the point by both Planetary Computer and USGS NAIP Plus on 2026-11-14 was 2022 (acquired 2022-08-04). Earlier years available on Planetary Computer: 2020, 2018, 2016 (0.6 m), 2014 (1 m).
- USGS NAIP Plus is a single mosaic exposing only the latest image per location; the query returned 2022 tiles only.
- USGS NAIP Plus returns geometry in Web Mercator (wkid 102100/3857); its `copyrightText` reads "USGS, USDA, The National Map: Orthoimagery. March 12, 2025."
- Planetary Computer documents that blob asset URLs must be signed with a SAS token (not tested without one here); the token endpoint is anonymous and tokens expire (about 24 h in the captured response).
- Planetary Computer collection `license` field is `proprietary`; FSA lists NAIP as public domain.
- Failure: `https://gis.apfo.usda.gov/arcgis/rest/services/NAIP?f=json` and `.../NAIP/USDA_CONUS_PRIME/ImageServer?f=json` failed on 2026-11-14 over HTTPS with `SSLEOFError(8, 'EOF occurred in violation of protocol')` (3 attempts each) and over HTTP with `RemoteDisconnected('Remote end closed connection without response')`. The APFO sample above is Representative.

## Documentation

- USDA FSA NAIP: https://www.fsa.usda.gov/programs-and-services/aerial-photography/imagery-programs/naip-imagery/
- USDA APFO services: https://gis.apfo.usda.gov/arcgis/rest/services/NAIP
- Planetary Computer NAIP dataset: https://planetarycomputer.microsoft.com/dataset/naip
- Planetary Computer STAC API: https://planetarycomputer.microsoft.com/api/stac/v1/collections/naip
- Planetary Computer SAS token docs: https://planetarycomputer.microsoft.com/docs/concepts/sas/
- USGS NAIP Plus ImageServer: https://imagery.nationalmap.gov/arcgis/rest/services/USGSNAIPPlus/ImageServer
- Esri ImageServer identify reference: https://developers.arcgis.com/rest/services-reference/enterprise/identify-image-service/
- STAC API item search specification: https://github.com/radiantearth/stac-api-spec/tree/main/item-search
