# Dataset card

One card per data set in `docs/DATA.md`. Statistics and structure, produced by
scripts; raw values only when the set is not sensitive, and then only short ones.

```markdown
### <set-name>

**What:** <one or two sentences: what this data is and where it comes from>.
**Location:** `data/<set>/` · **In git:** no · **Size:** <files, bytes, records>
**Kind:** owner's corpus | synthetic (generator `tests/data-gen/<x>`, seed <n>)
**Sensitive:** no | yes — <what: PII, credentials, real traffic> → rules: <stats only; never commit; synthetic look-alikes for examples>
**Profiled by:** `scripts/data/<profile-script>` on <date>, <full | sample of n, seed s>

**Structure**
- Format: <e.g. pcapng, link type Ethernet / NDJSON, one object per line / CSV, ; separated, header row>
- Schema / grammar: <fields with types and units, or the record layout; nesting; optional vs required>
- Encoding: <UTF-8, byte order, compression, timestamp format and precision>

**Content**
- Volume per file: <records: min / median / max>
- Key fields: <field: range, distribution (uniform, long tail, few dominant values), cardinality, null rate>
- Relationships: <keys that link records or files; ordering; time span; sessions/flows>
- Mix: <e.g. 70 % TCP, 25 % UDP, 5 % other; 12 protocols, top 5 cover 90 %>

**Cases present** (with example files)
- Typical: <…> — `file-a`
- Boundary: <empty file, single record, maximum sizes, …> — `file-b`
- Rare / unusual: <…>
- Malformed / truncated: <…, or "none — synthesize">

**Quality problems:** <duplicates, stale fields, known wrong values, gaps in time; with evidence>

**Good for**
- prototype: <which files make a good end-to-end demo>
- harnessing: <which support conformance or edge-case tests>
- production: <performance-sized files, variety>

**Not good for:** <what it cannot test — these are coverage gaps>
```

## What to profile, by kind of data

| Kind | Profile with | Look for |
| --- | --- | --- |
| Tabular (CSV, TSV, spreadsheets) | Python `csv`, `awk`, `csvstat` if installed | columns, types, null rate, ranges, distinct counts, key uniqueness, delimiter/quoting quirks |
| JSON / NDJSON / logs | `jq`, Python | key set per record, key order if it matters, nesting depth, optional keys, value types per key, timestamp format |
| Network captures | `capinfos`, `tshark -qz io,phs`, `tshark -qz conv,tcp` | link types, protocol hierarchy, conversations, time span, truncation (snaplen), malformed packets |
| Binary formats | the format's reference tool, `xxd` on headers | magic numbers, versions, endianness, record framing, variants present |
| Text / documents | `wc`, `file`, encoding detection | languages, encodings, line endings, lengths |
| Databases / dumps | `sqlite3 .schema`, `pg_restore -l` | tables, keys, row counts, referential integrity |
| Images / media | `file`, `identify`, `ffprobe` | formats, dimensions, durations, codecs |

Always: file-level counts and sizes (`data-inventory.sh`), the date profiled, and
whether the numbers come from all data or a seeded sample.
