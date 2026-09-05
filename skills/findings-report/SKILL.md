---
name: findings-report
description: 'Turn findings that already exist into a single self-contained HTML page - a TL;DR, then one card per finding with what it is, why it matters, and how to fix it. Use this whenever the user asks to present, write up, summarise, or share findings from a review, audit, security scan, investigation, or debugging session, and whenever they ask for "a report", "a page", "an HTML summary", "something I can look at", or "something I can send to the team" about problems you or another tool found. Reach for it even when the user does not say the word "report" - if there is a list of problems and they want it presented rather than fixed, this is the skill.'
model: sonnet
effort: medium
---

# Findings report

Findings that live in a transcript are findings nobody acts on. This skill renders them as one HTML
file: a TL;DR someone can read in thirty seconds, then a card per finding carrying what it is, why
it matters, and what to do about it.

**This skill presents; it does not investigate.** The findings must already exist, in the
conversation, in a markdown report, in scanner output, or in a file the user points at. Never
invent a finding to fill out a page, and never re-run an analysis to produce more of them. If the
user wants a review, run the review first, then use this to present the result.

**Ordering a runbook across many findings is a different job** and is deliberately out of scope.
Commands that belong to one finding live in that finding's card. Cross-cutting sequencing (what to
do first, what to verify after each step) belongs to a separate steps skill.

## Workflow

1. **Collect the findings.** Read what the user pointed at. Where they said "these findings" and
   meant the conversation, use the conversation.
2. **Write the payload** to a JSON file, per the schema below. Put it next to the report
   (`<name>.json`), because it is the thing to edit when the page needs a change: fix the JSON and
   re-render rather than hand-editing HTML.
3. **Say where the report will go, then render:**
   ```bash
   <skill-dir>/scripts/render.sh <skill-dir>/assets/report-template.html data.json report.html
   ```
   Resolve `<skill-dir>` from this file's own location. The script needs a shell and nothing else;
   it uses `jq` to validate the payload when `jq` happens to be installed.
4. **Tell the user the path.** They open it themselves. Do not open a browser for them.

Default output: `./findings-report-<subject>-YYYY-MM-DD.html` in the current directory. Nothing
here assumes a git repository, a project layout, or a `reports/` directory, so state the path
before writing and honour any path the user names instead.

The page makes no network requests, so it works offline and the findings stay on the machine.
Publish it as an Artifact only if the user asks: a report naming exploitable paths in their code
is not something to put on a URL by default.

## Serving it

A `file://` path is the right answer when the browser is on the same machine that generated the
report. It often is not: reports get generated on a remote box over SSH and read from a laptop on
the same subnet. Serve it when the user asks, when the work is happening somewhere their browser
is not, or when the copy buttons matter, since `http://localhost` is a secure origin where the
clipboard API works and a `file://` page falls back to a legacy copy path some browsers have
dropped.

```bash
<skill-dir>/scripts/serve.sh report.html             # port 8371, all interfaces
<skill-dir>/scripts/serve.sh report.html --port 9000
<skill-dir>/scripts/serve.sh report.html --local     # this machine only
```

Run it in the background so the session is not blocked, and **give the user every URL it prints**,
not just the localhost one. It reports the machine's own subnet addresses (skipping container and
VM bridges, which the reading machine cannot route to), and on a remote box the localhost line is
the one URL that is useless to them.

Two properties worth knowing before pointing anyone at it. It serves that one file at every path
and never the directory around it, because reports get written into working trees and a directory
server pointed at one would publish the tree. And it has no authentication: while it runs, anyone
who can route to the host can read the report. That is the right default for a subnet you trust and
the wrong one for a shared or public network, so say so once when you hand over the URL, and reach
for `--local` when the reader is on the same machine anyway.

## Payload schema

Every field is optional except `findings`. Anything absent is simply not rendered, which is what
makes the page work for findings that never went through a scoring rubric.

```json
{
  "title": "Security review: acme-api",
  "meta": ["7 files from git diff main...HEAD", "Go, Vue/TS", "2026-08-15"],
  "verdict": "1 Critical, 2 High. Do not ship until F1 is closed.",
  "highlights": [
    {"text": "One sentence on the thing that matters most.", "finding": "F1"}
  ],
  "findings": [
    {
      "id": "F1",
      "severity": "Critical",
      "confidence": "Confirmed",
      "title": "One-line claim about the defect",
      "location": "config/app.yaml:14",
      "tags": ["SEC-04"],
      "what": "What the code does, as a fact.",
      "why": "The consequence, and who can reach it.",
      "fix": "What to change, specifically enough to act on.",
      "evidence": "the offending lines, verbatim",
      "commands": [
        {"code": "grep -rn 'sk_live_' .", "note": "why this command, or what to look for in it"}
      ]
    }
  ],
  "coverage": [
    {"check": "semgrep", "reason": "not installed", "note": "pipx install semgrep"}
  ],
  "generated": "2026-08-15",
  "source": "claude-review-suite security-review"
}
```

Field notes:

- **`severity`** — `Critical`, `High`, `Medium`, `Low`, or omitted. Anything unrecognised renders
  as unscored and sorts after every scored finding, so an unfamiliar vocabulary degrades into
  "unscored" rather than silently claiming to be the least serious thing on the page.

  **When the source gave no severities, assign them anyway and say that you did.** Ranking is most
  of what makes a page actionable, and refusing to rank pushes that work onto the reader. But a
  severity that came from the write-up is a different kind of claim from one that came from a
  rubric or a scanner, and a badge cannot tell them apart. So add a line to `meta` such as
  `"Severities assigned in this write-up, not by a scanner or rubric"`. It costs one line in the
  header strip and it stops a judgement made in five seconds from reading like a graded result.
  Where the source did supply severities, carry them over unchanged and say nothing.
- **`confidence`** — a short label, one or two words: `Confirmed` / `Likely` / `Speculative` if the
  source used them. It renders as a badge beside the severity, so a clause put here ("Confirmed,
  though the link to the rate limiting is not proven") becomes the loudest thing on the card and
  crowds out the title. The caveat is what `why` is for; the badge is the index to it. Report a
  speculative finding as speculative rather than dropping it or promoting it.
- **`status`** — `Open` (the default, and what you get by omitting it), `Fixed`, or `Accepted`.
  Omit it entirely on a fresh report: every finding is open, a column of identical badges says
  nothing, and the concept only earns its place once something has changed.

  It earns its place when a report is **revisited after work has been done**. A resolved finding
  sorts below everything still open, its severity stripe goes neutral, and **it stops counting
  towards the severity chips**. That last part is the point: "1 Critical, 2 High" that silently
  includes findings closed last week tells the reader there is more to do than there is, and a
  count nobody can trust is worse than no count.

  `Accepted` is for a finding nobody intends to fix. It is not a quiet way to make something go
  away: it still renders, and the reason belongs in `resolution` where the next reader can argue
  with it.
- **`resolution`** — how a finding was closed and where, one or two sentences: "Fixed in 42a6e67,
  the route is wrapped in the auth middleware and the handler can no longer authenticate anyone."
  It renders as its own field labelled with the status. Put it here rather than appending to `fix`:
  `fix` is what to do, `resolution` is what happened, and a reader picking the report up later needs
  to tell those apart. On an open finding it renders as a plain note, which is the right place for
  "tried X, it did not work".
- **`id`** — short and stable (`F1`, `F2`). It is the anchor `highlights` links to, so keep the
  ids the source used; a reader holding the original report should find the same numbers here.
- **`tags`** — checklist ids, CWEs, CVEs, rule names. Whatever lets someone trace the finding back.
- **`evidence`** — verbatim code, rendered as a block. Use it when the claim is easier to believe
  when seen; skip it when the `what` line already carries the whole story.
- **`commands`** — only commands belonging to *this* finding. A copy button is attached to each.
- **`coverage`** — what did not run and why. Keep it even on a clean report: "the scanner found
  nothing" and "the scanner never started" are opposite claims, and a page that renders them the
  same way is worse than no page.
- **`agent_prompt`** — a copy-pasteable block for handing the findings to a coding agent, rendered
  under the TL;DR with a copy button and collapsed by default. See below. Omit it entirely when
  there are no findings; an empty block invites a downstream agent to invent work.

## The agent prompt block

**Drop resolved findings from the block.** An entry for something already fixed produces a
`SKIPPED-STALE` row and no work, because its anchor no longer matches. Leaving them in is not
dangerous, the anchor rule handles it, but it wastes a downstream agent's pass and buries the
entries that still matter.

**If the source already emitted one, carry it across verbatim.** `claude-review-suite` specifies
this artifact in `references/agent-prompt.md` and its reviews produce it; rewriting it loses the
anchors it chose. This section is for when there is no such block and the user wants one.

The block exists so that findings are **re-verified before they are applied**. A review is stale
the moment someone edits the file, and a block that can be pasted and obeyed without re-reading the
code is a machine for applying obsolete fixes. Four rules follow from that, and they are the whole
value of the block:

1. **Anchor by content, not line number.** Each entry carries a short literal snippet from the
   cited location, unique in the file and short enough to survive reformatting. Line numbers are
   hints, written `~L112`. If the anchor does not match, the finding is stale by definition, and
   the receiving agent should skip it rather than search for something nearby.
2. **State the issue and the expected end state, never a diff.** `Issue:` is what is wrong,
   `Expect:` is what must be true afterwards. Writing the patch removes the agent's reason to read
   the current code, which defeats the point. Naming an API is fine; writing the caller's line is
   not.
3. **Each entry stands alone.** The receiving agent has no report, no diff and no conversation.
   Restate enough of why it matters, including the trust boundary or the caller that makes it real.
4. **Demand a status table back**, one row per finding id, distinguishing "fixed", "skipped because
   the anchor no longer matches" and "skipped because I think the finding is wrong". Those last two
   mean opposite things: one says the review aged, the other says it may have been wrong. Collapsing
   them loses the only feedback signal on review quality there is.

Close with the validation commands to run afterwards, and **only name tools that are actually
installed**. Telling an agent to run a binary this machine does not have is how a block produces a
confident report of work it never validated.

The rendered block shows the warning by default and keeps the payload collapsed. That is
deliberate: the copy button is one click either way, and what should be visible is the instruction
to re-check, not a wall of text that reads as ready to paste.

`</script>` inside a string is handled by the renderer; write snippets verbatim and do not
pre-escape them.
**Text fields render a small markdown subset and nothing else:** backticks become inline code, and
`**bold**` becomes bold. Single-asterisk italics, links and lists are not parsed, and will show
their punctuation literally. That subset is deliberate: `*` appears constantly in real command text
(`--include='*.go'`, globs, wildcards), and outside a code span there is no reliable way to tell
emphasis from a shell pattern. Write plainly and use backticks for anything that is code.

## Writing the page

The page is only as good as the sentences in it. Three things carry most of the weight.

**The TL;DR is the deliverable.** Assume it is the only part read. `verdict` is one line carrying
the single decision that follows from the findings: "do not ship until F1 is closed", "all four are
hardening, ship it".

**Do not put counts in the `verdict`.** The page derives the severity chips from `findings` and
renders them directly beneath it, so a count written into the prose is a second source of truth for
a number the page already knows. It drifts the moment a finding is added, dropped or rescored, and
it drifts silently, because prose does not recompute. The failure is not hypothetical: a verdict
reading "6 findings: 5 Medium, 1 Low" sitting above chips reading "5 medium, 2 low" tells the
reader the report was assembled carelessly, which is the one impression a findings page cannot
afford. Say what to do; let the chips say how many. The same applies to `highlights`: write "the
two worth acting on this week", not "two of the six".

`highlights` is three to five entries, not a restatement of every finding. Choosing what to leave
out is the work; a highlights list as long as the findings list has made no decision and helps
nobody.

**What / Why / Fix answer different questions.** `what` is a fact about the code, phrased so a
reader can check it. `why` is the consequence and its reachability, which is what tells someone
whether to act today or next sprint. `fix` is specific enough to act on: "scope the query by the
authenticated principal, `WHERE id = $1 AND owner_id = $2`" rather than "add authorisation". Where
a fix is not a code change, say so plainly, and where a fix is incomplete on its own, say that too
(a committed credential needs rotating, not deleting, and a page that omits that leaves a live key
in history).

**Order by severity, but let the TL;DR carry the real priority.** The card list is sorted for you.
When the thing to do first is not the worst finding, that belongs in `verdict` or `highlights`,
because that judgement cannot be recovered from a sorted list.

## Common mistakes

- **Padding.** A finding list is not improved by low-value entries. Four real findings beat four
  real ones plus six restatements of a linter's opinion.
- **Losing the caveats.** The gaps and skipped checks the source reported belong in `coverage`. A
  report that quietly drops them reads as more complete than the work behind it was.
- **Editing the HTML.** Change the JSON and re-render. Hand edits are lost the next time and
  cannot be diffed against the source findings.
- **Restating severity in prose.** The badge already says Critical. Spend the sentence on the
  consequence instead.
- **Publishing without being asked.** The file is local for a reason.
