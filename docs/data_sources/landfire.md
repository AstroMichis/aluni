# USFS / USGS LANDFIRE

LANDFIRE (Landscape Fire and Resource Management Planning Tools) is a joint U.S. Forest Service and U.S. Department of the Interior program, produced at USGS EROS, that maps existing vegetation type, cover and height, fuels (fire behavior fuel models, canopy metrics), disturbance and topography for the United States at 30 m. Products are released as numbered versions (LF2016 base map, then update versions LF2020, LF2022, LF2023, LF2024, LF2025, plus LF2025 seasonal fuels for 2026). Each layer is a categorical or continuous 30 m raster with a value-to-attribute lookup table published as CSV. Two programmatic routes exist: ArcGIS ImageServer map services (point identify, no login) and the LANDFIRE Product Service (LFPS), an asynchronous clip-and-ship job API that returns a zipped multi-band GeoTIFF.

| | |
|---|---|
| Provider | LANDFIRE program (USDA Forest Service, U.S. Department of the Interior), hosted by USGS EROS |
| Base URL | ImageServer: `https://lfps.usgs.gov/arcgis/rest/services/Landfire_LF2025/` ; LFPS API: `https://lfps.usgs.gov/api/` |
| Auth | none for ImageServer; LFPS job submission requires an `Email` parameter (no account) |
| Formats | JSON (ArcGIS REST), GeoTIFF in ZIP (LFPS), CSV attribute tables, PDF data dictionaries |
| Coverage | CONUS, Alaska, Hawaii, Puerto Rico/U.S. Virgin Islands (varies by product; LF2025 services captured: `_CONUS` and `_AK`) |
| Resolution | 30 m (EPSG:5070 for CONUS services) |
| Cadence / latency | versioned releases (LF2025 latest full version at time of capture; seasonal fuels `_SP26`, `_SU26`, `_ES26`, `_FA26`) |
| Rate limits / quotas | not published; LFPS is scheduled for maintenance the last Wednesday of each month 8 AM to 12 PM CST/CDT (LFPS home page) |
| Documentation | https://lfps.usgs.gov/LFProductsServiceUserGuide.pdf , https://lfps.usgs.gov/docs/api , https://landfire.gov/vegetation/evt |

## Requests

### ImageServer identify (point value)

Returns the pixel value of one LANDFIRE layer at a point. One ImageServer per layer and region: `Landfire_LF2025/LF2025_<ACRONYM>_CONUS/ImageServer`. LF2025 CONUS services listed on 2026-11-14: `CBD`, `CBH`, `CC`, `CH`, `EVC`, `EVH`, `EVT`, `FBFM13`, `FBFM40`, `FCCS`, `FDist`, `FVC`, `FVH`, `FVT`. Other folders: `Landfire_LF2016`, `Landfire_LF2020`, `Landfire_LF2022`, `Landfire_LF2023`, `Landfire_LF2024`, `Landfire_LF2025_Seasonal_Fuels_2026`, `Landfire_Disturbance`, `Landfire_Topo`.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `geometry` | yes | Point as ArcGIS JSON (URL-encoded) | `{"x":-97.5,"y":40.95,"spatialReference":{"wkid":4326}}` |
| `geometryType` | yes | Geometry type | `esriGeometryPoint` |
| `returnGeometry` | no | Include geometry in response | `false` |
| `returnCatalogItems` | no | Include mosaic catalog items | `false` |
| `mosaicRule`, `renderingRule`, `pixelSize`, `time` | no | Standard ArcGIS ImageServer identify options | (omitted) |
| `f` | yes | Response format | `json` |

```
GET https://lfps.usgs.gov/arcgis/rest/services/Landfire_LF2025/LF2025_EVT_CONUS/ImageServer/identify
  ?geometry=%7B%22x%22%3A-97.5%2C%22y%22%3A40.95%2C%22spatialReference%22%3A%7B%22wkid%22%3A4326%7D%7D
  &geometryType=esriGeometryPoint&returnGeometry=false&returnCatalogItems=false&f=json
```

### Sample response (Captured 2026-11-14)

```json
{"objectId":0,"name":"Pixel","value":"7964","location":{"x":-125248.41420643812,"y":1994379.7970459964,"spatialReference":{"wkid":5070,"latestWkid":5070}},"properties":null,"catalogItems":null,"catalogItemVisibilities":[]}
```

Same request against other LF2025 CONUS services, captured 2026-11-14 (only `value` differs):

| Service | `value` | Lookup in that layer's CSV |
|---|---|---|
| `LF2025_EVT_CONUS` | `7964` | Western Cool Temperate Row Crop |
| `LF2025_EVC_CONUS` | `64` | NASS-Row Crop |
| `LF2025_EVH_CONUS` | `64` | NASS-Row Crop |
| `LF2025_FBFM40_CONUS` | `93` | NB3 |
| `LF2025_FVT_CONUS` | `2964` | (code also appears as `EVT_FUEL` = 2964, `EVT_FUEL_N` = "Da Row Crop" in the EVT row) |
| `LF2025_CC_CONUS` | `0` | (forest canopy cover, percent) |

### ImageServer service metadata

Returns pixel type, no-data value, extent and statistics for a layer.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `f` | yes | Response format | `json` |

```
GET https://lfps.usgs.gov/arcgis/rest/services/Landfire_LF2025/LF2025_EVT_CONUS/ImageServer?f=json
```

### Sample response (Captured 2026-11-14)

Trimmed: `fields`, `rasterFunctionInfos`, `rasterTypeInfos`, extents other than `extent`, and capability flags removed.

```json
{
  "currentVersion": 11.1,
  "name": "Landfire_LF2025/LF2025_EVT_CONUS",
  "extent": {"xmin": -2362395, "ymin": 221265, "xmax": 2327655, "ymax": 3267405, "spatialReference": {"wkid": 5070, "latestWkid": 5070}},
  "bandCount": 1,
  "pixelType": "S16",
  "minValues": [7008],
  "maxValues": [9994],
  "pixelSizeX": 30,
  "pixelSizeY": 30,
  "noDataValue": -9999,
  "serviceDataType": "esriImageServiceDataTypeThematic",
  "capabilities": "Image,Metadata,Catalog,Mensuration",
  "defaultResamplingMethod": "Nearest",
  "maxDownloadSizeLimit": 2048,
  "hasRasterAttributeTable": false,
  "spatialReference": {"wkid": 5070, "latestWkid": 5070}
}
```

`/ImageServer/legend?f=json` returns class labels with base64 swatches but no numeric values (e.g. `{"label":"Fill-NoData","values":["Fill-NoData"],...}`, 831 entries for EVT). `/ImageServer/rasterAttributeTable?f=json` returned `{}`. Codes are resolved with the CSV below.

### Attribute table (CSV download)

Static CSV per layer and version mapping `VALUE` to names and attributes.

| Parameter | Required | Description | Example |
|---|---|---|---|
| version (path) | yes | LANDFIRE version | `LF2025` |
| layer (file name) | yes | Layer acronym | `EVT`, `EVC`, `EVH`, `FBFM40` |

```
GET https://landfire.gov/sites/default/files/CSV/LF2025/LF2025_EVT.csv
```

### Sample response (Captured 2026-11-14)

Trimmed to the header and the row for the reference-point value. EVC, EVH and FBFM40 rows shown below the EVT row (each from its own CSV).

```
VALUE,EVT_NAME,LFRDB,EVT_FUEL,EVT_FUEL_N,EVT_LF,EVT_PHYS,EVT_GP,EVT_GP_N,SAF_SRM,EVT_ORDER,EVT_CLASS,EVT_SBCLS,R,G,B,RED,GREEN,BLUE
7964,Western Cool Temperate Row Crop,7964,2964,Da Row Crop,Agriculture,Agricultural,64,Agricultural-Row Crop,LF 80: Agriculture,Herbaceous / Nonvascular-dominated,Herbaceous - grassland,Annual Graminoid/Forb,250,255,119,0.980392,1.000000,0.466667

LF2025_EVC.csv:    VALUE,CLASSNAMES,R,G,B,RED,GREEN,BLUE
                   64,NASS-Row Crop,250,255,119,0.980392,1.000000,0.466667
LF2025_EVH.csv:    64,NASS-Row Crop,250,255,119,0.980392,1.000000,0.466667
LF2025_FBFM40.csv: VALUE,FBFM40,R,G,B,RED,GREEN,BLUE
                   93,NB3,255,237,237,1,0.929412,0.929412
```

### LFPS product list

Returns every layer name the LFPS job API accepts.

```
GET https://lfps.usgs.gov/api/products
```

### Sample response (Captured 2026-11-14)

Trimmed: 3 of 139 entries shown.

```json
{"products":[
 {"productName":"13 Anderson Fire Behavior Fuel Models","theme":"Fuels","layerName":"LF2025_FBFM13","acronym":"FBFM13","version":"LF2025","conus":true,"ak":true,"hi":false,"prvi":false,"geoAreas":"All"},
 {"productName":"40 Scott and Burgan Fire Behavior Fuel Models","theme":"Seasonal Fuels","layerName":"LF2025_FBFM40_SP26","acronym":"FBFM40","version":"LF2025","conus":true,"ak":false,"hi":false,"prvi":false,"geoAreas":""},
 {"productName":"Existing Vegetation Type","theme":"Vegetation","layerName":"LF2025_EVT","acronym":"EVT","version":"LF2025","conus":true,"ak":true,"hi":false,"prvi":false,"geoAreas":"All"}
]}
```

LF2025 CONUS layer names in that list: `LF2025_EVT`, `LF2025_EVC`, `LF2025_EVH` (Vegetation); `LF2025_FBFM13`, `LF2025_FBFM40`, `LF2025_CBH`, `LF2025_CBD`, `LF2025_CC`, `LF2025_CH`, `LF2025_FCCS`, `LF2025_FDist`, `LF2025_FVC`, `LF2025_FVH`, `LF2025_FVT` (Fuels); `LF2025_FBFM40_SP26`, `_SU26`, `_ES26`, `_FA26` (Seasonal Fuels); `LF2025_Dist25`, `LF2025_LDist25`, `LF2025_PDist25` (Disturbance).

### LFPS submit job

Queues a clip of one or more layers to an area of interest; output is a zipped multi-band GeoTIFF.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `Email` | yes | Requester email address | `<required_user_email>` |
| `Layer_List` | yes | Layer names separated by `;`, no spaces, in output band order | `LF2025_EVT;LF2025_EVC;LF2025_EVH` |
| `Area_of_Interest` | yes | `W S E N` in WGS84 separated by spaces, or a LANDFIRE map zone number | `-97.51 40.94 -97.49 40.96` |
| `Include_Layer_List_XML_File` | no | Include layer metadata XML in the ZIP | `false` |
| `Output_Projection` | no | WKID or WKT | `5070` |
| `Resample_Resolution` | no | Output resolution in metres, multiple of 30 (default 30) | `30` |
| `Edit_Rule` | no | JSON edit rules applied to fuel layers | (omitted) |
| `Edit_Mask` | no | JSON array of uploaded shapefile item IDs | (omitted) |
| `Priority_Code` | no | Code provisioned by LANDFIRE for key wildland fire systems | (omitted) |

```
GET https://lfps.usgs.gov/api/job/submit
  ?Email=<required_user_email>
  &Layer_List=LF2025_EVT;LF2025_EVC;LF2025_EVH
  &Area_of_Interest=-97.51%2040.94%20-97.49%2040.96
  &Include_Layer_List_XML_File=false
```

### Sample response (Representative)

Built from the LFPS User Guide v6.1 section 7.1.1 (response parameters `jobId`, `status`); the ID is a placeholder.

```json
{"jobId": "00000000-0000-0000-0000-000000000000", "status": "Pending"}
```

Captured 2026-11-14, same request without `Email` (HTTP 400):

```json
{"message":[{"parameter":"Email","message":"Required"}],"success":false}
```

### LFPS job status

| Parameter | Required | Description | Example |
|---|---|---|---|
| `JobId` | yes | Job queue ID returned by submit (not the Esri job ID) | `00000000-0000-0000-0000-000000000000` |

```
GET https://lfps.usgs.gov/api/job/status?JobId=00000000-0000-0000-0000-000000000000
```

### Sample response (Representative)

Built from the LFPS User Guide v6.1 section 7.1.2 (response parameters `jobId`, `status`, `messages`, `queuePosition`) and section 8.1 message texts. The guide does not print a complete status JSON; field order and the message object keys (`type`, `description`) follow the guide's wording.

```json
{
  "jobId": "00000000-0000-0000-0000-000000000000",
  "status": "Executing",
  "queuePosition": -1,
  "messages": [
    {"type": "<message type>", "description": "Validate AOI coordinates completed."},
    {"type": "<message type>", "description": "Start creating geotif"}
  ]
}
```

Other LFPS endpoints (guide section 7): `GET /api/job/cancel?JobId=<id>` returns `jobId`, `status` = `Canceled`; `POST /api/upload/shapefile` (zip, max 2 MB, deleted after 1 hour) returns `itemId`, `itemName`, `description`, `date`, `committed`; `GET /api/healthCheck`.

### LFPS health check

```
GET https://lfps.usgs.gov/api/healthCheck
```

### Sample response (Captured 2026-11-14)

```json
{"message":"The service is up","success":true}
```

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `value` (identify) | string | layer code | Pixel value at the point; integer code to look up in the layer CSV |
| `location.x`, `location.y` | number | metres, EPSG:5070 | Point projected to the service CRS |
| `name` | string | | Always `Pixel` for a single-band identify |
| EVT `VALUE` | integer | code | Existing Vegetation Type code (range 7008 to 9994 in LF2025 CONUS statistics) |
| EVT `EVT_NAME` | string | | Ecological system or land use name |
| EVT `EVT_LF` | string | | Lifeform (e.g. Agriculture, Tree, Shrub, Herb) |
| EVT `EVT_PHYS` | string | | Physiognomy group (e.g. Agricultural) |
| EVT `EVT_GP`, `EVT_GP_N` | integer, string | | EVT group code and name |
| EVT `EVT_FUEL`, `EVT_FUEL_N` | integer, string | | Fuel vegetation type crosswalk code and name |
| EVT `SAF_SRM` | string | | Society of American Foresters / Society for Range Management cover type |
| EVT `EVT_ORDER`, `EVT_CLASS`, `EVT_SBCLS` | string | | NVC-style order, class, subclass |
| EVT `LFRDB` | integer | | LANDFIRE reference database code |
| `R`,`G`,`B` / `RED`,`GREEN`,`BLUE` | integer / float | 0-255 / 0-1 | Display colour |
| EVC / EVH `CLASSNAMES` | string | % or m | Cover or height class label. Codes 11-69, 82 are land use classes (e.g. 64 NASS-Row Crop, 65 NASS-Close Grown Crop, 68 NASS-Wheat); 100 Sparse Vegetation Canopy; EVC 110-199 tree cover (value minus 100 = %), 210-299 shrub cover, 310-399 herb cover ("Herb Cover >= 99%" at 399); EVH 101+ tree height (1 m steps), 201+ shrub height (0.1 m steps), 301-310 herb height (0.1 m steps, 310 = ">= 1 meter") |
| FBFM40 `FBFM40` | string | | Scott and Burgan fuel model: NB1-NB9 non-burnable (91-99), GR (101-109), GS (121-124), SH (141-149), TU (161-165), TL (181-189), SB (201-204) |
| LFPS `jobId` | string (UUID) | | Job queue ID |
| LFPS `status` | string | | `Pending`, `Executing`, `Succeeded`, `Failed`, `Canceled` |
| LFPS `queuePosition` | integer | | Position in queue; `-1` while executing |
| LFPS `messages[]` | array | | Progress and error messages |

No-data: `-9999` (`Fill-NoData`) in all four CSVs and the EVT service `noDataValue`. FBFM40 code 93 (NB3) is "Agricultural" non-burnable in the Scott and Burgan (2005) system.

## Notes

- Identify responses carry only the numeric code as a string; the ImageServer exposes no raster attribute table (`hasRasterAttributeTable: false`), and the legend endpoint lists labels without codes.
- In agricultural pixels, EVC and EVH carry land-use codes (64 NASS-Row Crop) rather than cover percent or height metres; the crop classes are sourced from USDA NASS (label prefix "NASS-").
- The LFPS submit endpoint requires `Email`; no job was submitted for this document, so submit and status samples are Representative. A submit without `Email` returned HTTP 400 with the JSON shown.
- The LFPS guide states that older versions are removed from LFPS as new versions are released.
- `Area_of_Interest` order is W S E N separated by spaces (URL-encode spaces as `%20`).
- The LFPS GPServer (`https://lfps.usgs.gov/arcgis/rest/services/LandfireProductService/GPServer/LandfireProductService`) is also listed and documents the same parameters (`Layer_List`, `Area_of_Interest`, `Output_Projection`, `Resample_Resolution`, `Edit_Rule`, `Edit_Mask`, `Include_Layer_List_XML_File`, `API_Job_ID`), execution type asynchronous; it was not called.
- MRLC GeoServer (`https://www.mrlc.gov/geoserver/`) also lists a `landfire` workspace (425 layers) and `landfire_wcs` (232); not queried here.

## Documentation

- LFPS User Guide v6.1 (March 2026): https://lfps.usgs.gov/LFProductsServiceUserGuide.pdf
- LFPS Swagger: https://lfps.usgs.gov/docs/api ; product table: https://lfps.usgs.gov/products
- ImageServer directory: https://lfps.usgs.gov/arcgis/rest/services
- EVT page and CSV: https://landfire.gov/vegetation/evt , https://landfire.gov/sites/default/files/CSV/LF2025/LF2025_EVT.csv
- EVC: https://landfire.gov/vegetation/evc ; EVH: https://landfire.gov/vegetation/evh ; FBFM40: https://landfire.gov/fuel/fbfm40
- Attribute data dictionaries: `https://landfire.gov/sites/default/files/DataDictionary/LF2025/LF2025_<ACRONYM>ADD.pdf`
- LANDFIRE data dictionary: https://landfire.gov/data-downloads/documents/LF_Data_Dictionary.pdf
- Ecological systems descriptions: https://landfire.gov/data-downloads/documents/LANDFIRE_Ecological_Systems_Descriptions_CONUS.pdf
- LANDFIRE data are public domain (U.S. Government work).
