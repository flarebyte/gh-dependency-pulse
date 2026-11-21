package flyb

{
  "source": "gh-dependency-pulse",
  "name": "gh-dependency-pulse-design",
  "modules": [
    "core"
  ],
  "reports": [
    {
      "title": "gh dependency-pulse specification",
      "filepath": "../design/gh-dependency-pulse.md",
      "description": "Small shared package checks and native installation.",
      "sections": [
        {
          "title": "Specification",
          "sections": [
            {
              "title": "01 Purpose and commands",
              "notes": [
                "dep.overview",
                "dep.cli",
                "dep.config",
                "dep.config-example",
                "dep.list"
              ]
            },
            {
              "title": "02 Check and install rules",
              "notes": [
                "dep.rules"
              ]
            },
            {
              "title": "03 Shared implementation",
              "notes": [
                "dep.providers",
                "dep.ecosystems",
                "dep.delivery",
                "dep.language-policy",
                "dep.languages",
                "dep.manager-preflight",
                "dep.manager-setup",
                "dep.check-detail",
                "dep.list-manifests"
              ]
            },
            {
              "title": "04 Acceptance",
              "notes": [
                "dep.acceptance"
              ]
            },
            {
              "title": "05 Scope decisions",
              "notes": [
                "dep.scope-decisions"
              ]
            },
            {
              "title": "06 Source navigation",
              "notes": [
                "dep.concepts"
              ]
            }
          ]
        }
      ]
    }
  ],
  "notes": [
    {
      "name": "dep.overview",
      "title": "01 Purpose and scope",
      "markdown": "Draft specification for a standalone Go GitHub CLI extension, executable `gh-dependency-pulse`, invoked as `gh dependency-pulse`. Check one direct package release using public metadata and known advisories, then optionally delegate installation. List direct project dependencies and optionally check their exact releases. A pass means only that the stated checks completed; it does not certify safety, malware absence, runtime compatibility or transitive dependencies.\n\nThis specification is the complete requirements source for this repository. The earlier project specifications have been consolidated here and removed; the scope decisions below record intentional simplifications. No existing implementation or regression suite must be carried over. Required delivery covers check and install for JavaScript, TypeScript, Python, Rust, Go, Dart, Swift and Kotlin. Java checks remain required; Java installation is optional. The language support matrix separates required capabilities from optional expansion and records adapter effort. These are delivery requirements, not claims of implemented support: the current code is a CLI skeleton. Dart, Swift and Kotlin install design work is required rather than deferred.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.cli",
      "title": "02 Command and output contract",
      "markdown": "```text\ngh dependency-pulse check <ecosystem> <package> [--version <exact>] [--min-age-days <days>] [--format json|markdown | --json]\ngh dependency-pulse install <ecosystem> <package> [--version <exact>] [--min-age-days <days>]\n```\n\nThe `<ecosystem>` argument accepts a package-manager/ecosystem selector or a language alias from the ecosystem mapping. Every supported language has one explicit default package manager. For example, `check npm lodash`, `check javascript lodash` and `check js lodash` are equivalent; `install js lodash` delegates to npm after the same check passes. Python defaults to uv: `pypi`, `python`, `py` and `uv` select the same PyPI checks and uv install command. Aliases are exact lowercase tokens and do not add support for other package managers or ecosystems. Resolve selectors to a descriptor containing both canonical ecosystem and default manager; retain the selected manager through installation. JSON `ecosystem` and Markdown output use the canonical ecosystem. Thus `kotlin`, `kt` and `gradle` use Maven checks and Gradle installation, while `java`, `maven` and `mvn` use the same checks with Maven as the default manager. Java/Maven installation remains optional and unsupported until its adapter is delivered. Package-manager defaults remain fixed by this specification, without installed-tool discovery. Optional project configuration supplies minimum-age and check/list format defaults only.\n\nSeparate version input avoids parsing scoped npm names and Maven coordinates. Versionless input checks the provider default only. An explicit request is never replaced. Do not add alternative-version searches, `--explain`, passthrough package-manager flags or configuration fields beyond the declared defaults. Reject unsupported flags before network or execution.\n\nMarkdown check output is a readable Markdown summary containing status, canonical package, exact version, age when known, reason codes and advisory IDs. `--format json` (or its `--json` alias) emits one object with `ecosystem`, `package`, nullable `version`, `status` (`pass|review|fail`), `reasons` (code strings), `advisory_ids`, `age_days`, `latest_version`, `advisories` and `coverage` (`direct-package-only`). Arrays are deduplicated and sorted; no timestamps or install-command envelope. Reason codes: `ADVISORY_FOUND`, `RELEASE_DEPRECATED`, `VERSION_UNAVAILABLE`, `DEFAULT_UNAVAILABLE`, `AGE_UNKNOWN`, `RELEASE_TOO_YOUNG`, `PUBLICATION_IN_FUTURE`, `METADATA_UNAVAILABLE`, `ADVISORIES_INCOMPLETE`. Multiple applicable reasons may coexist. Invalid CLI input is a stderr error without a check object.\n\nCheck exits 0 for pass, 1 for review/fail, 2 for invalid usage or unsupported operation. Install exits 1 for a blocked check or launch failure, 2 for invalid usage/unsupported operation, otherwise the native exit code; cancellation is nonzero. Install rejects explicit `--json` and `--format` flags; the project format default applies only to check and never wraps native streams. An undelivered install adapter returns unsupported before network access or mutation, with check-only/manual-install guidance. It never masquerades as a successful install. Kotlin installation is required and must not be rejected merely because its check ecosystem is Maven.\n\nUniform developer experience is a required public contract: `check python PACKAGE` and `check kotlin GROUP:ARTIFACT` accept the same flags and return the same result schema, status meanings, reason codes and exit semantics. Only package identifiers differ. `install LANGUAGE PACKAGE` always performs that same check once before invoking the default manager. Its outcome is conveyed by consistent CLI diagnostics and the native exit status; no language-specific command syntax or manager flags are required from the user. An installation success means the native operation succeeded, not proof of runtime compatibility or a post-install security scan. Native output remains unmodified and install does not emit JSON in this scope.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.providers",
      "title": "01 Shared API flow",
      "markdown": "Load and validate optional project defaults, then merge explicitly supplied CLI flags over them before any provider request or native execution.\n\n1. Resolve a supported canonical selector or listed alias using the ecosystem mapping and its default package manager, then validate package and optional exact version with ecosystem rules. Reject control characters, option-like names and unsupported dependency forms. Normalize only as required by the ecosystem.\n2. For deps.dev-backed ecosystems, with no exact version, GET deps.dev `/v3/systems/{system}/packages/{name}` and select its sole marked default. Missing or ambiguous default yields review. No version sorting or stable-release search.\n3. Fetch the exact release through the selected metadata adapter; for deps.dev use GET `/v3/systems/{system}/packages/{name}/versions/{version}`. Require the returned canonical identity to match the requested normalized identity; conflicting identities yield `METADATA_UNAVAILABLE`. Use `publishedAt` and `isDeprecated` where supplied; absent deprecation evidence does not establish absence of withdrawal. A not-found exact version yields `VERSION_UNAVAILABLE`.\n4. POST OSV `/v1/query` with `package.name`, mapped `package.ecosystem` and the exact `version`; follow pagination. Use the exact-version response rather than implementing advisory range evaluation. Query only when a release identity is established.\n5. Apply the same policy and format the result. Install consumes this result directly.\n\nURL-escape each path parameter; never interpolate unescaped package names. Reuse one HTTP transport and a cancellation context. Unit tests use recorded/minimal fixtures and an injected clock/HTTP transport; install tests use stub executables. No live APIs are required by the test suite.\n\nProvider coverage and freshness limit every result. deps.dev does not index every registry release; missing data remains review rather than trying fallback providers. Each ecosystem has one configured metadata path; dedicated Pub and Swift adapters are deliberate extensions, not registry fallback chains. API references: [deps.dev v3](https://docs.deps.dev/api/v3/) and [OSV exact-version queries](https://google.github.io/osv.dev/post-v1-query/).\n\nMetadata adapters produce one normalized release record (canonical ecosystem/name, exact version, publication time, deprecation/withdrawal evidence and completeness). All adapters use the same policy and OSV client. Pub uses the hosted pub.dev API; Swift needs a bounded public-repository metadata design with verified URL/version/tag identity and publication semantics before implementation. Do not execute Dart, Swift, Gradle or project manifests during check. Missing required evidence produces review, never a weaker language-specific pass. A provider without a declared default returns DEFAULT_UNAVAILABLE for versionless requests; do not invent version sorting.\n\nThe deps.dev v3 API documents GO, RUBYGEMS, NPM, CARGO, MAVEN, PYPI and NUGET. OSV covers more ecosystems, but advisory coverage alone does not establish release metadata or default/age evidence. References: [deps.dev systems](https://docs.deps.dev/api/v3/), [OSV coverage](https://google.github.io/osv.dev/data/), [Pub metadata API](https://pub.dev/help/api).",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.delivery",
      "title": "03 Implementation boundary",
      "markdown": "Implement in three small slices: shared clients/result/policy and table-driven checks; CLI Markdown/JSON and exit contract; gated native runner with argument-builder tests. Keep transport, policy and process execution independently testable, using a small internal metadata interface and descriptor/manager tables, without a public plugin framework. Only metadata normalization, ecosystem identity and manager integration vary; policy, results and execution handling remain shared. Validate Go adapter command syntax against the native tools when implementing.\n\nAcceptance is the table below plus deterministic documentation generation. Do not port the former deep planners, add migration shims or treat optional languages as required. All must-have rows must meet their check/install delivery requirements.\n\nNative command references: [npm install](https://docs.npmjs.com/cli/install/), [Cargo add](https://doc.rust-lang.org/cargo/commands/cargo-add.html), [uv add](https://docs.astral.sh/uv/reference/cli/#uv-add), [Go get](https://go.dev/ref/mod#go-get).\n\nFor Kotlin, a mapping to `gradlew` alone cannot add a dependency. Specify a bounded dependency declaration strategy (supported root build file format, dependency configuration and exact version insertion), test preservation of unrelated content and then delegate resolution to the committed wrapper. Avoid a general Gradle parser or arbitrary injected build scripts. Swift similarly requires a tested exact SwiftPM dependency-add/resolve sequence and documented toolchain capabilities without a version gate. Keep these design gates visible; placeholders or manual instructions do not satisfy must-have installation. Any bounded declaration editor is a scoped exception to native-only manifest ownership, not a general repair engine. [Gradle dependency declarations](https://docs.gradle.org/current/userguide/declaring_dependencies.html), [SwiftPM add-dependency](https://docs.swift.org/main/documentation/packagemanagerdocs/packageadddependency/), [Dart pub add](https://dart.dev/tools/pub/cmd/pub-add).",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.rules",
      "title": "Rules",
      "filepath": "examples/rules.csv",
      "arguments": [
        "format-csv=table"
      ],
      "labels": [
        "csv"
      ]
    },
    {
      "name": "dep.ecosystems",
      "title": "02 Ecosystem mapping",
      "filepath": "examples/ecosystems.csv",
      "arguments": [
        "format-csv=table"
      ],
      "labels": [
        "csv"
      ]
    },
    {
      "name": "dep.acceptance",
      "title": "Acceptance criteria",
      "filepath": "examples/acceptance.csv",
      "arguments": [
        "format-csv=table"
      ],
      "labels": [
        "csv"
      ]
    },
    {
      "name": "dep.concepts",
      "title": "Concept registry",
      "filepath": "examples/concepts.csv",
      "arguments": [
        "format-csv=table"
      ],
      "labels": [
        "csv"
      ]
    },
    {
      "name": "dep.scope-decisions",
      "title": "Scope decisions from consolidation",
      "markdown": "The previous product specification and implementation proposal have been reviewed in full. The rules, API flow, ecosystem mapping and acceptance table retain their relevant package-only boundary and native delegation behavior. The following differences are intentional:\n\n| Earlier requirement | Standalone scope |\n| --- | --- |\n| Repository identity, stars, owners, activity, Scorecard and name-lookalike checks | Removed; no reputation or provenance verdict is claimed. |\n| Stable-version ordering, four candidates and alternative recommendations | One explicit release or provider default only; no sorting or replacement. |\n| Registry-specific descriptions and lifecycle lookups | No extra calls for descriptions; deprecation is checked only as exposed by deps.dev. Comprehensive yanking/retraction detection is not claimed. |\n| Existing JSON compatibility, recommendation labels and --explain | One new pass/review/fail schema and concise reasons; no migration obligation. |\n| Repository configuration discovery | Optional .gh-dependency-pulse.cue supplies project defaults; explicit CLI flags override them. Checks still work without configuration or Git. |\n| Pub and Swift adapters | Now required: add bounded metadata adapters while preserving shared policy and results. |\n| Maven/Swift print-only manifest generation | No print-only success mode. Swift and Kotlin install are required; Java/Maven install is optional. Bounded native integration must actually add the checked dependency. |\n| Merge native stderr into stdout | Preserve native stdout and stderr separately; both stream immediately without normalization. |\n| Retain strict planners, archive inspectors and old tests/delivery records | No legacy code retention requirement or inherited implementation claims. |\n\nThe direct dependency version passed to the native tool does not pin the transitive graph. Go may update related requirements through its normal module selection. A package-manager failure is returned directly, without repair. Missing local graph, lockfile, artifact or runtime evidence never adds a review reason to a package check.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.language-policy",
      "title": "04 Language support priorities and adapter effort",
      "markdown": "`examples/language-support.csv` is the capability planning matrix: one row per language, capped at 20 practical candidates, not a popularity ranking. All rows are planned; none asserts implementation. `must` is required for delivery; `nice-to-have` may be independently admitted for check or install. The eight required check/install languages include all seven gh-flarebyte build languages plus JavaScript; Java checks preserve the existing scope.\n\nEffort is an engineering estimate of additional specialized code, not runtime cost or a guarantee: `0-reuse` = existing ecosystem/manager adapter and an alias only; `1-mapping` = descriptor, validation rules and/or exact argv template plus fixtures; `2-adapter` = bounded metadata client or declaration adapter; `3-design` = unresolved identity, metadata or project-editing design. Ratings are incremental against the named shared adapter; implement prerequisite adapters first. For example F# reuses NuGet only after the .NET adapter exists.\n\nPrioritize optional check rows at 0/1 effort with shared provider fixtures (especially NuGet, RubyGems and Maven reuse). Independently enable optional install only when its adapter is ready; check-only support is useful and does not require install. A CSV row is a candidate, not automatic CLI acceptance. The explicit delivered capability registry determines accepted aliases; unsupported selectors or operations fail with exit 2 before network/mutation. Add descriptors and tests for cheap extensions rather than language-specific policy branches. Every promoted adapter must supply sufficient identity, release/age and advisory evidence under the same policy. Additional providers with higher effort remain optional.\n\nThe ecosystem table records required adapter contracts; the language matrix records required and candidate capabilities. Keep the two consistent when promoting candidates. Package-manager aliases select a manager as well as an ecosystem; sharing Maven checks must not erase Kotlin/Gradle versus Java/Maven installation intent.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.languages",
      "title": "05 Language support matrix",
      "filepath": "examples/language-support.csv",
      "arguments": [
        "format-csv=table"
      ],
      "labels": [
        "csv"
      ]
    },
    {
      "name": "dep.config",
      "title": "03 Optional project defaults",
      "markdown": "An optional `.gh-dependency-pulse.cue` belongs in the consuming project root, alongside `.gh-flarebyte.cue` when that file exists. The two configurations are independent: neither file requires or imports the other. This specifies future CLI behavior; the current skeleton does not load configuration.\n\nSupported fields are `minAgeDays` (nonnegative integer, default 14) and `format` (`\"json\"` or `\"markdown\"`, default `\"markdown\"`). Both fields are optional. `minAgeDays` applies to check and the pre-install check; zero disables only the age rule. `format` applies to check and list. List also accepts `--format table` as an invocation-only override. Install ignores the configured format and continues to preserve native stdout/stderr and exit status. No language-specific default policy is introduced.\n\nPrecedence, per field: explicitly supplied CLI flag > nearest project configuration > built-in default. Track whether a flag was supplied so a parser's default value cannot overwrite configuration; explicit zero must override a positive configured age. Check accepts `--format json|markdown`; `--json` is shorthand for `--format json`. Reject conflicting simultaneous output flags with exit 2. `--format markdown` allows overriding a configured JSON default. Configuration never overrides an explicit package or version.\n\nDiscovery starts at the invocation working directory. First establish whether that directory lies within a Git boundary (an ancestor, including the invocation directory itself, containing a `.git` file or directory). If a boundary exists, search for `.gh-dependency-pulse.cue` from the invocation directory upwards through that boundary directory, inclusive, and use the nearest file. Never read configuration above the boundary. If no Git boundary exists, check only the invocation directory; do not inspect ancestor configuration files. Do not merge files. This supports nested project commands while keeping standalone invocations local. Absence is normal and uses built-in defaults; neither a language manifest nor `.gh-flarebyte.cue` is a discovery marker. Configuration lookup never changes the working directory used for installation.\n\nA present but unreadable, malformed, nonconcrete or schema-invalid file is an error: stderr diagnostic and exit 2 before network access, native execution or mutation. Reject unknown fields, negative/fractional ages and unknown formats even when a CLI flag would override the invalid field. Parse only this single self-contained CUE file as data with a closed schema; allow no imports, external file reads or environment-driven evaluation. Do not interpret shell commands or load surrounding CUE files. Root `--help` and `--version` remain available without reading project configuration. No user-global config, environment overrides, multi-file layering or `--config` flag is introduced in this scope.\n\nFor example, configuring `minAgeDays: 30` and `format: \"json\"` makes `gh dependency-pulse check python requests` use those defaults. `gh dependency-pulse check python requests --min-age-days 0 --format markdown` overrides both for that invocation. `gh dependency-pulse install python requests` uses the configured age but preserves the normal native output contract.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.config-example",
      "title": "04 Project defaults example",
      "filepath": "examples/project-defaults.cue",
      "labels": [
        "example"
      ]
    },
    {
      "name": "dep.manager-preflight",
      "title": "06 Package-manager availability and version guidance",
      "markdown": "Before delegating installation or changing a dependency declaration, verify that the selected manager is available. This preflight runs after the shared package check passes and before any installation mutation. For ordinary managers, resolve the executable on PATH without spawning it; do not probe every manager or run --version to enforce a release. For bundled managers, resolve their host executable (dart for Pub, swift for SwiftPM). Gradle requires the project's committed executable wrapper and supporting files, plus Java; do not silently replace it with global Gradle. Check-only commands never require a local package manager.\n\nIf the manager or a required launcher/runtime is missing, emit a concise stderr diagnostic naming the missing component, followed by one or two lines of actionable macOS installation guidance and a link to official installation documentation. Return exit 1 without starting installation or editing declarations. Keep guidance in the manager descriptor, shared by all its language aliases; the setup table records the initial managers. When adding any optional install adapter, add equivalent executable checks, macOS guidance and an official URL before advertising install support. Homebrew commands are suggestions only and must say when Homebrew is a prerequisite; otherwise point to the official installer route. Do not automatically install tools, open links, bootstrap wrappers or change PATH. Non-macOS diagnostics still identify the missing executable and link to official cross-platform documentation; label any macOS-only hint as such.\n\nRecommend the latest stable CLI, SDK, runtime and package-manager releases in documentation and missing-tool guidance. This is advice, not enforcement: no latest-release network queries, mandatory upgrades, version gates, auto-updates or warnings solely because an installed version is older. Respect project-pinned wrappers/toolchains and native compatibility constraints. If an installed tool cannot execute the required operation, report its actual failure with relevant official guidance rather than proactively rejecting its version. A missing runtime discovered only at native startup is a launch failure, not proof that the manager itself is absent.\n\nThis recommendation does not override package selection: never replace an explicit package version or the declared provider default with a guessed newest version. The configured minimum-age policy still applies, including to a newly published latest release. Preserve native output and exit status once launched.\n\nExample missing-uv diagnostic (stderr):\n\n```text\nuv was not found on PATH.\nmacOS: with Homebrew installed, run brew install uv; otherwise use the official standalone installer. Latest stable is recommended.\nOfficial installation: https://docs.astral.sh/uv/getting-started/installation/\n```\n\nInstallation routes are maintained from the linked official documentation; do not download the guidance dynamically at runtime. The setup CSV is specification data, not an instruction for this development session to install tools.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.manager-setup",
      "title": "07 Package-manager setup guidance",
      "filepath": "examples/package-manager-setup.csv",
      "arguments": [
        "format-csv=table"
      ],
      "labels": [
        "csv"
      ]
    },
    {
      "name": "dep.list",
      "title": "05 List direct project dependencies",
      "markdown": "```text\ngh dependency-pulse list <ecosystem> [--check [--min-age-days <days>]] [--format json|markdown|table]\n```\n\nUse the same language and manager aliases as check and install. An explicit selector chooses one manifest adapter, so `list go` and `list python` can inspect the same directory independently. Kotlin/Gradle and Java/Maven share a check ecosystem but select different manifest adapters.\n\nRun from the project or module directory that owns the manifest. Read only the selected adapter's conventional paths relative to the invocation directory, including an explicitly listed companion file when present. Do not walk ancestors, scan subprojects or workspaces, follow links outside the invocation directory, or inspect installed environments. The Gradle version catalog is a fixed relative path used by the root build file. If both supported Gradle build files are present, report an ambiguous manifest and exit 2. Project defaults still follow their own Git-bounded discovery rules. Missing or unreadable required manifests, invalid syntax and unsupported selectors produce a diagnostic and exit 2. An empty supported manifest produces an empty listing. Parse supported declaration forms statically. When declarations cannot be enumerated completely, mark the listing partial and report why. No package manager, manifest code, install or resolver runs.\n\nList direct declarations only. A lockfile may supply version evidence for a declaration but must not add rows for transitive dependencies. Show each package's name, declared requirement, scope and exact version when known. Prefer an unambiguously matched locked version consistent with the declaration and source. Otherwise use an explicit exact declared version when there is no conflicting lock evidence. Keep ranges, floating references and conflicts visible without guessing an exact version. Where one declaration matches several locked versions for different environments, leave the exact version unknown rather than selecting an environment. Label version provenance as locked, declared or unknown. A locked or declared version is not a measurement of what's installed.\n\nNormalize scope to `prod`, `dev`, `optional`, `peer` or `unknown` where the manifest supports that distinction. Preserve the original group or configuration name where present. Keep separate declarations for separate scopes or conditions. In particular, Go's indirect marker describes dependency directness and does not imply dev scope. Omit indirect Go requirements from this direct-only view.\n\nJSON emits one object with `ecosystem`, `manifest` (relative path), `complete`, `warnings` and `packages`. Each row contains `package`, `requirement` (nullable), `version` (nullable), `version_source` (`locked|declared|unknown`), `scope` and `native_scope` (nullable). Markdown renders a Markdown table. Table renders aligned terminal columns. Both human formats display unknown values as a dash. Sort rows by package, scope, native scope, requirement and version, with stable manifest order for ties. Escape untrusted names, requirements and titles for the output format, and omit credentials and sensitive source details. The project `format` default applies to list too, with Markdown as the built-in default. Table is available via the list flag only.\n\nWithout `--check`, listing is local and offline. With it, check each unique eligible public package and exact release once using the same policy and age defaults as standalone check. `--min-age-days` overrides that default only with `--check`. Rows with missing exact versions or unsupported sources show `review` with an explanation and send no provider requests for those declarations. Never send raw manifest source URLs or credentials to a provider. A validated public Swift package identity can use the existing Swift check adapter. Bound enrichment work and concurrency and respect cancellation. A provider error yields the same review/fail semantics as standalone check and does not erase other rows.\n\nWith `--check`, add `status`, `reasons`, `age_days`, `latest_version` and `advisories` to each row. Use the standalone check fields for checked rows. List-only reasons are `EXACT_VERSION_UNKNOWN` and `UNSUPPORTED_SOURCE`. Advisory entries contain IDs and titles when supplied. Show Pass, Review or Fail in human output. Show the currently declared or locked release alongside its publication age and provider-reported latest version when known. The latest comparison is informational and does not affect the verdict, satisfy a declared range, suggest a compatible upgrade or replace the release being checked. This combines the direct-version comparison of npm outdated with advisory visibility from npm audit while keeping the existing direct-package policy. [npm outdated](https://docs.npmjs.com/cli/commands/npm-outdated/) and [npm audit](https://docs.npmjs.com/cli/commands/npm-audit/).\n\nExit 0 for a complete listing with every requested check passing (or no checks requested). Exit 1 for a partial listing or any review/fail row when checks were requested. Preserve the listing on exit 1. Exit 2 for command, configuration or manifest errors that prevent listing.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.check-detail",
      "title": "08 Check fields shared with project listings",
      "markdown": "Extend the standalone check result with `age_days` (nullable whole elapsed UTC days since publication), `latest_version` (nullable exact provider-reported default release for the same package identity) and `advisories` (sorted array of `{id, title}`, with a nullable title from the advisory summary). Retain `advisory_ids` for existing consumers. Use the same fields in Markdown and reuse them for list enrichment. Missing or unsafe advisory text does not remove the advisory or change the verdict.\n\nFor a versionless check, reuse the default already fetched. For an exact check displayed to the user, look up the provider default as best-effort metadata within the check deadline, reusing the response across rows for the same identity. Do not search or sort versions to infer a newest release. Failure of this informational lookup yields null and does not change the exact-version verdict. Age uses the checked release's publication date even if the age rule is disabled. Missing or future publication dates have null age. Install's internal check does not need an additional latest lookup. Keep the same bounded plain-text handling for titles as for advisory IDs.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.list-manifests",
      "title": "09 Conventional manifest paths for listing",
      "filepath": "examples/list-manifests.csv",
      "arguments": [
        "format-csv=table"
      ],
      "labels": [
        "csv"
      ]
    }
  ],
  "relationships": [],
  "argumentRegistry": {
    "version": "1",
    "arguments": [
      {
        "name": "format-csv",
        "valueType": "enum",
        "scopes": [
          "note"
        ],
        "allowedValues": [
          "table",
          "raw"
        ]
      }
    ]
  }
}
