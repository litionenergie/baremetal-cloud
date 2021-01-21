# color detection magic
use_color=false

# dircolors --print-database uses its own built-in database
# instead of using /etc/DIR_COLORS.  Try to use the external file
# first to take advantage of user additions.  Use internal bash
# globbing instead of external grep binary.
safe_term=${TERM//[^[:alnum:]]/?}   # sanitize TERM
match_lhs=""
[[ -f ~/.dir_colors   ]] && match_lhs="${match_lhs}$(<~/.dir_colors)"
[[ -f /etc/DIR_COLORS ]] && match_lhs="${match_lhs}$(</etc/DIR_COLORS)"
[[ -z ${match_lhs}    ]] \
	&& type dircolors >/dev/null \
	&& match_lhs=$(dircolors --print-database)
[[ $'\n'${match_lhs} == *$'\n'"TERM "${safe_term}* ]] && use_color=true

unset safe_term match_lhs

if ${use_color}; then
	if type -P dircolors >/dev/null ; then
		if [[ -f ~/.dir_colors ]] ; then
			eval $(dircolors -b ~/.dir_colors)
		elif [[ -f /etc/DIR_COLORS ]] ; then
			eval $(dircolors -b /etc/DIR_COLORS)
		fi
	fi


	if type -P gls >/dev/null; then
		alias ls="gls --color=auto"
	else
		alias ls="ls --color=auto"
	fi

	alias grep="grep --color=auto"
fi

# solarized color theme
# https://github.com/necolas/dotfiles/blob/master/bash/bash_prompt
BOLD=$(tput bold)
RESET=$(tput sgr0)
SOLAR_BLACK=$(tput setaf 0)
SOLAR_RED=$(tput setaf 1)
SOLAR_GREEN=$(tput setaf 2)
SOLAR_YELLOW=$(tput setaf 3)
SOLAR_BLUE=$(tput setaf 4)
SOLAR_MAGENTA=$(tput setaf 5)
SOLAR_CYAN=$(tput setaf 6)
SOLAR_WHITE=$(tput setaf 7)
