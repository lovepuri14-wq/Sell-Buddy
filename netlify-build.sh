#!/usr/bin/env bash
set -e

echo "Installing Flutter SDK..."
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json -o /tmp/releases.json

ARCHIVE=$(python3 -c "import json; d=json.load(open('/tmp/releases.json')); h=d['current_release']['stable']; print(next(r['archive'] for r in d['releases'] if r['hash']==h))")

curl -fL "https://storage.googleapis.com/flutter_infra_release/releases/$ARCHIVE" -o /tmp/flutter.tar.xz
tar -xf /tmp/flutter.tar.xz -C /tmp

export PATH="/tmp/flutter/bin:$PATH"

if [ -z "$API_BASE_URL" ]; then
  echo "ERROR: Set API_BASE_URL in Netlify environment variables."
  exit 1
fi

cd mobile
flutter pub get
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"
