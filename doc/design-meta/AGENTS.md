# Design sources

Edit app.cue and examples/*.csv; regenerate doc/design/gh-dep.md with flyb. The specification is self-contained; its scope decisions record intentional exclusions from the earlier project.

Start with examples/concepts.csv, then retrieve relevant records from the repository root:

```sh
rg -n 'check|install|architecture' doc/design-meta/examples/concepts.csv
rg -n -F ',install' doc/design-meta/examples -g '*.csv'
rg -n -F ',check' doc/design-meta/examples -g '*.csv'
```

Inspect headers and use a CSV parser for exact filtering. Also read the CLI and API notes in app.cue; focused ecosystems.csv has no concept column. Keep identifiers stable and records on one physical line. Validate CSV with the flyb-design-meta skill validator, then run:

```sh
flyb validate --config doc/design-meta
flyb generate markdown --config doc/design-meta
```
