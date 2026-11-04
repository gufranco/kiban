#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# shellcheck disable=SC2016

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup() {
  kb_test_setup
}

teardown() {
  kb_test_teardown
}

fake_tool() {
  local path="$1"
  local answer="$2"
  mkdir -p "$(dirname "${path}")"
  printf '#!/bin/sh\n{ set +x; } 2>/dev/null\nprintf "%%s\\n" %q\n' "${answer}" >"${path}"
  chmod +x "${path}"
}

@test "doctor on a Mac lists docker, colima, Rosetta and fzf" {
  # Arrange
  local expected="rosetta            ok       runs x86_64 images in the VM"

  # Act
  run kb_test_run doctor

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "gum                ok       "* ]]
  [[ "${lines[1]}" == "docker             ok       ${FAKES}/docker" ]]
  [[ "${output}" == *"colima             ok       ${FAKES}/colima"* ]]
  [[ "${output}" == *"${expected}"* ]]
  [[ "${output}" == *"fzf                ok       ${FAKES}/fzf"* ]]
}

@test "doctor warns when Rosetta is not installed on Apple Silicon" {
  # Arrange
  rm -f "${WORK}/rosetta"

  # Act
  run kb_test_run doctor

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"rosetta            warn     softwareupdate --install-rosetta, or x86_64 images are emulated"* ]]
}

@test "doctor on an Intel Mac has no Rosetta row" {
  # Arrange
  kb_test_host 8 16 512 0

  # Act
  run kb_test_run doctor

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" != *"rosetta"* ]]
}

@test "doctor on Linux lists systemctl and sudo instead of colima" {
  # Arrange
  export KIBAN_OS=Linux

  # Act
  run kb_test_run doctor

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"systemctl          ok"* ]]
  [[ "${output}" == *"sudo               ok"* ]]
  [[ "${output}" != *"colima"* ]]
}

@test "doctor fails without docker and passes without fzf" {
  # Arrange
  local farm
  farm="$(kb_test_farm docker fzf)"

  # Act
  run kb_test_run_path "${farm}" doctor

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${lines[1]}" == "docker             missing  required" ]]
  [[ "${output}" == *"fzf                missing  optional, picks containers without gum; a numbered menu otherwise" ]]
}

@test "doctor fails on a Mac without colima and on Linux without systemctl" {
  # Arrange
  local farm
  farm="$(kb_test_farm colima systemctl)"

  # Act
  run kb_test_run_path "${farm}" doctor
  local darwin="${status}"
  KIBAN_OS=Linux run kb_test_run_path "${farm}" doctor

  # Assert
  [[ "${darwin}" -eq 1 ]]
  [[ "${status}" -eq 1 ]]
}

@test "a uutils, BusyBox, GNU, mawk or one true awk tool is named with its version" {
  # Arrange
  fake_tool "${WORK}/t/u" "sed (uutils sed) 0.1.0"
  fake_tool "${WORK}/t/b" "BusyBox v1.36.1 (2024-03-22) multi-call binary."
  fake_tool "${WORK}/t/g" "GNU sed 4.9"
  fake_tool "${WORK}/t/m" "mawk 1.3.4 20240123"
  fake_tool "${WORK}/t/o" "awk version 20200816"
  local found=""

  # Act
  for tool in u b g m o; do
    found="${found}$(kb_test_call kb_tool_flavor "${WORK}/t/${tool}");"
  done

  # Assert
  [[ "${found}" == "uutils 0.1.0;busybox 1.36.1;gnu 4.9;mawk 1.3.4;bsd 20200816;" ]]
}

@test "a BusyBox applet that names itself after its error line is named busybox" {
  # Arrange
  mkdir -p "${WORK}/bin"
  printf '#!/bin/sh\necho "awk: invalid option -- -"\necho "BusyBox v1.37.0 (Ubuntu 1:1.37.0-7ubuntu1) multi-call binary."\n' >"${WORK}/bin/awk"
  chmod +x "${WORK}/bin/awk"

  # Act
  run kb_test_call kb_tool_flavor "${WORK}/bin/awk"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "busybox 1.37.0" ]]
}

@test "BusyBox sed, which says it is not GNU sed, is named busybox" {
  # Arrange
  fake_tool "${WORK}/bin/sed" "This is not GNU sed version 4.0"

  # Act
  run kb_test_call kb_tool_flavor "${WORK}/bin/sed"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "busybox" ]]
}

@test "a silent tool is named by where it lives and the system it runs on" {
  # Arrange
  fake_tool "${WORK}/cargo/bin/sed" ""
  fake_tool "${WORK}/t/sed" ""
  local cargo darwin

  # Act
  cargo="$(kb_test_call kb_tool_flavor "${WORK}/cargo/bin/sed")"
  darwin="$(kb_test_call kb_tool_flavor "${WORK}/t/sed")"
  KIBAN_OS=Linux run kb_test_call kb_tool_flavor "${WORK}/t/sed"

  # Assert
  [[ "${cargo}" == "uutils" ]]
  [[ "${darwin}" == "bsd" ]]
  [[ "${output}" == "unknown" ]]
}

@test "a JSON string escapes quotes, backslashes and control characters" {
  # Arrange
  local text
  text="$(printf 'a"b\\c\td\ne')"

  # Act
  run kb_test_call kb_json_string "${text}"

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == '"a\"b\\c\u0009d\ne"' ]]
}

@test "help and version never print a line wider than 80 columns" {
  # Arrange
  local page widest

  # Act
  page="$(
    kb_test_run help
    kb_test_run version
  )"

  # Assert
  widest="$(printf '%s\n' "${page}" | awk '{ if (length($0) > w) w = length($0) } END { print w + 0 }')"
  [[ "${widest}" -le 80 ]]
}
