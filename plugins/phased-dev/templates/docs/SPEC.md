# Specification

Derived from `CONCEPT.md`. It adds what the concept leaves open: the
architecture, the technology, the allowed libraries, the precise behaviour. It is
**final** when every question in `QUESTIONS.md` tagged `spec` is answered and the
owner has confirmed this file.

Status: draft | confirmed by owner on {{date}}

## 1. Scope

In scope (from the concept): … Out of scope: … (items the owner wants in a later
cycle are `F-n` entries in `FEATURES.md`).

## 2. Modules and contracts

The goal of this section: implementing any task means filling in a box whose
edges are already fixed. Defined **before** the plan, and built first.

### 2.1 Decomposition

A short description and a diagram of the modules and the data flow. Decompose
until each module has **one responsibility** that fits in a sentence; a module
whose description needs "and" is two modules.

| Module | Responsibility (one sentence) | Depends on | Location |
| --- | --- | --- | --- |

### 2.2 Contracts

One entry per boundary between modules, written in the project's language:

```
<the interface / trait / abstract class / typed signatures, exactly as it will be
written in code>
```

- **Provided by / used by:** …
- **Inputs, outputs:** types and meaning; units; valid ranges.
- **Errors:** which, when, and what the caller does with each.
- **Pre/postconditions and invariants:** …
- **Ownership and lifetime:** who allocates, who frees, what may be borrowed.
- **Example:** one call and its result.
- **Contract test:** what every implementation must pass.

### 2.3 Patterns

| Where | Pattern | Why this one | Not to be confused with |
| --- | --- | --- | --- |
| {{input sources}} | Adapter | several sources, one interface | — |

Only patterns that earn their place: a pattern that adds a layer without
removing a decision is not used.

### 2.4 Complexity budget

Limits every module, class and function stays within, enforced by lint where the
language allows:

| Measure | Limit | Enforced by |
| --- | --- | --- |
| function length | {{e.g. 50 lines}} | {{lint rule}} |
| nesting depth / cyclomatic complexity | {{e.g. 4 / 10}} | |
| parameters per function | {{e.g. 5}} | |
| module size | {{e.g. 500 lines}} | |
| dependencies of a module on other modules | {{e.g. ≤ 3, no cycles}} | |

## 3. Technology

| | Choice | Why | Decided by |
| --- | --- | --- | --- |
| Language(s) | | | |
| Framework(s) | | | |
| Build / packaging | | | |
| Target platforms | | | |
| Test tooling | | | |

## 4. Allowed libraries

Nothing outside this table is used. Adding a row is a question for the owner.

| Library | Version | Used for | Where it may be used (e.g. not on the hot path) | Licence |
| --- | --- | --- | --- | --- |

## 5. Interfaces

Inputs, outputs, command line / API, file formats, with examples.

## 6. Behaviour

The rules that decide the output, precisely enough to write a test from, each
citing the authority. The ones a sensible design gets wrong by default are
copied into `CLAUDE.md` → *Invariants*.

## 7. Quality targets per mode

| | prototype | harnessing | production |
| --- | --- | --- | --- |
| Correctness evidence | smoke run on sample data | conformance comparison on the full test data | same, plus fuzzing |
| Performance | not measured | measured, recorded | target: … |
| Robustness | refuses unsupported input visibly | malformed-input tests | hostile-input tests, bounded resources |

## 8. Decisions

| # | Decision | Reason / measurement | Owner ruling (date) | Reopen if |
| --- | --- | --- | --- | --- |
