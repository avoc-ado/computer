# shellcheck shell=bash
# Source this file in your shell startup for the default computer harness.
# Example in ~/.zshrc:
#   source /Users/tristyn/repos/computer/computer.sh

if [[ -n "${ZSH_VERSION:-}" ]]; then
  script_path="${(%):-%N}"
else
  script_path="${BASH_SOURCE[0]}"
fi

script_dir="$(cd "$(dirname "${script_path}")" && pwd)"
# shellcheck disable=SC1091
source "${script_dir}/profiles.sh"
