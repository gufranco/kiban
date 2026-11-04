#!/bin/sh
[ -n "${ZSH_VERSION:-}" ] && emulate sh

KB_LIB="$(cd "$(dirname "$0")/../lib" && pwd)" || exit 1

# shellcheck source=SCRIPTDIR/../lib/core.sh
. "${KB_LIB}/core.sh"
# shellcheck source=SCRIPTDIR/../lib/ui.sh
. "${KB_LIB}/ui.sh"
# shellcheck source=SCRIPTDIR/../lib/settings.sh
. "${KB_LIB}/settings.sh"
# shellcheck source=SCRIPTDIR/../lib/cli.sh
. "${KB_LIB}/cli.sh"
# shellcheck source=SCRIPTDIR/../lib/engine.sh
. "${KB_LIB}/engine.sh"
# shellcheck source=SCRIPTDIR/../lib/services.sh
. "${KB_LIB}/services.sh"

call_setting() {
  kb_resolve "$1"
  printf '%s\n' "${KB_VALUE}"
}

call_pick_on_terminal() {
  kb_load_service_settings
  KIBAN_INTERACTIVE=1 KIBAN_TERMINAL=1 kb_pick "$1" "Pick: " 2>/dev/null
}

kb_os_init
"$@"
