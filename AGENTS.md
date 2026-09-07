# Nimbo API documentation

This is `ecaresoft/nimbo-api-docs`, the public developer site built with Mintlify.
The separate `ecaresoft/nimbo-docs` repository is the end-user help center.
Reuse its approved Nimbo brand assets, not its analytics identifiers, canonical
URL, navigation, or product guides.

- Read `README.md`, `docs.json`, and the installed Mintlify skill before edits.
- Canonical replacement API contracts belong in `ecaresoft/nimbo-api`.
- Never hand-edit rendered files under `openapi/`. Inputs live under
  `scripts/contracts/`; import a committed public artifact with `scripts/sync-api.rb`.
  Keep revision evidence and publication decisions in `scripts/reference-policy.json`.
- Never copy `openapi.internal.yaml` into this public repository. Hidden pages
  and `.mintignore` are not authorization boundaries.
- Present one API reference organized by functionality. Do not expose backend
  migration status as product versions or ask readers to choose a backend.
- Publish generated operations only after reviewing their contract and recorded
  availability. Retain the existing definition when replacement evidence is
  incomplete. A new source revision requires a publication-policy review.
- Keep the reference-only playground until the integration host is reviewed.
- Preserve legacy coverage. Changes to `scripts/legacy-inventory.json` require
  an explicit explanation of additions, removals, or equivalent duplicates.
- Use synthetic examples only. Do not restore captured record IDs, headers,
  tokens, patient data, or tenant data from the historical imported specs.
- Write concise developer-facing English with title, sidebarTitle when useful,
  and description frontmatter. Add new pages to navigation.
- Run `npm test`, `npm run validate`, and `npm run links`. Visually check the
  landing page and at least one generated endpoint in light and dark mode.
- A merge to the Mintlify-connected branch can publish the site. Keep code
  review, merging, and verified hosted deployment as separate reported facts.
