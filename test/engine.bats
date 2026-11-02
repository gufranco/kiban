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

@test "start on Apple Silicon asks for a native aarch64 VM with Rosetta" {
  # Arrange
  local expected="colima start --profile default --cpus 4 --memory 8 --disk 64 --runtime docker --arch aarch64 --vm-type vz --mount-type virtiofs --mount ${HOME}:w --network-address --activate --vz-rosetta"

  # Act
  run kb_test_run start

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == "${expected}" ]]
  [[ "${output}" == *"VM:     default, 4 CPUs, 8 GiB memory, 64 GiB disk"* ]]
  [[ "${output}" == *"        aarch64 on vz, Rosetta for x86_64 images"* ]]
  [[ "${output}" == *"Started. Docker is ready in the default VM." ]]
}

@test "start on an Intel Mac asks for an x86_64 VM without Rosetta" {
  # Arrange
  kb_test_host 8 16 512 0

  # Act
  run kb_test_run start work

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"--profile work"*"--arch x86_64"* ]]
  [[ "$(<"${WORK}/calls")" != *"--vz-rosetta"* ]]
}

@test "start passes inotify and every DNS server when asked" {
  # Arrange
  local expected="--mount-inotify --dns 1.1.1.1 --dns 9.9.9.9"

  # Act
  run kb_test_run --mount-inotify --dns 1.1.1.1,9.9.9.9 start

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"${expected}" ]]
}

@test "start links the compose plugin once, leaving a real file alone" {
  # Arrange
  kb_test_write docker-compose 'exit 0'

  # Act
  run kb_test_run start

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -L "${HOME}/.docker/cli-plugins/docker-compose" ]]
  run kb_test_run start
  [[ "${status}" -eq 0 ]]
}

@test "start prints no summary for JSON" {
  # Arrange
  local expected="VM:"

  # Act
  run kb_test_run --json start

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" != *"${expected}"* ]]
}

@test "a VM that will not start is reported" {
  # Arrange
  export FAKE_FAIL=colima:start

  # Act
  run kb_test_run start

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"kiban: colima could not start the VM." ]]
}

@test "start stops when colima is missing" {
  # Arrange
  local farm
  farm="$(kb_test_farm colima)"

  # Act
  run kb_test_run_path "${farm}" start

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "kiban: stopped: colima is not installed. run 'kiban doctor'." ]]
}

@test "start stops when docker is missing" {
  # Arrange
  local farm
  farm="$(kb_test_farm docker)"

  # Act
  run kb_test_run_path "${farm}" start

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "kiban: stopped: docker is not installed. run 'kiban doctor'." ]]
}

@test "start on Linux starts the engine with no VM" {
  # Arrange
  export KIBAN_OS=Linux

  # Act
  run kb_test_run start

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"systemctl start docker"* ]]
  [[ "$(<"${WORK}/calls")" != *"colima"* ]]
  [[ "${output}" == "Started. Docker is running on this machine, with no VM." ]]
}

@test "start on Linux says so when Docker already runs" {
  # Arrange
  export KIBAN_OS=Linux
  touch "${WORK}/docker-up"

  # Act
  run kb_test_run start

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "Docker is already running." ]]
}

@test "start on Linux reports an engine that will not start" {
  # Arrange
  export KIBAN_OS=Linux FAKE_FAIL=systemctl:start

  # Act
  run kb_test_run start

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"kiban: systemctl could not start docker." ]]
}

@test "start on Linux stops when systemctl is missing" {
  # Arrange
  export KIBAN_OS=Linux
  local farm
  farm="$(kb_test_farm systemctl)"

  # Act
  run kb_test_run_path "${farm}" start

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "kiban: stopped: systemctl is not installed. run 'kiban doctor'." ]]
}

@test "stop stops the VM on a Mac and the engine on Linux" {
  # Arrange
  local expected="Stopped."

  # Act
  run kb_test_run stop
  KIBAN_OS=Linux run kb_test_run stop

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "${expected}" ]]
  [[ "$(<"${WORK}/calls")" == *"colima stop --profile default"*"systemctl stop docker.socket docker"* ]]
}

@test "stop reports a failure on each system" {
  # Arrange
  export FAKE_FAIL="colima:stop systemctl:stop"

  # Act
  run kb_test_run stop
  local darwin="${status}"
  KIBAN_OS=Linux run kb_test_run stop

  # Assert
  [[ "${darwin}" -eq 1 ]]
  [[ "${status}" -eq 1 ]]
}

@test "stop needs colima on a Mac and systemctl on Linux" {
  # Arrange
  local farm
  farm="$(kb_test_farm colima systemctl)"

  # Act
  run kb_test_run_path "${farm}" stop
  local darwin="${output}"
  KIBAN_OS=Linux run kb_test_run_path "${farm}" stop

  # Assert
  [[ "${darwin}" == "kiban: stopped: colima is not installed. run 'kiban doctor'." ]]
  [[ "${output}" == "kiban: stopped: systemctl is not installed. run 'kiban doctor'." ]]
}

@test "prune empties the profile after the typed confirmation" {
  # Arrange
  printf 'a1\nb2\n' >"${WORK}/ids"

  # Act
  run kb_test_answering 'default\n' prune

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"stop a1 b2"*"system prune -af --volumes --filter label!=keep"*"builder prune -af"* ]]
  [[ "${output}" == *"Pruned. Containers, images, volumes and build cache are gone." ]]
}

@test "prune of a named profile uses that VM's context" {
  # Arrange
  local expected="docker --context colima-work system prune"

  # Act
  run kb_test_answering 'work\n' prune work

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"${expected}"* ]]
}

@test "prune changes nothing on a wrong answer or without a terminal" {
  # Arrange
  local expected="kiban: stopped: nothing was changed."

  # Act
  run kb_test_answering 'nope\n' prune
  local wrong="${output}"
  run kb_test_run prune </dev/null

  # Assert
  [[ "${wrong}" == *"${expected}" ]]
  [[ "${output}" == "kiban: stopped: no terminal to confirm on, so nothing was changed." ]]
  [[ "$(<"${WORK}/calls")" != *"prune"* ]]
}

@test "prune reports a container that will not stop, and a failed prune" {
  # Arrange
  printf 'a1\n' >"${WORK}/ids"
  export FAKE_FAIL=docker:stop

  # Act
  run kb_test_answering 'default\n' prune
  local stopping="${status}"
  rm -f "${WORK}/ids"
  FAKE_FAIL=docker:system run kb_test_answering 'default\n' prune

  # Assert
  [[ "${stopping}" -eq 1 ]]
  [[ "${status}" -eq 1 ]]
}

@test "purge deletes the VM and its orphan disks on a Mac" {
  # Arrange
  mkdir -p "${HOME}/.colima/_lima/_disks/colima" "${HOME}/.colima/_lima/_disks/colima-old" "${HOME}/.colima/_lima/_disks/colima-live"
  printf 'PROFILE STATUS\nlive Running\n' >"${WORK}/colima-list"

  # Act
  run kb_test_answering 'default\n' purge

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"colima stop --profile default --force"*"colima delete --profile default --force"*"colima prune --all --force"* ]]
  [[ ! -e "${HOME}/.colima/_lima/_disks/colima-old" ]]
  [[ ! -e "${HOME}/.colima/_lima/_disks/colima" ]]
  [[ -d "${HOME}/.colima/_lima/_disks/colima-live" ]]
  [[ "${output}" == *"Purged. Nothing Docker held in default is left." ]]
}

@test "purge leaves orphan disks when colima cannot list its VMs" {
  # Arrange
  mkdir -p "${HOME}/.colima/_lima/_disks/colima-old"
  export FAKE_FAIL=colima:list

  # Act
  run kb_test_answering 'default\n' purge

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -d "${HOME}/.colima/_lima/_disks/colima-old" ]]
  [[ "${output}" == *"kiban: warning: colima list failed, so orphan disks are left in place."* ]]
}

@test "purge reports a VM that will not delete, or a failed prune" {
  # Arrange
  export FAKE_FAIL=colima:delete

  # Act
  run kb_test_answering 'default\n' purge
  local deleting="${status}"
  FAKE_FAIL=colima:prune run kb_test_answering 'default\n' purge
  local pruning="${status}"
  FAKE_FAIL=docker:system run kb_test_answering 'default\n' purge

  # Assert
  [[ "${deleting}" -eq 1 ]]
  [[ "${pruning}" -eq 1 ]]
  [[ "${status}" -eq 1 ]]
}

@test "purge on Linux prunes the engine and touches no VM" {
  # Arrange
  export KIBAN_OS=Linux

  # Act
  run kb_test_answering 'default\n' purge

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"docker --context default system prune"* ]]
  [[ "$(<"${WORK}/calls")" != *"colima"* ]]
}

@test "prune and purge need docker" {
  # Arrange
  local farm
  farm="$(kb_test_farm docker)"

  # Act
  run kb_test_run_path "${farm}" prune
  local pruning="${status}"
  run kb_test_run_path "${farm}" purge

  # Assert
  [[ "${pruning}" -eq 1 ]]
  [[ "${status}" -eq 1 ]]
}
