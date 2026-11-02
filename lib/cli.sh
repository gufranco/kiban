#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${KB_LIB:?}/state.sh"

kb_hint() {
  kb_say 0 "${KB_PROG}: $1. run '${KB_PROG} help' for usage." >&2
}

kb_cli_version() {
  kb_version "${KB_PROG}"
  kb_cv_platform="$(uname -sr)" || kb_cv_platform="unknown"
  printf 'platform: %s\n' "${kb_cv_platform}"
}

kb_doctor_row() {
  printf '%-18s %-8s %s\n' "$1" "$2" "$3"
}

kb_flavor_version() {
  printf '%s\n' "$1" | awk '{
    for (i = 1; i <= NF; i++) {
      t = $i
      gsub(/[,;()]/, "", t)
      sub(/^v/, "", t)
      if (t ~ /^[0-9]+(\.[0-9]+)+[a-z0-9]*$/ || t ~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/) { print t; exit }
    }
  }'
}

kb_tool_line() {
  kb_tl_line="$(printf '%s\n' "$1" | awk '/BusyBox|This is not GNU/ { print; exit }')"
  if [ -z "${kb_tl_line}" ]; then
    kb_tl_line="$(printf '%s\n' "$1" | sed -n '1p')"
  fi
  printf '%s\n' "${kb_tl_line}"
}

kb_tool_flavor() {
  kb_tf_raw="$("$1" --version 2>&1 </dev/null)" || true
  kb_tf_text="$(kb_tool_line "${kb_tf_raw}")"
  kb_tf_version="$(kb_flavor_version "${kb_tf_text}")"
  case "${kb_tf_text}" in
  *uutils*) kb_tf_name=uutils ;;
  *BusyBox*) kb_tf_name=busybox ;;
  *"This is not GNU"*)
    kb_tf_name=busybox
    kb_tf_version=""
    ;;
  *GNU*) kb_tf_name=gnu ;;
  *mawk*) kb_tf_name=mawk ;;
  *"awk version"*) kb_tf_name=bsd ;;
  *)
    kb_tf_version=""
    case "$1:${KB_OS}" in
    *uutils*:* | */cargo/*:*) kb_tf_name=uutils ;;
    *:Darwin) kb_tf_name=bsd ;;
    *) kb_tf_name=unknown ;;
    esac
    ;;
  esac
  printf '%s%s\n' "${kb_tf_name}" "${kb_tf_version:+ ${kb_tf_version}}"
}

kb_doctor_tool() {
  kb_dt_found="$(command -v "$1" 2>/dev/null || true)"
  if [ -z "${kb_dt_found}" ]; then
    kb_doctor_row "$1" missing "$2"
    return 1
  fi
  kb_dt_note=""
  case "$1" in
  awk | sed) kb_dt_note="$(kb_tool_flavor "${kb_dt_found}")" ;;
  *) ;;
  esac
  kb_doctor_row "$1" ok "${kb_dt_found}${kb_dt_note:+, ${kb_dt_note}}"
  return 0
}

kb_doctor_rosetta() {
  [ "${KB_HOST_ARCH}" = aarch64 ] || return 0
  if arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    kb_doctor_row rosetta ok "runs x86_64 images in the VM"
  else
    kb_doctor_row rosetta warn "softwareupdate --install-rosetta, or x86_64 images are emulated"
  fi
}

kb_doctor() {
  kb_dr_status=0
  kb_host_load
  kb_doctor_tool docker "required" || kb_dr_status=1
  for kb_dr_tool in awk sed; do
    kb_doctor_tool "${kb_dr_tool}" "required" || kb_dr_status=1
  done
  case "${KB_OS}" in
  Darwin)
    kb_doctor_tool colima "runs the Docker VM" || kb_dr_status=1
    kb_doctor_rosetta
    ;;
  *)
    kb_doctor_tool systemctl "starts and stops the Docker engine" || kb_dr_status=1
    kb_doctor_tool sudo "required to start and stop the Docker engine" || kb_dr_status=1
    ;;
  esac
  kb_doctor_tool fzf "optional, picks containers; a numbered menu otherwise" || true
  return "${kb_dr_status}"
}

kb_cli_is_option() {
  case "$1" in
  --* | -?*) return 0 ;;
  *) return 1 ;;
  esac
}

kb_cli_takes_value() {
  case " ${KB_VALUE_OPTIONS} " in
  *" $1 "*) return 0 ;;
  *) return 1 ;;
  esac
}

kb_cli_assign() {
  if ! kb_cli_takes_value "${1%%=*}"; then
    if kb_option_flag "${1%%=*}"; then
      kb_hint "option '${1%%=*}' takes no value"
    else
      kb_hint "unknown option '${1%%=*}'"
    fi
    return 1
  fi
  kb_option_value "${1%%=*}" "${1#*=}"
}

kb_cli_option() {
  KB_CLI_USED=0
  case "$1" in
  --*=*) kb_cli_assign "$1" ;;
  --?*)
    kb_option_flag "$1" && return 0
    if ! kb_cli_takes_value "$1"; then
      kb_hint "unknown option '$1'"
      return 1
    fi
    if [ "$2" -lt 1 ]; then
      kb_hint "option '$1' needs a value"
      return 1
    fi
    KB_CLI_USED=1
    kb_option_value "$1" "$3"
    ;;
  *)
    kb_hint "unknown option '$1'"
    return 1
    ;;
  esac
}

kb_cli_parse() {
  kb_cp_left="$#"
  kb_cp_literal=0
  while [ "${kb_cp_left}" -gt 0 ]; do
    kb_cp_arg="$1"
    shift
    kb_cp_left=$((kb_cp_left - 1))
    if [ "${kb_cp_literal}" -eq 1 ] || ! kb_cli_is_option "${kb_cp_arg}"; then
      set -- "$@" "${kb_cp_arg}"
    elif [ "${kb_cp_arg}" = "--" ]; then
      kb_cp_literal=1
    else
      kb_cli_option "${kb_cp_arg}" "${kb_cp_left}" "${1:-}" || return 1
      if [ "${KB_CLI_USED}" -eq 1 ]; then
        shift
        kb_cp_left=$((kb_cp_left - 1))
      fi
    fi
  done
  kb_dispatch "$@"
}
