# Cropland Data Layer (USDA NASS CropScape)

A 30 m map of what was planted on every field in the contiguous U.S., every year since 2008 (some states since 1997), classified from satellite imagery and trained on Farm Service Agency records.

| | |
|---|---|
| Endpoint | `GET https://nassgeodata.gmu.edu/axis2/services/CDLService/GetCDLValue` |
| Auth | none |
| Coordinates | **projected**, EPSG:5070 (CONUS Albers Equal Area, NAD83), in metres, not lat/lon |
| Resolution | 30 m |
| Release | previous year's layer is published around January-February |
| Accuracy | corn and soybeans typically above 95% in the Corn Belt; minor crops lower (see NASS accuracy tables per state) |
| Other operations | `GetCDLStat` (acreage statistics for an area), `GetCDLFile` (clip a GeoTIFF), `ExtractCDLByValues` |
| Docs | https://nassgeodata.gmu.edu/CropScape/devhelp/help.html |

## Request

The service takes EPSG:5070 coordinates (Albers equal area: standard parallels 29.5° and 45.5°, origin 23° N / 96° W, GRS80 ellipsoid).

```
GET /axis2/services/CDLService/GetCDLValue?year=2025&x=-125249.1&y=1994380.6
```

(40.95, -97.50) → x = -125249.1, y = 1994380.6.

## Sample responses (Captured)

The response is XML wrapping a JavaScript-style object (keys not quoted), so parse with a regex, not a JSON parser:

```xml
<ns1:GetCDLValueResponse xmlns:ns1="http://cropscape.csiss.gmu.edu/CDLService/"><Result>{x: -125249.1, y: 1994380.6, value: 5, category: "Soybeans", color: "#267300"}</Result></ns1:GetCDLValueResponse>
```

```xml
<ns1:GetCDLValueResponse xmlns:ns1="http://cropscape.csiss.gmu.edu/CDLService/"><Result>{x: -125249.1, y: 1994380.6, value: 1, category: "Corn", color: "#FFD400"}</Result></ns1:GetCDLValueResponse>
```

Five-year history for the reference field (Captured):

| Year | value | category |
|---|---|---|
| 2021 | 5 | Soybeans |
| 2022 | 1 | Corn |
| 2023 | 5 | Soybeans |
| 2024 | 1 | Corn |
| 2025 | 5 | Soybeans |

The sequence alternates corn and soybeans.

A point in town returns `value: 122, category: "Developed/Low Intensity"` (Captured): points that fall off cropland return non-crop classes.

## Codes (selection)

| value | category | | value | category |
|---|---|---|---|---|
| 1 | Corn | | 36 | Alfalfa |
| 4 | Sorghum | | 37 | Other Hay/Non Alfalfa |
| 5 | Soybeans | | 59 | Sod/Grass Seed |
| 2 | Cotton | | 61 | Fallow/Idle Cropland |
| 21 | Barley | | 176 | Grassland/Pasture |
| 23 | Spring Wheat | | 26 | Dbl Crop WinWht/Soybeans |
| 24 | Winter Wheat | | 225 | Dbl Crop WinWht/Corn |
| 28 | Oats | | 111 | Open Water |
| 27 | Rye | | 121-124 | Developed (open space to high intensity) |
| 205 | Triticale | | 141-143 | Forest |

"Dbl Crop" classes (22x, 26) mean two crops in one year: evidence the field can carry a winter crop or cover. Full legend: CropScape help page.

## Notes

- One 30 m pixel can land on a field edge, waterway or headland. Sample a few pixels inside the field (or use the field polygon with `GetCDLStat`) and take the majority.
- Classification errors happen, especially for minor crops and cover crops (cover crops are not mapped at all).
- The current year is not available until the following winter.

## Documentation

- CropScape developer guide: https://nassgeodata.gmu.edu/CropScape/devhelp/help.html
- CDL metadata and accuracy by state: https://www.nass.usda.gov/Research_and_Science/Cropland/metadata/meta.php
- Legend: https://www.nass.usda.gov/Research_and_Science/Cropland/docs/CDL_codes_names_colors.xlsx
