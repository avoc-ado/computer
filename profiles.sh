# Codex Chrome DevTools profiles
# - Use p1..p10 to select a profile
# - Use c to launch codex with profile-specific MCP args
# - Chrome instances are launched by chrome-devtools-mcp with lane-scoped user-data-dir

export CODEX_CHROME_PROFILES_ROOT="${HOME}/.cache/chrome-devtools-mcp/profiles"

# Harness behavior toggles
export COMPUTER_SET_TITLES="${COMPUTER_SET_TITLES:-1}"
export COMPUTER_AUTO_PROFILE_FROM_CWD="${COMPUTER_AUTO_PROFILE_FROM_CWD:-1}"
# hint | prompt | off
export COMPUTER_VSCODE_TABS_TITLE_MODE="${COMPUTER_VSCODE_TABS_TITLE_MODE:-hint}"
export CODEX_TASK="${CODEX_TASK:-}"
export COMPUTER_AUTO_SETUP_LANE_WORKTREE="${COMPUTER_AUTO_SETUP_LANE_WORKTREE:-1}"
export COMPUTER_AUTO_CD_LANE_WORKTREE="${COMPUTER_AUTO_CD_LANE_WORKTREE:-1}"
export COMPUTER_WORKTREE_SETUP_CMD="${COMPUTER_WORKTREE_SETUP_CMD:-}"


_codex_repo_root() {
  git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null
}

_codex_repo_common_root() {
  local top common
  top="$(_codex_repo_root)"
  [[ -n "${top}" ]] || return 0

  common="$(git -C "${top}" rev-parse --git-common-dir 2>/dev/null)"
  [[ -n "${common}" ]] || return 0

  if [[ "${common}" != /* ]]; then
    common="${top}/${common}"
  fi

  if ! common="$(cd "${common}" 2>/dev/null && pwd)"; then
    return 0
  fi

  if [[ "${common}" == */.git ]]; then
    echo "${common%/.git}"
    return 0
  fi

  echo "${top}"
}

_computer_is_vscode_terminal() {
  [[ "${TERM_PROGRAM:-}" == "vscode" || -n "${VSCODE_PID:-}" ]]
}

_computer_vscode_settings_candidates() {
  local root
  root="$(_codex_repo_root)"
  if [[ -n "${root}" ]]; then
    echo "${root}/.vscode/settings.json"
  fi
  echo "${HOME}/Library/Application Support/Code/User/settings.json"
  echo "${HOME}/Library/Application Support/Code - Insiders/User/settings.json"
  echo "${HOME}/Library/Application Support/VSCodium/User/settings.json"
}

_computer_vscode_tabs_title_has_sequence() {
  local file
  while IFS= read -r file; do
    [[ -f "${file}" ]] || continue
    if grep -E '"terminal\.integrated\.tabs\.title"[[:space:]]*:[[:space:]]*"[^"\n]*\$\{sequence\}[^"\n]*"' "${file}" >/dev/null 2>&1; then
      return 0
    fi
  done < <(_computer_vscode_settings_candidates)
  return 1
}

_computer_prompt_vscode_tabs_title() {
  [[ "${COMPUTER_VSCODE_TABS_TITLE_MODE:-hint}" == "prompt" ]] || return 0
  [[ -t 0 ]] || return 0

  printf "[computer] Open VS Code setting terminal.integrated.tabs.title now? [y/N]: " >&2
  local answer
  read -r answer
  case "${answer}" in
    y|Y|yes|YES)
      if command -v open >/dev/null 2>&1; then
        open "vscode://settings/terminal.integrated.tabs.title" >/dev/null 2>&1 || true
      fi
      ;;
    *)
      ;;
  esac
}

_computer_vscode_tabs_title_hint_once() {
  [[ "${COMPUTER_VSCODE_TABS_TITLE_MODE:-hint}" != "off" ]] || return 0
  _computer_is_vscode_terminal || return 0
  [[ "${_COMPUTER_VSCODE_TABS_TITLE_HINTED:-0}" == "1" ]] && return 0
  export _COMPUTER_VSCODE_TABS_TITLE_HINTED=1

  if _computer_vscode_tabs_title_has_sequence; then
    return 0
  fi

  cat >&2 <<'EOF_HINT'
[computer] VS Code terminal title is not set for sequence-driven titles.
[computer] Set: "terminal.integrated.tabs.title": "${sequence}"
[computer] This lets p3 ; c (and codex itself) rename tabs/panes reliably.
EOF_HINT

  _computer_prompt_vscode_tabs_title
}

_codex_title_text() {
  local profile="${CODEX_ENV_PROFILE:-no-lane}"
  local task="${CODEX_TASK:-}"

  if [[ -z "${task}" ]]; then
    task="no-task"
  fi

  echo "${profile}; ${task}"
}

_codex_emit_osc_title() {
  local title="$1"
  # OSC 0/1/2 for broad terminal compatibility (window/tab/title variants).
  printf '\033]0;%s\007\033]1;%s\007\033]2;%s\007' "${title}" "${title}" "${title}"
}

_codex_set_panel_title() {
  local title="$1"
  [[ "${COMPUTER_SET_TITLES:-1}" == "1" ]] || return 0
  [[ -n "${title}" ]] || return 0

  local current_tty=""

  if [[ -n "${TMUX:-}" ]]; then
    tmux select-pane -T "${title}" >/dev/null 2>&1 || true
  fi

  if [[ -t 1 ]]; then
    _codex_emit_osc_title "${title}"
    current_tty="$(tty 2>/dev/null || true)"
  fi

  # When task/title updates happen inside Codex's internal agent shell, stdout
  # may not be the same TTY as the parent CLI. Mirror title updates back.
  if [[ -n "${COMPUTER_PARENT_TTY:-}" && "${COMPUTER_PARENT_TTY}" == /dev/* && -w "${COMPUTER_PARENT_TTY}" ]]; then
    if [[ "${COMPUTER_PARENT_TTY}" != "${current_tty}" ]]; then
      _codex_emit_osc_title "${title}" > "${COMPUTER_PARENT_TTY}" 2>/dev/null || true
    fi
  fi

  if [[ -n "${COMPUTER_PARENT_TMUX_PANE:-}" ]]; then
    if [[ -n "${COMPUTER_PARENT_TMUX_SOCKET:-}" ]]; then
      tmux -S "${COMPUTER_PARENT_TMUX_SOCKET}" select-pane -t "${COMPUTER_PARENT_TMUX_PANE}" -T "${title}" >/dev/null 2>&1 || true
    else
      tmux select-pane -t "${COMPUTER_PARENT_TMUX_PANE}" -T "${title}" >/dev/null 2>&1 || true
    fi
  fi
}


_computer_disable_omz_auto_title() {
  [[ -n "${ZSH_VERSION:-}" ]] || return 0

  local has_omz="0"
  if [[ -n "${ZSH:-}" ]]; then
    has_omz="1"
  elif typeset -f omz_termsupport_precmd >/dev/null 2>&1; then
    has_omz="1"
  elif typeset -f omz_termsupport_preexec >/dev/null 2>&1; then
    has_omz="1"
  fi

  [[ "${has_omz}" == "1" ]] || return 0

  export DISABLE_AUTO_TITLE=true

  autoload -Uz add-zsh-hook 2>/dev/null || true
  add-zsh-hook -D precmd omz_termsupport_precmd >/dev/null 2>&1 || true
  add-zsh-hook -D preexec omz_termsupport_preexec >/dev/null 2>&1 || true
}

_computer_detect_profile_from_cwd() {
  local path="${PWD}"
  local detected=""

  if [[ "${path}" =~ /\.worktree/(p[0-9]+)(/|$) ]]; then
    detected="${match[1]}"
  fi

  if [[ -n "${detected}" ]]; then
    echo "${detected}"
  fi
}

_computer_auto_profile_from_cwd() {
  [[ "${COMPUTER_AUTO_PROFILE_FROM_CWD:-1}" == "1" ]] || return 0
  [[ -z "${CODEX_ENV_PROFILE:-}" ]] || return 0

  local detected
  detected="$(_computer_detect_profile_from_cwd)"
  [[ -n "${detected}" ]] || return 0

  _codex_profile_set "${detected}"
}

_computer_is_lane_profile() {
  local profile="$1"
  [[ "${profile}" =~ ^p[0-9]+$ ]]
}

_computer_lane_ports() {
  local profile="$1"
  local lane_num web_port api_port

  if [[ "${profile}" =~ ^p([0-9]+)$ ]]; then
    lane_num="${match[1]}"
    web_port="$((3100 + lane_num))"
    api_port="$((4100 + lane_num))"
    echo "${web_port} ${api_port}"
    return 0
  fi

  echo "3000 4000"
}

_computer_package_has_script() {
  local package_json="$1"
  local script_name="$2"
  [[ -f "${package_json}" ]] || return 1
  grep -Eq "\"${script_name}\"[[:space:]]*:" "${package_json}"
}

_computer_run_worktree_setup() {
  local worktree="$1"
  local package_json pm

  if [[ -n "${COMPUTER_WORKTREE_SETUP_CMD:-}" ]]; then
    (cd "${worktree}" && eval "${COMPUTER_WORKTREE_SETUP_CMD}")
    return $?
  fi

  if [[ -f "${worktree}/scripts/ensure-worktree-ready.sh" ]]; then
    (cd "${worktree}" && bash scripts/ensure-worktree-ready.sh)
    return $?
  fi

  package_json="${worktree}/package.json"
  [[ -f "${package_json}" ]] || return 0

  pm=""
  if [[ -f "${worktree}/yarn.lock" ]] && command -v yarn >/dev/null 2>&1; then
    pm="yarn"
  elif [[ -f "${worktree}/pnpm-lock.yaml" ]] && command -v pnpm >/dev/null 2>&1; then
    pm="pnpm"
  elif [[ -f "${worktree}/package-lock.json" ]] && command -v npm >/dev/null 2>&1; then
    pm="npm"
  elif command -v yarn >/dev/null 2>&1; then
    pm="yarn"
  elif command -v pnpm >/dev/null 2>&1; then
    pm="pnpm"
  elif command -v npm >/dev/null 2>&1; then
    pm="npm"
  fi

  case "${pm}" in
    yarn)
      if _computer_package_has_script "${package_json}" "worktree:ensure"; then
        (cd "${worktree}" && yarn worktree:ensure)
      elif _computer_package_has_script "${package_json}" "worktree:init"; then
        (cd "${worktree}" && yarn worktree:init)
      else
        (cd "${worktree}" && yarn install)
      fi
      ;;
    pnpm)
      if _computer_package_has_script "${package_json}" "worktree:ensure"; then
        (cd "${worktree}" && pnpm run worktree:ensure)
      elif _computer_package_has_script "${package_json}" "worktree:init"; then
        (cd "${worktree}" && pnpm run worktree:init)
      else
        (cd "${worktree}" && pnpm install)
      fi
      ;;
    npm)
      if _computer_package_has_script "${package_json}" "worktree:ensure"; then
        (cd "${worktree}" && npm run worktree:ensure)
      elif _computer_package_has_script "${package_json}" "worktree:init"; then
        (cd "${worktree}" && npm run worktree:init)
      else
        (cd "${worktree}" && npm install)
      fi
      ;;
  esac
}

_computer_write_lane_env() {
  local root="$1"
  local profile="$2"
  local worktree=".worktree/${profile}"
  local env_file="${root}/${worktree}/.env.codex.${profile}"
  local ports web_port api_port docker_group

  if [[ -f "${env_file}" ]]; then
    return 0
  fi

  ports=($(_computer_lane_ports "${profile}"))
  web_port="${ports[1]}"
  api_port="${ports[2]}"
  docker_group="codex-${profile}"

  cat > "${env_file}" <<EOF_ENV
# Generated by computer harness lane selector
export ROBERTO_LANE=${profile}
export ROBERTO_WORKTREE_DIR=${root}/${worktree}
export ROBERTO_WEB_PORT=${web_port}
export ROBERTO_API_PORT=${api_port}
export CODEX_DOCKER_GROUP=${docker_group}
export COMPOSE_PROJECT_NAME=${docker_group}
export NEXT_PUBLIC_API_URL=http://localhost:${api_port}
EOF_ENV
}

_computer_setup_lane_worktree() {
  local profile="$1"
  local root worktree branch

  _computer_is_lane_profile "${profile}" || return 0

  root="$(_codex_repo_common_root)"
  if [[ -z "${root}" ]]; then
    root="$(_codex_repo_root)"
  fi
  [[ -n "${root}" ]] || return 0

  mkdir -p "${root}/.worktree"
  worktree="${root}/.worktree/${profile}"
  branch="lane-${profile}"

  if ! git -C "${root}" worktree list --porcelain | grep -Fxq "worktree ${worktree}"; then
    if git -C "${root}" show-ref --verify --quiet "refs/heads/${branch}"; then
      git -C "${root}" worktree add "${worktree}" "${branch}" || return $?
    else
      git -C "${root}" worktree add -b "${branch}" "${worktree}" HEAD || return $?
    fi
  fi

  if [[ ! -d "${worktree}" ]]; then
    echo "Lane worktree path not found after setup: ${worktree}" >&2
    return 1
  fi

  _computer_write_lane_env "${root}" "${profile}"
  export ROBERTO_WORKTREE_DIR="${worktree}"
  if [[ "${COMPUTER_AUTO_SETUP_LANE_WORKTREE:-1}" == "1" ]]; then
    _computer_run_worktree_setup "${worktree}" || return $?
  fi

  if [[ "${COMPUTER_AUTO_CD_LANE_WORKTREE:-1}" == "1" ]]; then
    if [[ "${PWD}" != "${worktree}" && "${PWD}" != "${worktree}"/* ]]; then
      builtin cd "${worktree}" || return $?
    fi
  fi
}

_codex_profile_set() {
  local name="$1"
  export CODEX_ENV_PROFILE="$name"
  export CODEX_CHROME_PROFILE="$name"
  export CODEX_CHROME_PROFILE_DIR="${CODEX_CHROME_PROFILES_ROOT}/${name}"
  mkdir -p "${CODEX_CHROME_PROFILE_DIR}"

  _computer_setup_lane_worktree "${name}" || return $?

  _computer_vscode_tabs_title_hint_once
  _codex_set_panel_title "$(_codex_title_text)"
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

task() {
  if [[ $# -eq 0 ]]; then
    if [[ -n "${CODEX_TASK:-}" ]]; then
      echo "${CODEX_TASK}"
    else
      echo "no-task"
    fi
    return 0
  fi

  case "$1" in
    --help|-h)
      cat <<'EOF_HELP'
Usage: task [<title>|--clear|-c|--help|-h]

Show current task:
  task

Set current task title:
  task "short task title"

Clear current task:
  task --clear
EOF_HELP
      return 0
      ;;
    --clear|-c)
      unset CODEX_TASK
      _codex_set_panel_title "$(_codex_title_text)"
      echo "task cleared"
      return 0
      ;;
  esac

  export CODEX_TASK="$*"
  _codex_set_panel_title "$(_codex_title_text)"
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
lane() {
  if [[ $# -eq 0 ]]; then
    p
    return $?
  fi
  _codex_profile_set "$1"
}
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

# Quick shell refresh
if [[ -n "${ZSH_VERSION:-}" ]]; then
  unalias sz 2>/dev/null
  alias sz='source ~/.zshrc'
fi

_codex_run() {
  local common_root
  local parent_tty=""
  local parent_tmux_socket=""
  local prev_parent_tty="${COMPUTER_PARENT_TTY-}"
  local prev_parent_tmux_pane="${COMPUTER_PARENT_TMUX_PANE-}"
  local prev_parent_tmux_socket="${COMPUTER_PARENT_TMUX_SOCKET-}"
  local had_parent_tty="0"
  local had_parent_tmux_pane="0"
  local had_parent_tmux_socket="0"

  if [[ ${+COMPUTER_PARENT_TTY} -eq 1 ]]; then
    had_parent_tty="1"
  fi
  if [[ ${+COMPUTER_PARENT_TMUX_PANE} -eq 1 ]]; then
    had_parent_tmux_pane="1"
  fi
  if [[ ${+COMPUTER_PARENT_TMUX_SOCKET} -eq 1 ]]; then
    had_parent_tmux_socket="1"
  fi

  if [[ -z "${CODEX_CHROME_PROFILE:-}" ]]; then
    _codex_profile_set "c"
  fi

  parent_tty="$(tty 2>/dev/null || true)"
  if [[ "${parent_tty}" == /dev/* ]]; then
    export COMPUTER_PARENT_TTY="${parent_tty}"
  else
    unset COMPUTER_PARENT_TTY
  fi

  if [[ -n "${TMUX_PANE:-}" ]]; then
    export COMPUTER_PARENT_TMUX_PANE="${TMUX_PANE}"
  else
    unset COMPUTER_PARENT_TMUX_PANE
  fi

  if [[ -n "${TMUX:-}" ]]; then
    parent_tmux_socket="${TMUX%%,*}"
    if [[ -n "${parent_tmux_socket}" ]]; then
      export COMPUTER_PARENT_TMUX_SOCKET="${parent_tmux_socket}"
    else
      unset COMPUTER_PARENT_TMUX_SOCKET
    fi
  else
    unset COMPUTER_PARENT_TMUX_SOCKET
  fi

  _computer_vscode_tabs_title_hint_once
  _codex_set_panel_title "$(_codex_title_text)"

  _codex_env_load || return $?

  common_root="$(_codex_repo_common_root)"

  if [[ -n "${common_root}" && -d "${common_root}" ]]; then
    command codex \
      --add-dir "${common_root}" \
      -c 'mcp_servers.chrome-devtools.command="npx"' \
      -c "mcp_servers.chrome-devtools.args=[\"-y\",\"chrome-devtools-mcp@latest\",\"--user-data-dir=${CODEX_CHROME_PROFILE_DIR}\"]" \
      "$@"
  else
    command codex \
      -c 'mcp_servers.chrome-devtools.command="npx"' \
      -c "mcp_servers.chrome-devtools.args=[\"-y\",\"chrome-devtools-mcp@latest\",\"--user-data-dir=${CODEX_CHROME_PROFILE_DIR}\"]" \
      "$@"
  fi

  local exit_code=$?

  if [[ "${had_parent_tty}" == "1" ]]; then
    export COMPUTER_PARENT_TTY="${prev_parent_tty}"
  else
    unset COMPUTER_PARENT_TTY
  fi

  if [[ "${had_parent_tmux_pane}" == "1" ]]; then
    export COMPUTER_PARENT_TMUX_PANE="${prev_parent_tmux_pane}"
  else
    unset COMPUTER_PARENT_TMUX_PANE
  fi

  if [[ "${had_parent_tmux_socket}" == "1" ]]; then
    export COMPUTER_PARENT_TMUX_SOCKET="${prev_parent_tmux_socket}"
  else
    unset COMPUTER_PARENT_TMUX_SOCKET
  fi

  _codex_set_panel_title "$(_codex_title_text)"
  return ${exit_code}
}

codex() {
  _codex_run "$@"
}

# If this file is sourced while inside a .worktree/pN path, select that lane
# automatically unless the user already selected one.
_computer_disable_omz_auto_title

_computer_auto_profile_from_cwd

# Ensure a clean default title on fresh terminal launch.
_computer_vscode_tabs_title_hint_once
_codex_set_panel_title "$(_codex_title_text)"
