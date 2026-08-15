# claude-report-suite

Two skills that present work rather than do it. `findings-report` answers *what is wrong*;
`present-steps` answers *what to do and in what order*. They compose: the report writes a
`findings.json`, and the runbook reads the same file and keeps its finding ids.

Both render one self-contained HTML file with no network requests, so a page works offline and the
findings stay on the machine that produced them.

## Install

```
/plugin marketplace add mrevjd/claude-report-suite
/plugin install claude-report-suite@claude-report-suite
```

Or copy a single skill into `~/.claude/skills/`:

```bash
rsync -a --exclude='evals/' skills/findings-report/ ~/.claude/skills/findings-report/
```

## Skills

| Skill | Use it when |
|---|---|
| `findings-report` | Findings exist and need presenting: a review, an audit, a scanner dump, a debugging session. Produces a TL;DR, a card per finding with what/why/fix, a coverage section for what did not run, and an optional agent prompt block. |
| `present-steps` | Work has to happen in an order. Produces numbered steps carrying why each sits where it does, the commands, a verification with what a good result looks like, and a rollback. Handles both a pile of fixes where the order must be derived, and an operational procedure where it is already given. |

Neither investigates. The findings must already exist; these skills present what a review produced.

## How they work

Each skill is a template plus a marker-injection script. The model's job is the JSON payload, which
is where the judgement lives; the script renders it:

```bash
skills/findings-report/scripts/render.sh \
  skills/findings-report/assets/report-template.html findings.json report.html
```

`render.sh` is bash with no dependencies: no sed (backslashes and ampersands are routine inside
code snippets), no jq beyond an optional validation pass, no Python. A literal `</script>` in a
payload string is escaped so it cannot close the data element early.

The payload is the artifact to keep. Correcting a page means editing the JSON and re-rendering, not
hand-editing HTML, so a report can be diffed against the findings it came from.

## Serving

```bash
skills/present-steps/scripts/serve.sh runbook.html          # all interfaces, port 8371
skills/present-steps/scripts/serve.sh runbook.html --local  # this machine only
```

Serves that one file at every path and never the directory around it, because reports get written
into working trees. Binds all interfaces by default, since the common case is a page generated on a
remote box and read from a laptop on the same subnet, and prints every reachable address rather than
only localhost. There is no authentication: while it runs, anyone who can route to the host can read
the page.

## Layout

```
skills/<name>/SKILL.md          the skill
skills/<name>/assets/*.html     the template, self-contained, opens standalone as a preview
skills/<name>/scripts/render.sh marker injection, bash only
skills/<name>/scripts/serve.sh  one-file HTTP server
skills/<name>/evals/evals.json  eval prompts and expectations, excluded from the packaged skill
```

## Testing

Evals live in `skills/<name>/evals/evals.json`, each carrying the prompt, a description of the
expected output, and the expectations it is graded against.

They were run with skill-creator. `findings-report` went through two iterations of three evals
against an unaided baseline; the discriminators turned out to be narrow, since a capable model
writes a good page unaided, and what the skill actually buys is a re-renderable payload, a
consistent layout across runs, and scope discipline. `present-steps` went through four: three
derived-order cases, one of which is built so that severity order is the wrong answer, and one
given-order deployment procedure that tests the opposite instinct, leaving a sequence alone.

Both were then run against a real security review rather than only synthetic input, which is what
surfaced a CSS grid overflow bug and a stale count in a hand-written verdict line. The harness and
its rendered comparisons live outside this repo.

## License

MIT
