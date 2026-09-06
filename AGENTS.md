# Nimbo API documentation

This is `ecaresoft/nimbo-api-docs`, the public developer site built with Mintlify.
The separate `ecaresoft/nimbo-docs` repository is the end-user help center.
Reuse its approved Nimbo brand assets, not its analytics identifiers, canonical
URL, navigation, or product guides.

- Read `README.md`, `docs.json`, and the installed Mintlify skill before edits.
- Canonical replacement API contracts belong in `ecaresoft/nimbo-api`.
- Never hand-edit `openapi/nimbo_public.yml`; import a committed public artifact
  with `scripts/sync-api.rb` and commit its provenance lock.
- Never copy `openapi.internal.yaml` into this public repository. Hidden pages
  and `.mintignore` are not authorization boundaries.
- Keep the preview label and reference-only playground until the published
  operations, host, fidelity, and runtime availability have been reviewed.
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
