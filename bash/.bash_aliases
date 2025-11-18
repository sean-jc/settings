. $SETTINGS/bash/apt
. $SETTINGS/bash/backports
. $SETTINGS/bash/b4
. $SETTINGS/bash/catch
. $SETTINGS/bash/clangd
. $SETTINGS/bash/debug
. $SETTINGS/bash/dev-sync
. $SETTINGS/bash/devrez
. $SETTINGS/bash/dirs
. $SETTINGS/bash/docker
. $SETTINGS/bash/git
. $SETTINGS/bash/git-completion
. $SETTINGS/bash/gnome
. $SETTINGS/bash/go
. $SETTINGS/bash/kernel
. $SETTINGS/bash/kokonut
. $SETTINGS/bash/make-boot
. $SETTINGS/bash/make-gbuild
. $SETTINGS/bash/make-kernel
. $SETTINGS/bash/make-kut
. $SETTINGS/bash/make-selftests
. $SETTINGS/bash/modules
. $SETTINGS/bash/moo
. $SETTINGS/bash/qemu
. $SETTINGS/bash/system
. $SETTINGS/bash/testing
. $SETTINGS/bash/tracing
. $SETTINGS/bash/utils
. $SETTINGS/bash/vms

# Refresh bash terminal
alias rf='source ~/.bashrc'

alias bash_usage='cut -f1 -d" " ~/.bash_history | sort | uniq -c | sort -nr | head -n 30'

alias sk='sudo -sE'

alias gcm='gcert -s -m kernel-development --nossh_on_security_key && ssh-add $HOME/.ssh/id_local'
alias gcmc='gcert -s -m kernel-development,corevirt-team-testing --nossh_on_security_key && ssh-add $HOME/.ssh/id_local'

alias r=reup
alias k=kapwing
alias mf='make -j$(get-nr-cpus)'
alias mfc='make clean && make -j$(get-nr-cpus)'

function curl-time()
{
	curl -4 -w "@$SETTINGS/bin/curl-format.txt" -o /dev/null -s $@
}
alias curlt='curl-time'

# temporary workaround
alias vscode='code --enable-features=UseOzonePlatform --ozone-platform=wayland &'

function meld-si-ti() {
	meld sinux/$1 tinux/$1
}
function meld-ti-si() {
	meld tinux/$1 sinux/$1
}
alias mi='meld-ti-si'

# offlineimap
alias oi='offlineimap -f "INBOX"'
# alias ol='offlineimap -f "Lists/linus"'
# alias ok='offlineimap -f "Lists/kvm"'
# alias op='offlineimap -f "Lists/posted"'
# alias of='offlineimap -f "Lists/for_paolo"'
# alias oo='offlineimap -f "Lists/todo"'
# alias ou='offlineimap -f "Lists/x86"'
