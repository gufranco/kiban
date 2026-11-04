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

@test "up creates postgres with its port, shared memory, health check and data" {
  # Arrange
  local expected="run --detach --hostname postgres --name postgres --restart unless-stopped --log-driver local --log-opt max-size=10m --log-opt max-file=3 --mount type=bind,source=${HOME}/Docker/Postgres,target=/external --publish 127.0.0.1:5432:5432 --volume postgres-store:/var/lib/postgresql --env POSTGRES_USER=postgres --env POSTGRES_PASSWORD=postgres --shm-size 1g --health-cmd pg_isready -U postgres --health-interval 30s --health-timeout 10s --health-retries 3 postgres:18-alpine"

  # Act
  run kb_test_run up postgres

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"docker --context colima ${expected}"* ]]
  [[ -d "${HOME}/Docker/Postgres" ]]
  [[ "${output}" == "postgres is running on 127.0.0.1:5432." ]]
}

@test "up creates mongo with its credentials and both volumes" {
  # Arrange
  local expected="--volume mongo-data:/data/db --volume mongo-config:/data/configdb --env MONGO_INITDB_ROOT_USERNAME=mongo --env MONGO_INITDB_ROOT_PASSWORD=mongo"

  # Act
  run kb_test_run up mongo

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"${expected}"* ]]
}

@test "up gives redis, valkey and redict their own ports and memory limit" {
  # Arrange
  local expected="maxmemory 256mb"

  # Act
  run kb_test_run up redis valkey redict

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"--publish 127.0.0.1:6379:6379"*"redis-server --appendonly yes --${expected}"* ]]
  [[ "$(<"${WORK}/calls")" == *"--publish 127.0.0.1:7000:6379"*"valkey-server"* ]]
  [[ "$(<"${WORK}/calls")" == *"--publish 127.0.0.1:6380:6379"*"redict-server"* ]]
}

@test "up keeps the ubuntu container running and publishes nothing" {
  # Arrange
  local expected="ubuntu:26.04 sleep infinity"

  # Act
  run kb_test_run up ubuntu

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"${expected}"* ]]
  [[ "$(<"${WORK}/calls")" != *"--publish"* ]]
  [[ "${output}" == "ubuntu is running." ]]
}

@test "up honours a port and an image from the environment" {
  # Arrange
  local expected="--publish 127.0.0.1:5433:5432"

  # Act
  KIBAN_POSTGRES_PORT=5433 KIBAN_POSTGRES_IMAGE=postgres:17 run kb_test_run up postgres

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"${expected}"*"postgres:17"* ]]
}

@test "up starts a stopped container instead of creating it" {
  # Arrange
  kb_test_state redis exited

  # Act
  run kb_test_run up redis

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"docker --context colima start redis"* ]]
  [[ "$(<"${WORK}/calls")" != *" run "* ]]
}

@test "up leaves a running container alone" {
  # Arrange
  kb_test_state redis running

  # Act
  run kb_test_run up redis

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" != *"start redis"* ]]
  [[ "${output}" == "redis is running on 127.0.0.1:6379." ]]
}

@test "up names a service kiban does not know and keeps going" {
  # Arrange
  local expected="kiban: unknown service 'mysql'. kiban knows mongo postgres redis valkey redict ubuntu."

  # Act
  run kb_test_run up mysql redis

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"${expected}"* ]]
  [[ "${output}" == *"redis is running on 127.0.0.1:6379." ]]
}

@test "up reports a container that will not be created or started" {
  # Arrange
  export FAKE_FAIL=docker:run

  # Act
  run kb_test_run up redis
  local creating="${status}"
  kb_test_state valkey exited
  FAKE_FAIL=docker:start run kb_test_run up valkey

  # Assert
  [[ "${creating}" -eq 1 ]]
  [[ "${status}" -eq 1 ]]
}

@test "up reports a data folder it cannot create" {
  # Arrange
  printf 'file' >"${WORK}/blocker"

  # Act
  KIBAN_DATA_DIR="${WORK}/blocker" run kb_test_run up redis

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"kiban: could not create ${WORK}/blocker/Redis." ]]
}

@test "up on macOS refuses a data folder the Docker VM cannot see" {
  # Arrange
  local outside="${WORK}/outside"

  # Act
  KIBAN_DATA_DIR="${outside}" run kb_test_run up redis

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"kiban: ${outside}/Redis is outside ${HOME}, the only folder the Docker VM sees."* ]]
}

@test "up on Linux takes a data folder anywhere" {
  # Arrange
  export KIBAN_OS=Linux

  # Act
  KIBAN_DATA_DIR="${WORK}/anywhere" run kb_test_run up redis

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ -d "${WORK}/anywhere/Redis" ]]
}

@test "up with no service stops with the usage hint" {
  # Arrange
  local expected="kiban: no service given. run 'kiban help' for usage."

  # Act
  run kb_test_run up

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "down stops the named containers" {
  # Arrange
  kb_test_state redis running
  kb_test_state postgres running

  # Act
  run kb_test_run down redis postgres

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "Stopped redis postgres." ]]
}

@test "down with no names picks from the running containers by number" {
  # Arrange
  kb_test_state postgres running
  kb_test_state redis running

  # Act
  run kb_test_answering '1,2\n' down

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"  1) postgres"*"  2) redis"* ]]
  [[ "${output}" == *"Stopped postgres redis." ]]
}

@test "down reports a stop that fails" {
  # Arrange
  export FAKE_FAIL=docker:stop

  # Act
  run kb_test_run down redis

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "the picker uses fzf on a terminal" {
  # Arrange
  kb_test_state postgres running

  # Act
  run kb_test_call call_pick_on_terminal multi

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "postgres" ]]
  [[ "$(<"${WORK}/calls")" == *"fzf --multi --header"* ]]
}

@test "the picker asks fzf for one container when one is wanted" {
  # Arrange
  kb_test_state postgres running

  # Act
  run kb_test_call call_pick_on_terminal single

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" != *"--multi"* ]]
}

@test "the picker refuses a name it did not list" {
  # Arrange
  kb_test_state postgres running

  # Act
  run kb_test_answering 'mysql\n' shell

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"kiban: not a listed number or container: mysql" ]]
}

@test "the picker takes only one container for a shell" {
  # Arrange
  kb_test_state postgres running
  kb_test_state redis running

  # Act
  run kb_test_answering '1 2\n' logs

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"kiban: pick one container." ]]
}

@test "the picker refuses an empty answer" {
  # Arrange
  kb_test_state postgres running

  # Act
  run kb_test_answering '\n' shell

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"kiban: pick one container." ]]
}

@test "the picker stops when stdin ends" {
  # Arrange
  kb_test_state postgres running

  # Act
  run kb_test_answering '' shell

  # Assert
  [[ "${status}" -eq 1 ]]
}

@test "the picker says when no container runs" {
  # Arrange
  local expected="kiban: no container is running."

  # Act
  run kb_test_run shell

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}

@test "the picker needs a terminal" {
  # Arrange
  kb_test_state postgres running

  # Act
  run kb_test_run down </dev/null

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "kiban: no container given. run 'kiban help' for usage." ]]
}

@test "shell and logs go straight to a named container" {
  # Arrange
  local expected="docker --context colima logs -f --tail 200 postgres"

  # Act
  run kb_test_run shell postgres
  run kb_test_run logs postgres

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"exec -it postgres sh -c"*"${expected}"* ]]
}

@test "reset deletes the container, its volumes and its data after the typed name" {
  # Arrange
  kb_test_state mongo running
  mkdir -p "${HOME}/Docker/Mongo"

  # Act
  run kb_test_answering 'mongo\n' reset mongo

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"rm -f mongo"*"volume rm mongo-data"*"volume rm mongo-config"* ]]
  [[ ! -e "${HOME}/Docker/Mongo" ]]
  [[ "${output}" == *"Reset mongo. kiban up mongo starts it fresh." ]]
}

@test "reset changes nothing on a wrong answer" {
  # Arrange
  mkdir -p "${HOME}/Docker/Mongo"

  # Act
  run kb_test_answering 'nope\n' reset mongo

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ -d "${HOME}/Docker/Mongo" ]]
}

@test "reset takes exactly one known service" {
  # Arrange
  local expected="kiban: reset takes exactly one service. run 'kiban help' for usage."

  # Act
  run kb_test_run reset
  local none="${output}"
  run kb_test_run reset mysql

  # Assert
  [[ "${none}" == "${expected}" ]]
  [[ "${output}" == "kiban: unknown service 'mysql'. kiban knows mongo postgres redis valkey redict ubuntu." ]]
}

@test "status lists every service with its state and address" {
  # Arrange
  kb_test_state postgres running
  kb_test_state redis exited

  # Act
  run kb_test_run status

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${lines[0]}" == "service    state      address           image" ]]
  [[ "${output}" == *"postgres   running    127.0.0.1:5432    postgres:18-alpine"* ]]
  [[ "${output}" == *"redis      exited     127.0.0.1:6379    redis:8-alpine"* ]]
  [[ "${output}" == *"ubuntu     absent     -                 ubuntu:26.04"* ]]
}

@test "status prints JSON for scripts" {
  # Arrange
  kb_test_state postgres running

  # Act
  run kb_test_run --json status

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == '['*'{"service":"postgres","state":"running","address":"127.0.0.1:5432"}'*']' ]]
}

@test "status on Linux talks to the default context" {
  # Arrange
  export KIBAN_OS=Linux

  # Act
  run kb_test_run status

  # Assert
  [[ "${status}" -eq 0 ]]
  [[ "$(<"${WORK}/calls")" == *"docker --context default ps -a"* ]]
}

@test "every service command needs docker" {
  # Arrange
  local farm command expected="kiban: stopped: docker is not installed. run 'kiban doctor'."
  farm="$(kb_test_farm docker)"

  # Act
  for command in up down reset shell logs; do
    run kb_test_run_path "${farm}" "${command}" redis
    [[ "${status}" -eq 1 && "${output}" == "${expected}" ]]
  done
  run kb_test_run_path "${farm}" status

  # Assert
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == "${expected}" ]]
}
