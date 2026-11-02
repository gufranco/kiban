#!/usr/bin/env bats
# shellcheck disable=SC2016

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup() {
  kb_test_setup
}

teardown() {
  kb_test_teardown
}

@test "help prints the usage page on stdout" {
  # Arrange
  local first="kiban - run Docker and local dev databases at full speed on macOS and Linux"

  # Act
  run kb_test_run help

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "${first}" ]]
}

@test "-h and --help print the same page as help" {
  # Arrange
  local page long
  page="$(kb_test_run help)"
  long="$(kb_test_run --help)"

  # Act
  run kb_test_run -h

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${page}" ]]
  [[ "${long}" == "${page}" ]]
}

@test "version names the program, its version and the platform" {
  # Arrange
  local version
  version="$(sed -n 's/^KIBAN_VERSION="\(.*\)"$/\1/p' "${REPO_DIR}/lib/core.sh")"

  # Act
  run kb_test_run --version

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "kiban ${version}" ]]
  [[ "${lines[1]}" == "platform: FakeOS 1.0" ]]
}

@test "version says unknown when uname cannot name the platform" {
  # Arrange
  kb_test_write uname 'exit 1'

  # Act
  run kb_test_run -V

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[1]}" == "platform: unknown" ]]
}

@test "no command and no terminal stops with the usage hint" {
  # Arrange
  local expected="kiban: no command given. run 'kiban help' for usage."

  # Act
  run kb_test_run </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "an unknown command stops with the usage hint" {
  # Arrange
  local expected="kiban: unknown command 'fly'. run 'kiban help' for usage."

  # Act
  run kb_test_run fly

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "an unknown option stops with the usage hint" {
  # Arrange
  local expected="kiban: unknown option '--nope'. run 'kiban help' for usage."

  # Act
  run kb_test_run --nope status

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "an unknown option given a value stops with the usage hint" {
  # Arrange
  local expected="kiban: unknown option '--nope'. run 'kiban help' for usage."

  # Act
  run kb_test_run --nope=1 status

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a single-dash option stops with the usage hint" {
  # Arrange
  local expected="kiban: unknown option '-x'. run 'kiban help' for usage."

  # Act
  run kb_test_run -x status

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a flag given a value stops with the usage hint" {
  # Arrange
  local expected="kiban: option '--json' takes no value. run 'kiban help' for usage."

  # Act
  run kb_test_run --json=y status

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "an option without its value stops with the usage hint" {
  # Arrange
  local expected="kiban: option '--cpus' needs a value. run 'kiban help' for usage."

  # Act
  run kb_test_run --cpus

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a size that is not a whole number is refused" {
  # Arrange
  local expected="kiban: --memory must be a whole number of 1 or more, got: lots"

  # Act
  run kb_test_run --memory lots config

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "an architecture kiban does not know is refused" {
  # Arrange
  local expected="kiban: --arch must be one of aarch64 x86_64, got: mips"

  # Act
  run kb_test_run --arch=mips config

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a yes or no setting with another value is refused" {
  # Arrange
  local expected="kiban: KIBAN_ROSETTA must be one of y n, got: maybe"

  # Act
  KIBAN_ROSETTA=maybe run kb_test_run config

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "an extra argument after status stops with the usage hint" {
  # Arrange
  local expected="kiban: unexpected extra argument 'now'. run 'kiban help' for usage."

  # Act
  run kb_test_run status now

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "a second profile name stops with the usage hint" {
  # Arrange
  local expected="kiban: unexpected extra argument 'two'. run 'kiban help' for usage."

  # Act
  run kb_test_run stop one two

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "-- lets an argument that looks like an option through" {
  # Arrange
  local expected="kiban: unknown command '--json'. run 'kiban help' for usage."

  # Act
  run kb_test_run -- --json

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "the menu runs the command picked by number" {
  # Arrange
  local first="What would you like to do?"

  # Act
  run kb_test_answering '5\n'

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "${first}" ]]
  [[ "${output}" == *"postgres   absent"* ]]
}

@test "the menu refuses a choice it does not list" {
  # Arrange
  local expected="kiban: not a listed choice: 9"

  # Act
  run kb_test_answering '9\n'

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"${expected}" ]]
}

@test "the menu stops when stdin ends" {
  # Arrange
  local expected="Choice: "

  # Act
  run kb_test_answering ''

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"${expected}" ]]
}

@test "the menu runs each other command" {
  # Arrange
  kb_test_state postgres running

  # Act
  run kb_test_answering '1\n'
  run kb_test_answering '2\n'
  run kb_test_answering '3\nredis\n'
  run kb_test_answering '4\n1\n'
  run kb_test_answering '6\n1\n'
  run kb_test_answering '7\n1\n'
  run kb_test_answering '8\n'

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"colima start"*"colima stop"*"docker --context colima run"*"docker --context colima stop postgres"*"exec -it redis"*"logs -f --tail 200 redis"* ]]
}

@test "the menu stops when the service answer never comes" {
  # Arrange
  local expected="Which service? mongo postgres redis valkey redict ubuntu: "

  # Act
  run kb_test_answering '3\n'

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"${expected}" ]]
}

@test "an inherited KB_ variable changes nothing" {
  # Arrange
  local expected="kiban: unknown option '--nope'. run 'kiban help' for usage."

  # Act
  KB_PROG=other KB_WIDTH=10 KIBAN_TERMINAL=1 run kb_test_run --nope

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

called_by_name() {
  local -a shell_words
  read -r -a shell_words <<<"${KIBAN_TEST_SHELL:-sh}"
  cd "${REPO_DIR}/bin" && PATH="${REPO_DIR}/bin:${PATH}" "${shell_words[@]}" kiban version
}

@test "the program runs when called by name from PATH" {
  # Arrange
  local expected="kiban "

  # Act
  run called_by_name

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "${expected}"* ]]
}
