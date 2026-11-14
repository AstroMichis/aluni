# Terrain: elevation and slope

Slope and landscape position drive runoff, erosion, wet spots and frost pockets. Two sources:

| Source | What | Resolution | Access | Auth |
|---|---|---|---|---|
| USGS 3DEP via EPQS | Elevation at a point, U.S. only, mostly lidar | 1 m where lidar exists, otherwise 1/3 arc-second (~10 m) | `GET https://epqs.nationalmap.gov/v1/json` | none |
| NASA SRTM / NASADEM | Global elevation (Shuttle Radar Topography Mission, 2000) | 30 m (`SRTMGL1_NC.003`, `NASADEM_NC.001`), 90 m (`SRTMGL3_NC.003`) | AppEEARS (`appeears.md`), layer `SRTMGL1_DEM` (metres) | Earthdata |

Use 3DEP in the U.S. (sharper, newer); SRTM/NASADEM is the fallback outside it and the NASA-branded source to cite.

## Request (EPQS)

```
GET https://epqs.nationalmap.gov/v1/json?x=-97.50&y=40.95&units=Meters&wkid=4326
```

## Sample response (Captured)

```json
{"location":{"x":-97.5,"y":40.95,"spatialReference":{"wkid":4326,"latestWkid":4326}},"locationId":0,"value":"497.252014160","rasterId":137748,"resolution":1}
```

`value` is a **string** in metres; `resolution: 1` means 1 m lidar is available here. Compare NASA POWER's grid-cell elevation for the same point: 491.1 m (a 50 km average).

EPQS intermittently returns HTTP 200 with an empty body, or a 504. Retry with backoff (seen during capture).

## Slope from elevation

EPQS answers one point per call. Slope at the field point from four neighbours ~30 m away:

```
dz/dx = (z(east) - z(west))  / (2 x 30 m)
dz/dy = (z(north) - z(south)) / (2 x 30 m)
slope_% = 100 x sqrt((dz/dx)² + (dz/dy)²)
aspect  = atan2(dz/dx, dz/dy)    # direction the slope faces
```

For many points or whole fields, download a 3DEP tile once (The National Map, GeoTIFF); GeoTIFF tiles cover whole areas in one download.

SSURGO also carries a representative slope per component (`slope_r`, `ssurgo.md`): 1% for Hastings here.

## Documentation

- EPQS: https://epqs.nationalmap.gov/v1/docs
- 3DEP: https://www.usgs.gov/3d-elevation-program
- SRTM: https://www.earthdata.nasa.gov/data/instruments/srtm
- NASADEM: https://lpdaac.usgs.gov/products/nasadem_hgtv001/
