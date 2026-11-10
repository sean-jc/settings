export SETTINGS=$HOME/go/src/github.com/sean-jc/settings

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Fix minor typos on 'cd' and 'dir'
shopt -s cdspell
shopt -s dirspell

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# append to the history file, don't overwrite it
shopt -s histappend

HISTFILE=$HOME/.bash_history
# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=5000
HISTFILESIZE=10000

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

history -r

# Bind Cmd+Home escape sequence to jump to the beginning of the file/command buffer
if [[ $- == *i* ]]; then
	bind '"\e[1;8H": beginning-of-history'
	bind '"\e[1;8F": end-of-history'
fi

# tab complete/expand env variables, e.g. $SETTINGS
# shopt -s direxpand

. $SETTINGS/shell/main

# black ='\e[0;30m'
# brown ='\e[0;33m'
# green='\e[0;32m'
# GREEN='\e[0;32m'
# red='\e[0;31m'
# RED='\e[1;31m'
# blue='\e[0;34m'
# BLUE='\e[1;34m'
# cyan='\e[0;36m'
# CYAN='\e[1;36m'
# white='\e[1;37m'
# none='\e[0m'

# Unicode cheracters ✔ 'HEAVY CHECK MARK' (U+2714) and ✘ 'HEAVY BALLOT X' (U+2718)
# [[ $SSH_TTY ]] && host="@$HOSTNAME"
if [ "$UID" = 0 ]; then
	PS1='\[\e[0;33m\]\t$HOSTDISPLAY`if [ $? = 0 ]; then echo "\[\e[32m\] ✔ "; else echo "\[\e[31m\] ✘ "; fi`\[\e[1;31m\]\w \[\e[0;31m\]# \[\e[0m\]'
else
	PS1='\[\e[0;33m\]\t$HOSTDISPLAY`if [ $? = 0 ]; then echo "\[\e[32m\] ✔ "; else echo "\[\e[31m\] ✘ "; fi`\[\e[1;36m\]\w \[\e[0;36m\]\$ \[\e[0m\]'
fi

. $SETTINGS/bash/.bash_aliases

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
	debian_chroot=$(cat /etc/debian_chroot)
fi

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
	test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
	if [ -f /usr/share/bash-completion/bash_completion ]; then
	. /usr/share/bash-completion/bash_completion
	elif [ -f /etc/bash_completion ]; then
	. /etc/bash_completion
	fi

	# Enable tab complete of executables for sudo
	complete -cf sudo
fi

