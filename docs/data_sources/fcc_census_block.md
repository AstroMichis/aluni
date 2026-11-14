# FCC Census Block API

Returns the 2020 Census block, county and state for a latitude/longitude in the United States. Provided by the Federal Communications Commission. Answers synchronously in JSON.

| | |
|---|---|
| Provider | Federal Communications Commission (FCC) |
| Base URL | `https://geo.fcc.gov/api/census/` |
| Auth | none |
| Formats | JSON, XML |
| Coverage | United States and territories |
| Resolution | Census block (2020 vintage by default) |
| Cadence / latency | static per census vintage |
| Rate limits / quotas | not published |
| Documentation | https://geo.fcc.gov/api/census/ |

## Requests

### Block find

Returns the Census block, county and state that contain a point.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `latitude` | yes | WGS84 latitude | `40.95` |
| `longitude` | yes | WGS84 longitude | `-97.50` |
| `format` | no | `json` or `xml` | `json` |
| `censusYear` | no | census vintage (`2010`, `2020`) | `2020` |
| `showall` | no | `true` lists every block when the point lies on a boundary | `false` |

```
GET https://geo.fcc.gov/api/census/block/find?latitude=40.95&longitude=-97.50&format=json
```

### Sample response (Captured 2026-11-14)

```json
{"Block":{"FIPS":"311859696001175","bbox":[-97.501802,40.9445,-97.482658,40.959102]},"County":{"FIPS":"31185","name":"York County"},"State":{"FIPS":"31","code":"NE","name":"Nebraska"},"status":"OK","executionTime":"0"}
```

### Sample response: point on a block boundary (Captured 2026-11-14, latitude 40.87, longitude -97.59)

```json
{"messages":["FCC0001: The coordinate lies on the boundary of mulitple blocks, the block contains the clicked location is selected. For a complete list use showall=true to display 'intersection' element in the Block"],"Block":{"FIPS":"311859698001022","bbox":[-97.590097,40.869895,-97.589521,40.870881]},"County":{"FIPS":"31185","name":"York County"},"State":{"FIPS":"31","code":"NE","name":"Nebraska"},"status":"OK","executionTime":"0"}
```

### Area

Returns the block with county and state names plus FCC market-area codes and the block's 2020 population.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `lat` | yes | WGS84 latitude | `40.95` |
| `lon` | yes | WGS84 longitude | `-97.50` |
| `format` | no | `json` or `xml` | `json` |
| `censusYear` | no | census vintage | `2020` |

```
GET https://geo.fcc.gov/api/census/area?lat=40.95&lon=-97.50&format=json
```

### Sample response (Captured 2026-11-14)

```json
{"input":{"lat":40.95,"lon":-97.5,"censusYear":"2020"},"results":[{"block_fips":"311859696001175","bbox":[-97.501802,40.9445,-97.482658,40.959102],"county_fips":"31185","county_name":"York County","state_fips":"31","state_code":"NE","state_name":"Nebraska","block_pop_2020":6,"amt":"AMT004","bea":"BEA119","bta":"BTA256","cma":"CMA539","eag":"EAG005","ivm":"IVM539","mea":"MEA034","mta":"MTA045","pea":"PEA317","rea":"REA005","rpc":"RPC003","vpc":"VPC004"}]}
```

`amt` through `vpc` are FCC market-area codes (spectrum licensing areas); `block_pop_2020` is the block's 2020 census population.

## Fields

| Field | Type | Description |
|---|---|---|
| `Block.FIPS` | string (15 digits) | state (2) + county (3) + tract (6) + block (4) |
| `Block.bbox` | number[4] | block bounding box: min lon, min lat, max lon, max lat |
| `County.FIPS` | string (5 digits) | state + county FIPS; the last 3 digits are the county code used by USDA NASS (`county_ansi`) |
| `County.name` | string | county name |
| `State.FIPS` | string (2 digits) | state FIPS |
| `State.code` | string | USPS state abbreviation |
| `State.name` | string | state name |
| `status` | string | `OK` on success |
| `messages` | string[] | present only for notices such as boundary points (`FCC0001`; the message text contains the provider's own spelling "mulitple") |
| `executionTime` | string | server time in ms |

## Notes

- Points outside the United States return `status: "OK"` with every FIPS and name field `null` (Captured 2026-11-14 for 48.85, 2.35):
  `{"Block":{"FIPS":null,"bbox":null},"County":{"FIPS":null,"name":null},"State":{"FIPS":null,"code":null,"name":null},"status":"OK","executionTime":"0"}`

## Documentation

- https://geo.fcc.gov/api/census/
