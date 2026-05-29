#!/bin/bash
# Removes term-tint: stops the watcher, removes the shell hook and installed
# files. Optionally deletes the 20 color profiles it added to Terminal.

set -u

INSTALL_DIR="${TERM_TINT_DIR:-$HOME/.config/terminal-theme}"
LABEL="com.term-tint.theme-sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
RC="$HOME/.zshrc"

say() { printf '\033[1;36m==>\033[0m %s\n' "$1"; }

THEMES=(
  "Ink Black" "Steel Gray" "Deep Blue" "Slate Blue" "Indigo" "Violet" "Magenta" "Plum" "Amber" "Bronze"
  "Paper" "Silver" "Stone" "Sky Blue" "Periwinkle" "Lavender" "Orchid" "Cream" "Gold" "Apricot"
)

say "Stopping and removing the watcher LaunchAgent."
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$PLIST"

say "Removing the shell hook from $RC"
if [ -f "$RC" ] && grep -qF "# >>> term-tint >>>" "$RC"; then
  sed -i '' "/# >>> term-tint >>>/,/# <<< term-tint <<</d" "$RC"
fi

printf 'Also delete the 20 color profiles from Terminal? [y/N] '
read -r ans
if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
  for t in "${THEMES[@]}"; do
    osascript -e "tell application \"Terminal\" to delete settings set \"$t\"" 2>/dev/null
  done
  say "Deleted the term-tint color profiles."
else
  say "Kept the color profiles (you can remove them in Terminal ▸ Settings)."
fi

say "Removing installed files in $INSTALL_DIR"
rm -f "$INSTALL_DIR"/apply-theme.sh "$INSTALL_DIR"/demo-card.sh "$INSTALL_DIR"/demo.sh \
      "$INSTALL_DIR"/theme-watch.swift "$INSTALL_DIR"/theme-watch "$INSTALL_DIR"/theme-watch-poll.sh \
      "$INSTALL_DIR"/.last-dark "$INSTALL_DIR"/.last-light "$INSTALL_DIR"/watch.log
rmdir "$INSTALL_DIR" 2>/dev/null || say "Left $INSTALL_DIR (still has your profiles.conf or other files)."

say "term-tint removed. Open a new window for your shell to be hook-free."
