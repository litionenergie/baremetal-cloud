# bash completion

_bashcomp_debian() {
	bash=${BASH_VERSION%.*}; bmajor=${bash%.*}; bminor=${bash#*.}

	if [ -n "$PS1" ]; then
		if [ $bmajor -eq 2 -a $bminor '>' 04 ] || [ $bmajor -gt 2 ]; then
			if [ -r /etc/bash_completion ]; then
				. /etc/bash_completion
			fi
		fi
	fi

	unset bash bminor bmajor
}

if type -t _bashcomp_${_DISTNAME} &>/dev/null; then
	_bashcomp_${_DISTNAME}
fi

export COMP_WORDBREAKS=${COMP_WORDBREAKS/:/}
export FIGNORE=".o:~"
