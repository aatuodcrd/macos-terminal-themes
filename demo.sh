#!/bin/zsh
# Opens every theme in its own window, tiled across the screen, each labelled
# with its name and showing an ANSI color card — so you can compare them all.
# Only OPENS windows; never closes any.

emulate -L zsh
TT_DIR="${TERM_TINT_DIR:-$HOME/.config/terminal-theme}"
source "$TT_DIR/profiles.conf" 2>/dev/null || { print -u2 "term-tint: run install.sh first"; exit 1; }
card="$TT_DIR/demo-card.sh"

themes=("${DARK_THEMES[@]}" "${LIGHT_THEMES[@]}")
n=${#themes[@]}
(( n > 0 )) || { print -u2 "term-tint: no themes in profiles.conf"; exit 1; }

# screen size (logical points)
size="$(osascript -e 'tell application "Finder" to get {item 3, item 4} of (bounds of window of desktop)' 2>/dev/null)"
W="${${size%%,*}// /}"
H="${${size##*,}// /}"
[[ "$W" == <-> && "$H" == <-> ]] || { W=1440; H=900; }

cols=5
(( cols > n )) && cols=$n
rows=$(( (n + cols - 1) / cols ))

# AppleScript list literal of the theme names
list=""
for t in "${themes[@]}"; do list+="\"$t\", "; done
list="${list%, }"

osascript <<APPLESCRIPT
set themeList to {$list}
set colCount to $cols
set rowCount to $rows
set scrW to $W
set scrH to $H
set topMargin to 28
set cellW to scrW div colCount
set cellH to (scrH - topMargin) div rowCount
set winIDs to {}
tell application "Terminal"
	activate
	repeat with i from 1 to count of themeList
		set tName to item i of themeList
		do script ("$card " & quote & tName & quote)
		copy (id of front window) to end of winIDs
		delay 0.12
	end repeat
	delay 1.6
	repeat with i from 1 to count of themeList
		set wid to item i of winIDs
		set tName to item i of themeList
		set cc to (i - 1) mod colCount
		set rr to (i - 1) div colCount
		set x0 to cc * cellW
		set y0 to topMargin + rr * cellH
		try
			set current settings of every tab of window id wid to settings set tName
			set custom title of window id wid to tName
			set bounds of window id wid to {x0, y0, x0 + cellW - 6, y0 + cellH - 6}
		end try
	end repeat
end tell
APPLESCRIPT
print "term-tint: opened $n demo windows."
