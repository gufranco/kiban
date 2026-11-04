# shellcheck shell=bash
# shellcheck disable=SC2207

_kiban() {
  local cur prev words
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"
  if [[ "${COMP_WORDS[COMP_CWORD - 1]}" == "--theme" ]]; then
    COMPREPLY=($(compgen -W "kodougu catppuccin-mocha catppuccin-latte dracula nord gruvbox tokyo-night mono" -- "${COMP_WORDS[COMP_CWORD]}"))
    return
  fi

  case "${prev}" in
  --arch)
    COMPREPLY=($(compgen -W "aarch64 x86_64" -- "${cur}"))
    return
    ;;
  --vm-type)
    COMPREPLY=($(compgen -W "vz qemu krunkit" -- "${cur}"))
    return
    ;;
  --mount-type)
    COMPREPLY=($(compgen -W "virtiofs 9p sshfs" -- "${cur}"))
    return
    ;;
  --cpus | --memory | --disk | --dns)
    COMPREPLY=()
    return
    ;;
  --data-dir)
    COMPREPLY=($(compgen -d -- "${cur}"))
    return
    ;;
  *) ;;
  esac
  if [[ "${cur}" == -* ]]; then
    COMPREPLY=($(compgen -W "--cpus --memory --disk --arch --vm-type --rosetta --no-rosetta --mount-type --mount-inotify --no-mount-inotify --dns --data-dir --json --theme" -- "${cur}"))
    return
  fi
  words="mongo postgres redis valkey redict ubuntu"
  if [[ "${COMP_CWORD}" -eq 1 ]]; then
    words="start stop up down shell logs status reset prune purge config doctor version help"
  fi
  COMPREPLY=($(compgen -W "${words}" -- "${cur}"))
}

complete -F _kiban kiban
