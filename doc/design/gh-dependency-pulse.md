# gh dependency-pulse specification

Small shared package checks and native installation.

## Specification

### 01 Purpose and commands

#### 02 Command and output contract

```text
gh dependency-pulse check <ecosystem> <package> [--version <exact>] [--min-age-days <days>] [--format json|markdown | --json]
gh dependency-pulse install <ecosystem> <package> [--version <exact>] [--min-age-days <days>]
gh dependency-pulse list <ecosystem> [--check [--min-age-days <days>]] [--format json|markdown|table]
```

Selectors use the same lowercase language and manager aliases across commands. For example, `check npm lodash`, `check javascript lodash` and `check js lodash` are equivalent. Kotlin/Gradle and Java/Maven share the canonical `maven` check ecosystem but retain distinct managers and manifest adapters. The flags, result schema and policy are the same across languages.

Check uses the requested exact version or the provider default when the version is omitted. The result uses the canonical ecosystem regardless of alias.

Markdown summarizes the same check result as JSON. `--format json` (or its `--json` alias) emits one object with `ecosystem`, `package`, nullable `version`, `status` (`pass|review|fail`), `reasons` (code strings), `advisory_ids`, `age_days`, `latest_version`, `advisories` and `coverage` (`direct-package-only`). Arrays are deduplicated and sorted. The reason code table defines each trigger. Multiple reasons may apply, and fail takes precedence over review.

Check exits 0 for pass and 1 for review or fail. Install runs the same check once and delegates only an exact release that passes. A blocked check or launch failure exits 1; a launched manager's exit status is preserved, and cancellation is nonzero. Install preserves native stdout and stderr and rejects formatting flags.

Invalid usage and unsupported operations exit 2 before provider calls, native execution or changes. Diagnostics go to stderr. An unsupported install includes separate check and manual-install guidance.

#### 03 Optional project defaults

Optional `.gh-dependency-pulse.cue` can sit beside `.gh-flarebyte.cue` in the project root. Supported fields are:

- `minAgeDays`: nonnegative integer, default 14. Applies to standalone check, install's precheck and `list --check`. Zero disables only the age rule.
- `format`: `json` or `markdown`, default `markdown`. Applies to check and list. List also accepts `table` via `--format`.

Explicit flags override the file, which overrides built-ins. An explicit zero is an override. On check, `--json` aliases `--format json`. Conflicting format flags exit 2.

Inside Git, look for the nearest file from the invocation directory through the nearest ancestor containing a `.git` file or directory, inclusive. Outside Git, inspect only the invocation directory. Use one file without merging and keep the invocation directory for native execution.

Validate the entire file before applying overrides. Read one self-contained CUE file with a closed schema and concrete values. Reject imports, external reads, unknown fields and invalid values. An unreadable or invalid file exits 2 before network access, native execution or mutation. Root help and version bypass config loading.

#### 04 Project defaults example

```cue
// Save as .gh-dependency-pulse.cue in the consuming project root.
minAgeDays: 30
format: "json"
```

#### 05 List direct project dependencies

Select one manifest adapter with the same aliases as check and install. For example, `list go` and `list python` can inspect the same directory independently.

Read the selected adapter’s conventional files relative to the invocation directory, as listed in the manifest matrix. Exclude ancestors, workspaces, subprojects, installed environments and links outside that directory. If both Gradle build files exist, report ambiguity and exit 2. Parse declarations statically. Report a partial listing if some declarations cannot be enumerated. Missing, unreadable or invalid required manifests exit 2. Config discovery follows its separate Git boundary rules.

List direct declarations only. Prefer a unique locked release that matches the declaration and source, then an exact declaration if no lock evidence conflicts. Keep unresolved requirements visible with null versions. Version provenance is `locked`, `declared` or `unknown`.

Map scope to `prod`, `dev`, `optional`, `peer` or `unknown`, retaining the original group or configuration where available. Keep separate declarations for separate scopes or conditions.

JSON emits one object with `ecosystem`, `manifest` (relative path), `complete`, `warnings` and `packages`. Each row contains `package`, `requirement` (nullable), `version` (nullable), `version_source` (`locked|declared|unknown`), `scope` and `native_scope` (nullable). Markdown renders a Markdown table. Table renders aligned terminal columns. Both human formats display unknown values as a dash. Sort rows by package, scope, native scope, requirement and version, with stable manifest order for ties. Escape untrusted names, requirements and titles for the output format, and omit credentials and sensitive source details.

Plain list is offline. With `--check`, reuse the standalone check once per unique eligible public package and exact release. `--min-age-days` is accepted only with `--check`. Unresolved versions and unsupported sources yield review without provider requests for those rows. Send only validated public package identities. Bound enrichment and concurrency, respect cancellation, and retain other rows if a check fails. Listing never runs project code or a package manager.

With `--check`, add `status`, `reasons`, `age_days`, `latest_version` and `advisories` to each row. The reason code table identifies list-only codes. Unavailable age and latest version are null, and unavailable advisory entries use an empty array. Show Pass, Review or Fail in human output.

Exit 0 for a complete listing with every requested check passing (or no checks requested). Exit 1 for a partial listing or any review/fail row when checks were requested. Preserve the listing on exit 1. Exit 2 for command, configuration or manifest errors that prevent listing.

#### 01 Purpose and scope

Use `gh dependency-pulse` to check one public package release, install the checked release, or list direct project dependencies. Checks cover release metadata and known advisories for the direct package. A pass does not certify runtime compatibility, absence of malware or the transitive graph.

The language support matrix defines required and optional check/install capabilities. The manifest matrix defines the initial listing adapters.

### 02 Check and install rules

#### Reason codes

| code | scope | trigger | verdict |
| --- | --- | --- | --- |
| ADVISORY_FOUND | shared | A known applicable advisory has not been withdrawn. | fail |
| RELEASE_DEPRECATED | shared | The metadata provider confirms the checked release is deprecated. | fail |
| RELEASE_RETRACTED | shared | The metadata provider explicitly marks the exact release as retracted. | fail |
| VERSION_UNAVAILABLE | shared | The provider definitively reports that it does not have the exact release. | review |
| DEFAULT_UNAVAILABLE | shared | A conclusive provider response establishes no unambiguous default for a versionless check. | review |
| AGE_UNKNOWN | shared | The age rule requires a publication date and none is available. | review |
| RELEASE_TOO_YOUNG | shared | The release is younger than the configured minimum age. | review |
| PUBLICATION_IN_FUTURE | shared | The provider reports a publication date after the check time. | review |
| METADATA_UNAVAILABLE | shared | A required metadata lookup fails or returns malformed or conflicting release data. | review |
| ADVISORIES_INCOMPLETE | shared | The advisory query did not return a complete result. | review |
| EXACT_VERSION_UNKNOWN | list-only | The declaration has no unambiguous exact version to check. | review |
| UNSUPPORTED_SOURCE | list-only | The declaration does not identify a supported public package source. | review |

#### Rules

| concept | id | requirement |
| --- | --- | --- |
| check | C01 | Check exactly one public package and one exact version per invocation; no local manifest or runtime is needed. |
| check | C02 | An explicit --version must identify one release; reject ranges, moving tags and filesystem dependencies. Swift maps an exact version to one verified release tag; do not accept arbitrary branch/tag selectors. Canonical public Swift package URLs are identity input only. Otherwise use only the declared metadata provider default; if absent return review. Never search for an older or alternative release. |
| check | C03 | Fetch metadata through the single declared ecosystem adapter (deps.dev by default; Pub and Swift require dedicated adapters) and query OSV for the canonical ecosystem/name/version. Never execute a package manager or project code during check. |
| check | C04 | Built-in minimum age is 14 elapsed UTC days. Optional .gh-dependency-pulse.cue supplies minAgeDays for check, the pre-install check and list --check; explicit --min-age-days overrides it, including zero. Require a nonnegative integer; zero disables age checking only. Check remains usable without configuration or Git. |
| check | C05 | An applicable non-withdrawn advisory or explicit provider confirmation of deprecation or retraction of the exact release yields fail. Missing lifecycle metadata does not establish that the release is active. |
| check | C06 | Missing release/default, missing required date, future date, too-young release, incomplete response or provider failure yields review. No registry fallback chain. |
| check | C07 | Pass requires confirmed release metadata, satisfaction of the enabled age rule and a complete OSV query with no active findings. Fail takes precedence over review; review takes precedence over pass. Both fail and review block install. |
| check | C08 | Follow OSV page tokens up to 10 pages with repeated-token detection; any incomplete query yields review unless a fail is already known. Ignore withdrawn advisories; deduplicate remaining IDs. |
| check | C09 | Use a 30 second overall check deadline and 10 second HTTP request timeout with context cancellation; no retries or persistent cache in v1. Bound each response to 10 MiB; oversized or malformed responses yield review. |
| install | I01 | Install invokes the same check service and policy once. Only pass may launch a native tool using the checked exact version. No override flag or silent version substitution. |
| install | I02 | Execute a validated argument array without a shell in the invocation working directory; inherit environment and stdin. Keep stdout and stderr connected to the corresponding native streams. Own check/launch diagnostics go to stderr. Stream both immediately without whole-process buffering, prefixes or JSON wrapping; preserve their content. No total order between streams is promised. |
| install | I03 | Propagate native exit status and cancellation; startup failure returns nonzero. After a passing check and before declaration edits or delegation, verify the selected manager/launcher is available. If missing, exit 1 with its name, one or two lines of macOS installation guidance and an official installation URL. No automatic tool install, tool fallback, native output parsing or wrapper success message. |
| install | I04 | Native tools own resolution, lockfiles, scripts and partial changes on failure. A bounded tested declaration adapter may insert the exact checked dependency when a required manager has no suitable native add operation. No preflight resolution, transitive scan, staging, rollback or repair. Preserve normal native configuration, credentials and lifecycle hooks; no custom Python environment management. |
| architecture | A01 | One check service, normalized release/result model, policy evaluator, OSV client and process runner serve every language. Small internal metadata adapters and descriptors isolate provider identity; manager descriptors/argument builders isolate installation. Language-specific policy branches are forbidden. |
| architecture | A02 | No retained legacy modes or compatibility schemas. No repository stars, owner counts, Scorecard, identity verification, typosquatting lists, plugin framework or per-language policy branches. |
| architecture | A03 | Remote checks and installation cover only public packages from declared supported sources. List may display unsupported declarations without checking them. Dart, Swift and Kotlin are required alongside Go, Python, Rust, TypeScript and JavaScript; Java check remains required. Additional languages follow independent check/install priorities in language-support.csv. Unsupported capabilities fail before network access. |
| check | C10 | Own output must not expose credentials, raw HTTP bodies or untrusted instructions. Render upstream names and identifiers as bounded plain text with terminal control characters escaped. |
| architecture | A04 | Each supported language has one default manager. Resolve language/manager aliases into canonical ecosystem plus selected manager; preserve manager identity even when checks share an ecosystem. Canonical ecosystem output is alias-independent. No environment-based manager selection or fallback; missing tools fail clearly. Kotlin uses Maven checks and Gradle installation; Java/Maven install is optional. |
| architecture | A05 | Use the same check/install command shape, flags, policy, result schema, reason codes and exit contract for every language. Package coordinates may vary; users need not know native manager flags. Install checks once and reports native success/failure without claiming runtime compatibility or additional security verification. |
| architecture | A06 | Promote cheap optional check and install capabilities independently through descriptors and shared fixtures. Never enable install merely because check works; never treat a candidate matrix row or OSV ecosystem presence as implemented support. Required adapter design gaps must be resolved before claiming delivery. |
| architecture | A07 | Within a Git boundary (.git file or directory), discover the nearest optional .gh-dependency-pulse.cue from cwd upwards through the boundary directory inclusive. Without a Git boundary, inspect only cwd and ignore ancestor configuration. Load only one file; explicit CLI values override file values, which override built-ins. Invalid present configuration exits 2 before network or execution. Keep native installation cwd unchanged. |
| check | C11 | Project format accepts json or markdown and defaults to markdown for check and list. Explicit --format overrides it. List also accepts table via the CLI. On check --json aliases --format json. Reject conflicting output flags. Configured JSON must not affect install streams; install rejects explicit formatting flags. |
| install | I05 | Recommend latest stable tools without version enforcement, latest-release lookups or automatic upgrades. Respect pinned wrappers/toolchains; older installed versions are not rejected by age alone. Manager availability checks are independent of package-version selection and minimum-age policy. Check never probes local managers. |
| list | L01 | List direct dependencies for the explicitly selected ecosystem from conventional invocation-relative manifest paths only. Do not execute tools or traverse projects; optional lockfiles supply version evidence only. |
| list | L02 | Provide JSON, Markdown and table with uniform package, requirement, exact version and scope fields. Keep unknown versions and partial listings visible. |
| list | L03 | Without --check list is offline. With --check reuse standalone verdicts, age, latest version and advisory details for exact eligible releases. Missing exact versions or unsupported sources produce review without a provider request. |
| check | C12 | Standalone check reports nullable age_days/latest_version and advisory IDs with available titles. Latest lookup is best effort and cannot affect the exact-release verdict or change package selection. |

### 03 Shared implementation

#### 08 Check fields shared with project listings

Extend the standalone check result with `age_days` (nullable whole elapsed UTC days since publication), `latest_version` (nullable exact provider-reported default release for the same package identity) and `advisories` (sorted array of `{id, title}`, with a nullable title from the advisory summary). Retain `advisory_ids` for existing consumers. Use the same fields in Markdown and reuse them for list enrichment. Missing or unsafe advisory text does not remove the advisory or change the verdict.

For a versionless check, reuse the default already fetched. For an exact check displayed to the user, look up the provider default as best-effort metadata within the check deadline, reusing the response across rows for the same identity. Do not search or sort versions to infer a newest release. Failure of this informational lookup yields null and does not change the exact-version verdict. Age uses the checked release's publication date even if the age rule is disabled. Missing or future publication dates have null age. Install's internal check does not need an additional latest lookup. Keep the same bounded plain-text handling for titles as for advisory IDs.

#### 03 Implementation boundary

Share check policy, result types and the process runner across languages. Keep metadata adapters, static manifest readers and native manager integrations separate. Test with provider and manifest fixtures, an injected clock and transport, and native tool stubs. Use representative provider responses for each required ecosystem. Include Pub retraction and Swift identity and publication-date cases.

Kotlin installation requires bounded declaration editing for supported Gradle root builds and exact version insertion before resolution via the committed wrapper. Swift installation requires a tested SwiftPM sequence that adds and resolves the exact dependency. Verify that any declaration edits preserve unrelated content.

[npm install](https://docs.npmjs.com/cli/install/), [Cargo add](https://doc.rust-lang.org/cargo/commands/cargo-add.html), [uv add](https://docs.astral.sh/uv/reference/cli/#uv-add), [Go get](https://go.dev/ref/mod#go-get), [Gradle dependency declarations](https://docs.gradle.org/current/userguide/declaring_dependencies.html), [SwiftPM add-dependency](https://docs.swift.org/main/documentation/packagemanagerdocs/packageadddependency/), [Dart pub add](https://dart.dev/tools/pub/cmd/pub-add).

Keep direct dependencies to the modules in the recommendations table. Add each when its feature needs it. Reuse CUE for Dart YAML and keep Go, Swift and Gradle declaration handling scoped to the manifest matrix. Review any additional parser against representative fixtures before selecting it.

The GitHub star counts are adoption snapshots. Prefer actively maintained upstreams with over 500 stars. When introducing a module, pin a patched release compatible with the Go toolchain and build targets, check Go and upstream advisories, and scan the resolved direct and transitive dependencies. [Go vulnerability management](https://go.dev/doc/security/vuln/).

#### 10 Recommended Go dependencies

| feature | github_stars_snapshot | official_reference | recommended_package | repository_precedent | upstream_github | why |
| --- | --- | --- | --- | --- | --- | --- |
| CLI commands and flags | 44.8k | https://cobra.dev/docs/how-to-guides/working-with-flags/ | github.com/spf13/cobra | Used by gh-flarebyte with pflag | https://github.com/spf13/cobra | Models check, install and list as subcommands. Flag presence preserves explicit zero and distinguishes CLI overrides from defaults. Keep exit-code and stream handling in the CLI adapter. |
| Project defaults and Dart YAML | 6.3k | https://cuelang.org/docs/concept/how-cue-works-with-go/ | cuelang.org/go | gh-flarebyte uses local text extraction. The sibling Flyb project uses this module. | https://github.com/cue-lang/cue | Validate a single self-contained CUE file against a closed schema. Reuse the same module’s encoding/yaml package for pubspec.yaml and pubspec.lock, with fixture coverage for the supported dependency forms. |
| TOML manifests and locks | 2.0k | https://github.com/pelletier/go-toml | github.com/pelletier/go-toml/v2 | Used by gh-flarebyte | https://github.com/pelletier/go-toml | One stable v2 decoder covers Python and Cargo manifests and locks plus Gradle version catalogs. CUE’s TOML conversion API is documented as experimental. |

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

The language support matrix estimates the work needed for each operation. `must` is required for delivery. `nice-to-have` capabilities can be added independently. Java check is required and Java install is optional.

- `0-reuse` adds an alias to an existing adapter.
- `1-mapping` adds descriptors, validation or an argument template and fixtures.
- `2-adapter` adds a bounded metadata or declaration adapter.
- `3-design` needs an identity, metadata or project editing design before implementation.

Prioritize optional 0/1 effort checks such as Maven reuse, RubyGems and NuGet. Ratings assume the named prerequisite adapters exist. Enable each operation only after its own adapter and fixtures are ready.

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

#### 09 Conventional manifest paths for listing

| direct_declarations_and_scope | optional_companions | primary_manifest | selector | version_evidence |
| --- | --- | --- | --- | --- |
| dependencies prod; devDependencies dev; optionalDependencies optional; peerDependencies peer | npm-shrinkwrap.json or package-lock.json (shrinkwrap takes precedence) | package.json | npm | Matching root lock entries or exact public registry declaration |
| project.dependencies prod; dependency-groups dev for dev/test groups and unknown for other groups; project.optional-dependencies optional | uv.lock | pyproject.toml | pypi | Match root project and dependency conditions in lock; exact PEP 508 pin otherwise |
| dependencies prod; dev-dependencies dev; build-dependencies and target-specific scope as declared; optional dependencies optional | Cargo.lock | Cargo.toml | cargo | Match root package dependency edge and source; exact Cargo constraint otherwise; do not follow inherited workspace manifests |
| require without indirect marker; scope unknown; replacement directives retained as source evidence |  | go.mod | go | Exact module requirement unless a replacement changes its identity; go.sum is not a lockfile |
| dependencies prod; dev_dependencies dev; respect local dependency overrides | pubspec.lock | pubspec.yaml | pub | Matched hosted lock entry or exact hosted declaration; SDK/path/git references remain visible |
| Statically readable direct package dependencies; scope unknown unless explicitly supported | Package.resolved | Package.swift | swift | Match direct package URL to resolved pin or exact declaration; computed Swift declarations yield a partial listing |
| Recognized root dependency configurations; implementation/api/runtimeOnly prod; test configurations dev; other configurations unknown; include only catalog entries referenced by declarations | gradle/libs.versions.toml; gradle.lockfile | build.gradle.kts or build.gradle | gradle | Match lock configuration or exact literal/default catalog version; computed declarations yield partial listing |
| Direct project dependency entries; compile/runtime prod; test dev; optional optional; other scopes unknown |  | pom.xml | maven | Exact version or a statically resolved local property; no parent POM/imported BOM lookup |

#### 06 Package-manager availability and version guidance

After a passing check, verify the selected manager and known launch prerequisites before editing declarations or delegating. Resolve executables on PATH without running them. For Pub and SwiftPM, resolve the host tool. For Gradle, require the project's executable wrapper, its supporting files and Java.

If a prerequisite is missing, exit 1 with its name, one or two lines of macOS setup guidance and an official documentation link on stderr. Label macOS-only guidance and mention Homebrew when a suggestion requires it. Keep this guidance in the manager descriptor for all aliases and add it for each new install adapter.

Recommend current stable tools while honoring project pins. Availability checks do not compare versions, query tool releases, install or upgrade tools, or substitute another manager. If an installed tool fails during launch or execution, report the actual failure. Tool recommendations do not change package selection or age policy.

Example missing-uv diagnostic (stderr):

```text
uv was not found on PATH.
macOS: with Homebrew installed, run brew install uv; otherwise use the official standalone installer. Latest stable is recommended.
Official installation: https://docs.astral.sh/uv/getting-started/installation/
```

#### 07 Package-manager setup guidance

| availability_check | executable | macos_install_hint | manager | official_install_url |
| --- | --- | --- | --- | --- |
| Resolve npm on PATH | npm | Install the latest stable Node.js with npm using a Node version manager; follow the official macOS setup guide. | npm | https://docs.npmjs.com/downloading-and-installing-node-js-and-npm/ |
| Resolve cargo on PATH | cargo | Install the latest stable Rust toolchain with rustup; Cargo is included. | Cargo | https://doc.rust-lang.org/cargo/getting-started/installation.html |
| Resolve uv on PATH | uv | With Homebrew installed: brew install uv. Otherwise use the official standalone installer. | uv | https://docs.astral.sh/uv/getting-started/installation/ |
| Resolve go on PATH | go | Download and run the latest stable Go macOS installer (.pkg) for your Mac architecture. | Go | https://go.dev/doc/install |
| Resolve dart on PATH; Pub is bundled with Dart | dart | With Homebrew installed: brew tap dart-lang/dart then brew install dart. Otherwise follow the official SDK installation guide. | Dart Pub | https://dart.dev/get-dart |
| Resolve swift on PATH; SwiftPM is bundled with Swift | swift | Install the latest stable Swift toolchain using Swiftly via the official macOS guide; SwiftPM is included. | SwiftPM | https://www.swift.org/install/macos/ |
| Require executable committed wrapper and its JAR/properties in the supported project root; resolve java on PATH | ./gradlew | Restore the project Gradle wrapper from version control; if absent, have the project maintainer generate and commit it. Install a current compatible JDK if Java is missing. | Gradle wrapper | https://docs.gradle.org/current/userguide/gradle_wrapper.html |
| Resolve mvn and java on PATH | mvn | Install a current compatible JDK and Maven; with Homebrew installed, brew install maven is an option. | Maven | https://maven.apache.org/install.html |

#### 01 Shared API flow

1. Resolve the selector and validate the ecosystem's package identity and exact version. Reject option-like names, control characters and unsupported dependency forms.
2. Without an explicit version, request the adapter's declared default. For deps.dev use GET `/v3/systems/{system}/packages/{name}`. A definitive absence or ambiguous default yields `DEFAULT_UNAVAILABLE`. A failed lookup yields `METADATA_UNAVAILABLE` when the default is required.
3. Fetch the exact release. For deps.dev use GET `/v3/systems/{system}/packages/{name}/versions/{version}`. A definitive provider not-found response for the exact release yields `VERSION_UNAVAILABLE`. Transport errors, unsuccessful responses other than a definitive not-found, malformed metadata and identity mismatches yield `METADATA_UNAVAILABLE`. Normalize canonical identity, publication time and explicit deprecation or retraction evidence.
4. Once the release identity is established, query OSV with the canonical ecosystem, name and exact version. Follow continuation tokens even on pages with no findings. A query that cannot complete within the limits yields `ADVISORIES_INCOMPLETE`.
5. Apply the shared policy. An active applicable advisory, confirmed deprecation or confirmed release retraction yields fail, missing required evidence yields review, and complete clean evidence yields pass. Fail takes precedence over review.

Each ecosystem uses one metadata adapter without fallback. Pub uses the hosted pub.dev API and maps an explicit `retracted: true` for the exact release to `RELEASE_RETRACTED`. Report deprecation and retraction only where the adapter has positive evidence. Swift requires verified public repository URL, version, tag and publication mapping. deps.dev covers GO, RUBYGEMS, NPM, CARGO, MAVEN, PYPI and NUGET. OSV coverage alone does not provide release or age evidence. Escape every API path parameter. Use bounded, cancellable requests and report missing required evidence as review.

[deps.dev v3](https://docs.deps.dev/api/v3/), [OSV coverage](https://google.github.io/osv.dev/data/), [OSV exact-version queries](https://google.github.io/osv.dev/post-v1-query/), [Pub metadata API](https://pub.dev/help/api), [Pub hosted repository protocol](https://github.com/dart-lang/pub/blob/main/doc/repository-spec-v2.md).

### 04 Acceptance

#### Acceptance criteria

| concept | expected | id | scenario |
| --- | --- | --- | --- |
| check | Pass with the shared result schema and exit 0 | T01 | Clean mature release for each supported selector |
| check | Fail takes precedence over review and blocks installation | T02 | Applicable advisory, confirmed deprecation or confirmed retraction, with or without incomplete evidence |
| check | Review normally; zero skips only age rule | T03 | Too young or missing date; zero age option |
| check | Versionless check reviews with DEFAULT_UNAVAILABLE; exact check evaluates the requested release | T04 | Provider default missing, with and without an explicit version |
| check | Required metadata failures yield METADATA_UNAVAILABLE; incomplete advisory queries yield ADVISORIES_INCOMPLETE | T05 | Timeout, malformed or oversized response, or OSV pagination failure |
| check | Withdrawn ignored; active IDs deduplicated and sorted | T06 | Withdrawn and duplicate OSV records across pages |
| architecture | Provider receives the normalized and encoded identity | T07 | Scoped npm name, PyPI normalization, Go module path and Maven coordinate |
| install | Exact argv, current directory, inherited stdin and separate raw stdout/stderr; no extra check | T08 | Pass then install with stub executable for each native adapter |
| install | Blocked check and launch failure exit 1; preserve native exit status; cancellation is nonzero | T09 | Blocked check, manager launch failure, native exit or cancellation |
| install | No shell evaluation or file changes; unsupported operations fail before network | T10 | Invalid input, shell metacharacters, unsupported selector or unavailable install adapter |
| install | Progress reaches its native stream before exit; no whole-process buffering | T11 | Native stub writes progress then waits for stdin before exit |
| check | Own diagnostics omit credentials and raw bodies; identifiers cannot inject terminal instructions | T12 | Credential-bearing provider error or terminal controls in upstream identifiers |
| check | Built-in age/Markdown defaults and normal shared package-only checks; no local tool executes | T13 | Check outside Git without project config, manifest, lockfile or native tool |
| architecture | Equivalent aliases share results and adapters; Kotlin and Java share Maven checks but retain separate install and manifest adapters | T14 | Language and manager aliases across check, install and list |
| architecture | Shared check contract and exact-version installation with the default manager | T15 | Each required check and install capability |
| architecture | Install exits 2 before network access or mutation | T16 | Supported check with no install adapter |
| check | Missing or ambiguous provider evidence yields review; invalid user input exits 2 | T17 | Pub or Swift metadata missing a required date or default; ambiguous Swift release identity |
| install | Invoke the correct manager and preserve unrelated declaration content | T18 | Exact-version Kotlin and Swift installs |
| check | Built-ins fill absent fields; file supplies defaults; explicit flags win; --json and --format json agree and conflicting flags exit 2 | T19 | Missing, partial and complete project defaults; explicit overrides including zero and markdown |
| architecture | Inside Git use nearest file up to boundary inclusive; outside Git use only cwd and ignore ancestor configs; no merge; native cwd stays at invocation directory | T20 | Nested cwd with nearest config; multiple ancestors; .git file/directory boundary; standalone cwd with ancestor config but no Git boundary |
| architecture | Exit 2 before network/execution/mutation even with overriding CLI flags; help/version still work without loading config | T21 | Unreadable or invalid CUE; unknown fields; negative/fractional age; invalid format; imports or nonconcrete values |
| install | Configured age applies to the one pre-install check; configured format is ignored; native streams remain raw; explicit --json or --format exits 2 | T22 | Configured format json on install and explicit install formatting flags |
| install | Exit 1 before any install mutation; no automatic installation or fallback; stderr identifies missing component and gives brief macOS guidance plus an official URL; aliases share the same guidance | T23 | Passing check followed by missing manager, host executable, wrapper or known runtime |
| install | No tool version gate or upgrade; package selection and age policy are unchanged | T24 | Older installed manager or pinned wrapper |
| check | Neither path looks up or starts a native tool | T25 | Standalone check or blocked install with no manager installed |
| list | Read only the selected invocation-relative inputs; missing local manifest exits 2 | T26 | Go and Python manifests in a mixed repo and nested module |
| list | Only direct rows; exact versions include provenance; unknowns and scopes agree across formats | T27 | Direct and transitive lock entries, ranges, conflicts and distinct scopes |
| list | List only referenced catalog entries; mark unenumerable declarations partial and exit 1; complete empty list exits 0 | T28 | Gradle catalog references, computed Swift declarations and empty manifests |
| list | Plain list makes no requests; checked list reuses verdicts, age, latest and titles; review rows are retained at exit 1 | T29 | Offline list and list --check with repeated exact releases and unresolved rows |
| check | Latest is null without changing the verdict; advisory ID remains | T30 | Exact check with unavailable latest metadata or untitled advisory |
| check | Review and block installation | T31 | Incomplete evidence without an advisory, deprecation or retraction finding |
| list | List accepts table override; unsupported flag combinations exit 2 | T32 | Configured JSON and explicit table for list; standalone check with table; list age flag without --check |
| list | Keep all rows; unresolved or unsupported declarations make no requests; provider failure follows the shared verdict contract | T33 | List --check with unsupported source, conflicting lock evidence or failing provider |
| check | Definitive not-found yields VERSION_UNAVAILABLE; lookup failure yields METADATA_UNAVAILABLE | T34 | Exact release not found versus required metadata endpoint timing out or returning an invalid response |
| check | RELEASE_RETRACTED yields fail and blocks installation; absent retraction evidence does not emit the code | T35 | Exact Pub release is retracted, with or without an incomplete advisory query |
| check | Continue until completion; a later active finding yields fail; an unfinished query yields review in the absence of a fail reason | T36 | OSV page contains no findings and carries a continuation token |

### 05 Scope boundaries

#### Dependency and resolution boundaries

A dependency declaration or exact version passed to a native tool does not pin the transitive graph. Standalone check needs no local manifest, lockfile, installed environment or runtime. Native managers own resolution, lockfiles and recovery from failure.

### 06 Source navigation

#### Concept registry

| description | id | parent |
| --- | --- | --- |
| Shared package check | check |  |
| Native package manager delegation | install |  |
| Go implementation boundaries | architecture |  |
| Direct dependency listing and optional checks | list |  |

