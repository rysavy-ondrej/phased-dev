# Presenting a decision point

The owner decides; the agent's job is to make the decision easy and well
informed. One decision point = one question with 2–4 viable options.

## Is it a decision point?

| It is | It is not |
| --- | --- |
| more than one design is viable **and** the choice changes cost, capability, risk, or what the owner must live with | only one option is viable given what is already confirmed → decide it, log it as `agent (obvious)`, list it for veto |
| the concept is silent or ambiguous about something that matters | the owner would answer "whatever you think" → decide it, log it |
| the concept names a choice (language, DB, platform) → a **pre-filled** decision: confirm it, and raise it as a real decision only if it conflicts with something confirmed | a detail the implementer can settle inside one component without affecting its contract → not a spec question at all |
| options that differ mainly in speed or memory, with no clear winner on paper → propose **deciding by measurement**: candidates behind one contract, an `M-n` with a decision rule agreed now | a performance guess presented as a fact → never; cite an `M-n` or say it is unmeasured |

## The shape of each option

For every option, in a line or two each:

- **What it is** — concretely, in this project's terms.
- **Gives** — what it makes easy or possible.
- **Costs** — effort, complexity, dependencies, performance, lock-in.
- **Wrong when** — the situation in which you would regret it.

Put your **recommendation first** and say why in one sentence. Offer only viable
options — a straw man wastes the owner's attention. If an option is favoured
because of an earlier decision, name that decision (`D-4`).

## Asking

- Use **AskUserQuestion**: up to four decision points per round, 2–4 options
  each; the owner can always choose "Other" and write their own.
- Use the option **preview** for things best compared side by side: a component
  diagram for an architecture option, an interface sketch for a contract shape,
  a config snippet for a technology choice.
- Keep the question text self-contained: the owner may answer from a phone
  without the spec open.
- If an answer is "Other", restate how you understood it, check it against what
  is confirmed, and if it conflicts, say so and ask again.

## Example (level 1)

> **How should the processing be organised?**
>
> 1. **Pipeline of stages (recommended)** — reader → decoder → aggregator →
>    exporter, each behind an interface. *Gives:* each stage testable alone;
>    stages swappable (D-2 wants several input sources). *Costs:* data copied or
>    borrowed between stages. *Wrong when:* stages need to share a lot of state.
> 2. **Layered** — capture layer, domain layer, output layer. *Gives:* familiar;
>    fewer interfaces. *Costs:* a new input format touches two layers. *Wrong
>    when:* sources and outputs vary independently, as here.
> 3. **Event-driven** — components subscribe to packet/flow events. *Gives:*
>    easy to add consumers. *Costs:* ordering and back-pressure become your
>    problem. *Wrong when:* output must be deterministic, as the authority's is.

## Recording

Every decision point, answered or obvious, becomes a row in the spec's
*Decision log*: `D-n | level | question | options considered | chosen | owner /
agent (obvious) | date`. The chosen option's reasoning goes into the level's
text; the log is the index.
