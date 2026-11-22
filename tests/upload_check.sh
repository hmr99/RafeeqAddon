#!/bin/sh
# Regression check for scripts/upload-curseforge.sh: the metadata JSON must reach the server intact
# (a ';' in the changelog once cut it off with curl -F). Runs against a local echo server.
set -eu
cd "$(dirname "$0")/.."
cat > /tmp/cf_echo.py <<'PY'
import http.server, json, re, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"])).decode(errors="replace")
        m = re.search(r'name="metadata"\r\n\r\n(.*?)\r\n--', body, re.S)
        try:
            json.loads(m.group(1)); code, msg = 200, '{"id":1}'
        except Exception:
            code, msg = 400, '{"errorMessage":"Invalid JSON."}'
        self.send_response(code); self.end_headers(); self.wfile.write(msg.encode())
    def log_message(self, *a): pass
http.server.HTTPServer(("127.0.0.1", 8766), H).handle_request()
PY
python3 /tmp/cf_echo.py &
sleep 1
printf -- '- New: marker (option X; turns on a CVar) with "quotes", `ticks` & ampersands\n' > /tmp/cf_notes.md
echo dummy > /tmp/cf_test.zip
CF_API_TOKEN=test CF_PROJECT_ID=1 CF_API_URL=http://127.0.0.1:8766 ZIP=/tmp/cf_test.zip VERSION=9.9.9-beta1 \
  CHANGELOG_FILE=/tmp/cf_notes.md sh scripts/upload-curseforge.sh
echo "upload metadata check: OK"
