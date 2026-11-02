#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${KB_LIB:?}/state.sh"

kb_docker() {
  docker --context "${KB_CONTEXT}" "$@"
}

kb_require() {
  kb_cmd_exists "$1" && return 0
  kb_error "stopped: $1 is not installed. run 'kiban doctor'."
  return 1
}

kb_compose_plugin() {
  kb_cmd_exists docker-compose || return 0
  kb_cp_target="${HOME}/.docker/cli-plugins/docker-compose"
  [ -e "${kb_cp_target}" ] && return 0
  kb_cp_source="$(command -v docker-compose)"
  mkdir -p "${HOME}/.docker/cli-plugins" && ln -sfn "${kb_cp_source}" "${kb_cp_target}"
}

kb_vm_summary() {
  [ "${KIBAN_JSON:-n}" != y ] || return 0
  kb_vs_rosetta=""
  [ "${KB_S_ROSETTA}" = y ] && kb_vs_rosetta=", Rosetta for x86_64 images"
  printf '\n'
  kb_info "VM:     ${KB_S_PROFILE}, ${KB_S_CPUS} CPUs, ${KB_S_MEMORY} GiB memory, ${KB_S_DISK} GiB disk"
  kb_info "        ${KB_S_ARCH} on ${KB_S_VM_TYPE}${kb_vs_rosetta}"
  printf '\n'
}

kb_colima_args() {
  printf '%s\n' --profile "${KB_S_PROFILE}" --cpus "${KB_S_CPUS}" --memory "${KB_S_MEMORY}" \
    --disk "${KB_S_DISK}" --runtime docker --arch "${KB_S_ARCH}" --vm-type "${KB_S_VM_TYPE}" \
    --mount-type "${KB_S_MOUNT_TYPE}" --mount "${HOME}:w" --network-address --activate
  [ "${KB_S_ROSETTA}" = y ] && printf '%s\n' --vz-rosetta
  [ "${KB_S_MOUNT_INOTIFY}" = y ] && printf '%s\n' --mount-inotify
  for kb_ca_server in $(printf '%s' "${KB_S_DNS}" | tr ',' ' '); do
    printf '%s\n' --dns "${kb_ca_server}"
  done
  return 0
}

kb_start_darwin() {
  kb_require colima || return 1
  kb_load_vm_settings
  kb_vm_summary
  kb_compose_plugin
  kb_sd_args="$(kb_colima_args)"
  kb_run_lines "${kb_sd_args}" colima start || {
    kb_error "colima could not start the VM."
    return 1
  }
  kb_success "Started. Docker is ready in the ${KB_S_PROFILE} VM."
}

kb_start_linux() {
  if docker info >/dev/null 2>&1; then
    kb_success "Docker is already running."
    return 0
  fi
  kb_require systemctl || return 1
  sudo systemctl start docker || {
    kb_error "systemctl could not start docker."
    return 1
  }
  kb_compose_plugin
  kb_success "Started. Docker is running on this machine, with no VM."
}

kb_start() {
  kb_require docker || return 1
  case "${KB_OS}" in
  Darwin) kb_start_darwin ;;
  *) kb_start_linux ;;
  esac
}

kb_stop() {
  case "${KB_OS}" in
  Darwin)
    kb_require colima || return 1
    colima stop --profile "${KB_S_PROFILE}" || return 1
    ;;
  *)
    kb_require systemctl || return 1
    sudo systemctl stop docker.socket docker || return 1
    ;;
  esac
  kb_success "Stopped."
}

kb_prune_context() {
  kb_pc_ids="$(kb_docker ps -aq 2>/dev/null)" || kb_pc_ids=""
  if [ -n "${kb_pc_ids}" ]; then
    # shellcheck disable=SC2086
    kb_docker stop ${kb_pc_ids} >/dev/null || return 1
  fi
  kb_docker system prune -af --volumes --filter "label!=keep" || return 1
  kb_docker builder prune -af
}

kb_prune() {
  kb_require docker || return 1
  kb_confirm_typed "${KB_S_PROFILE}" "remove every container, image, volume and build cache" || return 1
  kb_prune_context || return 1
  kb_success "Pruned. Containers, images, volumes and build cache are gone."
}

kb_orphan_disks() {
  kb_od_list="$(colima list 2>/dev/null)" || {
    kb_warning "colima list failed, so orphan disks are left in place."
    return 0
  }
  kb_od_names="$(printf '%s\n' "${kb_od_list}" | awk 'NR > 1 { print $1 }')"
  for kb_od_dir in "${HOME}"/.colima/_lima/_disks/colima*; do
    [ -d "${kb_od_dir}" ] || continue
    kb_od_disk="${kb_od_dir##*/}"
    kb_od_profile="${kb_od_disk#colima-}"
    [ "${kb_od_disk}" = colima ] && kb_od_profile=default
    printf '%s\n' "${kb_od_names}" | grep -Fqx -- "${kb_od_profile}" && continue
    rm -rf "${kb_od_dir:?}" "${HOME:?}/.colima/_lima/${kb_od_disk:?}"
  done
  return 0
}

kb_purge() {
  kb_require docker || return 1
  kb_confirm_typed "${KB_S_PROFILE}" "delete everything Docker holds, and the VM itself" || return 1
  kb_prune_context || return 1
  if [ "${KB_OS}" = Darwin ]; then
    colima stop --profile "${KB_S_PROFILE}" --force || true
    colima delete --profile "${KB_S_PROFILE}" --force || return 1
    kb_orphan_disks
    colima prune --all --force || return 1
  fi
  kb_success "Purged. Nothing Docker held in ${KB_S_PROFILE} is left."
}
