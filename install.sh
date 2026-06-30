#!/bin/bash
# term-tint installer for macOS Terminal.app
#
# Installs 10 dark + 10 light color themes and wires up:
#   * each new window gets a random theme matching the current macOS appearance
#   * all windows re-theme instantly when you switch macOS Light/Dark
#
# Safe by design: when importing themes it only closes windows it just opened,
# and never closes anything if the window snapshot looks wrong.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${TERM_TINT_DIR:-$HOME/.config/terminal-theme}"
THEMES_DIR="$SCRIPT_DIR/themes"
LABEL="com.term-tint.theme-sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
RC="$HOME/.zshrc"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$1"; }

# --- preflight ----------------------------------------------------------------
[ "$(uname)" = "Darwin" ] || { warn "term-tint only supports macOS."; exit 1; }
[ -d "$THEMES_DIR" ] || { warn "themes/ folder not found next to install.sh"; exit 1; }

say "Installing term-tint into $INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$HOME/Library/LaunchAgents"

# --- copy runtime files -------------------------------------------------------
cp "$SCRIPT_DIR/lib/apply-theme.sh"      "$INSTALL_DIR/apply-theme.sh"
cp "$SCRIPT_DIR/lib/note.sh"             "$INSTALL_DIR/note.sh"
cp "$SCRIPT_DIR/lib/demo-card.sh"        "$INSTALL_DIR/demo-card.sh"
cp "$SCRIPT_DIR/lib/theme-watch.swift"   "$INSTALL_DIR/theme-watch.swift"
cp "$SCRIPT_DIR/lib/theme-watch-poll.sh" "$INSTALL_DIR/theme-watch-poll.sh"
cp "$SCRIPT_DIR/demo.sh"                 "$INSTALL_DIR/demo.sh"
chmod +x "$INSTALL_DIR"/*.sh
# Only install the default pools the first time; keep the user's edits on re-run.
if [ -f "$INSTALL_DIR/profiles.conf" ]; then
  say "Keeping your existing profiles.conf"
else
  cp "$SCRIPT_DIR/lib/profiles.conf" "$INSTALL_DIR/profiles.conf"
fi

# --- import the .terminal themes (safe) --------------------------------------
ids() { osascript -e 'tell application "Terminal" to get id of windows' 2>/dev/null; }

say "Importing themes into Terminal (this briefly opens a few windows)…"
expected=0; for _ in "$THEMES_DIR"/*.terminal; do expected=$((expected+1)); done
before="$(ids)"
for f in "$THEMES_DIR"/*.terminal; do
  tname="$(basename "$f" .terminal)"
  # Replace any existing profile of the same name so re-installs don't duplicate.
  osascript -e "tell application \"Terminal\" to delete settings set \"$tname\"" 2>/dev/null
  open "$f"
  sleep 0.25
done
sleep 1.2
after="$(ids)"

# Compute window ids that appeared during import (these are safe to close —
# they did not exist in the 'before' snapshot).
norm() { printf '%s\n' "$1" | tr ',' '\n' | tr -d ' ' | grep '[0-9]' | sort -u; }
if [ -z "$before" ]; then
  warn "Could not read existing windows; leaving import windows open (close them yourself)."
else
  newids="$(comm -13 <(norm "$before") <(norm "$after"))"
  count="$(printf '%s\n' "$newids" | grep -c '[0-9]')"
  if [ "$count" -ge 1 ]; then
    for id in $newids; do
      osascript -e "tell application \"Terminal\" to close (every window whose id is $id) saving no" 2>/dev/null
    done
    say "Imported $expected themes, closed $count import window(s)."
  fi
fi

# --- iTerm2 (optional): themed profiles + watermark badge --------------------
if [ -d "/Applications/iTerm.app" ] && [ -f "$SCRIPT_DIR/iterm2/term-tint.json" ]; then
  IDP="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  mkdir -p "$IDP"
  cp "$SCRIPT_DIR/iterm2/term-tint.json" "$IDP/term-tint.json"
  say "iTerm2 found: installed 20 'term-tint <name>' profiles with the watermark badge."
  echo "      Pick one in iTerm2 → Profiles; 'note \"text\"' shows a real background badge."
fi

# --- realtime watcher ---------------------------------------------------------
if command -v swiftc >/dev/null 2>&1; then
  say "Compiling event-driven watcher (Swift) — ~0% CPU when idle."
  if swiftc -O "$INSTALL_DIR/theme-watch.swift" -o "$INSTALL_DIR/theme-watch" 2>/dev/null; then
    PROG_ARGS=("$INSTALL_DIR/theme-watch")
  else
    warn "Swift build failed; using the polling watcher instead."
    PROG_ARGS=(/bin/zsh "$INSTALL_DIR/theme-watch-poll.sh")
  fi
else
  warn "No Swift toolchain found; using the lightweight polling watcher (2s)."
  PROG_ARGS=(/bin/zsh "$INSTALL_DIR/theme-watch-poll.sh")
fi

# --- LaunchAgent --------------------------------------------------------------
say "Installing LaunchAgent so it runs at login."
{
  printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
  printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
  printf '%s\n' '<plist version="1.0">'
  printf '%s\n' '<dict>'
  printf '  <key>Label</key><string>%s</string>\n' "$LABEL"
  printf '%s\n' '  <key>ProgramArguments</key>'
  printf '%s\n' '  <array>'
  for a in "${PROG_ARGS[@]}"; do printf '    <string>%s</string>\n' "$a"; done
  printf '%s\n' '  </array>'
  printf '%s\n' '  <key>EnvironmentVariables</key>'
  printf '  <dict><key>TERM_TINT_DIR</key><string>%s</string></dict>\n' "$INSTALL_DIR"
  printf '%s\n' '  <key>RunAtLoad</key><true/>'
  printf '%s\n' '  <key>KeepAlive</key><true/>'
  printf '%s\n' '  <key>LimitLoadToSessionType</key><string>Aqua</string>'
  printf '  <key>StandardOutPath</key><string>%s/watch.log</string>\n' "$INSTALL_DIR"
  printf '  <key>StandardErrorPath</key><string>%s/watch.log</string>\n' "$INSTALL_DIR"
  printf '%s\n' '</dict>'
  printf '%s\n' '</plist>'
} > "$PLIST"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
if launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; then
  say "Watcher loaded."
else
  warn "Could not load the LaunchAgent automatically. Try: launchctl bootstrap gui/\$(id -u) \"$PLIST\""
fi

# --- shell hook (random theme per new window) ---------------------------------
say "Adding the per-window hook to $RC"
HOOK_START="# >>> term-tint >>>"
HOOK_END="# <<< term-tint <<<"
touch "$RC"
if grep -qF "$HOOK_START" "$RC"; then
  # remove the previous block (BSD sed)
  sed -i '' "/$HOOK_START/,/$HOOK_END/d" "$RC"
fi
cat >> "$RC" <<EOF
$HOOK_START
export TERM_TINT_DIR="$INSTALL_DIR"
# Give each new Terminal window a random theme matching the current appearance.
if [[ -o interactive && "\$TERM_PROGRAM" == "Apple_Terminal" ]]; then
  ( "\$TERM_TINT_DIR/apply-theme.sh" window >/dev/null 2>&1 & )
fi
# Manual control: tint dark | light | all | demo
tint() {
  case "\${1:-}" in
    dark)  "\$TERM_TINT_DIR/apply-theme.sh" window dark ;;
    light) "\$TERM_TINT_DIR/apply-theme.sh" window light ;;
    all)   "\$TERM_TINT_DIR/apply-theme.sh" all ;;
    demo)  "\$TERM_TINT_DIR/demo.sh" ;;
    *)     "\$TERM_TINT_DIR/apply-theme.sh" window ;;
  esac
}
# Per-window watermark note:  note "what I'm doing"  |  note   (to clear)
[ -n "\${ZSH_VERSION:-}" ] && source "\$TERM_TINT_DIR/note.sh"
$HOOK_END
EOF

say "Done! 🎨"
echo
echo "  • Open a NEW Terminal window  → it gets a random theme."
echo "  • Toggle macOS Light/Dark     → all windows switch instantly."
echo "  • Try:  tint demo   (opens all 20 side by side)"
echo "          tint dark | tint light | tint all"
echo "  • Note a window: note \"deploying prod\"   (clear with: note)"
command -v figlet >/dev/null 2>&1 || echo "          └─ big watermark letters need figlet:  brew install figlet"
echo "  • Edit your pool:  $INSTALL_DIR/profiles.conf"
echo
echo "  Run 'source ~/.zshrc' in this window, or just open a new one."

# --- show off all 20 themes (tiled to fit the screen) -------------------------
if [ -z "${TT_NO_DEMO:-}" ]; then
  echo
  say "Opening all 20 themes so you can see them (set TT_NO_DEMO=1 to skip)…"
  TERM_TINT_DIR="$INSTALL_DIR" "$INSTALL_DIR/demo.sh" 2>/dev/null || true
fi
