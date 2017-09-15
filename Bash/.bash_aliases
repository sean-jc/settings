# Refresh bash terminal
alias rf='source ~/.bashrc'

# -----------------------------------------------------------------------------
# Git
# -----------------------------------------------------------------------------
function git-show() {
    if [ $# -eq 0 ]
    then
        git log --format=%B -n 1 $(git rev-parse --verify HEAD)
        echo
        git diff --name-only -r $(git rev-parse --verify HEAD)
    else
        git log --format=%B -n 1 $1
        echo
        git diff --name-only $1^ $1
    fi
}

function git-diff() {
    if [ $# -eq 0 ]
    then
        git diff $(git rev-parse --verify HEAD^) $(git rev-parse --verify HEAD)
    else
        git diff $1^ $1
    fi
}

function git-tree() {
    if [ $# -eq 0 ]
    then
        git diff-tree --no-commit-id --name-only -r $(git rev-parse --verify HEAD)
    else
        git diff-tree --no-commit-id --name-only -r $1
    fi
}

function git-blob() {
    git rev-list --all |
    while read commit; do
        if git ls-tree -r $commit | grep -q $1; then
            echo $commit
        fi
    done
}

function git-apply() {
    git reset --hard $(printf "origin/$(git rev-parse --abbrev-ref HEAD)")
    git am --whitespace=fix ~/Patches/*.patch
}

function git-url-patch() {
    # lynx -dump -nonumbers -hiddenlinks=liston $1 | grep -e "^http.*00(0[1-9]|1[0-7])\.patch" | xargs -n 1 curl -s | git am
    lynx -dump -nonumbers -hiddenlinks=liston $1 | grep -e "^http.*003[0-9].*\.patch" | xargs -n 1 curl -s | git am
}

. $SETTINGS/git/.git-completion.bash

# Add git completion to aliases
__git_complete g __git_main
__git_complete gb _git_branch

__git_complete gc _git_commit
__git_complete gd _git_diff
__git_complete ge _git_send_email
__git_complete gf _git_fetch
__git_complete gg _git_checkout
__git_complete gk _git_format_patch
__git_complete gl _git_log
__git_complete glo _git_log
__git_complete gp _git_cherry_pick
__git_complete gr _git_reset
__git_complete gs _git_log

alias g='git'
alias ga='git-apply'
alias gb='git branch'
alias gc='git commit'
alias gd='git-diff'
alias ge='git send-email'
alias gf='git fetch'
alias gg='git checkout'
alias gk='git format-patch -o ~/patches/'
alias gl='git log'
alias glo='git log --pretty=oneline'
alias gm="git status | grep modified | tr -d '\t' | tr -d ' ' | cut -f 2 -d :"
alias gp='git cherry-pick'
alias gr='git reset'
alias grh='git reset HEAD'
alias grhh='git reset HEAD --hard'
alias grc='git rebase --continue'
alias gri='git rebase --interactive'
alias gs='git status'
alias gsa='git stash apply'
alias gsl='git stash list'
alias gsp='git stash pop'
alias gss='git stash save'
alias gt='git-tree'
alias gu='git-url-patch'
alias gv='git remote -vv'


# Run gofmt on all .go files from the HEAD commit
function git-gofmt() {
    git diff-tree --no-commit-id --name-only -r $(git rev-parse --verify HEAD) | grep \\\.go | xargs --no-run-if-empty gofmt -s -w
}
alias gof=git-gofmt

# Run go lint on all .go files from the HEAD commit
function git-golint() {
    git diff-tree --no-commit-id --name-only -r $(git rev-parse --verify HEAD) | grep \\\.go | xargs -L 1 --no-run-if-empty golint
}
alias gol=git-golint

# -----------------------------------------------------------------------------
# Virtual Machines
# -----------------------------------------------------------------------------
alias virtd='daemon=false virt'
alias vm='virt stable kvm'
alias vmd='daemon=false virt stable kvm'
alias vmm='v2_cgroup=memory vm'
alias vms='sgx=92M virt sgx kvm'
alias vepc='v2_cgroup=sgx_epc vms'
alias hyv='virt stable hyv'
alias vuefi='virt stable uefi'
# alias vuefi='qemu=stable img=uefi display=vnc iso=~/images/ubuntu/ubuntu-16.04.3-desktop-amd64.iso virtualmachine'
alias vanilla='virtio=false virt stable'

alias hv='os=hyper-v virt stable machine'
alias hvd='os=hyper-v display=vnc virt stable machine'
alias hvi='os=hyper-v display=vnc iso1=~/images/hyper-v/virtio-win-0.1.126.iso virt stable machine'
alias hvnew='os=hyper-v display=vnc iso=~images/hyper-v/hyper-v-2016.iso iso1=~/images/hyper-v/virtio-win-0.1.126.iso virt stable'

# -----------------------------------------------------------------------------
# SGX
# -----------------------------------------------------------------------------
alias lsd='lsdt'
alias epc='~/go/src/epct/epct.sh'
alias epd='EPCT_DEBUG=1 epc'
alias ep2='EPCT_CGROUP_V2=1 epc'
alias epd2='EPCT_CGROUP_V2=1 epd'
alias mx='make_sgxsdk'
alias dx='DEBUG=1 make_sgxsdk'

# -----------------------------------------------------------------------------
# App Shortcuts
# -----------------------------------------------------------------------------
alias sub='/opt/sublime_text/sublime_text'
alias pts='~/.bin/pts/phoronix-test-suite'
alias time='/usr/bin/time'
alias ftime='time -f "REAL:\t\t%e\nSYSTEM\t\t%S\nUSER\t\t%U\nCPU:\t\t%P\nMAX_RSS:\t%M\nCTX_INV:\t%c\nCTX_VOL:\t%w\nIO_IN:\t\t%I\nIO_OUT:\t\t%O\nMAJ_PF:\t\t%F\nMIN_PF:\t\t%R\nSWAPS:\t\t%W"'

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------
alias sk='sudo -sE'

# Open the manual page for the last command you executed.
function lman {
    set -- $(fc -nl -1);
    while [ $# -gt 0 -a '(' "sudo" = "$1" -o "-" = "${1:0:1}" ')' ]; do
        shift;
    done;
    cmd="$(basename "$1")";
    man "$cmd" || help "$cmd";
}

alias term='gnome-terminal &'

# apt and dpkg
alias apt='sudo apt'
alias apt-get='sudo apt-get'
alias ard='apt-cache rdepends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --installed --recurse'

# zpool
alias zp='sudo zpool'

#
function dpkg-query-size {
    dpkg-query -Wf '${Installed-Size}\t${Package}\n'
}
alias dq='dpkg-query-size'
alias dqs='dq | sort -n'
alias dg='dq | grep'

function dpkg-purge {
    dpkg --list | grep "^rc" | cut -d " " -f 3 | xargs sudo dpkg --purge
}

# systemd
alias sys='sudo systemctl'
alias failed='sys list-units --state=failed'
alias services='sys list-unit-files --type=service'

# List all UDP/TCP ports
alias ports='netstat -tulanp'

# Find my systems in the lab...
alias christ='sudo nmap -sP 10.54.77.* | grep -e sjchrist -e "for 10"'
alias lchrist='sudo nmap -sP 10.54.74.* | grep -e sjchrist -e "for 10"'

# ls
alias ls='ls -aF --color=always'
alias ll='ls -l'

# clear
alias c='clear'
alias cls='c;ls'
alias cll='c;ll'

# dmesg
alias dm='dmesg'
alias dmc='sudo dmesg -c'

# disk usage
alias dus='df -hT'

# ZFS
alias zfs='sudo zfs'
alias zpool='sudo zpool'
alias zp='zpool'

# grep
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# find
alias rfind='sudo find / -name 2> /dev/null'

# ps
alias ps='ps -a --forest -o user,pid,ppid,%cpu,%mem,vsz,rss,cmd'
alias psm='ps -e | sort -nr -k 5 | head -10 | cut -c-$COLUMNS'
alias psc='ps -e | sort -nr -k 4 | head -10 | cut -c-$COLUMNS'
alias psg='ps -e | grep -v grep | grep -v -- --forest | expand | cut -c-$COLUMNS | grep -i -e VSZ -e'

function kill-aesmd {
    sudo kill -9 $(ps -e | grep -v grep | grep aesmd | tr -s " " | cut -d " " -f 2)
}
alias ak=kill-aesmd

# Show which commands are being used the most
alias bu='cut -f1 -d" " ~/.bash_history | sort | uniq -c | sort -nr | head -n 30'

# Shortcuts for moving up directories
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

# Typos
alias cd..="cd .."

# Direct navigation to go directories
alias so='cd -P ~/go/src'
alias gh='cd -P ~/go/src/github.com'
alias int='cd -P ~/go/src/intel.com'

# Direct navigation to kernel and image directories
alias kn='cd -P ~/build/kernel'
alias qq='cd -P ~/build/qemu'
alias iq='cd -P ~/images/qemu'
alias iv='cd -P ~/images/hyper-v'

alias mkdir='mkdir -p'
function mcd() {
    mkdir $1
    cd $1
}

function extract() {
    if [ -z "$1" ]; then
        # display usage if no parameters given
        echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
    else
        if [ -f $1 ] ; then
            FILE=$(readlink -f "$1")

            NAME=${1%.*}
            NAME=${NAME%.tar}
            mkdir $NAME && cd $NAME

            case $1 in
              *.tar.bz2)   tar xjf $FILE     ;;
              *.tar.gz)    tar xzf $FILE     ;;
              *.tar.xz)    tar xJf $FILE     ;;
              *.lzma)      unlzma $FILE      ;;
              *.bz2)       bunzip2 $FILE     ;;
              *.rar)       unrar x -ad $FILE ;;
              *.gz)        gunzip $FILE      ;;
              *.tar)       tar xf $FILE      ;;
              *.tbz2)      tar xjf $FILE     ;;
              *.tgz)       tar xzf $FILE     ;;
              *.zip)       unzip $FILE       ;;
              *.Z)         uncompress $FILE  ;;
              *.7z)        7z x $FILE        ;;
              *.xz)        unxz $FILE        ;;
              *.exe)       cabextract $FILE  ;;
              *)           echo "extract: '$1' - unknown archive method" ;;
            esac
        else
            echo "$1 - file does not exist"
        fi
    fi
}

# MAke HOst kernel
function make-kernel-package() {
    if [[ $# -lt 1 ]]; then
        printf "Must specify the target kernel name\n"
        return 1
    fi
    if [[ $# -gt 2 ]]; then
        printf "Maximum of 2 arguments supported: kernel (1) and revision (2)\n"
        return 2
    fi
    THREADS=$(grep -c '^processor' /proc/cpuinfo)
    if [[ $# -eq 1 ]]; then
        CONCURRENCY_LEVEL=$THREADS fakeroot make-kpkg --initrd --append-to-version=-$1 kernel_headers kernel_image --revision 1
    else
        CONCURRENCY_LEVEL=$THREADS fakeroot make-kpkg --initrd --append-to-version=-$1 kernel_headers kernel_image --revision $2
    fi
}
alias maho='make-kernel-package'

# MAke GuEst kernel
function make-kernel() {
    if [[ $# -lt 1 ]]; then
        printf "Must specify the target kernel name\n"
        return 1
    fi
    if [[ $# -gt 2 ]]; then
        printf "Maximum of 2 arguments supported: kernel (1) and target (2)\n"
        return 2
    fi

    stubify-linux $1

    THREADS=$(grep -c '^processor' /proc/cpuinfo)
    if [[ $# -eq 1 ]]; then
        make O=~/build/kernel/$1 -j$THREADS
        if [[ $? -eq 0 ]]; then
            make O=~/build/kernel/$1 INSTALL_MOD_PATH=~/build/kernel/$1 modules_install
        fi
    else
        make O=~/build/kernel/$1 $2
    fi
}
alias mage='make-kernel'

# time kernel
function time-kernel() {
    if [[ $# -ne 1 ]]; then
        printf "Must specify the target kernel name\n"
        return 1
    fi
    make O=~/build/kernel/$1 clean
    sleep .25
    ftime -o ~/build/kernel/$1/tk_time.log make O=~/build/kernel/$1 > ~/build/kernel/$1/tk_build.log 2>&1
}
alias tk='time-kernel'

function system-info() {
    printf "Kernel:\t\t       $(uname -spr)\n"
    printf "Date:\t\t       $(date)\n"
    printf "Uptime:\t\t      $(uptime)\n"
    lscpu | grep -v Architecture | grep -v "Byte Order" | grep -v op-mode | grep -v BogoMIPS | grep -v Virtualization | grep -v Flags | grep -v On-line
}
alias si='system-info'

# -----------------------------------------------------------------------------
# LXD
# -----------------------------------------------------------------------------
alias slxd='sudo -E $GOPATH/bin/lxd --group sudo'

alias maked="DEBUG='-gcflags \"-N -l\"' make"

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------
alias dps='docker ps'
alias drm='dps -qa | xargs --no-run-if-empty docker rm'
alias di='docker images'
alias drmi='di --quiet --filter=dangling=true | xargs --no-run-if-empty docker rmi'
alias docker-gc='sudo docker-gc'

function docker-bash() {
    if [ $# -eq 0 ]
    then
        docker exec -it $(docker ps -ql) bash
    else
        docker exec -it $1 bash
    fi
}
alias dbash='docker-bash'

function docker-build() {
    docker build --build-arg https_proxy=$https_proxy --build-arg http_proxy=$http_proxy --build-arg no_proxy=$no_proxy -t $1 $2
}
alias dbuild='docker-build'

function docker-dev() {
    docker run --privileged --rm -ti -v `pwd`:/go/src/github.com/docker/docker -e https_proxy=$https_proxy -e http_proxy=$http_proxy -e no_proxy=$no_proxy docker-dev:$(git rev-parse --abbrev-ref HEAD) /bin/bash
}
alias ddev='docker-dev'

function docker-make() {
    BINDDIR=. DOCKER_BUILD_ARGS="--build-arg https_proxy=$https_proxy --build-arg http_proxy=$http_proxy --build-arg no_proxy=$no_proxy" make "$@"
}
alias dmake='docker-make'
