# NASA GIBS / Worldview (MODIS, VIIRS, IMERG, SMAP imagery layers)

The Global Imagery Browse Services (GIBS), operated by NASA ESDIS, serve pre-rendered, georeferenced image tiles of more than 1,000 satellite data layers (MODIS, VIIRS, GPM IMERG, SMAP, Landsat WELD and others) through OGC WMTS, WMS and TWMS endpoints. NASA Worldview is the browser client built on GIBS. Layers are colour-mapped images (PNG or JPEG), not data values; each data layer publishes an XML colour map that relates RGB values to data ranges. Layers are daily or composite (8-day, 16-day, monthly) with per-layer time ranges; near-real-time layers appear within hours of observation. Projections offered: EPSG:4326, EPSG:3857, EPSG:3413 (Arctic), EPSG:3031 (Antarctic).

| | |
|---|---|
| Provider | NASA Earth Science Data and Information System (ESDIS) |
| Base URL | WMTS: `https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/` ; WMS: `https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi` ; Worldview: `https://worldview.earthdata.nasa.gov/` |
| Auth | none |
| Formats | PNG, JPEG tiles; XML capabilities, colour maps and time domains; SVG legends |
| Coverage | Global |
| Resolution | per layer tile matrix set: `250m`, `500m`, `1km`, `2km`, ... (EPSG:4326 matrices with 512 x 512 tiles) |
| Cadence / latency | per layer (daily, 30-minute, 8-day, 16-day, monthly); `Default` time in capabilities is the latest available |
| Rate limits / quotas | not published |
| Documentation | https://nasa-gibs.github.io/gibs-api-docs/ , https://nasa-gibs.github.io/gibs-api-docs/access-basics/ |

## Requests

### WMTS GetCapabilities

Lists every layer with its identifier, title, time dimension, tile matrix set, format, colour map and legend links, and URL templates.

| Parameter | Required | Description | Example |
|---|---|---|---|
| projection (path) | yes | `epsg4326`, `epsg3857`, `epsg3413`, `epsg3031` | `epsg4326` |
| quality (path) | yes | `best` (also `std`, `nrt`, `all`) | `best` |

```
GET https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/1.0.0/WMTSCapabilities.xml
```

### Sample response (Captured 2026-11-14)

The document is 5.3 MB with 1,330 layers. Trimmed to one layer; inside it the `Value` time ranges reduced to the last three (27 ranges in total) and `ResourceURL` entries of type `Domains` cut after the first.

```xml
<Layer>
  <ows:Title xml:lang='en'>Vegetation Index (16-Day, MODIS, Terra)</ows:Title>
  <ows:WGS84BoundingBox crs='urn:ogc:def:crs:OGC:2:84'><ows:LowerCorner>-180 -90</ows:LowerCorner><ows:UpperCorner>180 90</ows:UpperCorner></ows:WGS84BoundingBox>
  <ows:Identifier>MODIS_Terra_L3_NDVI_16Day</ows:Identifier>
  <ows:Metadata xlink:href='https://gibs.earthdata.nasa.gov/colormaps/v1.3/MODIS_L3_NDVI.xml' xlink:type='simple' xlink:title='GIBS Color Map: Data - RGB Mapping' xlink:role='http://earthdata.nasa.gov/gibs/metadata-type/colormap/1.3'/>
  <Style isDefault='true'>
    <ows:Title xml:lang='en'>default</ows:Title><ows:Identifier>default</ows:Identifier>
    <LegendURL width='378' height='86' xlink:title='GIBS Color Map Legend: Horizontal' xlink:href='https://gibs.earthdata.nasa.gov/legends/MODIS_L3_NDVI_H.svg' format='image/svg+xml'/>
  </Style>
  <Dimension>
    <ows:Identifier>Time</ows:Identifier><ows:UOM>ISO8601</ows:UOM>
    <Default>2026-10-16</Default><Current>false</Current>
    <Value>2024-01-01/2024-12-18/P16D</Value>
    <Value>2025-01-01/2025-12-19/P16D</Value>
    <Value>2026-01-01/2026-10-16/P16D</Value>
  </Dimension>
  <TileMatrixSetLink><TileMatrixSet>250m</TileMatrixSet></TileMatrixSetLink>
  <Format>image/png</Format>
  <ResourceURL template='https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/MODIS_Terra_L3_NDVI_16Day/default/{Time}/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.png' resourceType='tile' format='image/png'/>
  <ResourceURL template='https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/1.0.0/MODIS_Terra_L3_NDVI_16Day/default/{TileMatrixSet}/all/{TimeStart}--{TimeEnd}.xml' resourceType='Domains' format='text/xml'/>
</Layer>
```

Tile matrix set excerpt (same document), `250m` levels 0 and 8 (levels 1-7 removed):

```xml
<TileMatrix><ows:Identifier>0</ows:Identifier><ScaleDenominator>223632905.6114871</ScaleDenominator><TopLeftCorner>-180 90</TopLeftCorner><TileWidth>512</TileWidth><TileHeight>512</TileHeight><MatrixWidth>2</MatrixWidth><MatrixHeight>1</MatrixHeight></TileMatrix>
<TileMatrix><ows:Identifier>8</ows:Identifier><ScaleDenominator>873566.0375448716</ScaleDenominator><TopLeftCorner>-180 90</TopLeftCorner><TileWidth>512</TileWidth><TileHeight>512</TileHeight><MatrixWidth>320</MatrixWidth><MatrixHeight>160</MatrixHeight></TileMatrix>
```

Selected layer identifiers from the same capabilities (title, tile matrix set, first and last time range):

| Identifier | Title | Matrix set | Time ranges (first ... last) |
|---|---|---|---|
| `IMERG_Precipitation_Rate` | Precipitation Rate (IMERG) | 2km | `2000-06-01/2025-10-22/P1D` ... `2026-05-27/2026-11-13/P1D` (5 ranges) |
| `IMERG_Precipitation_Rate_30min` | Precipitation Rate, 30-minute avg. (IMERG) | 2km | `1998-01-01T00:00:00Z/2025-09-13T19:30:00Z/PT30M` ... `2026-02-10T01:00:00Z/2026-11-14T16:30:00Z/PT30M` |
| `MODIS_Terra_L3_NDVI_16Day` | Vegetation Index (16-Day, MODIS, Terra) | 250m | `2000-03-05/2000-12-18/P16D` ... `2026-01-01/2026-10-16/P16D` |
| `MODIS_Aqua_L3_NDVI_16Day`, `MODIS_Terra_L3_EVI_16Day`, `MODIS_Terra_L3_NDVI_Monthly` | 16-day / monthly NDVI, EVI | 250m | (per layer) |
| `MODIS_Terra_NDVI_8Day` | Vegetation Index (rolling 8-Day, MODIS, Terra) | 250m | `2025-02-12/2026-02-08/P1D` ... `2026-02-10/2026-11-13/P1D` |
| `VIIRS_SNPP_NDVI_8Day` | NDVI (rolling 8-Day, VIIRS, Suomi NPP) | 500m | `2025-07-01/2026-02-08/P1D` ... `2026-02-10/2026-11-02/P1D` |
| `MODIS_Terra_Land_Surface_Temp_Day` | Land Surface Temperature (Day, MODIS, Terra) | 1km | `2000-02-24/2000-04-25/P1D` ... `2022-10-23/2026-11-15/P1D` |
| `SMAP_L4_Analyzed_Root_Zone_Soil_Moisture` | Root Zone Soil Moisture (L4, 12z Instantaneous, Model Value-Added, SMAP) | 2km | `2015-03-31/2025-10-09/P1D` ... `2026-11-08/2026-11-10/P1D` |
| `SMAP_L4_Analyzed_Surface_Soil_Moisture` | Surface soil moisture (L4) | 2km | (per layer) |
| `SMAP_L3_Passive_Enhanced_Day_Soil_Moisture` | Soil Moisture (L3, Passive Enhanced, Day, Radiometer, SMAP) | 2km | `2015-03-31/2015-05-12/P1D` ... `2026-11-03/2026-11-11/P1D` (18 ranges) |
| `MODIS_Terra_CorrectedReflectance_TrueColor` | Corrected Reflectance (True Color, MODIS, Terra) | 250m | `2008-12-23/2016-02-18/P1D` ... `2022-10-23/2026-11-15/P1D` (JPEG) |
| `VIIRS_SNPP_CorrectedReflectance_TrueColor` | Corrected Reflectance (True Color, VIIRS, Suomi NPP) | (per layer) | (per layer) |

### WMTS GetTile (REST)

Returns one 512 x 512 tile. For EPSG:4326 the tile span at level `z` is `288 / 2^z` degrees; `TileCol = floor((lon + 180) / span)`, `TileRow = floor((90 - lat) / span)`.

| Parameter | Required | Description | Example |
|---|---|---|---|
| layer (path) | yes | Layer identifier | `MODIS_Terra_L3_NDVI_16Day` |
| style (path) | yes | Style | `default` |
| Time (path) | no | Date (`YYYY-MM-DD`) or datetime; omitted = default | `2025-07-12` |
| TileMatrixSet (path) | yes | From the layer's `TileMatrixSetLink` | `250m` |
| TileMatrix (path) | yes | Zoom level | `8` |
| TileRow, TileCol (path) | yes | Tile indices | `43`, `73` |
| extension | yes | From layer `Format` | `.png` |

```
GET https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/MODIS_Terra_L3_NDVI_16Day/default/2025-07-12/250m/8/43/73.png
GET https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/IMERG_Precipitation_Rate/default/2025-07-04/2km/5/5/9.png
```

### Sample response (Captured 2026-11-14)

Binary PNGs, not reproduced. Observed: NDVI tile HTTP 200, `image/png`, 131,391 bytes, 512 x 512, 8-bit palette (colour type 3). Pixel (170, 307) in that tile, which contains 40.95 N, 97.50 W, has palette RGB `(0, 84, 1)`. IMERG tile HTTP 200, `image/png`, 3,325 bytes; pixel (85, 230) at the point has RGB `(191, 191, 191)`.

### Colour map (RGB to value)

| Parameter | Required | Description | Example |
|---|---|---|---|
| colour map name (path) | yes | From the layer's `ows:Metadata` colormap link | `MODIS_L3_NDVI.xml` |

```
GET https://gibs.earthdata.nasa.gov/colormaps/v1.3/MODIS_L3_NDVI.xml
```

### Sample response (Captured 2026-11-14)

Trimmed: first 10 data entries and the entry matching the captured tile pixel kept; 143 `ColorMapEntry` rows in total.

```xml
<ColorMaps xsi:noNamespaceSchemaLocation="http://gibs.earthdata.nasa.gov/schemas/ColorMap_v1.3.xsd">
  <ColorMap title="No Data">
    <Entries>
      <ColorMapEntry rgb="0,26,105" transparent="true" sourceValue="[-3000,-2000)" value="[-0.3,-0.2)" nodata="true" ref="0"/>
    </Entries>
    <Legend type="classification"><LegendEntry rgb="0,26,105" tooltip="Fill" id="0"/></Legend>
  </ColorMap>
  <ColorMap title="Vegetation Indices" >
    <Entries>
      <ColorMapEntry rgb="225,225,225" transparent="true" sourceValue="[-2000,-999)" value="[-0.2000,-0.0999)" ref="1"/>
      <ColorMapEntry rgb="225,225,226" transparent="true" sourceValue="[-999,1)" value="[-0.0999,0.0001)" ref="2"/>
      <ColorMapEntry rgb="241,236,236" transparent="false" sourceValue="[1,51)" value="[0.0001,0.0051)" ref="3"/>
      ...
      <ColorMapEntry rgb="0,84,1" transparent="false" sourceValue="[8901,9001)" value="[0.8901,0.9001)" ref="132"/>
      ...
    </Entries>
    <Legend type="continuous" minLabel="0.0" maxLabel="1.0">
      ...
      <LegendEntry rgb="0,84,1" tooltip="0.890 – 0.900" id="132"/>
      ...
    </Legend>
  </ColorMap>
</ColorMaps>
```

`GPM_Precipitation_Rate.xml` (IMERG) begins with a "Classifications" map: `rgb="128,128,128"` nodata ("No Data"), `rgb="191,191,191"` `value="[-INF,0.1)"` ("Insignificant"), followed by a "Rain Rate" map with `units="mm/hr"`.

### WMTS time domain

Lists available times for a layer within a range.

```
GET https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/1.0.0/MODIS_Terra_L3_NDVI_16Day/default/250m/all/2025-01-01--2025-12-31.xml
```

### Sample response (Captured 2026-11-14)

```xml
<Domains xmlns:ows='http://www.opengis.net/ows/1.1'><SpaceDomain><BoundingBox crs='urn:ogc:def:crs:OGC:2:84' maxx='180' maxy='90' miny='-90' minx='-180'/></SpaceDomain><DimensionDomain><ows:Identifier>time</ows:Identifier><Domain>2025-01-01/2025-12-19/P16D</Domain><Size>1</Size></DimensionDomain></Domains>
```

### WMS GetMap

Renders an arbitrary bounding box for one or more layers and a time.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `SERVICE`, `VERSION`, `REQUEST` | yes | | `WMS`, `1.3.0`, `GetMap` |
| `LAYERS` | yes | Layer identifier(s), comma-separated | `SMAP_L4_Analyzed_Root_Zone_Soil_Moisture` |
| `STYLES` | yes (may be empty) | | (empty) |
| `CRS` | yes | `EPSG:4326` (1.3.0 axis order lat,lon) | `EPSG:4326` |
| `BBOX` | yes | `minlat,minlon,maxlat,maxlon` for 1.3.0 EPSG:4326 | `40.45,-98.0,41.45,-97.0` |
| `WIDTH`, `HEIGHT` | yes | Pixels | `256`, `256` |
| `FORMAT` | yes | `image/png` or `image/jpeg` | `image/png` |
| `TIME` | no | Date | `2025-07-04` |
| `TRANSPARENT` | no | | `TRUE` |

```
GET https://gibs.earthdata.nasa.gov/wms/epsg4326/best/wms.cgi?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=SMAP_L4_Analyzed_Root_Zone_Soil_Moisture&STYLES=&CRS=EPSG:4326&BBOX=40.45,-98.0,41.45,-97.0&WIDTH=256&HEIGHT=256&FORMAT=image/png&TIME=2025-07-04
```

### Sample response (Captured 2026-11-14)

HTTP 200, `image/png`, 1,966 bytes (binary, not reproduced). WMS capabilities: `.../wms.cgi?SERVICE=WMS&REQUEST=GetCapabilities&VERSION=1.3.0` (not captured).

### Worldview permalink

Worldview encodes view state in URL query parameters (layer list `l`, date `t`, extent `v`). Example built from the captured layer IDs:

```
https://worldview.earthdata.nasa.gov/?v=-98.5,40.4,-96.5,41.5&l=MODIS_Terra_L3_NDVI_16Day,MODIS_Terra_CorrectedReflectance_TrueColor&t=2025-07-12
```

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `ows:Identifier` (Layer) | string | | Layer ID used in tile and WMS URLs |
| `ows:Title` | string | | Human-readable layer name |
| `Dimension/Default` | date | | Latest (default) time |
| `Dimension/Value` | ISO 8601 interval | | `start/end/period` ranges of available times (gaps appear as separate ranges) |
| `TileMatrixSetLink/TileMatrixSet` | string | | Native resolution class (`250m`, `500m`, `1km`, `2km`) |
| `Format` | string | | `image/png` (data layers) or `image/jpeg` (true colour) |
| `ResourceURL@template` (tile) | string | | REST tile URL template |
| `ows:Metadata` colormap link | URL | | Colour map XML for RGB to value |
| `LegendURL` | URL | | SVG legend |
| `ColorMapEntry@rgb` | string | 0-255 triplet | Pixel colour |
| `ColorMapEntry@value` | interval | layer units | Data range for that colour (`[a,b)` half-open) |
| `ColorMapEntry@sourceValue` | interval | source integers | Range in the source product's scaled integers (NDVI x 10000) |
| `ColorMapEntry@nodata`, `@transparent` | boolean | | No-data / transparent classes |
| `ColorMap@units` | string | | Units of `value` (e.g. `mm/hr` for IMERG rain rate) |
| `LegendEntry@tooltip` | string | | Legend label for that colour |

Reading values: a tile pixel's RGB matched to the colour map gives a value interval, not the original value (e.g. RGB `(0,84,1)` = NDVI `[0.8901, 0.9001)` for `MODIS_Terra_L3_NDVI_16Day` on 2025-07-12 at the reference point; RGB `(191,191,191)` = IMERG rate `< 0.1 mm/hr` "Insignificant" on 2025-07-04).

## Notes

- GIBS layers are rendered imagery. Values recovered through the colour map are binned (NDVI colour-map bins are 0.005, 0.0075 or 0.01 wide depending on the range); JPEG layers (true colour) have no colour map.
- Time ranges have gaps; the capabilities `Value` list or the Domains endpoint shows which dates exist. `IMERG_Precipitation_Rate` lists 5 ranges, `SMAP_L3_Passive_Enhanced_Day_Soil_Moisture` 18.
- `MODIS_Terra_L3_NDVI_16Day` dates step every 16 days from 1 January each year; a request date must match a listed composite start date.
- For EPSG:4326, WMS 1.3.0 `BBOX` axis order is lat,lon; WMTS tile rows count from 90 N downward.
- Tiles at a pixel near the point show the value for the whole 250 m (NDVI) or about 10 km (IMERG native 0.1 degree, served on the 2km matrix) cell.
- GIBS also exposes `epsg3857` endpoints with Google-compatible tile matrices (`GoogleMapsCompatible_Level*`); not captured.

## Documentation

- GIBS API documentation: https://nasa-gibs.github.io/gibs-api-docs/
- Access basics and URL patterns: https://nasa-gibs.github.io/gibs-api-docs/access-basics/
- Available visualizations: https://nasa-gibs.github.io/gibs-api-docs/available-visualizations/
- Colour map format: https://nasa-gibs.github.io/gibs-api-docs/access-advanced-topics/#color-maps
- Worldview: https://worldview.earthdata.nasa.gov/ ; source and URL parameters: https://github.com/nasa-gibs/worldview
- NASA imagery is openly available with no restrictions; source citation per NASA Earthdata data use policy: https://www.earthdata.nasa.gov/engage/open-data-services-software-policies/data-use-guidance
