# Specification

Derived from `CONCEPT.md`. It adds what the concept leaves open: the
architecture, the technology, the allowed libraries, the precise behaviour. It is
**final** when every question in `QUESTIONS.md` tagged `spec` is answered and the
owner has confirmed this file.

Status: draft | confirmed by owner on {{date}}

## 1. Scope

In scope (from the concept): … Out of scope: … (items the owner wants in a later
cycle are `F-n` entries in `FEATURES.md`).

## 2. Architecture

A short description and a diagram of the components and the data flow.

| Component | Responsibility | Seam (interface) it sits behind |
| --- | --- | --- |

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
