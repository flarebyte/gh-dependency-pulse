# gh-dependency-pulse

Dependency checks and native package installation through `gh dependency-pulse`, written in Go.

The project currently provides a Go CLI skeleton. Help and version output work; `check` and `install` return exit code 2 with a not-implemented diagnostic. Read the [specification](doc/design/gh-dependency-pulse.md) for the planned behavior. Its editable [flyb source](doc/design-meta/app.cue) assembles the CSV inputs in `doc/design-meta/examples`.

```sh
flyb validate --config doc/design-meta
flyb generate markdown --config doc/design-meta
```

The specification is self-contained. Its scope decisions explain the simplifications made when consolidating the earlier project requirements.

Repository settings are managed by [`.gh-flarebyte.cue`](.gh-flarebyte.cue) using gh-flarebyte v0.30.0:

```sh
gh flarebyte config validate
gh flarebyte repo audit
# Apply intentional settings changes to GitHub:
gh flarebyte repo update
```

gh-flarebyte is used locally for development and repository administration. No GitHub Actions workflow is required for these local commands.

With Go 1.24.1 or later and gh-flarebyte installed, run from the repository root:

```sh
gh flarebyte test
gh flarebyte lint
gh flarebyte build
go run ./cmd/gh-dependency-pulse --help
```

Build artifacts and checksums are written under `build/` for the targets in `.gh-flarebyte.cue`. `cmd/gh-dependency-pulse` owns the executable entry point; `internal/cli` owns command dispatch and tests. No external Go dependencies are needed. `main.project.yaml` holds the initial development version.
