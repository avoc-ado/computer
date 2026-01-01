# Codex Chrome DevTools profiles
# - Use p1/p2/p3 to select a profile
# - Use c to launch codex with profile-specific MCP args

export CODEX_CHROME_PROFILES_ROOT="${HOME}/.cache/chrome-devtools-mcp/profiles"

_codex_profile_set() {
  local name="$1"
  export CODEX_CHROME_PROFILE="$name"
  export CODEX_CHROME_PROFILE_DIR="${CODEX_CHROME_PROFILES_ROOT}/${name}"
  mkdir -p "${CODEX_CHROME_PROFILE_DIR}"
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
    echo "Missing Codex env file: ${env_file}" >&2
    return 1
  fi
  if [[ -f "${env_file}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
  fi
}

p1() { export CODEX_ENV_PROFILE=p1; _codex_profile_set "p1"; }
p2() { export CODEX_ENV_PROFILE=p2; _codex_profile_set "p2"; }
p3() { export CODEX_ENV_PROFILE=p3; _codex_profile_set "p3"; }
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
  _codex_env_load || return $?
  if [[ -n "${CODEX_CHROME_PROFILE_DIR:-}" ]]; then
    command codex \
      -c model_providers.openai.name='"openai"' \
      -c "model_providers.openai.env_key=OPENAI_API_KEY" \
      -c "mcp_servers.chrome-devtools.args=[\"chrome-devtools-mcp@latest\",\"--user-data-dir=${CODEX_CHROME_PROFILE_DIR}\"]" \
      "$@"
    return $?
  fi
  command codex "$@"
}
