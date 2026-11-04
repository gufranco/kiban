#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${KB_LIB:?}/state.sh"

# shellcheck disable=SC2034
kb_ui_set() {
  KB_UI_ACCENT="$1"
  KB_UI_OK="$2"
  KB_UI_WARN="$3"
  KB_UI_ERR="$4"
  KB_UI_MUTED="$5"
  KB_UI_TEXT="$6"
  KB_UI_SURFACE="$7"
  KB_UI_HELP="$8"
}

kb_ui_palette() {
  case "$1" in
  kodougu) kb_ui_set "#F25D94" "#50FA7B" "#FFB86C" "#FF5555" "#6C7086" "#CDD6F4" "#313244" pink ;;
  catppuccin-mocha) kb_ui_set "#CBA6F7" "#A6E3A1" "#FAB387" "#F38BA8" "#6C7086" "#CDD6F4" "#313244" dark ;;
  catppuccin-latte) kb_ui_set "#8839EF" "#40A02B" "#FE640B" "#D20F39" "#8C8FA1" "#4C4F69" "#CCD0DA" light ;;
  dracula) kb_ui_set "#BD93F9" "#50FA7B" "#FFB86C" "#FF5555" "#6272A4" "#F8F8F2" "#44475A" dracula ;;
  nord) kb_ui_set "#88C0D0" "#A3BE8C" "#EBCB8B" "#BF616A" "#4C566A" "#D8DEE9" "#3B4252" dark ;;
  gruvbox) kb_ui_set "#FE8019" "#B8BB26" "#FABD2F" "#FB4934" "#928374" "#EBDBB2" "#3C3836" dark ;;
  tokyo-night) kb_ui_set "#7AA2F7" "#9ECE6A" "#E0AF68" "#F7768E" "#565F89" "#C0CAF5" "#292E42" tokyo-night ;;
  mono) kb_ui_set "" "" "" "" "" "" "" ascii ;;
  *) return 1 ;;
  esac
}

kb_ui_is_colour() {
  case "$1" in
  \#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) return 0 ;;
  *) return 1 ;;
  esac
}

# shellcheck disable=SC2034
kb_ui_setup() {
  if ! kb_ui_palette "${KB_THEME}"; then
    kb_ui_palette mono
    KB_UI_PROBLEM="--theme must be one of ${KB_UI_THEMES}, got: ${KB_THEME}"
    return 1
  fi
  if [ -n "${KB_ACCENT}" ] && ! kb_ui_is_colour "${KB_ACCENT}"; then
    KB_UI_PROBLEM="KODOUGU_ACCENT must be a colour such as #CBA6F7, got: ${KB_ACCENT}"
    return 1
  fi
  if [ -n "${KB_ACCENT}" ]; then
    KB_UI_ACCENT="${KB_ACCENT}"
  fi
  if [ -n "${NO_COLOR:-}" ]; then
    kb_ui_palette mono
  fi
}

kb_ui_forced() {
  [ "${KIBAN_TEST_GUM:-}" = 1 ]
}

kb_ui_has_gum() {
  command -v gum >/dev/null 2>&1
}

kb_ui_prompts() {
  kb_ui_forced && return 0
  [ -t 0 ] && [ -t 2 ] && kb_ui_has_gum
}

kb_ui_err() {
  kb_ui_forced && return 0
  [ "${KB_UI_STEP}" = 1 ] && return 0
  [ -t 2 ] && kb_ui_has_gum
}

kb_ui_out() {
  kb_ui_forced && return 0
  [ -t 1 ] && kb_ui_has_gum
}

kb_gum() {
  if [ -n "${KB_UI_TEXT}" ]; then
    CLICOLOR_FORCE=1 gum "$@"
    return
  fi
  gum "$@"
}

kb_ui_ink() {
  kb_ui_colour="$1"
  shift
  if [ -z "${kb_ui_colour}" ]; then
    kb_gum style "$@"
    return
  fi
  kb_gum style --foreground "${kb_ui_colour}" "$@"
}

kb_ui_header() {
  kb_uh_name=$(kb_ui_ink "${KB_UI_ACCENT}" --bold -- "kiban")
  kb_uh_number=$(kb_version | sed -n '1p')
  kb_uh_number="${kb_uh_number#kiban }"
  kb_uh_version=$(kb_ui_ink "${KB_UI_MUTED}" -- "${kb_uh_number}")
  kb_uh_tagline=$(kb_ui_ink "${KB_UI_TEXT}" -- "${KB_TAGLINE}")
  kb_uh_top=$(kb_gum join --horizontal "${kb_uh_name}" "  " "${kb_uh_version}")
  kb_uh_body=$(kb_gum join --vertical "${kb_uh_top}" "${kb_uh_tagline}")
  printf '\n' >&2
  kb_gum style --border rounded --border-foreground "${KB_UI_ACCENT}" --padding "0 2" -- "${kb_uh_body}" >&2
  printf '\n' >&2
}

kb_ui_title() {
  printf '\n' >&2
  kb_ui_ink "${KB_UI_ACCENT}" --bold -- "$1" >&2
  printf '\n' >&2
}

kb_ui_titled() {
  if kb_ui_prompts; then
    kb_ui_title "$1"
  fi
}

kb_ui_lower_first() {
  printf '%s\n' "$1" | awk 'NR == 1 { a = substr($0, 1, 1); b = substr($0, 2, 1); if (a != tolower(a) && b != toupper(b)) { $0 = tolower(a) substr($0, 2) } } { print }'
}

kb_ui_log() {
  kb_ul_level="$1"
  kb_ul_text=$(kb_ui_lower_first "$2")
  case "${kb_ul_level}" in
  ERROR) kb_ul_colour="${KB_UI_ERR}" ;;
  WARN) kb_ul_colour="${KB_UI_WARN}" ;;
  *) kb_ul_colour="${KB_UI_OK}" ;;
  esac
  kb_ul_label=$(kb_ui_ink "${kb_ul_colour}" --bold -- "${kb_ul_level}")
  printf '%s kiban: %s\n' "${kb_ul_label}" "${kb_ul_text}" >&2
}

kb_ui_choose() {
  kb_uc_header="$1"
  shift
  kb_gum choose --header "${kb_uc_header}" --cursor "> " --height 14 \
    --cursor.foreground "${KB_UI_ACCENT}" --selected.foreground "${KB_UI_ACCENT}" \
    --header.foreground "${KB_UI_TEXT}" "$@"
}

kb_ui_input() {
  kb_ui_header_text="$1"
  kb_ui_placeholder="$2"
  shift 2
  kb_gum input --header "${kb_ui_header_text}" --placeholder "${kb_ui_placeholder}" --prompt "> " \
    --prompt.foreground "${KB_UI_ACCENT}" --cursor.foreground "${KB_UI_ACCENT}" \
    --header.foreground "${KB_UI_TEXT}" --placeholder.foreground "${KB_UI_MUTED}" "$@"
}

kb_ui_write() {
  kb_gum write --header "$1" --placeholder "$2" --width 72 --height 8 --show-line-numbers \
    --cursor.foreground "${KB_UI_ACCENT}" --header.foreground "${KB_UI_TEXT}" \
    --placeholder.foreground "${KB_UI_MUTED}"
}

kb_ui_confirm() {
  kb_ucf_prompt="$1"
  kb_ucf_yes="$2"
  kb_ucf_no="$3"
  shift 3
  kb_gum confirm "${kb_ucf_prompt}" --affirmative "${kb_ucf_yes}" --negative "${kb_ucf_no}" \
    --prompt.foreground "${KB_UI_TEXT}" --selected.background "${KB_UI_ACCENT}" \
    --unselected.background "${KB_UI_SURFACE}" "$@"
}

kb_ui_summary() {
  kb_us2_pairs=$(($# / 2))
  while [ "${kb_us2_pairs}" -gt 0 ]; do
    kb_us2_label=$(printf '%-7s' "$1")
    kb_us2_label=$(kb_ui_ink "${KB_UI_MUTED}" -- "${kb_us2_label}")
    kb_us2_value=$(kb_ui_ink "${KB_UI_TEXT}" --bold -- "$2")
    shift 2
    set -- "$@" "${kb_us2_label} ${kb_us2_value}"
    kb_us2_pairs=$((kb_us2_pairs - 1))
  done
  printf '\n'
  kb_gum style --border rounded --border-foreground "${KB_UI_MUTED}" --padding "0 1" -- "$@"
  printf '\n'
}

kb_ui_spin() {
  kb_us_title="$1"
  kb_us_log="$2"
  shift 2
  (KB_UI_STEP=1 && "$@") 2>"${kb_us_log}" &
  kb_us_pid=$!
  if ! kb_ui_spin_wait "${kb_us_title}" "${kb_us_pid}"; then
    kill "${kb_us_pid}" 2>/dev/null
    exit 130
  fi
  kb_us_status=0
  wait "${kb_us_pid}" || kb_us_status=$?
  cat "${kb_us_log}" >&2
  return "${kb_us_status}"
}

kb_ui_spin_wait() {
  # shellcheck disable=SC2016
  kb_uw_loop='while kill -0 "$1" 2>/dev/null; do sleep 0.1; done'
  kb_gum spin --spinner dot --spinner.foreground "${KB_UI_ACCENT}" --title.foreground "${KB_UI_TEXT}" --title "$1" -- sh -c "${kb_uw_loop}" _ "$2" >&2
}

kb_ui_table() {
  kb_ut_line="-"
  if [ -n "${KB_UI_TEXT}" ]; then
    kb_ut_line=$(printf '\342\224\200')
  fi
  kb_ut_body=$(kb_ui_table_body "${kb_ut_line}")
  kb_gum style --border rounded --border-foreground "${KB_UI_MUTED}" --padding "0 1" -- "${kb_ut_body}"
}

kb_ui_table_body() {
  LC_ALL=C awk -F '\t' -v acc="${KB_UI_ACCENT}" -v ok="${KB_UI_OK}" -v warn="${KB_UI_WARN}" \
    -v bad="${KB_UI_ERR}" -v txt="${KB_UI_TEXT}" -v mut="${KB_UI_MUTED}" -v dash="$1" \
    -f "${KB_LIB}/table.awk"
}

kb_ui_done() {
  printf '\n'
  kb_ui_ink "${KB_UI_OK}" --bold -- "$1"
}

kb_ui_badge() {
  kb_ub_colour="$1"
  shift
  if [ -z "${kb_ub_colour}" ]; then
    kb_gum style --bold --underline --padding "0 1" -- "$*"
    return
  fi
  kb_gum style --background "${kb_ub_colour}" --foreground "#1E1E2E" --bold --padding "0 1" -- "$*"
}

kb_ui_chip() {
  if [ -z "${KB_UI_SURFACE}" ]; then
    kb_gum style --padding "0 1" -- "$1"
    return
  fi
  kb_gum style --background "${KB_UI_SURFACE}" --foreground "${KB_UI_TEXT}" --padding "0 1" -- "$1"
}

kb_ui_danger() {
  kb_ud_title=$(kb_ui_ink "${KB_UI_ERR}" --bold -- "$1")
  shift
  kb_gum style --border thick --border-foreground "${KB_UI_ERR}" --padding "0 1" -- "${kb_ud_title}" "$@" >&2
}

kb_ui_markdown() {
  awk '
    NR == 1 {
      split($0, head, " - ")
      printf "# %s\n\n%s\n", head[1], head[2]
      next
    }
    /^[a-z][a-z ]*:$/ {
      if (open) { print "```" }
      printf "\n## %s\n\n```text\n", toupper(substr($0, 1, 1)) substr($0, 2, length($0) - 2)
      open = 1
      next
    }
    { print }
    END { if (open) { print "```" } }
  '
}
