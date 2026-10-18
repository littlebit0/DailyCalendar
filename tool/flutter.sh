#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
tool_root="$(dirname "$project_root")"

select_existing_path() {
  local required_child="$1"
  shift
  local first_candidate=""

  for candidate in "$@"; do
    if [[ -z "$candidate" ]]; then
      continue
    fi
    if [[ -z "$first_candidate" ]]; then
      first_candidate="$candidate"
    fi
    if [[ -e "$candidate/$required_child" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if [[ -n "$first_candidate" ]]; then
    printf '%s\n' "$first_candidate"
    return 0
  fi

  return 1
}

flutter_root="${FLUTTER_ROOT:-}"
flutter_bin=""

if [[ -n "$flutter_root" ]]; then
  flutter_bin="$flutter_root/bin/flutter"
elif command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(command -v flutter)"
else
  flutter_root="$(select_existing_path "bin/flutter" \
    "$project_root/development/flutter-sdk" \
    "$tool_root/flutter-sdk" \
    "$HOME/development/flutter" \
    "$HOME/flutter" \
    "/opt/flutter" \
    "/usr/local/flutter" \
  )"
  flutter_bin="$flutter_root/bin/flutter"
fi

if [[ ! -x "$flutter_bin" ]]; then
  echo "Flutter SDK not found. Set FLUTTER_ROOT or install Flutter." >&2
  echo "Expected executable: $flutter_bin" >&2
  exit 1
fi

export PUB_CACHE="${PUB_CACHE:-$project_root/development/pub-cache}"
export PATH="$(dirname "$flutter_bin"):$PATH"

build_path="$project_root/build"
tmp_build_path="${DAILY_FLUTTER_BUILD_DIR:-/tmp/daily-flutter-build}"

if [[ ! -e "$build_path" ]]; then
  mkdir -p "$tmp_build_path"
  ln -s "$tmp_build_path" "$build_path"
fi

cd "$project_root"

flutter_args=("$@")

is_macos_command=false
if [[ " ${flutter_args[*]} " == *" build macos "* ]]; then
  is_macos_command=true
elif [[ " ${flutter_args[*]} " == *" run "* ]]; then
  for ((index = 0; index < ${#flutter_args[@]}; index++)); do
    if [[ "${flutter_args[$index]}" == "-d" ||
          "${flutter_args[$index]}" == "--device-id" ]]; then
      if ((index + 1 < ${#flutter_args[@]})) &&
         [[ "${flutter_args[$((index + 1))]}" == "macos" ]]; then
        is_macos_command=true
        break
      fi
    fi
  done
fi

has_desktop_client_secret=false
for argument in "${flutter_args[@]}"; do
  if [[ "$argument" == --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=* ]]; then
    has_desktop_client_secret=true
    break
  fi
done

if [[ "$is_macos_command" == true &&
      "$has_desktop_client_secret" == false ]]; then
  desktop_client_secret="${GOOGLE_DESKTOP_CLIENT_SECRET:-}"
  oauth_config="${GOOGLE_DESKTOP_OAUTH_CONFIG:-$HOME/Library/Application Support/Daily/google_desktop_oauth.json}"

  if [[ -z "$desktop_client_secret" && -f "$oauth_config" ]]; then
    desktop_client_secret="$(/usr/bin/plutil -extract installed.client_secret raw -o - "$oauth_config" 2>/dev/null || true)"
    if [[ -z "$desktop_client_secret" ]]; then
      desktop_client_secret="$(/usr/bin/plutil -extract client_secret raw -o - "$oauth_config" 2>/dev/null || true)"
    fi
  fi

  if [[ -n "$desktop_client_secret" ]]; then
    flutter_args+=("--dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=$desktop_client_secret")
    echo "Using the local macOS Desktop OAuth credential for this build."
  fi
fi

"$flutter_bin" "${flutter_args[@]}"
