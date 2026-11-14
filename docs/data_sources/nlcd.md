# USGS National Land Cover Database (Annual NLCD)

The National Land Cover Database is a 30 m land cover classification of the United States produced by USGS EROS with the Multi-Resolution Land Characteristics (MRLC) Consortium from the Landsat record. Annual NLCD Collection 1 (CU C1.2, released June 2026) provides one map per year for the conterminous U.S. from 1985 through 2025 in six products: Land Cover (LndCov), Land Cover Change (LndChg), Land Cover Confidence (LndCnf), Fractional Impervious Surface (FctImp), Impervious Descriptor (ImpDsc) and Spectral Change Day of Year (SpcChg). Legacy NLCD epochs (2001, 2004, 2006, 2008, 2011, 2013, 2016, 2019, 2021) remain published as separate layers. The classification uses a modified Anderson Level II legend (16 classes in CONUS). MRLC states that the annual products are updated once per year.

| | |
|---|---|
| Provider | U.S. Geological Survey (EROS) / MRLC Consortium |
| Base URL | `https://dmsdata.cr.usgs.gov/geoserver/` (links on the MRLC Data Services page); the same workspaces answer at `https://www.mrlc.gov/geoserver/` |
| Auth | none ("No user name or password is needed", MRLC Data Services page) |
| Formats | OGC WMS 1.1.1/1.3.0 (PNG/JPEG maps, GetFeatureInfo as JSON, text, HTML, GML), OGC WCS 1.0.0/2.0.1 (GeoTIFF), bulk GeoTIFF downloads |
| Coverage | Conterminous U.S. for Annual NLCD; legacy layers also for Alaska, Hawaii, Puerto Rico |
| Resolution | 30 m, native CRS EPSG:5070 (CONUS Albers); display layers also in EPSG:3857 |
| Cadence / latency | annual maps, 1985 to 2025 at time of capture; one release per year |
| Rate limits / quotas | not published |
| Documentation | https://www.mrlc.gov/data-services-page , https://www.mrlc.gov/data/project/annual-nlcd , https://www.mrlc.gov/documentation |

## Requests

Each Annual NLCD product is a separate GeoServer workspace with one time-enabled ImageMosaic layer. Workspace and layer names follow `mrlc_<Product>-Native_conus_year_data` / `<Product>-Native_conus_year_data` (EPSG:5070) and `mrlc_<Product>_conus_year_data` / `<Product>_conus_year_data` (EPSG:3857). `<Product>` is one of `Land-Cover`, `Land-Cover-Change`, `Land-Cover-Confidence`, `Fractional-Impervious-Surface`, `Impervious-Descriptor`, `Spectral-Change-Day-of-Year`. The `time` dimension lists `1985-01-01T00:00:00.000Z` through `2025-01-01T00:00:00.000Z`, one value per year, default `current` (2025).

### WMS GetFeatureInfo (point value for one year)

Returns the raster value under one pixel of a requested map.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `service` | yes | Service type | `WMS` |
| `version` | yes | WMS version (`1.1.1` uses `srs`, `x`, `y`; `1.3.0` uses `crs`, `i`, `j`) | `1.3.0` |
| `request` | yes | Operation | `GetFeatureInfo` |
| `layers` | yes | Layer name inside the workspace | `Land-Cover-Native_conus_year_data` |
| `query_layers` | yes | Layer(s) to query | `Land-Cover-Native_conus_year_data` |
| `styles` | yes (may be empty) | Style name | (empty) |
| `crs` | yes | CRS of `bbox`; `CRS:84` is lon,lat order | `CRS:84` |
| `bbox` | yes | Map extent `minx,miny,maxx,maxy` around the point | `-97.501,40.949,-97.499,40.951` |
| `width`, `height` | yes | Map size in pixels | `3`, `3` |
| `i`, `j` | yes | Pixel column/row to query (centre of a 3x3 map) | `1`, `1` |
| `info_format` | yes | Output format: `application/json`, `text/plain`, `text/html`, `application/vnd.ogc.gml` | `application/json` |
| `time` | no | Map year as ISO date; default is the latest year | `2024-01-01` |
| `feature_count` | no | Max features returned | `1` |

```
GET https://dmsdata.cr.usgs.gov/geoserver/mrlc_Land-Cover-Native_conus_year_data/wms
  ?service=WMS&version=1.3.0&request=GetFeatureInfo
  &layers=Land-Cover-Native_conus_year_data&query_layers=Land-Cover-Native_conus_year_data
  &styles=&crs=CRS:84&bbox=-97.501,40.949,-97.499,40.951
  &width=3&height=3&i=1&j=1
  &info_format=application/json&time=2024-01-01
```

### Sample response (Captured 2026-11-14)

Land Cover, 2024 (identical response for 2025, 2015, 2005, 1995 and 1985 at this point):

```json
{"type":"FeatureCollection","features":[{"type":"Feature","id":"","geometry":null,"properties":{"PALETTE_INDEX":82}}],"totalFeatures":"unknown","numberReturned":1,"timeStamp":"2026-11-14T22:52:04.245Z","crs":null}
```

Other Annual NLCD products at the same point (same request, workspace and layer swapped), captured 2026-11-14:

| Product (layer) | time=2024-01-01 | time=2025-01-01 |
|---|---|---|
| `Land-Cover-Confidence_conus_year_data` | `{"PALETTE_INDEX":93}` | `{"PALETTE_INDEX":93}` |
| `Land-Cover-Change_conus_year_data` | `{"PALETTE_INDEX":82}` | `{"PALETTE_INDEX":82}` |
| `Fractional-Impervious-Surface_conus_year_data` | `{"PALETTE_INDEX":0}` | `{"PALETTE_INDEX":0}` |
| `Impervious-Descriptor_conus_year_data` | `{"PALETTE_INDEX":0}` | `{"PALETTE_INDEX":0}` |
| `Spectral-Change-Day-of-Year_conus_year_data` | `{"GRAY_INDEX":0}` | `{"GRAY_INDEX":0}` |

`info_format=text/plain` response (Land Cover, time=1985-01-01), captured 2026-11-14:

```
Results for FeatureType 'http://mrlc_Land-Cover-Native_conus_year_data:Land-Cover-Native_conus_year_data':
--------------------------------------------
PALETTE_INDEX = 82.0
--------------------------------------------
```

### WCS DescribeCoverage (grid, time domain, no-data value)

Returns the coverage grid definition, the list of available years and the range type.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `service` | yes | Service type | `WCS` |
| `version` | yes | WCS version | `2.0.1` |
| `request` | yes | Operation | `DescribeCoverage` |
| `coverageId` | yes | `<workspace>__<layer>` | `mrlc_Land-Cover-Native_conus_year_data__Land-Cover-Native_conus_year_data` |

```
GET https://www.mrlc.gov/geoserver/mrlc_Land-Cover-Native_conus_year_data/wcs
  ?service=WCS&version=2.0.1&request=DescribeCoverage
  &coverageId=mrlc_Land-Cover-Native_conus_year_data__Land-Cover-Native_conus_year_data
```

### Sample response (Captured 2026-11-14)

Trimmed: namespace declarations, keywords, and TimeInstant entries 1987 to 2024 removed.

```xml
<wcs:CoverageDescription gml:id="mrlc_Land-Cover-Native_conus_year_data__Land-Cover-Native_conus_year_data">
  <gml:description>Generated from ImageMosaic</gml:description>
  <gml:boundedBy>
    <gml:EnvelopeWithTimePeriod srsName="http://www.opengis.net/def/crs/EPSG/0/5070" axisLabels="X Y time" uomLabels="m m s" srsDimension="2">
      <gml:lowerCorner>-2415585.0 164805.0</gml:lowerCorner>
      <gml:upperCorner>2384415.0 3314805.0</gml:upperCorner>
      <gml:beginPosition>1985-01-01T00:00:00.000Z</gml:beginPosition>
      <gml:endPosition>2025-01-01T00:00:00.000Z</gml:endPosition>
    </gml:EnvelopeWithTimePeriod>
  </gml:boundedBy>
  <wcsgs:TimeDomain default="2025-01-01T00:00:00.000Z">
    <gml:TimeInstant><gml:timePosition>1985-01-01T00:00:00.000Z</gml:timePosition></gml:TimeInstant>
    <gml:TimeInstant><gml:timePosition>1986-01-01T00:00:00.000Z</gml:timePosition></gml:TimeInstant>
    ...
    <gml:TimeInstant><gml:timePosition>2025-01-01T00:00:00.000Z</gml:timePosition></gml:TimeInstant>
  </wcsgs:TimeDomain>
  <gml:RectifiedGrid dimension="2">
    <gml:limits><gml:GridEnvelope><gml:low>0 0</gml:low><gml:high>159999 104999</gml:high></gml:GridEnvelope></gml:limits>
    <gml:origin><gml:Point srsName="http://www.opengis.net/def/crs/EPSG/0/5070"><gml:pos>-2415585.0 3314805.0</gml:pos></gml:Point></gml:origin>
    <gml:offsetVector>29.999999995403137 0.0</gml:offsetVector>
    <gml:offsetVector>0.0 -30.000000026127967</gml:offsetVector>
  </gml:RectifiedGrid>
  <swe:field name="PALETTE_INDEX">
    <swe:nilValue reason="http://www.opengis.net/def/nil/OGC/0/unknown">250.0</swe:nilValue>
    <swe:interval>0 255</swe:interval>
  </swe:field>
  <wcs:nativeFormat>image/tiff</wcs:nativeFormat>
</wcs:CoverageDescription>
```

A WCS 2.0.1 `GetCoverage` request with `coverageId`, `subset=X(...)`, `subset=Y(...)`, `subset=time("2024-01-01T00:00:00.000Z")` and `format=image/tiff` returns a GeoTIFF clip; it was not captured here (binary).

### Legacy NLCD and summary layers (WMS GetFeatureInfo)

Legacy epoch layers live in the `mrlc_display` workspace, e.g. `NLCD_2021_Land_Cover_L48`, `NLCD_2019_Land_Cover_L48`, ..., `NLCD_2001_Land_Cover_L48`, plus impervious (`NLCD_2021_Impervious_L48`) and tree canopy (`nlcd_tcc_conus_2021_v2021-4`). Summary layers: `Annual_NLCD_Smy_LndCov_ChgCnt_1985_2023_CU_C1V0` (number of land cover changes 1985 to 2023) and `Annual_NLCD_Smy_LndCov_ChgIdx_1985_2023_CU_C1V0` (change index).

```
GET https://www.mrlc.gov/geoserver/mrlc_display/wms
  ?service=WMS&version=1.1.1&request=GetFeatureInfo
  &layers=NLCD_2021_Land_Cover_L48&query_layers=NLCD_2021_Land_Cover_L48
  &styles=&srs=EPSG:4326&bbox=-97.501,40.949,-97.499,40.951
  &width=3&height=3&x=1&y=1&info_format=application/json&feature_count=1
```

### Sample response (Captured 2026-11-14)

```json
{"type":"FeatureCollection","features":[{"type":"Feature","id":"","geometry":null,"properties":{"PALETTE_INDEX":82}}],"totalFeatures":"unknown","numberReturned":1,"timeStamp":"2026-11-14T22:51:22.977Z","crs":null}
```

Same request with `Annual_NLCD_Smy_LndCov_ChgCnt_1985_2023_CU_C1V0` returned `{"GRAY_INDEX":0}`. Annual tree canopy (`mrlc_NLCD-Tree-Canopy-Native_conus_year_data`, time=2024-01-01) returned `{"PALETTE_INDEX":0}`.

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `features[].properties.PALETTE_INDEX` | number | class code or value | Raster value at the pixel. Meaning depends on product (see below) |
| `features[].properties.GRAY_INDEX` | number | product-specific | Raster value for single-band grey layers (Spectral Change Day of Year, summary change count) |
| `timeStamp` | string (ISO 8601) | UTC | Server time of the response, not the data year |
| `numberReturned` | integer | count | Number of features returned |

Value meaning per product (MRLC Annual NLCD page):

| Product | Value |
|---|---|
| Land Cover (LndCov) | class code from the legend below |
| Land Cover Change (LndChg) | "Depicts land cover change between one product year and the next. Changes are represented in the latter year." |
| Land Cover Confidence (LndCnf) | "probability value for the land cover class derived from the classification method" (93 at the reference point) |
| Fractional Impervious Surface (FctImp) | "fractional surface area of the map unit (pixel) that is covered with artificial substrate or structures" (0 at the reference point) |
| Impervious Descriptor (ImpDsc) | categorical; "distinguishing roads from urban-non-road" (0 at the reference point); code list in the Annual NLCD user guide |
| Spectral Change Day of Year (SpcChg) | day of year of a significant Landsat reflectance deviation in that calendar year (0 at the reference point) |

Land cover class legend (MRLC "NLCD Class Legend and Description"):

| Code | Class | Definition (abridged) |
|---|---|---|
| 11 | Open Water | open water, generally less than 25% vegetation or soil cover |
| 12 | Perennial Ice/Snow | perennial ice and/or snow, generally greater than 25% of cover |
| 21 | Developed, Open Space | impervious surfaces less than 20% of cover (lawns, parks, golf courses) |
| 22 | Developed, Low Intensity | impervious 20% to 49% |
| 23 | Developed, Medium Intensity | impervious 50% to 79% |
| 24 | Developed, High Intensity | impervious 80% to 100% |
| 31 | Barren Land (Rock/Sand/Clay) | vegetation generally less than 15% of cover |
| 41 | Deciduous Forest | trees over 5 m, over 20% cover; over 75% shed foliage seasonally |
| 42 | Evergreen Forest | trees over 5 m, over 20% cover; over 75% keep leaves all year |
| 43 | Mixed Forest | neither deciduous nor evergreen over 75% |
| 51 | Dwarf Scrub | Alaska only |
| 52 | Shrub/Scrub | shrubs under 5 m, canopy over 20% |
| 71 | Grassland/Herbaceous | graminoid or herbaceous over 80%; not tilled, may be grazed |
| 72 | Sedge/Herbaceous | Alaska only |
| 73 | Lichens | Alaska only |
| 74 | Moss | Alaska only |
| 81 | Pasture/Hay | grasses/legumes planted for grazing or hay, typically perennial; over 20% of vegetation |
| 82 | Cultivated Crops | annual crops (corn, soybeans, vegetables, tobacco, cotton) and perennial woody crops (orchards, vineyards); over 20% of vegetation; includes all actively tilled land |
| 90 | Woody Wetlands | forest or shrub over 20% of cover, soil periodically saturated or covered with water |
| 95 | Emergent Herbaceous Wetlands | perennial herbaceous over 80%, soil periodically saturated or covered with water |

No-data: WCS range type declares nil value `250`. Value range 0 to 255 (8-bit).

## Notes

- `CRS:84` and WMS 1.1.1 `EPSG:4326` take bbox in lon,lat order; WMS 1.3.0 with `EPSG:4326` takes lat,lon order.
- A time range (`time=2020-01-01/2025-01-01`) in GetFeatureInfo returned one feature only (`PALETTE_INDEX` 82), not one per year; one request per year was needed to read a history.
- GetFeatureInfo returns the value of the 30 m pixel containing the queried map pixel; it carries no class name, only the code.
- The MRLC services page links the Annual NLCD services on `dmsdata.cr.usgs.gov`; both `dmsdata.cr.usgs.gov` and `www.mrlc.gov` returned identical values on 2026-11-14.
- `Annual_NLCD_LndCov_2024_CU_C1V1-wmstest` exists in `mrlc_display` with a `-wmstest` suffix in its name.
- The root GetCapabilities document (`https://www.mrlc.gov/geoserver/ows?service=WMS&version=1.3.0&request=GetCapabilities`) is about 16 MB and lists about 5,600 layers across all MRLC projects; per-workspace capabilities are smaller.
- MRLC notes that Annual NLCD legends do not display correctly through WCS in ArcGIS Pro and publishes `.lyrx` style files for that case.

## Documentation

- MRLC Data Services page (WMS/WCS links): https://www.mrlc.gov/data-services-page
- Annual NLCD project page: https://www.mrlc.gov/data/project/annual-nlcd
- NLCD class legend and description: https://www.mrlc.gov/data/legends/national-land-cover-database-class-legend-and-description
- Annual NLCD Collection 1 Science Product User Guide (LSDS-2103, v1.2, 2026-04-21): linked from https://www.mrlc.gov/documentation
- USGS Annual NLCD page: https://www.usgs.gov/centers/eros/science/annual-national-land-cover-database
- Reference data release: https://doi.org/10.5066/P13EDMAF
- NLCD data are U.S. Government public domain.
