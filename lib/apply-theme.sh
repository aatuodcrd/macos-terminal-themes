#!/bin/zsh
# Apply a RANDOM Terminal.app profile that matches the current macOS appearance.
#
# Usage:
#   apply-theme.sh window   # randomize only the front window's tab (used by new shells)
#   apply-theme.sh all      # randomize EVERY open window (used by the realtime watcher)
#
# Dark mode -> DARK_THEMES, Light mode -> LIGHT_THEMES.
# Randomness is done in zsh (seeded from /dev/urandom) and never repeats the
# immediately-previous pick, so consecutive new windows look distinct.

emulate -L zsh
set -u

TT_DIR="${TERM_TINT_DIR:-$HOME/.config/terminal-theme}"
CONF="${TT_DIR}/profiles.conf"
[[ -f "$CONF" ]] || { print -u2 "term-tint: missing $CONF"; exit 1; }
source "$CONF"

target="${1:-window}"   # window | all
force="${2:-}"          # optional: dark | light  (override appearance detection)

# Never auto-launch Terminal; do nothing if it isn't already running.
/bin/ps -A -o comm= 2>/dev/null | grep -q '/Terminal\.app/Contents/MacOS/Terminal$' || exit 0

# Pick pool by forced mode, else by current macOS appearance.
if [[ "$force" == "dark" || "$force" == "light" ]]; then
  appearance="$force"
elif defaults read -g AppleInterfaceStyle 2>/dev/null | grep -qi dark; then
  appearance="dark"
else
  appearance="light"
fi
if [[ "$appearance" == "dark" ]]; then pool=("${DARK_THEMES[@]}"); else pool=("${LIGHT_THEMES[@]}"); fi
(( ${#pool[@]} > 0 )) || { print -u2 "term-tint: empty theme pool"; exit 1; }

# Strong per-process seed so separate windows diverge.
RANDOM=$(( $(od -An -N2 -tu2 /dev/urandom) ))

STATE="${TT_DIR}/.last-${appearance}"

# pick -> sets $REPLY to a theme, avoiding the previous pick recorded in $STATE.
# Must be called in the current shell (not a subshell) so RANDOM advances.
pick() {
  local n=${#pool[@]} c last="" tries=0
  if (( n == 1 )); then REPLY="${pool[1]}"; return; fi
  [[ -f "$STATE" ]] && last="$(<"$STATE")"
  while :; do
    c="${pool[$(( (RANDOM % n) + 1 ))]}"
    [[ "$c" != "$last" ]] && break
    (( ++tries > 12 )) && break
  done
  REPLY="$c"
  print -r -- "$REPLY" >| "$STATE"
}

apply_to_front() {
  /usr/bin/osascript - "$1" <<'EOF'
on run argv
  set p to item 1 of argv
  tell application "Terminal"
    try
      set current settings of selected tab of front window to settings set p
    end try
  end tell
end run
EOF
}

apply_to_window_id() {
  /usr/bin/osascript - "$1" "$2" <<'EOF'
on run argv
  set wid to (item 1 of argv) as integer
  set p to item 2 of argv
  tell application "Terminal"
    try
      set current settings of every tab of window id wid to settings set p
    end try
  end tell
end run
EOF
}

set_new_window_default() {
  /usr/bin/osascript - "$1" <<'EOF'
on run argv
  set p to item 1 of argv
  tell application "Terminal"
    try
      set default settings to settings set p
      set startup settings to settings set p
    end try
  end tell
end run
EOF
}

if [[ "$target" == "all" ]]; then
  ids=$(/usr/bin/osascript -e 'tell application "Terminal" to get id of windows' 2>/dev/null)
  for id in ${(s:, :)ids}; do
    [[ "$id" == <-> ]] || continue
    pick
    apply_to_window_id "$id" "$REPLY"
  done
  pick
  set_new_window_default "$REPLY"
else
  pick
  apply_to_front "$REPLY"
fi
