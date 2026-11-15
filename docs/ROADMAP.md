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
2. ✅ **A three-season timeline per strategy**, month by month: crop in the ground, bare soil, and the storm, dry, frost and heat bands (`Rotations::Timeline`, `app/rotations/_timeline*`). Bare months under storms, drought or frost are marked as exposed.
3. **Three or more strategies side by side**, with scores per criterion and why, evidence, benefits, gaps and risks. This part exists today.
4. **"Talk this over with your adviser"**: the risks that need local judgment.

## Checkpoint (2026-11-15, end of day)

**In production (aluni.us, auto-deploy from `main`):**
- **Your plan.** Finishing the profile opens the rotation comparison, and a "Your rotation plan" card sits above the home dial. The comparator offers the current rotation plus legume, small-grain, other-family and perennial strategies, with scores, evidence, benefits, gaps, risks and a Gemini "why".
- **Crop data.** FAO-56 water need for 20 of 27 crops, with southern-hemisphere seasons. FAO ECOCROP requirements for 25 of 27 (tomato and cabbage pending: ECOCROP uses older names).
- **The profile's priorities in the comparator.** Conservation practices, cautious risk tolerance, contract or export sales.
- **"Your field from space".** Monthly NDVI over the last year from **Landsat (NASA/USGS)** and Sentinel-2 through Planetary Computer, with bare-soil windows and the cover-crop opportunity, on the field and on the plan.
- **Data sources.** NASA POWER climate and season, GAEZ suitability, the landing field finder (Nominatim), and SSURGO, 3DEP and CDL in the US.
- **Gemini on Vertex AI.** No key, trial credits, a 2000-request daily cap that pauses itself.
- **Field station catalogue** (`/devices`) with a 3D product viewer (`docs/DEVICES.md`).

**Rate limit (fixed):** Planetary Computer rate-limits bursts (429). The client now asks 2 months at a time, retries 429/5xx with exponential backoff and jitter (about 2, 4, 8, 16 s, or `Retry-After`), and stops the other months once one fails. A rate-limited field reruns only the NDVI later (15, 30, 45 min plus jitter, 3 times).

**Still missing:**
- **NASA breadth.** Done: POWER, Landsat, NASADEM (SRTM), GPM IMERG, SMAP. Missing from the challenge list: ECOSTRESS, MODIS, GRACE.
- **Alerts on the phone.** The daily alerts run and show in the app; push and email go out once the `cron`, `push` and `mail` switches are resumed and the shells ship.
- **Global soil.** Outside the US it depends on the farmer (the slope now comes from NASADEM).

## P0: the demo tells the whole story

| | Item | Status |
|---|---|---|
| P0.1 | Gemini on (Vertex, daily cap 2000) | ✅ |
| P0.2 | Finishing the profile opens **Your plan**; a "Your rotation plan" card sits above the home dial | ✅ #21 |
| P0.3 | Water need for 20 of 27 catalog crops (FAO-56 Tables 11/12), with seasons flipped south of 15°S | ✅ #21 |
| P0.3b | ECOCROP requirements (`config/ecocrop.yml`, 25 of 27; the task reads the Latin-1 CSV and maps older names) | ✅ #21; tomato and cabbage pending |
| P0.4 | Use the profile's priorities: conservation practices count as the soil health goal; a cautious farmer sees "new crop" risks; contract or export sales see "check your buyer" | ✅ #21 |
| P0.5 | Cover crops: the timeline marks every bare window of two months or more and proposes a cover from the catalog by its weather (rye where it freezes, oats when cool, cowpea when warm; dry windows flagged), with the exposed months it saves (the first month still counts); the comparator cites the field's past cover crops (`role: cover`). Second crops (`role: second`) still wait | ✅ cover crops; second crops ⏳ |
| P0.6 | Use irrigation water source and soil depth, salinity and drainage in the water and fit scores | ⏳ |

## P1: NASA depth (each item checks one dataset off the challenge list)

Suggested next order: MODIS and ECOSTRESS (same AppEEARS task path as SMAP), then GRACE.

| Item | Dataset | How |
|---|---|---|
| ✅ Crop health and **bare-field periods** | Landsat (NASA/USGS) + Sentinel-2 NDVI | Done (#22): `monthly_ndvi`, the `vegetation` observation, `Fields::Vegetation`, "Your field from space". Next: compare the observed bare months with the timeline's current rotation. |
| Long-term vegetation baseline and anomalies | MODIS NDVI (16-day, 20+ years) | AppEEARS or Planetary Computer |
| ✅ **Global slope** for erosion | NASADEM (SRTM) | Done: `PlanetaryComputer::Client#terrain`, the `nasadem` observation; 3DEP first in the US, NASADEM everywhere else (56°S to 60°N) in the profile and the comparator. |
| ✅ Extreme rain frequency | GPM IMERG | Done: 20 years of daily IMERG through NASA POWER (`IMERG_PRECTOT`, no account), `Weather::RainExtremes`, the `gpm_imerg` observation; storm-prone months and 50 mm days raise the erosion of row crops in the comparator. The stormy months are on the 3-season timeline. |
| ✅ Soil moisture and anomalies | SMAP L4 | Done: `Appeears::Client` (submit, poll, results CSV), `Fields::FetchSoilMoistureJob` (the `smap` observation stays `pending` while AppEEARS works), `Weather::SoilMoisture`; the plan cites dry months and warns a rainfed field. |
| Long-term water trend | GRACE / GRACE-FO | One trend indicator per region |
| Heat stress and evaporation | ECOSTRESS | AppEEARS |
| Global soil | SoilGrids (ISRIC) | REST point query; fills texture and pH outside SSURGO |

## P2: a reason to come back

- ✅ **Forecast:** seven days of Meteomatics on the weather screen (`Weather::Forecast`, lazy `forecast` frame): local solar days, frost (air or soil at 5 cm), heat, heavy rain and wind alerts with what to do, and the week's rain-minus-evapotranspiration balance.
- ✅ **Daily alerts job:** `Weather::DailyAlertsJob` (cron 10:00 UTC) checks today and tomorrow at each located field and sends the kinds each farmer chose (frost, heat, heavy rain; a dry spell when the next six days bring almost no rain) through `NotificationRouter` (purpose `weather_alert`, one per field, day and kind). The alerts screen lists the last two weeks from the deliveries, sent or shown here only.
- ✅ **Refresh** (`Fields::RefreshObservationsJob`, sidekiq-cron): weekly, the season so far (POWER) and the NDVI for fields fetched over 6 days ago, 3 minutes apart; monthly, every source including AppEEARS for fields with month-old data, 10 minutes apart. Runs once the `cron` switch is resumed.

## P3: the wow

- **Scenario sliders** (+2 °C, −20 % rain) that recompute water need and frost for each strategy.
- **NDVI overlay** on the field map (Planetary Computer tiles).
- **Glossary and uncertainty** (evapotranspiration, NDVI, anomalies), and satellite next to ground readings (the field station, `docs/DEVICES.md`).

## Demo checklist

- [ ] Gemini resumed, `geocoding` resumed (Platform switch `status`)
- [x] A sample farm in English and one in Spanish with a crop history, so Your plan has three strategies with evidence. Sign up a **dedicated demo account** with a passkey (nothing signs in for you), then load a preset from `config/demo_farms.yml` into it:
  ```
  bin/rails demo:farm USER_ID=<id> PRESET=nebraska   # English: York, Nebraska, rainfed corn and soybeans, mechanized
  bin/rails demo:farm USER_ID=<id> PRESET=chile      # Spanish: Buin, canal-irrigated maize and wheat, cautious, sells under contract
  ```
  In production: `kamal app exec --reuse --roles=web 'bin/rails demo:farm USER_ID=.. PRESET=..'`. It refuses an account with other farms (`FORCE=1` overrides), replaces only its own sample farm when run again, and waits for the worker to fetch the data at the pin (about a minute; SMAP arrives later).
- [ ] Disk snapshot of the VM before the demo (`docs/deploy/DEPLOY.md`)
- [ ] Script: landing pin → profile chat → Your plan → one strategy's why, evidence and risks → the timeline → the field station catalogue
