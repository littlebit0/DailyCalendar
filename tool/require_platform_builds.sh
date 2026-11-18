#!/usr/bin/env bash
# Fails unless the newest Platform Builds run of a release tag's commit
# succeeded. Release workflows run this before building anything.
#
# Usage: GH_TOKEN=... tool/require_platform_builds.sh <owner/repo> <tag>
set -euo pipefail

repo="$1"
tag="$2"

sha="$(gh api "repos/$repo/commits/tags/$tag" --jq .sha)"
if [[ -z "$sha" || "$sha" == "null" ]]; then
  echo "Could not resolve $tag to a commit." >&2
  exit 1
fi

# The newest run decides, so a rerun or a manual run replaces an earlier
# result in either direction.
latest="$(gh api "repos/$repo/actions/workflows/platform-builds.yml/runs?head_sha=$sha&per_page=100" \
  --jq '.workflow_runs | sort_by(.run_number) | last | select(. != null) | "\(.status) \(.conclusion) \(.html_url)"')"
if [[ -z "$latest" ]]; then
  echo "No Platform Builds run exists for $tag ($sha)." >&2
  echo "Run the Platform Builds workflow on the tag (Actions > Platform Builds > Run workflow > $tag), then start the release again." >&2
  exit 1
fi

read -r status conclusion url <<< "$latest"
if [[ "$status" != "completed" || "$conclusion" != "success" ]]; then
  echo "Platform Builds is '$status/$conclusion' for $tag ($sha): $url" >&2
  exit 1
fi
echo "Platform Builds passed for $tag ($sha): $url"
