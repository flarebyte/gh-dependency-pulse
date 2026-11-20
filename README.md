# gh-dependency-pulse

Dependency checks and native package installation through `gh dependency-pulse`, written in Go.

The project is currently at specification stage. Read the [new specification](doc/design/gh-dependency-pulse.md). Its editable [flyb source](doc/design-meta/app.cue) assembles the CSV inputs in `doc/design-meta/examples`.

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

Build and release settings describe the planned Go binary; those commands require the implementation and a Go module. `main.project.yaml` holds the initial development version.
