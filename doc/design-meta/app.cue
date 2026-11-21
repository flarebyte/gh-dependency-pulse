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
                "dep.rules",
                "dep.reason-codes"
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
                "dep.list-manifests",
                "dep.dependencies"
              ]
            },
            {
              "title": "04 Acceptance",
              "notes": [
                "dep.acceptance"
              ]
            },
            {
              "title": "05 Scope boundaries",
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
      "markdown": "Use `gh dependency-pulse` to check one public package release, install the checked release, or list direct project dependencies. Checks cover release metadata and known advisories for the direct package. A pass does not certify runtime compatibility, absence of malware or the transitive graph.\n\nThe language support matrix defines required and optional check/install capabilities. The manifest matrix defines the initial listing adapters.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.cli",
      "title": "02 Command and output contract",
      "markdown": "```text\ngh dependency-pulse check <ecosystem> <package> [--version <exact>] [--min-age-days <days>] [--format json|markdown | --json]\ngh dependency-pulse install <ecosystem> <package> [--version <exact>] [--min-age-days <days>]\ngh dependency-pulse list <ecosystem> [--check [--min-age-days <days>]] [--format json|markdown|table]\n```\n\nSelectors use the same lowercase language and manager aliases across commands. For example, `check npm lodash`, `check javascript lodash` and `check js lodash` are equivalent. Kotlin/Gradle and Java/Maven share the canonical `maven` check ecosystem but retain distinct managers and manifest adapters. The flags, result schema and policy are the same across languages.\n\nCheck uses the requested exact version or the provider default when the version is omitted. The result uses the canonical ecosystem regardless of alias.\n\nMarkdown summarizes the same check result as JSON. `--format json` (or its `--json` alias) emits one object with `ecosystem`, `package`, nullable `version`, `status` (`pass|review|fail`), `reasons` (code strings), `advisory_ids`, `age_days`, `latest_version`, `advisories` and `coverage` (`direct-package-only`). Arrays are deduplicated and sorted. The reason code table defines each trigger. Multiple reasons may apply, and fail takes precedence over review.\n\nCheck exits 0 for pass and 1 for review or fail. Install runs the same check once and delegates only an exact release that passes. A blocked check or launch failure exits 1; a launched manager's exit status is preserved, and cancellation is nonzero. Install preserves native stdout and stderr and rejects formatting flags.\n\nInvalid usage and unsupported operations exit 2 before provider calls, native execution or changes. Diagnostics go to stderr. An unsupported install includes separate check and manual-install guidance.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.providers",
      "title": "01 Shared API flow",
      "markdown": "1. Resolve the selector and validate the ecosystem's package identity and exact version. Reject option-like names, control characters and unsupported dependency forms.\n2. Without an explicit version, request the adapter's declared default. For deps.dev use GET `/v3/systems/{system}/packages/{name}`. A definitive absence or ambiguous default yields `DEFAULT_UNAVAILABLE`. A failed lookup yields `METADATA_UNAVAILABLE` when the default is required.\n3. Fetch the exact release. For deps.dev use GET `/v3/systems/{system}/packages/{name}/versions/{version}`. A definitive provider not-found response for the exact release yields `VERSION_UNAVAILABLE`. Transport errors, unsuccessful responses other than a definitive not-found, malformed metadata and identity mismatches yield `METADATA_UNAVAILABLE`. Normalize canonical identity, publication time and explicit deprecation or retraction evidence.\n4. Once the release identity is established, query OSV with the canonical ecosystem, name and exact version. Follow continuation tokens even on pages with no findings. A query that cannot complete within the limits yields `ADVISORIES_INCOMPLETE`.\n5. Apply the shared policy. An active applicable advisory, confirmed deprecation or confirmed release retraction yields fail, missing required evidence yields review, and complete clean evidence yields pass. Fail takes precedence over review.\n\nEach ecosystem uses one metadata adapter without fallback. Pub uses the hosted pub.dev API and maps an explicit `retracted: true` for the exact release to `RELEASE_RETRACTED`. Report deprecation and retraction only where the adapter has positive evidence. Swift requires verified public repository URL, version, tag and publication mapping. deps.dev covers GO, RUBYGEMS, NPM, CARGO, MAVEN, PYPI and NUGET. OSV coverage alone does not provide release or age evidence. Escape every API path parameter. Use bounded, cancellable requests and report missing required evidence as review.\n\n[deps.dev v3](https://docs.deps.dev/api/v3/), [OSV coverage](https://google.github.io/osv.dev/data/), [OSV exact-version queries](https://google.github.io/osv.dev/post-v1-query/), [Pub metadata API](https://pub.dev/help/api), [Pub hosted repository protocol](https://github.com/dart-lang/pub/blob/main/doc/repository-spec-v2.md).",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.delivery",
      "title": "03 Implementation boundary",
      "markdown": "Share check policy, result types and the process runner across languages. Keep metadata adapters, static manifest readers and native manager integrations separate. Test with provider and manifest fixtures, an injected clock and transport, and native tool stubs. Use representative provider responses for each required ecosystem. Include Pub retraction and Swift identity and publication-date cases.\n\nKotlin installation requires bounded declaration editing for supported Gradle root builds and exact version insertion before resolution via the committed wrapper. Swift installation requires a tested SwiftPM sequence that adds and resolves the exact dependency. Verify that any declaration edits preserve unrelated content.\n\n[npm install](https://docs.npmjs.com/cli/install/), [Cargo add](https://doc.rust-lang.org/cargo/commands/cargo-add.html), [uv add](https://docs.astral.sh/uv/reference/cli/#uv-add), [Go get](https://go.dev/ref/mod#go-get), [Gradle dependency declarations](https://docs.gradle.org/current/userguide/declaring_dependencies.html), [SwiftPM add-dependency](https://docs.swift.org/main/documentation/packagemanagerdocs/packageadddependency/), [Dart pub add](https://dart.dev/tools/pub/cmd/pub-add).\n\nKeep direct dependencies to the modules in the recommendations table. Add each when its feature needs it. Reuse CUE for Dart YAML and keep Go, Swift and Gradle declaration handling scoped to the manifest matrix. Review any additional parser against representative fixtures before selecting it.\n\nThe GitHub star counts are adoption snapshots. Prefer actively maintained upstreams with over 500 stars. When introducing a module, pin a patched release compatible with the Go toolchain and build targets, check Go and upstream advisories, and scan the resolved direct and transitive dependencies. [Go vulnerability management](https://go.dev/doc/security/vuln/).",
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
      "title": "Dependency and resolution boundaries",
      "markdown": "A dependency declaration or exact version passed to a native tool does not pin the transitive graph. Standalone check needs no local manifest, lockfile, installed environment or runtime. Native managers own resolution, lockfiles and recovery from failure.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.language-policy",
      "title": "04 Language support priorities and adapter effort",
      "markdown": "The language support matrix estimates the work needed for each operation. `must` is required for delivery. `nice-to-have` capabilities can be added independently. Java check is required and Java install is optional.\n\n- `0-reuse` adds an alias to an existing adapter.\n- `1-mapping` adds descriptors, validation or an argument template and fixtures.\n- `2-adapter` adds a bounded metadata or declaration adapter.\n- `3-design` needs an identity, metadata or project editing design before implementation.\n\nPrioritize optional 0/1 effort checks such as Maven reuse, RubyGems and NuGet. Ratings assume the named prerequisite adapters exist. Enable each operation only after its own adapter and fixtures are ready.",
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
      "markdown": "Optional `.gh-dependency-pulse.cue` can sit beside `.gh-flarebyte.cue` in the project root. Supported fields are:\n\n- `minAgeDays`: nonnegative integer, default 14. Applies to standalone check, install's precheck and `list --check`. Zero disables only the age rule.\n- `format`: `json` or `markdown`, default `markdown`. Applies to check and list. List also accepts `table` via `--format`.\n\nExplicit flags override the file, which overrides built-ins. An explicit zero is an override. On check, `--json` aliases `--format json`. Conflicting format flags exit 2.\n\nInside Git, look for the nearest file from the invocation directory through the nearest ancestor containing a `.git` file or directory, inclusive. Outside Git, inspect only the invocation directory. Use one file without merging and keep the invocation directory for native execution.\n\nValidate the entire file before applying overrides. Read one self-contained CUE file with a closed schema and concrete values. Reject imports, external reads, unknown fields and invalid values. An unreadable or invalid file exits 2 before network access, native execution or mutation. Root help and version bypass config loading.",
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
      "markdown": "After a passing check, verify the selected manager and known launch prerequisites before editing declarations or delegating. Resolve executables on PATH without running them. For Pub and SwiftPM, resolve the host tool. For Gradle, require the project's executable wrapper, its supporting files and Java.\n\nIf a prerequisite is missing, exit 1 with its name, one or two lines of macOS setup guidance and an official documentation link on stderr. Label macOS-only guidance and mention Homebrew when a suggestion requires it. Keep this guidance in the manager descriptor for all aliases and add it for each new install adapter.\n\nRecommend current stable tools while honoring project pins. Availability checks do not compare versions, query tool releases, install or upgrade tools, or substitute another manager. If an installed tool fails during launch or execution, report the actual failure. Tool recommendations do not change package selection or age policy.\n\nExample missing-uv diagnostic (stderr):\n\n```text\nuv was not found on PATH.\nmacOS: with Homebrew installed, run brew install uv; otherwise use the official standalone installer. Latest stable is recommended.\nOfficial installation: https://docs.astral.sh/uv/getting-started/installation/\n```",
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
      "markdown": "Select one manifest adapter with the same aliases as check and install. For example, `list go` and `list python` can inspect the same directory independently.\n\nRead the selected adapter’s conventional files relative to the invocation directory, as listed in the manifest matrix. Exclude ancestors, workspaces, subprojects, installed environments and links outside that directory. If both Gradle build files exist, report ambiguity and exit 2. Parse declarations statically. Report a partial listing if some declarations cannot be enumerated. Missing, unreadable or invalid required manifests exit 2. Config discovery follows its separate Git boundary rules.\n\nList direct declarations only. Prefer a unique locked release that matches the declaration and source, then an exact declaration if no lock evidence conflicts. Keep unresolved requirements visible with null versions. Version provenance is `locked`, `declared` or `unknown`.\n\nMap scope to `prod`, `dev`, `optional`, `peer` or `unknown`, retaining the original group or configuration where available. Keep separate declarations for separate scopes or conditions.\n\nJSON emits one object with `ecosystem`, `manifest` (relative path), `complete`, `warnings` and `packages`. Each row contains `package`, `requirement` (nullable), `version` (nullable), `version_source` (`locked|declared|unknown`), `scope` and `native_scope` (nullable). Markdown renders a Markdown table. Table renders aligned terminal columns. Both human formats display unknown values as a dash. Sort rows by package, scope, native scope, requirement and version, with stable manifest order for ties. Escape untrusted names, requirements and titles for the output format, and omit credentials and sensitive source details.\n\nPlain list is offline. With `--check`, reuse the standalone check once per unique eligible public package and exact release. `--min-age-days` is accepted only with `--check`. Unresolved versions and unsupported sources yield review without provider requests for those rows. Send only validated public package identities. Bound enrichment and concurrency, respect cancellation, and retain other rows if a check fails. Listing never runs project code or a package manager.\n\nWith `--check`, add `status`, `reasons`, `age_days`, `latest_version` and `advisories` to each row. The reason code table identifies list-only codes. Unavailable age and latest version are null, and unavailable advisory entries use an empty array. Show Pass, Review or Fail in human output.\n\nExit 0 for a complete listing with every requested check passing (or no checks requested). Exit 1 for a partial listing or any review/fail row when checks were requested. Preserve the listing on exit 1. Exit 2 for command, configuration or manifest errors that prevent listing.",
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
    },
    {
      "name": "dep.reason-codes",
      "title": "Reason codes",
      "filepath": "examples/reason-codes.csv",
      "arguments": [
        "format-csv=table"
      ],
      "labels": [
        "csv"
      ]
    },
    {
      "name": "dep.dependencies",
      "title": "10 Recommended Go dependencies",
      "filepath": "examples/dependency-recommendations.csv",
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
