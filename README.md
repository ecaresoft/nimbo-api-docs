# Nimbo API documentation

Public developer documentation for Nimbo, rendered by Mintlify.
Repository: `ecaresoft/nimbo-api-docs` (formerly `ecaresoft/documentation`).
The separate `ecaresoft/nimbo-docs` project remains the user help center at
https://help.nimbo-x.com.

## Develop and validate

Use Node.js 24 and Ruby 3.3+ (Ruby 4.x is also supported).

```sh
npm ci
npm test
npm run validate
npm run links
npm run dev
```

Ruby 3.3 includes Minitest; on Ruby 4 use an installed Minitest gem. Ruby scripts
need no Rails app, database, production credentials, or external services.

## Update the public contract

In `nimbo-api`, run `bin/openapi`, validate, and commit its source and generated
artifacts. Only `docs/api/generated/openapi.public.yaml` may cross into this
public repository. Then, from this repository:

```sh
ruby scripts/sync-api.rb --source /path/to/nimbo-api --revision FULL_COMMIT_SHA
npm test
npm run validate
npm run links
ruby scripts/sync-api.rb --source /path/to/nimbo-api --revision FULL_COMMIT_SHA --check
```

Review `scripts/reference-policy.json` for the selected revision before syncing.
Open a documentation PR containing the input, rendered specs, and provenance lock.
Review the operation inventory, contract diff, source SHA, and preview. Merge
only the reviewed snapshot. This explicit local handoff works with a private
API repository without granting this public repo a cross-repository token.

The import is deterministic, reads a committed artifact instead of dirty files,
and records its source revision and digest. CI checks the artifact digest,
public operation inventory, excluded metadata, and legacy coverage offline.
There is no scheduled sync or automatic tracking of API `main`.

## Reference policy

Readers see one API reference organized by functionality. Backend migration
status, publication decisions, and source provenance belong in maintainer files.

- `scripts/contracts/` stores the unchanged imported inputs (25 generated and
  83 existing operation entries). These are excluded from the Mintlify site.
- `scripts/reference-policy.json` pins the reviewed source revision, approves
  21 generated operations using recorded Traffic-ready/production-routed
  evidence, and defers four whose replacement fidelity remains incomplete.
  Existing specialty and waiting-room definitions remain published.
- `scripts/build-reference.rb` generates the five served OpenAPI files with
  customer-facing descriptions and no source/migration extensions. Explicit
  ownership resolves overlapping definitions, including ERP/billing copies.
  Each normalized method/path has one published definition: 98 operations total.
- ERP's consultation response schema and billing's report schema/filter details
  are retained instead of the less complete general copies. The 83-operation
  input inventory remains unchanged and continues to be checked.
- The old patient-web-app spec remains excluded because its canonical contracts
  classify it internal-only. No internal artifact is imported into this repo.
- A new source SHA requires a new publication-policy review. Public audience
  alone does not establish fidelity or availability. The recorded release
  evidence used here is not a fresh live-environment probe.
- The synthetic server and non-interactive playground remain unchanged.
- Public documentation does not imply executable LLM tool eligibility.

Run `ruby scripts/build-reference.rb` after input or presentation-policy changes.
CI reproduces the served files, rejects duplicate endpoints, and checks that
unapproved generated definitions do not replace existing contracts. The old
`/reference/public-preview` guide redirects to the unified reference guide.

The original imports remain in Git history. Removing captured examples from the
current tree does not purge historical copies or attest that old values were
synthetic. History rewriting and credential rotation are outside this change.

## Brand and project configuration

Almond theme, blue colors, favicon, and light/dark logos are reused from
`nimbo-docs`. Analytics, SEO verification, canonical host, and CSS workarounds
are intentionally project-specific and are not copied.

GitHub repository renaming, the local checkout name, the saved Codex project,
and Mintlify's dashboard project/Git connection are separate settings. Verify
Mintlify's connected repository is `ecaresoft/nimbo-api-docs`, its deployment
branch is the intended branch, and its project display name is `Nimbo API`.
Do not change the end-user documentation project or its domain.

Mintlify's GitHub App publishes changes from the connected branch. PR validation
and a local preview do not prove a hosted deployment. After an approved merge,
verify the dashboard deployment revision, landing page, and generated endpoint.
