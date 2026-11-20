# gh-dep

Dependency checks and native package installation through `gh dep`, written in Go.

The project is currently at specification stage. Read the [new specification](doc/design/gh-dep.md). Its editable [flyb source](doc/design-meta/app.cue) assembles the CSV inputs in `doc/design-meta/examples`.

```sh
flyb validate --config doc/design-meta
flyb generate markdown --config doc/design-meta
```

The specification is self-contained. Its scope decisions explain the simplifications made when consolidating the earlier project requirements.
