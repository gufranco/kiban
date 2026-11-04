export PS1='$ '
export PATH="/Users/Shared/demo/bin:${SCREENS_REPO:?}/bin:${PATH}"
unset KODOUGU_THEME KIBAN_THEME KODOUGU_ACCENT NO_COLOR
unset KIBAN_PROFILE
export KIBAN_DATA_DIR="${HOME}/.kiban-screens"
cd /Users/Shared/demo || return 1
clear
