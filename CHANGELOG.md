# Changelog

## 0.1.0

First release. Two skills, `findings-report` and `present-steps`, built and evaluated together.

### findings-report

- Renders findings as one self-contained HTML page: TL;DR, a card per finding with what / why /
  fix, optional evidence and per-finding commands, and a coverage section for checks that did not
  run.
- Reads any findings, with the `claude-review-suite` rubric (severity, confidence, checklist ids)
  as a first-class case. Findings that never went through a rubric render unscored and sort after
  every scored one, rather than silently claiming to be the least serious thing on the page.
- Where the source gave no severities, assigns them and says so in the header, so a judgement made
  during the write-up does not read like a graded result.
- Optional `agent_prompt` block, rendered under the TL;DR with the re-verify warning visible and the
  payload collapsed. Carries a source-emitted block verbatim where there is one.

### present-steps

- Renders an ordered runbook: numbered steps carrying why each sits where it does, the commands, a
  verification with what a good result looks like, and a rollback including where the answer is
  that there is none. Irreversible steps are marked above their commands, not below.
- Two modes. Derived order applies a documented doctrine where severity is the tiebreaker rather
  than the sort key. Given order, for a deploy or migration the user already has, leaves the
  sequence alone and fills in the verification, rollback and preconditions it lacks.
- Explicitly not for troubleshooting: diagnosis branches and a numbered list cannot express a
  decision tree.

### Shared

- `render.sh` injects a JSON payload into a template with bash string handling only. A literal
  `</script>` in a payload string is escaped so it cannot close the data element early.
- `serve.sh` serves exactly one file at every path, never the directory around it, binding all
  interfaces by default and printing every reachable address.
- Templates render a deliberately small markdown subset in text fields: backticks as inline code and
  `**bold**` as bold, nothing else, because `*` is too common in command text to disambiguate.
