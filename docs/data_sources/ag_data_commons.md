# USDA Ag Data Commons

Ag Data Commons is the USDA National Agricultural Library (NAL) catalog and repository for agricultural research data. It runs on Figshare: dataset landing pages are served at `agdatacommons.nal.usda.gov/articles/dataset/...` and the same records are returned by the public Figshare API (`api.figshare.com/v2`) with `url_public_html` pointing to the Ag Data Commons host. Records are dataset metadata (title, description, authors, tags, categories, licence, DOI or handle, temporal and geographic extent in custom fields) plus either hosted files or link-only files pointing to external repositories (Zenodo, ArcGIS Hub, etc.). Content is added continuously; there is no fixed cadence.

| | |
|---|---|
| Provider | USDA National Agricultural Library (platform: Figshare) |
| Base URL | Web: `https://agdatacommons.nal.usda.gov/`; API: `https://api.figshare.com/v2/` |
| Auth | none for public search and article reads |
| Formats | JSON (API); dataset files in their original formats |
| Coverage | USDA-funded and agricultural research datasets, worldwide topics |
| Resolution | per dataset record |
| Cadence / latency | continuous publication; not published |
| Rate limits / quotas | not published in sources fetched |
| Documentation | https://docs.figshare.com/ |

## Requests

### Search articles (Figshare API, Ag Data Commons group)

Returns a list of public articles matching the text, filtered to a Figshare group.

| Parameter (JSON body) | Required | Description | Example |
|---|---|---|---|
| `search_for` | no | Free-text query | `crop rotation` |
| `group` | no | Figshare group id; Ag Data Commons records captured here have `group_id` 51645 | `51645` |
| `page_size` | no | Results per page | `5` |
| `page` | no | Page number | `1` |

Other body parameters (item type, ordering, dates) are listed in the Figshare API documentation; they were not exercised here.

```
POST https://api.figshare.com/v2/articles/search
Content-Type: application/json

{"search_for": "crop rotation", "group": 51645, "page_size": 5}
```

### Sample response (Captured 2026-11-14)

First of 5 elements shown in full; the other 4 reduced to id, title, published date and DOI.

```json
[
 {
  "project_id": null,
  "id": 31100317,
  "title": "Cover and cash crop diversification outcomes for soil health and soil microbial communities",
  "doi": "10.5281/zenodo.17860160",
  "handle": "",
  "url": "https://api.figshare.com/v2/articles/31100317",
  "published_date": "2026-02-13T17:22:01Z",
  "thumb": "",
  "defined_type": 3,
  "defined_type_name": "dataset",
  "group_id": 51645,
  "url_private_api": "https://api.figshare.com/v2/account/articles/31100317",
  "url_public_api": "https://api.figshare.com/v2/articles/31100317",
  "url_private_html": "https://figshare.com/account/articles/31100317",
  "url_public_html": "https://agdatacommons.nal.usda.gov/articles/dataset/Cover_and_cash_crop_diversification_outcomes_for_soil_health_and_soil_microbial_communities/31100317",
  "timeline": {"posted": "2026-02-13T17:22:01", "firstOnline": "2026-02-13"},
  "resource_title": "Wooliver, R., Kivlin, S.N. & Jagadamma, S. (2025). Microbial communities and their association with soil health indicators under row cash crop and cover crop diversification: a case study. Front. Microbiol. 16. https://doi.org/10.3389/fmicb.2025.1664417",
  "resource_doi": "10.3389/fmicb.2025.1664417",
  "created_date": "2026-02-13T17:22:01Z",
  "modified_date": "2026-08-25T19:19:33Z"
 },
 {"id": 31100455, "title": "Data from: Response of soil organic carbon fractions to cover cropping: A meta-analysis of agroecosystems", "published_date": "2026-02-13T17:03:59Z", "doi": "10.5281/zenodo.17859917"},
 {"id": 29464793, "title": "Data from: Improving semi-arid agroecosystem services with cover crop mixes", "published_date": "2025-08-22T16:12:08Z", "doi": "10.15786/3D2R-EW09"},
 {"id": 28410539, "title": "Data from: Seasonal vapor pressure deficit and temperature effects on carbon dioxide and water dynamics in a prevalent crop rotation in the northern Great Plains", "published_date": "2025-05-16T19:18:02Z", "doi": "10.5281/zenodo.14646348"},
 {"id": 24856926, "title": "PhenoCam images from ARSLTARMDCR site, Caroline County, Maryland, USA since 2017", "published_date": "2024-02-20T19:32:11Z", "doi": ""}
]
```

### Article detail

Returns the full public record including description, authors, files, licence, tags, categories and Ag Data Commons custom fields.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{article_id}` (path) | yes | Article `id` | `31100317` |

```
GET https://api.figshare.com/v2/articles/31100317
```

### Sample response (Captured 2026-11-14)

Trimmed: `description` cut after the first sentence; `authors` reduced to the first entry; `custom_fields` reduced to name/value pairs, `Data contact email` value removed, `Geographic Coverage` GeoJSON cut; fields equal to those in the search result (urls, timeline, dates) removed; `folder_structure`, `funding`, `funding_list`, `references`, `related_materials`, embargo fields removed.

```json
{
 "id": 31100317,
 "title": "Cover and cash crop diversification outcomes for soil health and soil microbial communities",
 "doi": "10.5281/zenodo.17860160",
 "description": "<p dir=\"ltr\">Microbial community abundance and taxonomy data and soil property data associated with a four-year, two-way crop diversification field experiment in western Tennessee, USA. ...",
 "authors": [{"id": 22795475, "full_name": "RACHEL WOOLIVER", "is_active": true, "orcid_id": "0000-0002-7723-437X"}, "..."],
 "files": [{"id": "...", "name": "zenodo.17860160", "size": 0, "is_link_only": true, "download_url": "https://doi.org/10.5281/zenodo.17860160", "mimetype": "undefined"}],
 "license": {"value": 2, "name": "CC0", "url": "https://creativecommons.org/publicdomain/zero/1.0/"},
 "tags": ["Crop Diversification", "Soil organic carbon", "Soil microbial community", "Cover crop", "Crop rotation", "Soil health"],
 "categories": [{"id": 33725, "title": "Soil sciences", "parent_id": 33614, "path": "/33614/33725", "source_id": "4106", "taxonomy_id": 102}, {"id": 30602, "title": "Agriculture, land and farm management", "...": "..."}],
 "custom_fields": [
  {"name": "Data contact name", "value": "Wooliver, Rachel"},
  {"name": "Publisher", "value": "Zenodo"},
  {"name": "Temporal Extent Start Date", "value": "2020-09-01"},
  {"name": "Temporal Extent End Date", "value": "2024-10-01"},
  {"name": "Geographic Coverage", "value": "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"geometry\":{\"type\":\"Point\",\"coordinates\":[-88.860111,35.633167 ..."},
  {"name": "Geographic location - description", "value": "University of Tennessee’s AgResearch and Education Center in Jackson, TN, USA (35° 37′59.4″ N, 88° 51′36.4″ W)"},
  {"name": "ISO Topic Category", "value": "['biota', 'environment', 'farming']"},
  {"name": "National Agricultural Library Thesaurus terms", "value": "cash crops; soil quality; microbial communities; taxonomy; soil properties; field experimentation; ecosystems; soil bact..."},
  {"name": "OMB Bureau Code", "value": "['005:20 - National Institute of Food and Agriculture']"},
  {"name": "Primary article PubAg Handle", "value": "['https://hdl.handle.net/10113/9486753', 'https://hdl.handle.net/10113/9400306']"},
  {"name": "Public Access Level", "value": "['Public']"}
 ],
 "size": 0,
 "version": 1,
 "group_id": 51645,
 "defined_type_name": "dataset",
 "citation": "WOOLIVER, RACHEL; Kivlin, Stephanie N.; Duncan, Lori; McNeal, Jake; Raper, Tyson; Denton, Andrew; et al. (2026). Cover and cash crop diversification outcomes for soil health and soil microbial communities. Zenodo. Dataset. https://doi.org/10.5281/zenodo.17860160"
}
```

A second record (`GET https://api.figshare.com/v2/articles/25234117`, "GRACEnet Soil Biology Network", Captured 2026-11-14) has `handle`-based citation `https://hdl.handle.net/10113/AA6236`, licence CC0, `group_id` 51645, tags including "Soil Biology" and "Agricultural Research Service", and one link-only file pointing to `https://agcros-usdaars.opendata.arcgis.com/datasets?group_ids=091b86e9e44a4e948ef2aeae3c916ca5`.

## Fields

### Search result / article

| Field | Type | Unit | Description |
|---|---|---|---|
| `id` | integer | | Figshare article id |
| `title` | string | | Dataset title |
| `doi` | string | | DOI (may be empty; may be an external DOI such as Zenodo) |
| `handle` | string | | Handle (may be empty) |
| `published_date`, `created_date`, `modified_date` | string | ISO 8601 UTC | Dates |
| `timeline` | object | date | `posted`, `firstOnline`, `publisherPublication` |
| `defined_type` / `defined_type_name` | integer / string | | Item type (3 / "dataset") |
| `group_id` | integer | | Figshare group (51645 for the records captured) |
| `url_public_api`, `url_public_html` | string | | API URL and Ag Data Commons landing page |
| `resource_title`, `resource_doi` | string | | Related publication |
| `description` | string (HTML) | | Abstract |
| `authors[]` | object[] | | `id`, `full_name`, `orcid_id`, ... |
| `files[]` | object[] | bytes | `name`, `size`, `download_url`, `mimetype`, `is_link_only`, `supplied_md5`, `computed_md5` |
| `license` | object | | `value`, `name`, `url` |
| `tags`, `keywords` | string[] | | Free keywords |
| `categories[]` | object[] | | Figshare taxonomy categories |
| `custom_fields[]` | object[] | | Ag Data Commons metadata: Data contact name/email, Publisher, Intended use, Use limitations, Temporal Extent Start/End Date, Frequency, Theme, Geographic Coverage (GeoJSON string), Geographic location - description, ISO Topic Category, Ag Data Commons Group, National Agricultural Library Thesaurus terms, OMB Bureau Code, OMB Program Code, ARS National Program Number, ARIS Log Number, Primary article PubAg Handle, Pending citation, Related material without URL, Public Access Level, Preferred dataset citation |
| `citation` | string | | Formatted citation |
| `size` | integer | bytes | Total size of hosted files (0 for link-only records) |

Several custom field values are Python-style list strings (e.g. `"['Public']"`), not JSON arrays.

## Notes

- `https://agdatacommons.nal.usda.gov/` returned HTTP 202 with an empty body on two attempts on 2026-11-14 (scripted client); the landing page content was not read. The Figshare API worked.
- Ag Data Commons runs on Figshare: records returned by `api.figshare.com` carry `url_public_html` on `agdatacommons.nal.usda.gov` and `figshare_url` equal to that landing page.
- `GET https://api.figshare.com/v2/institutions` returned HTTP 404; the Ag Data Commons institution id was not determined. Filtering by `"group": 51645` returned only Ag Data Commons records in this capture; whether every Ag Data Commons record belongs to that group was not verified.
- A search without `group` (`{"search_for":"crop rotation agdatacommons ..."}`) returned `[]`; a plain `"crop rotation"` search returned records from many Figshare portals (T&F, PLOS, Frontiers).
- Many records are link-only (`is_link_only: true`, `size: 0`); the data live in the external repository named in `download_url`.
- Licences are per record (CC0 on both records captured).

## Documentation

- Ag Data Commons: https://agdatacommons.nal.usda.gov/
- Figshare API documentation: https://docs.figshare.com/
- Figshare API search endpoint reference: https://docs.figshare.com/#articles_search
