#!/bin/zsh
# term-tint: per-window background note (watermark).
#
#   note "fixing auth bug"   # pin a big faint watermark at the top of THIS window
#   note                     # clear it
#
# Terminal.app can't paint text *behind* the cursor layer — it has no live
# background-image AppleScript property and ignores DEC double-size lines. So the
# closest real "watermark" is: reserve the top rows with a scroll region and
# redraw a big, dim banner there on every prompt. State is a plain shell var, so
# it's naturally per-tab/window. Big letters need `figlet` (brew install figlet);
# without it you still get a dim caps banner.
#
# Only ever touches the screen on an interactive TTY — sourced/called from a
# non-interactive shell it just records the text, so it can't corrupt scripts.
# ponytail: scroll-region banner, fragile across resize mid-command — `note`
# (bare) is the escape hatch and always resets the region cleanly.

typeset -g _TT_NOTE=""

_tt_note_lines() {                       # render $_TT_NOTE -> banner lines on stdout
  if command -v figlet >/dev/null 2>&1; then
    figlet -w "${COLUMNS:-80}" -- "$_TT_NOTE" 2>/dev/null
  else
    print -r -- "${(U)_TT_NOTE}"         # no figlet: uppercase single line
  fi
}

_tt_note_geom() {                        # -> "$h $rows $cols", robust against a 0/unknown size
  local r=${LINES:-0} c=${COLUMNS:-0}
  (( r > 0 )) || { r=$(tput lines 2>/dev/null) || r=24; }
  (( c > 0 )) || { c=$(tput cols  2>/dev/null) || c=80; }
  local -a lines; lines=("${(@f)$(_tt_note_lines)}")
  local h=$#lines maxh=$(( r / 3 ))
  (( maxh < 1 )) && maxh=1              # never collapse the banner to zero rows
  (( h > maxh )) && h=$maxh
  print -r -- "$h $r $c"
}

_tt_note_draw() {                        # redraw the frozen banner (called each precmd)
  [[ -n "$_TT_NOTE" && -o interactive && -t 1 ]] || return
  local h r c; read h r c <<<"$(_tt_note_geom)"
  (( h < 1 )) && return
  local -a lines; lines=("${(@f)$(_tt_note_lines)}")
  printf '\0337'                                    # save cursor + attrs (DECSC)
  printf '\033[%d;%dr' $((h+1)) "$r"               # scroll region below banner (also homes cursor)
  printf '\033[H'                                   # home, into the frozen top region
  local i
  for (( i = 1; i <= h; i++ )); do
    printf '\033[2K\033[2;90m%.*s\033[0m\r\n' "$c" "${lines[i]}"   # dim grey = faint watermark
  done
  printf '\0338'                                    # restore cursor (DECRC)
}

note() {
  case "${1:-}" in
    ""|off|clear|-c)
      _TT_NOTE=""
      [[ -t 1 ]] && printf '\033[r\033]1;\007'      # release scroll region + clear tab title (no screen wipe)
      return ;;
    *)
      _TT_NOTE="$*"
      [[ -t 1 ]] || return                          # not a terminal: just record the text
      printf '\033]1;%s\007' "$_TT_NOTE"            # label the tab
      [[ -o interactive ]] || return                # non-interactive: don't touch the screen
      local h r c; read h r c <<<"$(_tt_note_geom)"
      (( h < 1 )) && return
      printf '\033[%d;%dr\033[H\033[2J' $((h+1)) "$r"   # reserve banner rows + clean slate
      _tt_note_draw
      printf '\033[%d;1H' $((h+1)) ;;                # park cursor below banner for the next prompt
  esac
}

# Keep it pinned: redraw before every prompt (re-establishes the region + banner
# after a clear, a full-screen app, or a resize). Cheap no-op when no note is set.
autoload -Uz add-zsh-hook 2>/dev/null
if add-zsh-hook precmd _tt_note_draw 2>/dev/null; then :; else precmd_functions+=(_tt_note_draw); fi
