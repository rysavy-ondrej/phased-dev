# Data catalog

What test and demo data this project has, what it looks like, what it is good
for, and how to make more. Written by the `test-data` skill from the owner's
corpus (if any) and from the spec; read by every agent before building a
fixture. **Describes** the data — never copies sensitive content into git.

| File | Says |
| --- | --- |
| **this file** | what the data *is*: structure, distributions, cases, coverage, synthesis |
| `PROVENANCE.md` | where each set *came from*, which tool and version made it, how to regenerate it |
| `TEST_DATA.md` | what is still *missing* |

## Sets

| Set | Location | In git? | Kind | Size | Sensitive? | Card |
| --- | --- | --- | --- | --- | --- | --- |
| {{corpus-name}} | `data/{{…}}` | no | owner's corpus | {{n files, size}} | {{yes: real traffic / PII / no}} | [below](#set-name) |
| {{synthetic-name}} | `tests/data/{{…}}` | yes | synthetic, generated | | no | |

## Coverage

Which data exercises which behaviour of the spec (`SPEC.md` §4) — the gaps are
what synthesis is for.

| Spec behaviour / component | Covered by (set: files or filter) | Cases present | Missing → synthesize |
| --- | --- | --- | --- |

## Cards

<!-- One card per set; format in the test-data skill's references/dataset-card.md -->
