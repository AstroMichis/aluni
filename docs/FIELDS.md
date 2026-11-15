# The menu sections (My fields, My crops, Weather, My team, Reports)

The farm, its fields, the add-a-field conversation and where each datum comes from. A working web preview under `/menu/fields`: the person's answers are used everywhere but kept only in their session, nothing in the database. The sample farm shows until they add a field of their own.

## Screens

| Path | What it does |
|---|---|
| `GET /menu/fields` | Tab "Fields": every field as an illustrated plot with its progress, Aluni's greeting with what is waiting, add a field |
| `GET /menu/fields/farm` | Tab "My farm": profile (classification), what is left, the farm data by group, editable |
| `GET /menu/fields/sources` | Tab "Sources": every datum with its origin, sources per layer, scale, confidence, use; the gaps |
| `GET /menu/fields/:id` | One field: the plot (empty with a pin and a crop picker, or the crop growing), Aluni's tip, what is left (links to each card), section chips that follow the scroll, history, data by group, editable |
| `GET /menu/fields/new`, `POST /menu/fields` | The add-a-field conversation as one form: one question per screen, a live plot for the crop, ranked goals, a review step, then the field is created and opened. Farm steps already answered are skipped |
| `PATCH /menu/fields/:subject/readings/:datum` | Confirm (`confirm=1`), answer or correct one datum of `farm` or a field |
| `DELETE /menu/fields/preview` | Start over: back to the sample farm |

Every form redirects back to its page and Turbo morphs it (`turbo_refreshes_with method: :morph, scroll: :preserve` in `fields/_bar`): the card, the plot, the progress and the to-do list update together and the scroll stays put. A new crop gives the plot a new id, so it grows in again.

## Pieces

| File | Role |
|---|---|
| `config/field_profile.yml` | The registry: every datum (origin per layer, sources, snapshot paths, options, feeds) and the onboarding steps. Validated by `Fields::Profile` |
| `app/services/fields/farm.rb` | `Fields::Farm.build(data)`: the farm and its fields from one data shape, `reading(datum)`, `todo`, `progress`, `classification`, `needs?(step)` |
| `app/services/fields/draft.rb` | Where the data shape is kept: the session today. Without a draft, the sample (`config/samples/farm.yml`) |
| `app/services/fields/answer_service.rb` | Validates and applies one confirmation, answer or correction; returns the new data |
| `app/services/fields/add_field_service.rb` | Turns the conversation's answers into a field (and the farm, the first time); returns the new data and the field key |
| `FieldsController`, `FieldReadingsController` | Thin: draft in, service, draft out, redirect |

### The data shape

```ruby
{ "sample" => true | nil,
  "answers" => { datum_key => value },          # farm: what the person said or corrected
  "confirmed" => [datum_key],                   # farm: inferred values they agreed with
  "fields" => { key => { "answers" => {}, "confirmed" => [], "snapshot" => bool } } }
```

### When the profile model arrives

Replace `Fields::Draft` with a class that reads and writes the farm and field tables in this shape (or have the models expose it), and point the controllers at it. The services, `Fields::Farm`, the views and the specs stay as they are. `answers` maps to the profile columns (or a `jsonb`), `confirmed` to a list per farm and field, `snapshot` to the stored snapshot of each field.

## Reading states

`answered`, `unanswered` (asked data); `auto`, `to_confirm`, `confirmed`, `corrected` (inferred data; a correction is the person's value and wins); `pending` (a documented source, not connected yet); `gap` (no documented source: the person is asked, and their answer counts as `answered`). The to-do list holds `to_confirm`, `unanswered` and `gap`, except optional data. Progress counts what the person can settle (asked, confirm-origin and gap data that are not optional).

## The snapshot contract (for the data work)

The screens read the JSON that `farm_data.py` writes (`farm_data_<lat>_<lon>.json`): `location`, `period`, `climate_summary.*` and `site_attributes.*` (including `crop_<year>`). To light up a datum:

1. Produce its value under a stable path in the snapshot.
2. Add `snapshot:` (name => path) and `snapshot_source:` to the datum in the registry. A path ending in `*` collects every key with that prefix (`site_attributes.crop_*`).
3. If the value has several parts, add `fields.data.<key>.value` in both locales (`%{name}` per part).

`spec/services/fields/profile_spec.rb` fails when a registry path is missing from the sample snapshot or when copy is missing.

The preview has one snapshot, so every farm sits at its point (near Ames, Iowa, said on the location step) and only the first field gets parcel data; later fields show what will arrive. `climate_summary` covers the snapshot's `period` (a season so far), not 30-year normals; `climate_normals` and `frost_window` wait for the POWER climatology endpoint.

## Classification

`Farm#classification`: size from the total area (small under 2 ha, medium 2 to 50 ha, large above; thresholds still to validate per country), water access, fertilizer level, the first goal, and the level of detail. Labels reuse the asked data's option labels.

## Known gaps

No documented source yet for: global soil (SoilGrids), drainage outside the US, global reverse geocoding (country and region), and a base map for the pin and outline steps (they show a placeholder). Crop history outside the US, markets, machinery and water access are asked.

## Sections 2 to 5

They run on the same farm preview (`FarmPreview` concern: the draft in, a service, the draft out, a redirect that Turbo morphs) and the same shell (`shared/_screen_bar` with `ScreenHelper::SECTION_TABS`). The menu dial links every option (`MenuHelper::OPTION_PATHS`).

| Section | Screens | Data |
|---|---|---|
| My crops `/menu/crops` | Now (each field's crop, family, season, tip), Rotation (seasons, next-season plan, basic checks, readiness to compare strategies), Calendar (planting to harvest against the frost-free stretch) | `config/crops.yml` (family and plant shape; ECOCROP later), `Crops::RotationCheck` (same family twice, same crop three times, no legume in four seasons), `Crops::PlanService` |
| Weather `/menu/weather` | This season (headline numbers, daily temperature, weekly rain, root-zone moisture, a monthly table, the forecast gap), Alerts (which kinds to receive, the frost-free stretch, what this season would have sent) | `Weather::Season` reads the daily NASA POWER rows of the CSV `farm_data.py` writes (`series:` in the sample) and matches its summary; `Weather::AlertsService` |
| My team `/menu/staff` | Team (members, role, fields), Tasks (add, complete, remove, overdue), Roles (what each role can do) | `Staff::Roles`, `Staff::SaveMemberService`, `RemoveMemberService`, `SaveTaskService`, `RemoveTaskService` |
| Reports `/menu/reports` | Season (area by crop, weather, field by field, team; prints clean), Harvest (yield per field, compared within a crop), Export (CSV and JSON downloads) | `Reports::Export`; yield is the field datum `yield` |

Honest gaps shown on screen: no forecast source, no county yields without a NASS key (US only), the rotation comparison waits for the engine (the screen shows what each strategy will carry: why, evidence, benefits, gaps, risks).
