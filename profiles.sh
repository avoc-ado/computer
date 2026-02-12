# Codex Chrome DevTools profiles
# - Use p1/p2/p3 to select a profile
# - Use c to launch codex with profile-specific MCP args

export CODEX_CHROME_PROFILES_ROOT="${HOME}/.cache/chrome-devtools-mcp/profiles"

# Optional per-profile app overrides
export CODEX_CHROME_APP_C="${CODEX_CHROME_APP_C:-/Applications/Google Chrome.app}"
export CODEX_CHROME_APP_P1="${CODEX_CHROME_APP_P1:-/Applications/Google Chrome Beta.app}"
export CODEX_CHROME_APP_P2="${CODEX_CHROME_APP_P2:-/Applications/Google Chrome Dev.app}"
export CODEX_CHROME_APP_P3="${CODEX_CHROME_APP_P3:-/Applications/Google Chrome Canary.app}"

_codex_profile_port() {
  case "$1" in
    c) echo 9222 ;;
    p1) echo 9223 ;;
    p2) echo 9224 ;;
    p3) echo 9225 ;;
    *) echo 9226 ;;
  esac
}

_codex_profile_app_path() {
  case "$1" in
    c) echo "${CODEX_CHROME_APP_C}" ;;
    p1) echo "${CODEX_CHROME_APP_P1}" ;;
    p2) echo "${CODEX_CHROME_APP_P2}" ;;
    p3) echo "${CODEX_CHROME_APP_P3}" ;;
    *) echo "${CODEX_CHROME_APP_C}" ;;
  esac
}

_codex_profile_set() {
  local name="$1"
  export CODEX_ENV_PROFILE="$name"
  export CODEX_CHROME_PROFILE="$name"
  export CODEX_CHROME_PROFILE_DIR="${CODEX_CHROME_PROFILES_ROOT}/${name}"
  export CODEX_CHROME_DEBUG_PORT="$(_codex_profile_port "${name}")"
  export CODEX_CHROME_APP="$(_codex_profile_app_path "${name}")"
  export CODEX_CHROME_BROWSER_URL="http://127.0.0.1:${CODEX_CHROME_DEBUG_PORT}"
  mkdir -p "${CODEX_CHROME_PROFILE_DIR}"
}

_codex_chrome_is_ready() {
  local url="$1"
  curl -fsS --max-time 1 "${url}/json/version" >/dev/null 2>&1
}

_codex_launch_profile_chrome() {
  if [[ -z "${CODEX_CHROME_BROWSER_URL:-}" || -z "${CODEX_CHROME_PROFILE_DIR:-}" || -z "${CODEX_CHROME_APP:-}" ]]; then
    echo "Codex Chrome profile is not configured." >&2
    return 1
  fi

  if _codex_chrome_is_ready "${CODEX_CHROME_BROWSER_URL}"; then
    return 0
  fi

  if [[ ! -d "${CODEX_CHROME_APP}" ]]; then
    echo "Chrome app not found for profile ${CODEX_CHROME_PROFILE:-unknown}: ${CODEX_CHROME_APP}" >&2
    echo "Install channel apps (beta/dev/canary) or override CODEX_CHROME_APP_P1/P2/P3 in your shell." >&2
    return 1
  fi

  open -na "${CODEX_CHROME_APP}" --args \
    --remote-debugging-port="${CODEX_CHROME_DEBUG_PORT}" \
    --user-data-dir="${CODEX_CHROME_PROFILE_DIR}" \
    --no-first-run \
    --no-default-browser-check \
    about:blank >/dev/null 2>&1

  local i
  for i in {1..80}; do
    if _codex_chrome_is_ready "${CODEX_CHROME_BROWSER_URL}"; then
      return 0
    fi
    sleep 0.1
  done

  echo "Chrome did not expose remote debug endpoint at ${CODEX_CHROME_BROWSER_URL}" >&2
  return 1
}

_codex_repo_root() {
  git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null
}

_codex_env_file() {
  if [[ -n "${CODEX_ENV_FILE:-}" ]]; then
    echo "${CODEX_ENV_FILE}"
    return 0
  fi
  local root
  root="$(_codex_repo_root)"
  if [[ -z "${root}" ]]; then
    return 0
  fi
  if [[ -n "${CODEX_ENV_PROFILE:-}" ]]; then
    echo "${root}/.env.codex.${CODEX_ENV_PROFILE}"
    return 0
  fi
  echo "${root}/.env.codex"
}

_codex_env_load() {
  local env_file
  env_file="$(_codex_env_file)"
  if [[ -z "${env_file}" ]]; then
    return 0
  fi
  if [[ -n "${CODEX_ENV_PROFILE:-}" && ! -f "${env_file}" ]]; then
    # Missing profile env should behave like an empty profile file.
    return 0
  fi
  if [[ -f "${env_file}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
  fi
}

p1() { _codex_profile_set "p1"; }
p2() { _codex_profile_set "p2"; }
p3() { _codex_profile_set "p3"; }
p() {
  if [[ -z "${CODEX_ENV_PROFILE:-}" ]]; then
    echo "No codex profile. Run p1, p2 or p3."
    return 1
  fi
  echo "${CODEX_ENV_PROFILE}"
}

# Remove any existing alias so the function wins
unalias c 2>/dev/null

c() {
  if [[ -z "${CODEX_CHROME_PROFILE:-}" ]]; then
    _codex_profile_set "c"
  fi

  _codex_env_load || return $?
  _codex_launch_profile_chrome || return $?

  command codex \
    -c model_providers.openai.name='"openai"' \
    -c "model_providers.openai.env_key=OPENAI_API_KEY" \
    -c "mcp_servers.chrome-devtools.args=[\"chrome-devtools-mcp@latest\",\"--browserUrl=${CODEX_CHROME_BROWSER_URL}\"]" \
    "$@"
}
