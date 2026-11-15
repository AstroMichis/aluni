# OECD Data Explorer SDMX API (OECD-FAO Agricultural Outlook)

The OECD publishes its statistical databases through a public SDMX 2.1 REST service at `sdmx.oecd.org`, the same service that feeds the OECD Data Explorer web application. Among the dataflows is the OECD-FAO Agricultural Outlook, a joint OECD and FAO ten-year projection of production, consumption, trade and prices for the main agricultural commodities (cereals, oilseeds, sugar, meat, dairy, fish, cotton, biofuels) by country and region, released every July. Requests are keyless; the service returns SDMX-ML, SDMX-JSON or SDMX-CSV. On 2026-11-15 every request from a non-browser client was answered by a Cloudflare JavaScript challenge (HTTP 403), so nothing in this file was captured; the request grammar below is the SDMX 2.1 REST standard that the service implements, and the dataflow details still have to be confirmed from a browser or a client that passes the challenge.

| | |
|---|---|
| Provider | OECD (Trade and Agriculture Directorate for the Agricultural Outlook, jointly with FAO) |
| Base URL | `https://sdmx.oecd.org/public/rest/` |
| Auth | none (keyless); the edge refused the Ruby client with a Cloudflare challenge on 2026-11-15, see Notes |
| Formats | SDMX-ML 2.1 (`genericdata`, `structurespecificdata`), SDMX-JSON (`jsondata`), SDMX-CSV (`csvfile`, `csvfilewithlabels`) |
| Coverage | OECD members, partner economies and world regions; the Outlook covers about 40 commodities for roughly 50 countries plus aggregates |
| Resolution | country or region, commodity, annual |
| Cadence / latency | Outlook: one edition per year (July), ten-year horizon plus history; other dataflows have their own schedules |
| Rate limits / quotas | 60 data downloads per hour per client; traffic from VPNs or anonymised networks is refused (from the inventory's reading of the OECD API best-practices page, not re-read today) |
| Licence | OECD terms and conditions: data may be used for any purpose including commercial use with credit to the OECD; third-party data excluded (from the inventory, not re-read today) |
| Documentation | https://www.oecd.org/en/data/insights/data-explainers/2024/11/Api-best-practices-and-recommendations.html ; https://data-explorer.oecd.org/ |

## Requests

The service follows the SDMX 2.1 RESTful web service specification. Structural metadata lives under `/dataflow`, `/datastructure` and `/codelist`; observations live under `/data`. Agency, resource id and version are joined with commas in the data path.

### List the dataflows of an agency

Returns the dataflows published by one agency, with names and references to their data structure definitions. The agency that publishes the Agricultural Outlook is `OECD.TAD.ATM` (Trade and Agriculture Directorate, Agro-food Trade and Markets division).

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{agencyID}` (path) | yes | Agency identifier, or `all` | `OECD.TAD.ATM` |
| `{resourceID}` (path) | no | Dataflow id, or `all` | `all` |
| `format` | no | `sdmx-json` or `sdmx-2.1`; the `Accept` header can be used instead | `sdmx-json` |
| `references` | no | `children`, `descendants`, `all`: include the referenced structures | `all` |

```
GET https://sdmx.oecd.org/public/rest/dataflow/OECD.TAD.ATM/all?format=sdmx-json
```

### Sample response (Representative)

Shape of an SDMX-JSON structure message, following the SDMX 2.1 REST specification; names and ids below are placeholders to be read from the live response.

```json
{
  "meta": { "schema": "https://json.sdmx.org/2.1/sdmx-json-structure-schema.json", "contentLanguages": ["en"] },
  "data": {
    "dataflows": [
      { "id": "DF_OUTLOOK_2025_2034", "agencyID": "OECD.TAD.ATM", "version": "1.0",
        "name": "OECD-FAO Agricultural Outlook 2025-2034",
        "structure": "urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=OECD.TAD.ATM:DSD_AGR(1.0)" }
    ]
  }
}
```

### Data structure (dimensions and codelists)

Returns the data structure definition referenced by a dataflow: the ordered dimensions that make up a series key and, with `references=children`, their codelists.

```
GET https://sdmx.oecd.org/public/rest/datastructure/OECD.TAD.ATM/DSD_AGR/1.0?references=children&format=sdmx-json
```

### Data query

Returns observations. The key is one code per dimension in the order the data structure defines, separated by dots; an empty position is a wildcard and `+` joins several codes in one position.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{flowRef}` (path) | yes | `agency,dataflow,version` | `OECD.TAD.ATM,DSD_AGR@DF_OUTLOOK_2025_2034,1.0` |
| `{key}` (path) | yes | Dot-separated series key; `all` for everything | `USA+BRA.A.CPC_0112.PROD` (dimension order to be confirmed from the data structure) |
| `startPeriod`, `endPeriod` | no | Time bounds | `2023`, `2034` |
| `dimensionAtObservation` | no | `AllDimensions` flattens the result to one row per observation | `AllDimensions` |
| `format` | no | `csvfilewithlabels`, `csvfile`, `jsondata`, `genericdata` | `csvfilewithlabels` |

```
GET https://sdmx.oecd.org/public/rest/data/OECD.TAD.ATM,DSD_AGR@DF_OUTLOOK_2025_2034,1.0/USA+BRA.A.CPC_0112.PROD?startPeriod=2023&endPeriod=2026&format=csvfilewithlabels
```

### Sample response (Representative)

SDMX-CSV with labels, as the specification defines it: one row per observation, each dimension and attribute as an id column followed by a label column. Column names depend on the data structure; the United States and Brazil are the reporters in the request above.

```csv
STRUCTURE,STRUCTURE_ID,ACTION,REF_AREA,"Reference area",FREQ,"Frequency of observation",COMMODITY,"Commodity",MEASURE,"Measure",TIME_PERIOD,"Time period",OBS_VALUE,"Observation value",UNIT_MEASURE,"Unit of measure",OBS_STATUS,"Observation status"
dataflow,OECD.TAD.ATM:DSD_AGR@DF_OUTLOOK_2025_2034(1.0),I,USA,"United States",A,"Annual",CPC_0112,"Maize",PROD,"Production",2023,"2023",<value>,<value>,T,"Tonnes",,
dataflow,OECD.TAD.ATM:DSD_AGR@DF_OUTLOOK_2025_2034(1.0),I,BRA,"Brazil",A,"Annual",CPC_0112,"Maize",PROD,"Production",2023,"2023",<value>,<value>,T,"Tonnes",,
```

### Request without a browser (Captured 2026-11-15)

All three requests above, and the OECD terms page, returned HTTP 403 with a Cloudflare challenge page (`server: cloudflare`, title "Just a moment..."). Untrimmed first bytes:

```html
<!DOCTYPE html><html lang="en-US"><head><title>Just a moment...</title><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"><meta name="robots" content="noindex,nofollow"> ... https://challenges.cloudflare.com ...
```

## Fields

SDMX-CSV columns common to every OECD dataflow (dimension and attribute columns vary per data structure).

| Field | Type | Unit | Description |
|---|---|---|---|
| `STRUCTURE` | string | | `dataflow` |
| `STRUCTURE_ID` | string | | `agency:dataflow(version)` |
| `ACTION` | string | | `I` (information) in downloads |
| `<DIMENSION>` and `<Dimension label>` | string | | One id column and one label column per dimension, in key order (`REF_AREA`, `FREQ`, commodity, measure, ...) |
| `TIME_PERIOD` | string | year | Observation period |
| `OBS_VALUE` | number | per `UNIT_MEASURE` | Observation |
| `UNIT_MEASURE`, `UNIT_MULT` | string | | Unit code and power-of-ten multiplier |
| `OBS_STATUS` | string | | Status flag (estimate, provisional, ...) |

## Licence

OECD terms and conditions (https://www.oecd.org/en/about/terms-conditions.html): OECD data can be used for any purpose, including commercial use, provided the OECD is credited as the source; material identified as belonging to third parties is excluded. The Agricultural Outlook is co-produced with FAO, so the inventory asks for the co-ownership of that dataflow to be confirmed before redistribution. The terms page returned the same Cloudflare 403 as the API on 2026-11-15, so this comes from the inventory (which cites a secondary source), not re-read today. Verdict in the inventory: PASS, with the FAO co-ownership caveat.

## Overlap with NASA sources

NASA publishes no commodity price, consumption or trade projections. The Outlook's production and area series sit beside NASA Harvest and the GEOGLAM Crop Monitor (crop condition by country and season) and the MODIS and HLS vegetation indices documented in `vegetation_indices.md`, which describe the current season rather than projected balances.

## Notes

- `https://sdmx.oecd.org/public/rest/dataflow/OECD.TAD.ATM/all?format=sdmx-json`, the same path with an SDMX `Accept` header and a browser user agent, the data request above, and `https://www.oecd.org/en/about/terms-conditions.html` all returned HTTP 403 Cloudflare challenge pages on 2026-11-15. The service is reachable from browsers; a server-side client needs to pass the challenge or use an alternative such as the OECD bulk files.
- The dataflow id `DSD_AGR@DF_OUTLOOK_2025_2034` and the dimension order in the sample key were not confirmed today; read them from the dataflow and datastructure responses. The inventory lists the exact Outlook dataflow ids and horizon as unknown.
- The 60 downloads per hour limit and the refusal of VPN traffic come from the OECD API best-practices page cited in the inventory; that page is also behind Cloudflare.
- The SDMX 2.1 REST grammar used here is the public SDMX standard (https://github.com/sdmx-twg/sdmx-rest), which the OECD service implements.

## Documentation

- OECD API best practices: https://www.oecd.org/en/data/insights/data-explainers/2024/11/Api-best-practices-and-recommendations.html
- OECD Data Explorer: https://data-explorer.oecd.org/
- OECD terms and conditions: https://www.oecd.org/en/about/terms-conditions.html
- OECD-FAO Agricultural Outlook: https://www.oecd.org/en/publications/serials/oecd-fao-agricultural-outlook_19991142.html
- SDMX REST specification: https://github.com/sdmx-twg/sdmx-rest
