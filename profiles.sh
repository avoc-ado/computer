# Codex Chrome DevTools profiles
# - Use p1..p10 to select a profile
# - Use c to launch codex with profile-specific MCP args

export CODEX_CHROME_PROFILES_ROOT="${HOME}/.cache/chrome-devtools-mcp/profiles"

_codex_profile_default_app_path() {
  case "$1" in
    c) echo "/Applications/Google Chrome.app" ;;
    p1) echo "/Applications/Google Chrome Beta.app" ;;
    p2) echo "/Applications/Google Chrome Dev.app" ;;
    p3) echo "/Applications/Google Chrome Canary.app" ;;
    p4|p5|p6|p7|p8|p9|p10) echo "/Applications/Google Chrome.app" ;;
    *) echo "/Applications/Google Chrome.app" ;;
  esac
}

_codex_profile_brew_cask() {
  case "$1" in
    c) echo "google-chrome" ;;
    p1) echo "google-chrome@beta" ;;
    p2) echo "google-chrome@dev" ;;
    p3) echo "google-chrome@canary" ;;
    p4|p5|p6|p7|p8|p9|p10) echo "google-chrome" ;;
    *) echo "google-chrome" ;;
  esac
}

_codex_all_channel_casks() {
  echo "google-chrome@beta google-chrome@dev google-chrome@canary"
}

# Optional per-profile app overrides
export CODEX_CHROME_APP_C="${CODEX_CHROME_APP_C:-$(_codex_profile_default_app_path c)}"
export CODEX_CHROME_APP_P1="${CODEX_CHROME_APP_P1:-$(_codex_profile_default_app_path p1)}"
export CODEX_CHROME_APP_P2="${CODEX_CHROME_APP_P2:-$(_codex_profile_default_app_path p2)}"
export CODEX_CHROME_APP_P3="${CODEX_CHROME_APP_P3:-$(_codex_profile_default_app_path p3)}"
export CODEX_CHROME_APP_P4="${CODEX_CHROME_APP_P4:-$(_codex_profile_default_app_path p4)}"
export CODEX_CHROME_APP_P5="${CODEX_CHROME_APP_P5:-$(_codex_profile_default_app_path p5)}"
export CODEX_CHROME_APP_P6="${CODEX_CHROME_APP_P6:-$(_codex_profile_default_app_path p6)}"
export CODEX_CHROME_APP_P7="${CODEX_CHROME_APP_P7:-$(_codex_profile_default_app_path p7)}"
export CODEX_CHROME_APP_P8="${CODEX_CHROME_APP_P8:-$(_codex_profile_default_app_path p8)}"
export CODEX_CHROME_APP_P9="${CODEX_CHROME_APP_P9:-$(_codex_profile_default_app_path p9)}"
export CODEX_CHROME_APP_P10="${CODEX_CHROME_APP_P10:-$(_codex_profile_default_app_path p10)}"

_codex_profile_port() {
  case "$1" in
    c) echo 9222 ;;
    p1) echo 9223 ;;
    p2) echo 9224 ;;
    p3) echo 9225 ;;
    p4) echo 9226 ;;
    p5) echo 9227 ;;
    p6) echo 9228 ;;
    p7) echo 9229 ;;
    p8) echo 9230 ;;
    p9) echo 9231 ;;
    p10) echo 9232 ;;
    *) echo 9222 ;;
  esac
}

_codex_profile_app_path() {
  case "$1" in
    c) echo "${CODEX_CHROME_APP_C}" ;;
    p1) echo "${CODEX_CHROME_APP_P1}" ;;
    p2) echo "${CODEX_CHROME_APP_P2}" ;;
    p3) echo "${CODEX_CHROME_APP_P3}" ;;
    p4) echo "${CODEX_CHROME_APP_P4}" ;;
    p5) echo "${CODEX_CHROME_APP_P5}" ;;
    p6) echo "${CODEX_CHROME_APP_P6}" ;;
    p7) echo "${CODEX_CHROME_APP_P7}" ;;
    p8) echo "${CODEX_CHROME_APP_P8}" ;;
    p9) echo "${CODEX_CHROME_APP_P9}" ;;
    p10) echo "${CODEX_CHROME_APP_P10}" ;;
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

_codex_prompt_install_profile_app() {
  local profile="$1"
  local app_path="$2"
  local cask
  cask="$(_codex_profile_brew_cask "${profile}")"

  if ! command -v brew >/dev/null 2>&1; then
    if [[ "${profile}" == "c" ]]; then
      echo "Homebrew is not installed. Install manually: brew install --cask ${cask}" >&2
    else
      echo "Homebrew is not installed. Install manually: brew install --cask $(_codex_all_channel_casks)" >&2
    fi
    return 1
  fi

  if [[ "${profile}" != "c" ]]; then
    local all_casks
    all_casks="$(_codex_all_channel_casks)"

    if [[ ! -t 0 ]]; then
      echo "Chrome app missing for profile ${profile}: ${app_path}" >&2
      echo "Run manually: brew install --cask ${all_casks}" >&2
      return 1
    fi

    echo "Chrome app not found for profile ${profile}: ${app_path}" >&2
    printf "Install all Chrome channel builds now (beta/dev/canary)? [Y/n]: " >&2

    local answer
    read -r answer
    case "${answer}" in
      n|N|no|NO)
        echo "Install skipped." >&2
        return 1
        ;;
      *)
        brew install --cask google-chrome@beta google-chrome@dev google-chrome@canary || return 1
        ;;
    esac

    return 0
  fi

  if [[ ! -t 0 ]]; then
    echo "Chrome app missing for profile ${profile}: ${app_path}" >&2
    echo "Run manually: brew install --cask ${cask}" >&2
    return 1
  fi

  echo "Chrome app not found for profile ${profile}: ${app_path}" >&2
  printf "Install it now via Homebrew cask '%s'? [y/N]: " "${cask}" >&2

  local answer
  read -r answer
  case "${answer}" in
    y|Y|yes|YES)
      brew install --cask "${cask}" || return 1
      ;;
    *)
      echo "Install skipped." >&2
      return 1
      ;;
  esac

  return 0
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
    local profile default_app
    profile="${CODEX_CHROME_PROFILE:-c}"
    default_app="$(_codex_profile_default_app_path "${profile}")"

    if [[ -d "${default_app}" ]]; then
      export CODEX_CHROME_APP="${default_app}"
    else
      _codex_prompt_install_profile_app "${profile}" "${CODEX_CHROME_APP}" || return 1
      if [[ -d "${default_app}" ]]; then
        export CODEX_CHROME_APP="${default_app}"
      fi
    fi

    if [[ ! -d "${CODEX_CHROME_APP}" ]]; then
      echo "Chrome app still not found for profile ${profile}: ${CODEX_CHROME_APP}" >&2
      return 1
    fi
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
p4() { _codex_profile_set "p4"; }
p5() { _codex_profile_set "p5"; }
p6() { _codex_profile_set "p6"; }
p7() { _codex_profile_set "p7"; }
p8() { _codex_profile_set "p8"; }
p9() { _codex_profile_set "p9"; }
p10() { _codex_profile_set "p10"; }
p() {
  if [[ -z "${CODEX_ENV_PROFILE:-}" ]]; then
    echo "No codex profile. Run p1..p10."
    return 1
  fi
  echo "${CODEX_ENV_PROFILE}"
}

# Keep c as shorthand for codex
unalias c 2>/dev/null
alias c='codex'

_codex_run() {
  if [[ -z "${CODEX_CHROME_PROFILE:-}" ]]; then
    _codex_profile_set "c"
  fi

  _codex_env_load || return $?

  command codex \
    -c model_providers.openai.name='"openai"' \
    -c "model_providers.openai.env_key=OPENAI_API_KEY" \
    -c 'mcp_servers.chrome-devtools.command="npx"' \
    -c "mcp_servers.chrome-devtools.args=[\"-y\",\"chrome-devtools-mcp@latest\",\"--browserUrl=${CODEX_CHROME_BROWSER_URL}\"]" \
    "$@"
}

codex() {
  _codex_run "$@"
}
