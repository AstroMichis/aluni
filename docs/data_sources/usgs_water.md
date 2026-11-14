# USGS water: streams and groundwater

Ground-truth water availability near the field: how much is flowing in nearby streams and how deep the water table is in nearby wells. On irrigated farms (much of Nebraska pumps from the High Plains/Ogallala aquifer) groundwater trends are the long-term constraint on which rotations are sustainable.

USGS is migrating from the legacy NWIS Water Services to the new **Water Data OGC API**. The legacy instantaneous-values service still answered on 2026-11-14. The legacy groundwater endpoint already answers 403 (Captured).

| | New | Legacy |
|---|---|---|
| Base | `https://api.waterdata.usgs.gov/ogcapi/v0/collections/{collection}/items` (v1 links are returned in responses) | `https://waterservices.usgs.gov/nwis/iv/` |
| Format | GeoJSON (`f=json`), paginated with `links[rel=next]` cursors | WaterML-as-JSON |
| Auth | none (an optional free API key raises rate limits) | none |
| Docs | https://api.waterdata.usgs.gov/ | https://waterservices.usgs.gov/ |

Parameter codes: `00060` streamflow (ft³/s), `00065` gage height (ft), `72019` depth to water below land surface (ft), `62611` groundwater level above NAVD88 (ft).

## Groundwater: field measurements (Captured)

```
GET /ogcapi/v0/collections/field-measurements/items
    ?bbox=-97.800,40.650,-97.200,41.250
    &parameter_code=72019
    &datetime=2024-01-01/..
    &limit=3&f=json
```

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "field_measurements_series_id": "2eccf39b-6628-4d32-b01d-8816715ed9e4",
        "reading_type": "ReferencePrimary",
        "parameter_code": "72019",
        "monitoring_location_id": "USGS-411410097173003",
        "observing_procedure": "GW level, electric tape",
        "value": "99.89",
        "unit_of_measure": "ft",
        "time": "2024-04-02T18:00:00+00:00",
        "qualifier": ["Static"],
        "approval_status": "Approved",
        "measuring_agency": "NE008",
        "year": 2024, "month": 4, "day": 2
      },
      "id": "017ff37e-e495-4188-bfa6-19eea2e78855",
      "geometry": { "type": "Point", "coordinates": [-97.2919867570974, 41.2361251680045] }
    },
    {
      "type": "Feature",
      "properties": {
        "monitoring_location_id": "USGS-411134097123401",
        "observing_procedure": "GW level, estim, report, observ",
        "parameter_code": "72019", "value": "21.50", "unit_of_measure": "ft",
        "time": "2025-04-09T18:00:00+00:00", "qualifier": ["Static"], "approval_status": "Approved", "measuring_agency": "NE013"
      },
      "geometry": { "type": "Point", "coordinates": [-97.2097620005497, 41.1927909564671] }
    },
    {
      "type": "Feature",
      "properties": {
        "monitoring_location_id": "USGS-411035097370701",
        "observing_procedure": "GW level, estim, report, observ",
        "parameter_code": "72019", "value": "55.57", "unit_of_measure": "ft",
        "time": "2024-04-08T18:00:00+00:00", "qualifier": ["Static"], "approval_status": "Approved", "measuring_agency": "NE031"
      },
      "geometry": { "type": "Point", "coordinates": [-97.6189405844734, 41.1764034651893] }
    }
  ]
}
```

`value` is a string in **feet below land surface** (bigger = deeper water). Wells are measured by hand, typically each spring before pumping (`qualifier: Static`), so expect one value per well per year. Depth varies between neighbouring wells (21.5 ft to 99.9 ft in this sample).

## Streamflow: latest value (Captured)

```
GET /ogcapi/v0/collections/latest-continuous/items
    ?bbox=-98.000,40.450,-97.000,41.450&parameter_code=00060&limit=2&f=json
```

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "time_series_id": "d8764ab593b649538fb4662aa809f9c8",
        "monitoring_location_id": "USGS-06773500",
        "parameter_code": "00060",
        "statistic_id": "00011",
        "time": "2026-11-14T20:45:00+00:00",
        "value": "38.8",
        "unit_of_measure": "ft^3/s",
        "approval_status": "Provisional"
      },
      "geometry": { "type": "Point", "coordinates": [-97.67545, 41.329233] }
    },
    {
      "type": "Feature",
      "properties": {
        "monitoring_location_id": "USGS-06880500",
        "parameter_code": "00060",
        "time": "1994-10-01T04:00:00+00:00",
        "value": "46.0",
        "unit_of_measure": "ft^3/s",
        "approval_status": "Approved"
      },
      "geometry": { "type": "Point", "coordinates": [-97.1116666666667, 40.9030555555556] }
    }
  ],
  "numberReturned": 2,
  "links": [
    { "rel": "next", "href": "https://api.waterdata.usgs.gov/ogcapi/v1/collections/latest-continuous/items?cursor=NjQ3...&bbox=...&limit=2&f=json" }
  ]
}
```

The second station's "latest" value is from **1994**: a discontinued gauge. The `time` field gives the date of the latest value. For history use the `daily` collection (daily means) with a `datetime` range.

## Legacy instantaneous values (Captured, trimmed)

```
GET https://waterservices.usgs.gov/nwis/iv/?format=json&bBox=-98.0000,40.4500,-97.0000,41.4500&parameterCd=00060,00065&siteStatus=active
```

```json
{ "value": { "timeSeries": [ {
  "sourceInfo": {
    "siteName": "Silver Creek, at Mile 4 near Silver Creek, Nebr.",
    "siteCode": [{ "value": "06772898", "network": "NWIS", "agencyCode": "USGS" }],
    "geoLocation": { "geogLocation": { "srs": "EPSG:4326", "latitude": 41.297347, "longitude": -97.714031 } },
    "siteProperty": [{ "value": "ST", "name": "siteTypeCd" }, { "value": "102001030304", "name": "hucCd" }, { "value": "31", "name": "stateCd" }]
  },
  "variable": { "variableCode": [{ "value": "00060" }], "variableName": "Streamflow, ft&#179;/s", "unit": { "unitCode": "ft3/s" }, "noDataValue": -999999.0 },
  "values": [{ "value": [{ "value": "60.9", "qualifiers": ["P"], "dateTime": "2026-11-14T14:45:00.000-06:00" }] }],
  "name": "USGS:06772898:00060:00000"
} ] } }
```

`qualifiers: ["P"]` = provisional. `hucCd` is the watershed (HUC-12) code: useful to group farms by watershed.

## Notes

- Gauges and wells are sparse; at the reference point the nearest returned were 20-40 km away.
- Many state agencies (`measuring_agency` `NE008`, `NE013`, `NE031` here are Nebraska natural resources districts) report through USGS; data quality varies by `observing_procedure` ("estim, report" is less precise than "electric tape").
- USGS is migrating from the legacy services to the Water Data OGC API.

## Documentation

- Water Data OGC API: https://api.waterdata.usgs.gov/
- Legacy Water Services: https://waterservices.usgs.gov/
- Parameter codes: https://help.waterdata.usgs.gov/codes-and-parameters/parameters
