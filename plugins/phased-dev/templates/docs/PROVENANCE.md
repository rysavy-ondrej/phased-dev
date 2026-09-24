# Test data provenance

Where every test-data set came from and how to regenerate it. If data is not in
git, this file is what git records in its place.

| Set | Path | Source | Produced by (tool + version) | Regenerate with | In git? |
| --- | --- | --- | --- | --- | --- |
| {{name}} | `data/...` | {{origin}} | {{tool x.y.z}} | {{command}} | no |

## Known defects in the data

Goldens can be stale or wrong. Record it here, with evidence, and say which set
is the authority for which field instead.
