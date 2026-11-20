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
                "dep.cli"
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
                "dep.delivery"
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
      "markdown": "Draft specification for a standalone Go GitHub CLI extension, executable `gh-dependency-pulse`, invoked as `gh dependency-pulse`. Check one direct package release using public metadata and known advisories, then optionally delegate installation. A pass means only that the stated checks completed; it does not certify safety, malware absence, runtime compatibility or transitive dependencies.\n\nThis specification is the complete requirements source for this repository. The earlier project specifications have been consolidated here and removed; the scope decisions below record intentional simplifications. No existing implementation or regression suite must be carried over. First delivery covers npm, Cargo, PyPI, Go and Maven checks; native install covers the first four. Pub and Swift are deferred to avoid bespoke metadata pipelines.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.cli",
      "title": "02 Command and output contract",
      "markdown": "```text\ngh dependency-pulse check <ecosystem> <package> [--version <exact>] [--min-age-days <days>] [--json]\ngh dependency-pulse install <ecosystem> <package> [--version <exact>] [--min-age-days <days>]\n```\n\nThe `<ecosystem>` argument accepts a package-manager/ecosystem selector or a language alias from the ecosystem mapping. Every supported language has one explicit default package manager. For example, `check npm lodash`, `check javascript lodash` and `check js lodash` are equivalent; `install js lodash` delegates to npm after the same check passes. Python defaults to uv: `pypi`, `python`, `py` and `uv` select the same PyPI checks and uv install command. Aliases are exact lowercase tokens and do not add support for other package managers or ecosystems. Normalize aliases to the canonical selector before checking or installing; JSON `ecosystem` and text output use the canonical selector. Java/Maven aliases still support check only. Defaults are fixed by this specification, without configuration or installed-tool discovery.\n\nSeparate version input avoids parsing scoped npm names and Maven coordinates. Versionless input checks the provider default only. An explicit request is never replaced. Do not add alternative-version searches, `--explain`, passthrough package-manager flags or configuration files in v1. Reject unsupported flags before network or execution.\n\nText check output contains status, canonical package, exact version, age when known, reason codes and advisory IDs. `--json` emits one object with `ecosystem`, `package`, nullable `version`, `status` (`pass|review|fail`), `reasons` (code strings), `advisory_ids` and `coverage` (`direct-package-only`). Arrays are deduplicated and sorted; no timestamps or install-command envelope. Reason codes: `ADVISORY_FOUND`, `RELEASE_DEPRECATED`, `VERSION_UNAVAILABLE`, `DEFAULT_UNAVAILABLE`, `AGE_UNKNOWN`, `RELEASE_TOO_YOUNG`, `PUBLICATION_IN_FUTURE`, `METADATA_UNAVAILABLE`, `ADVISORIES_INCOMPLETE`. Multiple applicable reasons may coexist. Invalid CLI input is a stderr error without a check object.\n\nCheck exits 0 for pass, 1 for review/fail, 2 for invalid usage or unsupported operation. Install exits 1 for a blocked check or launch failure, 2 for invalid usage/unsupported operation, otherwise the native exit code; cancellation is nonzero. Install rejects `--json`. A Maven install returns unsupported with guidance to run check and install manually; it does not masquerade as a successful install.",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.providers",
      "title": "01 Shared API flow",
      "markdown": "1. Resolve a supported canonical selector or listed alias using the ecosystem mapping and its default package manager, then validate package and optional exact version with ecosystem rules. Reject control characters, option-like names and unsupported dependency forms. Normalize only as required by the ecosystem.\n2. With no exact version, GET deps.dev `/v3/systems/{system}/packages/{name}` and select its sole marked default. Missing or ambiguous default yields review. No version sorting or stable-release search.\n3. GET `/v3/systems/{system}/packages/{name}/versions/{version}`. Require the returned canonical identity to match the requested normalized identity; conflicting identities yield `METADATA_UNAVAILABLE`. Use `publishedAt` and `isDeprecated` where supplied; absent deprecation evidence does not establish absence of withdrawal. A not-found exact version yields `VERSION_UNAVAILABLE`.\n4. POST OSV `/v1/query` with `package.name`, mapped `package.ecosystem` and the exact `version`; follow pagination. Use the exact-version response rather than implementing advisory range evaluation. Query only when a release identity is established.\n5. Apply the same policy and format the result. Install consumes this result directly.\n\nURL-escape each path parameter; never interpolate unescaped package names. Reuse one HTTP transport and a cancellation context. Unit tests use recorded/minimal fixtures and an injected clock/HTTP transport; install tests use stub executables. No live APIs are required by the test suite.\n\nProvider coverage and freshness limit every result. deps.dev does not index every registry release; missing data remains review rather than starting a second discovery system. API references: [deps.dev v3](https://docs.deps.dev/api/v3/) and [OSV exact-version queries](https://google.github.io/osv.dev/post-v1-query/).",
      "labels": [
        "spec"
      ]
    },
    {
      "name": "dep.delivery",
      "title": "03 Implementation boundary",
      "markdown": "Implement in three small slices: shared clients/result/policy and table-driven checks; CLI text/JSON and exit contract; gated native runner with argument-builder tests. Keep transport, policy and process execution independently testable, without a general provider/plugin abstraction. Only native argument construction and ecosystem identity rules vary. Validate Go adapter command syntax against the native tools when implementing.\n\nAcceptance is the table below plus deterministic documentation generation. Do not port the former deep planners, add migration shims or promise every language in the first release.\n\nNative command references: [npm install](https://docs.npmjs.com/cli/install/), [Cargo add](https://doc.rust-lang.org/cargo/commands/cargo-add.html), [uv add](https://docs.astral.sh/uv/reference/cli/#uv-add), [Go get](https://go.dev/ref/mod#go-get).",
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
      "markdown": "The previous product specification and implementation proposal have been reviewed in full. The rules, API flow, ecosystem mapping and acceptance table retain their relevant package-only boundary and native delegation behavior. The following differences are intentional:\n\n| Earlier requirement | Standalone scope |\n| --- | --- |\n| Repository identity, stars, owners, activity, Scorecard and name-lookalike checks | Removed; no reputation or provenance verdict is claimed. |\n| Stable-version ordering, four candidates and alternative recommendations | One explicit release or provider default only; no sorting or replacement. |\n| Registry-specific descriptions and lifecycle lookups | No extra calls for descriptions; deprecation is checked only as exposed by deps.dev. Comprehensive yanking/retraction detection is not claimed. |\n| Existing JSON compatibility, recommendation labels and --explain | One new pass/review/fail schema and concise reasons; no migration obligation. |\n| Repository configuration discovery | Explicit age flag with a 14-day default; checks also work outside Git repositories. |\n| Pub and GitHub-only Swift adapters | Deferred; no separate metadata pipeline in the first delivery. |\n| Maven/Swift print-only manifest generation | Maven check remains; install is explicitly unsupported. No manifest generation or editing. |\n| Merge native stderr into stdout | Preserve native stdout and stderr separately; both stream immediately without normalization. |\n| Retain strict planners, archive inspectors and old tests/delivery records | No legacy code retention requirement or inherited implementation claims. |\n\nThe direct dependency version passed to the native tool does not pin the transitive graph. Go may update related requirements through its normal module selection. A package-manager failure is returned directly, without repair. Missing local graph, lockfile, artifact or runtime evidence never adds a review reason to a package check.",
      "labels": [
        "spec"
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
