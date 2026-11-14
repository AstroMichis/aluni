# OpenET

Field-scale (30 m) actual evapotranspiration for the 17 western U.S. states, built from Landsat by an ensemble of six satellite ET models.

| | |
|---|---|
| Base URL | `https://openet-api.org` |
| Auth | API key in the `Authorization` header (`OPENET_API_KEY`), from https://account.etdata.org |
| Coverage | AZ, CA, CO, ID, KS, MT, NE, NV, NM, ND, OK, OR, SD, TX, UT, WA, WY (the reference field in Nebraska is inside) |
| Resolution | 30 m |
| Cadence | daily and monthly; monthly is the stable product |
| Record | 1985 onward for the ensemble in most states (varies by model) |
| Quota | monthly request and area limits per key tier (see account.etdata.org) |
| Docs | https://openet.gitbook.io/docs |

## Models

`Ensemble` (per OpenET: the mean of the models after removing outliers) or a single model: `SSEBop`, `SIMS`, `PTJPL`, `eeMETRIC`, `geeSEBAL`, `DisALEXI`.

## Request: point time series

```
POST https://openet-api.org/raster/timeseries/point
Authorization: <OPENET_API_KEY>
Content-Type: application/json
```

```json
{
  "date_range": ["2025-01-01", "2025-10-31"],
  "interval": "monthly",
  "geometry": [-97.50, 40.95],
  "model": "Ensemble",
  "variable": "ET",
  "reference_et": "gridMET",
  "units": "mm",
  "file_format": "JSON"
}
```

`variable` options include `ET` (actual), `ETo` / `ETr` (reference grass / alfalfa ET from gridMET), `ETof` (fraction of reference = crop coefficient), `NDVI`, and `PR` (gridMET precipitation). For a field polygon, use `/raster/timeseries/polygon` with a GeoJSON-style coordinate list and `"reducer": "mean"`.

## Sample response: `ET`, Ensemble (Captured 2026-11-14)

```json
[
    { "time":"2025-01-01", "et":11.0 },
    { "time":"2025-02-01", "et":25.0 },
    { "time":"2025-03-01", "et":41.0 },
    { "time":"2025-04-01", "et":35.0 },
    { "time":"2025-05-01", "et":61.0 },
    { "time":"2025-06-01", "et":124.0 },
    { "time":"2025-07-01", "et":153.0 },
    { "time":"2025-08-01", "et":138.0 },
    { "time":"2025-09-01", "et":79.0 },
    { "time":"2025-10-01", "et":42.0 }
]
```

One object per interval. The value key is the requested variable in lowercase (`et`, `eto`, `etof`, `pr`), and `time` is the first day of the interval. Units are mm per interval (here mm per month), and ET comes back rounded to whole millimetres. Season total for May-September is **555 mm** in this soybean year (CDL 2025 = Soybeans).

## Same window, other variables (Captured)

The same request with `"variable"` changed. All four requests share the same `time` keys, so they join cleanly:

| Month | `et` (mm) | `eto` reference ET (mm) | `etof` crop coefficient | `pr` rain (mm) | `pr - et` (mm) |
|---|---|---|---|---|---|
| 2025-01 | 11 | 34.671 | 0.317 | 0.7 | -10.3 |
| 2025-02 | 25 | 32.665 | 0.765 | 15.1 | -9.9 |
| 2025-03 | 41 | 89.903 | 0.456 | 39.0 | -2.0 |
| 2025-04 | 35 | 107.414 | 0.326 | 24.9 | -10.1 |
| 2025-05 | 61 | 135.395 | 0.451 | 94.7 | +33.7 |
| 2025-06 | 124 | 158.49 | 0.782 | 120.6 | -3.4 |
| 2025-07 | 153 | 140.67 | 1.088 | 122.9 | -30.1 |
| 2025-08 | 138 | 121.881 | 1.132 | 77.4 | -60.6 |
| 2025-09 | 79 | 96.007 | 0.823 | 26.2 | -52.8 |
| 2025-10 | 42 | 86.378 | 0.486 | 37.8 | -4.2 |

Raw shapes are identical apart from the key, for example `{ "time":"2025-07-01", "etof":1.088 }` and `{ "time":"2025-07-01", "pr":122.9 }`. `eto` keeps three decimals, `pr` one.

`etof` is ET divided by reference ET (`eto`); in winter months `eto` is small, so the ratio varies widely.

## Model spread (Captured)

The same point and months with `"model"` set to individual models (`SSEBop`, `PTJPL`) instead of `Ensemble`:

| Month | Ensemble | SSEBop | PTJPL | Spread |
|---|---|---|---|---|
| 2025-06 | 124 | 112 | 109 | 15 mm (12%) |
| 2025-07 | 153 | 147 | 154 | 7 mm (5%) |
| 2025-08 | 138 | 145 | 132 | 13 mm (9%) |

## Notes

- Outside the 17 states the API returns an error or empty data. Check coverage first and fall back to ECOSTRESS/MODIS.
- The current month is provisional; re-fetch it until the month closes.
- Point requests sample a single 30 m pixel. A polygon endpoint (`/raster/timeseries/polygon`) returns area-reduced values.

## Documentation

- API docs: https://openet.gitbook.io/docs
- Interactive API reference: https://openet-api.org/docs
- Account and keys: https://account.etdata.org
