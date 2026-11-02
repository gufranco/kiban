#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup() {
  kb_test_setup
}

teardown() {
  kb_test_teardown
}

@test "a large Apple Silicon Mac keeps today's caps" {
  # Arrange
  kb_test_host 14 36 1024 1

  # Act
  run kb_test_run config

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"KIBAN_CPUS               4 "* ]]
  [[ "${output}" == *"KIBAN_MEMORY             8 "* ]]
  [[ "${output}" == *"KIBAN_DISK               64 "* ]]
  [[ "${output}" == *"KIBAN_ARCH               aarch64 "* ]]
  [[ "${output}" == *"KIBAN_ROSETTA            y "* ]]
}

@test "a small Mac gets the floor of 2 CPUs and its own memory" {
  # Arrange
  kb_test_host 2 2 40 0

  # Act
  run kb_test_run config

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"KIBAN_CPUS               2 "* ]]
  [[ "${output}" == *"KIBAN_MEMORY             2 "* ]]
  [[ "${output}" == *"KIBAN_DISK               64 "* ]]
}

@test "a machine below the floors gets everything it has" {
  # Arrange
  kb_test_host 1 1 20 0

  # Act
  run kb_test_run config

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"KIBAN_CPUS               1 "* ]]
  [[ "${output}" == *"KIBAN_MEMORY             1 "* ]]
}

@test "an odd half of the cores rounds up to an even count" {
  # Arrange
  kb_test_host 6 16 512 1

  # Act
  run kb_test_run config

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"KIBAN_CPUS               4 "* ]]
}

@test "an Intel Mac gets an x86_64 VM without Rosetta" {
  # Arrange
  kb_test_host 8 16 512 0

  # Act
  run kb_test_run config

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"KIBAN_ARCH               x86_64 "* ]]
  [[ "${output}" == *"KIBAN_ROSETTA            n "* ]]
}

@test "a Mac whose sysctl answers nothing falls back to safe sizes" {
  # Arrange
  kb_test_write sysctl 'exit 1'
  kb_test_write df 'exit 1'

  # Act
  run kb_test_run config

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"KIBAN_CPUS               2 "* ]]
  [[ "${output}" == *"KIBAN_ARCH               x86_64 "* ]]
}

@test "an option wins over the environment, which wins over the default" {
  # Arrange
  local expected="option"

  # Act
  KIBAN_CPUS=2 KIBAN_POSTGRES_PORT=5433 run kb_test_run --cpus 3 config

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"KIBAN_CPUS               3                                    ${expected}"* ]]
  [[ "${output}" == *"KIBAN_POSTGRES_PORT      5433                                 environment"* ]]
  [[ "${output}" == *"KIBAN_REDIS_PORT         6379                                 default"* ]]
}

@test "every setting can come from its environment variable" {
  # Arrange
  local names name search_path
  search_path="$(kb_test_path)"
  names="PROFILE MEMORY DISK VM_TYPE ARCH ROSETTA MOUNT_TYPE MOUNT_INOTIFY DNS DATA_DIR MONGO_IMAGE MONGO_PORT MONGO_USER MONGO_PASSWORD POSTGRES_IMAGE POSTGRES_USER POSTGRES_PASSWORD POSTGRES_SHM REDIS_IMAGE REDIS_MAXMEMORY VALKEY_IMAGE VALKEY_PORT VALKEY_MAXMEMORY REDICT_IMAGE REDICT_PORT REDICT_MAXMEMORY UBUNTU_IMAGE"

  # Act
  run env KIBAN_PROFILE=p KIBAN_MEMORY=3 KIBAN_DISK=9 KIBAN_VM_TYPE=qemu KIBAN_ARCH=x86_64 KIBAN_ROSETTA=n \
    KIBAN_MOUNT_TYPE=9p KIBAN_MOUNT_INOTIFY=y KIBAN_DNS=1.1.1.1 KIBAN_DATA_DIR=/d KIBAN_MONGO_IMAGE=m \
    KIBAN_MONGO_PORT=1 KIBAN_MONGO_USER=u KIBAN_MONGO_PASSWORD=w KIBAN_POSTGRES_IMAGE=p KIBAN_POSTGRES_USER=u \
    KIBAN_POSTGRES_PASSWORD=w KIBAN_POSTGRES_SHM=2g KIBAN_REDIS_IMAGE=r KIBAN_REDIS_MAXMEMORY=1mb \
    KIBAN_VALKEY_IMAGE=v KIBAN_VALKEY_PORT=2 KIBAN_VALKEY_MAXMEMORY=1mb KIBAN_REDICT_IMAGE=t KIBAN_REDICT_PORT=3 \
    KIBAN_REDICT_MAXMEMORY=1mb KIBAN_UBUNTU_IMAGE=b PATH="${search_path}" sh "${REPO_DIR}/bin/kiban" config

  # Assert
  [[ "${status}" -eq 0 ]]
  for name in ${names}; do
    [[ "${output}" == *"KIBAN_${name} "*" environment"* ]]
  done
}

@test "options set every VM setting they name" {
  # Arrange
  local expected="option"

  # Act
  run kb_test_run --memory 3 --disk 9 --arch x86_64 --vm-type qemu --no-rosetta --mount-type sshfs \
    --mount-inotify --dns 9.9.9.9 --data-dir /data config

  # Assert
  [[ "${status}" -eq 0 ]]
  local count
  count="$(grep -c " ${expected}$" <<<"${output}")"
  [[ "${count}" -eq 9 ]]
}

@test "--rosetta and --no-mount-inotify are recorded as options" {
  # Arrange
  local expected="option"

  # Act
  run kb_test_run --rosetta --no-mount-inotify config

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"KIBAN_ROSETTA            y                                    ${expected}"* ]]
  [[ "${output}" == *"KIBAN_MOUNT_INOTIFY      n                                    ${expected}"* ]]
}

@test "config on Linux leaves the VM settings out" {
  # Arrange
  export KIBAN_OS=Linux

  # Act
  run kb_test_run config

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" != *"KIBAN_CPUS"* ]]
  [[ "${output}" == *"KIBAN_DATA_DIR"* ]]
}

@test "config prints every setting as one JSON object" {
  # Arrange
  local expected='"KIBAN_PROFILE":{"value":"default","from":"default"}'

  # Act
  run kb_test_run config --json

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "{"*"${expected}"*"}" ]]
}

@test "a Linux arm64 machine reports its own architecture" {
  # Arrange
  export KIBAN_OS=Linux
  kb_test_host 4 8 128 1

  # Act
  run kb_test_call call_setting ARCH

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "aarch64" ]]
}

@test "a Linux machine whose tools answer nothing falls back to safe sizes" {
  # Arrange
  export KIBAN_OS=Linux
  kb_test_write nproc 'exit 1'
  kb_test_write uname 'printf "x86_64\n"'

  # Act
  run kb_test_call call_setting CPUS

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "2" ]]
}
