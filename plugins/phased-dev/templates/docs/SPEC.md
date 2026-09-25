# Specification

Designed **top-down** from `CONCEPT.md` by the agent, **decided by the owner**
(`specify` skill). Each level is proposed with options, confirmed by the owner,
and only then does the next level start. The spec is complete when every level
is confirmed; it must be detailed enough that implementing a task means filling
in a box whose edges are already fixed.

## Progress

| Level | Section | Status |
| --- | --- | --- |
| 0 | Understanding and scope | not started |
| 1 | Architecture | not started |
| 2 | Technology | not started |
| 3 | Components and contracts | not started |
| 3.x | {{one row per component, added at level 1}} | not started |
| 4 | Cross-cutting rules | not started |

Statuses: *not started* · *proposed* (waiting for the owner) · *confirmed
<date>* · *confirmed, pending M-n* (confirmed, with a choice left to a
measurement) · *reopened* (a later level found a problem — see the decision log).

---

## 1. Understanding and scope (level 0)

The agent's restatement of the concept, confirmed by the owner. The concept may
be abstract; this is where it becomes concrete.

- **Goal:** {{one sentence}}
- **Users and consumers of the output:** …
- **Main functionality** (use cases, one line each):
  1. …
- **In scope for this cycle:** … **Out of scope:** … (later wishes are `F-n`
  entries in `FEATURES.md`)
- **The prototype demonstrates:** {{the end-to-end scenario}}
- **The authority** (what decides correctness): …
- **Priorities when they conflict:** 1. … 2. … 3. …

## 2. Architecture (level 1)

### 2.1 Style and overview

The architectural style chosen and why (pipeline, layered, client–server,
event-driven, plugin host …), with a diagram of the components and the data
flow.

### 2.2 Components

Each with **one responsibility** (a description that needs "and" is two).

| Component | Responsibility (one sentence) | Depends on |
| --- | --- | --- |

### 2.3 Boundaries

Which component talks to which, in which direction, exchanging what. Names only
at this level — the full contracts are level 3. Include the boundaries to the
outside world (user interface, files, network, database).

| Boundary | Between | Direction | Carries |
| --- | --- | --- | --- |

## 3. Technology (level 2)

Pre-filled from the concept where it names something; every row confirmed.

| Concern | Choice | Version | Why | Source (concept / option chosen) |
| --- | --- | --- | --- | --- |
| Language(s) | | | | |
| SDK / runtime | | | | |
| Framework(s) | | | | |
| Database / storage | | | | |
| User interface | | | | |
| Target platform(s) and deployment | | | | |
| Build and packaging | | | | |
| Test tooling, lint | | | | |

### 3.1 Allowed libraries

Nothing outside this table is used. Adding a row is a question for the owner.

| Library | Version | Used for | Where it may be used | Licence |
| --- | --- | --- | --- | --- |

## 4. Components and contracts (level 3)

One subsection per component, in the order the plan will build them.

### 4.1 {{Component}}

- **Responsibility:** (from 2.2)
- **Pattern:** {{e.g. Adapter}} — why this one, what it saves the implementer
- **Method:** {{the algorithm / data structure / library}} — or, when the choice
  depends on performance, **candidates pending measurement**: `M-n` in
  `MEASUREMENTS.md` lists them (all implementing the contract below), the
  workload and the decision rule. Tasks that depend on the choice wait for it.
- **Contract** (as it will be written in code):

  ```
  <interface / trait / abstract class / typed signatures>
  ```

  - Inputs, outputs: types, meaning, units, valid ranges
  - Errors: which, when, what the caller does with each
  - Pre/postconditions and invariants
  - Ownership and lifetime
  - Example: one call and its result
  - Contract test: what every implementation must pass
- **Behaviour rules:** precise enough to write a test from, each citing the
  authority. An unobserved rule is marked *hypothesis*.
- **External interface** (if the component faces the outside): CLI / API / UI /
  file format, with an example.

## 5. Cross-cutting rules (level 4)

### 5.1 Complexity budget

| Measure | Limit | Enforced by |
| --- | --- | --- |
| function length | {{e.g. 50 lines}} | {{lint rule}} |
| nesting depth / cyclomatic complexity | {{e.g. 4 / 10}} | |
| parameters per function | {{e.g. 5}} | |
| module size | {{e.g. 500 lines}} | |
| dependencies of a component on others | {{e.g. ≤ 3, no cycles}} | |

### 5.2 Error handling, logging, configuration

One policy each, applied everywhere.

### 5.3 Quality targets per mode

| | prototype | harnessing | production |
| --- | --- | --- | --- |
| Correctness evidence | demonstration on sample data | conformance on the full test data | + fuzzing |
| Performance | only choices pending `M-n` | measured, recorded (`M-n`) | target: …, measured at the gate |
| Robustness | refuses unsupported input visibly | edge and malformed input | hostile input, bounded resources |

---

## Decision log

Every design decision at every level. The owner decides; the agent decides only
what is **obvious** (one viable option given what is already confirmed), and
lists those for the owner's veto when the level is confirmed.

| # | Level | Question | Options considered | Chosen | Decided by | Date |
| --- | --- | --- | --- | --- | --- | --- |
| D-1 | 1 | {{architectural style}} | pipeline · layered · event-driven | pipeline | owner | {{date}} |
| D-2 | 3 | {{flow table structure}} | hash map · sorted vec | pending M-1 | owner (deferred to measurement) | {{date}} |
