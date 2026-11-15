# Roadmap

Where the app goes after the profile, aimed at the NASA Space Apps 2026 challenge **"Adapting Farms with NASA Data"**. The challenge asks for a decision-support tool that:

- uses NASA Earth observations, local soil, crop traits and farmer priorities to explore crop rotations;
- compares at least three strategies, including the current one;
- explains, for each strategy, why it was suggested, the evidence behind it, its benefits, the information gaps and the risks that need local review;
- shows bare-field periods and vulnerable seasons;
- stays readable for farmers and supports their judgment, never replaces it.

## The product loop

```
1. DISCOVER     Landing finder: drop a pin → the place's climate (NASA POWER) before signing up
2. PROFILE      Ask Aluni chat: priorities, soil, history, resources
3. ★ YOUR PLAN   The payoff, opened as soon as the profile is done
4. FOLLOW       During the season: forecast, alerts, crop health from satellites (later the field station)
5. CLOSE        What was planted and how it went → next season's plan recomputes
```

**Your plan** is the screen the demo is built around (`/app/fields/:id/rotation`, `Rotations::Comparator`):

1. **Your field from space.** 20-year climate, soil, slope, NDVI and bare periods, each value labelled with the dataset that measured it.
2. **A three-season timeline per strategy**, month by month: crop in the ground, bare soil, and the frost, heat and dry-spell bands.
3. **Three or more strategies side by side**, with scores per criterion and why, evidence, benefits, gaps and risks. This part exists today.
4. **"Talk this over with your adviser"**: the risks that need local judgment.

## Where we are (2026-11-15)

**Done:**
- The comparator: the current rotation plus legume, small-grain, other-family and perennial strategies, scored on fit, pest break, soil health, nitrogen, water, erosion and workload, weighted by goals, with benefits, evidence, gaps and risks, and a Gemini "why".
- Screens for fields, crops, rotation, calendar, weather (past season), reports and export.
- NASA POWER climate and season.
- GAEZ suitability.
- SSURGO, 3DEP and CDL (US only).

**Missing:**
- **NASA breadth.** Only POWER, plus GIBS as a picture. The challenge lists SMAP, ECOSTRESS, GPM, Landsat/MODIS, GRACE and SRTM.
- **Bare-field periods.** Nothing detects them.
- **A real forecast.** The forecast option shows the past season.
- **Alerts.** None are sent.
- **Global soil and slope.** Outside the US they depend on the farmer.

## P0: the demo tells the whole story

| | Item | Status |
|---|---|---|
| P0.1 | Gemini on (Vertex, daily cap 2000) | ✅ |
| P0.2 | Finishing the profile opens **Your plan**; a "Your rotation plan" card sits above the home dial | ✅ `feature/p0-tu-plan` |
| P0.3 | Water need for 20 of 27 catalog crops (FAO-56 Tables 11/12), with seasons flipped south of 15°S | ✅ `feature/p0-tu-plan` |
| P0.3b | ECOCROP requirements: run `rake ecocrop:extract` with the OpenCLIM CSV and commit `config/ecocrop.yml` | ⏳ needs the CSV download |
| P0.4 | Use the profile's priorities: conservation practices count as the soil health goal; a cautious farmer sees "new crop" risks; contract or export sales see "check your buyer" | ✅ `feature/p0-tu-plan` |
| P0.5 | Count second and cover crops (today the comparator and calendar read only `role: main`) | ⏳ |
| P0.6 | Use irrigation water source and soil depth, salinity and drainage in the water and fit scores | ⏳ |

## P1: NASA depth (each item checks one dataset off the challenge list)

| Item | Dataset | How |
|---|---|---|
| Crop health and **bare-field periods** | Sentinel-2 / Landsat NDVI | `PlanetaryComputer::Client#ndvi` exists. Store a FieldObservation and draw it on the timeline. |
| Long-term vegetation baseline and anomalies | MODIS NDVI (16-day, 20+ years) | AppEEARS or Planetary Computer |
| **Global slope** for erosion | SRTM / NASADEM | Planetary Computer point value; replaces US-only 3DEP outside the US |
| Extreme rain frequency | GPM IMERG | Earthdata credentials already in credentials |
| Soil moisture and anomalies | SMAP L3/L4 | AppEEARS async request (Earthdata) |
| Long-term water trend | GRACE / GRACE-FO | One trend indicator per region |
| Heat stress and evaporation | ECOSTRESS | AppEEARS |
| Global soil | SoilGrids (ISRIC) | REST point query; fills texture and pH outside SSURGO |

## P2: a reason to come back

- **Forecast:** `Meteomatics::Client#forecast` on the weather screen (72 h, field pin, cached per hour).
- **Daily alerts job:** frost, heavy rain, dry spell and heat per field from the forecast, shown in the app (push when the shells ship). Purposes go in `config/notification_purposes.yml`.
- **Weekly refresh** of each field's observations (sidekiq-cron); today only a pin change refreshes them.

## P3: the wow

- **Scenario sliders** (+2 °C, −20 % rain) that recompute water need and frost for each strategy.
- **NDVI overlay** on the field map (Planetary Computer tiles).
- **Glossary and uncertainty** (evapotranspiration, NDVI, anomalies), and satellite next to ground readings (the field station, `docs/DEVICES.md`).

## Demo checklist

- [ ] Gemini resumed, `geocoding` resumed (Platform switch `status`)
- [ ] A seeded farm in English and one in Spanish with a crop history, so Your plan has three strategies with evidence
- [ ] Disk snapshot of the VM before the demo (`docs/deploy/DEPLOY.md`)
- [ ] Script: landing pin → profile chat → Your plan → one strategy's why, evidence and risks → the timeline → the field station catalogue
