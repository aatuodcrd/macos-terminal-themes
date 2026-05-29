#!/bin/zsh
# Prints a small preview card for a theme: name + ANSI color swatches + sample text.
# Used by demo.sh to show every theme side by side.
name="$1"
clear
printf '\n  ===  %s  ===\n\n' "$name"
printf '  '; for i in 0 1 2 3 4 5 6 7; do printf '\033[4%dm   \033[0m' $i; done; printf '\n'
printf '  '; for i in 0 1 2 3 4 5 6 7; do printf '\033[10%dm   \033[0m' $i; done; printf '\n\n'
printf '  The quick brown fox 0123456789\n'
printf '  \033[1mbold\033[0m \033[3mitalic\033[0m \033[4munderline\033[0m \033[31mred\033[0m \033[32mgreen\033[0m \033[34mblue\033[0m\n'
