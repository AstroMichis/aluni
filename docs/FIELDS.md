# The menu sections (My fields, My crops, Weather, My team, Reports)

After the onboarding chat, `/app` is the menu dial (`App::HomeController`, layout `app_screen`). Each section reads and writes the person's own farm: the onboarding models (`FarmerProfile`, `Farm`, `Field`, `FieldCrop`, `docs/ONBOARDING.md`) and what the public data sources returned for each field's pin (`FieldObservation`). There is no sample data.

## Screens

| Path | What it does |
|---|---|
| `/app` | The dial; "Add a new field"; account menu (language, theme, the chat, passkeys, sign out) |
| `/app/fields`, `/app/fields/:id` | Fields with progress; a field, read only: plot, GIBS view, source suggestions ("Confirm all"), what is left, crop history, data by group, data-source status and "Refresh data" |
| `/app/fields/:id/edit`, `PATCH /app/fields/:id`, `POST /app/fields/:id/confirm` | One form for every answer of the field, each source suggestion beside its field with a box to take it; "Confirm all" takes every suggestion |
| `/app/farm`, `/app/farm/edit` | The profile (segment, team, budget, goals) and farm data, and one form to edit them |
| `/app/fields/sources` | Every datum with origin, sources per layer and status, gaps |
| `/app/fields/new` | Add a field: pin (geolocate or coordinates), name, area, watering, crop, past seasons, review |
| `/app/crops` (`/rotation`, `/calendar`) | Crop per field with GAEZ suitability, attainable yield and ECOCROP fit; seasons, plan for next year, rotation checks, "what grows well here"; planting to harvest against the frost-free stretch |
| `/app/weather` (`/alerts`) | Season so far and 30-year normals at a field's pin (NASA POWER); alerts kept in `FarmerProfile#notification_preferences["weather"]` |
| `/app/team` | The profile's role, team, team size, tenure, budget, equipment, livestock, practices; "Edit" opens the farm form |
| `/app/reports` (`/harvest`, `/export`) | Season summary (prints clean), GAEZ attainable harvest per field, CSV and JSON export |

Forms redirect to the page they belong to and Turbo morphs it (`shared/_screen_bar`).

## Only the essentials are asked

Five answers drive the comparison and are the only ones the to-do list and progress count (`essential: true` in the registry): the field's pin, its watering, this season's crop, the seasons before (proposed by the US crop map) and up to three goals. Every other answer sits under "More details (optional)" in the edit forms; the data sources and the onboarding chat fill most of it.

## Rotation comparison

`/app/fields/:id/rotation` (`App::RotationsController`, `Rotations::Comparator`) compares the current rotation with at least two alternatives over the next three seasons: bring in a legume (when the rotation has none), add a small grain, change crop family, rest with perennial forage (with animals or a soil-health goal). Seven criteria score each strategy 0-100: crop fit (FAO GAEZ suitability at the pin), pest break (`Crops::RotationCheck`; a perennial stand counts once), soil health, nitrogen (legume seasons), water (how much of the crops' need the usual rain covers), erosion (row crops on the USGS slope) and workload (distinct crops, a combine for small grains). The farmer's goals weigh their criteria three times. Each strategy carries why, evidence with its source, benefits against the current rotation, gaps (always market prices) and risks to check locally. `Rotations::NarrateService` lets Gemini write the "why" in two sentences from those facts only, cached, in a lazy Turbo frame; without Gemini the rule text stays. "Use as plan" saves the strategy's first crop as next season (`Crops::PlanService`).

## Water per crop

`Crops::WaterNeed` sets a crop's season need (FAO-56 single Kc curve) against the usual rain at the pin: `Weather::Et0` computes the monthly FAO-56 Penman-Monteith reference ET from NASA POWER normals (T2M, RH2M, WS2M, ALLSKY_SFC_SW_DWN, the cell elevation), effective rain follows the FAO/CROPWAT formula. Coefficients exist only where `docs/data_sources/fao56_crop_coefficients.md` captured them (corn and soybeans, `fao56` in `config/crops/agronomy.yml`); other crops show the water need as a gap. It ignores water stored in the soil, so the comparison uses it relatively and the dry risk only fires when season rain is under half the need.

## Data from the pin

`Fields::FetchObservationsJob(field_id)` runs when a pin is set or moved (`Field#after_commit`) and on "Refresh data". It stores one `FieldObservation` per source (status ok, empty, out_of_coverage, failed):

| Source | Client | Coverage | Feeds |
|---|---|---|---|
| `fcc` | `Fcc::Client` | US | US layer on or off; `Farm#country_code`/`admin_area` |
| `nasa_power` | `NasaPower::Client` | global, ~50 km | daily season (T2M, min, max, rain, root-zone wetness) and climatology (incl. FROST_DAYS) |
| `gaez` | `Gaez::Client` | global, ~9 km | suitability and attainable yield, rainfed, input level from the profile (budget high or mechanized segment = High) |
| `ssurgo` | `Ssurgo::Client` | US | map unit, drainage, topsoil sand, clay, organic matter, water capacity, pH |
| `usgs_elevation` | `Usgs::ElevationClient` | US | elevation, slope |
| `vegetation` | `PlanetaryComputer::Client#monthly_ndvi` | global, 10 to 30 m | one clear-sky NDVI per month over the last year (Landsat, Sentinel-2); bare periods (`Fields::Vegetation`) |
| `nasadem` | `PlanetaryComputer::Client#terrain` | 56°S to 60°N, 30 m | elevation, slope (90 m neighbours); the slope where 3DEP has none |
| `smap` | `Appeears::Client` + `Fields::FetchSoilMoistureJob` + `Weather::SoilMoisture` | global, 9 km, asynchronous | root-zone soil moisture and its percentile per month over the last year; dry and wet months; `pending` while AppEEARS works (minutes) |
| `gpm_imerg` | `NasaPower::Client#imerg_daily` + `Weather::RainExtremes` | global, ~10 km | 20 years of daily rain: 25 and 50 mm days per year and month, wettest day, dry spells; erosion and risks |
| `cdl` | `Cdl::Client` | US | crop per year for the last five years |

All clients share `DataSources::Client` (Faraday, retries, timeouts, `Platform::Switchboard.guard!(:data)`). The GIBS picture is a URL (`Onboarding::AreaImage`), loaded by the browser. Not connected yet (next phase, `status: planned` in the registry): AppEEARS products (MODIS phenology, SMAP), OpenET, FAO-56. Gaps: SoilGrids and a global reverse geocoder.

ECOCROP requirements live in `config/ecocrop.yml`, extracted once from the OpenCLIM CSV with `bin/rails ecocrop:extract CSV=path` (`lib/tasks/ecocrop.rake`); until it exists the fit shows as pending. `config/crops/agronomy.yml` maps each crop (keyed like `FieldCrop#crop_key`) to aliases, family, plant shape and its GAEZ name.

## The registry: `config/field_profile.yml`

Per datum: `column` (where the answer lives: `profile.*`, `farm.*`, `field.*`, `field.soil.*`, `field.location`, `crops.current[.attr]`, `crops.history`), `observation` (paths in a `FieldObservation` payload), `origin` per layer (ask, auto, confirm), `propose` (how a source value becomes the answer: `texture_class`, `drainage_class`, `number`, `cdl_history`), sources and feeds. Answer options come from `Onboarding::Allowlist`, so the chat and the menu share one vocabulary; labels are `onboarding.values.*`.

## Reading and writing

`Fields::Farm.for(user)` builds the view (`Root` for the farm and profile, `Field` per field). States: answered, unanswered, auto, to_confirm, confirmed, pending, failed, needs_pin, gap. `Fields::SaveService` saves a whole edit form in one transaction through `Onboarding::Allowlist.filter`: blank answers stay as they are, a list sent empty is emptied, only what changed is written, and a ticked suggestion is saved as the farmer's own (SSURGO sand/clay as a texture class, CDL years as `FieldCrop` rows with `source: cdl`); what the farmer typed wins over a ticked suggestion. `Fields::CreateFieldService` adds fields; `Crops::PlanService` keeps next season as a `FieldCrop` for next year; `Weather::AlertsService` the alert choices.

## Pending

Own yields need a column (Reports shows GAEZ's attainable yield meanwhile); team members and tasks need their own models; the forecast has no documented source.
