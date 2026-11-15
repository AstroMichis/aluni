# GBIF occurrence records (and Atlas of Living Australia)

The Global Biodiversity Information Facility (GBIF) aggregates species occurrence records (specimens, human observations, traps, eDNA) from thousands of publishers into one index with a keyless REST API, asynchronous downloads (free account) and monthly Parquet snapshots on public cloud buckets. Every record carries its own licence: CC0 1.0, CC BY 4.0 or CC BY-NC 4.0. Pest occurrence is one use: a crop pest is a taxon like any other, so the API answers "where and when has this species been recorded" with coordinates, date, basis of record and licence. GBIF has no "agricultural pest" flag; the pest list must come from elsewhere (EPPO Codes, host tables). The Atlas of Living Australia (ALA) is a national node with its own API and the same per-record licence model; it is covered at the end.

| | |
|---|---|
| Provider | GBIF Secretariat (Copenhagen); Atlas of Living Australia (CSIRO) |
| Base URL | `https://api.gbif.org/v1/` ; snapshots `s3://gbif-open-data-{region}/occurrence/YYYY-MM-DD/` (also `https://gbif-open-data-us-east-1.s3.amazonaws.com/`) ; ALA `https://api.ala.org.au/occurrences/` |
| Auth | none for search, count and species match; free GBIF account for asynchronous downloads; none for the S3 snapshots |
| Formats | JSON (API); Darwin Core Archive or CSV (downloads); Parquet (snapshots) |
| Coverage | global, all taxa |
| Resolution | point records (`decimalLatitude`, `decimalLongitude`, `coordinateUncertaintyInMeters`) with event date |
| Cadence / latency | index updated continuously as publishers are crawled; snapshots monthly (67 snapshot folders from 2021-04-13 to 2026-11-01 in `us-east-1`) |
| Rate limits / quotas | GBIF: "we highly recommend you set the HTTP User-Agent to a URL or email address ... Rapid or numerous queries to search APIs may be rate limited"; search paging is capped (`limit` max 300) |
| Licence | per record: CC0 1.0, CC BY 4.0, CC BY-NC 4.0; the `license` filter selects |
| Documentation | https://techdocs.gbif.org/en/openapi/ ; https://github.com/gbif/occurrence/blob/dev/aws-public-data.md |

## Requests

### Species match

Resolves a name to a GBIF backbone `usageKey` (the `taxonKey` used in occurrence queries).

| Parameter | Required | Description | Example |
|---|---|---|---|
| `name` | yes | Scientific name | `Spodoptera frugiperda` |
| `kingdom`, `rank`, `strict` | no | Disambiguation | `Animalia` |

```
GET https://api.gbif.org/v1/species/match?name=Spodoptera%20frugiperda
```

### Sample response (Captured 2026-11-15)

Untrimmed.

```json
{"usageKey":5109855,"scientificName":"Spodoptera frugiperda J.E.Smith, 1797","canonicalName":"Spodoptera frugiperda","rank":"SPECIES","status":"ACCEPTED","confidence":99,"matchType":"EXACT","kingdom":"Animalia","phylum":"Arthropoda","order":"Lepidoptera","family":"Noctuidae","genus":"Spodoptera","species":"Spodoptera frugiperda","kingdomKey":1,"phylumKey":54,"classKey":216,"orderKey":797,"familyKey":7015,"genusKey":1765207,"speciesKey":5109855,"class":"Insecta"}
```

### Occurrence search (licence-filtered)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `taxonKey` or `scientificName` | no | Taxon | `5109855` |
| `country` | no | ISO 3166-1 alpha-2 | `US` |
| `stateProvince` | no | Verbatim-interpreted state | `Nebraska` |
| `license` | no, repeatable | `CC0_1_0`, `CC_BY_4_0`, `CC_BY_NC_4_0` | `CC0_1_0` and `CC_BY_4_0` |
| `year` | no | Year or range `a,b` | `2023,2025` |
| `geometry` | no | WKT polygon | |
| `decimalLatitude`, `decimalLongitude` | no | Ranges `a,b` | `40,42` |
| `facet`, `facetLimit` | no | Counts by field | `license` |
| `limit`, `offset` | no | Paging (max 300 per page) | `2` |

```
GET https://api.gbif.org/v1/occurrence/search?scientificName=Spodoptera%20frugiperda&country=US&stateProvince=Nebraska&license=CC0_1_0&license=CC_BY_4_0&year=2023,2025&limit=2
```

### Sample response (Captured 2026-11-15)

14,113 bytes, `count` 4. Trimmed to selected fields of the two returned records (extensions, multimedia, identifiers and verbatim fields removed).

```json
{"offset":0,"limit":2,"endOfRecords":false,"count":4,"results":[
 {"key":5889646518,"datasetKey":"50c9509d-22c7-4a22-a47d-8c48425ef4a7","datasetName":"iNaturalist research-grade observations",
  "license":"http://creativecommons.org/publicdomain/zero/1.0/legalcode","basisOfRecord":"HUMAN_OBSERVATION",
  "eventDate":"2025-07-26T20:21","year":2025,"decimalLatitude":40.855387,"decimalLongitude":-96.688344,
  "coordinateUncertaintyInMeters":848.0,"countryCode":"US","stateProvince":"Nebraska",
  "scientificName":"Spodoptera frugiperda J.E.Smith, 1797","taxonKey":5109855,"occurrenceStatus":"DETECTED",
  "institutionCode":"iNaturalist","issues":["COORDINATE_ROUNDED","CONTINENT_DERIVED_FROM_COORDINATES","TAXON_ID_NOT_FOUND"]},
 {"key":5838117786,"datasetName":"iNaturalist research-grade observations",
  "license":"http://creativecommons.org/licenses/by/4.0/legalcode","basisOfRecord":"HUMAN_OBSERVATION",
  "eventDate":"2025-08-31T22:06","year":2025,"decimalLatitude":41.716758,"decimalLongitude":-103.673114,
  "coordinateUncertaintyInMeters":15.0,"countryCode":"US","stateProvince":"Nebraska","occurrenceStatus":"DETECTED"}
]}
```

Non-US example, Kenya (`taxonKey=5109855&country=KE&license=CC0_1_0&license=CC_BY_4_0&limit=1&facet=year`): `count` 662; the first record is an eDNA `MATERIAL_SAMPLE` from 2022-05-01 at 0.2925, 34.7622 published from GB under CC BY 4.0; the year facet showed 166 records in 2017, 2 in 2018, 2 in 2019, 1 in 2022.

### Licence and region facets

```
GET https://api.gbif.org/v1/occurrence/search?taxonKey=5109855&country=US&limit=0&facet=license&facet=stateProvince&facetLimit=8
```

### Sample response (Captured 2026-11-15)

Untrimmed.

```json
{"offset":0,"limit":0,"endOfRecords":false,"count":9073,"results":[],"facets":[
 {"field":"LICENSE","counts":[{"name":"CC_BY_NC_4_0","count":6218},{"name":"CC0_1_0","count":1691},{"name":"CC_BY_4_0","count":1164}]},
 {"field":"STATE_PROVINCE","counts":[{"name":"Texas","count":4539},{"name":"Illinois","count":423},{"name":"Georgia","count":335},{"name":"Oklahoma","count":324},{"name":"Florida","count":293},{"name":"Alabama","count":286},{"name":"Mississippi","count":219},{"name":"Maryland","count":189}]}]}
```

69% of US fall armyworm records (6,218 of 9,073) are CC BY-NC.

### Occurrence count

```
GET https://api.gbif.org/v1/occurrence/count?taxonKey=5109855&country=US
```

### Sample response (Captured 2026-11-15)

Body `9073` (a bare integer). Same request with `country=KE` returned `667`.

### Monthly snapshots (anonymous S3)

```
GET https://gbif-open-data-us-east-1.s3.amazonaws.com/?prefix=occurrence/&delimiter=/
GET https://gbif-open-data-us-east-1.s3.amazonaws.com/?prefix=occurrence/2026-11-01/&delimiter=/
GET https://gbif-open-data-us-east-1.s3.amazonaws.com/occurrence/2026-11-01/citation.txt
```

### Sample response (Captured 2026-11-15)

The first listing returned 67 `CommonPrefixes` from `occurrence/2021-04-13/` to `occurrence/2026-11-01/`. The second (791 bytes) returned one object and one prefix:

```xml
<ListBucketResult><Name>gbif-open-data-us-east-1</Name><Prefix>occurrence/2026-11-01/</Prefix>
 <Contents><Key>occurrence/2026-11-01/citation.txt</Key><LastModified>2026-11-02T12:14:58.000Z</LastModified><Size>87</Size></Contents>
 <CommonPrefixes><Prefix>occurrence/2026-11-01/occurrence.parquet/</Prefix></CommonPrefixes>
</ListBucketResult>
```

`citation.txt`: `GBIF.org (1 November 2026) GBIF Occurrence Download https://doi.org/10.15468/dl.jeesns`

The GBIF README says the buckets exist in five regions (`af-south-1`, `ap-southeast-2`, `eu-central-1`, `sa-east-1`, `us-east-1`) and that "The snapshot includes all CC0, CC-BY and CC-BY-NC licensed data published through GBIF".

## Fields

### Occurrence (API and Parquet; Parquet names are lowercase)

| Field | Type | Unit | Description |
|---|---|---|---|
| `key` / `gbifid` | integer / string | | GBIF occurrence id |
| `datasetKey`, `publishingOrgKey` | UUID | | Dataset and publisher |
| `license` | string | | Licence URL (API) or code (`CC0_1_0`, `CC_BY_4_0`, `CC_BY_NC_4_0`) |
| `basisOfRecord` | string | | `PRESERVED_SPECIMEN`, `HUMAN_OBSERVATION`, `MACHINE_OBSERVATION`, `MATERIAL_SAMPLE`, `OCCURRENCE`, ... |
| `occurrenceStatus` | string | | `DETECTED` or `NOT_DETECTED`; the README advises filtering for `DETECTED` |
| `taxonKey`, `speciesKey`, `scientificName` | integer, string | | Aligned to the GBIF backbone |
| `decimalLatitude`, `decimalLongitude` | number | degrees WGS84 | |
| `coordinateUncertaintyInMeters` | number | m | |
| `countryCode`, `stateProvince` | string | | ISO 3166 code; state as interpreted |
| `eventDate`, `year`, `month`, `day` | string, integer | ISO 8601 | |
| `issues` | array | | Interpretation flags (`COORDINATE_ROUNDED`, ...) |

## Licence

- Per record. CC0 1.0 and CC BY 4.0 rows allow commercial reuse (CC BY with attribution); CC BY-NC 4.0 rows do not. The API `license` filter and the Parquet `license` column select rows (read in the README and the API on 2026-11-15).
- The snapshots include NC rows; the README says: "Filter using the license column if you need to exclude CC-BY-NC data".
- Citation: each download and snapshot has a DOI (`citation.txt`).
- The GBIF terms page `https://www.gbif.org/terms` returned a Cloudflare challenge (HTTP 403) to the script, so the data user agreement was not re-read; the verdict "PASS for CC0 and CC BY rows only" comes from the inventory.

## Overlap with NASA sources

- NASA publishes no species occurrence or pest records.
- NASA serves the environmental side of each record's time and place: POWER daily and hourly temperature, humidity and rain (`nasa_power.md`, used by `pest_weather_rules.md`), SMAP soil moisture (`smap.md`), IMERG rainfall (`gpm_imerg.md`) and MODIS or HLS vegetation anomalies (`vegetation_indices.md`).

## Notes

- `scientificName` and `taxonKey` give the same result once the name is matched; use the `usageKey` from species match.
- Records cluster where observers are: Texas holds half of the US fall armyworm records. Absence of records is not absence of the pest.
- The inventory reports a user-filed issue (gbif/occurrence #609) that AWS snapshots since 2025-07-01 miss every parquet part whose number is a multiple of 20 (about 5% of rows); its status was not checked.
- The snapshot Parquet folder was not listed or downloaded (about 180 GB per month per the inventory).

## Atlas of Living Australia

ALA indexes Australian records with the same per-record licence model; `license` is a string per record and the licence list is at `https://collections.ala.org.au/ws/licence`.

```
GET https://api.ala.org.au/occurrences/occurrences/search?q=taxa:%22Spodoptera%20frugiperda%22&pageSize=2
```

### Sample response (Captured 2026-11-15)

4,195 bytes, `totalRecords` 78. First record reduced to selected fields:

```json
{"uuid":"199863af-6071-42ad-980d-c227c406948e","dataResourceName":"NSW DPI Biosecurity Collections","dataResourceUid":"dr22311",
 "license":"CC-BY 4.0 (Int)","scientificName":"Spodoptera frugiperda","vernacularName":"Fall Armyworm",
 "eventDate":1606176000000,"year":2020,"month":"11","stateProvince":"New South Wales","country":"Australia",
 "basisOfRecord":"PRESERVED_SPECIMEN","collectionName":"NSW Insect & Mite Collection","institutionName":"NSW Department of Primary Industries"}
```

`eventDate` is in milliseconds since the Unix epoch. The inventory lists NC resources on ALA (for example "Bugs for Bugs", CC BY-NC) that must be excluded by `license`.

## Documentation

- GBIF API reference: https://techdocs.gbif.org/en/openapi/
- Occurrence search parameters: https://techdocs.gbif.org/en/openapi/v1/occurrence
- Snapshots on AWS: https://github.com/gbif/occurrence/blob/dev/aws-public-data.md ; https://registry.opendata.aws/gbif/
- Snapshot issue #609: https://github.com/gbif/occurrence/issues/609
- ALA web services: https://api-legacy.ala.org.au/ ; https://docs.ala.org.au/
