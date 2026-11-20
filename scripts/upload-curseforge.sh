#!/bin/sh
# Upload a packaged Rafeeq zip to CurseForge.
# Env: CF_API_TOKEN (secret), CF_PROJECT_ID, CF_GAME_VERSIONS (comma list, default 17053 = WoW Forever),
#      ZIP, VERSION, CHANGELOG_FILE
# Game version IDs: GET https://wow.curseforge.com/api/game/versions with header X-Api-Token.
set -eu
: "${CF_API_TOKEN:?missing CF_API_TOKEN secret}" "${CF_PROJECT_ID:?missing CF_PROJECT_ID}" "${ZIP:?}" "${VERSION:?}"
GAME_VERSIONS="${CF_GAME_VERSIONS:-17053}"

case "$VERSION" in
  *alpha*) RELEASE_TYPE=alpha ;;
  *beta*)  RELEASE_TYPE=beta ;;
  *)       RELEASE_TYPE=release ;;
esac

CHANGELOG=$(cat "${CHANGELOG_FILE:-/dev/null}")
METADATA=$(jq -n \
  --arg changelog "$CHANGELOG" \
  --arg name "Rafeeq v$VERSION" \
  --arg type "$RELEASE_TYPE" \
  --argjson versions "[$GAME_VERSIONS]" \
  '{changelog: $changelog, changelogType: "markdown", displayName: $name, releaseType: $type,
    gameVersions: $versions,
    relations: {projects: [{slug: "questiedb", type: "requiredDependency"}]}}')

response=$(curl -sS -w '\n%{http_code}' \
  -H "X-Api-Token: $CF_API_TOKEN" \
  -F "metadata=$METADATA" \
  -F "file=@$ZIP" \
  "https://wow.curseforge.com/api/projects/$CF_PROJECT_ID/upload-file")
code=$(printf '%s' "$response" | tail -n1)
body=$(printf '%s' "$response" | sed '$d')
echo "CurseForge HTTP $code: $body"
[ "$code" = "200" ] || exit 1
