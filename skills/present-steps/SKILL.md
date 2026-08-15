---
name: present-steps
description: 'Turn work that has to happen in a particular order into a runbook page - numbered steps, each with why it sits where it does, the commands to run, the check that proves it worked, and how to undo it. Use this whenever the user asks for "a runbook", "a plan", "the steps", "a remediation plan", "the deploy steps", "a release checklist", "a migration plan", "a cutover plan", "what do I fix first", or "walk me through doing this". Covers both cases: a pile of fixes after a review or an incident, where working out the order is the job, and an operational procedure like a deploy, release, migration or cutover, where the order is already known and the value is the verification and rollback on every step. It pairs with findings-report, which presents findings themselves - that skill answers what is wrong, this one answers what to do and in what order. Not for troubleshooting or diagnosis: those branch on what you observe, and a numbered list cannot express a decision tree.'
---

# Present steps

A findings list sorted by severity does not tell anyone what to do first. Severity ranks
consequence; execution order is a different question, decided by what blocks what, what gets worse
while you wait, and what cannot be undone. This skill renders that ordering as a runbook: numbered
steps, each carrying the reason it sits where it does, the commands, the check that proves it
worked, and how to undo it.

**Two kinds of input, and they need different work from you.**

- **Derived order.** A pile of fixes from a review or an incident, where nobody has decided the
  sequence. Working it out is the job, and the ordering doctrine below is how.
- **Given order.** An operational procedure the user already has: a deploy, a release, a migration,
  a cutover. The sequence is theirs. See "When the order is given" below, because the temptation to
  re-derive it is the main way this skill can do damage.

**This skill sequences and records; it does not investigate or diagnose.** The work must already
exist, in a `findings.json` from `findings-report`, in a review, or described in the conversation.
Never invent a step to round out a plan.

**It is not for troubleshooting.** Diagnosis branches: check this, and depending on what you see do
that or the other. A numbered list cannot express a decision tree, and forcing one produces a page
that looks like a sequence and is not, which is worse than no page because a reader mid-incident
follows it in order. A flat "run these checks and report what you see" is a checklist and renders
fine; anything with a fork in it needs a different shape than this skill has.

**It is not the findings report.** What is wrong, why it matters and where it lives belong on that
page. This one assumes the reader has decided to act and needs the order. When both are wanted,
produce the report first and the runbook second, and keep the finding ids in `closes` so the two
cross-reference.

## Workflow

1. **Collect the work.** If the user points at a `findings.json`, read it: `id`, `severity`,
   `fix` and `commands` are the raw material. Otherwise take what they described.
2. **Establish whether the order is yours to decide.** If the user handed you a procedure, it is
   not; go to "When the order is given". If they handed you a pile, order it using the doctrine
   below, and that is the work.
3. **Write the payload** to a JSON file per the schema, beside the runbook (`<name>.json`). It is
   what you edit when the order changes: fix the JSON and re-render rather than hand-editing HTML.
4. **Say where it will go, then render:**
   ```bash
   <skill-dir>/scripts/render.sh <skill-dir>/assets/runbook-template.html steps.json runbook.html
   ```
   Resolve `<skill-dir>` from this file's own location. Needs a shell and nothing else; it uses
   `jq` to validate the payload when `jq` is installed.
5. **Tell the user the path.** Do not open a browser for them.

Default output: `./runbook-<subject>-YYYY-MM-DD.html` in the current directory. Nothing assumes a
git repository or a project layout, so state the path before writing and honour any path the user
names instead.

## Ordering doctrine

**For derived order only.** When the user handed you the sequence, skip this section entirely and
use "When the order is given" instead.

Apply these in order. Where two rules disagree, the earlier one wins, and say so in `why_here`.

1. **Stop the bleeding.** Anything where delay increases the damage goes first, however small the
   fix. A live credential is revoked before anything is tidied; a publicly reachable endpoint is
   closed before the dependency bumps. The question is not "how bad is this" but "is it getting
   worse while I do something else".
2. **Hard dependencies.** B after A when B genuinely needs A. Do not invent dependencies to
   justify an order that is really a preference.
3. **Group by deploy boundary.** Steps that share a build, a restart or a migration window belong
   together, so the work ships once rather than five times. This is the rule most often missed, and
   it is why a runbook is not just the findings list renumbered.
4. **Irreversible work late, and flagged.** History rewrites, data migrations, force pushes and key
   deletions come after the reversible work has landed and been verified, so a mistake earlier in
   the plan is still recoverable when you reach them.
5. **Severity last.** It is the tiebreaker between steps that rules 1 to 4 do not separate, never
   the sort key. If your runbook comes out in exactly severity order, check whether you actually
   applied the first four rules or just re-rendered the report.

Two failure modes worth naming. **A plan that is really a wish** puts five days of refactoring at
step 2 because it is High; put the containment first and the refactor in `after`. And **a plan with
no seams**: if steps 3 through 9 all have to succeed before anything is verifiable, that is one step
with nine commands, and it should say so rather than pretending to be nine checkpoints.

## When the order is given

A deploy, a release, a migration, a cutover. Somebody worked this sequence out, often the hard way,
and the reasons may not be written down anywhere you can see. **Do not reorder it.** A step that
looks redundant is usually load-bearing for a reason the person who wrote it stopped explaining
years ago, and a runbook that quietly rearranges someone's deploy is worse than no runbook.

Your job shrinks, and what is left is the part operational procedures most often lack:

- **A `verify` on every step.** Most handed-over procedures are a list of commands with no way to
  tell a partial success from a complete one. "Did that work?" is the question this page exists to
  answer, and `expect` is where the answer goes.
- **A `rollback` on every step, including the ones where it is "you cannot".** A deploy runbook
  without rollbacks is a document people follow until something breaks and then abandon.
- **`irreversible: true` wherever it belongs.** Migrations, destructive DDL, force pushes, cache
  flushes that lose data, DNS changes with long TTLs. This is the flag most likely to be missing
  from a procedure that has always worked, because nobody writes down the risk of a step that has
  never yet gone wrong.
- **`before` filled in properly.** Access, approvals, who to tell, what window. In a remediation
  plan these are nice to have; in a cutover they are the difference between a rehearsal and an
  outage.

Two things you may change, and must say you changed:

- **Grouping steps that share a deploy or a restart**, where the user listed them separately and the
  sequence allows it. Say so in `why_here`.
- **Splitting a step that has no single verifiable outcome.** If one step's `expect` cannot be
  written without "and also", it was two steps.

Anything else you would like to reorder, put in `after` as a note rather than acting on it. Where a
step's rationale is genuinely unknown to you, write that in `why_here` plainly ("carried from the
existing procedure; the reason for this position is not recorded"). An honest gap is worth more
than a confident guess, because the next reader can tell the difference between a reason and a
reconstruction.

## Payload schema

Every field is optional except `steps`. Anything absent is not rendered.

```json
{
  "title": "Runbook: checkout-svc",
  "meta": ["from findings-report checkout-svc", "2026-08-15"],
  "goal": "One line: what is true when this is finished.",
  "before": ["A precondition, access needed, or who to tell first"],
  "steps": [
    {
      "n": 1,
      "title": "Rotate the Stripe key",
      "closes": ["F1"],
      "irreversible": false,
      "why_here": "Why this step is at this position rather than later.",
      "commands": [{"code": "…", "note": "what to watch while it runs"}],
      "verify": {"code": "…", "expect": "what a good result looks like"},
      "rollback": "How to undo it, or that it cannot be undone."
    }
  ],
  "after": ["What is deliberately still open when this is done"],
  "generated": "2026-08-15",
  "source": "findings-report checkout-svc"
}
```

Field notes:

- **`why_here`** — the reason for the position, not a restatement of the fix. "Ahead of the history
  rewrite: the key is live until it is revoked and the rewrite takes hours" is the job. "Rotates the
  leaked key" is the title again. If a step's `why_here` would just be "it is Critical", rules 1 to
  4 have not been applied yet. This field is the skill's whole product; a runbook without it is a
  numbered list, and the reader could have made that themselves.
- **`verify`** — one command and what a good result looks like, so a failure is attributable to the
  step that caused it. `expect` matters more than `code`: "401, and a 200 means you rolled the wrong
  key" tells a reader what to do with the output, where "check the response" does not. A step
  needing three separate checks is usually three steps.
- **`irreversible`** — `true` renders a marker above the commands, because a reader needs that
  before running, not after. Reserve it for work that genuinely cannot be undone: history rewrites,
  destructive migrations, key deletion, force pushes. Marking everything irreversible destroys the
  signal exactly like severity inflation does.
- **`rollback`** — state it even when the answer is "you cannot". Silence reads as "probably fine".
  Beginning it with "None" or "Not reversible" renders it in the warning colour.
- **`closes`** — what this step closes out. Finding ids when the work came from a report (`F1`,
  `F4`), kept exactly as the source wrote them so a reader holding both pages can move between
  them. Anything else that identifies the item when it did not: a ticket key, a CVE, a change
  number, the name of the thing being cut over. Omit it entirely when a step closes nothing
  identifiable, which is the normal case in a deploy, and do not invent an id to fill the field.
- **`before` / `after`** — `before` is what must be true to start (access, approvals, a heads-up to
  the team). `after` is what this plan deliberately leaves undone, which is what stops a finished
  runbook reading as a finished problem.

`</script>` inside a string is handled by the renderer; write snippets verbatim and do not
pre-escape them.
**Text fields render a small markdown subset and nothing else:** backticks become inline code, and
`**bold**` becomes bold. Single-asterisk italics, links and lists are not parsed, and will show
their punctuation literally. That subset is deliberate: `*` appears constantly in real command text
(`--include='*.go'`, globs, wildcards), and outside a code span there is no reliable way to tell
emphasis from a shell pattern. Write plainly and use backticks for anything that is code.

## Serving it

Same as its sibling: a `file://` path works when the browser is on the same machine, and often it
is not.

```bash
<skill-dir>/scripts/serve.sh runbook.html             # port 8371, all interfaces
<skill-dir>/scripts/serve.sh runbook.html --local     # this machine only
```

Run it in the background and give the user every URL it prints, not just the localhost one. It
serves that one file at every path and never the directory around it, and it has no authentication,
so while it runs anyone who can route to the host can read the runbook. Say that once when you hand
over the URL.

## Common mistakes

- **Re-rendering the findings list.** If the order matches severity exactly and every `why_here`
  cites severity, this page is adding nothing. Go back to rules 1 to 4.
- **Reordering a procedure you were given.** The doctrine is for a pile of fixes, not for someone's
  deploy. Rearranging a working sequence on the strength of five rules read this morning is the
  most damaging thing this skill can do.
- **Verification at the end.** A single check after fifteen steps tells you something broke, not
  which step broke it.
- **Silent irreversibility.** A force push or a migration presented like any other step is the one
  defect on this page that cannot be undone by the reader noticing later.
- **Padding the plan.** Steps that exist to look thorough push the real work down the page.
- **Losing what is not being done.** Fixes you decided to defer belong in `after`, named. A runbook
  that omits them implies the list is complete.
