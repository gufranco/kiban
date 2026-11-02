#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${KB_LIB:?}/state.sh"

kb_service_check() {
  case " ${KB_SERVICES} " in
  *" $1 "*) return 0 ;;
  *) ;;
  esac
  kb_error "unknown service '$1'. kiban knows ${KB_SERVICES}."
  return 1
}

kb_service_volumes() {
  case "$1" in
  mongo) printf '%s\n' mongo-data:/data/db mongo-config:/data/configdb ;;
  postgres) printf '%s\n' postgres-store:/var/lib/postgresql ;;
  *) printf '%s\n' "$1-data:/data" ;;
  esac
}

kb_service_info() {
  case "$1" in
  mongo) KB_PORT="${KB_S_MONGO_PORT}" KB_IMAGE="${KB_S_MONGO_IMAGE}" KB_INNER=27017 ;;
  postgres) KB_PORT="${KB_S_POSTGRES_PORT}" KB_IMAGE="${KB_S_POSTGRES_IMAGE}" KB_INNER=5432 ;;
  redis) KB_PORT="${KB_S_REDIS_PORT}" KB_IMAGE="${KB_S_REDIS_IMAGE}" KB_INNER=6379 ;;
  valkey) KB_PORT="${KB_S_VALKEY_PORT}" KB_IMAGE="${KB_S_VALKEY_IMAGE}" KB_INNER=6379 ;;
  redict) KB_PORT="${KB_S_REDICT_PORT}" KB_IMAGE="${KB_S_REDICT_IMAGE}" KB_INNER=6379 ;;
  *) KB_PORT="" KB_IMAGE="${KB_S_UBUNTU_IMAGE}" KB_INNER="" ;;
  esac
}

kb_data_dir() {
  kb_dd_name="$(printf '%s\n' "$1" | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }')"
  printf '%s/%s\n' "${KB_S_DATA_DIR}" "${kb_dd_name}"
}

kb_health() {
  printf '%s\n' --health-cmd "$1" --health-interval 30s --health-timeout 10s --health-retries 3
}

kb_kv_args() {
  kb_health "$2 ping"
  printf '%s\n' "$4" "$1" --appendonly yes --maxmemory "$3" --maxmemory-policy allkeys-lru
}

kb_service_args() {
  case "$1" in
  mongo)
    printf '%s\n' --env "MONGO_INITDB_ROOT_USERNAME=${KB_S_MONGO_USER}" \
      --env "MONGO_INITDB_ROOT_PASSWORD=${KB_S_MONGO_PASSWORD}"
    kb_health "mongosh --eval 'db.adminCommand({ping: 1})' --quiet"
    printf '%s\n' "${KB_S_MONGO_IMAGE}"
    ;;
  postgres)
    printf '%s\n' --env "POSTGRES_USER=${KB_S_POSTGRES_USER}" \
      --env "POSTGRES_PASSWORD=${KB_S_POSTGRES_PASSWORD}" --shm-size "${KB_S_POSTGRES_SHM}"
    kb_health "pg_isready -U ${KB_S_POSTGRES_USER}"
    printf '%s\n' "${KB_S_POSTGRES_IMAGE}"
    ;;
  redis) kb_kv_args redis-server redis-cli "${KB_S_REDIS_MAXMEMORY}" "${KB_S_REDIS_IMAGE}" ;;
  valkey) kb_kv_args valkey-server valkey-cli "${KB_S_VALKEY_MAXMEMORY}" "${KB_S_VALKEY_IMAGE}" ;;
  redict) kb_kv_args redict-server redict-cli "${KB_S_REDICT_MAXMEMORY}" "${KB_S_REDICT_IMAGE}" ;;
  *) printf '%s\n' "${KB_S_UBUNTU_IMAGE}" sleep infinity ;;
  esac
}

kb_run_args() {
  printf '%s\n' run --detach --hostname "$1" --name "$1" --restart unless-stopped \
    --log-driver local --log-opt max-size=10m --log-opt max-file=3 \
    --mount "type=bind,source=$2,target=/external"
  kb_service_info "$1"
  [ -n "${KB_PORT}" ] && printf '%s\n' --publish "127.0.0.1:${KB_PORT}:${KB_INNER}"
  kb_ra_volumes="$(kb_service_volumes "$1")"
  for kb_ra_volume in ${kb_ra_volumes}; do
    printf '%s\n' --volume "${kb_ra_volume}"
  done
  kb_service_args "$1"
}

kb_service_create() {
  kb_sc_data="$(kb_data_dir "$1")"
  mkdir -p "${kb_sc_data}" || {
    kb_error "could not create ${kb_sc_data}."
    return 1
  }
  kb_sc_args="$(kb_run_args "$1" "${kb_sc_data}")"
  kb_run_lines "${kb_sc_args}" kb_docker >/dev/null
}

kb_container_state() {
  kb_docker container inspect -f '{{.State.Status}}' "$1" 2>/dev/null
}

kb_up_one() {
  kb_service_check "$1" || return 1
  kb_uo_state="$(kb_container_state "$1")" || kb_uo_state=""
  case "${kb_uo_state}" in
  running) ;;
  "") kb_service_create "$1" || return 1 ;;
  *) kb_docker start "$1" >/dev/null || return 1 ;;
  esac
  kb_service_info "$1"
  if [ -n "${KB_PORT}" ]; then
    kb_success "$1 is running on 127.0.0.1:${KB_PORT}."
  else
    kb_success "$1 is running."
  fi
}

kb_up() {
  kb_require docker || return 1
  if [ "$#" -eq 0 ]; then
    kb_hint "no service given"
    return 1
  fi
  kb_up_status=0
  for kb_up_name in "$@"; do
    kb_up_one "${kb_up_name}" || kb_up_status=1
  done
  return "${kb_up_status}"
}

kb_down() {
  kb_require docker || return 1
  if [ "$#" -eq 0 ]; then
    kb_dn_names="$(kb_pick multi "Stop which containers? Numbers or names: ")" || return 1
    # shellcheck disable=SC2086
    set -- ${kb_dn_names}
  fi
  kb_docker stop "$@" >/dev/null || return 1
  kb_success "Stopped $*."
}

kb_reset() {
  kb_require docker || return 1
  if [ "$#" -ne 1 ]; then
    kb_hint "reset takes exactly one service"
    return 1
  fi
  kb_service_check "$1" || return 1
  kb_rs_data="$(kb_data_dir "$1")"
  kb_confirm_typed "$1" "delete its container, its volumes and ${kb_rs_data}" || return 1
  kb_docker rm -f "$1" >/dev/null 2>&1 || true
  kb_rs_volumes="$(kb_service_volumes "$1")"
  for kb_rs_volume in ${kb_rs_volumes}; do
    kb_docker volume rm "${kb_rs_volume%%:*}" >/dev/null 2>&1 || true
  done
  rm -rf "${kb_rs_data:?}"
  kb_success "Reset $1. kiban up $1 starts it fresh."
}

kb_shell() {
  kb_require docker || return 1
  kb_sh_name="${1:-}"
  [ -n "${kb_sh_name}" ] || kb_sh_name="$(kb_pick single "Open a shell in which container? Number or name: ")" || return 1
  kb_docker exec -it "${kb_sh_name}" sh -c 'command -v bash >/dev/null 2>&1 && exec bash; exec sh'
}

kb_logs() {
  kb_require docker || return 1
  kb_lg_name="${1:-}"
  [ -n "${kb_lg_name}" ] || kb_lg_name="$(kb_pick single "Follow the log of which container? Number or name: ")" || return 1
  kb_docker logs -f --tail 200 "${kb_lg_name}"
}

kb_status() {
  kb_require docker || return 1
  kb_st_table="$(kb_docker ps -a --format '{{.Names}} {{.State}}' 2>/dev/null)" || kb_st_table=""
  kb_st_states="$(printf '%s\n' "${kb_st_table}" | awk -v names="${KB_SERVICES}" '
    { state[$1] = $2 }
    END {
      n = split(names, list, " ")
      for (i = 1; i <= n; i++) print (list[i] in state ? state[list[i]] : "absent")
    }')"
  kb_st_json=""
  [ "${KIBAN_JSON:-n}" = y ] || printf '%-10s %-10s %-17s %s\n' service state address image
  # shellcheck disable=SC2086
  set -- ${kb_st_states}
  for kb_st_name in ${KB_SERVICES}; do
    kb_service_info "${kb_st_name}"
    kb_st_address="-"
    [ -n "${KB_PORT}" ] && kb_st_address="127.0.0.1:${KB_PORT}"
    if [ "${KIBAN_JSON:-n}" = y ]; then
      kb_st_json="${kb_st_json}${kb_st_json:+,}{\"service\":\"${kb_st_name}\",\"state\":\"$1\",\"address\":\"${kb_st_address}\"}"
    else
      printf '%-10s %-10s %-17s %s\n' "${kb_st_name}" "$1" "${kb_st_address}" "${KB_IMAGE}"
    fi
    shift
  done
  [ "${KIBAN_JSON:-n}" = y ] && printf '[%s]\n' "${kb_st_json}"
  return 0
}

kb_pick() {
  kb_pk_names="$(kb_docker ps --format '{{.Names}}' 2>/dev/null)" || kb_pk_names=""
  if [ -z "${kb_pk_names}" ]; then
    kb_error "no container is running."
    return 1
  fi
  if ! kb_interactive; then
    kb_hint "no container given"
    return 1
  fi
  if kb_cmd_exists fzf && { [ "${KIBAN_TERMINAL:-}" = 1 ] || [ -t 2 ]; }; then
    if [ "$1" = multi ]; then
      printf '%s\n' "${kb_pk_names}" | fzf --multi --header "$2"
    else
      printf '%s\n' "${kb_pk_names}" | fzf --header "$2"
    fi
    return "$?"
  fi
  printf '%s\n' "${kb_pk_names}" | awk '{ printf "  %d) %s\n", NR, $0 }' >&2
  printf '%s' "$2" >&2
  kb_pk_answer=""
  IFS= read -r kb_pk_answer || [ -n "${kb_pk_answer}" ] || return 1
  kb_pick_match "${kb_pk_answer}" "${kb_pk_names}" "$1"
}

kb_pick_match() {
  kb_pm_found=""
  for kb_pm_word in $(printf '%s' "$1" | tr ',' ' '); do
    kb_pm_hit="$(printf '%s\n' "$2" | awk -v w="${kb_pm_word}" 'NR == w || $0 == w { print; exit }')"
    if [ -z "${kb_pm_hit}" ]; then
      kb_error "not a listed number or container: ${kb_pm_word}"
      return 1
    fi
    kb_pm_found="${kb_pm_found}${kb_pm_found:+ }${kb_pm_hit}"
  done
  if [ -z "${kb_pm_found}" ] || { [ "$3" = single ] && [ "${kb_pm_found}" != "${kb_pm_found%% *}" ]; }; then
    kb_error "pick one container."
    return 1
  fi
  printf '%s\n' "${kb_pm_found}"
}
