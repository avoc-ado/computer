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
export COMPUTER_TASK_BUS_DIR="${COMPUTER_TASK_BUS_DIR:-${TMPDIR:-/tmp}/computer-task-bus}"
export COMPUTER_TASK_CHANNEL_FILE="${COMPUTER_TASK_CHANNEL_FILE:-}"


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

_computer_tmux_conf_has_setting() {
  local conf_file="$1"
  local setting="$2"
  [[ -f "${conf_file}" ]] || return 1
  grep -Eq "${setting}" "${conf_file}"
}

_computer_tmux_scrollback_prompt_once() {
  [[ -t 0 && -t 1 ]] || return 0
  [[ "${_COMPUTER_TMUX_SCROLLBACK_HINTED:-0}" == "1" ]] && return 0
  export _COMPUTER_TMUX_SCROLLBACK_HINTED=1

  local conf_file="${HOME}/.tmux.conf"
  local has_mouse="0"
  local has_history="0"
  local answer=""

  if _computer_tmux_conf_has_setting "${conf_file}" '^[[:space:]]*set(-option)?[[:space:]]+-g[[:space:]]+mouse[[:space:]]+on([[:space:]]|$)'; then
    has_mouse="1"
  fi
  if _computer_tmux_conf_has_setting "${conf_file}" '^[[:space:]]*set(-option)?[[:space:]]+-g[[:space:]]+history-limit[[:space:]]+[0-9]+'; then
    has_history="1"
  fi

  if [[ "${has_mouse}" == "1" && "${has_history}" == "1" ]]; then
    return 0
  fi

  echo ""
  echo "[computer] Preserve terminal scrolling behavior in tmux?"
  echo "[computer] This enables mouse scrolling and increases scrollback in ${conf_file}."
  echo -n "[computer] Update tmux config now? [y/N]: "
  read -r answer
  case "${answer}" in
    y|Y|yes|YES)
      {
        echo ""
        [[ "${has_mouse}" == "1" ]] || echo "set -g mouse on"
        [[ "${has_history}" == "1" ]] || echo "set -g history-limit 200000"
      } >> "${conf_file}"
      tmux set-option -g mouse on >/dev/null 2>&1 || true
      tmux set-option -g history-limit 200000 >/dev/null 2>&1 || true
      ;;
    *)
      ;;
  esac
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

_codex_task_bus_dir() {
  echo "${COMPUTER_TASK_BUS_DIR:-${TMPDIR:-/tmp}/computer-task-bus}"
}

_codex_task_bus_write() {
  local title="$1"
  local file="$2"
  local dir=""
  [[ -n "${title}" ]] || return 0
  [[ -n "${file}" ]] || return 0

  dir="$(dirname "${file}")"
  mkdir -p "${dir}" >/dev/null 2>&1 || return 0
  printf '%s\n' "${title}" >| "${file}" 2>/dev/null || true
}

_codex_task_channel_file() {
  local channel="${COMPUTER_TASK_CHANNEL_FILE:-}"
  local tmux_session=""
  local tmux_env=""

  if [[ -z "${channel}" && -n "${TMUX:-}" ]]; then
    tmux_session="$(tmux display-message -p "#{session_name}" 2>/dev/null || true)"
    if [[ -n "${tmux_session}" ]]; then
      tmux_env="$(tmux show-environment -t "${tmux_session}" COMPUTER_TASK_CHANNEL_FILE 2>/dev/null || true)"
      if [[ "${tmux_env}" == COMPUTER_TASK_CHANNEL_FILE=* ]]; then
        channel="${tmux_env#*=}"
      fi
    fi
  fi

  echo "${channel}"
}

_codex_publish_title() {
  local title="$1"
  local channel=""
  [[ -n "${title}" ]] || return 0

  channel="$(_codex_task_channel_file)"
  _codex_task_bus_write "${title}" "${channel}"
}

_codex_apply_parent_title() {
  local title="$1"
  local parent_tty="$2"
  local parent_tmux_pane="$3"
  local parent_tmux_socket="$4"
  [[ -n "${title}" ]] || return 0

  if [[ -n "${parent_tty}" && "${parent_tty}" == /dev/* && -w "${parent_tty}" ]]; then
    _codex_emit_osc_title "${title}" > "${parent_tty}" 2>/dev/null || true
  fi

  if [[ -n "${parent_tmux_pane}" ]]; then
    if [[ -n "${parent_tmux_socket}" ]]; then
      tmux -S "${parent_tmux_socket}" select-pane -t "${parent_tmux_pane}" -T "${title}" >/dev/null 2>&1 || true
    else
      tmux select-pane -t "${parent_tmux_pane}" -T "${title}" >/dev/null 2>&1 || true
    fi
  fi
}

_codex_watch_task_bus() {
  local session_file="$1"
  local parent_tty="$2"
  local parent_tmux_pane="$3"
  local parent_tmux_socket="$4"
  local title=""
  local last_title=""

  while true; do
    title=""

    if [[ -n "${session_file}" && -r "${session_file}" ]]; then
      IFS= read -r title < "${session_file}" || true
    fi

    if [[ -n "${title}" && "${title}" != "${last_title}" ]]; then
      _codex_apply_parent_title "${title}" "${parent_tty}" "${parent_tmux_pane}" "${parent_tmux_socket}"
      last_title="${title}"
    fi

    sleep 0.2 || break
  done
}

_codex_set_panel_title() {
  local title="$1"
  [[ "${COMPUTER_SET_TITLES:-1}" == "1" ]] || return 0
  [[ -n "${title}" ]] || return 0

  if [[ -n "${TMUX:-}" ]]; then
    tmux select-pane -T "${title}" >/dev/null 2>&1 || true
  fi

  if [[ -t 1 ]]; then
    _codex_emit_osc_title "${title}"
  fi

  _codex_publish_title "${title}"
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

_computer_lane_env_override_file() {
  local root="$1"
  local profile="$2"
  local repo_name=""
  local overrides_dir=""
  local candidate=""

  repo_name="${root##*/}"

  if [[ -n "${COMPUTER_LANE_ENV_OVERRIDES_DIR:-}" ]]; then
    local dirs=()
    IFS=':' read -r -A dirs <<< "${COMPUTER_LANE_ENV_OVERRIDES_DIR}"
    for overrides_dir in "${dirs[@]}"; do
      [[ -n "${overrides_dir}" ]] || continue
      candidate="${overrides_dir}/${repo_name}/lane-env.${profile}.sh"
      if [[ -f "${candidate}" ]]; then
        echo "${candidate}"
        return 0
      fi
      candidate="${overrides_dir}/${repo_name}/lane-env.sh"
      if [[ -f "${candidate}" ]]; then
        echo "${candidate}"
        return 0
      fi
    done
  fi

  candidate="${root}/.codex/lane-env.${profile}.sh"
  if [[ -f "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi
  candidate="${root}/.codex/lane-env.sh"
  if [[ -f "${candidate}" ]]; then
    echo "${candidate}"
    return 0
  fi

  return 1
}

_computer_apply_lane_env_overrides() {
  local root="$1"
  local profile="$2"
  local override_file=""
  local lane_num=0

  override_file="$(_computer_lane_env_override_file "${root}" "${profile}")"
  if [[ -z "${override_file}" ]]; then
    return 0
  fi

  if [[ "${profile}" =~ ^p([0-9]+)$ ]]; then
    lane_num="${match[1]}"
  fi
  export CODEX_LANE_PROFILE="${profile}"
  export CODEX_LANE_NUMBER="${lane_num}"
  if (( lane_num > 0 )); then
    export CODEX_LANE_OFFSET="$((lane_num - 1))"
  else
    export CODEX_LANE_OFFSET="0"
  fi

  set -a
  # shellcheck disable=SC1090
  source "${override_file}"
  set +a
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

  _computer_apply_lane_env_overrides "${root}" "${profile}"
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

_computer_tmux_wrap_profile() {
  local profile="$1"
  shift
  local -a cmd_args=("$@")
  local session=""
  local cmd_str=""
  local created_session=0
  local tty_name=""
  local task_bus_dir=""
  local session_task_file=""
  local parent_tty=""
  local parent_tmux_pane=""
  local parent_tmux_socket=""
  local watcher_pid=""
  local initial_title=""

  if ! _computer_is_lane_profile "${profile}"; then
    _codex_profile_set "${profile}"
    if (( ${#cmd_args[@]} )); then
      "${cmd_args[@]}"
      return $?
    fi
    return 0
  fi

  if [[ -n "${TMUX:-}" || "${COMPUTER_TMUX_LANES:-1}" != "1" ]]; then
    _codex_profile_set "${profile}" || return $?
    if (( ${#cmd_args[@]} )); then
      "${cmd_args[@]}"
      return $?
    fi
    return 0
  fi

  if ! command -v tmux >/dev/null 2>&1; then
    _codex_profile_set "${profile}" || return $?
    if (( ${#cmd_args[@]} )); then
      "${cmd_args[@]}"
      return $?
    fi
    return 0
  fi

  session="codex-${profile}"
  tty_name="$(tty 2>/dev/null || true)"
  if [[ "${tty_name}" == /dev/* ]]; then
    tty_name="${tty_name#/dev/}"
  else
    tty_name="no-tty-${$}"
  fi
  tty_name="${tty_name//[^a-zA-Z0-9]/_}"
  session="${session}-${tty_name}"

  if ! tmux has-session -t "${session}" 2>/dev/null; then
    created_session=1
    tmux new-session -d -s "${session}" -n "${profile}"
    tmux send-keys -t "${session}" "${profile}" C-m
  fi

  tmux set-option -t "${session}" status off >/dev/null 2>&1 || true
  tmux set-option -t "${session}" pane-border-status off >/dev/null 2>&1 || true

  _computer_tmux_scrollback_prompt_once

  task_bus_dir="$(_codex_task_bus_dir)"
  if [[ -n "${task_bus_dir}" ]]; then
    session_task_file="${task_bus_dir}/session.${session}.task-title"
    tmux set-environment -t "${session}" COMPUTER_TASK_CHANNEL_FILE "${session_task_file}" >/dev/null 2>&1 || true
    initial_title="$(tmux display-message -p -t "${session}" "#{pane_title}" 2>/dev/null || true)"
    if [[ -z "${initial_title}" ]]; then
      initial_title="${profile}; no-task"
    fi
    _codex_task_bus_write "${initial_title}" "${session_task_file}"

    parent_tty="$(tty 2>/dev/null || true)"
    if [[ "${parent_tty}" != /dev/* ]]; then
      parent_tty=""
    fi
    parent_tmux_pane="${TMUX_PANE:-}"
    if [[ -n "${TMUX:-}" ]]; then
      parent_tmux_socket="${TMUX%%,*}"
    fi

    if [[ -n "${parent_tty}" || -n "${parent_tmux_pane}" ]]; then
      _codex_watch_task_bus "${session_task_file}" "${parent_tty}" "${parent_tmux_pane}" "${parent_tmux_socket}" &
      watcher_pid=$!
    fi
  fi

  if (( ${#cmd_args[@]} )); then
    if (( ! created_session )); then
      tmux send-keys -t "${session}" "${profile}" C-m
    fi
    cmd_str="${(j: :)cmd_args}"
    tmux send-keys -l -t "${session}" -- "${cmd_str}"
    tmux send-keys -t "${session}" C-m
  fi

  tmux attach -t "${session}"

  if [[ -n "${watcher_pid}" ]]; then
    kill "${watcher_pid}" >/dev/null 2>&1 || true
    wait "${watcher_pid}" >/dev/null 2>&1 || true
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


p1() { _computer_tmux_wrap_profile "p1" "$@"; }
p2() { _computer_tmux_wrap_profile "p2" "$@"; }
p3() { _computer_tmux_wrap_profile "p3" "$@"; }
p4() { _computer_tmux_wrap_profile "p4" "$@"; }
p5() { _computer_tmux_wrap_profile "p5" "$@"; }
p6() { _computer_tmux_wrap_profile "p6" "$@"; }
p7() { _computer_tmux_wrap_profile "p7" "$@"; }
p8() { _computer_tmux_wrap_profile "p8" "$@"; }
p9() { _computer_tmux_wrap_profile "p9" "$@"; }
p10() { _computer_tmux_wrap_profile "p10" "$@"; }
lane() {
  if [[ $# -eq 0 ]]; then
    p
    return $?
  fi
  local profile="$1"
  shift
  _computer_tmux_wrap_profile "${profile}" "$@"
}
p() {
  if [[ -z "${CODEX_ENV_PROFILE:-}" ]]; then
    echo "No codex profile. Run p1..p10."
    return 1
  fi
  echo "${CODEX_ENV_PROFILE}"
}

_computer_capture_c_alias() {
  local alias_def=""
  local alias_cmd=""

  if alias c >/dev/null 2>&1; then
    alias_def="$(alias c)"
    alias_cmd="${alias_def#*=}"
    alias_cmd="${alias_cmd#\'}"
    alias_cmd="${alias_cmd%\'}"
    if [[ -n "${alias_cmd}" ]]; then
      export COMPUTER_C_ALIAS_CMD="${alias_cmd}"
    fi
  fi
}

_computer_capture_c_alias
unalias c 2>/dev/null

# Quick shell refresh
if [[ -n "${ZSH_VERSION:-}" ]]; then
  unalias sz 2>/dev/null
  alias sz='source ~/.zshrc'
fi

_codex_run() {
  local common_root
  local -a codex_cmd
  local base_cmd="${CODEX_BASE_CMD:-codex}"
  local exit_code=0

  if [[ -z "${CODEX_CHROME_PROFILE:-}" ]]; then
    _codex_profile_set "c"
  fi

  _computer_vscode_tabs_title_hint_once
  _codex_set_panel_title "$(_codex_title_text)"

  if [[ -n "${CODEX_ENV_PROFILE:-}" ]]; then
    common_root="$(_codex_repo_common_root)"
    if [[ -z "${common_root}" ]]; then
      common_root="$(_codex_repo_root)"
    fi
    if [[ -n "${common_root}" ]]; then
      _computer_apply_lane_env_overrides "${common_root}" "${CODEX_ENV_PROFILE}"
    fi
  fi

  common_root="$(_codex_repo_common_root)"

  eval "codex_cmd=(${base_cmd})"

  local -a add_dir_args=()
  if [[ -n "${common_root}" && -d "${common_root}" ]]; then
    add_dir_args=(--add-dir "${common_root}")
  fi

  command "${codex_cmd[@]}" \
    "${add_dir_args[@]}" \
    -c 'mcp_servers.chrome-devtools.command="npx"' \
    -c 'mcp_servers.chrome-devtools.startup_timeout_sec=60' \
    -c "mcp_servers.chrome-devtools.args=[\"-y\",\"chrome-devtools-mcp@latest\",\"--user-data-dir=${CODEX_CHROME_PROFILE_DIR}\"]" \
    "$@"

  exit_code=$?

  _codex_set_panel_title "$(_codex_title_text)"
  return ${exit_code}
}

codex() {
  _codex_run "$@"
}

c() {
  local prev_base="${CODEX_BASE_CMD-}"

  if [[ -n "${COMPUTER_C_ALIAS_CMD:-}" ]]; then
    export CODEX_BASE_CMD="${COMPUTER_C_ALIAS_CMD}"
  else
    export CODEX_BASE_CMD="codex"
  fi

  _codex_run "$@"

  if [[ -n "${prev_base}" ]]; then
    export CODEX_BASE_CMD="${prev_base}"
  else
    unset CODEX_BASE_CMD
  fi
}

# If this file is sourced while inside a .worktree/pN path, select that lane
# automatically unless the user already selected one.
_computer_disable_omz_auto_title

_computer_auto_profile_from_cwd

# Ensure a clean default title on fresh terminal launch.
_computer_vscode_tabs_title_hint_once
_codex_set_panel_title "$(_codex_title_text)"
