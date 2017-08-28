# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples
export HOSTPOST=${HOSTNAME#sjchrist-}
export SETTINGS=$HOME/go/src/github.com/sean-jc/settings

# Define GOPATH
export GOPATH=$HOME/go

# For development of GO itself
export GOROOT_BOOTSTRAP=/usr/local/go

# Add ~/bin, (repo)/bin, and GO bins to PATH
if [[ $PATH != *"sean-jc/settings"* ]]; then
    export PATH=$HOME/bin:$SETTINGS/bin:$HOME/go/bin:/usr/local/go/bin:$PATH
fi

# Require a revision when using make-kpkg to build .deb kernels
export DEBIAN_REVISION_MANDATORY=1

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Fix minor typos on 'cd' and 'dir'
shopt -s cdspell
shopt -s dirspell

alias vi='vim'
export EDITOR=vim

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

# if [ -n "$force_color_prompt" ]; then
#     if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
# 	# We have color support; assume it's compliant with Ecma-48
# 	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
# 	# a case would tend to support setf rather than setaf.)
# 	color_prompt=yes
#     else
# 	color_prompt=
#     fi
# fi

# if [ "$color_prompt" = yes ]; then
#     PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
# else
#     PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
# fi
# unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
# case "$TERM" in
# xterm*|rxvt*)
#     PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
#     ;;
# *)
#     ;;
# esac


build_ps1() {
    # green='\e[0;32m'
    # GREEN='\e[0;32m'
    # red='\e[0;31m'
    # RED='\e[1;31m'
    # blue='\e[0;34m'
    # BLUE='\e[1;34m'
    # cyan='\e[0;36m'
    # CYAN='\e[1;36m'
    # none='\e[0m'

    # Unicode cheracters ✔ 'HEAVY CHECK MARK' (U+2714) and ✘ 'HEAVY BALLOT X' (U+2718)
    # [[ $SSH_TTY ]] && host="@$HOSTNAME"
    if [ "$UID" = 0 ]; then
        if [ "$HOSTPOST" = coffee ]; then
            echo '\[\e[1;30m\]\t`if [ $? = 0 ]; then echo "\[\e[32m\] ✔ "; else echo "\[\e[31m\] ✘ "; fi`\[\e[1;31m\]\w \[\e[0;31m\]# \[\e[0m\]'
        else
            echo '\[\e[1;30m\]\t@$HOSTPOST`if [ $? = 0 ]; then echo "\[\e[32m\] ✔ "; else echo "\[\e[31m\] ✘ "; fi`\[\e[1;31m\]\w \[\e[0;31m\]# \[\e[0m\]'
        fi
    else
        if [ "$HOSTPOST" = coffee ]; then
            echo '\[\e[1;30m\]\t`if [ $? = 0 ]; then echo "\[\e[32m\] ✔ "; else echo "\[\e[31m\] ✘ "; fi`\[\e[1;36m\]\w \[\e[0;36m\]\$ \[\e[0m\]'
        else
            echo '\[\e[1;30m\]\t@$HOSTPOST`if [ $? = 0 ]; then echo "\[\e[32m\] ✔ "; else echo "\[\e[31m\] ✘ "; fi`\[\e[1;36m\]\w \[\e[0;36m\]\$ \[\e[0m\]'
        fi
    fi

}
PS1=$(build_ps1)


# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.
. $SETTINGS/Bash/.bash_aliases

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
