# SSURGO soils (USDA NRCS Soil Data Access)

The official U.S. soil survey at field scale (1:12,000-1:24,000 maps). For any point it returns the soil map unit, the soil series in it, and lab-grade properties layer by layer down to 2 m. The data is refreshed annually (October).

| | |
|---|---|
| Endpoint | `POST https://sdmdataaccess.sc.egov.usda.gov/Tabular/post.rest` |
| Auth | none |
| Query language | T-SQL against the SSURGO schema, plus spatial helper functions |
| Format | `JSON+COLUMNNAME` (first row is the header) |
| Coverage | United States (STATSGO2 fills the rare unmapped gaps at regional scale) |
| Updates | annually (October refresh) |
| Docs | https://sdmdataaccess.sc.egov.usda.gov/ (schema: "SSURGO Metadata - Tables and Columns") |

## Data model in one paragraph

A **map unit** (`mapunit`, key `mukey`) is a polygon on the soil map. It contains one or more **components** (`component`, key `cokey`), each a soil series with a share of the area (`comppct_r`); `majcompflag = 'Yes'` marks the main ones. Each component has **horizons** (`chorizon`) by depth with physical and chemical properties. `muaggatt` holds map-unit summaries already weighted for you. Values ending in `_r` are representative; `_l`/`_h` are the low/high range.

## Query 1: map unit and components

```sql
SELECT mu.mukey, mu.musym, mu.muname, mu.farmlndcl,
       ma.niccdcd, ma.drclassdcd, ma.hydgrpdcd, ma.aws0100wta, ma.flodfreqdcd,
       c.cokey, c.compname, c.comppct_r, c.taxclname, c.hydgrp, c.drainagecl,
       c.slope_r, c.erocl, c.nirrcapcl, c.irrcapcl, c.tfact, c.wei, c.cropprodindex
FROM SDA_Get_Mukey_from_intersection_with_WktWgs84('point(-97.50 40.95)') k
JOIN mapunit mu  ON mu.mukey = k.mukey
JOIN muaggatt ma ON ma.mukey = mu.mukey
JOIN component c ON c.mukey  = mu.mukey
ORDER BY c.comppct_r DESC
```

Body: `{"query": "<sql>", "format": "JSON+COLUMNNAME"}`. Note WKT order is **lon lat**.

### Sample response (Captured)

```json
{"Table":[
 ["mukey","musym","muname","farmlndcl","niccdcd","drclassdcd","hydgrpdcd","aws0100wta","flodfreqdcd","cokey","compname","comppct_r","taxclname","hydgrp","drainagecl","slope_r","erocl","nirrcapcl","irrcapcl","tfact","wei","cropprodindex"],
 ["2605832","3864","Hastings silt loam, 0 to 1 percent slopes","All areas are prime farmland","1","Well drained","C","19.09","None","29220193","Hastings","85","Fine, smectitic, mesic Udic Argiustolls","C","Well drained","1","Class 1","1","1","5","48",null],
 ["2605832","3864","Hastings silt loam, 0 to 1 percent slopes","All areas are prime farmland","1","Well drained","C","19.09","None","29220191","Crete","5","Fine, smectitic, mesic Pachic Udertic Argiustolls","C","Moderately well drained","1","Class 1","2","2","5","48",null],
 ["2605832","3864","Hastings silt loam, 0 to 1 percent slopes","All areas are prime farmland","1","Well drained","C","19.09","None","29220192","Fillmore","4","Fine, smectitic, mesic Vertic Argialbolls","D","Somewhat poorly drained","0","None - deposition","3","4","3","48",null],
 ["2605832","3864","Hastings silt loam, 0 to 1 percent slopes","All areas are prime farmland","1","Well drained","C","19.09","None","29220190","Butler","4","Fine, smectitic, mesic Vertic Argiaquolls","C/D","Somewhat poorly drained","1","None - deposition","2","2","3","48",null],
 ["2605832","3864","Hastings silt loam, 0 to 1 percent slopes","All areas are prime farmland","1","Well drained","C","19.09","None","29220194","Holder","2","Fine-silty, mixed, superactive, mesic Udic Argiustolls","C","Well drained","0","Class 1","1","1","5","48",null]
]}
```

All values arrive as **strings** (or `null`). `cropprodindex` is null in Nebraska (it is populated in some states only).

Values in this sample: map unit 85% Hastings, well drained, prime farmland, capability class 1 dryland and irrigated, `aws0100wta` 19.09 cm; minor components include Fillmore (4%, somewhat poorly drained, class 3 dryland / 4 irrigated).

## Query 2: horizons of the major components

```sql
SELECT h.hzname, h.hzdept_r, h.hzdepb_r, h.sandtotal_r, h.silttotal_r, h.claytotal_r, h.om_r,
       h.dbthirdbar_r, h.ksat_r, h.awc_r, h.ph1to1h2o_r, h.cec7_r, h.kffact, h.ec_r, h.caco3_r
FROM SDA_Get_Mukey_from_intersection_with_WktWgs84('point(-97.50 40.95)') k
JOIN component c ON c.mukey = k.mukey AND c.majcompflag = 'Yes'
JOIN chorizon h  ON h.cokey = c.cokey
ORDER BY c.comppct_r DESC, h.hzdept_r
```

### Sample response (Captured)

```json
{"Table":[
 ["hzname","hzdept_r","hzdepb_r","sandtotal_r","silttotal_r","claytotal_r","om_r","dbthirdbar_r","ksat_r","awc_r","ph1to1h2o_r","cec7_r","kffact","ec_r","caco3_r"],
 ["Ap","0","16","13","63","24","3","1.4","9","0.23","5.8","20.1",".37","0.1","0"],
 ["A","16","32","10","59","31","2.5","1.35","2.7","0.23","5.9","24.9",".32","0.1","0"],
 ["BA","32","42","8","56","36","1.5","1.35","2.7","0.17","6.3","27.9",".37","0.1","0"],
 ["Bt","42","82","7","55","38","0.75","1.35","2.7","0.17","6.8","28.5",".37","0.1","0"],
 ["Bk","82","99","7","66","27","0.5","1.25","2.7","0.19","7.9","21",".49","0.4","1"],
 ["C","99","200","9","66","25","0.25","1.25","9","0.19","7.8","19.2",".49","0.5","0"]
]}
```

Values in this sample: Ap horizon 0-16 cm with 3% organic matter and pH 5.8; Bt horizon 42-82 cm with 38% clay and ksat 2.7 µm/s; carbonate (`caco3_r` 1) in the Bk horizon from 82 cm.

## Fields

| Column | Unit / values |
|---|---|
| `muname` | text |
| `farmlndcl` | "All areas are prime farmland", "Prime farmland if irrigated", "Not prime farmland" ... |
| `niccdcd` / `nirrcapcl` / `irrcapcl` | 1 (fewest limitations) to 8 |
| `drainagecl` / `drclassdcd` | Excessively ... Very poorly drained |
| `hydgrp` / `hydgrpdcd` | A (sandy, fast infiltration) to D (clay, runoff); dual A/D, B/D, C/D = D when undrained |
| `aws0100wta` | cm |
| `awc_r` (per horizon) | cm/cm |
| `sandtotal_r`, `silttotal_r`, `claytotal_r` | % |
| `om_r` | % |
| `ph1to1h2o_r` | pH |
| `cec7_r` | meq/100 g |
| `dbthirdbar_r` | g/cm³ |
| `ksat_r` | µm/s |
| `kffact` | 0.02-0.69 |
| `tfact` | tons/acre/year |
| `wei` | tons/acre/year |
| `erocl` | None, Class 1-4 |
| `ec_r`, `caco3_r` | dS/m, % |
| `flodfreqdcd` | None, Rare, Occasional, Frequent |
| `taxclname` | text |

## Notes

- The point query picks one map unit; a field often spans 2-4. `SDA_Get_Mukey_from_intersection_with_WktWgs84` also accepts a polygon WKT and returns every intersecting map unit.
- Values are survey estimates, not lab tests of this field.
- Invalid column names return HTTP 400 with no detail (Captured: `farmlndcl` lives on `mapunit`, not `muaggatt`). Test queries in the SDA web query page first.

## Documentation

- Soil Data Access: https://sdmdataaccess.sc.egov.usda.gov/
- SSURGO table and column descriptions: https://www.nrcs.usda.gov/resources/data-and-reports/soil-survey-geographic-database-ssurgo
- Web Soil Survey (interactive viewer of the same data): https://websoilsurvey.nrcs.usda.gov/app/
