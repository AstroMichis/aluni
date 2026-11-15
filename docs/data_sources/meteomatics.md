# Meteomatics Weather API

Meteomatics is a commercial weather API with historical, current and forecast data. Its own high-resolution models (EURO1k, US1k) run at 1 km, and it serves more than 1,800 parameters, including soil, evapotranspiration and agricultural indices. The NASA Space Apps 2026 offer gives **1,000 queries per day across all features for the duration of the hackathon**.

| | |
|---|---|
| Provider | Meteomatics AG |
| Base URL | `https://api.meteomatics.com` |
| Auth | Account username and password (sent by email after claiming the offer), as HTTP Basic auth. An OAuth token flow also exists (see Documentation). |
| Formats | `json`, `csv`, `xml`, `html`, `png` (last path segment) |
| Coverage | Global; 1 km downscaling over Europe (EURO1k) and the U.S. (US1k) |
| Resolution | Time steps down to minutes (`PT1H` hourly is typical); spatial per model |
| Cadence / latency | Forecasts updated several times a day; current conditions in near real time |
| Rate limits / quotas | Hackathon offer: 1,000 queries a day. A query is one request, whatever the number of parameters (up to 10 per request). |
| Documentation | https://www.meteomatics.com/en/api/getting-started/ |

## Requests

### Time series at a point

```
GET https://api.meteomatics.com/{validdatetime}/{parameters}/{lat},{lon}/json
Authorization: Basic <username:password>
```

- `validdatetime`: one instant (`2026-11-15T12:00:00Z`) or a range with a step, `start--end:step` (`2026-11-15T12:00:00Z--2026-11-18T12:00:00Z:PT1H`).
- `parameters`: comma-separated `name:unit` strings, at most 10.
- Location: `lat,lon` in decimal degrees. A grid (`lat1,lon1_lat2,lon2:res_lat,res_lon`) and several points (`lat,lon+lat,lon`) also exist.

Example from the official getting-started page (HTML output):

```
https://api.meteomatics.com/2026-11-12T00:00:00Z--2026-11-15T00:00:00Z:PT1H/t_2m:C,precip_1h:mm,wind_speed_10m:ms/52.520551,13.461804/html
```

### Parameters useful for a field

The docs write parameter names with placeholders: `000m` (height), `-000cm` (depth) and `00h` (accumulation period). These are the concrete strings the app requests:

| Parameter | Meaning |
|---|---|
| `t_2m:C` | Air temperature at 2 m |
| `t_min_2m_24h:C`, `t_max_2m_24h:C` | Daily minimum and maximum (frost and heat risk) |
| `precip_1h:mm`, `precip_24h:mm` | Precipitation accumulated over 1 h / 24 h |
| `prob_precip_1h:p` | Probability of precipitation |
| `relative_humidity_2m:p`, `dew_point_2m:C` | Humidity and dew point (disease risk, frost) |
| `wind_speed_10m:ms`, `wind_gusts_10m_1h:ms` | Wind and gusts (spraying windows) |
| `evapotranspiration_1h:mm`, `evapotranspiration_24h:mm` | Evapotranspiration (irrigation) |
| `soil_moisture_index_-5cm:idx`, `soil_moisture_index_-15cm:idx`, `soil_moisture_index_-50cm:idx` | Soil moisture index by depth |
| `volumetric_soil_water_-15cm:m3m3` | Volumetric soil water |
| `t_-5cm:C` | Soil temperature at 5 cm |
| `leaf_wetness:idx` | Leaf wetness |
| `growing_degree_days_accumulated:gdd` | Accumulated growing degree days |
| `frost_depth:cm` | Frost depth |
| `global_rad:W` | Global radiation |

Strings come from the alphabetic parameter list (Documentation). Some need a model or a reference date; check the parameter's page before relying on it.

### Sample response (Representative)

Not fetched: it needs the hackathon account. The shape follows the official JSON format:

```json
{
  "version": "3.0",
  "user": "<username>",
  "dateGenerated": "2026-11-15T12:00:00Z",
  "status": "OK",
  "data": [
    {
      "parameter": "t_2m:C",
      "coordinates": [
        {
          "lat": 40.95,
          "lon": -97.5,
          "dates": [
            { "date": "2026-11-15T12:00:00Z", "value": 8.4 },
            { "date": "2026-11-15T13:00:00Z", "value": 9.1 }
          ]
        }
      ]
    }
  ]
}
```

## Fields

| Field | Type | Unit | Meaning |
|---|---|---|---|
| `status` | string | | `OK` on success |
| `data[].parameter` | string | | The requested `name:unit` string |
| `data[].coordinates[].lat`, `.lon` | number | degrees | The point |
| `data[].coordinates[].dates[].date` | string (ISO 8601, UTC) | | Valid time |
| `data[].coordinates[].dates[].value` | number | per parameter | Value; the unit is the suffix of the parameter string |

## Notes

- Credential names: `METEOMATICS_USERNAME`, `METEOMATICS_PASSWORD` (or credentials `meteomatics.username` / `meteomatics.password`). Values are never written in these docs.
- With 1,000 queries a day, the app caches each answer per point (rounded to 0.01°, about 1 km) and hour (`Meteomatics::Client`, `METEOMATICS_CACHE_TTL_SECONDS`, default 3600). Ask for all the parameters a screen needs in one request instead of one per parameter.
- Access lasts for the duration of the hackathon. The client is off while the credentials are unset (`Platform::Features.meteomatics?`), and `platform:bootstrap` pauses it on a new server.

## Documentation

- Getting started (URL structure, examples): https://www.meteomatics.com/en/api/getting-started/
- Available parameters: https://www.meteomatics.com/en/api/available-parameters/
- Alphabetic parameter list: https://www.meteomatics.com/en/api/available-parameters/alphabetic-list/
- Request structure and options: https://www.meteomatics.com/en/api/request/
- Python connector: https://github.com/meteomatics/python-connector-api
