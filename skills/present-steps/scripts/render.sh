#!/usr/bin/env bash
# Inject a steps JSON payload into the runbook template.
#
# Everything here is bash string handling on purpose: no sed (backslashes and
# ampersands are routine inside code snippets and would need escaping), no jq,
# no python. The only hard requirement is a shell.
set -euo pipefail

MARKER='"__RUNBOOK_DATA__"'

usage() {
  cat >&2 <<'EOF'
usage: render.sh <template.html> <steps.json> <output.html>

Writes output.html: the template with its placeholder replaced by data.json.
EOF
  exit 2
}

die() { printf 'render.sh: %s\n' "$1" >&2; exit 1; }

[ $# -eq 3 ] || usage
template=$1
data=$2
output=$3

[ -r "$template" ] || die "cannot read template: $template"
[ -r "$data" ] || die "cannot read data file: $data"

tpl=$(cat "$template")
case $tpl in
  *"$MARKER"*) ;;
  *) die "placeholder $MARKER not found in $template" ;;
esac

head=${tpl%%"$MARKER"*}
tail=${tpl#*"$MARKER"}
case $tail in
  *"$MARKER"*) die "placeholder $MARKER appears more than once in $template" ;;
esac

json=$(cat "$data")
[ -n "$json" ] || die "data file is empty: $data"

# A literal </script> inside any string value would close the data element and
# spill the rest of the payload into the document as markup. JSON reads \/ as a
# plain slash, so this stays the same data once parsed.
needle='</script'
replacement='<\/script'
json=${json//"$needle"/"$replacement"}

# Optional: jq is not required, but when it is present a malformed payload
# should fail here rather than as a blank page in the browser.
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$json" | jq empty 2>/dev/null || die "data file is not valid JSON: $data"
fi

{
  printf '%s' "$head"
  printf '%s' "$json"
  printf '%s\n' "$tail"
} > "$output"

printf 'wrote %s\n' "$output"
