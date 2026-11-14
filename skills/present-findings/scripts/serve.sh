#!/usr/bin/env bash
# Serve one finished report over HTTP, for viewing it in a browser that is not
# on this machine, or for getting a real origin.
#
# It serves the single file it was given and nothing else, whatever path is
# requested: a report often sits inside a working tree, and a directory server
# pointed at one would publish the tree.
#
# It binds every interface by default, because the common case is a report
# generated on a remote box and read from a laptop on the same subnet, and a
# localhost default makes that case fail in a way that looks like a broken
# server. There is no authentication, so while it runs anyone who can route to
# this host can read the report. Use --local to restrict it to this machine.
set -euo pipefail

port=8371
host=0.0.0.0
file=""

usage() {
  cat >&2 <<'EOF'
usage: serve.sh <report.html> [--port N] [--local]

  --port N   listen on N (default 8371)
  --local    bind 127.0.0.1 only (default: all interfaces, reachable from the subnet)

Serves that one file at every path, with no authentication. Ctrl-C to stop.
EOF
  exit 2
}

while [ $# -gt 0 ]; do
  case $1 in
    --port)  [ $# -ge 2 ] || usage; port=$2; shift 2 ;;
    --local) host=127.0.0.1; shift ;;
    -h|--help) usage ;;
    -*) printf 'serve.sh: unknown option %s\n' "$1" >&2; usage ;;
    *)  file=$1; shift ;;
  esac
done

[ -n "$file" ] || usage
[ -r "$file" ] || { printf 'serve.sh: cannot read %s\n' "$file" >&2; exit 1; }

case $port in
  ''|*[!0-9]*) printf 'serve.sh: port must be a number, got %s\n' "$port" >&2; exit 2 ;;
esac

abs=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")

runtime=""
if command -v bun >/dev/null 2>&1; then
  runtime=bun
elif command -v python3 >/dev/null 2>&1; then
  runtime=python3
else
  printf 'serve.sh: needs bun or python3 to serve; neither found. Open the file directly instead:\n  file://%s\n' "$abs" >&2
  exit 1
fi

printf 'serving %s   (%s)\n' "$abs" "$runtime"
printf '  http://localhost:%s/\n' "$port"

if [ "$host" = "0.0.0.0" ]; then
  # Print the addresses another machine can actually use. Container and VM
  # bridges are skipped: they are unreachable from the laptop doing the reading,
  # and listing five of them buries the one address that works.
  addrs=$(ip -4 -o addr show scope global 2>/dev/null \
            | awk '$2 !~ /^(docker|br-|virbr|veth|lxdbr|podman)/ {split($4,a,"/"); print a[1]}' \
          || hostname -I 2>/dev/null | tr ' ' '\n')
  for a in $addrs; do
    [ -n "$a" ] && printf '  http://%s:%s/\n' "$a" "$port"
  done
  printf 'Reachable from your subnet, with no authentication, until you stop it.\n'
fi

printf 'Ctrl-C to stop.\n'

if [ "$runtime" = bun ]; then
  script=$(mktemp -t serve-report-XXXXXX.js)
  trap 'rm -f "$script"' EXIT
  cat > "$script" <<'JS'
const [file, port, hostname] = process.argv.slice(2);
Bun.serve({
  port: Number(port),
  hostname,
  fetch: () =>
    new Response(Bun.file(file), {
      headers: {
        "content-type": "text/html; charset=utf-8",
        "cache-control": "no-store",
      },
    }),
});
JS
  exec bun run "$script" "$abs" "$port" "$host"
fi

exec python3 - "$abs" "$port" "$host" <<'PY'
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

path, port, host = sys.argv[1], int(sys.argv[2]), sys.argv[3]

class OneFile(BaseHTTPRequestHandler):
    def do_GET(self):
        # Re-read per request so a re-render shows up on refresh.
        try:
            body = open(path, "rb").read()
        except OSError as e:
            self.send_error(500, str(e))
            return
        self.send_response(200)
        self.send_header("content-type", "text/html; charset=utf-8")
        self.send_header("content-length", str(len(body)))
        self.send_header("cache-control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

HTTPServer((host, port), OneFile).serve_forever()
PY
