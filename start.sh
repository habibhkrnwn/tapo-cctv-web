#!/usr/bin/env bash
# Start MediaMTX (RTSP -> HLS/WebRTC) and a static web server for the viewer page.
set -euo pipefail
cd "$(dirname "$0")"

MEDIAMTX_VERSION=v1.21.1

if [ ! -f .env ]; then
  echo "Missing .env. Run: cp .env.example .env, then fill in the camera account." >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
. ./.env
set +a
: "${CAMERA_HOST:?CAMERA_HOST is empty in .env}"
: "${CAMERA_USER:?CAMERA_USER is empty in .env}"
: "${CAMERA_PASS:?CAMERA_PASS is empty in .env}"

if [ ! -x bin/mediamtx ]; then
  case "$(uname -m)" in
    x86_64) ARCH=amd64 ;;
    aarch64 | arm64) ARCH=arm64 ;;
    armv7l) ARCH=armv7 ;;
    armv6l) ARCH=armv6 ;;
    *) echo "Unsupported CPU: $(uname -m)" >&2; exit 1 ;;
  esac
  echo "Downloading MediaMTX ${MEDIAMTX_VERSION} (${ARCH})..."
  mkdir -p bin
  curl -fsSL "https://github.com/bluenviron/mediamtx/releases/download/${MEDIAMTX_VERSION}/mediamtx_${MEDIAMTX_VERSION}_linux_${ARCH}.tar.gz" \
    | tar xz -C bin mediamtx
fi

# Render the config with the camera URL. Credentials are URL-encoded so special
# characters in the password do not break the RTSP URL.
umask 077
python3 - <<'EOF'
import os
from urllib.parse import quote

url = "rtsp://{}:{}@{}:{}".format(
    quote(os.environ["CAMERA_USER"], safe=""),
    quote(os.environ["CAMERA_PASS"], safe=""),
    os.environ["CAMERA_HOST"],
    os.environ.get("CAMERA_PORT") or "554",
)
with open("mediamtx.yml") as src, open("mediamtx.run.yml", "w") as dst:
    dst.write(src.read().replace("{{CAMERA_URL}}", url))
EOF

./bin/mediamtx ./mediamtx.run.yml &
MTX_PID=$!
python3 -m http.server "${WEB_PORT:-8080}" --directory web &
WEB_PID=$!

trap 'kill $MTX_PID $WEB_PID 2>/dev/null' EXIT INT TERM

IP=$(hostname -I | awk '{print $1}')
echo "Open: http://localhost:${WEB_PORT:-8080}  (LAN: http://$IP:${WEB_PORT:-8080})"
wait
