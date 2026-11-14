---
name: verify
description: Verify that a code change actually does what it's supposed to by running the app and observing behavior. Use when asked to verify a PR, confirm a fix works, test a change manually, check that a feature works, or validate local changes before pushing.
---

# Verify (Aluni project rules)

This project uses **importmap-rails** and has zero npm tooling. That means:

- **Never use Playwright, Puppeteer, npx, npm, or any node_modules tool for verification.**
- **Never run `node`, `npx`, or any JS runtime outside of the Rails asset pipeline.**

Violating this is a hard stop, not a judgment call. The one scripted browser in the project is Cuprite (headless Chrome) inside `spec/system`, driven by RSpec.

## Allowed verification surfaces

### Server / Rails
- `curl` for HTTP responses and redirects (add `-A "Aluni Hotwire Native iOS"` to reach the native-only pages, or run with `NATIVE_WEB_ACCESS=1`)
- `mise exec -- bundle exec rails runner "..."` for in-process checks
- `mise exec -- bundle exec rspec spec/...` for request specs (they must render the page, not just assert a redirect)
- `mise exec -- bundle exec rspec spec/system` for Cuprite system specs

### Browser
Passkey ceremonies cannot be scripted. If browser or device confirmation is needed:
1. Confirm the server returns 200 and the right HTML via `curl -s http://localhost:3000/path | grep "expected text"`
2. State clearly: **"Visual confirmation requires opening the browser manually at `<url>`"** (or the simulator/emulator).
3. Do not attempt to automate it with any npm-based tool.

### API / webhooks
- `curl` with the appropriate headers (`X-Aluni-Native: 1` for API writes) and JSON body.

## Report format

```
## Verification: <one-line what changed>

**Verdict:** PASS | FAIL | BLOCKED

**Method:** curl / rails runner / rspec

### Steps
1. ✅/❌ <what you did> → <what you observed>
   <raw output>

### Findings
<anything surprising, broken adjacent to the change, or worth noting>
```

**PASS** = you ran the app and it did what it should.
**FAIL** = you ran it and it doesn't, or something adjacent broke.
**BLOCKED** = couldn't reach a runnable state (say exactly where it stopped).
