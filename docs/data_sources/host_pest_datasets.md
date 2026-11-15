# Host-pest datasets (NHM HOSTS, USDA Fungus-Host, GloBI)

Three open resources that answer "which pests and pathogens are recorded on this crop". HOSTS is the Natural History Museum's archival table of the world's Lepidoptera caterpillar host plants (140,485 rows in the public datastore, CC0), queryable record by record through the museum's CKAN datastore API. The USDA Fungus-Host Distributions database (U.S. National Fungus Collections, public domain) records fungus, host and locality combinations from the literature; it is served by a USDA web application whose backend API is not publicly documented, and its Ag Data Commons record is a link-only catalogue entry. GloBI (Global Biotic Interactions) aggregates species interaction datasets (eats, parasiteOf, pathogenOf, hasHost, ...) from many sources with the originating citation on every record, through a keyless REST API and multi-gigabyte bulk files. None of them carries a time series: they are reference tables keyed by scientific names.

| | |
|---|---|
| Provider | Natural History Museum, London (HOSTS); USDA ARS, U.S. National Fungus Collections (Fungus-Host); Global Biotic Interactions project (GloBI) |
| Base URL | `https://data.nhm.ac.uk/api/3/action/` ; `https://fungi.ars.usda.gov/` ; `https://api.globalbioticinteractions.org/` |
| Auth | none for all three (the USDA app's backend calls carry an `x-api-key` header set by the front end; that API is not documented for external use) |
| Formats | JSON (CKAN API, GloBI), CSV (HOSTS download), TSV/CSV/JSON/dot (GloBI), HTML (USDA app) |
| Coverage | global; HOSTS is Lepidoptera only, Fungus-Host is fungi and oomycetes, GloBI is any taxon |
| Resolution | one row per pest x host (x country or locality for HOSTS and Fungus-Host); GloBI rows may carry coordinates and dates from the source study |
| Cadence / latency | HOSTS: frozen (update frequency "never", last modified 2023-03-28); Fungus-Host: curated continuously by USDA (no schedule published); GloBI: continuous indexing, bulk products versioned (latest Zenodo version 0.3, 2021-11-17) |
| Rate limits / quotas | not published; GloBI pages results (default and maximum 1,024 rows per request) |
| Licence | HOSTS: CC0 (Creative Commons CCZero on the record). Fungus-Host: U.S. Public Domain (Ag Data Commons record). GloBI: CC BY 4.0 by default, "unless otherwise noted", each record keeps its source's licence. See Licence |
| Documentation | https://data.nhm.ac.uk/dataset/hosts ; https://fungi.ars.usda.gov/ ; https://github.com/globalbioticinteractions/globalbioticinteractions/wiki/API |

| Dataset | Access | Size | Licence (as read today) |
|---|---|---|---|
| NHM HOSTS, resource `877f387a-36a3-486c-a0c1-b8d5fb69f85a` | CKAN `datastore_search` or CSV download | 140,485 records, CSV 14,884,296 bytes | `license_id: cc-zero`, DOI 10.5519/havt50xw |
| USDA Fungus-Host (U.S. National Fungus Collections) | web application; Ag Data Commons record 24660510 is link-only | not published | U.S. Public Domain (Ag Data Commons) |
| GloBI interactions | REST API; bulk on Zenodo 10.5281/zenodo.5708970 | `interactions.tsv.gz` 1,340,390,543 bytes | README: CC BY 4.0 unless otherwise noted; Zenodo bulk record: `cc-zero` |

## Requests

### HOSTS dataset metadata (CKAN `package_show`)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `id` | yes | Dataset name or UUID | `hosts` |

```
GET https://data.nhm.ac.uk/api/3/action/package_show?id=hosts
```

### Sample response (Captured 2026-11-15)

5,455 bytes. Trimmed to the licence, identifier and resource fields; `notes` (the long description) shortened to its first sentence.

```json
{"success": true, "result": {
  "id": "11623cfb-ae19-41df-8d4e-fa7a1665ac29", "name": "hosts",
  "title": "HOSTS - a Database of the World's Lepidopteran Hostplants",
  "author": "Gaden S. Robinson; Phillip R. Ackery; Ian Kitching; George W Beccaloni; Luis M. Hernández",
  "license_id": "cc-zero", "license_title": "Creative Commons CCZero", "license_url": "http://www.opendefinition.org/licenses/cc-zero",
  "doi": "10.5519/havt50xw", "update_frequency": "never", "dataset_category": ["Research"],
  "metadata_created": "2023-03-23T16:26:37.988921", "metadata_modified": "2023-03-28T11:36:08.724442",
  "notes": "__Please note: HOSTS will not be further updated or amended. This dataset is an archival resource ...__",
  "resources": [
    {"id": "877f387a-36a3-486c-a0c1-b8d5fb69f85a", "name": "HOSTS", "format": "CSV", "size": 14884296, "datastore_active": true,
     "url": "https://data.nhm.ac.uk/dataset/11623cfb-ae19-41df-8d4e-fa7a1665ac29/resource/877f387a-36a3-486c-a0c1-b8d5fb69f85a/download/hosts-data.csv"},
    {"id": "86341d1d-beeb-4a46-8f69-d974e0afa3dd", "name": "Supplementary Materials", "format": "PDF", "size": 249309, "datastore_active": false,
     "url": "https://data.nhm.ac.uk/dataset/11623cfb-ae19-41df-8d4e-fa7a1665ac29/resource/86341d1d-beeb-4a46-8f69-d974e0afa3dd/download/supplementary-materials.pdf"}
  ]
}}
```

The description says the web version is "drawn from about 180,000 records comprising taxonomically 'cleaned' hostplant data for about 22,000 Lepidoptera species drawn from about 1600 published and manuscript sources"; the datastore holds 140,485 rows (next request).

### HOSTS records (CKAN `datastore_search`)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `resource_id` | yes | HOSTS CSV resource id | `877f387a-36a3-486c-a0c1-b8d5fb69f85a` |
| `q` | no | Full-text query over all columns | `Zea mays` |
| `filters` | no | JSON object of exact column matches | `{"Hostplant Genus":"Zea","Hostplant Species":"mays"}` |
| `limit` | no | Rows per page (0 returns only `total` and `fields`) | `3` |
| `offset` | no | Paging offset | `0` |
| `sort` | no | `"<field> asc|desc"` | `"Insect Family asc"` |

```
GET https://data.nhm.ac.uk/api/3/action/datastore_search?resource_id=877f387a-36a3-486c-a0c1-b8d5fb69f85a&q=Zea%20mays&limit=3
GET https://data.nhm.ac.uk/api/3/action/datastore_search?resource_id=877f387a-36a3-486c-a0c1-b8d5fb69f85a&filters=%7B%22Hostplant%20Genus%22%3A%22Zea%22%2C%22Hostplant%20Species%22%3A%22mays%22%7D&limit=2
GET https://data.nhm.ac.uk/api/3/action/datastore_search?resource_id=877f387a-36a3-486c-a0c1-b8d5fb69f85a&limit=0
```

### Sample response (Captured 2026-11-15)

First request, 2,163 bytes, untrimmed except `help` and the `after` paging cursor. Both the `q` and the `filters` forms returned `total: 709` for maize; the `limit=0` request returned `total: 140485` with the same `fields` array.

```json
{"success": true, "result": {"total": 709, "records": [
  {"_id": "99997", "HOSTS ID": "99997", "Insect Family": "Pyralidae", "Insect Genus": "Achyra", "Insect Species": "massalis", "Insect Subspecies": "", "Insect Author": "Walker",
   "Hostplant Family": "Gramineae", "Hostplant Genus": "Zea", "Hostplant Species": "mays", "Hostplant Subspecies/var": "", "Location": "India", "Damage": "on leaves", "Lab Rearing": ""},
  {"_id": "99991", "HOSTS ID": "99991", "Insect Family": "Pyralidae", "Insect Genus": "Achyra", "Insect Species": "coelatalis", "Insect Subspecies": "", "Insect Author": "Walker",
   "Hostplant Family": "Gramineae", "Hostplant Genus": "Zea", "Hostplant Species": "mays", "Hostplant Subspecies/var": "", "Location": "Togo", "Damage": "in stems", "Lab Rearing": ""},
  {"_id": "99971", "HOSTS ID": "99971", "Insect Family": "Pyralidae", "Insect Genus": "Achyra", "Insect Species": "affinitalis", "Insect Subspecies": "", "Insect Author": "Lederer",
   "Hostplant Family": "Gramineae", "Hostplant Genus": "Zea", "Hostplant Species": "mays", "Hostplant Subspecies/var": "", "Location": "Australia", "Damage": "", "Lab Rearing": ""}
 ],
 "fields": [{"id": "_id", "type": "string"}, {"id": "HOSTS ID", "type": "number", "sortable": true}, {"id": "Insect Family", "type": "string", "sortable": true}, "... one entry per column, see Fields ...", {"id": "Lab Rearing", "type": "boolean", "sortable": true}]
}}
```

### USDA Fungus-Host: Ag Data Commons record (Figshare API)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{article_id}` (path) | yes | Ag Data Commons article id | `24660510` |

```
GET https://api.figshare.com/v2/articles/24660510
```

### Sample response (Captured 2026-11-15)

17,305 bytes. Trimmed to licence, identifiers, the first sentences of the description, the use fields and the single (link-only) file.

```json
{"id": 24660510, "title": "U.S. National Fungus Collections", "doi": "10.15482/USDA.ADC/1326639", "defined_type_name": "dataset",
 "license": {"value": 96, "name": "U.S. Public Domain", "url": "https://www.usa.gov/publicdomain/label/1.0/"},
 "published_date": "2024-02-08T20:36:47Z", "modified_date": "2025-11-22T00:16:33Z",
 "url_public_html": "https://agdatacommons.nal.usda.gov/articles/dataset/U_S_National_Fungus_Collections/24660510",
 "description": "The U.S. National Fungus Collections (BPI) are the \"Smithsonian for fungi\" and are the repository for over one million fungal specimens worldwide ... Data from the labels of more than 750,000 of the specimens have been entered into a database. These labels have information on the host on which the fungus was found and the locality in which the specimen was collected. Sixty percent of these specimens are from the United States ... Resources in this dataset: Resource Title: Fungal databases - Specimens. File Name: Web Page, url: https://nt.ars-grin.gov/fungaldatabases/specimens/specimens.cfm ...",
 "custom_fields": [{"name": "Publisher", "value": "U.S. Department of Agriculture, Agricultural Research Service"},
   {"name": "Intended use", "value": "Access is available to professional mycologists associated with a recognized herbarium."},
   {"name": "Temporal Extent Start Date", "value": "1800-01-01"}, {"name": "ISO Topic Category", "value": "[\"biota\"]"}],
 "files": [{"id": 44335271, "name": "specimens.cfm", "size": 0, "is_link_only": true, "download_url": "https://nt.ars-grin.gov/fungaldatabases/specimens/specimens.cfm"}]}
```

The "Intended use" and "Use limitations" fields describe access to the physical specimen collection, not to the database. Searches of the Ag Data Commons group (`POST https://api.figshare.com/v2/articles/search` with `{"search_for":"Fungus-Host","group":51645}` and `{"search_for":"Fungal Databases","group":51645}`) returned this record, "National Microbial Germplasm Program" (24661746) and "ARS Collection of Entomopathogenic Fungal Cultures" (24660507); no separate "Fungus-Host Distributions" record was found.

### USDA Fungus-Host: live application

```
GET https://fungi.ars.usda.gov/
```

### Sample response (Captured 2026-11-15)

HTTP 200, 54,478 bytes, `text/html`, Last-Modified 2026-01-30; an Angular single-page application ("USDA fungal databases") whose text is loaded by JavaScript. Its main bundle (`main-NDIYHXAG.js`, 1,760,843 bytes) contains the site description and the backend configuration, extracted here:

```
"The US National Fungus Collections is a mycological institution that includes the Western Hemisphere's largest fungal
herbarium (Herbarium BPI), the John A. Stevenson Mycological Library, the USDA Fungus-Host Databases, and the only
actively curated nomenclature database focused on plant pathogenic fungi. ... The world-renowned fungus-host-location
database, literature database, and the nomenclature database for agriculturally important fungi are searchable on this site."

endpoint: "https://fungi-api.ars.usda.gov/"   path prefix "api/results"   header "x-api-key"
paths seen: fh-search-all-names, fh-auto-comp?fungus=&host=&countryName=, fh-get-fungus-names/, fh-get-host-names/,
            fh-get-localities/, fh-get-countries, fh-get-citations?, hp-get-db-stats, data-download, nomen-search?,
            nom-get-genus-list?, nom-get-species-list?, lit-search?Author=, host-family, fungus-group, fungus-order
UI strings: "Total fungus-host records: ", "Unique fungus-host comb.: ", "Unique fungus-host-locales: ", "Select page of fungus-host Records"
```

The backend API is not publicly documented and was not called in this pass. The legacy host `nt.ars-grin.gov` named in the Ag Data Commons record did not resolve in DNS on 2026-11-15.

### GloBI interactions

| Parameter | Required | Description | Example |
|---|---|---|---|
| `sourceTaxon` | no (one of source or target in practice) | Subject taxon name or id; repeatable; child taxa included unless `excludeChildTaxa=true` | `Spodoptera frugiperda` |
| `targetTaxon` | no | Object taxon (the crop when asking what eats it) | `Zea mays` |
| `interactionType` | no | One of `/interactionTypes` (`eats`, `eatenBy`, `preysOn`, `parasiteOf`, `hasParasite`, `pathogenOf`, `hasPathogen`, `hasHost`, `hostOf`, `pollinates`, `visitsFlowersOf`, `interactsWith`, ...) | `eats` |
| `bbox` | no | `west,south,east,north` | `-104.1,40.0,-95.3,43.0` |
| `lat`, `lng` | no | Point of interest | `40.95`, `-97.50` |
| `accordingTo` | no | Restrict to a source or study (substring, or exact study URL) | `inaturalist` |
| `fields` | no | Comma-separated return fields from `/interactionFields` (or repeated `field=`) | `source_taxon_name,interaction_type,target_taxon_name,study_citation,study_source_citation` |
| `includeObservations` | no | `true` to return one row per record with study fields instead of distinct pairs | `true` |
| `type` | no | `json` (compact columns + data, default), `json.v2` (one object per row), `csv`, `tsv`, `dot` | `json.v2` |
| `limit`, `offset` | no | Paging; default and maximum 1,024 | `5`, `0` |
| `taxonIdPrefix` | no | Prefer one taxonomy for ids (`/prefixes`, e.g. `OTT`, `GBIF`, `NCBI`) | `GBIF` |

```
GET https://api.globalbioticinteractions.org/interaction?targetTaxon=Zea%20mays&interactionType=eats&limit=5&fields=source_taxon_name,interaction_type,target_taxon_name,study_citation,study_source_citation&includeObservations=true&type=json.v2
GET https://api.globalbioticinteractions.org/taxon/Zea%20mays/eatenBy
GET https://api.globalbioticinteractions.org/interactionTypes
GET https://api.globalbioticinteractions.org/interactionFields
```

### Sample response (Captured 2026-11-15)

First request: HTTP 200, 2,772 bytes, served as `text/html;charset=utf-8` although the body is JSON. 5 rows returned; trimmed to 3 and the long trophiCH citation shortened. Note the first row's `interaction_type` is `preysOn` although `eats` was requested: GloBI resolves the requested type to its more specific sub-types.

```json
[{"source_taxon_name": "Clarias ngamensis", "interaction_type": "preysOn", "target_taxon_name": "Zea mays",
  "study_citation": "Globi",
  "study_source_citation": "Carvajal-Quintero, J.D. et al. 2026. Degradation of fish food webs in the Anthropocene. Science Advances. https://doi.org/10.1126/sciadv.adu6540",
  "source": {"name": "Clarias ngamensis"}, "type": "preysOn", "target": {"name": "Zea mays"}},
 {"source_taxon_name": "Protaetia orientalis", "interaction_type": "eats", "target_taxon_name": "Zea mays",
  "study_citation": "https://scan-bugs.org:443/portal/collections/individual/index.php?occid=23683829",
  "study_source_citation": "Symbiota Collections of Arthropods Network (SCAN)",
  "source": {"name": "Protaetia orientalis"}, "type": "eats", "target": {"name": "Zea mays"}},
 {"source_taxon_name": "Gryllodes sigillatus", "interaction_type": "eats", "target_taxon_name": "Zea mays",
  "study_citation": "Poelen, J. H. Global Biotic Interactions: Interpreted Data Products. Zenodo https://doi.org/10.5281/zenodo.5708970 (2021).",
  "study_source_citation": "Reji Chacko, M., ... Pellissier, L. (2024). trophiCH v1 - a food web for Switzerland. EnviDat. https://www.doi.org/10.16904/envidat.467.",
  "source": {"name": "Gryllodes sigillatus"}, "type": "eats", "target": {"name": "Zea mays"}}]
```

`/interactionTypes` (5,312 bytes) maps each type to its source and target roles and OBO Relation Ontology IRI, for example `"eats": {"source": "consumer", "target": "food", "termIRI": "http://purl.obolibrary.org/obo/RO_0002470"}`. `/interactionFields` (17,429 bytes) describes every selectable column (`latitude`, `longitude`, `event_date`, `locality`, `source_taxon_name`, `source_taxon_path`, `interaction_type`, `interaction_type_id`, `target_taxon_name`, `study_citation`, `study_source_citation`, `study_url`, ...), mostly as Darwin Core equivalents.

### GloBI bulk products (Zenodo)

```
GET https://zenodo.org/api/records/5708970
```

### Sample response (Captured 2026-11-15)

17,103 bytes. Trimmed to identifiers, licence and the main files.

```json
{"doi": "10.5281/zenodo.5708970", "conceptdoi": "10.5281/zenodo.3950589",
 "metadata": {"title": "Global Biotic Interactions: Interpreted Data Products", "publication_date": "2021-11-17", "version": "0.3", "license": {"id": "cc-zero"}},
 "files": [{"key": "interactions.tsv.gz", "size": 1340390543}, {"key": "interactions.csv.gz", "size": 1341828540}, {"key": "citations.tsv.gz", "size": 34873776},
           {"key": "taxonCache.tsv.gz", "size": 109607454}, {"key": "taxonMap.tsv.gz", "size": 57818516}, {"key": "refuted-interactions.tsv.gz", "size": 2147233},
           {"key": "dwca.zip", "size": 345754352}, {"key": "dwca-by-study.zip", "size": 220426473}, {"key": "neo4j-graphdb.zip", "size": 4293882223}, {"key": "interactions.nq.gz", "size": 3904405190}]}
```

## Fields

### HOSTS record

| Field | Type | Unit | Description |
|---|---|---|---|
| `HOSTS ID` | number | | Record id (also `_id`) |
| `Insect Family`, `Insect Genus`, `Insect Species`, `Insect Subspecies`, `Insect Author` | string | | Lepidoptera taxon and authority |
| `Hostplant Family`, `Hostplant Genus`, `Hostplant Species`, `Hostplant Subspecies/var` | string | | Host plant taxon (family names as in the sources, e.g. `Gramineae`) |
| `Location` | string | | Country or region of the record |
| `Damage` | string | | Feeding site or damage note (e.g. `on leaves`, `in stems`), often empty |
| `Lab Rearing` | boolean | | Whether the record is a laboratory rearing (datastore type boolean; values arrive as `""` or `true`) |

### GloBI interaction row (`json.v2`)

| Field | Type | Unit | Description |
|---|---|---|---|
| `source_taxon_name` | string | | Subject of the interaction (the pest when `interactionType=eats` and the crop is the target) |
| `interaction_type` | string | | Verb; `interaction_type_id` gives the RO IRI |
| `target_taxon_name` | string | | Object of the interaction |
| `study_citation` | string | | Citation or URL of the specific claim or record |
| `study_source_citation` | string | | Citation of the dataset that contributed the record; the licence of the row follows this source |
| `latitude`, `longitude`, `event_date`, `locality` | number, number, string, string | degrees, ISO date | Present only when the source study records them |
| `source`, `target` | object | | `{ "name": ... }` repeats of the names in `json.v2` |

### USDA Fungus-Host

The record structure (fungus name, host name, locality or country, literature citation) is described in the site text and reflected in the backend path names (`fh-get-fungus-names`, `fh-get-host-names`, `fh-get-localities`, `fh-get-countries`, `fh-get-citations`); no field dictionary is published.

## Licence

- **NHM HOSTS: CC0.** `license_id: cc-zero`, `license_title: Creative Commons CCZero`, `license_url: http://www.opendefinition.org/licenses/cc-zero` on the record (re-read 2026-11-15). Matches the inventory (PASS).
- **USDA Fungus-Host: U.S. Public Domain.** `license.name: U.S. Public Domain` on Ag Data Commons record 24660510 (re-read 2026-11-15). The record is a catalogue entry pointing to a dead legacy URL; the live application at `fungi.ars.usda.gov` publishes no separate terms page in the HTML fetched. Matches the inventory (PASS).
- **GloBI: per source.** README (re-read 2026-11-15): "Unless otherwise noted, source code is released under GLPv3 and data is available under Creative Commons Attribution 4.0 International License." Each row names its contributing dataset in `study_source_citation`; sources such as iNaturalist carry CC BY-NC records, so reuse has to be decided per source. The Zenodo bulk record 5708970 is labelled `cc-zero` in its metadata, which differs from the README's CC BY 4.0 default; the inventory's verdict (PASS only for allow-listed sources) stands.

## Overlap with NASA sources

- NASA publishes no host-pest or host-pathogen tables; none of these three datasets has a NASA counterpart.
- The weather side of a pest question (temperature, humidity, dew point, rain, wind at the field) is served by NASA POWER (`nasa_power.md`, `pest_weather_rules.md`); these datasets supply the organism side: which Lepidoptera (HOSTS), fungi and oomycetes (Fungus-Host) or any recorded interactor (GloBI) is associated with a given crop species.
- GloBI rows with `latitude`/`longitude` and `event_date` can be placed against the same POWER grid cell and dates as any other point record; HOSTS and Fungus-Host carry country or locality names only.

## Notes

- HOSTS is frozen: "HOSTS will not be further updated or amended" (record description). The museum's description says about 180,000 records; the datastore `total` is 140,485.
- CKAN `datastore_search` supports `q` (full text), `filters` (exact JSON matches), `sort`, `limit`, `offset` and a cursor in `result.after`; `limit=0` returns the schema and total only. Both query forms returned 709 rows for maize.
- The Ag Data Commons record for the National Fungus Collections points at `https://nt.ars-grin.gov/fungaldatabases/specimens/specimens.cfm`; that hostname returned a DNS resolution error on 2026-11-15. The current site is `https://fungi.ars.usda.gov/` (bundle dated 2026-01-30).
- The USDA application's backend (`https://fungi-api.ars.usda.gov/`, prefix `api/results`, `x-api-key` header) was identified from the front-end bundle only and was not called. The bundle also references a `data-download` path and the IPNI and MyCoPortal sites.
- GloBI returned JSON with a `text/html` content type; parse by body, not by header. `preysOn` rows appear in an `eats` query because GloBI expands the requested type to its sub-types.
- GloBI bulk files are large (`interactions.tsv.gz` 1.34 GB, `neo4j-graphdb.zip` 4.29 GB); `citations.tsv.gz` (34.9 MB) lists the contributing datasets and is the file to read for licences.
- The NHM Host-Parasite database (`https://data.nhm.ac.uk/dataset/host-parasite-database`, CC BY, more than a quarter of a million records per the inventory) covers animal helminth parasites and has low relevance for crops; it was not fetched.

## Documentation

- HOSTS dataset: https://data.nhm.ac.uk/dataset/hosts (DOI https://doi.org/10.5519/havt50xw)
- NHM data portal API help: https://data.nhm.ac.uk/api/3/action/help_show?name=datastore_search
- U.S. National Fungus Collections on Ag Data Commons: https://agdatacommons.nal.usda.gov/articles/dataset/U_S_National_Fungus_Collections/24660510 (DOI https://doi.org/10.15482/USDA.ADC/1326639)
- USDA fungal databases: https://fungi.ars.usda.gov/
- GloBI API wiki: https://github.com/globalbioticinteractions/globalbioticinteractions/wiki/API
- GloBI interaction types and fields: https://api.globalbioticinteractions.org/interactionTypes ; https://api.globalbioticinteractions.org/interactionFields
- GloBI interpreted data products: https://doi.org/10.5281/zenodo.5708970 (concept DOI https://doi.org/10.5281/zenodo.3950589)
- GloBI source repository and licence statement: https://github.com/globalbioticinteractions/globalbioticinteractions
