# gh dependency-pulse specification

Small shared package checks and native installation.

## Specification

### 01 Purpose and commands

#### 02 Command and output contract

```text
gh dependency-pulse check <ecosystem> <package> [--version <exact>] [--min-age-days <days>] [--json]
gh dependency-pulse install <ecosystem> <package> [--version <exact>] [--min-age-days <days>]
```

The `<ecosystem>` argument accepts a package-manager/ecosystem selector or a language alias from the ecosystem mapping. Every supported language has one explicit default package manager. For example, `check npm lodash`, `check javascript lodash` and `check js lodash` are equivalent; `install js lodash` delegates to npm after the same check passes. Python defaults to uv: `pypi`, `python`, `py` and `uv` select the same PyPI checks and uv install command. Aliases are exact lowercase tokens and do not add support for other package managers or ecosystems. Resolve selectors to a descriptor containing both canonical ecosystem and default manager; retain the selected manager through installation. JSON `ecosystem` and text output use the canonical ecosystem. Thus `kotlin`, `kt` and `gradle` use Maven checks and Gradle installation, while `java`, `maven` and `mvn` use the same checks with Maven as the default manager. Java/Maven installation remains optional and unsupported until its adapter is delivered. Defaults are fixed by this specification, without configuration or installed-tool discovery.

Separate version input avoids parsing scoped npm names and Maven coordinates. Versionless input checks the provider default only. An explicit request is never replaced. Do not add alternative-version searches, `--explain`, passthrough package-manager flags or configuration files in v1. Reject unsupported flags before network or execution.

Text check output contains status, canonical package, exact version, age when known, reason codes and advisory IDs. `--json` emits one object with `ecosystem`, `package`, nullable `version`, `status` (`pass|review|fail`), `reasons` (code strings), `advisory_ids` and `coverage` (`direct-package-only`). Arrays are deduplicated and sorted; no timestamps or install-command envelope. Reason codes: `ADVISORY_FOUND`, `RELEASE_DEPRECATED`, `VERSION_UNAVAILABLE`, `DEFAULT_UNAVAILABLE`, `AGE_UNKNOWN`, `RELEASE_TOO_YOUNG`, `PUBLICATION_IN_FUTURE`, `METADATA_UNAVAILABLE`, `ADVISORIES_INCOMPLETE`. Multiple applicable reasons may coexist. Invalid CLI input is a stderr error without a check object.

Check exits 0 for pass, 1 for review/fail, 2 for invalid usage or unsupported operation. Install exits 1 for a blocked check or launch failure, 2 for invalid usage/unsupported operation, otherwise the native exit code; cancellation is nonzero. Install rejects `--json`. An undelivered install adapter returns unsupported before network access or mutation, with check-only/manual-install guidance. It never masquerades as a successful install. Kotlin installation is required and must not be rejected merely because its check ecosystem is Maven.

Uniform developer experience is a required public contract: `check python PACKAGE` and `check kotlin GROUP:ARTIFACT` accept the same flags and return the same result schema, status meanings, reason codes and exit semantics. Only package identifiers differ. `install LANGUAGE PACKAGE` always performs that same check once before invoking the default manager. Its outcome is conveyed by consistent CLI diagnostics and the native exit status; no language-specific command syntax or manager flags are required from the user. An installation success means the native operation succeeded, not proof of runtime compatibility or a post-install security scan. Native output remains unmodified and install does not emit JSON in this scope.

#### 01 Purpose and scope

Draft specification for a standalone Go GitHub CLI extension, executable `gh-dependency-pulse`, invoked as `gh dependency-pulse`. Check one direct package release using public metadata and known advisories, then optionally delegate installation. A pass means only that the stated checks completed; it does not certify safety, malware absence, runtime compatibility or transitive dependencies.

This specification is the complete requirements source for this repository. The earlier project specifications have been consolidated here and removed; the scope decisions below record intentional simplifications. No existing implementation or regression suite must be carried over. Required delivery covers check and install for JavaScript, TypeScript, Python, Rust, Go, Dart, Swift and Kotlin. Java checks remain required; Java installation is optional. The language support matrix separates required capabilities from optional expansion and records adapter effort. These are delivery requirements, not claims of implemented support: the current code is a CLI skeleton. Dart, Swift and Kotlin install design work is required rather than deferred.

### 02 Check and install rules

#### Rules

| concept | id | requirement |
| --- | --- | --- |
| check | C01 | Check exactly one public package and one exact version per invocation; no local manifest or runtime is needed. |
| check | C02 | An explicit --version must identify one release; reject ranges, moving tags and filesystem dependencies. Swift maps an exact version to one verified release tag; do not accept arbitrary branch/tag selectors. Canonical public Swift package URLs are identity input only. Otherwise use only the declared metadata provider default; if absent return review. Never search for an older or alternative release. |
| check | C03 | Fetch metadata through the single declared ecosystem adapter (deps.dev by default; Pub and Swift require dedicated adapters) and query OSV for the canonical ecosystem/name/version. Never execute a package manager or project code during check. |
| check | C04 | Default minimum age is 14 elapsed UTC days. --min-age-days accepts a nonnegative integer on both commands; zero disables age checking only. No configuration file or Git repository discovery. |
| check | C05 | Known applicable non-withdrawn advisories or deps.dev isDeprecated=true yield fail. This is an upstream deprecation signal; do not claim comprehensive yanking or retraction coverage. |
| check | C06 | Missing release/default, missing required date, future date, too-young release, incomplete response or provider failure yields review. No registry fallback chain. |
| check | C07 | Pass requires confirmed release metadata, sufficient age and a complete OSV query with no active findings. Fail takes precedence over review; review takes precedence over pass. Both fail and review block install. |
| check | C08 | Follow OSV page tokens up to 10 pages with repeated-token detection; any incomplete query yields review unless a fail is already known. Ignore withdrawn advisories; deduplicate remaining IDs. |
| check | C09 | Use a 30 second overall check deadline and 10 second HTTP request timeout with context cancellation; no retries or persistent cache in v1. Bound each response to 10 MiB; oversized or malformed responses yield review. |
| install | I01 | Install invokes the same check service and policy once. Only pass may launch a native tool using the checked exact version. No override flag or silent version substitution. |
| install | I02 | Execute a validated argument array without a shell in the invocation working directory; inherit environment and stdin. Keep stdout and stderr connected to the corresponding native streams. Own check/launch diagnostics go to stderr. Stream both immediately without whole-process buffering, prefixes or JSON wrapping; preserve their content. No total order between streams is promised. |
| install | I03 | Propagate native exit status and cancellation; startup failure returns nonzero. Missing tools fail clearly. No automatic tool install, tool fallback, output parsing or wrapper success message. |
| install | I04 | Native tools own resolution, lockfiles, scripts and partial changes on failure. A bounded tested declaration adapter may insert the exact checked dependency when a required manager has no suitable native add operation. No preflight resolution, transitive scan, staging, rollback or repair. Preserve normal native configuration, credentials and lifecycle hooks; no custom Python environment management. |
| architecture | A01 | One check service, normalized release/result model, policy evaluator, OSV client and process runner serve every language. Small internal metadata adapters and descriptors isolate provider identity; manager descriptors/argument builders isolate installation. Language-specific policy branches are forbidden. |
| architecture | A02 | No retained legacy modes or compatibility schemas. No repository stars, owner counts, Scorecard, identity verification, typosquatting lists, plugin framework or per-language policy branches. |
| architecture | A03 | Only public packages from declared supported sources are in scope. Dart, Swift and Kotlin are required alongside Go, Python, Rust, TypeScript and JavaScript; Java check remains required. Additional languages follow independent check/install priorities in language-support.csv. Private registries remain excluded. Unsupported capabilities fail before network access. |
| check | C10 | Own output must not expose credentials, raw HTTP bodies or untrusted instructions. Render upstream names and identifiers as bounded plain text with terminal control characters escaped. |
| architecture | A04 | Each supported language has one default manager. Resolve language/manager aliases into canonical ecosystem plus selected manager; preserve manager identity even when checks share an ecosystem. Canonical ecosystem output is alias-independent. No environment-based manager selection or fallback; missing tools fail clearly. Kotlin uses Maven checks and Gradle installation; Java/Maven install is optional. |
| architecture | A05 | Use the same check/install command shape, flags, policy, result schema, reason codes and exit contract for every language. Package coordinates may vary; users need not know native manager flags. Install checks once and reports native success/failure without claiming runtime compatibility or additional security verification. |
| architecture | A06 | Promote cheap optional check and install capabilities independently through descriptors and shared fixtures. Never enable install merely because check works; never treat a candidate matrix row or OSV ecosystem presence as implemented support. Required adapter design gaps must be resolved before claiming delivery. |

### 03 Shared implementation

#### 03 Implementation boundary

Implement in three small slices: shared clients/result/policy and table-driven checks; CLI text/JSON and exit contract; gated native runner with argument-builder tests. Keep transport, policy and process execution independently testable, using a small internal metadata interface and descriptor/manager tables, without a public plugin framework. Only metadata normalization, ecosystem identity and manager integration vary; policy, results and execution handling remain shared. Validate Go adapter command syntax against the native tools when implementing.

Acceptance is the table below plus deterministic documentation generation. Do not port the former deep planners, add migration shims or treat optional languages as required. All must-have rows must meet their check/install delivery requirements.

Native command references: [npm install](https://docs.npmjs.com/cli/install/), [Cargo add](https://doc.rust-lang.org/cargo/commands/cargo-add.html), [uv add](https://docs.astral.sh/uv/reference/cli/#uv-add), [Go get](https://go.dev/ref/mod#go-get).

For Kotlin, a mapping to `gradlew` alone cannot add a dependency. Specify a bounded dependency declaration strategy (supported root build file format, dependency configuration and exact version insertion), test preservation of unrelated content and then delegate resolution to the committed wrapper. Avoid a general Gradle parser or arbitrary injected build scripts. Swift similarly requires a tested exact SwiftPM dependency-add/resolve sequence and a documented minimum toolchain. Keep these design gates visible; placeholders or manual instructions do not satisfy must-have installation. Any bounded declaration editor is a scoped exception to native-only manifest ownership, not a general repair engine. [Gradle dependency declarations](https://docs.gradle.org/current/userguide/declaring_dependencies.html), [SwiftPM add-dependency](https://docs.swift.org/main/documentation/packagemanagerdocs/packageadddependency/), [Dart pub add](https://dart.dev/tools/pub/cmd/pub-add).

#### 02 Ecosystem mapping

| aliases | canonical_ecosystem | default_package_manager | deps_dev_system | install_arguments | language | osv_ecosystem | package_name | selector |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| javascript; js; typescript; ts | npm | npm | NPM | npm install --save-exact NAME@VERSION | JavaScript / TypeScript | npm | Registry name including optional scope | npm |
| rust | cargo | cargo | CARGO | cargo add NAME@=VERSION | Rust | crates.io | Crate name | cargo |
| python; py; uv | pypi | uv | PYPI | uv add NAME==VERSION | Python | PyPI | PEP 503 normalized distribution name | pypi |
| golang | go | go | GO | go get NAME@VERSION | Go | Go | Module path, not arbitrary import path; preserve case and major-version suffix; accept exact pseudo-versions without sorting or VCS discovery | go |
| java; mvn | maven | maven (mvn) | MAVEN | Planned optional Maven adapter; unsupported until POM integration is specified and tested | Java | Maven | group:artifact | maven |
| dart | pub | dart pub |  | dart pub add NAME:VERSION | Dart | Pub | Public pub.dev package name | pub |
| swiftpm; spm | swift | Swift Package Manager |  | Planned SwiftPM exact dependency addition and resolution; validate supported toolchain | Swift | SwiftURL | Canonical public repository URL; exact version/tag mapping must be specified | swift |
| kotlin; kt | maven | Gradle wrapper | MAVEN | Planned Gradle wrapper adapter; exact declaration integration must be specified | Kotlin | Maven | group:artifact | gradle |

#### 04 Language support priorities and adapter effort

`examples/language-support.csv` is the capability planning matrix: one row per language, capped at 20 practical candidates, not a popularity ranking. All rows are planned; none asserts implementation. `must` is required for delivery; `nice-to-have` may be independently admitted for check or install. The eight required check/install languages include all seven gh-flarebyte build languages plus JavaScript; Java checks preserve the existing scope.

Effort is an engineering estimate of additional specialized code, not runtime cost or a guarantee: `0-reuse` = existing ecosystem/manager adapter and an alias only; `1-mapping` = descriptor, validation rules and/or exact argv template plus fixtures; `2-adapter` = bounded metadata client or declaration adapter; `3-design` = unresolved identity, metadata or project-editing design. Ratings are incremental against the named shared adapter; implement prerequisite adapters first. For example F# reuses NuGet only after the .NET adapter exists.

Prioritize optional check rows at 0/1 effort with shared provider fixtures (especially NuGet, RubyGems and Maven reuse). Independently enable optional install only when its adapter is ready; check-only support is useful and does not require install. A CSV row is a candidate, not automatic CLI acceptance. The explicit delivered capability registry determines accepted aliases; unsupported selectors or operations fail with exit 2 before network/mutation. Add descriptors and tests for cheap extensions rather than language-specific policy branches. Every promoted adapter must supply sufficient identity, release/age and advisory evidence under the same policy. Additional providers with higher effort remain optional.

The ecosystem table records required adapter contracts; the language matrix records required and candidate capabilities. Keep the two consistent when promoting candidates. Package-manager aliases select a manager as well as an ecosystem; sharing Maven checks must not erase Kotlin/Gradle versus Java/Maven installation intent.

#### 05 Language support matrix

| aliases | check_adapter_effort | check_priority | check_reuse | decision_notes | default_package_manager | ecosystem | install_adapter_effort | install_priority | install_work | language |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| javascript; js; npm | 1-mapping | must | deps.dev NPM + OSV npm | Shared npm adapter with TypeScript | npm | npm | 1-mapping | must | Exact npm argv | JavaScript |
| typescript; ts | 0-reuse | must | Reuse JavaScript checks | No TypeScript-specific policy | npm | npm | 0-reuse | must | Reuse npm argv | TypeScript |
| python; py; pypi; uv | 1-mapping | must | deps.dev PYPI + OSV PyPI | Existing normalization rules | uv | pypi | 1-mapping | must | Exact uv add argv | Python |
| rust; cargo | 1-mapping | must | deps.dev CARGO + OSV crates.io | No Rust-specific policy | cargo | cargo | 1-mapping | must | Exact cargo add argv | Rust |
| go; golang | 1-mapping | must | deps.dev GO + OSV Go | Preserve module identity and pseudo-versions | go | go | 1-mapping | must | Exact go get argv | Go |
| dart; pub | 2-adapter | must | New pub.dev metadata adapter + OSV Pub | Must establish publication date and default-release rules | dart pub | pub | 1-mapping | must | dart pub add NAME:VERSION | Dart |
| swift; swiftpm; spm | 3-design | must | Public repository release metadata + OSV SwiftURL | Define canonical URL/tag/version/date mapping and supported SwiftPM version; no shell or executable manifests during check | Swift Package Manager | swift | 2-adapter | must | SwiftPM dependency addition and resolution | Swift |
| kotlin; kt; gradle | 0-reuse | must | Reuse Maven group:artifact checks | Do not confuse Maven registry with Maven install tool; design exact dependency insertion before delivery | Gradle wrapper | maven | 3-design | must | Bounded Gradle dependency declaration adapter | Kotlin |
| java; maven; mvn | 1-mapping | must | deps.dev MAVEN + OSV Maven | Retain existing check scope; check-only is acceptable until install adapter is designed | Maven | maven | 3-design | nice-to-have | POM dependency declaration and native resolution | Java |
| csharp; cs; nuget | 1-mapping | nice-to-have | deps.dev NUGET + OSV NuGet | Good candidate after NuGet identity and date fixtures | dotnet CLI | nuget | 1-mapping | nice-to-have | Exact dotnet package-add argv | C# |
| fsharp; fs | 0-reuse | nice-to-have | Reuse C# NuGet checks | Incremental estimate assumes NuGet/dotnet adapter exists | dotnet CLI | nuget | 0-reuse | nice-to-have | Reuse dotnet adapter | F# |
| ruby; gem; rubygems | 1-mapping | nice-to-have | deps.dev RUBYGEMS + OSV RubyGems | Document environment installation scope; no Bundler project support implied | RubyGems | rubygems | 1-mapping | nice-to-have | Exact gem install argv | Ruby |
| php; composer | 2-adapter | nice-to-have | New Packagist metadata adapter + OSV Packagist | Provider adapter required despite simple install mapping | Composer | packagist | 1-mapping | nice-to-have | Exact composer require argv | PHP |
| scala; sbt | 0-reuse | nice-to-have | Reuse Maven checks with exact published artifact coordinates | No Scala binary-version suffix inference | sbt | maven | 3-design | nice-to-have | sbt build dependency declaration | Scala |
| c | 3-design | nice-to-have | Reuse C++ provider only after Conan/advisory identity is established | No universal C registry; source-level Git coverage is not automatically Conan release coverage | Conan | conan | 2-adapter | nice-to-have | Reuse Conan reference handling with C project integration | C |
| elixir; mix | 2-adapter | nice-to-have | New Hex metadata adapter + OSV Hex | No evaluation of project code during check | Mix | hex | 2-adapter | nice-to-have | mix.exs dependency declaration and native resolution | Elixir |
| erlang; rebar3 | 0-reuse | nice-to-have | Reuse Elixir Hex checks once implemented | Different install adapter from Elixir | rebar3 | hex | 2-adapter | nice-to-have | rebar.config dependency declaration | Erlang |
| r; cran | 2-adapter | nice-to-have | New CRAN metadata adapter + OSV R identity validation | Default install.packages does not itself express arbitrary exact versions | R install.packages | cran | 3-design | nice-to-have | Exact archived release installation design | R |
| julia | 2-adapter | nice-to-have | New General registry metadata adapter + OSV Julia | Require canonical UUID and reliable release publication evidence | Julia Pkg | julia | 2-adapter | nice-to-have | Exact Pkg add invocation via fixed program and argv | Julia |
| cpp; cxx; conan | 3-design | nice-to-have | No assumed deps.dev/OSV Conan identity mapping | Registry identity to advisory identity is an unresolved prerequisite; no guessed pass | Conan | conan | 2-adapter | nice-to-have | Exact Conan reference and project integration | C++ |

#### 01 Shared API flow

1. Resolve a supported canonical selector or listed alias using the ecosystem mapping and its default package manager, then validate package and optional exact version with ecosystem rules. Reject control characters, option-like names and unsupported dependency forms. Normalize only as required by the ecosystem.
2. For deps.dev-backed ecosystems, with no exact version, GET deps.dev `/v3/systems/{system}/packages/{name}` and select its sole marked default. Missing or ambiguous default yields review. No version sorting or stable-release search.
3. Fetch the exact release through the selected metadata adapter; for deps.dev use GET `/v3/systems/{system}/packages/{name}/versions/{version}`. Require the returned canonical identity to match the requested normalized identity; conflicting identities yield `METADATA_UNAVAILABLE`. Use `publishedAt` and `isDeprecated` where supplied; absent deprecation evidence does not establish absence of withdrawal. A not-found exact version yields `VERSION_UNAVAILABLE`.
4. POST OSV `/v1/query` with `package.name`, mapped `package.ecosystem` and the exact `version`; follow pagination. Use the exact-version response rather than implementing advisory range evaluation. Query only when a release identity is established.
5. Apply the same policy and format the result. Install consumes this result directly.

URL-escape each path parameter; never interpolate unescaped package names. Reuse one HTTP transport and a cancellation context. Unit tests use recorded/minimal fixtures and an injected clock/HTTP transport; install tests use stub executables. No live APIs are required by the test suite.

Provider coverage and freshness limit every result. deps.dev does not index every registry release; missing data remains review rather than trying fallback providers. Each ecosystem has one configured metadata path; dedicated Pub and Swift adapters are deliberate extensions, not registry fallback chains. API references: [deps.dev v3](https://docs.deps.dev/api/v3/) and [OSV exact-version queries](https://google.github.io/osv.dev/post-v1-query/).

Metadata adapters produce one normalized release record (canonical ecosystem/name, exact version, publication time, deprecation/withdrawal evidence and completeness). All adapters use the same policy and OSV client. Pub uses the hosted pub.dev API; Swift needs a bounded public-repository metadata design with verified URL/version/tag identity and publication semantics before implementation. Do not execute Dart, Swift, Gradle or project manifests during check. Missing required evidence produces review, never a weaker language-specific pass. A provider without a declared default returns DEFAULT_UNAVAILABLE for versionless requests; do not invent version sorting.

The deps.dev v3 API documents GO, RUBYGEMS, NPM, CARGO, MAVEN, PYPI and NUGET. OSV covers more ecosystems, but advisory coverage alone does not establish release metadata or default/age evidence. References: [deps.dev systems](https://docs.deps.dev/api/v3/), [OSV coverage](https://google.github.io/osv.dev/data/), [Pub metadata API](https://pub.dev/help/api).

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
| install | No shell evaluation or file changes; unsupported operations fail before network | T10 | Invalid input, shell metacharacters, unsupported selector or unavailable install adapter |
| install | Progress reaches its native stream before exit; no whole-process buffering | T11 | Native stub writes progress then waits for stdin before exit |
| check | Own diagnostics omit credentials and raw bodies; identifiers cannot inject terminal instructions | T12 | Credential-bearing provider error or terminal controls in upstream identifiers |
| check | Same package-only result as inside a project; no local tool executes | T13 | Check outside Git with no manifest or lockfile and no native tool installed |
| architecture | Equivalent aliases yield identical check requests/results and manager-specific native argv; Kotlin and Java share Maven checks but keep distinct install intent; unavailable operations fail before network | T14 | Canonical selectors and every listed language/package-manager alias on check and install |
| architecture | Same flags and result/exit semantics; fixture-backed identity/date/advisory evidence; exact checked dependency added by correct default manager; skeleton stubs do not satisfy delivery | T15 | All must-have language check/install capabilities in the matrix |
| architecture | Check succeeds under normal shared evidence policy; install exits 2 before check/network/mutation; adding a language alias introduces no policy fork | T16 | Optional shared-ecosystem check support with no install adapter |
| check | Missing evidence yields review and blocks install; invalid identity is rejected; no fallback, project execution or fabricated clean result | T17 | Pub/Swift missing release date or default; Swift ambiguous URL/tag/version identity |
| install | Stub/fixture tests verify declaration edits where needed, preservation of unrelated content, correct manager invocation and exit propagation; no check duplication or manual-only success | T18 | Kotlin/Gradle or Swift native integration with exact checked version |

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
| Pub and Swift adapters | Now required: add bounded metadata adapters while preserving shared policy and results. |
| Maven/Swift print-only manifest generation | No print-only success mode. Swift and Kotlin install are required; Java/Maven install is optional. Bounded native integration must actually add the checked dependency. |
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

