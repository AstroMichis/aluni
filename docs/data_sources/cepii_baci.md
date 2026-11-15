# CEPII BACI (bilateral trade at the HS6 product level)

BACI (Base pour l'Analyse du Commerce International) is CEPII's reconciled version of the UN Comtrade bilateral trade data: one annual value and quantity per exporter, importer and 6-digit Harmonized System product, for about 200 countries and 5,000 products. CEPII removes the duplicate reporting of each flow (an export reported by the seller and an import reported by the buyer), estimates and strips CIF costs from import values, and weights reporters by reliability, so that each flow appears once. The data are static CSV files inside one ZIP archive per HS revision (HS92 to HS22), with no API and no login; a new version is published every January. The current version is 202601 (released 22 January 2026) and the HS92 vintage covers 1995-2024.

| | |
|---|---|
| Provider | CEPII (Centre d'Etudes Prospectives et d'Informations Internationales, France) |
| Base URL | `https://www.cepii.fr/DATA_DOWNLOAD/baci/data/BACI_HS{rev}_V{version}.zip` (current); `https://www.cepii.fr/DATA_DOWNLOAD/baci/legacy/{version}/...` (archives) |
| Auth | none (direct ZIP download, no registration) |
| Formats | ZIP of CSV files (comma delimiter, dot decimal separator); release notes PDF |
| Coverage | about 200 countries (same coverage as Comtrade), about 5,000 HS6 products; HS92 1995-2024, HS96 1996-2024, HS02 2002-2024, HS07 2007-2024, HS12 2012-2024, HS17 2017-2024, HS22 2022-2024 |
| Resolution | exporter x importer x HS6 product x year; only strictly positive flows are recorded |
| Cadence / latency | annual, every January; the latest year is provisional and revised in later versions |
| Rate limits / quotas | none published; files are large (HS92 ZIP 2.4 GB) |
| Licence | Etalab Open Licence 2.0 ("any use is authorized, provided the source is mentioned") |
| Documentation | https://www.cepii.fr/DATA_DOWNLOAD/baci/doc/baci_webpage.html |

## Requests

### Documentation page

The page carries the description, the file naming convention, the download links for the current and legacy versions, the FAQ and the licence. It is a static Quarto HTML page.

```
GET https://www.cepii.fr/DATA_DOWNLOAD/baci/doc/baci_webpage.html
```

### Sample response (Captured 2026-11-15)

HTTP 200, 2,092,737 bytes, `last-modified: Thu, 22 Jan 2026 19:51:29 GMT`. Markup removed; trimmed to the variable table, the naming table and the FAQ answers quoted in this file.

```
BACI contains 6 variables:
  t   Year
  k   Product category (HS 6-digit code)
  i   Exporter (3-digit country code)
  j   Importer (3-digit country code)
  v   Value of the trade flow (in thousands current USD)
  q   Quantity (in metric tons)

HS revision  Years available  Name of the files
92           1995-2024        BACI_HS92_Y<year>_V<version>.csv
96           1996-2024        BACI_HS96_Y<year>_V<version>.csv
02           2002-2024        BACI_HS02_Y<year>_V<version>.csv
07           2007-2024        BACI_HS07_Y<year>_V<version>.csv
12           2012-2024        BACI_HS12_Y<year>_V<version>.csv
17           2017-2024        BACI_HS17_Y<year>_V<version>.csv
22           2022-2024        BACI_HS22_Y<year>_V<version>.csv

Last update: January 22, 2026. This is the 202601 version.
Each zip file corresponds to one revision of the Harmonized System, and contains annual trade
flows files, as well as metadata files for country codes and product codes.
The country codes in BACI are inherited from the UN Comtrade dataset, and may differ from
standard ISO 3-digit country codes.
To save space, only the strictly positive trade flows are recorded in BACI.
When is BACI updated? BACI is updated every year in January.
Is data for the last year definitive? ... not necessarily definitive and may be significantly
revised in future releases.
What are the conditions to use BACI? BACI is distributed under the Etalab Open Licence 2.0,
which means that any use is authorized, provided the source is mentionned.
Is there data for Taiwan? ... the category "Asia, not elsewhere specified" (country code 490)
serves as a reliable proxy.
```

### Current version archives

One ZIP per HS revision. The archive holds one trade-flow CSV per year, a country metadata file (code, name, ISO codes), a product metadata file (HS6 code, description) and a readme.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{rev}` (path) | yes | HS revision: `92`, `96`, `02`, `07`, `12`, `17`, `22` | `92` |
| `{version}` (path) | yes | Release id `YYYYMM` | `202601` |

```
GET https://www.cepii.fr/DATA_DOWNLOAD/baci/data/BACI_HS92_V202601.zip
GET https://www.cepii.fr/DATA_DOWNLOAD/baci/data/BACI_HS22_V202601.zip
GET https://www.cepii.fr/DATA_DOWNLOAD/baci/doc/release_notes_202601.pdf
```

Links present on the page on 2026-11-15: current `data/BACI_HS{02,07,12,17,22,92,96}_V202601.zip`; legacy `legacy/202501/`, `legacy/202401b/`, `legacy/202401/`, `legacy/202301/`, `legacy/202201/`, `legacy/202102/` (same naming), and older `legacy/202001/trade_flows/BACI_HS92_V202001.zip`, `legacy/201901/trade_flows/...`, with separate `zeros_V202001.zip` and `reporter_reliability_V202001.zip` files for the 2019 and 2020 versions.

### Sample response (Captured 2026-11-15, HEAD)

Headers only; the archives were not downloaded.

```
BACI_HS92_V202601.zip      200 OK  content-type: application/x-zip-compressed  content-length: 2417732497  last-modified: Thu, 22 Jan 2026 19:35:14 GMT
BACI_HS22_V202601.zip      200 OK  content-type: application/x-zip-compressed  content-length: 301386611   last-modified: Thu, 22 Jan 2026 19:34:36 GMT
release_notes_202601.pdf   200 OK  content-type: application/pdf               content-length: 283163      last-modified: Thu, 22 Jan 2026 19:41:49 GMT
```

### Trade-flow file rows (Representative)

Layout of `BACI_HS92_Y2023_V202601.csv` per the variable table above. The values are placeholders showing the column order and types, not data; country codes follow the Comtrade numbering that BACI inherits (842 United States, 484 Mexico, 392 Japan in that numbering) and must be checked against the country metadata file in the archive.

```csv
t,i,j,k,v,q
2023,842,484,100590,<thousands of current USD>,<metric tons>
2023,842,392,100590,<thousands of current USD>,<metric tons>
2023,842,484,120100,<thousands of current USD>,<metric tons>
```

### Metadata files (Representative)

The country file maps the 3-digit code to the country name and ISO codes; the product file maps HS6 codes to descriptions. File names in the 202601 archive were not read (the ZIP was not opened); in earlier releases they were `country_codes_V<version>.csv` and `product_codes_HS<rev>_V<version>.csv`.

```csv
country_code,country_name,country_iso2,country_iso3
842,USA,US,USA

code,description
100590,"Maize (excl. seed for sowing)"
```

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `t` | integer | year | Year in which the flow took place |
| `i` | integer | | Exporter, 3-digit Comtrade country code (not ISO 3166-1 numeric in every case) |
| `j` | integer | | Importer, 3-digit Comtrade country code |
| `k` | string | | HS6 product code in the revision of the archive; keep as text, leading zeros matter (`010121`) |
| `v` | number | thousands of current USD | Reconciled FOB value of the flow |
| `q` | number | metric tons | Quantity |

HS6 codes for the reference crops depend on the revision: in HS92 maize other than seed is `100590`, soya beans are `120100` (one code) and wheat other than durum is `100190`; from HS12 onwards soya beans split into `120110` (seed) and `120190` (other) and wheat into `100111`/`100119` (durum) and `100191`/`100199` (other). `100590` is unchanged across revisions. Eurostat's Comext labelled `100590` "Maize (excl. seed for sowing)" on 2026-11-15 (see `eurostat.md`).

## Licence

Etalab Open Licence 2.0 (Licence Ouverte 2.0), re-read on the BACI page on 2026-11-15: "BACI is distributed under the Etalab Open Licence 2.0, which means that any use is authorized, provided the source is mentionned. Mentioning BACI and the CEPII is an appropriate reference, ideally a link to the webpage can be added." The licence link on the page (`https://www.etalab.gouv.fr/wp-content/uploads/2018/11/open-licence.pdf`) redirects to `https://static.data.gouv.fr/resources/licence-ouverte-2-0/20260911-071954/open-licence.pdf` (PDF, 99,941 bytes; HEAD only, text not read). Reference to cite: Gaulier, G. and Zignago, S. (2010) BACI: International Trade Database at the Product-Level. The 1994-2007 Version. CEPII Working Paper 2010-23. Verdict in the inventory: PASS. BACI is built from UN Comtrade; UN Comtrade's own re-dissemination terms state that transformed data is not subject to its restrictions (inventory, not re-read today).

## Overlap with NASA sources

NASA publishes no trade statistics. BACI's country-to-country flows have no NASA counterpart; the NASA sources that sit beside them describe supply conditions rather than trade: NASA Harvest and the GEOGLAM Crop Monitor (crop condition by country), NASA POWER (weather) and the MODIS and HLS vegetation indices in `vegetation_indices.md`.

## Notes

- The archives were not downloaded (2.4 GB for HS92); sizes come from HEAD requests. The page warns that the trade-flow files are too large for spreadsheet software and that CEPII does not provide subsamples.
- The latest year in each release is built from Comtrade data downloaded in January and is often incomplete; CEPII advises not to mix versions in one analysis because flows are revised.
- Country codes: Comtrade numbering, so for example "Asia, not elsewhere specified" (490) is used as the proxy for Taiwan; the country metadata file is the mapping to ISO codes.
- Older archives (versions 201901, 202001) also ship `zeros_*.zip` (flows reported as zero) and `reporter_reliability_*.zip`; the 2021 and later archives on the page do not list these as separate files.
- The page links to World Bank concordance tables for mapping HS to other classifications; CEPII publishes HS only.

## Documentation

- BACI page (description, downloads, FAQ, licence): https://www.cepii.fr/DATA_DOWNLOAD/baci/doc/baci_webpage.html
- Release notes 202601: https://www.cepii.fr/DATA_DOWNLOAD/baci/doc/release_notes_202601.pdf
- Etalab Open Licence 2.0: https://www.etalab.gouv.fr/wp-content/uploads/2018/11/open-licence.pdf
- CEPII working paper 2010-23 (methodology): https://www.cepii.fr/CEPII/en/publications/wp/abstract.asp?NoDoc=2726
