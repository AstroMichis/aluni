# Demo script

A starting point for the team to rehearse and change. About 6 minutes, on https://aluni.us, phone width or a narrow browser window. The story is the challenge's own: compare at least three rotation strategies with NASA data, explain each, show the bare and vulnerable seasons, and support the farmer's judgment without replacing it.

## Before the demo (start 3 hours ahead)

AppEEARS runs one task at a time per account, so a new field's SMAP, MODIS and ECOSTRESS can take an hour or two to arrive.

1. **Demo account.** Sign up on aluni.us with a passkey on the presenting device (for example "Demo Aluni"). Load a sample farm into it, in production:
   ```
   kamal app exec --reuse --roles=web 'bin/rails demo:farm USER_ID=<id> PRESET=chile'      # Spanish: Buin, canal irrigation
   kamal app exec --reuse --roles=web 'bin/rails demo:farm USER_ID=<id> PRESET=nebraska'   # English: York, rainfed
   ```
   One account holds one sample farm; use two accounts (two passkeys) to show both languages.
2. **Check the data arrived.** Field page → "Data for this pin": every source "Ready", none "Requested from NASA" or "Could not be reached". "Refresh data" asks again.
3. **Switches** (Actions → Platform switch → `status`): `gemini` and `geocoding` resumed. `cron`, `mail` and `push` may stay paused: alerts still show on the alerts screen.
4. **Snapshot** of the VM disk (`docs/deploy/DEPLOY.md`, "Snapshot before a demo"). The last one: `aluni-vm-2026-11-15`.
5. **Fallbacks.** Screenshots of each step below in case the network fails. Without Gemini the plan shows the rule-based "why"; nothing else depends on it.

## The script

| # | Screen | Show | Say (the point) |
|---|---|---|---|
| 1 | Landing, field finder | Drop the pin on Buin (or York) | One pin is all a farmer needs to give: the satellites already know this place. |
| 2 | Profile (Aluni's chat) | The finished profile: cautious, sells under contract, canal irrigation | We ask only what the pin cannot tell: goals, risk, how they sell. Those priorities weigh the comparison. |
| 3 | **Your plan** (field → rotation) | The current rotation and at least two alternatives, scores per criterion, the best one highlighted | Three or more strategies side by side, the current one as the baseline. |
| 4 | One strategy | Its "why", evidence (each line names its NASA dataset), benefits, gaps, risks | Every number says where it comes from. What we do not know is said too ("gaps"). |
| 5 | Evidence, Chile preset | GRACE: the region's water store about 20 cm below 2004-2009 (the megadrought); risk for canal irrigation. SMAP root-zone moisture; ECOSTRESS water stress; IMERG heavy-rain days; NASADEM slope | NASA's view of water from orbit, at five scales, turned into one sentence each a farmer can act on. |
| 6 | Your field from space | Monthly NDVI (Landsat and Sentinel-2) with MODIS's 20-year normal as a tick on each month; the bare window | This year against the field's own normal, and the months the soil was bare. |
| 7 | **Three-season timeline** | Weather strip (storms, dry, frost, heat), then each strategy's months: crop, bare, bare and exposed | The vulnerable seasons the challenge asks for: bare soil under storms or drought. Compare how many exposed months each strategy leaves. |
| 8 | Risks to check locally | "Check with your buyer", "try a new crop on part of a field", water rights | It supports the farmer's judgment and the local adviser; it does not decide for them. |
| 9 | Weather | Seven-day forecast with what to do; the alerts screen and its recent alerts | The plan carries into the season: frost, heat, heavy rain and dry spells, each with an action. |
| 10 | `/devices` | The field station in 3D | Next: ground readings next to the satellite ones. |

**Close:** the NASA data behind it: POWER (climate), Landsat (vegetation), NASADEM/SRTM (slope), GPM IMERG (extreme rain), SMAP (soil moisture), MODIS (vegetation normal), ECOSTRESS (water stress), GRACE (water storage).

## If something goes wrong

- **A source says "Requested from NASA"**: it is on its way (AppEEARS); show another strategy's evidence and come back.
- **Gemini is slow or paused**: the "why" falls back to the rule-based sentence by itself.
- **The site is down**: restore the snapshot (`docs/deploy/DEPLOY.md`, "If the VM is lost") after the demo; present from the screenshots.
