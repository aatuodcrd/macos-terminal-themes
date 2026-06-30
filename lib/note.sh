#!/bin/zsh
# term-tint: per-window background note (watermark).
#
#   note "fixing auth bug"   # label THIS window/pane with a big faint watermark
#   note                     # clear it
#
# iTerm2: uses the native badge — real text on the background layer, behind your
# shell text, per-pane, set with one escape. This is the good path.
#
# Apple Terminal: has no live background-image API and ignores DEC double-size, so
# a true behind-the-text layer is impossible. Falls back to a big dim banner pinned
# in a reserved top scroll region, redrawn each prompt. Big letters need `figlet`.
#
# State is a plain shell var, so it's per-tab/window. Only ever touches the screen
# on an interactive TTY; in a non-interactive shell it just records the text.

typeset -g _TT_NOTE=""
typeset -g _TT_NOTE_PNG=""
typeset -g _TT_ITERM=0
[[ "${TERM_PROGRAM:-}" == "iTerm.app" || "${LC_TERMINAL:-}" == "iTerm2" ]] && _TT_ITERM=1
: ${TERM_TINT_DIR:=$HOME/.config/terminal-theme}

# ---- iTerm2 background watermark --------------------------------------------
# Centered image via SetBackgroundImageFile when the note-bg renderer is built;
# otherwise a top-right badge. Both are real background layers, behind the text.
_tt_badge() { printf '\033]1337;SetBadgeFormat=%s\a' "$(print -rn -- "$1" | base64 | tr -d '\n')"; }
_tt_bgimage() { printf '\033]1337;SetBackgroundImageFile=%s\a' "$(print -rn -- "$1" | base64 | tr -d '\n')"; }

_tt_iterm_set() {                        # $1 = note text
  local gen="$TERM_TINT_DIR/note-bg" png="${TMPDIR:-/tmp}/tt-note-$$-$RANDOM.png"
  if [[ -x "$gen" ]] && "$gen" "$1" "$png" 2>/dev/null; then
    [[ -n "$_TT_NOTE_PNG" ]] && rm -f "$_TT_NOTE_PNG"
    _TT_NOTE_PNG="$png"
    _tt_bgimage "$png"                   # centered watermark on the background
  else
    _tt_badge "$1"                       # fallback: top-right badge
  fi
}
_tt_iterm_clear() {
  _tt_bgimage ""; _tt_badge ""
  [[ -n "$_TT_NOTE_PNG" ]] && rm -f "$_TT_NOTE_PNG"; _TT_NOTE_PNG=""
}

# ---- Apple Terminal pinned banner -------------------------------------------
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

_tt_note_draw() {                        # redraw the frozen banner (Apple Terminal, each precmd)
  (( _TT_ITERM )) && return             # iTerm2 badge persists itself — nothing to redraw
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
      [[ -t 1 ]] || return
      if (( _TT_ITERM )); then
        _tt_iterm_clear                             # remove bg image + badge
      else
        printf '\033[r' ; printf '\033]1;\007'      # release scroll region + clear tab title
      fi
      return ;;
    *)
      _TT_NOTE="$*"
      [[ -t 1 ]] || return                          # not a terminal: just record the text
      printf '\033]1;%s\007' "$_TT_NOTE"            # label the tab title (both terminals)
      if (( _TT_ITERM )); then
        _tt_iterm_set "$_TT_NOTE"                    # centered background watermark
        return
      fi
      [[ -o interactive ]] || return                # Apple Terminal banner: needs an interactive screen
      local h r c; read h r c <<<"$(_tt_note_geom)"
      (( h < 1 )) && return
      printf '\033[%d;%dr\033[H\033[2J' $((h+1)) "$r"   # reserve banner rows + clean slate
      _tt_note_draw
      printf '\033[%d;1H' $((h+1)) ;;                # park cursor below banner for the next prompt
  esac
}

# Apple Terminal only: redraw before every prompt so the banner survives a clear,
# a full-screen app, or a resize. No-op in iTerm2 and when no note is set.
autoload -Uz add-zsh-hook 2>/dev/null
if add-zsh-hook precmd _tt_note_draw 2>/dev/null; then :; else precmd_functions+=(_tt_note_draw); fi
