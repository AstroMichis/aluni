# NASA POWER

Prediction Of Worldwide Energy Resources: daily, monthly and climatological weather, solar and soil-wetness values for any point on Earth, built from the MERRA-2 reanalysis and CERES satellite radiation. No login, JSON out, fast (under 1 s per request). The record is gap-free from 1981 to a few days ago, and a climatology endpoint returns long-term monthly normals.

| | |
|---|---|
| Base URL | `https://power.larc.nasa.gov/api/temporal/{daily,monthly,climatology,hourly}/point` |
| Auth | none |
| Resolution | 0.5° x 0.625° meteorology (~50 km), 1° solar; one value per grid cell, so neighbouring farms often share values |
| Latency | daily values appear 1-3 days after the date |
| Fill value | `-999` |
| Rate limit | be polite: one point request carries up to 20 parameters; batch parameters, not requests |
| Docs | https://power.larc.nasa.gov/docs/services/api/ |

## Request

```
GET /api/temporal/daily/point
  ?parameters=T2M,T2M_MAX,T2M_MIN,PRECTOTCORR,RH2M,ALLSKY_SFC_SW_DWN,GWETTOP,GWETROOT,GWETPROF,EVPTRNS,WS2M,T2MDEW
  &community=AG          # AG = agroclimatology units (MJ/m²/day, mm/day)
  &latitude=40.95&longitude=-97.50
  &start=20250701&end=20250705
  &format=JSON           # also CSV, NETCDF, ASCII, ICASA
```

`community=AG` matters: it switches radiation to MJ/m²/day, which crop models expect. Monthly takes `start=2020&end=2024` (years); climatology takes no dates.

## Sample response: daily (Captured)

```json
{
  "type": "Feature",
  "geometry": { "type": "Point", "coordinates": [-97.5, 40.95, 491.1] },
  "properties": {
    "parameter": {
      "T2M":               { "20250701": 24.11, "20250702": 25.78, "20250703": 27.27, "20250704": 26.13, "20250705": 26.49 },
      "T2M_MAX":           { "20250701": 30.17, "20250702": 32.53, "20250703": 32.94, "20250704": 30.88, "20250705": 31.39 },
      "T2M_MIN":           { "20250701": 17.34, "20250702": 18.53, "20250703": 20.86, "20250704": 22.42, "20250705": 22.69 },
      "PRECTOTCORR":       { "20250701": 0.0,   "20250702": 7.47,  "20250703": 0.0,   "20250704": 17.04, "20250705": 5.23 },
      "RH2M":              { "20250701": 57.06, "20250702": 67.25, "20250703": 64.91, "20250704": 76.38, "20250705": 77.61 },
      "ALLSKY_SFC_SW_DWN": { "20250701": 31.02, "20250702": 28.9,  "20250703": 29.97, "20250704": 23.53, "20250705": 28.11 },
      "GWETTOP":           { "20250701": 0.46,  "20250702": 0.5,   "20250703": 0.44,  "20250704": 0.49,  "20250705": 0.54 },
      "GWETROOT":          { "20250701": 0.45,  "20250702": 0.44,  "20250703": 0.43,  "20250704": 0.42,  "20250705": 0.46 },
      "GWETPROF":          { "20250701": 0.46,  "20250702": 0.46,  "20250703": 0.46,  "20250704": 0.45,  "20250705": 0.46 },
      "EVPTRNS":           { "20250701": 10.7,  "20250702": 9.75,  "20250703": 10.87, "20250704": 6.45,  "20250705": 9.66 },
      "WS2M":              { "20250701": 1.06,  "20250702": 2.81,  "20250703": 3.56,  "20250704": 4.13,  "20250705": 2.78 },
      "T2MDEW":            { "20250701": 14.56, "20250702": 18.87, "20250703": 19.69, "20250704": 21.29, "20250705": 21.83 }
    }
  },
  "header": {
    "title": "NASA/POWER Source Native Resolution Daily Data",
    "api": { "version": "v2.10.3", "name": "POWER Daily API" },
    "sources": ["MERRA2", "SYN1DEG", "POWER"],
    "fill_value": -999.0,
    "time_standard": "LST",
    "start": "20250701", "end": "20250705"
  },
  "messages": [],
  "parameters": {
    "T2M": { "units": "C", "longname": "Temperature at 2 Meters" },
    "PRECTOTCORR": { "units": "mm/day", "longname": "Precipitation Corrected" },
    "ALLSKY_SFC_SW_DWN": { "units": "MJ/m^2/day", "longname": "All Sky Surface Shortwave Downward Irradiance" },
    "GWETROOT": { "units": "1", "longname": "Root Zone Soil Wetness" },
    "EVPTRNS": { "units": "MJ/m^2/day", "longname": "Evapotranspiration Energy Flux" }
  }
}
```

Shape notes: values are keyed `parameter -> "YYYYMMDD" -> number`; `geometry.coordinates[2]` is the grid cell's elevation in metres (the grid cell's mean, not the point's); `parameters` carries the units of each parameter.

## Sample response: climatology (Captured)

25-year monthly normals (2001-2025) for the same point. `ANN` is the annual value (for `FROST_DAYS`, the annual total; for `T2M_MAX`/`T2M_MIN`, the extreme).

```json
{
  "properties": { "parameter": {
    "T2M":         { "JAN": -3.95, "APR": 10.69, "MAY": 16.78, "JUL": 25.71, "SEP": 19.41, "OCT": 10.95, "ANN": 10.86 },
    "T2M_MAX":     { "MAY": 36.46, "JUN": 42.64, "JUL": 43.15, "AUG": 40.03, "ANN": 43.15 },
    "T2M_MIN":     { "APR": -8.38, "MAY": -2.35, "SEP": 2.38, "OCT": -6.51, "ANN": -26.83 },
    "FROST_DAYS":  { "MAR": 20.7, "APR": 6.8, "MAY": 0.2, "JUN": 0.0, "SEP": 0.0, "OCT": 4.7, "ANN": 136.2 },
    "PRECTOTCORR": { "APR": 2.38, "MAY": 3.96, "JUN": 3.61, "JUL": 2.51, "AUG": 3.01, "ANN": 1.98 },
    "ALLSKY_SFC_SW_DWN": { "JUN": 24.42, "JUL": 24.24, "DEC": 6.97, "ANN": 15.82 }
  } },
  "header": { "range": "25-year Meteorological and Solar Monthly & Annual Climatologies (January 2001 - December 2025)" }
}
```

Values in this sample: May averages 0.2 frost days (period minimum -2.35 °C); October averages 4.7 frost days.

## Sample response: monthly (Captured, trimmed)

```json
{ "properties": { "parameter": {
  "PRECTOTCORR": { "202005": 4.34, "202006": 1.92, "202007": 3.67, "202013": 1.51,
                   "202305": 1.31, "202306": 2.19, "202307": 3.87, "202313": 1.37 }
} } }
```

Month `13` is the **annual** value (mm/day averaged over the year), not a month. Monthly precipitation is a daily **rate** (mm/day): multiply by days in month for a total.

## Parameters

| Code | Unit |
|---|---|
| `T2M`, `T2M_MAX`, `T2M_MIN` | degC |
| `PRECTOTCORR` | mm/day |
| `RH2M`, `T2MDEW` | %, degC |
| `ALLSKY_SFC_SW_DWN` | MJ/m²/day |
| `WS2M` | m/s |
| `GWETTOP` (0-5 cm), `GWETROOT` (0-100 cm), `GWETPROF` (full profile) | 0-1 wetness |
| `EVPTRNS` | MJ/m²/day (÷ 2.45 = mm/day) |
| `FROST_DAYS` (climatology) | days/month |
| `T2M_RANGE`, `PS`, `QV2M` | |

Wetness is **not** volumetric moisture: 0 is completely dry, 1 is saturated, relative to the model soil. Compare trends and percentiles, not absolute values against SMAP's m³/m³.

## Notes

- One grid cell is ~50 km wide; neighbouring points often return identical values.
- `time_standard: LST` means days are local solar time, not UTC.
- The most recent days can be revised; re-fetch the trailing 7 days on each sync.

## Documentation

- POWER API docs: https://power.larc.nasa.gov/docs/services/api/
- Parameter dictionary: https://power.larc.nasa.gov/parameters/
- Methodology: https://power.larc.nasa.gov/docs/methodology/
