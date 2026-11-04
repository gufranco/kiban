#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup() {
  kb_test_setup
  unset KODOUGU_THEME KODOUGU_ACCENT KIBAN_THEME NO_COLOR
  export KIBAN_TEST_GUM=1
  export KIBAN_TEST_GUM_LOG="${WORK}/gum.log"
  export KIBAN_TEST_GUM_ANSWERS="${WORK}/answers"
  export KIBAN_INTERACTIVE=1
  : >"${KIBAN_TEST_GUM_LOG}"
}

teardown() {
  kb_test_teardown
}

answers() {
  printf '%s\n' "$@" >"${KIBAN_TEST_GUM_ANSWERS}"
}

called() {
  grep -q -F -- "$1" "${KIBAN_TEST_GUM_LOG}"
}

@test "the menu starts the services marked in gum" {
  # Arrange
  answers "Start services" "postgres"

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"run Docker and local dev databases at full speed"* ]]
  [[ "${output}" == *"postgres is running on 127.0.0.1:5432."* ]]
  called "choose --header x marks a service"
}

@test "the menu says nothing was marked when Enter submits no service" {
  # Arrange
  answers "Start services" ""

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"ERROR kiban: nothing was marked. press x on each service to start, then Enter."* ]]
}

@test "the menu starts Docker" {
  # Arrange
  touch "${WORK}/docker-up"
  answers "Start Docker"

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"colima start"* ]]
  [[ "${output}" == *"Started. Docker is ready in the default VM."* ]]
}

@test "the menu stops Docker" {
  # Arrange
  answers "Stop Docker"

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"colima stop"* ]]
}

@test "the menu stops the containers picked in gum" {
  # Arrange
  kb_test_state redis running
  kb_test_state postgres running
  answers "Stop containers" "redis"

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/state-redis")" == "exited" ]]
  [[ "$(<"${WORK}/state-postgres")" == "running" ]]
  called "--no-limit"
}

@test "the menu shows every service in a table" {
  # Arrange
  kb_test_state redis running
  kb_test_state mongo exited
  answers "Show every service"

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Service"*"State"*"Address"* ]]
  [[ "${output}" == *"running"* ]]
  [[ "${output}" == *"exited"* ]]
  [[ "${output}" == *"absent"* ]]
}

@test "the menu opens a shell in the container picked in gum" {
  # Arrange
  kb_test_state redis running
  answers "Open a shell in a container" "redis"

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"exec"*"redis"* ]]
}

@test "the menu follows the log of the container picked in gum" {
  # Arrange
  kb_test_state redis running
  answers "Follow a container's log" "redis"

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"logs"*"redis"* ]]
}

@test "the menu shows every setting in a table" {
  # Arrange
  answers "Show every setting"

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Setting"*"Value"*"From"* ]]
  [[ "${output}" == *"KIBAN_POSTGRES_PORT"* ]]
}

@test "the menu stops on an answer it did not offer" {
  # Arrange
  answers "Something else"

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "a cancelled menu stops" {
  # Arrange
  answers "<cancel>"

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "a cancelled service choice starts nothing" {
  # Arrange
  answers "Start services" "<cancel>"

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "a cancelled container pick stops nothing" {
  # Arrange
  kb_test_state redis running
  answers "<cancel>"

  # Act
  run kb_test_run down </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "$(<"${WORK}/state-redis")" == "running" ]]
}

@test "reset asks for the name inside a danger box" {
  # Arrange
  kb_test_state postgres running
  answers "postgres"

  # Act
  run kb_test_run reset postgres </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"Reset postgres."* ]]
  called "--border thick"
  called "input --header Type postgres to confirm, or anything else to stop"
}

@test "reset stops when the typed name is wrong" {
  # Arrange
  kb_test_state postgres running
  answers "redis"

  # Act
  run kb_test_run reset postgres </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"ERROR kiban: stopped: nothing was changed."* ]]
  [[ -e "${WORK}/state-postgres" ]]
}

@test "reset stops when the typed confirmation is cancelled" {
  # Arrange
  kb_test_state postgres running
  answers "<cancel>"

  # Act
  run kb_test_run reset postgres </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ -e "${WORK}/state-postgres" ]]
}

@test "doctor draws its rows in a table" {
  # Arrange
  local expected="Ready. Every tool kiban needs is here."

  # Act
  run kb_test_run doctor </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"${expected}"* ]]
}

@test "doctor draws a missing Rosetta as a warning row" {
  # Arrange
  rm -f "${WORK}/rosetta"

  # Act
  run kb_test_run doctor </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"rosetta"*"warn"*"softwareupdate --install-rosetta"* ]]
}

@test "a warning is drawn with the WARN level" {
  # Arrange
  mkdir -p "${HOME}/.colima/_lima/_disks/colima-old"
  export FAKE_FAIL=colima:list
  answers "default"

  # Act
  run kb_test_run purge </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"WARN"*"kiban: colima list failed, so orphan disks are left in place."* ]]
}

@test "doctor reports a missing tool below the table" {
  # Arrange
  local farm
  farm="$(kb_test_farm docker)"

  # Act
  run kb_test_run_path "${farm}" doctor </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"ERROR kiban: a required tool is missing."* ]]
}

@test "doctor fails without gum" {
  # Arrange
  local farm
  farm="$(kb_test_farm gum)"

  # Act
  KIBAN_TEST_GUM=0 run kb_test_run_path "${farm}" doctor </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"gum                missing  install with: brew install gum"* ]]
}

@test "version shows the version and platform as badges" {
  # Arrange
  local version
  version="$(sed -n 's/^KIBAN_VERSION="\(.*\)"$/\1/p' "${REPO_DIR}/lib/core.sh")"

  # Act
  run kb_test_run version </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "kiban ${version} platform FakeOS 1.0" ]]
}

@test "help is formatted with gum" {
  # Arrange
  local expected="## Usage"

  # Act
  run kb_test_run help </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"${expected}"* ]]
  called "format --theme pink"
}

@test "--theme picks the palette over the environment" {
  # Arrange
  local theme="nord"

  # Act
  KODOUGU_THEME=dracula KIBAN_THEME=gruvbox run kb_test_run --theme "${theme}" version </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  called "--background #88C0D0"
}

@test "--theme= with a value picks the palette" {
  # Arrange
  local option="--theme=tokyo-night"

  # Act
  run kb_test_run "${option}" version </dev/null

  # Assert
  [[ "${status}" -eq 0 ]]
  called "--background #7AA2F7"
}

@test "an unknown theme stops before anything runs" {
  # Arrange
  local theme="solarized"

  # Act
  KODOUGU_THEME="${theme}" run kb_test_run status </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"got: solarized"* ]]
}

@test "--theme without a value stops with the usage hint" {
  # Arrange
  local option="--theme"

  # Act
  run kb_test_run version "${option}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"option '--theme' needs a value. run 'kiban help' for usage."* ]]
}

@test "--theme after -- is left to the command line" {
  # Arrange
  local option="--theme"

  # Act
  run kb_test_run status -- "${option}" </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"--theme"* ]]
}
