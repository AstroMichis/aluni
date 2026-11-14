# Cover crop decision tools (MCCC Decision Tool and Cover Crop Council Species Selector)

Two public cover crop tools publish per-species, per-location cover crop data for the U.S.: (1) the Midwest Cover Crops Council (MCCC) Cover Crop Decision Tool, which gives county-level seeding windows and goal ratings for 13 U.S. states, Ontario and Michigan vegetable crops; (2) the Cover Crop Species Selector built by Precision Sustainable Agriculture (PSA) with the four regional cover crop councils (MCCC, NECCC, SCCC, WCCC), backed by the "Crop Selector API" at `api.covercrop-selector.org`. Both return species ratings (goals such as nitrogen source/scavenger, erosion fighter, weed fighter, grazing), soil drainage suitability, winter survival and establishment date windows. The data are static expert ratings per council zone or county; frost dates and planting windows are county climatology. Neither tool requires a login to read data.

| | |
|---|---|
| Provider | Midwest Cover Crops Council (decision tool, hosted by Michigan State University); Precision Sustainable Agriculture with MCCC, NECCC, SCCC, WCCC (species selector and API) |
| Base URL | `https://covercroptool.midwestcovercrops.org/` (MCCC tool JSON, unofficial); `https://api.covercrop-selector.org/` (Crop Selector API v3.0.0) |
| Auth | none needed in practice; the Crop Selector API OpenAPI spec declares an `x-api-key` header scheme on every operation, but all requests below succeeded without a key |
| Formats | JSON; Crop Selector API `output` parameter also lists `csv`, `html`, `xlsx` |
| Coverage | MCCC tool: IL, IN, IA, KS, MI, MN, MO, NE, ND, OH, SD, WI, Ontario, "Michigan Vegetable Crops"; Selector: U.S. states by council |
| Resolution | county (MCCC tool); state + council zone/county/ecoregion region ids (Selector) |
| Cadence / latency | not published; MCCC attribution text lists "Data Version 1.0" |
| Rate limits / quotas | not published |
| Documentation | https://api.covercrop-selector.org/redoc ; https://www.midwestcovercrops.org/selector-tools/ |

## Requests

### Crop Selector API: regions for a point

Returns the council, state and sub-regions (county, ecoregion) containing a lat/lon, plus council data attribution text.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `lat` | yes | Latitude | `40.95` |
| `lon` | yes | Longitude | `-97.5` |
| `output` | no | `json`, `csv`, `html`, `xlsx` | `json` |

```
GET https://api.covercrop-selector.org/v1/regions?lat=40.95&lon=-97.5
```

### Sample response (Captured 2026-11-14)

Trimmed: `attributions` reduced to the MCCC entry; NECCC, SCCC, WCCC and the combined `generalStatement` entries removed (same wording with each council's name).

```json
{"type":"array",
 "data":[
  {"id":56,"label":"Midwest Cover Crops Council","shorthand":"MCCC"},
  {"id":31,"label":"Nebraska","shorthand":"NE","councilId":56,"parentId":56,"localityId":1},
  {"id":859,"label":"York","locality_id":3,"created_at":"2023-02-27T20:56:26.049Z","updated_at":"2023-02-27T20:56:26.049Z","deleted_at":null,"shorthand":"York","council_id":null,"parent_id":31,"context_id":null,"subregions":{}},
  {"id":1316,"label":"Great Plains","locality_id":6,"created_at":"2024-12-02T08:36:28.292Z","updated_at":"2024-12-02T08:36:28.292Z","deleted_at":null,"shorthand":"Ecoregion 9","council_id":1198,"parent_id":null,"context_id":2,"subregions":{}}
 ],
 "attributions":{"MCCC":{
  "generalStatement":"We, MCCC have released our species selection and seeding rate calculator data under the CC-BY4.0 license. ...",
  "withModifications":"“Midwestern Cover Crops Species Selector Data” by Midwest Cover Crops Council is licensed under CC-BY4.0 / Data Version 1.0 / Date Copied: 01/01/2024 / [list modifications and exclusions]. The MCCC does not endorse this use of the data.",
  "withoutModifications":"“Midwestern Cover Crops Species Selector Data” by Midwest Cover Crops Council (MCCC) is licensed under CC-BY4.0 / no modifications and no exclusions / Data Version 1.0 / Date Copied: 01/01/2024 / no modifications and no exclusions. The MCCC does not endorse this use of the data."}}}
```

### Crop Selector API: crops for a state and regions

Returns every species available in the state with all attributes, goals and planting-date windows for the given region ids.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `stateId` (path) | yes | State region id (from `/v1/states` or `/v1/regions`) | `31` (Nebraska) |
| `regions` | no per spec | Region id(s) | `859` (York County) |
| `output` | no | `json`, `csv`, `html`, `xlsx` | |

```
GET https://api.covercrop-selector.org/v1/states/31/crops?regions=859
```

`GET /v1/states/{stateId}/crops/{cropId}?regions=` returns one crop. Other operations in the spec: `/v1/states`, `/v1/states/{stateId}/regions`, `/v1/states/{stateId}/filters`, `/v1/states/{stateId}/dictionary`, `/v1/states/{stateId}/goals?regions=&seasons=`, `/v1/attribute-values?regions=&slug=`, `/v1/crops/{cropId}/images`, `/v1/crops/{cropId}/resources`, `/v2/attribute/`, `/v2/crops/`, `/v2/crops/{cropId}`, `/v2/regions`, `/v2/regions/{stateId}`, `/v3/dictionary`, `/v3/council?council=&zone=&state=&crop=&category=`, `/v3/crops?council=`, `/v3/filters_goals`, `/v3/regions`, `/v3/regions/{stateId}`, `/v3/airtable`, `/qc/*`, `/v1/health-check`.

### Sample response (Captured 2026-11-14)

Response size 754,401 bytes, 55 crops for Nebraska / York. Trimmed: one crop object (`Rye, Winter Cereal`, id 599) shown; `attributes` reduced to 14 of 40 entries with `description` kept on the first only; `goals` (18 entries, same shape as `attributes`) reduced to labels; thumbnail URLs shortened.

```json
{"type":"array","data":[
 {"id":599,"label":"Rye, Winter Cereal","group":"Grass","scientificName":"Secale cereale",
  "thumbnail":"https://selectorimages.blob.core.windows.net/processed/Rye, Winter Cereal/thumbnails/50x50_...jpg",
  "isMix":false,
  "soilDrainage":["Somewhat poorly drained","Moderately well drained","Well drained","Somewhat excessively drained","Excessively drained","Well drained muck"],
  "keyTraits":[],
  "attributes":[
   {"label":"Cash Crop Interseed","dataType":"pillbox","description":"Cover crop’s suitability for establishment into a standing cash crop, either early in the growing season or just prior to harvest.","units":"","values":[{"value":"3","label":"Very Good"}]},
   {"label":"Drought Tolerance","dataType":"pillbox","units":"","values":[{"value":"2","label":"Good"}]},
   {"label":"Erosion Fighter","dataType":"pillbox","units":"","values":[{"value":"4","label":"Excellent"}]},
   {"label":"Flooding Duration","dataType":"string","units":"","values":[{"value":"2","label":"Brief - up to 7 days"}]},
   {"label":"Frost Seed","dataType":"boolean","units":"","values":[{"value":"1","label":"Yes"}]},
   {"label":"Good Grazing","dataType":"pillbox","units":"","values":[{"value":"4","label":"Excellent"}]},
   {"label":"Increased Weed Potential","dataType":"pillbox","units":"","values":[{"value":"0","label":"Could be a major problem"}]},
   {"label":"Legume Nitrogen Source","dataType":"pillbox","units":"","values":[{"value":"0","label":"Poor"}]},
   {"label":"Nitrogen Scavenger","dataType":"pillbox","units":"","values":[{"value":"4","label":"Excellent"}]},
   {"label":"Planting Methods","dataType":"string","units":"","values":[{"value":"Precision"},{"value":"Aerial"},{"value":"Broadcast"},{"value":"Drilled"}]},
   {"label":"Soil Builder","dataType":"pillbox","units":"","values":[{"value":"4","label":"Excellent"}]},
   {"label":"Termination Methods","dataType":"string","units":"","values":[{"value":"Tillage"},{"value":"Mow"},{"value":"Chemical"},{"value":"Roller Crimper"}]},
   {"label":"Weed Fighter","dataType":"pillbox","units":"","values":[{"value":"4","label":"Excellent"}]},
   {"label":"Winter Survivability","dataType":"integer","units":"","values":[{"value":"4","label":"Excellent"}]}
  ],
  "goals":["Cash Crop Interseed","Drought Tolerance","Early Interseed (Pre-Canopy)","Erosion Fighter","Flood Tolerance","Good Grazing","Grain Seed Harvest","Heat Tolerance","Lasting Residue","Legume Nitrogen Source","Limited Rainfall","Low Fertility Tolerance","Mechanical Forage Harvest","Quick Growth","Shade Tolerance","Soil Builder","Weed Fighter","Winter Survivability"],
  "plantingDates":[
   {"label":"Freeze/Moisture Risk to Establishment","description":"The Temperature/Moisture Risk period is an approximation. ...","values":[{"value":"07/20/2009 - 08/29/2009"},{"value":"11/04/2009 - 12/16/2009"}]},
   {"label":"Reliable Establishment","description":"The Reliable Establishment period is an approximation. ...","values":[{"value":"08/29/2009 - 11/04/2009"}]}
  ]}
 ],
 "attributions":{"...":"..."}}
```

All 40 attribute values captured for the two species (same request), as `value` / `label`:

| Attribute | Rye, Winter Cereal (599, Secale cereale) | Clover, Red (544, Trifolium pratense) |
|---|---|---|
| Cash Crop Interseed | 3 Very Good | 3 Very Good |
| Delayed Emergence | 2 Could be a minor problem | 2 Could be a minor problem |
| Drought Tolerance | 2 Good | 2 Good |
| Erosion Fighter | 4 Excellent | 2 Good |
| Establishment Challenges | 4 Rarely a problem | 3 Occasionally a minor problem |
| Flooding Duration | 2 Brief - up to 7 days | 2 Brief - up to 7 days |
| Flood Tolerance | 2 Good | 2 Good |
| Fly-free Date | 0 No | 0 No |
| Frost Seed | 1 Yes | 1 Yes |
| Good Grazing | 4 Excellent | 3 Very Good |
| Grain Seed Harvest | 4 Excellent | 2 Good |
| Heat Tolerance | 2 Good | 3 Very Good |
| Hinders Crops | 1 Could be a moderate problem | 4 Rarely a problem |
| Increased Crop Diseases | 2 Could be a minor problem | 2 Could be a minor problem |
| Increased Insects/Nematodes | 5 Information too limited to rate | 1 Could be a moderate problem |
| Increased Weed Potential | 0 Could be a major problem | 2 Could be a minor problem |
| Lasting Residue | 4 Excellent | 1 Fair |
| Legume Nitrogen Source | 0 Poor | 3 Very Good |
| Low Fertility Tolerance | 3 Very Good | 2 Good |
| Mature Incorporation Challenges | 1 Could be a moderate problem | 3 Occasionally a minor problem |
| Mechanical Forage Harvest | 4 Excellent | 3 Very Good |
| Nitrogen Scavenger | 4 Excellent | 1 Fair |
| Other - Attract Beneficials | 1 Fair | 3 Very Good |
| Other - Bears Traffic | 4 Excellent | 3 Very Good |
| Other - Short Windows | 3 Very Good | 1 Fair |
| Planting Methods | Precision, Aerial, Broadcast, Drilled | Precision, Aerial, Broadcast, Drilled |
| Quick Growth | 3 Very Good | 2 Good |
| Shade Tolerance | 3 Very Good | 3 Very Good |
| Soil Builder | 4 Excellent | 3 Very Good |
| Soil Ecology - Allelopathic | 4 Excellent | 2 Good |
| Soil Ecology - Choke Weeds | 4 Excellent | 2 Good |
| Soil Ecology - Disease | 2 Good | 2 Good |
| Soil Ecology - Nematodes | 2 Good | 3 Very Good |
| Soil Impact - Frees P and K | 5 Information too limited to rate | 5 Information too limited to rate |
| Soil Impact - Loosens Topsoil | 4 Excellent | 3 Very Good |
| Soil Impact - Subsoiler | 3 Very Good | 3 Very Good |
| Termination Methods | Tillage, Mow, Chemical, Roller Crimper | Tillage, Chemical |
| Weed Fighter | 4 Excellent | 3 Very Good |
| Winter Survivability | 4 Excellent | 4 Excellent |
| Winter Survival | See Winter Survivability | See Winter Survivability |
| soilDrainage | Somewhat poorly drained ... Well drained muck (6 classes, above) | Poorly drained, Somewhat poorly drained, Moderately well drained, Well drained, Somewhat excessively drained, Excessively drained, Well drained muck |
| plantingDates | Freeze/Moisture Risk 07/20-08/29 and 11/04-12/16; Reliable Establishment 08/29-11/04 | Reliable Establishment 03/31-05/18 and 08/29-10/09 |

Other clovers returned for Nebraska / York: `Clover, Balansa`, `Clover, Berseem`, `Clover, Crimson`, `Sweetclover`.

### MCCC Decision Tool: county grid

Returns one row per cover crop for a state/county: drainage suitability flags, goal ratings, and seeding-window bars.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `published` | yes (as used by the tool) | Published rows only | `1` |
| `state` | yes | `STATE_ID` from `/states` | `NE` |
| `county` | no | `COUNTY_ID` from `/counties` | `1959` (York, NE) |

```
GET https://covercroptool.midwestcovercrops.org/grids?published=1&state=NE&county=1959
```

Supporting lists used by the tool: `/states`, `/counties`, `/cash-crops`, `/cover-crops`, `/cover-crop-families`, `/frost-freeze?stid=NE`, `/goals?stid=NE`. The base URL is built in the tool's `main.bundle.js` from `window.location.origin`; these paths are not documented by MCCC.

### Sample response (Captured 2026-11-14)

61 rows (75,570 bytes). Two rows shown untrimmed:

```json
[
{"CC_ID": "1111", "STATE_ID": "NE", "COVER_CROP_ID": "9", "DISPLAY_NAME": "Rye, Winter Cereal", "FAMILY": "Grasses", "ccStateUse": "C", "flyFree": "No", "frostSeeding": "Yes", "veryPoorlyDrained": "0", "poorlyDrained": "0", "somePoorlyDrained": "1", "modWellDrained": "1", "wellDrained": "1", "excessDrained": "1", "saturatedMuck": "0", "wellDrainedMuck": "1", "ponding": "2", "nSourceAttr": "0", "nScavengerAttr": "4", "soilBuilderAttr": "4", "erosionFighterAttr": "4", "weedFighterAttr": "4", "goodGrazingAttr": "4", "quickGrowthAttr": "3", "lastingResidueAttr": "4", "forageHarvestAttr": "4", "grainSeedHarvestAttr": "4", "interseedCashCropAttr": "3", "earlyInterseedAttr": null, "salinityTolerance": "0", "limitedRainFall": "0", "surfaceLayerTilthEnhancer": "0", "waterErosionFighter": "0", "windProtection": "0", "weedSuppressor": "0", "quickBreakdown": "0", "attractsBeneficialInsects": "0", "nurseCompanionCrop": "0", "forageValue": "0", "seedHarvestValue": "0", "plowPanPerforator": "0", "winterSurvivalAttr": "4", "ws_county_id": "1959", "PUBLISHED": "1", "id": "4544", "cc_id": "1111", "bars": [{"START_NUM": 201, "END_NUM": 241, "COLOR": "Y"}, {"START_NUM": 241, "END_NUM": 308, "COLOR": "G"}, {"START_NUM": 308, "END_NUM": 350, "COLOR": "Y"}]},
{"CC_ID": "1134", "STATE_ID": "NE", "COVER_CROP_ID": "21", "DISPLAY_NAME": "Clover, Red", "FAMILY": "Legumes", "ccStateUse": "C", "flyFree": "No", "frostSeeding": "Yes", "veryPoorlyDrained": "0", "poorlyDrained": "1", "somePoorlyDrained": "1", "modWellDrained": "1", "wellDrained": "1", "excessDrained": "1", "saturatedMuck": "0", "wellDrainedMuck": "1", "ponding": "2", "nSourceAttr": "3", "nScavengerAttr": "1", "soilBuilderAttr": "3", "erosionFighterAttr": "2", "weedFighterAttr": "3", "goodGrazingAttr": "3", "quickGrowthAttr": "2", "lastingResidueAttr": "1", "forageHarvestAttr": "3", "grainSeedHarvestAttr": "2", "interseedCashCropAttr": "3", "earlyInterseedAttr": null, "salinityTolerance": "0", "limitedRainFall": "0", "surfaceLayerTilthEnhancer": "0", "waterErosionFighter": "0", "windProtection": "0", "weedSuppressor": "0", "quickBreakdown": "0", "attractsBeneficialInsects": "0", "nurseCompanionCrop": "0", "forageValue": "0", "seedHarvestValue": "0", "plowPanPerforator": "0", "winterSurvivalAttr": "4", "ws_county_id": "1959", "PUBLISHED": "1", "id": "695", "cc_id": "1134", "bars": [{"START_NUM": 90, "END_NUM": 138, "COLOR": "G"}, {"START_NUM": 241, "END_NUM": 282, "COLOR": "G"}]}
]
```

Frost and fly-free row for the same county (`/frost-freeze?stid=NE`, one of the returned rows):

```json
{"STATE_ID": "NE", "COUNTY_ID": "1959", "spring90": "90", "spring50": "104", "spring10": "118", "fall10": "282", "fall50": "296", "fall90": "308", "flyFree": "0"}
```

Goals list (`/goals?stid=NE`), untrimmed:

```json
[{"id": "erosionFighterAttr", "name": "Erosion Fighter"}, {"id": "forageHarvestAttr", "name": "Mechanical Forage Harvest Value"}, {"id": "goodGrazingAttr", "name": "Good Grazing"}, {"id": "grainSeedHarvestAttr", "name": "Grain/Seed Harvest Value"}, {"id": "interseedCashCropAttr", "name": "Late Interseed (Pre-Harvest)"}, {"id": "lastingResidueAttr", "name": "Lasting Residue"}, {"id": "nScavengerAttr", "name": "Nitrogen Scavenger"}, {"id": "nSourceAttr", "name": "Nitrogen Source"}, {"id": "quickGrowthAttr", "name": "Quick Growth"}, {"id": "soilBuilderAttr", "name": "Soil Builder"}, {"id": "weedFighterAttr", "name": "Weed Fighter"}, {"id": "winterSurvivalAttr", "name": "Winter Survivability"}]
```

## Fields

### Crop Selector API crop object

| Field | Type | Unit | Description |
|---|---|---|---|
| `id` | integer | | Crop id |
| `label` | string | | Display name (e.g. "Rye, Winter Cereal") |
| `group` | string | | Grass, Legume, Brassica, Broadleaf (values in the Nebraska capture) |
| `scientificName` | string | | Scientific name |
| `thumbnail*` | string (URL) | | Image URLs in several sizes |
| `isMix` | boolean | | Species mix flag |
| `soilDrainage` | string[] | class | Drainage classes the species is rated for |
| `keyTraits` | array | | Key traits (empty in captures) |
| `attributes[]` | object[] | | `label`, `dataType` (`pillbox`, `string`, `boolean`, `integer`), `description`, `units` (empty in captures), `values[]` of `{value, label}` |
| `goals[]` | object[] | | Subset of attributes used as goals, same shape |
| `plantingDates[]` | object[] | date range | `label` ("Reliable Establishment", "Freeze/Moisture Risk to Establishment"), `description`, `values[]` of `"MM/DD/YYYY - MM/DD/YYYY"` |

Pillbox rating scale observed: `0` Poor / Could be a major problem, `1` Fair / Could be a moderate problem, `2` Good / Could be a minor problem, `3` Very Good / Occasionally a minor problem, `4` Excellent / Rarely a problem, `5` Information too limited to rate.

### MCCC grid row

| Field | Type | Unit | Description |
|---|---|---|---|
| `CC_ID`, `cc_id`, `id` | string (numeric) | | Row identifiers |
| `STATE_ID`, `ws_county_id` | string | | State code, county id |
| `COVER_CROP_ID`, `DISPLAY_NAME`, `FAMILY` | string | | Cover crop id, name, family (Grasses, Legumes, Brassicas, Broadleaves, Mixes in the Nebraska capture) |
| `ccStateUse` | string | code | State use code (values `C`, `E` observed; meaning not documented in sources fetched) |
| `flyFree`, `frostSeeding` | string | Yes/No | Hessian fly-free date applies; frost seeding suitable |
| `veryPoorlyDrained`, `poorlyDrained`, `somePoorlyDrained`, `modWellDrained`, `wellDrained`, `excessDrained`, `saturatedMuck`, `wellDrainedMuck` | string | 0/1 | Drainage class suitability flags |
| `ponding` | string | code | Ponding tolerance code |
| `nSourceAttr`, `nScavengerAttr`, `soilBuilderAttr`, `erosionFighterAttr`, `weedFighterAttr`, `goodGrazingAttr`, `quickGrowthAttr`, `lastingResidueAttr`, `forageHarvestAttr`, `grainSeedHarvestAttr`, `interseedCashCropAttr`, `earlyInterseedAttr`, `winterSurvivalAttr` | string or null | rating | Goal ratings (names in `/goals`) |
| `salinityTolerance`, `limitedRainFall`, `surfaceLayerTilthEnhancer`, `waterErosionFighter`, `windProtection`, `weedSuppressor`, `quickBreakdown`, `attractsBeneficialInsects`, `nurseCompanionCrop`, `forageValue`, `seedHarvestValue`, `plowPanPerforator` | string | rating | Additional attributes (all "0" in the rows shown) |
| `bars[]` | object[] | day of year | Seeding windows: `START_NUM`, `END_NUM`, `COLOR` (`G`, `Y`) |
| `PUBLISHED` | string | 0/1 | Published flag |

### MCCC frost-freeze row

| Field | Type | Unit | Description |
|---|---|---|---|
| `spring90`, `spring50`, `spring10` | string (numeric) | day of year (as returned) | Spring freeze dates at 90/50/10 levels |
| `fall10`, `fall50`, `fall90` | string (numeric) | day of year (as returned) | Fall freeze dates at 10/50/90 levels |
| `flyFree` | string | | Hessian fly-free date value ("0" for York, NE) |

All numeric values in MCCC responses are strings.

## Notes

- For winter cereal rye in York County, NE, the MCCC `bars` (Y 201-241, G 241-308, Y 308-350) coincide with the Selector `plantingDates` for the same county when converted from 2009 calendar dates to day of year (07/20 = 201, 08/29 = 241, 11/04 = 308, 12/16 = 350): `Y` matches "Freeze/Moisture Risk to Establishment" and `G` matches "Reliable Establishment". The same holds for red clover (G 90-138, 241-282 vs 03/31-05/18, 08/29-10/09). Selector dates carry the placeholder year 2009.
- Neither response captured contains seeding rates or nitrogen amounts (lb/acre) for these species; the attribution text refers to a separate "seeding rate calculator" dataset.
- The Crop Selector API spec declares `x-api-key` on every operation, but `/v1/states`, `/v1/regions` and `/v1/states/31/crops` returned HTTP 200 without a key on 2026-11-14. No key was used.
- `https://selectorimport.covercrop-data.org/` returned HTTP 526 on 2026-11-14 (not retried further).
- The MCCC tool endpoints are not documented; they were read from `https://covercroptool.midwestcovercrops.org/static/main.bundle.js`.
- Licence: each council's species selection and seeding rate calculator data is released under CC-BY 4.0 per the `attributions` object returned by the API, which also requires attribution with data version and date copied and a record of modifications or exclusions.

## Documentation

- Crop Selector API reference (ReDoc): https://api.covercrop-selector.org/redoc (OpenAPI JSON: https://api.covercrop-selector.org/docs/json)
- Cover Crop Species Selector: https://covercrop-selector.org/
- MCCC selector tools page: https://www.midwestcovercrops.org/selector-tools/
- MCCC Cover Crop Decision Tool: https://covercroptool.midwestcovercrops.org/
- CC BY 4.0: https://creativecommons.org/licenses/by/4.0/
