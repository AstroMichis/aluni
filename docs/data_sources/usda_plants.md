# USDA PLANTS Database

The PLANTS Database (USDA NRCS, National Plant Data Team) holds standardized information on vascular plants, mosses, liverworts, hornworts and lichens of the U.S. and its territories: accepted names and synonyms, symbols, duration, growth habit, native status, state and county distribution, and, for a subset of taxa and cultivars, a set of "characteristics" (morphology/physiology, growth requirements, reproduction, suitability/use) such as nitrogen fixation, drought and shade tolerance, pH range, minimum temperature, frost-free days, precipitation range and minimum root depth. Characteristics are static attribute values per taxon or cultivar; there is no time dimension. The plants.usda.gov web site is an Angular application backed by a JSON service at `plantsservices.sc.egov.usda.gov/api/`; NRCS does not publish documentation for that service.

| | |
|---|---|
| Provider | USDA Natural Resources Conservation Service (NRCS), National Plant Data Team |
| Base URL | `https://plantsservices.sc.egov.usda.gov/api/` (JSON service used by the web site; unofficial, undocumented); downloads at `https://plants.sc.egov.usda.gov/DocumentLibrary/` |
| Auth | none |
| Formats | JSON (service); CSV-formatted text (complete checklist `plantlst.txt`); PDF (plant guides, fact sheets) |
| Coverage | U.S. and territories, plus Canada and other areas of the PLANTS Floristic Area for names and distribution; 93,156 checklist rows (accepted names plus synonyms) in `plantlst.txt` on 2026-11-14 |
| Resolution | per taxon (and per cultivar for characteristics) |
| Cadence / latency | not published |
| Rate limits / quotas | not published |
| Documentation | https://plants.usda.gov/ ; help document https://plants.sc.egov.usda.gov/DocumentLibrary/Pdf/PLANTS_Help_Document_2022.pdf |

The web app configuration (`https://plants.usda.gov/assets/config.json`) lists `plantsServicesUrl: https://plantsservices.sc.egov.usda.gov/api/` and a health check at `https://plantsservices.sc.egov.usda.gov/healthcheck` (returned `Health Check Succeeded` on 2026-11-14). Endpoint paths below were taken from the site's `main.js` bundle.

## Requests

### Plant profile by symbol (unofficial JSON)

Returns the taxon profile: names, rank, durations, growth habits, native status by region, ancestors, flags for available sections, plant guide and fact sheet paths. A synonym symbol returns the accepted taxon.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `symbol` | yes | PLANTS symbol (accepted or synonym) | `SECE` |
| `searchName` | no | Name used in the search (the web app passes it with the symbol) | |

```
GET https://plantsservices.sc.egov.usda.gov/api/PlantProfile?symbol=SECE
```

`GET https://plantsservices.sc.egov.usda.gov/api/PlantProfile/{Id}` returns the same object by numeric `Id`.

### Sample response (Captured 2026-11-14)

Trimmed: `Ancestors` reduced to rank and symbol of each of the 10 entries (each entry is a full profile object with mostly null fields); `MapCoordinates` removed; null-valued fields after `FactSheetUrls` removed.

```json
{
  "Id": 25527,
  "Symbol": "SECE",
  "ScientificName": "<i>Secale cereale</i> L.",
  "ScientificNameComponents": null,
  "CommonName": "cereal rye",
  "Group": "Monocot",
  "RankId": 180,
  "Rank": "Species",
  "Durations": ["Annual"],
  "GrowthHabits": ["Graminoid"],
  "NativeStatuses": [
    {"Region": "AK", "Status": "I", "Type": "Introduced"},
    {"Region": "CAN", "Status": "W", "Type": "Introduced"},
    {"Region": "GL", "Status": "W", "Type": "Introduced"},
    {"Region": "L48", "Status": "I", "Type": "Introduced"}
  ],
  "AcceptedId": 25527,
  "OtherCommonNames": [],
  "HasSynonyms": true,
  "Synonyms": null,
  "Ancestors": [
    {"Rank": "Kingdom", "Symbol": "Plantae"}, {"Rank": "Subkingdom", "Symbol": "Tracheobionta"},
    {"Rank": "Superdivision", "Symbol": "Spermatophyta"}, {"Rank": "Division", "Symbol": "Magnoliophyta"},
    {"Rank": "Class", "Symbol": "Liliopsida"}, {"Rank": "Subclass", "Symbol": "Commelinidae"},
    {"Rank": "Order", "Symbol": "Cyperales"}, {"Rank": "Family", "Symbol": "POACEA"},
    {"Rank": "Genus", "Symbol": "SECAL"}, {"Rank": "Species", "Symbol": "SECE"}
  ],
  "HasSubordinateTaxa": false,
  "HasWildlife": true,
  "HasWetlandData": false,
  "HasImages": true,
  "HasRelatedLinks": true,
  "HasLegalStatuses": false,
  "HasNoxiousStatuses": false,
  "HasDocumentation": true,
  "HasDistributionData": true,
  "PlantNotes": {"General_Notes": null, "Synonym_Notes": null, "Characteristic_Notes": null, "...": null},
  "NumImages": 0,
  "ProfileImageFilename": "sece_002_shp.jpg",
  "HasInvasiveStatuses": false,
  "PlantGuideUrls": ["/DocumentLibrary/plantguide/pdf/pg_sece.pdf"],
  "FactSheetUrls": ["/DocumentLibrary/factsheet/pdf/fs_sece.pdf"],
  "HasCharacteristics": true,
  "Characteristics": null
}
```

Profile lookups for the reference crops (Captured 2026-11-14):

| Request symbol | Returned `Symbol` | `Id` | ScientificName | CommonName | Durations | GrowthHabits | HasCharacteristics |
|---|---|---|---|---|---|---|---|
| ZEMA | ZEMA | 26453 | Zea mays L. | corn | Annual | Graminoid | true |
| GLMA4 | GLMA4 | 79390 | Glycine max (L.) Merr. | soybean | Annual | Forb/herb | true |
| TRAE | TRAE | 26221 | Triticum aestivum L. | common wheat | Annual | Graminoid | true |
| MESA | MESA | 81217 | Medicago sativa L. | alfalfa | Annual, Perennial | Forb/herb | true |
| SECE | SECE | 25527 | Secale cereale L. | cereal rye | Annual | Graminoid | true |
| MADO4 | MAPU | 90101 | Malus pumila Mill. | paradise apple | Perennial | Tree | false |
| MALUS | MALUS | 90034 | Malus Mill. (genus) | apple | Perennial | Shrub, Tree | true |

### Plant characteristics (unofficial JSON)

Returns a flat array of name/value records for the taxon, one per characteristic per cultivar (`CultivarName` null for the species-level record).

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{Id}` (path) | yes | Numeric `Id` from the profile | `25527` |

```
GET https://plantsservices.sc.egov.usda.gov/api/PlantCharacteristics/25527
```

### Sample response (Captured 2026-11-14)

First 3 of 156 records for SECE (50 Morphology/Physiology, 40 Growth Requirements, 40 Reproduction, 26 Suitability/Use):

```json
[
 {"PlantCharacteristicName": "Active Growth Period", "PlantCharacteristicValue": "Spring, Summer, Fall", "PlantCharacteristicCategory": "Morphology/Physiology", "CultivarName": null, "SynonymName": null},
 {"PlantCharacteristicName": "Active Growth Period", "PlantCharacteristicValue": "Spring, Summer, Fall", "PlantCharacteristicCategory": "Morphology/Physiology", "CultivarName": "Aroostook", "SynonymName": null},
 {"PlantCharacteristicName": "After Harvest Regrowth Rate", "PlantCharacteristicValue": "Moderate", "PlantCharacteristicCategory": "Morphology/Physiology", "CultivarName": "Aroostook", "SynonymName": null}
]
```

Selected characteristics for the reference crops, pivoted from the captured arrays (one row per `CultivarName`; "(species)" = `CultivarName` null). Values are copied exactly; an empty cell means the record has no such characteristic.

| Taxon (Id) / cultivar | Active Growth Period | Growth Form | Height, Mature (feet) | Lifespan | Nitrogen Fixation | C:N Ratio | Drought Tolerance | Shade Tolerance | Salinity Tolerance | Anaerobic Tolerance | CaCO3 Tolerance | Fertility Requirement | Moisture Use |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ZEMA (26453) (species) | Summer | Single Stem | 8.0 | | None | Medium | Low | Low | Low | None | Medium | High | High |
| GLMA4 (79390) (species) | Summer | Single Crown | 3.0 | | Medium | Low | Medium | High | Medium | Low | Low | Low | Medium |
| GLMA4 Bobwhite | Spring and Summer | Multiple Stem | 3.0 | | High | Low | Low | High | Medium | None | Low | Low | Medium |
| GLMA4 Quail Haven | Spring and Summer | Multiple Stem | 4.0 | | High | Low | Low | High | Medium | None | None | Low | Medium |
| TRAE (26221) (species) | Fall, Winter and Spring | Bunch | 3.3 | | None | Low | Medium | Low | Medium | None | Medium | Medium | Low |
| MESA (81217) (species) | Spring, Summer, Fall | Single Crown | 2.0 | Long | High | Low | High | High | Medium | None | High | High | High |
| MESA Ladak | Spring, Summer, Fall | Single Crown | 1.6 | Long | High | Low | High | High | Medium | None | Low | Medium | Medium |
| SECE (25527) (species) | Spring, Summer, Fall | Bunch | 3.5 | | None | Medium | Medium | High | Medium | None | Medium | Medium | High |
| SECE Aroostook | Spring, Summer, Fall | Bunch | 3.5 | | None | Medium | Medium | High | Medium | None | Medium | Medium | High |
| MALUS (90034) Magenta | Spring and Summer | Multiple Stem | 30.0 | Long | None | Medium | Medium | High | None | None | Medium | Medium | Medium |

| Taxon / cultivar | pH, Minimum | pH, Maximum | Precipitation, Minimum | Precipitation, Maximum | Root Depth, Minimum (inches) | Temperature, Minimum (°F) | Frost Free Days, Minimum | Adapted to Coarse / Medium / Fine Textured Soils | Planting Density per Acre, Min / Max | Seed per Pound | Small Grain |
|---|---|---|---|---|---|---|---|---|---|---|---|
| ZEMA (species) | 5.5 | 7.5 | 20 | 50 | 8 | 32 | 90 | No / Yes / No | 16000 / 23000 | 1134 | Yes |
| GLMA4 (species) | 5.5 | 7.8 | 16 | 59 | 8 | -28 | 140 | Yes / Yes / Yes | | 4880 | No |
| GLMA4 Bobwhite | 5.7 | 7.2 | 30 | 60 | 8 | 47 | 100 | Yes / Yes / Yes | | 5000 | No |
| GLMA4 Quail Haven | 5.7 | 7.2 | 30 | 60 | 8 | 47 | 100 | No / Yes / Yes | | 5000 | No |
| TRAE (species) | 5.5 | 8.0 | 10 | 100 | 18 | -28 | 100 | Yes / Yes / Yes | | 11360 | Yes |
| MESA (species) | 6.0 | 8.5 | 12 | 65 | 24 | -43 | 90 | No / Yes / Yes | | 226800 | No |
| MESA Ladak | 6.2 | 7.2 | 16 | 30 | 24 | -33 | 100 | No / Yes / No | | 226800 | No |
| SECE (species) | 4.5 | 8.2 | 8 | 50 | 8 | -33 | 110 | Yes / Yes / No | | 18160 | Yes |
| SECE Aroostook | 5.2 | 7.5 | 15 | 50 | 8 | -43 | 90 | Yes / Yes / No | | 18160 | Yes |
| MALUS Magenta | 5.0 | 7.5 | 33 | 55 | 30 | -78 | 100 | Yes / Yes / No | 300 / 1200 | 20000 | No |

The two GLMA4 cultivar records carry `SynonymName` "<i>Glycine soja</i> (L.) Merr., non Siebold & Zucc., nom. illeg.".

### Name search (unofficial JSON)

Returns matching names, each with a reduced plant object.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `searchText` | yes | Name text | `cereal rye` |

```
GET https://plantsservices.sc.egov.usda.gov/api/PlantSearch?searchText=cereal%20rye
```

### Sample response (Captured 2026-11-14)

First element only; null and false fields of the nested `Plant` object removed.

```json
[{"Text": "cereal rye", "Plant": {"Id": 25527, "Symbol": "SECE", "ScientificName": "<i>Secale cereale</i> L.", "CommonName": "cereal rye", "RankId": 180, "Rank": "Species", "AcceptedId": 0, "NumImages": 0, "ImageId": 0, "PlantLocationId": 0}}]
```

### Cover crop plant list (unofficial JSON)

Returns the list of taxa the site flags as cover crop plants.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `orderBy` | yes (HTTP 400 "The orderBy field is required." when empty) | Sort key | `CommonName` |

```
GET https://plantsservices.sc.egov.usda.gov/api/common/getCoverCropPlants?orderBy=CommonName
```

### Sample response (Captured 2026-11-14)

First 2 of 112 elements:

```json
[{"Symbol":"AMCA3","Synonym":null,"ScientificName":"Amaranthus caudatus","CommonName":"foxtail amaranth","PlantFamily":"Amaranthaceae - Amaranth family"},
 {"Symbol":"AMCR4","Synonym":null,"ScientificName":"Amaranthus cruentus","CommonName":"red amaranth","PlantFamily":"Amaranthaceae - Amaranth family"}]
```

`orderBy=ScientificName` and `orderBy=CommonName` returned identical bodies (15,582 bytes) in this capture.

### Other service paths found in the web app (not captured)

`PlantSynonyms/{id}`, `PlantSubordinateTaxa/{id}?offset=`, `Classification/{id}`, `PlantDocumentation/{id}?orderBy=&offset=`, `PlantWildlife/{id}`, `PlantWetland/{id}`, `PlantLegalStatus/{id}`, `PlantNoxiousStatus/{id}`, `PlantInvasiveStatus/{id}`, `PlantRelatedLinks/{id}`, `PlantEthnobotany/{id}`, `PlantPollinator/{id}`, `RaritySearch?state=`, `StateSearch/GetCounties/{stateId}`, `PlantSpotlight`, `common/getCulturallySignificantPlants`, `plantsDownload/GetGSATStateList`, `plantsDownload/GetGSATByState?state=`, `plantsDownload/GetUnkownSymbolCSV`, and POST endpoints `plants-search-results`, `plants-search-results/download`, `characteristicSearchResults`, `characteristicSearchFilterResults`, `characteristicSearchResultsDownload`, `PlantProfile/getDownloadDistributionDocumentation`.

### Complete PLANTS checklist (official download)

Comma-separated, quoted text file of all accepted names and synonyms.

| Parameter | Required | Description | Example |
|---|---|---|---|
| (none) | | Static file | |

```
GET https://plants.sc.egov.usda.gov/DocumentLibrary/Txt/plantlst.txt
```

### Sample rows (Captured 2026-11-14)

File size 7,038,655 bytes, 93,157 lines including header. Header plus the rows for the reference crops' symbols (other rows omitted; synonym rows for ZEMA's neighbours omitted):

```csv
"Symbol","Synonym Symbol","Scientific Name with Author","Common Name","Family"
"MAPU","","Malus pumila Mill.","paradise apple","Rosaceae"
"MAPU","MACO21","Malus communis Poir.","",""
"MAPU","MADO4","Malus domestica auct. non Borkh.","",""
"MAPU","MAPR8","Malus praecox (Pall.) Borkh.","",""
"MAPU","MAPUN2","Malus pumila Mill. var. niedzwetzkyana (Dieck) C.K. Schneid.","",""
"MAPU","MASY3","Malus sylvestris Amer. auth., non (L.) Mill.","",""
"MAPU","MASYP","Malus sylvestris (L.) Mill. var. praecox (Pall.) Ponomar.","",""
"MAPU","PYPU3","Pyrus pumila (Mill.) K. Koch","",""
"SECE","","Secale cereale L.","cereal rye","Poaceae"
"SECE","SEMO","Secale montanum Guss., nom. inq.","",""
"SECE","SEST10","Secale strictum (C. Presl) C. Presl","",""
"SECE","TRCE5","Triticum cereale (L.) Salisb.","",""
"ZEMA","","Zea mays L.","corn","Poaceae"
```

## Fields

### PlantProfile

| Field | Type | Unit | Description |
|---|---|---|---|
| `Id` | integer | | Internal numeric id; used in the other `/{id}` paths |
| `Symbol` | string | | PLANTS symbol of the accepted taxon |
| `ScientificName` | string (HTML) | | Name with author; genus/epithet wrapped in `<i>` tags |
| `CommonName` | string | | National common name |
| `Group` | string | | e.g. Monocot, Dicot |
| `RankId` / `Rank` | integer / string | | Taxonomic rank (180 = Species) |
| `Durations` | string[] | | Annual, Biennial, Perennial |
| `GrowthHabits` | string[] | | e.g. Graminoid, Forb/herb, Shrub, Tree, Vine, Subshrub |
| `NativeStatuses` | object[] | | `Region` (e.g. L48, AK, HI, PR, VI, CAN, GL, SPM, PB), `Status` code, `Type` (Native/Introduced) |
| `MapCoordinates` | object[] | degrees | Bounding boxes per region (`StateAbbr`, `XMin`, `YMin`, `XMax`, `YMax`) |
| `AcceptedId` | integer | | Id of accepted taxon |
| `OtherCommonNames` | string[] | | Additional common names |
| `HasSynonyms`, `HasCharacteristics`, `HasImages`, ... | boolean | | Whether the corresponding section exists (fetched by its own path) |
| `Ancestors` | object[] | | Classification from Kingdom down, each a reduced profile object |
| `PlantNotes` | object | | Note text per section (`General_Notes`, `Characteristic_Notes`, ...) |
| `PlantGuideUrls` / `FactSheetUrls` | string[] | | Paths relative to `https://plants.sc.egov.usda.gov` |
| `ProfileImageFilename` | string | | Image file name |

### PlantCharacteristics

| Field | Type | Unit | Description |
|---|---|---|---|
| `PlantCharacteristicName` | string | in name where given | Characteristic name; units appear only inside some names, e.g. "Height, Mature (feet)", "Root Depth, Minimum (inches)", "Temperature, Minimum (°F)" |
| `PlantCharacteristicValue` | string | | Value as text (numbers are strings, e.g. "7.5") |
| `PlantCharacteristicCategory` | string | | Morphology/Physiology, Growth Requirements, Reproduction, Suitability/Use |
| `CultivarName` | string or null | | Cultivar the record applies to; null for the taxon-level record |
| `SynonymName` | string or null | | Synonym under which the record was entered |

Characteristic names observed in the captures (category: names): Morphology/Physiology: Active Growth Period, After Harvest Regrowth Rate, Bloat, C:N Ratio, Coppice Potential, Fall Conspicuous, Fire Resistant, Flower Color, Flower Conspicuous, Foliage Color, Foliage Porosity Summer, Foliage Porosity Winter, Foliage Texture, Fruit/Seed Color, Fruit/Seed Conspicuous, Growth Form, Growth Rate, Height at 20 Years, Maximum (feet), Height, Mature (feet), Known Allelopath, Leaf Retention, Lifespan, Low Growing Grass, Nitrogen Fixation, Resprout Ability, Shape and Orientation, Toxicity. Growth Requirements: Adapted to Coarse / Medium / Fine Textured Soils, Anaerobic Tolerance, CaCO3 Tolerance, Cold Stratification Required, Drought Tolerance, Fertility Requirement, Fire Tolerance, Frost Free Days, Minimum, Hedge Tolerance, Moisture Use, pH, Minimum, pH, Maximum, Planting Density per Acre, Minimum / Maximum, Precipitation, Minimum / Maximum, Root Depth, Minimum (inches), Salinity Tolerance, Shade Tolerance, Temperature, Minimum (°F). Reproduction: Bloom Period, Commercial Availability, Fruit/Seed Abundance, Fruit/Seed Period Begin / End, Fruit/Seed Persistence, Propagated by Bare Root / Bulb / Container / Corm / Cuttings / Seed / Sod / Sprigs / Tubers, Seed per Pound, Seed Spread Rate, Seedling Vigor, Small Grain, Vegetative Spread Rate. Suitability/Use: Berry/Nut/Seed Product, Christmas Tree Product, Fodder Product, Fuelwood Product, Lumber Product, Naval Store Product, Nursery Stock Product, Palatable Browse Animal, Palatable Graze Animal, Palatable Human, Post Product, Protein Potential, Pulpwood Product, Veneer Product.

### plantlst.txt

| Field | Type | Unit | Description |
|---|---|---|---|
| `Symbol` | string | | Accepted symbol |
| `Synonym Symbol` | string | | Empty on the accepted-name row; synonym symbol on synonym rows |
| `Scientific Name with Author` | string | | Name with authority |
| `Common Name` | string | | Filled on accepted rows only |
| `Family` | string | | Filled on accepted rows only |

## Notes

- The JSON service is not documented by NRCS; paths and shapes were read from the web app bundle and captured responses on 2026-11-14 and may change without notice.
- No auth header or key was needed for any captured request.
- `MADO4` (Malus domestica) is a synonym in PLANTS ("Malus domestica auct. non Borkh."); `PlantProfile?symbol=MADO4` returned the accepted taxon `MAPU` (Malus pumila, "paradise apple"), which has `HasCharacteristics: false`. The only apple characteristics found were on the genus `MALUS` (Id 90034), for cultivar "Magenta".
- PLANTS has no separate winter wheat taxon; `TRAE` (Triticum aestivum, "common wheat") is the species record.
- Units are stated in the characteristic name only for height (feet), root depth (inches) and minimum temperature (°F). "Precipitation, Minimum/Maximum" and "Frost Free Days, Minimum" carry no unit in the API response or in the PLANTS help document (DOCX) checked; the unit is not documented in the sources fetched.
- Values within a taxon differ by cultivar and are not aggregated (e.g. GLMA4 "Temperature, Minimum (°F)" is -28 for the species record and 47 for cultivars Bobwhite and Quail Haven).
- Plant guide and fact sheet paths are relative; prefix `https://plants.sc.egov.usda.gov` (e.g. `pg_sece.pdf` returned HTTP 200, application/pdf).
- `plants.usda.gov` URLs redirect to `plants.sc.egov.usda.gov`.

## Documentation

- PLANTS Database: https://plants.usda.gov/
- Help document (PDF): https://plants.sc.egov.usda.gov/DocumentLibrary/Pdf/PLANTS_Help_Document_2022.pdf (DOCX: https://plants.sc.egov.usda.gov/DocumentLibrary/Docx/PLANTS_Help_Document.docx)
- Complete checklist: https://plants.sc.egov.usda.gov/DocumentLibrary/Txt/plantlst.txt
- Web app configuration: https://plants.usda.gov/assets/config.json
- Licence and citation (help document): the help document states that PLANTS plant information (distribution maps, lists, text) is not copyrighted and is free for any use; cite as "USDA, NRCS. [YEAR]. The PLANTS Database (http://plants.usda.gov, [DAY MONTH YEAR]). National Plant Data Team, Greensboro, NC USA." Images have separate copyright conditions.
