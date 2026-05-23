#!/usr/bin/env bash
set -euo pipefail

API_VERSION="1.0.0"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/v1/manifest.json"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cd "$ROOT_DIR"

resources='{}'
while IFS= read -r -d '' file; do
  rel="${file#v1/}"
  [[ "$rel" == "manifest.json" ]] && continue

  sha="$(sha256sum "$file" | cut -d' ' -f1)"

  updated_at="$(git log -1 --format=%cI -- "$file" 2>/dev/null || true)"
  [[ -z "$updated_at" ]] && updated_at="$GENERATED_AT"

  resources="$(jq \
    --arg path "$rel" \
    --arg sha "$sha" \
    --arg ts "$updated_at" \
    '. + {($path): {updated_at: $ts, sha256: $sha}}' <<<"$resources")"
done < <(find v1 -name "*.json" -type f -print0 | sort -z)

jq -n \
  --arg version "$API_VERSION" \
  --arg generated "$GENERATED_AT" \
  --argjson resources "$resources" \
  '{api_version: $version, generated_at: $generated, resources: $resources}' \
  >"$MANIFEST_PATH"

echo "Wrote $MANIFEST_PATH"
