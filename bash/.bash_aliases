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
    if [ $# -eq 0 ]; then
        git am -3 ~/mutt/*.patch
    else
        git am -3 $1/*.patch
    fi
}

function git-cherry-pick-branch() {
    local commits
    local arbitrary=1000

    if [ $# -ne 2 ]; then
        printf "Usage for cherry picking a branch: 'gpb <last commit> <first commit>'\n"
        return 1
    fi

    glo $1 | head -$arbitrary | grep -q $2
    if [[ $? -ne 0 ]]; then
        printf "Did not find $2 in log from $1\n"
        return 1
    fi
    glo $1 | head -$arbitrary | grep -B $arbitrary $2
    printf "\e[1;7;35mCherry pick these commits?"
    read -r -p "[Y/n] " response
    printf "\e[0m"
    response=${response,,}    # tolower
    if [[ -z $response || $response =~ ^(yes|y)$ ]]; then
        commits=$(glo $1 | head -$arbitrary | grep -B $arbitrary $2 | tac | cut -f 1 -d ' ' | xargs)
        git cherry-pick $commits
        return $?
    fi
    return 1
}

function git-cherry-pick-ref() {
    git status | grep "currently cherry-picking commit" | grep -o -E "[0-9a-f]{12}\b"
}

function git-cherry-pick-log() {
    git log -1 $(git-cherry-pick-ref)
}

function git-cherry-pick-show() {
    git show $(git-cherry-pick-ref)
}

function git-push() {
    local opts
    local response=y
    local branch=$(git rev-parse --abbrev-ref HEAD)
    local remote
    local upstream
    if [[ $# -eq 1 && $1 != "force" ]]; then
        remote=$1
        upstream=$branch
    else
        remote=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} | cut -f 1 -d /)
        if [[ $? -eq 0 ]]; then
             upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} | cut -f 2- -d /)
        else
            printf "No remote configured or specified\n"
            return 1
        fi
    fi

    local exists=$(git ls-remote --heads $remote $upstream | wc -l)
    if [[ $exists == "0" ]]; then
        printf "\e[1;7;35mCreate and track remote branch $remote/$upstream? "
        read -r -p "[Y/n] " response
        printf "\e[0m"
    elif [[ $exists != "1" ]]; then
        printf "Found multiple ($exists) branches: $upstream\n"
        return 1
    elif [[ $1 == "force" ]]; then
        opts="-f"
        git status
        printf "\e[1;7;35mForce push $branch to $remote/$upstream? "
        read -r -p "[Y/n] " response
        printf "\e[0m"
    fi
    response=${response,,}    # tolower
    if [[ -z $response || $response =~ ^(yes|y)$ ]]; then
        git push $opts $remote $branch:$upstream
        git branch --set-upstream-to=$remote/$upstream
    fi
}

function git-get-branch() {
    if [[ $# -eq 1 ]]; then
        git checkout -b $1 origin/$1
    elif [[ $# -eq 2 ]]; then
        git checkout -b $1 $2
    else
        printf "git-get-branch <branch> [remote]\n"
        return 1
    fi
}

function git-get-prefixed-branch() {
    git checkout $1/$2
}

function git-url-patch() {
    # lynx -dump -nonumbers -hiddenlinks=liston $1 | grep -e "^http.*00(0[1-9]|1[0-7])\.patch" | xargs -n 1 curl -s | git am
    lynx -dump -nonumbers -hiddenlinks=liston $1 | grep -e "^http.*003[0-9].*\.patch" | xargs -n 1 curl -s | git am
}

. $SETTINGS/git/.git-completion.bash

# Add git completion to aliases
__git_complete g __git_main
__git_complete gb _git_branch
__git_complete ggb _git_branch

__git_complete gc _git_commit
__git_complete gd _git_diff
__git_complete ge _git_send_email
__git_complete gf _git_fetch
__git_complete gg _git_checkout
__git_complete gfp _git_format_patch
__git_complete gl _git_log
__git_complete glo _git_log
__git_complete gp _git_cherry_pick
__git_complete gpb _git_log
__git_complete gr _git_reset
__git_complete gs _git_log

alias g='git'
alias ga='git add'
alias gb='git branch'
alias gbg='git branch -r | grep'
alias gbgo='git branch -r | grep origin'
alias gc='git commit'
alias gd='git-diff'
alias gdd='git diff'
alias gds='git diff --staged'
alias ge='git-email'
alias gek='git-email kvm'
alias ges='git-email sgx'
alias gf='git fetch'
alias gfo='git fetch origin'
alias gfp='nosend=1 git-email'
alias gft='git fetch --tags'
alias gg='git checkout'
alias ggs='git-get-prefixed-branch sgx'
alias gsc='git-get-prefixed-branch sgx/core'
alias gsu='git-get-prefixed-branch sgx/up'
alias gsk='git-get-prefixed-branch sgx/kvm'
alias ggk='git-get-prefixed-branch vmx'
alias ggb='git-get-branch'
alias ggd='gs | grep deleted: | cut -f 2 | tr -s " " | cut -f 2 -d " " | xargs git checkout'
alias gl='git log --decorate'
alias glo='git log --pretty=oneline --decorate'
alias gm="git status | grep modified | tr -d '\t' | tr -d ' ' | cut -f 2 -d :"
alias gw="git show"
alias gwo="git show -s --pretty='tformat:%h (%s)'"
alias gwp="git show -s --pretty='tformat:%h, %s'"
alias gpa='git-apply'
alias gpu='git-push'
alias gpo='git-push origin'
alias gpf='git-push force'
alias gp='git cherry-pick'
alias gpb='git-cherry-pick-branch'
alias gpc='git cherry-pick --continue'
alias gpl='git-cherry-pick-log'
alias gps='git-cherry-pick-show'
alias gr='git reset'
alias grh='git reset HEAD'
alias grhh='git reset HEAD --hard'
alias grc='git rebase --continue'
alias gri='git rebase --interactive'
alias gu='git pull'
alias gs='git status'
alias gsa='git stash apply'
alias gsdd='git stash drop'
alias gsl='git stash list'
alias gso='git stash show'
alias gsop='git stash show -p'
alias gsp='git stash pop'
alias gss='git stash save'
alias gt='git-tree'
alias gv='git remote -vv'


# -----------------------------------------------------------------------------
# Go
# -----------------------------------------------------------------------------
# Run gofmt on all .go files from the HEAD commit
function git-gofmt() {
    git diff-tree --no-commit-id --name-only -r $(git rev-parse --verify HEAD) | grep \\\.go | xargs --no-run-if-empty gofmt -s -w
}

# Run go lint on all .go files from the HEAD commit
function git-golint() {
    git diff-tree --no-commit-id --name-only -r $(git rev-parse --verify HEAD) | grep \\\.go | xargs -L 1 --no-run-if-empty golint
}

alias goi='go install -v'
alias gou='go get -u -v ./...'
alias gof='git-gofmt'
# Ignore comment, caps, ID and URL warnings
alias gol='git-golint | grep -v -e "should have comment" -e ALL_CAPS -e Id -e Url'

# -----------------------------------------------------------------------------
# Virtual Machines
# -----------------------------------------------------------------------------
alias virtd='daemon=true virt'
alias vm='virt stable kvm'
alias tvm='trace=1 virt stable kvm'
alias vmd='daemon=true virt stable kvm'
alias vmm='v2_cgroup=memory vm'
alias vb='uefi=false virt bios kvm'
alias vbd='daemon=true uefi=false virt bios kvm'
alias ve='epc=92M virt sgx'
alias vms='ve kvm'
alias vmo='epc=512M virt sgx kvm'
alias vmsd='daemon=true ve kvm'
alias vepc='v2_cgroup=sgx_epc vms'
alias ven='ve k2'
alias hyv='virt stable hyv'
alias vuefi='virt stable uefi'
# alias vuefi='qemu=stable img=uefi display=vnc iso=~/images/ubuntu/ubuntu-16.04.3-desktop-amd64.iso virtualmachine'
alias vanilla='virtio=false virt stable'
alias vu='uvirt stable'

alias hv='os=hyper-v virt stable machine'
alias hvd='os=hyper-v display=vnc virt stable machine'
alias hvi='os=hyper-v display=vnc iso1=~/images/hyper-v/virtio-win-0.1.126.iso virt stable machine'
alias hvnew='os=hyper-v display=vnc iso=~images/hyper-v/hyper-v-2016.iso iso1=~/images/hyper-v/virtio-win-0.1.126.iso virt stable'

# -----------------------------------------------------------------------------
# SGX
# -----------------------------------------------------------------------------
alias lsd='lsdt'
alias epc='~/go/src/intel.com/epct/epct.sh'
alias epd='EPCT_DEBUG=1 epc'
alias ep2='EPCT_CGROUP_V2=1 epc'
alias epd2='EPCT_CGROUP_V2=1 epd'
alias mx='make_sgxsdk'
alias dx='DEBUG=1 make_sgxsdk'

function mod-probe-intel-sgx() {
    sudo modprobe intel_sgx
    sudo chmod 666 /dev/sgx
}
alias mpi='mod-probe-intel-sgx'

# -----------------------------------------------------------------------------
# App Shortcuts
# -----------------------------------------------------------------------------
alias sub='/opt/sublime_text/sublime_text'
alias pts='~/.bin/pts/phoronix-test-suite'

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------
alias ipa="ifconfig | grep 10.54 | tr -s ' ' | cut -f 3 -d ' ' | cut -f 2 -d :"
alias sk='sudo -sE'
alias sbn='sudo reboot now'
alias sbf='sudo reboot -f'
if [[ "$HOSTPOST" == kvm || "$HOSTPOST" == k2 ]]; then
    alias ssn='sudo shutdown now'
    alias ssf='sudo shutdown -f'
fi
alias lg='lsmod | grep'
alias mp='sudo modprobe'
alias rdmsr='sudo rdmsr'
alias wrmsr='sudo wrmsr'
alias time='/usr/bin/time'
alias ftime='time -f "REAL:\t\t%e\nSYSTEM\t\t%S\nUSER\t\t%U\nCPU:\t\t%P\nMAX_RSS:\t%M\nCTX_INV:\t%c\nCTX_VOL:\t%w\nIO_IN:\t\t%I\nIO_OUT:\t\t%O\nMAJ_PF:\t\t%F\nMIN_PF:\t\t%R\nSWAPS:\t\t%W"'

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
alias ard='apt-cache rdepends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances --installed --recurse'
alias ai='sudo apt install'
alias ad='sudo apt update'
alias ap='sudo apt purge'
alias au='sudo apt upgrade'

# zpool
alias zp='sudo zpool'

#
function dpkg-query-size {
    dpkg-query -Wf '${Installed-Size}\t${Package}\n'
}
alias dq='dpkg-query-size'
alias dqs='dq | sort -n'
alias dg='dq | grep'
alias di='sudo dpkg -i'
alias ds='dpkg -S'

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
alias christ='sudo nmap -sP 10.54.74.* | grep -e sjchrist -e "for 10"'
alias lchrist='sudo nmap -sP 10.54.75.* | grep -e sjchrist -e "for 10"'
alias mchrist='sudo nmap -sP 10.54.77.* | grep -e sjchrist -e "for 10"'

# ls
alias ls='ls -aF --color=always'
alias ll='ls -lh'

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
alias ko='cd -P ~/go/src/kernel.org'

# Direct navigation to kernel and image directories
alias ku='cd -P ~/go/src/kernel.org/kvm-unit-tests'
alias li='cd -P ~/go/src/kernel.org/linux'
alias fu='cd ~/go/src/kernel.org/full'
alias sy='cd -P ~/go/src/kernel.org/syzkaller'
alias ho='cd ~/go/src/kernel.org/host'
alias se='cd -P ~/go/src/github.com/sean-jc/settings'
alias qq='cd -P ~/go/src/github.com/qemu/qemu'
alias kn='cd -P ~/build/kernel'
alias qe='cd -P ~/build/qemu'
alias iq='cd -P ~/images/qemu'
alias iv='cd -P ~/images/hyper-v'

# Direct navigation to outbox directories
alias out='cd -P ~/outbox'
alias ol='cd -P ~/outbox/linux'
alias ok='cd -P ~/outbox/linux/kvm'
alias om='cd -P ~/outbox/linux/mm'
alias os='cd -P ~/outbox/linux/sgx'

# Direct navigation to misc directories
alias dl='cd -P ~/Downloads'

# Kernel grep and gdb commands
alias gk='readelf -s vmlinux | grep'

function gdb-disassemble() {
    gdb -batch -ex "file $1" -ex "disassemble $2"
}
alias dis='gdb-disassemble'

function gdb-kernel {
    gdb-disassemble vmlinux $1
}
alias dk='gdb-kernel'

alias mkdir='mkdir -p'
function mcd() {
    mkdir $1
    cd $1
}

function pushd() {
    command pushd "$@" > /dev/null
}

function popd() {
    command popd "$@" > /dev/null
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

function make-kernel-package() {
    if [[ $# -lt 1 ]]; then
        printf "Must specify the target kernel name\n"
        return 1
    fi
    if [[ $# -gt 3 ]]; then
        printf "Maximum of 2 arguments supported: kernel (1), revision (2) and no-install (3)\n"
        return 2
    fi

    if [[ $guest == "true" ]]; then
        stubify-guest
    fi

    rev="1"
    if [[ $# -ge 2 ]]; then
        rev=$2
    fi
    rm -f ../*$1+_${rev}_*.deb
    THREADS=$(grep -c '^processor' /proc/cpuinfo)
    CONCURRENCY_LEVEL=$THREADS fakeroot make-kpkg --initrd --append-to-version=-$1 kernel_headers kernel_image --revision $rev
    if [[ $? -eq 0 && $# -lt 3 && $guest != "true" ]]; then
        sudo dpkg -i ../*$1+_${rev}_*.deb
    fi
}

# Make Host kernel
alias mh='make-kernel-package'

# Make Guest kernel
alias mg='guest=true make-kernel-package'

function list-kernel-package {
    grep menuentry /boot/grub/grub.cfg | grep -o -e "'Ubuntu, with Linux.*$1+'" | cut -f 2 -d "'" | cut -f 4 -d " "
}
alias lk='list-kernel-package'

function boot-kernel-package {
    if [[ $# -ne 1 ]]; then
        printf "Must specify the target kernel name\n"
        return 1
    fi
    local k=${1%%+}
    if [[ $(grep menuentry /boot/grub/grub.cfg | grep -c -e "'Ubuntu, with Linux.*$k+'") != "1" ]]; then
        grep menuentry /boot/grub/grub.cfg | grep -o -e "'Ubuntu, with Linux.*$k+'" | cut -f 2 -d "'"
        printf "Failed to find single entry for $1\n"
        return 1
    fi
    local entry=$(grep menuentry /boot/grub/grub.cfg | grep -o -e "'Ubuntu, with Linux.*$k+'" | cut -f 2 -d "'")
    if [[ -z $entry ]]; then
        printf "Failed to find entry=$entry\n"
        return 1
    fi
    printf "sudo grub-reboot 'Advanced options for Ubuntu>$entry'\n"
    sudo grub-reboot "Advanced options for Ubuntu>$entry"
    grep next_entry /boot/grub/grubenv
}
alias bk='boot-kernel-package'

function boot-windows {
    sudo grub-reboot "Windows Boot Manager (on /dev/sdb2)"
    grep next_entry /boot/grub/grubenv
}
alias bw='boot-windows'

#
function purge-kernel-package {
    if [[ $# -ne 1 ]]; then
        printf "Must specify the target kernel name\n"
        return 1
    fi
    local k=${1%%+}
    if [[ $(dpkg-query-size | grep -c -e "linux-image.*$k+") != "1" ]]; then
        dpkg-query-size | grep -e "linux-image.*$k+"
        printf "Failed to find single image for '$1'\n"
        return 1
    fi
    if [[ $(dpkg-query-size | grep -c -e "linux-headers.*$k+") != "1" ]]; then
        dpkg-query-size | grep -e "linux-headers.*$k+"
        printf "Failed to find single headers for '$1'\n"
        return 1
    fi
    local img=$(dpkg-query-size | grep -e "linux-image.*$k+"    | cut -f 2)
    local hdr=$(dpkg-query-size | grep -e "linux-headers.*$k+"  | cut -f 2)
    if [[ -z $img || -z $hdr ]]; then
        printf "Failed to find image=$img or headers=$hdr\n"
        return 1
    fi
    printf "sudo dpkg --purge $img $hdr\n"
    sudo dpkg --purge $img $hdr
}
alias pk='purge-kernel-package'

# Make Custom kernel
function make-kernel() {
    if [[ $# -lt 1 ]]; then
        printf "Must specify the target kernel name\n"
        return 1
    fi
    if [[ $# -gt 2 ]]; then
        printf "Maximum of 2 arguments supported: kernel (1) and target (2)\n"
        return 2
    fi
    if [[ $# -eq 2 ]]; then
        if [[ -n $TARGET ]]; then
            printf "Maximum of 1 argument when \$target is defined\n"
            return 2
        fi
        TARGET=$2
    fi
    if [[ ! -d ~/build/kernel/$1 ]]; then
        printf "Target build directory '~/build/kernel/$1' does not exist\n"
        return 4
    fi
    if [[ ! -d .git/info || ! -d kernel ]]; then
        printf "Must run from a top-level Linux repository\n"
        return 5
    fi
    if [[ -d ~/build/kernel/$1/source ]]; then
        local prev=$(readlink -f ~/build/kernel/$1/source)
        local curr=$(readlink -f $PWD)
        if [[ $prev != $curr ]]; then
            printf "Mismatch in build's previous source dir\n"
            return 6
        fi
    fi

    if [[ -f .git/info/sparse-checkout && -z $TARGET ]]; then
        stubify-linux $1
    fi

    if [[ $sgx == "true" ]]; then
        if git diff --quiet && git diff --staged --quiet ; then
            git cherry-pick sgx/zzz-token || return 1
        else
            git stash save
            git cherry-pick sgx/zzz-token || return 1
            git stash pop
        fi
    fi
    THREADS=$(grep -c '^processor' /proc/cpuinfo)
    if [[ -z $TARGET ]]; then
        make O=~/build/kernel/$1 -j$THREADS
        if [[ $? -eq 0 ]]; then
            make O=~/build/kernel/$1 INSTALL_MOD_PATH=~/build/kernel/$1 modules_install
        fi
    else
        make O=~/build/kernel/$1 $TARGET
    fi
    if [[ $sgx == "true" ]]; then
        if git diff --quiet && git diff --staged --quiet ; then
            git reset HEAD^ --hard
        else
            git stash save
            git reset HEAD^ --hard
            git stash pop
        fi
    fi
}
alias mk='make-kernel'
alias mc='make-kernel'
alias mks='sgx=true make-kernel'
alias mkb='TARGET=bzImage make-kernel'

function make-config() {
    if [[ $# -ne 1 && $# -ne 2 ]]; then
        printf "usage: mm <menuconfig|oldconfig> [dir]\n"
        return 1
    elif [[ $1 != "oldconfig" && $1 != "menuconfig" ]]; then
        printf "usage: mm <menuconfig|oldconfig> [dir]\n"
        return 1
    elif [[ $# -eq 2 ]]; then
        if [[ ! -f .git/info/sparse-checkout ]]; then
            printf "mm <dir> without sparse directory\n"
            return 1
        elif [[ -f .config ]]; then
            printf "mm <dir> with local config\n"
            return 1
        fi
        TARGET=$1 make-kernel $2
    else
        if [[ -f .git/info/sparse-checkout ]]; then
            printf "mm with sparse directory\n"
            return 1
        elif [[ ! -f .config ]]; then
            printf "mm without local config\n"
            return 1
        fi
        make $1
    fi
}
alias mm='make-config menuconfig'
alias mo='make-config oldconfig'

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
    printf "IP Address:\t       $(ipa)\n"
    printf "Kernel:\t\t       $(uname -r)\n"
}
alias si='system-info'

function system-info-verbose() {
    printf "IP Address:\t       $(ipa)\n"
    printf "Kernel:\t\t       $(uname -r)\n"
    printf "Date:\t\t       $(date)\n"
    printf "Uptime:\t\t      $(uptime)\n"
    lscpu | grep -v Architecture | grep -v "Byte Order" | grep -v op-mode | grep -v BogoMIPS | grep -v Virtualization | grep -v Flags | grep -v On-line
}
alias siv='system-info-verbose'

function make-qemu() {
    THREADS=$(grep -c '^processor' /proc/cpuinfo)
    make -j$THREADS
}
alias mq='make-qemu'

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
alias dim='docker images'
alias drim='di --quiet --filter=dangling=true | xargs --no-run-if-empty docker rmi'
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
