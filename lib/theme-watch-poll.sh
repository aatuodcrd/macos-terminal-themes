#!/bin/zsh
# Polling fallback watcher for machines without the Swift toolchain.
# Checks the macOS appearance every 2s and re-themes all Terminal windows when
# it changes. install.sh uses this only if `swiftc` is unavailable.

emulate -L zsh
TT_DIR="${TERM_TINT_DIR:-$HOME/.config/terminal-theme}"
APPLY="$TT_DIR/apply-theme.sh"

current_mode() {
  if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -qi dark; then print dark; else print light; fi
}

last=""
"$APPLY" all 2>/dev/null   # sync once at launch
while :; do
  cur="$(current_mode)"
  if [[ "$cur" != "$last" ]]; then
    "$APPLY" all 2>/dev/null
    last="$cur"
  fi
  sleep 2
done
