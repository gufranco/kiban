#!/usr/bin/env bash

KIBAN_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${KIBAN_TESTS_DIR}/.." && pwd)"
KIBAN_TEST_OS="$(uname -s)"
export KIBAN_TESTS_DIR REPO_DIR KIBAN_TEST_OS
PATH="${KIBAN_TESTS_DIR}/bin:${PATH}"
export PATH

kb_test_write() {
  local name="$1"
  local body="$2"
  printf '#!/bin/sh\n{ set +x; } 2>/dev/null\nW=%q\n%s\n' "${WORK}" "${body}" >"${FAKES}/${name}.tmp"
  chmod +x "${FAKES}/${name}.tmp"
  mv -f "${FAKES}/${name}.tmp" "${FAKES}/${name}"
}

kb_test_fakes() {
  # shellcheck disable=SC2016
  kb_test_write docker '
printf "docker %s\n" "$*" >>"$W/calls"
[ "$1" = --context ] && shift 2
case " ${FAKE_FAIL:-} " in *" docker:$1 "*) exit 1 ;; esac
case "$1" in
info) [ -e "$W/docker-up" ] ;;
container) [ -e "$W/state-$5" ] || exit 1; cat "$W/state-$5" ;;
ps)
  case "$2" in
  -aq) cat "$W/ids" 2>/dev/null ;;
  -a) for f in "$W"/state-*; do [ -e "$f" ] && printf "%s %s\n" "${f##*/state-}" "$(cat "$f")"; done ;;
  *) for f in "$W"/state-*; do [ -e "$f" ] && grep -qx running "$f" && printf "%s\n" "${f##*/state-}"; done ;;
  esac
  ;;
run) while [ "$#" -gt 0 ]; do [ "$1" = --name ] && printf running >"$W/state-$2"; shift; done; echo id ;;
start) printf running >"$W/state-$2" ;;
stop) shift; for n in "$@"; do [ -e "$W/state-$n" ] && printf exited >"$W/state-$n"; done; exit 0 ;;
rm) rm -f "$W/state-$3" ;;
*) exit 0 ;;
esac'
  # shellcheck disable=SC2016
  kb_test_write colima '
printf "colima %s\n" "$*" >>"$W/calls"
case " ${FAKE_FAIL:-} " in *" colima:$1 "*) exit 1 ;; esac
[ "$1" = list ] && cat "$W/colima-list" 2>/dev/null
exit 0'
  # shellcheck disable=SC2016
  kb_test_write systemctl '
printf "systemctl %s\n" "$*" >>"$W/calls"
case " ${FAKE_FAIL:-} " in *" systemctl:$1 "*) exit 1 ;; esac
exit 0'
  # shellcheck disable=SC2016
  kb_test_write fzf '
printf "fzf %s\n" "$*" >>"$W/calls"
head -n "${FAKE_FZF_PICK:-1}"'
  # shellcheck disable=SC2016
  kb_test_write sysctl '
cat "$W/sysctl-$2" 2>/dev/null || exit 1'
  # shellcheck disable=SC2016
  kb_test_write nproc '
cat "$W/nproc"'
  # shellcheck disable=SC2016
  kb_test_write uname '
case "$1" in -m) cat "$W/machine" ;; -sr) printf "FakeOS 1.0\n" ;; *) printf "FakeOS\n" ;; esac'
  # shellcheck disable=SC2016
  kb_test_write df '
printf "Filesystem 1024-blocks Used Available Capacity Mounted on\n/dev/fake %s 0 0 0%% /\n" "$(cat "$W/disk-kib")"'
  # shellcheck disable=SC2016
  kb_test_write arch '
[ -e "$W/rosetta" ]'
  if [[ "${KIBAN_TEST_OS}" == "Linux" ]]; then
    kb_test_sudo_passthrough
  else
    ln -sf "${KIBAN_TESTS_DIR}/shim/sudo" "${FAKES}/sudo"
  fi
}

kb_test_sudo_passthrough() {
  local real
  real="$(command -v sudo)"
  # shellcheck disable=SC2016
  printf '#!/bin/sh\n{ set +x; } 2>/dev/null\nexec %q env "PATH=$PATH" "FAKE_FAIL=${FAKE_FAIL:-}" "$@"\n' "${real}" >"${FAKES}/sudo"
  chmod +x "${FAKES}/sudo"
}

kb_test_host() {
  printf '%s' "$1" >"${WORK}/sysctl-hw.ncpu"
  printf '%s' "$1" >"${WORK}/nproc"
  printf '%s' $(($2 * 1073741824)) >"${WORK}/sysctl-hw.memsize"
  printf '%s' $(($3 * 1048576)) >"${WORK}/disk-kib"
  printf '%s' "$4" >"${WORK}/sysctl-hw.optional.arm64"
  if [[ "$4" == 1 ]]; then
    printf 'aarch64' >"${WORK}/machine"
  else
    printf 'x86_64' >"${WORK}/machine"
  fi
}

kb_test_setup() {
  WORK="$(mktemp -d "${BATS_TMPDIR:-/tmp}/kiban.XXXXXX")"
  FAKES="${WORK}/fakes"
  mkdir -p "${FAKES}" "${WORK}/home"
  : >"${WORK}/calls"
  kb_test_fakes
  kb_test_host 14 36 1024 1
  touch "${WORK}/rosetta"
  export WORK FAKES
  export HOME="${WORK}/home"
  export KIBAN_OS=Darwin
}

kb_test_teardown() {
  rm -rf "${WORK:?}"
}

kb_test_path() {
  printf '%s:%s\n' "${FAKES}" "${PATH}"
}

kb_test_run() {
  local search_path
  local -a shell_words
  search_path="$(kb_test_path)"
  read -r -a shell_words <<<"${KIBAN_TEST_SHELL:-sh}"
  PATH="${search_path}" "${shell_words[@]}" "${REPO_DIR}/bin/kiban" "$@"
}

kb_test_run_path() {
  local search_path="$1"
  local -a shell_words
  shift
  read -r -a shell_words <<<"${KIBAN_TEST_SHELL:-sh}"
  PATH="${search_path}" "${shell_words[@]}" "${REPO_DIR}/bin/kiban" "$@"
}

kb_test_call() {
  local search_path
  local -a shell_words
  search_path="$(kb_test_path)"
  read -r -a shell_words <<<"${KIBAN_TEST_SHELL:-sh}"
  PATH="${search_path}" "${shell_words[@]}" "${KIBAN_TESTS_DIR}/call.sh" "$@"
}

kb_test_answering() {
  local answer="$1"
  shift
  printf '%b' "${answer}" | KIBAN_INTERACTIVE=1 kb_test_run "$@"
}

kb_test_calls() {
  cat "${WORK}/calls"
}

kb_test_state() {
  printf '%s' "$2" >"${WORK}/state-$1"
}

kb_test_farm() {
  local farm="${WORK}/farm"
  local dir tool search_path
  local -a dirs batch
  mkdir -p "${farm}"
  search_path="$(kb_test_path)"
  IFS=: read -r -a dirs <<<"${search_path}"
  for dir in "${dirs[@]}"; do
    batch=()
    for tool in "${dir}"/*; do
      kb_test_farm_wanted "${farm}" "${tool}" "$@" && batch+=("${tool}")
    done
    [[ ${#batch[@]} -eq 0 ]] || ln -s "${batch[@]}" "${farm}/"
  done
  printf '%s\n' "${farm}"
}

kb_test_farm_wanted() {
  local farm="$1"
  local tool="$2"
  local name="${2##*/}"
  local excluded
  shift 2
  [[ -x "${tool}" && ! -e "${farm}/${name}" ]] || return 1
  for excluded in "$@"; do
    [[ "${name}" == "${excluded}" ]] && return 1
  done
  return 0
}
