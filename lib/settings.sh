#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${KB_LIB:?}/state.sh"

kb_env() {
  case "$1" in
  PROFILE) KB_ENV="${KIBAN_PROFILE:-}" ;;
  CPUS) KB_ENV="${KIBAN_CPUS:-}" ;;
  MEMORY) KB_ENV="${KIBAN_MEMORY:-}" ;;
  DISK) KB_ENV="${KIBAN_DISK:-}" ;;
  VM_TYPE) KB_ENV="${KIBAN_VM_TYPE:-}" ;;
  ARCH) KB_ENV="${KIBAN_ARCH:-}" ;;
  ROSETTA) KB_ENV="${KIBAN_ROSETTA:-}" ;;
  MOUNT_TYPE) KB_ENV="${KIBAN_MOUNT_TYPE:-}" ;;
  MOUNT_INOTIFY) KB_ENV="${KIBAN_MOUNT_INOTIFY:-}" ;;
  DNS) KB_ENV="${KIBAN_DNS:-}" ;;
  DATA_DIR) KB_ENV="${KIBAN_DATA_DIR:-}" ;;
  MONGO_IMAGE) KB_ENV="${KIBAN_MONGO_IMAGE:-}" ;;
  MONGO_PORT) KB_ENV="${KIBAN_MONGO_PORT:-}" ;;
  MONGO_USER) KB_ENV="${KIBAN_MONGO_USER:-}" ;;
  MONGO_PASSWORD) KB_ENV="${KIBAN_MONGO_PASSWORD:-}" ;;
  POSTGRES_IMAGE) KB_ENV="${KIBAN_POSTGRES_IMAGE:-}" ;;
  POSTGRES_PORT) KB_ENV="${KIBAN_POSTGRES_PORT:-}" ;;
  POSTGRES_USER) KB_ENV="${KIBAN_POSTGRES_USER:-}" ;;
  POSTGRES_PASSWORD) KB_ENV="${KIBAN_POSTGRES_PASSWORD:-}" ;;
  POSTGRES_SHM) KB_ENV="${KIBAN_POSTGRES_SHM:-}" ;;
  REDIS_IMAGE) KB_ENV="${KIBAN_REDIS_IMAGE:-}" ;;
  REDIS_PORT) KB_ENV="${KIBAN_REDIS_PORT:-}" ;;
  REDIS_MAXMEMORY) KB_ENV="${KIBAN_REDIS_MAXMEMORY:-}" ;;
  VALKEY_IMAGE) KB_ENV="${KIBAN_VALKEY_IMAGE:-}" ;;
  VALKEY_PORT) KB_ENV="${KIBAN_VALKEY_PORT:-}" ;;
  VALKEY_MAXMEMORY) KB_ENV="${KIBAN_VALKEY_MAXMEMORY:-}" ;;
  REDICT_IMAGE) KB_ENV="${KIBAN_REDICT_IMAGE:-}" ;;
  REDICT_PORT) KB_ENV="${KIBAN_REDICT_PORT:-}" ;;
  REDICT_MAXMEMORY) KB_ENV="${KIBAN_REDICT_MAXMEMORY:-}" ;;
  *) KB_ENV="${KIBAN_UBUNTU_IMAGE:-}" ;;
  esac
}

kb_host_darwin() {
  KB_HOST_CPUS="$(sysctl -n hw.ncpu 2>/dev/null)" || KB_HOST_CPUS=""
  kb_hd_bytes="$(sysctl -n hw.memsize 2>/dev/null)" || kb_hd_bytes=0
  kb_hd_arm="$(sysctl -n hw.optional.arm64 2>/dev/null)" || kb_hd_arm=0
  kb_is_uint "${kb_hd_bytes}" || kb_hd_bytes=0
  KB_HOST_MEMORY=$((kb_hd_bytes / 1073741824))
  KB_HOST_ARCH=x86_64
  [ "${kb_hd_arm}" = 1 ] && KB_HOST_ARCH=aarch64
  return 0
}

kb_host_linux() {
  KB_HOST_CPUS="$(nproc 2>/dev/null)" || KB_HOST_CPUS=""
  kb_hx_kib="$(awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo 2>/dev/null)" || kb_hx_kib=0
  kb_is_uint "${kb_hx_kib}" || kb_hx_kib=0
  KB_HOST_MEMORY=$((kb_hx_kib / 1048576))
  kb_hx_machine="$(uname -m)"
  case "${kb_hx_machine}" in
  aarch64 | arm64) KB_HOST_ARCH=aarch64 ;;
  *) KB_HOST_ARCH=x86_64 ;;
  esac
}

kb_host_load() {
  [ -n "${KB_HOST_ARCH}" ] && return 0
  if [ "${KB_OS}" = Darwin ]; then
    kb_host_darwin
  else
    kb_host_linux
  fi
  kb_is_uint "${KB_HOST_CPUS}" || KB_HOST_CPUS=2
  kb_hl_df="$(df -Pk "${HOME}" 2>/dev/null)" || kb_hl_df=""
  kb_hl_kib="$(printf '%s\n' "${kb_hl_df}" | awk 'NR == 2 { print $2 }')"
  kb_is_uint "${kb_hl_kib}" || kb_hl_kib=0
  KB_HOST_DISK=$(((kb_hl_kib / 1048576 + 255) / 256 * 256))
}

kb_clamp() {
  if [ "$1" -gt "$3" ]; then
    KB_CLAMPED="$3"
  elif [ "$1" -ge "$2" ]; then
    KB_CLAMPED="$1"
  elif [ "$4" -ge "$2" ]; then
    KB_CLAMPED="$2"
  else
    KB_CLAMPED="$4"
  fi
}

kb_power_of_two() {
  KB_POWER=1
  while [ "${KB_POWER}" -lt "$1" ]; do
    KB_POWER=$((KB_POWER * 2))
  done
}

kb_default_sized() {
  case "$1" in
  CPUS)
    kb_ds_half=$((KB_HOST_CPUS * 50 / 100))
    [ "${kb_ds_half}" -ge 2 ] && [ $((kb_ds_half % 2)) -ne 0 ] && kb_ds_half=$((kb_ds_half + 1))
    kb_clamp "${kb_ds_half}" 2 4 "${KB_HOST_CPUS}"
    ;;
  MEMORY)
    kb_power_of_two $((KB_HOST_MEMORY * 50 / 100))
    kb_clamp "${KB_POWER}" 2 8 "${KB_HOST_MEMORY}"
    ;;
  *)
    kb_power_of_two $((KB_HOST_DISK * 25 / 100))
    kb_clamp "${KB_POWER}" 8 64 "${KB_HOST_DISK}"
    ;;
  esac
  KB_DEFAULT="${KB_CLAMPED}"
}

kb_default() {
  case "$1" in
  CPUS | MEMORY | DISK)
    kb_host_load
    kb_default_sized "$1"
    return 0
    ;;
  ARCH | ROSETTA) kb_host_load ;;
  *) ;;
  esac
  case "$1" in
  PROFILE) KB_DEFAULT=default ;;
  VM_TYPE) KB_DEFAULT=vz ;;
  ARCH) KB_DEFAULT="${KB_HOST_ARCH}" ;;
  ROSETTA) KB_DEFAULT=n && [ "${KB_HOST_ARCH}" = aarch64 ] && KB_DEFAULT=y ;;
  MOUNT_TYPE) KB_DEFAULT=virtiofs ;;
  MOUNT_INOTIFY) KB_DEFAULT=n ;;
  DNS) KB_DEFAULT="" ;;
  DATA_DIR) KB_DEFAULT="${HOME}/Docker" ;;
  MONGO_IMAGE) KB_DEFAULT=mongo:8 ;;
  MONGO_PORT) KB_DEFAULT=27017 ;;
  MONGO_USER | MONGO_PASSWORD) KB_DEFAULT=mongo ;;
  POSTGRES_IMAGE) KB_DEFAULT=postgres:18-alpine ;;
  POSTGRES_PORT) KB_DEFAULT=5432 ;;
  POSTGRES_USER | POSTGRES_PASSWORD) KB_DEFAULT=postgres ;;
  POSTGRES_SHM) KB_DEFAULT=1g ;;
  REDIS_IMAGE) KB_DEFAULT=redis:8-alpine ;;
  REDIS_PORT) KB_DEFAULT=6379 ;;
  VALKEY_IMAGE) KB_DEFAULT=valkey/valkey:8-alpine ;;
  VALKEY_PORT) KB_DEFAULT=7000 ;;
  REDICT_IMAGE) KB_DEFAULT=registry.redict.io/redict:7-alpine ;;
  REDICT_PORT) KB_DEFAULT=6380 ;;
  REDIS_MAXMEMORY | VALKEY_MAXMEMORY | REDICT_MAXMEMORY) KB_DEFAULT=256mb ;;
  *) KB_DEFAULT=ubuntu:26.04 ;;
  esac
  return 0
}

kb_resolve() {
  case " ${KB_OPTIONS_SET} " in
  *" $1 "*) KB_FROM=option ;;
  *) KB_FROM=environment ;;
  esac
  kb_env "$1"
  KB_VALUE="${KB_ENV}"
  [ -n "${KB_VALUE}" ] && return 0
  kb_default "$1"
  KB_VALUE="${KB_DEFAULT}"
  KB_FROM=default
}

kb_load_service_settings() {
  for kb_ls_name in ${KB_SERVICE_NAMES}; do
    kb_resolve "${kb_ls_name}"
    kb_assign "${kb_ls_name}" "${KB_VALUE}"
  done
  kb_resolve PROFILE
  KB_S_PROFILE="${KB_VALUE}"
  KB_CONTEXT=default
  [ "${KB_OS}" = Darwin ] && KB_CONTEXT=colima
  [ "${KB_OS}" = Darwin ] && [ "${KB_S_PROFILE}" != default ] && KB_CONTEXT="colima-${KB_S_PROFILE}"
  return 0
}

kb_load_vm_settings() {
  for kb_lv_name in ${KB_VM_NAMES}; do
    kb_resolve "${kb_lv_name}"
    kb_assign "${kb_lv_name}" "${KB_VALUE}"
  done
}

kb_assign() {
  case "$1" in
  PROFILE) KB_S_PROFILE="$2" ;;
  CPUS) KB_S_CPUS="$2" ;;
  MEMORY) KB_S_MEMORY="$2" ;;
  DISK) KB_S_DISK="$2" ;;
  VM_TYPE) KB_S_VM_TYPE="$2" ;;
  ARCH) KB_S_ARCH="$2" ;;
  ROSETTA) KB_S_ROSETTA="$2" ;;
  MOUNT_TYPE) KB_S_MOUNT_TYPE="$2" ;;
  MOUNT_INOTIFY) KB_S_MOUNT_INOTIFY="$2" ;;
  DNS) KB_S_DNS="$2" ;;
  DATA_DIR) KB_S_DATA_DIR="$2" ;;
  MONGO_IMAGE) KB_S_MONGO_IMAGE="$2" ;;
  MONGO_PORT) KB_S_MONGO_PORT="$2" ;;
  MONGO_USER) KB_S_MONGO_USER="$2" ;;
  MONGO_PASSWORD) KB_S_MONGO_PASSWORD="$2" ;;
  POSTGRES_IMAGE) KB_S_POSTGRES_IMAGE="$2" ;;
  POSTGRES_PORT) KB_S_POSTGRES_PORT="$2" ;;
  POSTGRES_USER) KB_S_POSTGRES_USER="$2" ;;
  POSTGRES_PASSWORD) KB_S_POSTGRES_PASSWORD="$2" ;;
  POSTGRES_SHM) KB_S_POSTGRES_SHM="$2" ;;
  REDIS_IMAGE) KB_S_REDIS_IMAGE="$2" ;;
  REDIS_PORT) KB_S_REDIS_PORT="$2" ;;
  REDIS_MAXMEMORY) KB_S_REDIS_MAXMEMORY="$2" ;;
  VALKEY_IMAGE) KB_S_VALKEY_IMAGE="$2" ;;
  VALKEY_PORT) KB_S_VALKEY_PORT="$2" ;;
  VALKEY_MAXMEMORY) KB_S_VALKEY_MAXMEMORY="$2" ;;
  REDICT_IMAGE) KB_S_REDICT_IMAGE="$2" ;;
  REDICT_PORT) KB_S_REDICT_PORT="$2" ;;
  REDICT_MAXMEMORY) KB_S_REDICT_MAXMEMORY="$2" ;;
  *) KB_S_UBUNTU_IMAGE="$2" ;;
  esac
}

kb_config() {
  kb_cf_json=""
  kb_cf_names="${KB_SERVICE_NAMES}"
  [ "${KB_OS}" = Darwin ] && kb_cf_names="${KB_VM_NAMES} ${KB_SERVICE_NAMES}"
  kb_cf_rows=""
  kb_cf_drawn=no
  [ "${KIBAN_JSON:-n}" = y ] || ! kb_ui_out || kb_cf_drawn=yes
  [ "${KIBAN_JSON:-n}" = y ] || [ "${kb_cf_drawn}" = yes ] || printf '%-24s %-36s %s\n' setting value from
  for kb_cf_name in ${kb_cf_names}; do
    kb_resolve "${kb_cf_name}"
    if [ "${kb_cf_drawn}" = yes ]; then
      kb_cf_rows="${kb_cf_rows}KIBAN_${kb_cf_name}	${KB_VALUE:--}	@mut:${KB_FROM}
"
    elif [ "${KIBAN_JSON:-n}" = y ]; then
      kb_cf_quoted="$(kb_json_string "${KB_VALUE}")"
      kb_cf_json="${kb_cf_json}${kb_cf_json:+,}\"KIBAN_${kb_cf_name}\":{\"value\":${kb_cf_quoted},\"from\":\"${KB_FROM}\"}"
    else
      printf '%-24s %-36s %s\n' "KIBAN_${kb_cf_name}" "${KB_VALUE:--}" "${KB_FROM}"
    fi
  done
  [ "${KIBAN_JSON:-n}" = y ] && printf '{%s}\n' "${kb_cf_json}"
  [ "${kb_cf_drawn}" = no ] || printf 'Setting\tValue\tFrom\n%s' "${kb_cf_rows}" | kb_ui_table
  return 0
}

kb_run_lines() (
  kb_rl_list="$1"
  shift
  set -f
  kb_rl_newline="$(printf '\nx')"
  IFS="${kb_rl_newline%x}"
  # shellcheck disable=SC2086
  set -- "$@" ${kb_rl_list}
  "$@"
)
