#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${KB_LIB:?}/state.sh"

KIBAN_VERSION="1.0.1"

kb_version() {
  printf '%s %s\n' "${1:-${KB_PROG}}" "${KIBAN_VERSION}"
}

kb_wrap() {
  awk -v width="${KB_WIDTH}" -v indent="$1" '
    function pad(n,   s) {
      s = ""
      while (n-- > 0) { s = s " " }
      return s
    }
    length($0) <= width { print; next }
    {
      match($0, /^ */)
      n = split($0, word, " ")
      out = substr($0, 1, RLENGTH) word[1]
      for (i = 2; i <= n; i++) {
        if (length(out) + 1 + length(word[i]) > width) {
          print out
          out = pad(indent) word[i]
        } else {
          out = out " " word[i]
        }
      }
      print out
    }'
}

kb_terminal() {
  [ "${KIBAN_TERMINAL:-}" = 1 ] || [ -t 1 ]
}

kb_say() {
  kb_sy_text="$2"
  if [ "${#kb_sy_text}" -le "${KB_WIDTH}" ] || ! kb_terminal; then
    printf '%s\n' "${kb_sy_text}"
    return 0
  fi
  printf '%s\n' "${kb_sy_text}" | kb_wrap "$1"
}

kb_info() {
  [ "${KIBAN_JSON:-n}" != y ] || return 0
  kb_say 8 "$*"
}

kb_success() {
  [ "${KIBAN_JSON:-n}" != y ] || return 0
  if kb_ui_out; then
    kb_ui_done "$*"
    return 0
  fi
  kb_say 0 "$*"
}

kb_warning() {
  if kb_ui_err; then
    kb_ui_log WARN "$*"
    return 0
  fi
  kb_say 0 "${KB_PROG}: warning: $*" >&2
}

kb_error() {
  if kb_ui_err; then
    kb_ui_log ERROR "$*"
    return 0
  fi
  kb_say 0 "${KB_PROG}: $*" >&2
}

kb_json_string() {
  printf '%s' "$1" | awk '
    BEGIN { for (i = 1; i < 32; i++) code[sprintf("%c", i)] = sprintf("\\u%04x", i) }
    function escape(s,   r, c, i) {
      r = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\") r = r "\\\\"
        else if (c == "\"") r = r "\\\""
        else if (c in code) r = r code[c]
        else r = r c
      }
      return r
    }
    { out = out (NR > 1 ? "\\n" : "") escape($0) }
    END { printf "\"%s\"", out }'
}

kb_cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

kb_is_uint() {
  case "$1" in
  '' | *[!0-9]*) return 1 ;;
  *) return 0 ;;
  esac
}

kb_os_init() {
  [ -n "${KB_OS}" ] || KB_OS="$(uname -s)"
}

kb_confirm_typed() {
  if ! kb_interactive; then
    kb_error "stopped: no terminal to confirm on, so nothing was changed."
    return 1
  fi
  kb_ct_answer=""
  if kb_ui_prompts; then
    kb_ui_danger "This will $2." "Nothing it removes can be recovered."
    kb_ct_answer="$(kb_ui_input "Type $1 to confirm, or anything else to stop" "$1")" || kb_ct_answer=""
  else
    printf 'Type %s to %s, or anything else to stop: ' "$1" "$2" >&2
    IFS= read -r kb_ct_answer || true
  fi
  [ "${kb_ct_answer}" = "$1" ] && return 0
  kb_error "stopped: nothing was changed."
  return 1
}

kb_interactive() {
  [ "${KIBAN_INTERACTIVE:-}" = 1 ] && return 0
  [ -t 0 ]
}
