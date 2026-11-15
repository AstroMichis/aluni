# EPPO Codes and the EPPO Global Database

The European and Mediterranean Plant Protection Organization (EPPO) maintains two linked resources. EPPO Codes are a harmonized 5 or 6 letter coding system for plants, pests and pathogens (more than 98,500 species as of June 2025) with preferred and synonym names in many languages and a parent/child taxonomy; they are distributed through the EPPO Data Portal (`data.eppo.int`) as bulk files and through a keyed REST API. The EPPO Global Database (GD, `gd.eppo.int`) adds, for about 1,900 pests of regulatory interest, host plants, country and state level distribution with pest status, quarantine categorization by country, Reporting Service articles, photos and datasheets; the same content is served by the Global Database API v2 (`api.eppo.int/gd/v2`) with an API key. The codes are under an open licence; the GD website carries "All Rights Reserved" and no licence grant for host or distribution data was found.

| | |
|---|---|
| Provider | EPPO (European and Mediterranean Plant Protection Organization), Paris |
| Base URL | API v2 `https://api.eppo.int/gd/v2` (OpenAPI spec `https://api.eppo.int/gd/v2/eppo_api_gd_v2.yml`); legacy v1 `https://api.eppo.int/gd/v1` (spec `.../gd/v1/eppo_api_gd_v1.yml`); legacy Data Service REST `https://data.eppo.int/api/rest/1.0/`; website `https://gd.eppo.int/` |
| Auth | API: `X-Api-Key` header, key generated in the Data Portal dashboard after free registration and acceptance of the Open Data Licence; every v2 endpoint including `/status` returned HTTP 401 `{"error":"API key is missing"}` without one. Website pages and the per-taxon CSV/XLSX exports: none |
| Formats | JSON (API); HTML, CSV, XLSX (website); EPPO Codes bulk exports in XML, SQL and JSON (portal, login required) |
| Coverage | Codes: more than 98,500 species (59,000 plants, 27,500 animals, 12,000 microorganisms) plus 625 non-taxonomic entities; GD detail (hosts, distribution, categorization): about 1,900 regulated pests (count from the inventory, not re-verified) |
| Resolution | Codes: one record per taxon; distribution: country, with state or province for large countries (United States, Canada, China, etc.) |
| Cadence / latency | Codes: about 2,000 new codes per year, monthly users newsletter; GD distribution pages show a "Last updated" date per taxon (LAPHFR: 2026-09-01) |
| Rate limits / quotas | API v2: 2,000 requests per IP address in a 10-second sliding window (effective 2026-05-22), HTTP 429 beyond that (from the spec) |
| Licence | EPPO Codes: EPPO Open Data Licence (free registration, attribution and download date). GD hosts, distribution, categorization, Reporting Service: no licence grant found; website footer "EPPO 2026 All Rights Reserved". See Licence |
| Documentation | https://data.eppo.int/apis/ (API cards) ; https://api.eppo.int/gd/v2/eppo_api_gd_v2.yml ; https://www.eppo.int/RESOURCES/eppo_databases/eppo_codes ; https://gd.eppo.int/ |

### Portal and service transition (checked 2026-11-15)

| Location | Status | Notes |
|---|---|---|
| `https://data.eppo.int/` | HTTP 200 | "EPPO Data Portal - Professional API Access". Free account, "accept the Open Data Licence to access all EPPO Data Portal services", API keys and data downloads from the dashboard. Lists "API v2.1 Released". |
| `https://data.eppo.int/legacy` | HTTP 200 | "Starting December 7, 2025, the EPPO Data Service has evolved into the EPPO Data Portal"; all users must create a new account; legacy endpoints `/api/rest/` and `/api/logshipping/` "remain active for a limited period". An end-of-life date of September 1, 2026 is present in the page source inside an HTML comment, so it is not displayed. |
| `https://data.eppo.int/api/rest/1.0/tools/names2codes`, `.../taxon/LAPHFR` | HTTP 403 | Legacy REST 1.0 still answers: `{"message":"You do not have sufficent rights to perform this operation"}` (spelling as served) without a token. |
| `https://data.eppo.int/docs/` | HTTP 200 | "Authentication Required: Please log in to access and download documents and data files." Lists the EPPO Codes Database in XML, SQL and JSON formats and the EPPO Standards (PP and PM series). |
| `https://data.eppo.int/data/Open_Licence.pdf` | HTTP 200 (HEAD) | `application/pdf`, 22,725 bytes, Last-Modified 2014-11-17. Not read in this pass. The path `/media/Open_Licence.pdf` cited in the inventory returned HTTP 404. |
| `https://api.eppo.int/gd/v2/eppo_api_gd_v2.yml` | HTTP 200 | OpenAPI 3.0.0, "version: 2.0.4 - 2026.07.04", 82,613 bytes, served as `application/octet-stream`. |

## Requests

### API v2 endpoint list (from the OpenAPI spec)

All paths are relative to `https://api.eppo.int/gd/v2` and need `X-Api-Key`. Responses are JSON.

| Group | Paths |
|---|---|
| General | `/status` |
| Taxons | `/taxons/list`; `/taxons/taxon/{EPPOCODE}/overview`, `/infos`, `/names`, `/taxonomy`, `/categorization`, `/kingdom`, `/hosts`, `/pests`, `/vectors`, `/vectorof`, `/bca`, `/bcaof`, `/photos`, `/reporting_articles`, `/documents`, `/standards`, `/distribution` |
| Country | `/country/{ISOCODE}/overview`, `/categorization`, `/presence` |
| RPPO | `/rppo/{RPPOCODE}/overview`, `/categorization` |
| Reportings | `/reportings/list`, `/reportings/reporting/{reporting_id}`, `/reportings/article/{article_id}` |
| References | `/references/rppos`, `/qList`, `/distributionStatus`, `/pestHostClassification`, `/vectorClassification`, `/countries`, `/countriesStates` |
| Tools | `/tools/name2codes`, `/tools/search` |

`EPPOCODE` matches `^[0-9A-Z]{5,6}$` (example in the spec: `BEMITA`, Bemisia tabaci); `ISOCODE` is a two-letter country code; `RPPOCODE` matches `^9[A-Z]$`.

### Hosts of a taxon (API v2, key required)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{EPPOCODE}` (path) | yes | EPPO code of the pest | `LAPHFR` (Spodoptera frugiperda, fall armyworm) |
| `X-Api-Key` (header) | yes | Portal API key | |

```
GET https://api.eppo.int/gd/v2/taxons/taxon/LAPHFR/hosts
```

### Sample response (Representative)

Field names and types are from the spec (`getGDTaxonHosts`); the values are the first two rows of the host CSV export captured from the website (below). Not fetched from the API: no key.

```json
[
  {"eppocode": "GLXMA", "prefname": "Glycine max", "class_id": 1, "class_label": "Major host",
   "bibref": "* Montezano DG, Specht A, Sosa-Gómez DR, Roque-Specht VF, Sousa-Silva JC, Paula-Moraes SV, Peterson JA, Hunt T (2018) Host plants of Spodoptera frugiperda (Lepidoptera: Noctuidae) in the Americas. African Entomology 26, 286-300."},
  {"eppocode": "GOSHI", "prefname": "Gossypium hirsutum", "class_id": 1, "class_label": "Major host", "bibref": "* Montezano DG, ... African Entomology 26, 286-300."}
]
```

`class_id` values are listed by `/references/pestHostClassification` (`class_id`, `class_label` such as "Major host", "Minor host", "Major pest"); the integer shown here is illustrative.

### Request without a key (Captured 2026-11-15)

```
GET https://api.eppo.int/gd/v2/taxons/taxon/LAPHFR/hosts
GET https://api.eppo.int/gd/v2/status
```

Both returned HTTP 401, untrimmed:

```json
{"error":"API key is missing"}
```

### Distribution of a taxon (API v2, key required)

```
GET https://api.eppo.int/gd/v2/taxons/taxon/LAPHFR/distribution
```

### Sample response (Representative)

Array of `DistributionItem` objects as defined in the spec; the values follow the United States rows of the captured distribution page ("Present, no details"). Status codes are listed by `/references/distributionStatus` (`peststatus` such as "A", "B", "C" with labels such as "Present, widespread", "Absent, pest eradicated"); the letter shown is illustrative.

```json
[
  {"country_iso": "US", "state_id": null, "peststatus": "A", "yr_situation": null, "yr_introd": null, "yr_erad": null},
  {"country_iso": "US", "state_id": "US-NE", "peststatus": "A", "yr_situation": null, "yr_introd": null, "yr_erad": null}
]
```

### Name to codes (API v2, key required)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `name` | yes | Taxon name to search | `Spodoptera frugiperda` |
| `onlyPreferred` | no | `true` (default) searches preferred names only | `false` |

```
GET https://api.eppo.int/gd/v2/tools/name2codes?name=Spodoptera%20frugiperda
```

### Sample response (Representative)

`NameToCodeResponse` from the spec: `eppocode` and `preferred` (whether the searched name is the preferred name for that code).

```json
[{"eppocode": "LAPHFR", "preferred": true}]
```

`/tools/search?keyword=Bemisia&searchMode=2` (1 whole word, 2 starting with, 3 containing; minimum 3 characters, at most 10 results) returns `eppocode`, `full_name`, `is_preferred`, `isolang`, `language`.

### Global Database web pages (no login)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{CODE}` (path) | yes | EPPO code | `LAPHFR` |
| section (path) | no | `hosts`, `distribution`, `categorization`, `reporting`, `photos`, `documents`, `datasheet` | `hosts` |

```
GET https://gd.eppo.int/taxon/LAPHFR
GET https://gd.eppo.int/taxon/LAPHFR/hosts
GET https://gd.eppo.int/taxon/LAPHFR/distribution
GET https://gd.eppo.int/taxon/LAPHFR/categorization
```

### Sample response (Captured 2026-11-15)

HTML (18,670, 217,859, 138,883 and 15,880 bytes). Text extracted from the markup; each page trimmed to the rows that show its structure.

```
Overview   Code created in: 2002-10-29
  EPPO Code: LAPHFR   Preferred name: Spodoptera frugiperda   Authority: (Smith)
  Other scientific names: Laphygma frugiperda (Smith)
  Common names: fall armyworm (English US), cogollero del maíz (Spanish), gusano cogollero del maíz (Spanish MX), ...

Hosts      "Categories have been assigned by the EPPO Secretariat ... remain indicative only."
  Glycine max (GLXMA)        Major host   * Montezano DG, ... (2018) ... African Entomology 26, 286-300.
  Zea mays (ZEAMX)           Major host   * Maruthadurai R, Ramesh R (2020) ...; * Montezano DG ... (2018); * Nurkomar I ... (2023) ...
  Abelmoschus esculentus (ABMES)   Host   * Montezano DG, ... (2018)
  ... (358 host rows: 6 Major host, 351 Host, 1 Experimental)

Distribution   Last updated: 2026-09-01   Legend: Present, Transient
  Continent | Country                  | State    | Status
  Africa    | Angola                   |          | Present, no details   view...
  America   | United States of America |          | Present, no details
  America   | United States of America | Alabama  | Present, no details
  America   | United States of America | Iowa     | Present, no details
  ...

Categorization
  Country/NPPO | List            | Year addition | Year transfer | Year deletion
  Morocco      | Quarantine pest | 2018          |               |
  Tunisia      | Quarantine pest | 2012          |               |
  Bahrain      | A1 list         | 2003          |               |
  ...
```

Footer of every GD page: "EPPO 2026 All Rights Reserved".

### Global Database CSV export (no login)

The hosts and distribution pages link "Save list as csv file" and "Save list as excel file".

```
GET https://gd.eppo.int/taxon/LAPHFR/download/hosts_csv
GET https://gd.eppo.int/taxon/LAPHFR/download/hosts_xlsx
GET https://gd.eppo.int/taxon/LAPHFR/download/distribution_csv
GET https://gd.eppo.int/taxon/LAPHFR/download/distribution_xlsx
```

### Sample response (Captured 2026-11-15)

`hosts_csv`: HTTP 200, 102,921 bytes, served with `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` although the body is CSV. References are multi-line quoted strings. Trimmed to the header and three rows; the third row's reference list shortened.

```csv
"type","EPPOCode","Pref_name","References"
"Major host","GLXMA","Glycine max","* Montezano DG, Specht A, Sosa-Gómez DR, Roque-Specht VF, Sousa-Silva JC, Paula-Moraes SV, Peterson JA, Hunt T (2018) Host plants of Spodoptera frugiperda (Lepidoptera: Noctuidae) in the Americas. African Entomology 26, 286-300."
"Major host","GOSHI","Gossypium hirsutum","* Montezano DG, Specht A, Sosa-Gómez DR, Roque-Specht VF, Sousa-Silva JC, Paula-Moraes SV, Peterson JA, Hunt T (2018) Host plants of Spodoptera frugiperda (Lepidoptera: Noctuidae) in the Americas. African Entomology 26, 286-300."
"Major host","ORYSA","Oryza sativa","* Montezano DG, ... (2018) ...
* Valdez EM, Joshi RC, ... (2023) Rice: a new host of fall armyworm Spodoptera frugiperda (J.E. Smith) and its strains in the Philippines. Insect Environment 26(2), 129-136."
```

## Fields

### API v2 `hosts` item

| Field | Type | Unit | Description |
|---|---|---|---|
| `eppocode` | string | | EPPO code of the host plant (`^[0-9A-Z]{5,6}$`) |
| `prefname` | string | | Preferred scientific name of the host |
| `class_id` | integer | | Host classification id; labels from `/references/pestHostClassification` |
| `class_label` | string | | "Major host", "Minor host", "Host", "Experimental", "Wild/Weed", ... |
| `bibref` | string | | Bibliographic references, one per line starting with `* ` |

### API v2 `DistributionItem`

| Field | Type | Unit | Description |
|---|---|---|---|
| `country_iso` | string | | ISO 3166-1 alpha-2 country code (`/references/countries`) |
| `state_id` | string or null | | State or subdivision code (`/references/countriesStates`) |
| `peststatus` | string | | Status code; labels from `/references/distributionStatus` (e.g. "Present, widespread", "Absent, pest eradicated") |
| `yr_situation` | string or null | year | Year of the reported situation |
| `yr_introd` | string or null | year | Year of introduction |
| `yr_erad` | string or null | year | Year of eradication |

### Website CSV export `hosts_csv`

| Field | Type | Unit | Description |
|---|---|---|---|
| `type` | string | | Host category ("Major host", "Host", "Experimental", ...) |
| `EPPOCode` | string | | Host plant EPPO code |
| `Pref_name` | string | | Host plant preferred name |
| `References` | string (multi-line) | | Supporting references, each prefixed `* `; EPPO Secretariat comments appear as lines prefixed with dashes |

### EPPO code structure (from the EPPO Codes page)

| Taxon type | Code length | Construction |
|---|---|---|
| Pests and pathogens | 6 letters | 4 (genus) + 2 (species), e.g. `LAPHFR` |
| Cultivated and wild plants | 5 letters | 3 (genus) + 2 (species), e.g. `ZEAMX` |
| Viruses and virus-like organisms | 6 letters | acronym when possible |
| Higher taxa | | family codes start with `1` and end with `F`, e.g. `1GNORG` for a genus |

The code stays the same when the scientific name changes (example on the page: `GNORAB` kept across Gnorimoschema absoluta, Tuta absoluta and Phthorimaea absoluta).

## Licence

- **EPPO Codes: open licence.** The EPPO Codes page states "EPPO codes can be freely downloaded and incorporated into other IT systems" and that they "are freely available under the terms of an open data licence" (re-read 2026-11-15). The licence PDF itself (`https://data.eppo.int/data/Open_Licence.pdf`, dated 2014) was not re-read; from the inventory: it grants "a worldwide, perpetual, free of charge, non-exclusive, personal right to use the EPPO Codes" including "To exploit the EPPO Codes freely or commercially ... by including them in your own product or application", conditioned on attribution with the download date, no implied endorsement and no use of the EPPO logo; it defines "Derivative information" as EPPO Codes combined with "other data or information not subject to this licence". Inventory verdict: PASS for the codes.
- **GD hosts, distribution, categorization, Reporting Service: no grant found.** The licence names only the EPPO Codes. Every GD page footer reads "EPPO 2026 All Rights Reserved" (re-read 2026-11-15), and no terms page on `gd.eppo.int` was found that licenses this content. The host and distribution CSV exports download without a login, which says nothing about reuse rights. Inventory verdict: STILL UNKNOWN, to be treated as not cleared for commercial redistribution without written permission from EPPO.
- **Photos:** "for educational purposes only" per the GD user guide (from the inventory, not re-read).
- **Code creation:** requesting new EPPO codes "is still subject to fees" (EPPO Codes page).

## Overlap with NASA sources

- NASA publishes no pest or host taxonomy, no pest codes, no host lists and no pest distribution or quarantine status. None of the content in this file has a NASA counterpart.
- The weather inputs that pest rules combine with a host or distribution list (temperature, relative humidity, dew point, precipitation, wind) come from NASA POWER hourly and daily (`nasa_power.md`, `pest_weather_rules.md`); EPPO adds the identifiers (codes) and the pest-to-host and pest-to-country relations.
- Country and state names in GD distribution rows map to the FCC Census Block and administrative lookups already documented (`fcc_census_block.md`) only through the ISO country and state codes, not through coordinates: EPPO has no point data.

## Notes

- The REST v2 paths listed in the inventory from the third-party R package eppoFindeR (`/taxons/taxon/{CODE}/hosts`, `/distribution`, `/categorization`) are confirmed by EPPO's own OpenAPI spec fetched today; the inventory marked them "not confirmed in EPPO docs".
- The spec marks `/status` with `#security: []` (commented out), yet the live endpoint returned HTTP 401 without a key.
- The inventory quotes the GD home page as "more than 99 700 species"; the EPPO Codes page re-read today says "more than 98 500 species (as of June 2025)". Both are EPPO figures from different dates.
- Legacy Data Service REST 1.0 (`data.eppo.int/api/rest/1.0/`) still responds (HTTP 403 without a token) on 2026-11-15 although the migration page's commented-out end-of-life date (2026-09-01) has passed.
- `hosts_csv` is CSV content with an XLSX content type; `References` cells contain newlines and must be parsed with a quote-aware CSV reader.
- The two GD HTML list pages are large (hosts 218 KB, distribution 139 KB for LAPHFR) and are rendered server-side, so the text is present without JavaScript despite the "JavaScript is required" banner.
- The third-party host of the EPPO server list in the spec includes `https://api2025.eppo.dev:6443/gd/v2`, a staging host; use `api.eppo.int`.

## Documentation

- EPPO Data Portal: https://data.eppo.int/
- API cards: https://data.eppo.int/apis/ (Global Database API: https://data.eppo.int/apis/GDAPI ; legacy v1: https://data.eppo.int/apis/GDAPIV1)
- OpenAPI specs: https://api.eppo.int/gd/v2/eppo_api_gd_v2.yml ; https://api.eppo.int/gd/v1/eppo_api_gd_v1.yml
- Migration notice: https://data.eppo.int/legacy
- Open Data Licence (PDF): https://data.eppo.int/data/Open_Licence.pdf
- EPPO Codes: https://www.eppo.int/RESOURCES/eppo_databases/eppo_codes
- EPPO Global Database: https://gd.eppo.int/ ; user guide (2019): https://gd.eppo.int/media/files/general_user-guide_2019_09.pdf
- Fall armyworm in GD: https://gd.eppo.int/taxon/LAPHFR
