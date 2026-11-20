# gh dep specification

Small shared package checks and native installation.

## Specification

### 01 Purpose and commands

#### 02 Command and output contract

```text
gh dep check <ecosystem> <package> [--version <exact>] [--min-age-days <days>] [--json]
gh dep install <ecosystem> <package> [--version <exact>] [--min-age-days <days>]
```

Separate version input avoids parsing scoped npm names and Maven coordinates. Versionless input checks the provider default only. An explicit request is never replaced. Do not add alternative-version searches, `--explain`, passthrough package-manager flags or configuration files in v1. Reject unsupported flags before network or execution.

Text check output contains status, canonical package, exact version, age when known, reason codes and advisory IDs. `--json` emits one object with `ecosystem`, `package`, nullable `version`, `status` (`pass|review|fail`), `reasons` (code strings), `advisory_ids` and `coverage` (`direct-package-only`). Arrays are deduplicated and sorted; no timestamps or install-command envelope. Reason codes: `ADVISORY_FOUND`, `RELEASE_DEPRECATED`, `VERSION_UNAVAILABLE`, `DEFAULT_UNAVAILABLE`, `AGE_UNKNOWN`, `RELEASE_TOO_YOUNG`, `PUBLICATION_IN_FUTURE`, `METADATA_UNAVAILABLE`, `ADVISORIES_INCOMPLETE`. Multiple applicable reasons may coexist. Invalid CLI input is a stderr error without a check object.

Check exits 0 for pass, 1 for review/fail, 2 for invalid usage or unsupported operation. Install exits 1 for a blocked check or launch failure, 2 for invalid usage/unsupported operation, otherwise the native exit code; cancellation is nonzero. Install rejects `--json`. A Maven install returns unsupported with guidance to run check and install manually; it does not masquerade as a successful install.

#### 01 Purpose and scope

Draft specification for a standalone Go GitHub CLI extension, executable `gh-dep`, invoked as `gh dep`. Check one direct package release using public metadata and known advisories, then optionally delegate installation. A pass means only that the stated checks completed; it does not certify safety, malware absence, runtime compatibility or transitive dependencies.

This specification is the complete requirements source for this repository. The earlier project specifications have been consolidated here and removed; the scope decisions below record intentional simplifications. No existing implementation or regression suite must be carried over. First delivery covers npm, Cargo, PyPI, Go and Maven checks; native install covers the first four. Pub and Swift are deferred to avoid bespoke metadata pipelines.

### 02 Check and install rules

#### Rules

| concept | id | requirement |
| --- | --- | --- |
| check | C01 | Check exactly one public package and one exact version per invocation; no local manifest or runtime is needed. |
| check | C02 | An explicit --version must identify one release; reject ranges, tags, URLs and filesystem dependencies. Otherwise use only the deps.dev default version; if absent return review. Never search for an older or alternative release. |
| check | C03 | Fetch release metadata from deps.dev and query OSV for the canonical ecosystem/name/version. Never execute a package manager during check. |
| check | C04 | Default minimum age is 14 elapsed UTC days. --min-age-days accepts a nonnegative integer on both commands; zero disables age checking only. No configuration file or Git repository discovery. |
| check | C05 | Known applicable non-withdrawn advisories or deps.dev isDeprecated=true yield fail. This is an upstream deprecation signal; do not claim comprehensive yanking or retraction coverage. |
| check | C06 | Missing release/default, missing required date, future date, too-young release, incomplete response or provider failure yields review. No registry fallback chain. |
| check | C07 | Pass requires confirmed release metadata, sufficient age and a complete OSV query with no active findings. Fail takes precedence over review; review takes precedence over pass. Both fail and review block install. |
| check | C08 | Follow OSV page tokens up to 10 pages with repeated-token detection; any incomplete query yields review unless a fail is already known. Ignore withdrawn advisories; deduplicate remaining IDs. |
| check | C09 | Use a 30 second overall check deadline and 10 second HTTP request timeout with context cancellation; no retries or persistent cache in v1. Bound each response to 10 MiB; oversized or malformed responses yield review. |
| install | I01 | Install invokes the same check service and policy once. Only pass may launch a native tool using the checked exact version. No override flag or silent version substitution. |
| install | I02 | Execute a validated argument array without a shell in the invocation working directory; inherit environment and stdin. Keep stdout and stderr connected to the corresponding native streams. Own check/launch diagnostics go to stderr. Stream both immediately without whole-process buffering, prefixes or JSON wrapping; preserve their content. No total order between streams is promised. |
| install | I03 | Propagate native exit status and cancellation; startup failure returns nonzero. Missing tools fail clearly. No automatic tool install, tool fallback, output parsing or wrapper success message. |
| install | I04 | Native tools own resolution, manifests, lockfiles, scripts and partial changes on failure. No preflight resolution, transitive scan, artifact inspection, staging, rollback or repair. Preserve normal native configuration, credentials and lifecycle hooks; no script suppression or custom Python environment management. |
| architecture | A01 | One Go check service, deps.dev client, OSV client, result model, policy evaluator and process runner serve every supported ecosystem. Ecosystem differences are a small descriptor table plus input normalization and install argument builders. |
| architecture | A02 | No retained legacy modes or compatibility schemas. No repository stars, owner counts, Scorecard, identity verification, typosquatting lists, plugin framework or per-language policy branches. |
| architecture | A03 | Only public registry packages are in scope. Pub, Swift, private registries and additional ecosystems are deferred until they can fit the shared contract. Unsupported selectors fail before network access. |
| check | C10 | Own output must not expose credentials, raw HTTP bodies or untrusted instructions. Render upstream names and identifiers as bounded plain text with terminal control characters escaped. |

### 03 Shared implementation

#### 03 Implementation boundary

Implement in three small slices: shared clients/result/policy and table-driven checks; CLI text/JSON and exit contract; gated native runner with argument-builder tests. Keep transport, policy and process execution independently testable, without a general provider/plugin abstraction. Only native argument construction and ecosystem identity rules vary. Validate Go adapter command syntax against the native tools when implementing.

Acceptance is the table below plus deterministic documentation generation. Do not port the former deep planners, add migration shims or promise every language in the first release.

Native command references: [npm install](https://docs.npmjs.com/cli/install/), [Cargo add](https://doc.rust-lang.org/cargo/commands/cargo-add.html), [uv add](https://docs.astral.sh/uv/reference/cli/#uv-add), [Go get](https://go.dev/ref/mod#go-get).

#### 02 Ecosystem mapping

| deps_dev_system | install_arguments | osv_ecosystem | package_name | selector |
| --- | --- | --- | --- | --- |
| NPM | npm install --save-exact NAME@VERSION | npm | Registry name including optional scope | npm |
| CARGO | cargo add NAME@=VERSION | crates.io | Crate name | cargo |
| PYPI | uv add NAME==VERSION | PyPI | PEP 503 normalized distribution name | pypi |
| GO | go get NAME@VERSION | Go | Module path, not arbitrary import path; preserve case and major-version suffix; accept exact pseudo-versions without sorting or VCS discovery | go |
| MAVEN | Unsupported; fail before check with manual-install guidance and no generated declaration | Maven | group:artifact | maven |

#### 01 Shared API flow

1. Validate selector, package and optional exact version with ecosystem rules. Reject control characters, option-like names and unsupported dependency forms. Normalize only as required by the ecosystem.
2. With no exact version, GET deps.dev `/v3/systems/{system}/packages/{name}` and select its sole marked default. Missing or ambiguous default yields review. No version sorting or stable-release search.
3. GET `/v3/systems/{system}/packages/{name}/versions/{version}`. Require the returned canonical identity to match the requested normalized identity; conflicting identities yield `METADATA_UNAVAILABLE`. Use `publishedAt` and `isDeprecated` where supplied; absent deprecation evidence does not establish absence of withdrawal. A not-found exact version yields `VERSION_UNAVAILABLE`.
4. POST OSV `/v1/query` with `package.name`, mapped `package.ecosystem` and the exact `version`; follow pagination. Use the exact-version response rather than implementing advisory range evaluation. Query only when a release identity is established.
5. Apply the same policy and format the result. Install consumes this result directly.

URL-escape each path parameter; never interpolate unescaped package names. Reuse one HTTP transport and a cancellation context. Unit tests use recorded/minimal fixtures and an injected clock/HTTP transport; install tests use stub executables. No live APIs are required by the test suite.

Provider coverage and freshness limit every result. deps.dev does not index every registry release; missing data remains review rather than starting a second discovery system. API references: [deps.dev v3](https://docs.deps.dev/api/v3/) and [OSV exact-version queries](https://google.github.io/osv.dev/post-v1-query/).

### 04 Acceptance

#### Acceptance criteria

| concept | expected | id | scenario |
| --- | --- | --- | --- |
| check | Identical pass policy and result shape | T01 | Same complete clean mature fixture for each supported selector |
| check | Fail; no process starts | T02 | Advisory or deprecated release; also missing evidence |
| check | Review normally; zero skips only age rule | T03 | Too young or missing date; zero age option |
| check | Review without default; exact request checks only that release | T04 | Missing default; exact release supplied |
| check | Review; never treat incomplete data as clean | T05 | Timeout, bad JSON, oversized data, OSV token loop or page cap |
| check | Withdrawn ignored; active IDs deduplicated and sorted | T06 | Withdrawn and duplicate OSV records across pages |
| architecture | Correct encoded API identity; no shared lexical version sorting | T07 | Scoped npm, PyPI normalization, Go path and Maven coordinate |
| install | Exact argv, current directory, inherited stdin and separate raw stdout/stderr; no extra check | T08 | Pass then install with stub executable for each native adapter |
| install | No launch for blocked check; appropriate nonzero status otherwise | T09 | Review, fail, missing tool, native error or cancellation |
| install | No shell evaluation or file changes; unsupported operations fail before network | T10 | Invalid input, shell metacharacters, unsupported selector or Maven install |
| install | Progress reaches its native stream before exit; no whole-process buffering | T11 | Native stub writes progress then waits for stdin before exit |
| check | Own diagnostics omit credentials and raw bodies; identifiers cannot inject terminal instructions | T12 | Credential-bearing provider error or terminal controls in upstream identifiers |
| check | Same package-only result as inside a project; no local tool executes | T13 | Check outside Git with no manifest or lockfile and no native tool installed |

### 05 Scope decisions

#### Scope decisions from consolidation

The previous product specification and implementation proposal have been reviewed in full. The rules, API flow, ecosystem mapping and acceptance table retain their relevant package-only boundary and native delegation behavior. The following differences are intentional:

| Earlier requirement | Standalone scope |
| --- | --- |
| Repository identity, stars, owners, activity, Scorecard and name-lookalike checks | Removed; no reputation or provenance verdict is claimed. |
| Stable-version ordering, four candidates and alternative recommendations | One explicit release or provider default only; no sorting or replacement. |
| Registry-specific descriptions and lifecycle lookups | No extra calls for descriptions; deprecation is checked only as exposed by deps.dev. Comprehensive yanking/retraction detection is not claimed. |
| Existing JSON compatibility, recommendation labels and --explain | One new pass/review/fail schema and concise reasons; no migration obligation. |
| Repository configuration discovery | Explicit age flag with a 14-day default; checks also work outside Git repositories. |
| Pub and GitHub-only Swift adapters | Deferred; no separate metadata pipeline in the first delivery. |
| Maven/Swift print-only manifest generation | Maven check remains; install is explicitly unsupported. No manifest generation or editing. |
| Merge native stderr into stdout | Preserve native stdout and stderr separately; both stream immediately without normalization. |
| Retain strict planners, archive inspectors and old tests/delivery records | No legacy code retention requirement or inherited implementation claims. |

The direct dependency version passed to the native tool does not pin the transitive graph. Go may update related requirements through its normal module selection. A package-manager failure is returned directly, without repair. Missing local graph, lockfile, artifact or runtime evidence never adds a review reason to a package check.

### 06 Source navigation

#### Concept registry

| description | id | parent |
| --- | --- | --- |
| Shared package check | check |  |
| Native package manager delegation | install |  |
| Go implementation boundaries | architecture |  |

