# Market access: travel-time rasters (Malaria Atlas Project) and the World Port Index (NGA)

Two static global layers describe how far a place is from markets and from export infrastructure. The Malaria Atlas Project (MAP, University of Oxford) publishes the accessibility rasters of Weiss et al.: travel time in minutes from every 1 km pixel to the nearest densely populated area (nominal year 2015, Nature 2018) and to the nearest hospital or clinic by motorised and by walking-only transport (nominal year 2019, Nature Medicine 2020), together with the friction surfaces they were computed from. MAP serves them through a public GeoServer (WCS 2.0.1 for raster subsets, WMS for tiles and point queries) and they are also in the Google Earth Engine catalog. The World Port Index (Pub. 150) is the US National Geospatial-Intelligence Agency's table of about 3,700 ports with coordinates, harbour size and type, depths, cargo facilities and services; NGA publishes it as a shapefile and CSV, and OCHA mirrors a 2017 shapefile on the Humanitarian Data Exchange (HDX) under CC0.

| | |
|---|---|
| Provider | Malaria Atlas Project (University of Oxford) with Google, JRC and University of Twente; US National Geospatial-Intelligence Agency (NGA), mirrored by OCHA ROLAC on HDX |
| Base URL | MAP GeoServer `https://data.malariaatlas.org/geoserver/Accessibility/ows` (WCS) and `.../Accessibility/wms` (WMS); Earth Engine `projects/malariaatlasproject/assets/accessibility/accessibility_to_cities/2015_v1_0`, `Oxford/MAP/accessibility_to_healthcare_2019`; HDX `https://data.humdata.org/api/3/action/package_show?id=world-port-index`; NGA `https://msi.nga.mil/Publications/WPI` |
| Auth | none (GeoServer, HDX); Earth Engine needs a Google account and is free for research, education and nonprofit use only |
| Formats | GeoTIFF (`image/tiff;application=geotiff`), PNG/JPEG tiles, GML; GetFeatureInfo as JSON or text; shapefile ZIP (WPI) |
| Coverage | rasters: global land, 60 S to 85 N; WPI: 3,669 ports worldwide |
| Resolution | rasters: 30 arc-seconds (927.67 m), grid 43,200 x 17,400, EPSG:4326; WPI: point per port |
| Cadence / latency | static: 2015 (cities), 2019/2020 (healthcare, friction); WPI shapefile dated 2017-03-28, HDX record dated 2019-12-01 |
| Rate limits / quotas | none published; GeoServer `Fees NONE`, `AccessConstraints NONE` |
| Licence | MAP rasters CC BY 4.0 (Earth Engine catalog pages, re-read 2026-11-15); WPI: US government work, HDX copy "Public Domain / No restrictions (CC0)" |
| Documentation | https://malariaatlas.org/ ; https://developers.google.com/earth-engine/datasets/catalog/projects_malariaatlasproject_assets_accessibility_accessibility_to_cities_2015_v1_0 ; https://msi.nga.mil/Publications/WPI |

## Requests

### MAP WCS capabilities (coverage list)

```
GET https://data.malariaatlas.org/geoserver/Accessibility/ows?service=WCS&version=2.0.1&request=GetCapabilities
```

### Sample response (Captured 2026-11-15)

558,054 bytes of XML (the workspace capabilities document lists every coverage on the server). Trimmed to the service block and the six coverages of the `Accessibility` workspace.

```xml
<wcs:Capabilities version="2.0.1" updateSequence="5435">
  <ows:ServiceIdentification> ... <ows:Fees>NONE</ows:Fees><ows:AccessConstraints>NONE</ows:AccessConstraints></ows:ServiceIdentification>
  <wcs:ServiceMetadata><wcs:formatSupported>image/tiff</wcs:formatSupported><wcs:formatSupported>image/tiff;application=geotiff</wcs:formatSupported>
    <wcs:formatSupported>image/png</wcs:formatSupported><wcs:formatSupported>application/gml+xml</wcs:formatSupported><wcs:formatSupported>text/plain</wcs:formatSupported></wcs:ServiceMetadata>
  <wcs:Contents>
    <wcs:CoverageSummary><ows:Title>Travel Time to Cities</ows:Title>
      <ows:Abstract>This layer map provides estimates of travel time (in minutes) to nearest city to assess inequalities in accessibility in 2015.</ows:Abstract>
      <wcs:CoverageId>Accessibility__201501_Global_Travel_Time_to_Cities</wcs:CoverageId></wcs:CoverageSummary>
    <wcs:CoverageSummary><ows:Title>Land-based Travel Speed Friction Surface</ows:Title><wcs:CoverageId>Accessibility__201501_Global_Travel_Speed_Friction_Surface</wcs:CoverageId></wcs:CoverageSummary>
    <wcs:CoverageSummary><ows:Title>Travel Time to Nearest Healthcare Facility with Access to Motorized Transport</ows:Title><wcs:CoverageId>Accessibility__202001_Global_Motorized_Travel_Time_to_Healthcare</wcs:CoverageId></wcs:CoverageSummary>
    <wcs:CoverageSummary><wcs:CoverageId>Accessibility__202001_Global_Walking_Only_Travel_Time_To_Healthcare</wcs:CoverageId></wcs:CoverageSummary>
    <wcs:CoverageSummary><ows:Title>Global friction surface enumerating land-based travel speed with access to motorized transport</ows:Title><wcs:CoverageId>Accessibility__202001_Global_Motorized_Friction_Surface</wcs:CoverageId></wcs:CoverageSummary>
    <wcs:CoverageSummary><ows:Title>Global friction surface enumerating land-based travel walking-only speed without access to motorized transport</ows:Title><wcs:CoverageId>Accessibility__202001_Global_Walking_Only_Friction_Surface</wcs:CoverageId></wcs:CoverageSummary>
  </wcs:Contents>
</wcs:Capabilities>
```

### MAP WCS DescribeCoverage

| Parameter | Required | Description | Example |
|---|---|---|---|
| `coverageId` | yes | Coverage id from the capabilities | `Accessibility__201501_Global_Travel_Time_to_Cities` |

```
GET https://data.malariaatlas.org/geoserver/Accessibility/ows?service=WCS&version=2.0.1&request=DescribeCoverage&coverageId=Accessibility__201501_Global_Travel_Time_to_Cities
```

### Sample response (Captured 2026-11-15)

3,858 bytes. Trimmed: namespaces and the `swe:DataRecord` wrapper removed.

```xml
<wcs:CoverageDescription gml:id="Accessibility__201501_Global_Travel_Time_to_Cities">
  <gml:name>Travel Time to Cities</gml:name>
  <gml:boundedBy><gml:Envelope srsName="http://www.opengis.net/def/crs/EPSG/0/4326" axisLabels="Lat Long" uomLabels="Deg Deg" srsDimension="2">
    <gml:lowerCorner>-60.0 -180.0</gml:lowerCorner><gml:upperCorner>85.0 180.0</gml:upperCorner></gml:Envelope></gml:boundedBy>
  <ows:Keywords><ows:Keyword>spatialResolution:1Km</ows:Keyword><ows:Keyword>spatialExtent:Global</ows:Keyword><ows:Keyword>temporalExtent:2015</ows:Keyword></ows:Keywords>
  <gml:RectifiedGrid dimension="2"><gml:limits><gml:GridEnvelope><gml:low>0 0</gml:low><gml:high>43199 17399</gml:high></gml:GridEnvelope></gml:limits>
    <gml:origin><gml:Point><gml:pos>84.99583333333334 -179.9958333333333</gml:pos></gml:Point></gml:origin></gml:RectifiedGrid>
  <swe:field name="GRAY_INDEX"><swe:Quantity><swe:nilValues><swe:nilValue reason="http://www.opengis.net/def/nil/OGC/0/unknown">-9999.0</swe:nilValue></swe:nilValues></swe:Quantity></swe:field>
  <wcs:nativeFormat>image/tiff</wcs:nativeFormat>
</wcs:CoverageDescription>
```

The healthcare coverage (`202001_Global_Motorized_Travel_Time_to_Healthcare`) describes identically with `temporalExtent:2019`. The `swe:uom code="W.m-2.Sr-1"` in the description is a GeoServer default; the unit is minutes per the layer abstract and the Earth Engine pages.

### MAP WMS GetFeatureInfo (pixel value at a point)

Returns the raster value under one pixel of a small WMS map, which is the simplest way to read the travel time at a coordinate without downloading a GeoTIFF.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `layers`, `query_layers` | yes | `Accessibility:<coverage name>` | `Accessibility:201501_Global_Travel_Time_to_Cities` |
| `bbox` | yes | `minLon,minLat,maxLon,maxLat` (WMS 1.1.1 order) around the point | `-97.51,40.94,-97.49,40.96` |
| `width`, `height`, `x`, `y` | yes | Map size in pixels and the queried pixel | `101`, `101`, `50`, `50` |
| `srs` | yes | `EPSG:4326` | |
| `info_format` | no | `application/json`, `text/plain` | `application/json` |

```
GET https://data.malariaatlas.org/geoserver/Accessibility/wms?service=WMS&version=1.1.1&request=GetFeatureInfo&layers=Accessibility:201501_Global_Travel_Time_to_Cities&query_layers=Accessibility:201501_Global_Travel_Time_to_Cities&styles=&bbox=-97.51,40.94,-97.49,40.96&width=101&height=101&srs=EPSG:4326&x=50&y=50&info_format=application/json
```

### Sample response (Captured 2026-11-15)

Untrimmed, reference site 40.95, -97.50 (York County, Nebraska):

```json
{"type":"FeatureCollection","features":[{"type":"Feature","id":"","geometry":null,"properties":{"GRAY_INDEX":57}}],"totalFeatures":"unknown","numberReturned":1,"timeStamp":"2026-11-15T18:43:18.994Z","crs":null}
```

Same request against `Accessibility:202001_Global_Motorized_Travel_Time_to_Healthcare` at the reference site: `"GRAY_INDEX":9.88388729095459`. Against the cities layer at 0.52, 35.27 (Eldoret, Kenya, inside the town): `"GRAY_INDEX":0`. Values are minutes.

### MAP WCS GetCoverage (raster subset)

Returns a GeoTIFF clipped to the subset. Not fetched (binary); the request follows the WCS 2.0.1 KVP binding advertised in the capabilities.

```
GET https://data.malariaatlas.org/geoserver/Accessibility/ows?service=WCS&version=2.0.1&request=GetCoverage&coverageId=Accessibility__201501_Global_Travel_Time_to_Cities&subset=Lat(40.5,41.5)&subset=Long(-98.0,-97.0)&format=image/tiff
```

### World Port Index on HDX (CKAN package)

```
GET https://data.humdata.org/api/3/action/package_show?id=world-port-index
```

### Sample response (Captured 2026-11-15)

10,520 bytes. Trimmed to the fields that describe the dataset and its one resource.

```json
{"success":true,"result":{"name":"world-port-index","title":"World Port Index","license_title":"Public Domain / No restrictions (CC0)","license_id":"other-pd-nr",
 "dataset_source":"OCHA ROLAC","dataset_date":"[2019-12-01T00:00:00 TO 2019-12-01T23:59:59]","data_update_frequency":"-2",
 "methodology":"Direct Observational Data/Anecdotal Data","last_modified":"2019-12-01T20:05:44.533859","metadata_modified":"2026-08-27T14:36:41.588538",
 "notes":"The World Port Index shows locations, physical characteristics, facilities, and services offered by major ports around the world. This dataset is created by the Maritime Security Office of the National Geospatial-Intelligence Agency (NGA) to document the locations and features of major ports around the world. ...",
 "resources":[{"name":"world_port_index.zip","format":"SHP","size":603601,"url":"https://data.humdata.org/dataset/3f976f27-2566-4ea7-b29e-7fc6ebc90aab/resource/060abaf3-8c9f-4df4-b7e3-5335a15c6247/download/world_port_index.zip","last_modified":"2019-12-01T20:05:44.533859"}]}}
```

### World Port Index shapefile (HDX resource)

```
GET https://data.humdata.org/dataset/3f976f27-2566-4ea7-b29e-7fc6ebc90aab/resource/060abaf3-8c9f-4df4-b7e3-5335a15c6247/download/world_port_index.zip
```

### Sample response (Captured 2026-11-15)

HTTP 302 to an S3 URL, then 200, 603,601 bytes (`application/zip`). Archive contents: `WPI.shp` (102,832 bytes), `WPI.shx`, `WPI.dbf` (64,837,429 bytes uncompressed), `WPI.prj` (GCS_WGS_1984), `WPI.cpg` (UTF-8), `WPI.sbn`, `WPI.sbx`, all dated 2017-03-28. The DBF holds 3,669 records and 78 fields (`last update 2017-03-28`). Three records, empty fields dropped and the record cut after the pilotage fields:

```
PORT_NAME=HOUSTON | COUNTRY=US | LATITUDE=29.750000 | LONGITUDE=-95.283333 | INDEX_NO=9240 | REGION_NO=8650 | PUB=CP05 | CHART=11325 | HARBORSIZE=L | HARBORTYPE=RT | SHELTER=G | ENTRY_TIDE=N | ENTRYSWELL=N | ENTRY_ICE=N | ENTRYOTHER=Y | OVERHD_LIM=Y | CHAN_DEPTH=G | ANCH_DEPTH=K | CARGODEPTH=L | OIL_DEPTH=J | TIDE_RANGE=0 | MAX_VESSEL=L | HOLDGROUND=Y | TURN_BASIN=Y | PORTOFENTR=Y | US_REP=Y | ETAMESSAGE=Y | PILOT_REQD=Y | PILOTAVAIL=Y | PILOTADVSD=Y
PORT_NAME=NEW ORLEANS | COUNTRY=US | LATITUDE=29.950000 | LONGITUDE=-90.050000 | INDEX_NO=8860 | REGION_NO=8650 | PUB=CP05 | CHART=11368 | HARBORSIZE=L | HARBORTYPE=RN | SHELTER=E | CHAN_DEPTH=J | ANCH_DEPTH=A | CARGODEPTH=J | OIL_DEPTH=E | MAX_VESSEL=L | PORTOFENTR=Y | US_REP=Y
PORT_NAME=MOMBASA | COUNTRY=KE | LATITUDE=-4.066667 | LONGITUDE=39.666667 | INDEX_NO=47100 | REGION_NO=47090 | PUB=171 | CHART=61212 | HARBORSIZE=M | HARBORTYPE=CT | SHELTER=G | ENTRYSWELL=Y | CHAN_DEPTH=G | ANCH_DEPTH=M | CARGODEPTH=K | OIL_DEPTH=N | TIDE_RANGE=3 | MAX_VESSEL=M | PORTOFENTR=Y | US_REP=N
```

### NGA source page (Captured 2026-11-15)

```
GET https://msi.nga.mil/Publications/WPI  -> 503 Service Unavailable (Akamai NetStorage "apology" page, 17,445 bytes)
GET https://msi.nga.mil/                  -> 302 /home -> 503 Service Unavailable
```

The current NGA edition (which has more fields and a 2019 and later revision) could not be reached; the HDX copy is the 2017 shapefile.

## Fields

MAP rasters (one band each):

| Field | Type | Unit | Description |
|---|---|---|---|
| `accessibility` (cities 2015) | float32 | minutes | Travel time to the nearest densely populated area (1,500 or more inhabitants per km2 or majority built-up land cover with a population centre of at least 50,000); range 0 to 41,556 |
| `accessibility` (healthcare 2019) | float32 | minutes | Travel time to the nearest hospital or clinic with access to motorised transport; range 0 to 41,504.1 |
| `accessibility_walking_only` (healthcare 2019) | float32 | minutes | Same, non-motorised transport only; range 0 to 138,893 |
| friction surfaces | float32 | minutes per metre | Nominal time to cross one metre of each pixel (2015 generic; 2020 motorised and walking-only) |
| nodata | | | `-9999` in the GeoServer coverages |

World Port Index (2017 shapefile, 78 DBF fields): `INDEX_NO` (port number in Pub. 150), `REGION_NO`, `PORT_NAME`, `COUNTRY` (ISO-style two letters), `LATITUDE`, `LONGITUDE` (decimal degrees) plus `LAT_DEG`/`LAT_MIN`/`LAT_HEMI` and `LONG_*`, `PUB` (Sailing Directions volume), `CHART`, `HARBORSIZE` (L large, M medium, S small, V very small), `HARBORTYPE` (CN coastal natural, CB coastal breakwater, CT coastal tide gate, RN river natural, RB river basin, RT river tide gate, LC lake or canal, OR open roadstead, TH typhoon harbour), `SHELTER` (E excellent, G good, F fair, P poor, N none), entry restrictions (`ENTRY_TIDE`, `ENTRYSWELL`, `ENTRY_ICE`, `ENTRYOTHER`, `OVERHD_LIM`), coded depth ranges (`CHAN_DEPTH`, `ANCH_DEPTH`, `CARGODEPTH`, `OIL_DEPTH`, letters A to Q as defined in Pub. 150), `TIDE_RANGE` (metres), `MAX_VESSEL` (L over 500 ft, M 500 ft or less), pilotage and tug flags, communications, cargo wharf and anchorage flags, `MED_FACIL`, cranes and lifts, supplies (`PROVISIONS`, `WATER`, `FUEL_OIL`, `DIESEL`), `REPAIRCODE`, `DRYDOCK`, `RAILWAY`. Flag fields are `Y`/`N` or empty.

## Licence

MAP rasters: "This work is licensed under a Creative Commons Attribution 4.0 International License", read on 2026-11-15 on the Earth Engine catalog pages for `accessibility_to_cities/2015_v1_0` and `Oxford/MAP/accessibility_to_healthcare_2019` (the latter marked "[deprecated]" in the catalog title). The GeoServer capabilities declare `Fees NONE` and `AccessConstraints NONE`. The Earth Engine platform is "free to use for research, education, and nonprofit use", a platform condition separate from the data licence; the GeoServer and MAP's own downloads carry no such condition. Citations: Weiss et al., Nature 2018, doi:10.1038/nature25181 (cities); Weiss et al., Nature Medicine 2020 (healthcare). Verdict in the inventory: PASS.

World Port Index: the HDX record declares "Public Domain / No restrictions (CC0)" (`license_id` `other-pd-nr`), re-read today; the source is a US federal publication. NGA's own page could not be read (HTTP 503). Verdict in the inventory: PASS on secondary verification.

## Overlap with NASA sources

NASA publishes no travel-time or port datasets. The population layer that sits beside these rasters on the NASA side is SEDAC's Gridded Population of the World (GPW v4) at the same 30 arc-second grid; the city definition inside the MAP cities layer comes from the JRC Global Human Settlement Layer, not from NASA. Terrain that enters the friction surfaces is covered on the NASA side by SRTM and NASADEM (`terrain.md`).

## Notes

- GeoServer serves 1 km pixels; at the reference site the cities layer gives 57 minutes and the motorised healthcare layer 9.88 minutes. The Eldoret, Kenya point returns 0 because it lies inside a town that qualifies as a densely populated area.
- The WCS capabilities document is large (558 KB) because it lists every coverage on `data.malariaatlas.org`, not only the `Accessibility` workspace.
- The HDX shapefile is the March 2017 WPI edition (3,669 ports). NGA has since revised the publication and its field list; `msi.nga.mil` was unavailable on 2026-11-15, so the current edition and its download format were not checked. The inventory reports a direct CSV request to NGA returning HTTP 403 on 2026-10-06.
- `data_update_frequency` -2 is an HDX code; the HDX resource has not changed since 2019-12-01 (`metadata_modified` 2026-08-27 reflects catalogue edits).
- The DBF stores numeric fields as `N16.6` (for example `INDEX_NO=9240.000000`) and every text field as `C254`, which is why the uncompressed DBF is 64 MB for 3,669 rows.

## Documentation

- MAP accessibility project: https://malariaatlas.org/project-resources/accessibility-to-healthcare/
- MAP data explorer and GeoServer: https://data.malariaatlas.org/
- Earth Engine catalog, cities 2015: https://developers.google.com/earth-engine/datasets/catalog/projects_malariaatlasproject_assets_accessibility_accessibility_to_cities_2015_v1_0
- Earth Engine catalog, healthcare 2019: https://developers.google.com/earth-engine/datasets/catalog/Oxford_MAP_accessibility_to_healthcare_2019
- Weiss et al. 2018: https://doi.org/10.1038/nature25181
- NGA World Port Index: https://msi.nga.mil/Publications/WPI
- HDX copy: https://data.humdata.org/dataset/world-port-index
