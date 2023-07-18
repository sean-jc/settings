# VS code linting gets confused :-()
. $SETTINGS/bash/catch

# Refresh bash terminal
alias rf='source ~/.bashrc'

function psudo() {
    printf "sudo %s\n" "$*"
    sudo $@
}

function pushd() {
    command pushd "$@" > /dev/null
}

function popd() {
    command popd "$@" > /dev/null
}

function get-nr-cpus() {
    grep -c '^processor' /proc/cpuinfo
}
alias cpus=get-nr-cpus

function is-guest() {
    grep -q hypervisor /proc/cpuinfo
    if [[ $? -eq 0 ]]; then
        echo "y"
        return 0
    fi

    return 1
}

function is-integer() {
    local re='^[0-9]+$'

    if [[ $1 =~ $re ]] ; then
        echo "y"
        return 0
    fi
    return 1
}

function curl-time()
{
    curl -4 -w "@$SETTINGS/bin/curl-format.txt" -o /dev/null -s $@
}
alias curlt='curl-time'

# -----------------------------------------------------------------------------
# MOOn
# -----------------------------------------------------------------------------
function moo-server-gulp() {
    pushd ~/go/src/github.com/zombull/moo/server
    gulp
    popd
}
alias msg='moo-server-gulp'

function moo-server-restart() {
    pushd ~/go/src/github.com/zombull/moo
    set -o xtrace
    go install -v && \
    sudo cp /home/sean/go/src/github.com/zombull/moo/server/nginx/nginx.conf /etc/nginx/nginx.conf && \
    cd server && gulp && \
    systemctl restart moo
    set +o xtrace
    popd
}
alias msr='moo-server-restart'

# -----------------------------------------------------------------------------
# Audio Mixer
# -----------------------------------------------------------------------------
function amixer-volume() {
    if [[ $# -eq 0 ]]; then
        amixer -D pulse sget Master
    else
        amixer -D pulse sset Master $(($1 * 65536 / 100))
    fi
}
alias av='amixer-volume'

#
# clangd
#
function gen-clangd-commands() {
    local repo=$(pwd | rev | cut -d'/' -f1 | rev)

    if [[ ! -f ./scripts/clang-tools/gen_compile_commands.py ]]; then
        printf "Needs to be run from top-level directory of kernel repo\n"
        return 1
    fi
    rm ./.vscode/compile_commands.json
    if [[ $repo != "slf" ]]; then
        ./scripts/clang-tools/gen_compile_commands.py -d /home/seanjc/build/kernel/clangd_$repo -o ./.vscode/compile_commands.json
    fi
    LLVM=1 make -C tools/testing/selftests/kvm -Bnwk | compiledb -n --build-dir ./tools/testing/selftests/kvm -o - >> ./.vscode/compile_commands.json
}
alias ccm='gen-clangd-commands'

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
    if [[ $# -eq 0 ]]; then
        git diff $(git rev-parse --verify HEAD^) $(git rev-parse --verify HEAD)
    elif [[ $# -eq 1 ]]; then
        git diff $1^ $1
    else
        git diff --no-index $1 $2
    fi
}

function git-diff-upstream() {
    git diff $(git rev-parse --abbrev-ref HEAD) $(git rev-parse --abbrev-ref --symbolic-full-name @{upstream})
}

function git-diff-local() {
    git diff $(git rev-parse --abbrev-ref --symbolic-full-name @{upstream}) $(git rev-parse --abbrev-ref HEAD)
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
        git am -3 $HOME/patches/*.*
    else
        git am -3 $1/*.*
    fi
}

function git-cherry-pick-branch() {
    local commits
    local arbitrary=1000
    local start
    local end

    if [ $# -ne 2 ]; then
        printf "Usage for cherry picking a branch: 'gpb <first commit> <last commit> (or <start> <nr commits>)'\n"
        return 1
    fi

    if [[ $(is-integer $2) ]]; then
        end=$1
        start=$(git rev-parse "$end~$(($2-1))")
    else
        start=$1
        end=$2
    fi

    git log --pretty=oneline --decorate $end | head -$arbitrary | grep -q $start
    if [[ $? -ne 0 ]]; then
        printf "Did not find $start in log from $end\n"
        return 1
    fi
    git log --pretty=oneline --decorate $end | head -$arbitrary | grep -B $arbitrary $start
    printf "\e[1;7;35mCherry pick these commits?"
    read -r -p "[Y/n] " response
    printf "\e[0m"
    response=${response,,}    # tolower
    if [[ -z $response || $response =~ ^(yes|y)$ ]]; then
        commits=$(glo $end | head -$arbitrary | grep -B $arbitrary $start | tac | cut -f 1 -d ' ' | xargs)
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

function git-archive-branch() {
    if [[ $# -eq 2 && $1 != "-f" || $# -gt 2 ]]; then
        printf "git-archive-branch [-f] <branch>\n"
        return 1
    fi

    local branch
    if [[ $# -eq 1 ]]; then
        branch=$1
    else
        branch=$2
    fi
    local dir=${branch//\//.}
    local repo=$(pwd | rev | cut -d'/' -f1 | rev)

    if [[ $HOSTDISPLAY == "@cloud" || $HOSTDISPLAY == "@zagreus" ]]; then
        printf "Archiving branches from remotes is not allowed\n"
        return 1;
    fi

    if [[ $repo == "slf" || $repo == "nox" ]]; then
        repo="linux"
    fi

    if [[ $# -eq 1  && ! -d "$HOME/outbox/$repo/$dir" ]]; then
        printf "'$branch' is not archived at '$HOME/outbox/$repo/$dir'\n"
        return 1
    fi
    git branch -D $branch
    if [[ $? -eq 0 ]]; then
        git push --delete o $branch
    fi
}

function git-get() {
    if [[ $# -eq 0 ]]; then
        git show -s --pretty="%C(auto)   %D"
    else
        git checkout $@
    fi
}

function git-get-branch() {
    if [[ $# -eq 1 ]]; then
        git checkout -b $1 o/$1
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

function git-stash() {
    if [[ $# -eq 2 ]]; then
        git stash $1 stash@{$2}
    else
        git stash $1
    fi
}

function git-update-subs() {
    git submodule update --recursive --remote
    git submodule update --recursive
}

function git-format-patch() {
    local nr

    if [[ $# -eq 0 ]]; then
        nr=1
    else
        nr=$1
    fi
    git format-patch --base="HEAD~$nr" -M --minimal --patience -o ~/patches -$nr
}

function git-send-thank-you() {
    if [[ $# -ne 1 ]]; then
        printf "Specify the target directory\n"
        return 1
    fi

    if [[ ! -d ~/thanks/$1 ]]; then
        printf "Target directory '~/thanks/$1' does not exist\n"
        return 1
    fi

    git send-email --to="Sean Christopherson <seanjc@google.com>" --confirm=always ~/thanks/$1/*.thanks

    read -r -p "Delete thanks?: [y/N]" response

    response=${response,,}    # tolower
    if [[ $response =~ ^(yes|y)$ ]]; then
        rm ~/thanks/$1/*.thanks
    fi
}

function git-merge-kvm-x86() {
    local branches=(
                    "apic"
                    "generic"
                    "misc"
                    "mmu"
                    "selftests"
                    "svm"
                    "vmx"
                    "pmu"
                   )
    local all="${branches[@]}"

    git fetch x

    for branch in "${branches[@]}"; do
        if [[ $CTHULU == "n" ]]; then
            git branch $branch x/$branch && git merge --no-ff --log $branch
        else
            git branch $branch x/$branch
        fi
    done

    if [[ $CTHULU != "n" ]]; then
        git merge --no-ff --log $all
    fi

    for branch in "${branches[@]}"; do
        git branch -D $branch
    done
}

function git-tag-kvm-x86-next() {
    local tag="kvm-x86-next-$(TZ=":America/Los_Angeles" date +%Y.%m.%d)"

    git tag $tag && printf "Created tag '$tag'\n"
}

function git-push-kvm-x86() {
    git push x q/apic:apic q/generic:generic q/misc:misc q/mmu:mmu q/pmu:pmu q/selftests:selftests q/svm:svm q/vmx:vmx
}

function git-rebase-kvm-x86() {
    local branches=("apic"
                "generic"
                "misc"
                "mmu"
                "pmu"
                "selftests"
                "svm"
                "vmx")

    for branch in "${branches[@]}"; do
        git checkout q/$branch && git merge --ff-only kvm/next
    done
}

function git-get-tag() {
    local major=$(grep -E "^VERSION" Makefile | cut -f 3 -d ' ')
    local minor=$(($(grep -E "^PATCHLEVEL" Makefile | cut -f 3 -d ' ')+1))

    tag="kvm-x86-$1-$major.$minor"
    if [[ $1 != "apic" &&
          $1 != "generic" &&
          $1 != "misc" &&
          $1 != "mmu" &&
          $1 != "pmu" &&
          $1 != "selftests" &&
          $1 != "svm" &&
          $1 != "vmx" &&
          $1 != "fixes" ]]; then
        printf "$1 isn't a known branch\n"
        return 1
    fi

    if [[ $1 == "fixes" ]]; then
        minor=$(($(grep -E "^PATCHLEVEL" Makefile | cut -f 3 -d ' ')))
    else
        minor=$(($(grep -E "^PATCHLEVEL" Makefile | cut -f 3 -d ' ')+1))
    fi

    echo "kvm-x86-$1-$major.$minor"
    return 0
}

function git-request-pull() {
    local tag=$(git-get-tag $1)

    if [[ $? -ne 0 ]]; then
        return 1
    fi

    if [[ $# -ne 1 && $# -ne 2 ]]; then
        printf "Usage: git-request-pull <target branch> [number of commits to omit]\n"
        return 1
    fi

    git fetch x
    if [[ $# -eq 2 ]]; then
        git checkout autopull && git reset --hard "x/$1~$2" && git tag -s $tag
    else
        git checkout autopull && git reset --hard x/$1 && git tag -s $tag
    fi

    printf "\e[1;7;35mPush '$tag' to kvm-x86?"
    read -r -p "[Y/n] " response
    printf "\e[0m"
    response=${response,,}    # tolower
    if [[ -z $response || $response =~ ^(yes|y)$ ]]; then
        git push x $tag

        printf "\e[1;7;35mGenerate $HOME/pulls/$1.mail?"
        read -r -p "[Y/n] " response
        printf "\e[0m"
        response=${response,,}    # tolower
        if [[ -z $response || $response =~ ^(yes|y)$ ]]; then
            printf "Subject: [GIT PULL] KVM: x86: $tag *** SUBJECT HERE ***\n\n*** BLURB HERE ***\n\n" > $HOME/pulls/$1.mail
            git request-pull kvm/master https://github.com/kvm-x86/linux.git tags/$tag >> $HOME/pulls/$1.mail
        fi
    fi
}

function git-make-kut-tag() {
    local tag="kvm-x86-$(TZ=":America/Los_Angeles" date +%Y.%m.%d)"

    git fetch x
    git checkout autopull && git reset --hard x/next && git tag -s $tag && git push x $tag
}

function git-request-kut-pull() {
    local tag="kvm-x86-$(TZ=":America/Los_Angeles" date +%Y.%m.%d)"

    printf "Subject: [kvm-unit-tests GIT PULL] x86: *** SUBJECT HERE ***\n\n*** BLURB HERE ***\n\n" > $HOME/pulls/kut.mail
    git request-pull $1 https://github.com/kvm-x86/kvm-unit-tests.git tags/$tag >> $HOME/pulls/kut.mail
}

function git-send-pull-requests() {
    local branches=("generic"
                    "misc"
                    "mmu"
                    "pmu"
                    "selftests"
                    "svm"
                    "vmx")

    if [[ $1 == "kut" ]]; then
        branches=("kut")
    fi

    for branch in "${branches[@]}"; do
        if [[ ! -f $HOME/pulls/$branch.mail ]]; then
            printf "Dude, generate a pull request for $branch"
            return 1;
        fi

        grep -q -e "BLURB HERE" -e "SUBJECT HERE" $HOME/pulls/$branch.mail
        if [ $? -eq 0 ]; then
            printf "Edit the subject+blurb (%s) before sending!\n" "$HOME/pulls/$branch.mail"
            return 1
        fi
    done

    read -r -p "Send pull requests to self: [Y/n]" response
    response=${response,,}    # tolower
    if [[ -z $response || $response =~ ^(yes|y)$ ]]; then
        git send-email --confirm=always --suppress-cc=all --reply-to="Sean Christopherson <seanjc@google.com>" --to="Sean Christopherson <seanjc@google.com>" $HOME/pulls
    else
        return 1
    fi

    read -r -p "Send pull requests to Paolo: [Y/n]" response
    response=${response,,}    # tolower
    if [[ -z $response || $response =~ ^(yes|y)$ ]]; then
        git send-email --confirm=always --suppress-cc=all --reply-to="Sean Christopherson <seanjc@google.com>" --to="Paolo Bonzini <pbonzini@redhat.com>" --cc=kvm@vger.kernel.org --bcc="Sean Christopherson <seanjc@google.com>" $HOME/pulls
    fi
}

. $SETTINGS/git/.git-completion.bash

# Add git completion to aliases
__git_complete g __git_main
__git_complete gab _git_branch
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
__git_complete gri _git_branch
__git_complete gs _git_log

alias g='git'
alias ga='git add'
alias gab='git-archive-branch'
alias gb='git branch'
alias gc='git commit'
alias gd='git-diff'
alias gdd='git diff'
alias gds='git diff --staged'
alias gdu='git-diff-upstream'
alias gdl='git-diff-local'
alias gek='git-email kvm'
alias geu='git-email ku'
alias gem='git-email mm'
alias geq='git-email qemu'
alias gex='git-email x86'
alias gf='git fetch'
alias gfo='git fetch o'
alias gfu='git fetch upstream'
alias gfx='git fetch x'
alias gfp='git-format-patch'
alias gfk='nosend=1 git-email kvm'
alias gft='git fetch --tags'
alias gg='git-get'
alias gga='git branch -r | tr -d " " | grep -v -E "^o/" | grep'
alias ggb='git-get-branch'
alias ggc='git-get-cc'
alias ggd='gs | grep deleted: | cut -f 2 | tr -s " " | cut -f 2 -d " " | xargs git checkout'
alias ggl='git branch | grep'
alias ggo='git branch -r | tr -d " " | grep -E "^o/" | cut -f 2- -d "/" | grep'
alias gl='git log --decorate'
alias glc='git log --pretty=oneline --decorate --author=christopherson'
alias glg='git log --pretty=oneline --decorate --graph'
alias glo='git log --pretty=oneline --decorate'
alias gm="git status | grep modified | tr -d '\t' | tr -d ' ' | cut -f 2 -d :"
alias gmk='git-merge-kvm-x86'
alias gmks='CTHULU=n git-merge-kvm-x86'
alias gmr='git pull --rebase=false --no-ff'
alias gmt='git-make-tag'
alias gw="git show"
alias gwo="git show -s --pretty='tformat:%h (\"%s\")'"
alias gwp="git show -s --pretty='tformat:%h, \"%s\"'"
alias gpa='git-apply'
alias gpu='git-push'
alias gpo='git-push o'
alias gpf='git-push force'
alias gp='git cherry-pick'
alias gpb='git-cherry-pick-branch'
alias gpc='git cherry-pick --continue'
alias gpl='git-cherry-pick-log'
alias gps='git-cherry-pick-show'
alias gpk='git-push-kvm-x86'
alias gr='git reset'
alias grh='git reset HEAD'
alias grhh='git reset HEAD --hard'
alias grp='git-request-pull'
alias gru='git-request-kut-pull'
alias grc='git rebase --continue'
alias gri='git rebase --interactive'
alias gu='git pull'
alias gs='git status'
alias gsa='git-stash apply'
alias gsdd='git-stash drop'
alias gsl='git-stash list'
alias gso='git-stash show'
alias gsop='git-stash "show -p"'
alias gsp='git-stash pop'
alias gsr='git-send-pull-requests'
alias gss='git-stash save'
alias gst='git-send-thank-you'
alias gsu='git-send-pull-requests kut'
alias gt='git-tree'
alias gtc='git tag -l --contains'
alias gtn='git-tag-kvm-x86-next'
alias gus='git-update-subs'
alias gv='git remote -vv'

# b4 and other lore stuff
function b4-am-apply() {
    rm -f $HOME/patches/*
    $HOME/go/src/kernel.org/b4/b4.sh am --no-cover -s -C -o $HOME/patches/ "$@" && git-apply
}

function b4-am() {
    rm -f $HOME/patches/*
    $HOME/go/src/kernel.org/b4/b4.sh am --no-cover -s -C -o $HOME/patches/ "$@"
}

function b4-mbox() {
    $HOME/go/src/kernel.org/b4/b4.sh mbox -o $HOME/mail/ "$1"
}

function b4-mbox-mutt() {
    local fname=$($HOME/go/src/kernel.org/b4/b4.sh mbox -o $HOME/mail/ "$1" 2>&1 | grep Saved | cut -f 2 -d ' ')

    if [[ -z $fname ]]; then
        $HOME/go/src/kernel.org/b4/b4.sh mbox -o $HOME/mail/ "$1"
        return 1;
    fi
    sed -i -r 's/"([a-zA-Z0-9]+),+\s+([a-zA-Z0-9]+\s*[a-zA-Z0-9]*)"/\2 \1/' "$fname"
    printf "Saved and Opening $fname\n"
    mutt -f "$fname"
}

function b4-am-mbox() {
    b4-mbox "${@: -1}"
    b4-am-apply "$@"
}

function b4-ty() {
    if [[ $# -ne 1 ]]; then
        return 1
    fi

    local dir=$(git rev-parse --abbrev-ref HEAD | cut -f 2 -d '/')

    if [[ $dir != "apic" &&
          $dir != "generic" &&
          $dir != "misc" &&
          $dir != "mmu" &&
          $dir != "pmu" &&
          $dir != "selftests" &&
          $dir != "svm" &&
          $dir != "vmx" &&
          $dir != "next" &&
          $dir != "fixes" ]]; then
        printf "Switch to the right branch...\n"
        return 1
    fi
    $HOME/go/src/kernel.org/b4/b4.sh ty -o $HOME/thanks/$dir -t $1
}

function b4-ty-fixup() {
    local commits
    local hash
    local shortlog
    local i=1

    if [[ $# -ne 2 ]]; then
        return 1
    fi

    commits=$(git log --oneline $1 | head -$2 | tac)
    echo "$commits" | while IFS= read -r commit ; do
        hash=$(echo $commit | cut -f 1 -d ' ')
        shortlog=$(echo $commit | cut -f 2- -d ' ')
        printf "[$i/$2] $shortlog\n      https://github.com/kvm-x86/linux/commit/$hash\n"

        i=$((i+1))
    done
}

alias b4=$HOME/go/src/kernel.org/b4/b4.sh

alias bb='b4-am-apply'
alias bbl='b4-am-apply -t -l'
alias bbn='b4-am'
alias bm='b4-mbox'
alias bmm='b4-mbox-mutt'
alias bam='b4-am-mbox -t -l'
alias ty='b4-ty'
alias scy='scp -r ~/thanks/. z:~/thanks'
alias sy='ll ~/thanks/**/*.thanks'
alias tyf='b4-ty-fixup'
alias yy='b4 ty -o $HOME/thanks -l'
alias dy='b4 ty -o $HOME/thanks -d'

alias mu='mutt -f $HOME/mail/*.mbx'
alias mf='mutt -f'

# offlineimap
alias oi='offlineimap -f "INBOX"'
alias ol='offlineimap -f "Lists/linus"'
alias ok='offlineimap -f "Lists/kvm"'
alias op='offlineimap -f "Lists/posted"'
alias of='offlineimap -f "Lists/for_paolo"'
alias oo='offlineimap -f "Lists/todo"'
alias ou='offlineimap -f "Lists/x86"'

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
alias virtd='daemon=y run_vm'
alias vm='run_vm stable kvm'
alias vme='run_vm emulator kvm'
alias vmm='modules=n vm'
alias vm32='ovmf=32 vm'
alias ivm='i386=y run_vm stable i386'
alias tvm='trace=1 run_vm stable kvm'
alias vmd='daemon=y run_vm stable kvm'
alias vm2='v2_cgroup=memory vm'
alias vb='mbr=y run_vm bios kvm'

function vm-mig-src {
    gb=32 modules=n cpus=16 cpuid="-invtsc" vm vm
}
function vm-mig-dst {
    migrate=6666 gb=32 modules=n cpus=16 cpuid="-invtsc" vm vm
}

# SGX, i.e. expose EPC
alias vbd='daemon=y mbr=y run_vm bios kvm'
alias vmi='epc=64M,prealloc run_vm sgx kvm'
alias vmo='epc=128M,prealloc,reclaim run_vm sgx kvm'
alias vms='epc="16M,prealloc 16M,prealloc 16M 16M 16M 12M" run_vm sgx kvm'
alias vmsd='daemon=y vms'
alias vepc='v2_cgroup=sgx_epc vms'

alias hyv='run_vm stable hyv'
alias vuefi='run_vm stable uefi'
# alias vuefi='qemu=stable img=uefi display=vnc iso=~/images/ubuntu/ubuntu-16.04.3-desktop-amd64.iso virtualmachine'
alias vanilla='virtio=false run_vm stable'

alias mountbase='sudo mount -o loop,offset=210763776 ~/images/qemu/ubuntu-18.04-server-base.raw ~/images/qemu/mnt'
alias mountk2='sudo mount -o loop,offset=210763776 ~/images/qemu/ubuntu-18.04-server-k2.raw ~/images/qemu/mnt'
alias mounti386='sudo mount -o loop,offset=1048576 ~/images/qemu/ubuntu-18.04-server-i386.raw ~/images/qemu/mnt'
alias mountvm='sudo mount -o loop,offset=210763776 ~/images/qemu/ubuntu-18.04-server-kvm.raw ~/images/qemu/mnt'

# Get the PID of the VM.  Obviously expects a single VM to be running...
alias vp='psg build/qemu | grep sean | tr -s " " | cut -f 2 -d " "'

function vm-stats() {
    local pid=$(vp)
    local cmd=$(cat /proc/$pid/cmdline | tr '\000' ' ')
    local vm_lines=$(cat /proc/$pid/status | grep --color=never -e Vm)
    local lines=$(cat /proc/$pid/status | grep --color=never -e Huge -e Rss)
    local line
    local field
    local mb

    if [ $# -gt 0 ]; then
        printf "$cmd\n\n"
    fi

    while read -r line; do
        field=$(echo $line | cut -f 1 -d " ")
        mb=$(echo $line | awk '{megs=$2/1024} END {print megs}')
        printf "%s\t\t%8.1f MB\n" $field $mb
    done <<< "$vm_lines"

    while read -r line; do
        field=$(echo $line | cut -f 1 -d " ")
        mb=$(echo $line | awk '{megs=$2/1024} END {print megs}')
        printf "%s\t%8.1f MB\n" $field $mb
    done <<< "$lines"

    if [[ -z $(getcap $HOME/bin/get_smaps | grep cap_sys_ptrace) ]]; then
        psudo setcap cap_sys_ptrace+ep $HOME/bin/get_smaps
    fi

    mb=$($HOME/bin/get_smaps $pid | grep -e AnonHugePages | awk '{ if($2>4) print $0} ' | awk -F ":" '{print $2}' | awk '{Total+=$1/1024} END {print Total}')
    printf "AnonHugePages:\t%8.1f MB\n" $mb
}
alias vs='vm-stats'
alias vss='vm-stats true'

alias ssl='ssh -6 sean@fe80::216:3eff:fe68:00%tap1'
alias ssl1='ssh -6 sean@fe80::216:3eff:fe68:00%tap1'
alias ssl2='ssh -6 sean@fe80::216:3eff:fe68:10%tap1'
alias ssl3='ssh -6 sean@fe80::216:3eff:fe68:20%tap1'
alias ssi='ssh -6 sean@fe80::216:3eff:fe68:80%tap1'
alias ssi1='ssh -6 sean@fe80::216:3eff:fe68:80%tap1'
alias ssi2='ssh -6 sean@fe80::216:3eff:fe68:90%tap1'
alias ssi3='ssh -6 sean@fe80::216:3eff:fe68:a0%tap1'

function scp-to {
    scp -6 $1 sean@[fe80::216:3eff:fe68:0%tap1]:$2
}
alias scr='scp-to'

function scp-from {
    scp -6 sean@[fe80::216:3eff:fe68:0%tap1]:$2 $1
}
alias scl='scp-from'

alias dvm='gdb -x $SETTINGS/bin/debug_vm'

alias hv='os=hyper-v run_vm stable machine'
alias hvd='os=hyper-v display=vnc run_vm stable machine'
alias hvi='os=hyper-v display=vnc iso1=~/images/hyper-v/virtio-win-0.1.126.iso run_vm stable machine'
alias hvnew='os=hyper-v display=vnc iso=~images/hyper-v/hyper-v-2016.iso iso1=~/images/hyper-v/virtio-win-0.1.126.iso run_vm stable'

alias mvm='modules=false run_vm stable kvm'
alias mivm='modules=false i386=y run_vm stable i386'

# -----------------------------------------------------------------------------
# SGX
# -----------------------------------------------------------------------------
alias lsd='lsdt'
alias lsb='lsdr --heap 8 -c 16 -k nil --no-output'
alias lst='lsdr --heap 8 --min-heap 1.5 -c 16 -k nil --no-output'
alias lst1='lsdr --heap 1 --min-heap 2.0 -c 16 -k nil --no-output --threads 1'
alias ls1='lsdr --heap 1 --processes 1 --goroutines 1 --threads 1 -c 16 -k nil --no-output'
alias lsr='lsdr --heap 8 --min-heap 1.5 -c 16 -k rand --no-output'
alias lsk='lsdr --heap 8 --min-heap 1.5 -c 16 -k kill --no-output'
alias lss='lsdr --heap 8 --min-heap 1.5 -c 16 -k kill --no-output --min-kill-delay 2000 --max-kill-delay 8000'
alias lsp='lsdr --heap 8 -c 16 -k nil -r'
alias epc='~/go/src/intel.com/epct/epct.sh'
alias epd='EPCT_DEBUG=1 epc'
alias ep2='EPCT_CGROUP_V2=1 epc'
alias epd2='EPCT_CGROUP_V2=1 epd'

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------
alias ipa="ifconfig | grep -e 10.54 -e 192.168.1 | tr -s ' ' | cut -f 3 -d ' ' | cut -f 2 -d :"
alias sk='SEAN_HOME=$HOME sudo -sE'
alias sbn='sudo reboot now'
alias sbf='sudo reboot -f'

function reboot-sysrq() {
    echo 1 | sudo tee /proc/sys/kernel/sysrq > /dev/null
    echo b | sudo tee /proc/sysrq-trigger > /dev/null
}

if [[ "$HOSTPOST" =~ ^[a-z]+-(vm|l2|l3|i386|i2|ii) ]]; then
    alias sbr='reboot-sysrq'
    alias ssn='sudo shutdown now'
    alias ssf='sudo shutdown -f'
fi

function check-patch-head() {
    local dir=$(pwd | rev | cut -d'/' -f1 | rev)
    local nr

    if [[ $# -eq 0 ]]; then
        nr=1
    else
        nr=$1
    fi

    if [[ $dir == "qemu" ]]; then
        ./scripts/checkpatch.pl --branch HEAD~1..HEAD
    else
        ./scripts/checkpatch.pl -g "HEAD~$nr"..HEAD --codespell --codespellfile=$SETTINGS/codespell/dictionary.txt
    fi
}
alias cph='check-patch-head'

alias cs='codespell -D $SETTINGS/codespell/dictionary.txt'

function cpio-initramfs() {
    if [[ $# -ne 2 ]]; then
        printf "usage: cpr <input> <output>\n"
        return 1
    fi
    echo lib/firmware/$1 | cpio -H newc -o > ~/build/initramfs/$2.cpio
}
alias cpr='cpio-initramfs'
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

#
function dpkg-query-size {
    dpkg-query -Wf '${Installed-Size}\t${Package}\n'
}
alias dpq='dpkg-query-size'
alias dpqs='dpq | sort -n'
alias dg='dpq | grep'
alias di='sudo dpkg -i'

function dpkg-purge {
    dpkg --list | grep "^rc" | cut -d " " -f 3 | xargs sudo dpkg --purge
}

# systemd
alias sys='sudo systemctl'
alias failed='sys list-units --state=failed'
alias services='sys list-unit-files --type=service'

# misc system
alias btm='blueman-manager &'
alias gcm='gcert -s -m kernel-development,corevirt-team-testing'

function dev-sync() {
    if [[ $# -ne 2 ]]; then
        printf "usage: dev-sync <host> <option>\n"
        return 1
    elif [[ $1 != "full" && $1 != "settings" && $1 != "binaries" && $1 != "kvm" && $1 != "tests" ]]; then
        printf "usage: ds[,b,k,s,t] <target>\n"
        return 1
    fi

    if [[ $1 == "full" ]]; then
        ssh $2 "mkdir -p /data/local/seanjc/build/kernel/vm/arch/x86/boot; \
                mkdir -p /data/local/seanjc/build/kernel/vm/lib/modules; \
                mkdir -p /data/local/seanjc/build/kernel/pae/arch/x86/boot; \
                mkdir -p /data/local/seanjc/build/kernel/pae/lib/modules; \
                mkdir -p /data/local/seanjc/build/qemu; \
                mkdir -p /data/local/seanjc/go/src/github.com/sean-jc; \
                mkdir -p /data/local/seanjc/go/src/kernel.org; \
                mkdir -p /data/local/seanjc/images/qemu"
    fi
    if [[ $1 == "full" || $1 == "settings" ]]; then
        rsync --checksum ~/.bashrc $2:/data/local/seanjc
        rsync --checksum ~/.inputrc $2:/data/local/seanjc
        rsync --checksum ~/.vimrc $2:/data/local/seanjc
        rsync --checksum --recursive --exclude='.git*' ~/go/src/github.com/sean-jc/settings $2:/data/local/seanjc/go/src/github.com/sean-jc
        rsync --checksum ~/go/src/github.com/sean-jc/settings/git/.git-completion.bash $2:/data/local/seanjc/go/src/github.com/sean-jc/settings/git
        ssh $2 "chmod +x /data/local/seanjc/go/src/github.com/sean-jc/settings/bin/timeout"
    fi
    if [[ $1 == "full" || $1 == "binaries" ]]; then
        rsync --checksum --recursive --links ~/build/qemu/static-7.0 $2:/data/local/seanjc/build/qemu
        rsync --checksum --recursive --links ~/build/ovmf $2:/data/local/seanjc/build
        ssh $2 "rm -f /data/local/seanjc/build/qemu/stable; ln -s /data/local/seanjc/build/qemu/static-7.0/x86_64-softmmu/qemu-system-x86_64 /data/local/seanjc/build/qemu/stable"
    fi
    if [[ $1 == "full" || $1 == "tests" ]]; then
        rsync --checksum --recursive --links ~/build/selftests $2:/data/local/seanjc/build
        rsync --checksum --recursive --links --exclude='.git*' --exclude='logs*' ~/go/src/kernel.org/kvm-unit-tests $2:/data/local/seanjc/go/src/kernel.org
        rsync --checksum --recursive --links --exclude='.git*' --exclude='logs*' ~/go/src/kernel.org/kut-32 $2:/data/local/seanjc/go/src/kernel.org
        rsync --checksum --recursive --links --exclude='.git*' --exclude='logs*' ~/go/src/kernel.org/kut-efi $2:/data/local/seanjc/go/src/kernel.org
    fi
    if [[ $1 == "full" || $1 == "kvm" ]]; then
        rsync --checksum ~/build/kernel/vm/arch/x86/boot/bzImage $2:/data/local/seanjc/build/kernel/vm/arch/x86/boot
        rsync --checksum --recursive ~/build/kernel/vm/lib/modules $2:/data/local/seanjc/build/kernel/vm/lib
        rsync --checksum ~/build/kernel/pae/arch/x86/boot/bzImage $2:/data/local/seanjc/build/kernel/pae/arch/x86/boot
        rsync --checksum --recursive ~/build/kernel/pae/lib/modules $2:/data/local/seanjc/build/kernel/pae/lib
    fi
}
alias ds='dev-sync full'
alias dsb='dev-sync binaries'
alias dsk='dev-sync kvm'
alias dss='dev-sync settings'
alias dst='dev-sync tests'

# List all UDP/TCP ports
alias ports='netstat -tulanp'

#org.gnome.settings-daemon.plugins.media-keys play-static ['XF86AudioPlay', '<Ctrl>XF86AudioPlay']
#org.gnome.settings-daemon.plugins.media-keys next-static ['XF86AudioNext', '<Ctrl>XF86AudioNext']
#org.gnome.settings-daemon.plugins.media-keys previous-static ['XF86AudioPrev', '<Ctrl>XF86AudioPrev']
function show-keybindings() {
    (for schema in $(gsettings list-schemas); do gsettings list-recursively $schema; done)
}
alias shks="'show-keybindings' | grep '<Super>'"
alias shkc="'show-keybindings' | grep '<Ctrl>'"
alias shka="'show-keybindings' | grep '<Alt>'"

function unset-keybinding() {
    gsettings set $@ []
}
alias ukb='unset-keybinding'

# Find my systems in the lab...
alias christ='sudo nmap -sP 10.54.74.* | grep -e sjchrist -e "for 10"'
alias jchrist='sudo nmap -sP 10.54.31.* | grep -e sjchrist -e "for 10"'
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

# grep
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# find
alias rfind='sudo find / -name 2> /dev/null'

function ps-grep-kill() {
    local response=y
    local kps
    local kp
    kps=$(/bin/ps -e -o pid,user,cmd | grep -v grep | grep -v -- --forest | expand | cut -c-$COLUMNS | grep $1)

    while read -r -u 3 kp; do
        printf "Kill\n\t$kp?\n"
        read -r -p "[Y/n] " response
        response=${response,,}    # tolower
        if [[ -z $response || $response =~ ^(yes|y)$ ]]; then
            kcmd="kill"
            if [[ $kill == "true" ]]; then
                kcmd="$kcmd -KILL"
            fi
            kcmd="$kcmd $(echo $kp | cut -f 1 -d ' ')"
            if [[ $(echo $kp | cut -f 2 -d ' ') != "sean" ]]; then
                kcmd="sudo $kcmd"
            fi
            $kcmd
            if [[ $? -eq 0 ]]; then
                printf "Killed $(echo $kp | cut -f 1 -d ' ')\n"
            fi
        fi
    done 3<<< "$kps"
}

# ps
alias ps='ps -a --forest -o user,pid,ppid,%cpu,%mem,vsz,rss,cmd'
alias psm='ps -e | sort -nr -k 5 | head -10 | cut -c-$COLUMNS'
alias psc='ps -e | sort -nr -k 4 | head -10 | cut -c-$COLUMNS'
alias psg='ps -e | grep -v grep | grep -v -- --forest | expand | cut -c-$COLUMNS | grep -i -e VSZ -e'
alias psk='ps-grep-kill'
alias pskk='kill=true ps-grep-kill'

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

# Direct navigation to directories
alias so='cd ~/go/src'
alias gh='cd ~/go/src/github.com'
alias se='cd ~/go/src/github.com/sean-jc/settings'
alias qq='cd ~/go/src/github.com/qemu/qemu'
alias zz='cd ~/go/src/github.com/zombull'
alias int='cd ~/go/src/intel.com'
alias ko='cd ~/go/src/kernel.org'
alias ho='cd ~/go/src/kernel.org/host'
alias ku='cd ~/go/src/kernel.org/kvm-unit-tests'
alias k32='cd ~/go/src/kernel.org/kut-32'
alias li='cd ~/go/src/kernel.org/linux'
alias no='cd ~/go/src/kernel.org/nox'
alias nt='cd ~/go/src/kernel.org/nox/tools/testing/selftests/kvm'
alias si='cd ~/go/src/kernel.org/sinux'
alias te='cd ~/go/src/kernel.org/slf'
alias tk='cd ~/go/src/kernel.org/slf/tools/testing/selftests/kvm'
alias uu='cd ~/go/src/kernel.org/gpu'
alias bi='cd ~/build'
alias kn='cd ~/build/kernel'
alias qe='cd ~/build/qemu'
alias tt='cd ~/build/selftests'
alias ig='cd ~/images/guest'
alias iq='cd ~/images/qemu'
alias iv='cd ~/images/hyper-v'
alias dr='cd ~/images/devrez'

# Direct navigation to outbox directories (posted patches)
alias pp='cd ~/outbox/linux'
alias pu='cd ~/outbox/kvm-unit-tests'
alias pq='cd ~/outbox/qemu'

# Direct navigation to misc directories
alias dl='cd ~/Downloads'
alias cpa='cd ~/patches'
alias th='cd ~/thanks'
alias sp='rm -f ~/patches/* && scp c:~/patches/* ~/patches/'

# Kernel grep and gdb commands
alias gk='readelf -sW vmlinux | grep'
alias gkv='readelf -sW arch/x86/kvm/kvm-intel.ko | grep'
alias gkk='readelf -sW arch/x86/kvm/kvm.ko | grep'
alias gx='readelf -sW drivers/platform/x86/intel_sgx/intel_sgx.ko | grep'
alias gq='readelf -sW ~/build/qemu/stable | grep'

function gdb-disassemble() {
    if [[ $# -lt 2 ]]; then
        printf "Must specify the target file (1) and function (2)\n"
        return 1
    fi
    if [[ $# -gt 3 ]]; then
        printf "Maximum of 3 arguments supported: file (1), function (2) and offset (3)\n"
        return 2
    fi

    gdb -batch -ex "file $1" -ex "disassemble $2"
    gdb -batch -ex "file $1" -ex "disassemble /r $2"
    gdb -batch -ex "file $1" -ex "disassemble /m $2"
    if [[ $# -eq 3 ]]; then
        gdb -batch -ex "file $1" -ex "list *$2+$3"
        printf "Offset $3 in $2 in decimal: %d\n" $3
    fi
}
alias dis='gdb-disassemble'
alias dk='gdb-disassemble vmlinux'
alias dks='gdb-disassemble arch/x86/kvm/kvm-amd.ko'
alias dkv='gdb-disassemble arch/x86/kvm/kvm-intel.ko'
alias dkk='gdb-disassemble arch/x86/kvm/kvm.ko'
alias dx='gdb-disassemble drivers/platform/x86/intel_sgx/intel_sgx.ko'
alias dq='gdb-disassemble ~/build/qemu/stable'

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
alias mguest='guest=true make-kernel-package'


function make-x86() {
    $@
}
function make-clang() {
    LLVM=1 $@
}
function make-arm() {
    ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- $@
}
alias ma='make-arm make'
alias ja='make-clang make-arm make'
alias mah='make-arm make headers_install'

function make-mips() {
    ARCH=mips CROSS_COMPILE=mips64-linux-gnuabi64- $@
}
function make-ppc() {
    ARCH=powerpc CROSS_COMPILE=powerpc64-linux-gnu- $@
}
function make-riscv() {
    ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- $@
}
alias mr='make-riscv make'
alias jr='make-clang make-riscv make'
alias mrh='make-riscv make headers_install'

function make-s390() {
    ARCH=s390 CROSS_COMPILE=s390x-linux-gnu- $@
}
alias ms='make-s390 make'
alias js='make-clang make-s390 make'
alias msh='make-s390 make headers_install'

function make-selftests() {
    local arch_dir
    local tests
    local i
    local selftest
    local static=""
    local ls

    if [[ $# -lt 1 ]] || [[ $1 != "x86" && $1 != "clang" && $1 != "arm" ]]; then
        printf "Must specify 'x86', 'clang' or 'arm' as first argument\n"
        return 1
    fi
     if [[ $# -lt 2 ]] || [[ $2 != "slf" && $2 != "nox" ]]; then
        printf "Must specify 'slf' or 'nox' as second argument\n"
        return 1
    fi
    if [[ $# -gt 3 ]]; then
        printf "Max of 3 arguments supported\n"
    fi
    if [[ $# -gt 2 && $3 != "clean" ]]; then
        printf "Can only specify 'clean' as third argument\n"
        return 1
    fi

    pushd $HOME/go/src/kernel.org/$2/tools/testing/selftests/kvm
    if [[ $# -gt 2 && $3 == "clean" ]]; then
        git clean -fdx
    fi

    if [[ $(whoami) == "seanjc" ]]; then
        static="-static"
    fi

    if [[ $1 == "arm" ]]; then
        arch_dir="aarch64"
    else
        arch_dir="x86_64"
    fi
    ls=$(which ls)
    tests=( $($ls -1 $HOME/go/src/kernel.org/$2/tools/testing/selftests/kvm/*.c $HOME/go/src/kernel.org/$2/tools/testing/selftests/kvm/$arch_dir/*.c) )

    EXTRA_CFLAGS="$static -Werror -gdwarf-4" make-$1 make -j$(get-nr-cpus)
    if [[ $? -eq 0 ]]; then
        rm -f $HOME/build/selftests/*
        for i in "${tests[@]}"; do
            i="${i%.*}"
            selftest=$(basename -- "$i")
            if [[ -f $i ]]; then
                cp $i $HOME/build/selftests/$selftest
            fi
        done
    fi
    popd
}
alias mt='make-selftests x86 slf'
alias mtc='make-selftests x86 slf clean'
alias jt='make-clang make-selftests x86 slf'
alias jtc='make-clang make-selftests x86 slf clean'
alias jtx='make-clang make-selftests x86 nox'
alias jtxc='make-clang make-selftests x86 nox clean'
alias mta='make-selftests arm nox'
alias mtac='make-selftests arm nox clean'
alias jta='make-clang make-selftests arm nox'
alias jtac='make-clang make-selftests arm nox clean'

function run-selftests() {
    local RED='\033[1;31m' # Bold Red
    local GREEN='\e[0;32m' # Bold Green
    local BROWN='\e[1;33m'  # Bold Brown
    local BLUE='\e[1;34m'  # Bold Blue
    local cyan='\033[0;36m' # Cyan
    local NOF='\033[0m' # No Format
    local tests=( $(/bin/ls -1 $HOME/build/selftests) )
    local ret
    local i

    qemu=stable probe_modules

    for i in "${tests[@]}"; do
        local __stdout
        local __stderr

        printf "Running $i\n"

        if [[ $i == "max_guest_memory_test" && $(is-guest) ]]; then
            ret=4
        else
            catch __stdout __stderr $HOME/build/selftests/$i
            ret=$?
        fi

        if [[ $ret -eq 0 ]]; then
            printf "${GREEN}PASSED ${cyan}$i${NOF}\n"
        elif [[ $ret -eq 4 ]]; then
            printf "${BROWN}SKIPPED ${cyan}$i${NOF}\n"
        elif [[ $ret -eq 139 ]]; then
            printf "${RED}SEGFAULT ${cyan}$i${NOF}\n"
        else
            printf "${RED}FAILED ${cyan}$i${RED} : ret ='$ret'${NOF}\n"
            printf "$__stdout\n"
            printf "$__stderr\n"
        fi
        echo ""
    done
}
alias rt='run-selftests'

function run-gvisor {
    #!/bin/bash
    for i in $(seq 1 $1); do
	    ~/build/runc/runsc --platform=kvm --network=none do echo ok
    done
}
alias rung='run-gvisor 1000'

function run-nx-gvisor {
    local nr_cpus=$(get-nr-cpus)
    for i in $(seq 1 $nr_cpus); do
        run-gvisor 1000 > /dev/null 2>&1 &
    done

    for i in $(seq 1 100); do
        echo Y > /sys/module/kvm/parameters/nx_huge_pages
        sleep 1
        echo N > /sys/module/kvm/parameters/nx_huge_pages
        sleep 1
    done
}
alias runx='run-nx-gvisor'

function modprobe-kvm-loop {
    for i in $(seq 1 1000); do
	    psudo modprobe kvm_intel
        psudo modprobe kvm_amd
        psudo rmmod kvm_amd
        psudo rmmod kvm_intel

        psudo modprobe kvm_amd
        psudo modprobe kvm_intel
        psudo rmmod kvm_intel
        psudo rmmod kvm_amd
    done
}

function modprobe-kvm-all {
    local nr_cpus=$(get-nr-cpus)
    for i in $(seq 1 $nr_cpus); do
        modprobe-kvm-loop > /dev/null 2>&1 &
    done
}
alias mpka='modprobe-kvm-all'

function modprobe-kvm() {
    grep vendor_id "/proc/cpuinfo" | grep -q AuthenticAMD
    if [[ $? -eq 0 ]]; then
        kvm=kvm_amd
    else
        kvm=kvm_intel
    fi
    psudo modprobe $kvm $@
}
alias mpk='modprobe-kvm'
alias mpkk='psudo modprobe kvm'

function rmmod-kvm() {
    grep vendor_id "/proc/cpuinfo" | grep -q AuthenticAMD
    if [[ $? -eq 0 ]]; then
        kvm=kvm_amd
    else
        kvm=kvm_intel
    fi
    psudo rmmod $kvm $@
}
alias rmk='rmmod-kvm'
alias rmkk='rmmod-kvm kvm'

function make-kernel-package() {
    if [[ $# -lt 1 ]]; then
        printf "Must specify the target kernel name\n"
        return 1
    fi
    if [[ $# -gt 3 ]]; then
        printf "Maximum of 2 arguments supported: kernel (1), and no-install (2)\n"
        return 2
    fi
    if [[ ! -f REPORTING-BUGS ]]; then
        printf "REPORTING-BUGS file not detected\n"
        return 3
    fi
    if [[ $(id -u) -ne 0 ]]; then
        printf "Must be run as root\n"
        return 4
    fi
    if [[ $guest == "true" ]]; then
        stubify-guest
    fi

    rev="1"
    rm -f ../*$1+_${rev}_*.deb
    name="$(git show -s --pretty='tformat:%h')-$1"

    CONCURRENCY_LEVEL=$(get-nr-cpus) make-kpkg --initrd --append-to-version=-$name kernel_headers kernel_image --revision $rev

    if [[ $? -eq 0 && $# -lt 2 && $guest != "true" ]]; then
        dpkg -i ../*${name}*_${rev}_*.deb
    fi
}
alias mguest='guest=true make-kernel-package'

function make-host {
    if [[ $# -lt 1 ]]; then
        printf "Must specify the target kernel name\n"
        return 1
    fi

    if [[ -f /boot/grub/grub.cfg ]]; then
        make-kernel-package $@
        return 0
    fi

    local name="-$(git show -s --pretty='tformat:%h')-$1"
    local threads=$(get-nr-cpus)
    make LOCALVERSION=$name -j $threads && sudo make modules_install && sudo make install
    # if [[ $? -eq 0 && ]]; then
    #     local version=$(ls -1 /boot | egrep "vmlinuz-[.0-9]+(-rc[0-9])?$name" | sed -e "s/vmlinuz-//")
    #     if [[ -z $version ]]; then
    #         printf "Failed to locate new kernel $name\n"
    #         return 1
    #     fi
    #     sudo kernel-install add $version /boot/vmlinuz-$version /boot/initrd.img-$version
    # fi
}
alias mho='make-host'

function make-gbuild {
    if [[ $# -ne 2 ]]; then
        printf "Must specify the target arch and kernel name\n"
        return 1
    fi

    local name="-$(git show -s --pretty='tformat:%h')-$2"

    gbuild RELEASE=$name ARCH=$1
}
alias mg='make-gbuild x86_64'
alias mga='make-gbuild arm64'

function get-kernel {
    if [[ -f /boot/grub/grub.cfg ]]; then
        grep menuentry /boot/grub/grub.cfg | grep -v -e \( -e generic | grep "'Ubuntu, with Linux." | cut -f 2 -d "'"
    else
        ls -1 /boot/config-* | cut -f 3 -d "/" | cut -f 2- -d "-" | grep -v generic
    fi
}
alias gkp=get-kernel

function list-kernel {
    if [[ -f /boot/grub/grub.cfg ]]; then
        gkp | grep -o -e "Ubuntu, with Linux.*$1+\?" | cut -f 4 -d " "
    else
        gkp
    fi
}
alias lk='list-kernel'

function boot-kernel {
    if [[ $# -ne 1 ]]; then
        printf "Must specify the target kernel name\n"
        return 1
    fi
    if [[ -f /boot/grub/grub.cfg ]]; then
        local k=${1%%+}
        if [[ $(gkp | grep -c -e "Ubuntu, with Linux.*$k+\?") != "1" ]]; then
            gkp | grep -o -e "Ubuntu, with Linux.*$k+\?" | cut -f 2 -d "'"
            printf "Failed to find single entry for $1\n"
            return 1
        fi
        local entry=$(gkp | grep -o -e "Ubuntu, with Linux.*$k+\?" | cut -f 2 -d "'")
        if [[ -z $entry ]]; then
            printf "Failed to find entry=$entry\n"
            return 1
        fi
        printf "sudo grub-reboot 'Advanced options for Ubuntu>$entry'\n"
        sudo grub-reboot "Advanced options for Ubuntu>$entry"
        grep next_entry /boot/grub/grubenv
    else
        local version=$(lk | grep $1)
        if [[ -z $version ]]; then
            printf "Failed to find for '$1'\n"
            return 1
        elif [[ $(echo $version | wc -l) -gt 1 ]]; then
            printf "$version\nFound multiple entries for '$1'\n"
            return 1
        fi
        local entry=$(gkp | grep $version)
        if [[ -z $entry ]]; then
            printf "Failed to find for '$1'\n"
            return 1
        elif [[ $(echo $entry | wc -l) -gt 1 ]]; then
            printf "$entry\nFound multiple entries for '$1'\n"
            return 1
        fi
        sudo rm /boot/vmlinuz /boot/initrd.img
        sudo ln -s /boot/initrd.img-$version /boot/initrd.img
        sudo ln -s /boot/vmlinuz-$version /boot/vmlinuz
        sudo cp /boot/initrd.img-$version /boot/efi/EFI/Pop_OS-f3ed92a4-e46e-48f6-b760-8af78b9bc3be/initrd.img
        sudo cp /boot/vmlinuz-$version /boot/efi/EFI/Pop_OS-f3ed92a4-e46e-48f6-b760-8af78b9bc3be/vmlinuz.efi
        printf "Next Kernel: %s\n" $(readlink -e /boot/vmlinuz | cut -f 3 -d "/")
    fi
}
alias bk='boot-kernel'

function boot-windows {
    sudo grub-reboot "Windows Boot Manager (on /dev/sdb2)"
    grep next_entry /boot/grub/grubenv
}

function purge-kernel {
    if [[ $# -ne 1 ]]; then
        printf "Must specify the target kernel name\n"
        return 1
    fi
    if [[ -f /boot/grub/grub.cfg ]]; then
        local k=${1%%+}
        if [[ $(dpkg-query-size | grep -c -e "linux-image.*$k+\?") != "1" ]]; then
            dpkg-query-size | grep -e "linux-image.*$k+"
            printf "Failed to find single image for '$1'\n"
            return 1
        fi
        if [[ $(dpkg-query-size | grep -c -e "linux-headers.*$k+\?") != "1" ]]; then
            dpkg-query-size | grep -e "linux-headers.*$k+"
            printf "Failed to find single headers for '$1'\n"
            return 1
        fi
        local img=$(dpkg-query-size | grep -e "linux-image.*$k+\?"    | cut -f 2)
        local hdr=$(dpkg-query-size | grep -e "linux-headers.*$k+\?"  | cut -f 2)
        if [[ -z $img || -z $hdr ]]; then
            printf "Failed to find image=$img or headers=$hdr\n"
            return 1
        fi
        printf "sudo dpkg --purge $img $hdr\n"
        sudo dpkg --purge $img $hdr
    else
        local version=$(lk | grep $1)
        if [[ -z $version ]]; then
            printf "Failed to find entry for '$1'\n"
            return 1
        elif [[ $(echo $version | wc -l) -gt 1 ]]; then
            printf "$version\nFound multiple entries for '$1'\n"
            return 1
        fi
        sudo rm -f /boot/config-$version /boot/vmlinuz-$version /boot/initrd.img-$version /boot/System.map-$version
        sudo rm -rf /usr/lib/modules/$version
    fi
}
alias pk='purge-kernel'

# Make Custom kernel
function make-kernel() {
    if [[ $# -lt 1 ]]; then
        printf "Must specify the command\n"
        return 1
    fi
    if [[ $# -gt 2 ]]; then
        printf "Maximum of 2 arguments supported: command (1) and kernel (2)\n"
        return 2
    fi
    if [[ $# -eq 1 ]]; then
        if [[ $1 == "make" ]]; then
            printf "Use make-host (mh) for local build\n"
            return 3
        fi
        if [[ ! -f REPORTING-BUGS ]]; then
            printf "Local build without REPORTING-BUGS\n"
            return 3
        elif [[ ! -f .config ]]; then
            printf "Local build without local config\n"
            return 3
        elif [[ -f .git/info/sparse-checkout && ! -f .config ]]; then
            printf "Local build with sparse directory\n"
            return 3
        fi
        if [[ $1 == "htmldocs" ]]; then
            make htmldocs SPHINXOPTS=-v
        else
            make $1
        fi
        return 0
    fi

    if [[ ! -d ~/build/kernel/$2 ]]; then
        printf "Target build directory '~/build/kernel/$2' does not exist\n"
        return 4
    elif [[ ! -d .git/info || ! -d kernel ]]; then
        printf "Must run from a top-level Linux repository\n"
        return 4
    elif [[ ! -f .git/info/sparse-checkout ]]; then
        printf "Remote build without sparse directory\n"
        return 4
    elif [[ -f REPORTING-BUGS ]]; then
        printf "Remote build with probable host directory (detected REPORTING-BUGS)\n"
        return 4
    elif [[ -f .config ]]; then
        printf "Remote build with local config\n"
        return 4
    fi

    if [[ -d ~/build/kernel/$2/source ]]; then
        local prev=$(readlink -f ~/build/kernel/$2/source)
        local curr=$(readlink -f $PWD)
        if [[ $prev != $curr ]]; then
            printf "Mismatch in build's previous source dir\n"
            return 5
        fi
    fi

    local ret
    if [[ $1 == "make" ]]; then
        stubify-linux $2

        make O=~/build/kernel/$2 $EXTRAS -j$(get-nr-cpus)
        ret=$?
        if [[ $ret -eq 0 ]]; then
            rm -rf ~/build/kernel/$2/lib/modules/*
            make O=~/build/kernel/$2 INSTALL_MOD_PATH=~/build/kernel/$2 modules_install
        fi
    else
        if [[ $1 == "htmldocs" ]]; then
            printf "'htmldocs' isn't supported for sparse trees\n"
            return 6
        fi
        if [[ $1 != "defconfig" &&
              $1 != "oldconfig" &&
              $1 != "menuconfig" &&
              $1 != "localmodconfig" &&
              $1 != "clean" ]]; then
            printf "Unsupported command '$1'\n"
            return 7
        fi
        make O=~/build/kernel/$2 $1
        ret=$?
    fi

    return $ret
}

alias mc='make-kernel make'
alias mw='EXTRAS="W=1" make-kernel make'
alias mh='make headers_install'
alias msp='EXTRAS="C=1" make-kernel make'
alias md='make-kernel htmldocs'
alias ml='make-kernel localmodconfig'
alias mm='make-kernel menuconfig'
alias mo='make-kernel oldconfig'
alias me='make-kernel clean'

function make-kernel-clang() {
    make-clang make-kernel $@
}
alias jc='make-kernel-clang make'
alias jw='EXTRAS="W=1" make-kernel-clang make'
alias jcc='make-kernel-clang make c'
alias jsp='EXTRAS="C=1" make-kernel-clang'
alias jl='make-kernel-clang localmodconfig'
alias jm='make-kernel-clang menuconfig'
alias jo='make-kernel-clang oldconfig'
alias je='make-kernel-clang clean'

function make-kernel-arm() {
    make-arm make-kernel $@
}
alias amc='make-kernel-arm make cc_arm'
alias amd='make-kernel-arm defconfig cc_arm'
alias ame='make-kernel-arm clean cc_arm'
alias amm='make-kernel-arm menuconfig cc_arm'
alias amo='make-kernel-arm oldconfig cc_arm'

function make-kernel-mips() {
    make-mips make-kernel $@
}
alias mmc='make-kernel-mips make cc_mips64'
alias mmd='make-kernel-mips defconfig cc_mips64'
alias mme='make-kernel-mips clean cc_mips64'
alias mmm='make-kernel-mips menuconfig cc_mips64'
alias mmo='make-kernel-mips oldconfig cc_mips64'

function make-kernel-ppc() {
    make-ppc make-kernel $@
}
alias pmc='make-kernel-ppc make cc_ppc64'
alias pmd='make-kernel-ppc defconfig cc_ppc64'
alias pme='make-kernel-ppc clean cc_ppc64'
alias pmm='make-kernel-ppc menuconfig cc_ppc64'
alias pmo='make-kernel-ppc oldconfig cc_ppc64'

alias emc='make-kernel-ppc make cc_e500mc'
alias emd='make-kernel-ppc defconfig cc_e500mc'
alias eme='make-kernel-ppc clean cc_e500mc'
alias emm='make-kernel-ppc menuconfig cc_e500mc'
alias emo='make-kernel-ppc oldconfig cc_e500mc'

function make-kernel-riscv() {
    make-riscv make-kernel $@
}
alias rmc='make-kernel-riscv make cc_riscv'
alias rmd='make-kernel-riscv defconfig cc_riscv'
alias rme='make-kernel-riscv clean cc_riscv'
alias rmm='make-kernel-riscv menuconfig cc_riscv'
alias rmo='make-kernel-riscv oldconfig cc_riscv'

function make-kernel-s390() {
    make-s390 make-kernel $@
}
alias smc='make-kernel-s390 make cc_s390'
alias smd='make-kernel-s390 defconfig cc_s390'
alias smm='make-kernel-s390 menuconfig cc_s390'
alias smo='make-kernel-s390 oldconfig cc_s390'

alias xmc='make-kernel make cc_x86'
alias xmd='make-kernel defconfig cc_x86'
alias xmm='make-kernel menuconfig cc_x86'
alias xmo='make-kernel oldconfig cc_x86'

function make-kernel-branch() {
    local RED='\033[1;31m' # Bold Red
    local cyan='\033[0;36m' # Cyan
    local NOF='\033[0m' # No Format
    local arbitrary=1000
    local cflags=""
    local targets
    local branch
    local start
    local end
    local ret

    if [[ $# -lt 2 ]]; then
        printf "Must specify the target and command\n"
        return 1
    fi

    if [[ $# -gt 4 ]]; then
        printf "Usage: target (1), command (2), first commit (3), and branch (4)\n"
        return 1
    fi

    branch=$(git rev-parse --abbrev-ref HEAD)

    git rev-parse --verify autotest
    if [[ $? -ne 0 ]]; then
        git branch autotest
    fi

    if [[ $1 == "clang" ]]; then
        targets=("make-kernel $2 clang")
    elif [[ $1 == "vm" ]]; then
        targets=("make-kernel $2 vm")
    elif [[ $1 == "x86" ]]; then
        targets=("make-kernel $2 vm"
                 "make-kernel $2 pae"
                 "make-kernel $2 up"
                 "make-kernel $2 all"
                 "make-kernel-clang $2 clang"
                 "make-kernel-clang $2 clang_pae"
                 "make-kernel-clang $2 clang_all")
    elif [[ $1 == "gpu" ]]; then
        targets=("make-kernel $2 gpu"
                 "make-kernel-clang $2 clang_gpu")
    elif [[ $1 == "all" ]]; then
        targets=("make-kernel-arm $2 cc_arm"
                 "make-kernel-mips $2 cc_mips64"
                 "make-kernel-ppc $2 cc_ppc64"
                 "make-kernel-ppc $2 cc_e500mc"
                 "make-kernel-riscv $2 cc_riscv"
                 "make-kernel-s390 $2 cc_s390"
                 "make-kernel $2 cc_x86")
    elif [[ $1 == "kut"* ]]; then
        targets=("make clean"
                 "make -j$(get-nr-cpus)"
                 "make clean"
                 "make-clang make -j$(get-nr-cpus)")
        cflags="-Werror"
    elif [[ $1 == "tests-"* ]]; then
        local test_arch=${1#"tests-"}
        targets=("make-$test_arch make clean"
                 "make-$test_arch make -j$(get-nr-cpus)"
                 "make-clang make-$test_arch make clean"
                 "make-clang make-$test_arch make -j$(get-nr-cpus)")
        cflags="-Werror"
    else
        printf "Unknown target '$1'\n"
        return 1
    fi

    if [[ $# -lt 3 ]]; then
        start=$(git rev-parse HEAD)
    else
        start=$(git rev-parse --verify $3)
        if [[ $? -ne 0 ]]; then
            printf "Did not find $3 in git\n"
            return 1
        fi
    fi
    if [[ $# -lt 4 ]]; then
        end=$start
    elif [[ $(is-integer $4) ]]; then
        end=$start
        start=$(git rev-parse "$end~$(($4-1))")
    else
        end=$(git rev-parse --verify $4)
        if [[ $? -ne 0 ]]; then
            printf "Did not find $4 in git\n"
            return 1
        fi
    fi

    printf "start = $start, end = $end\n"

    local commits=$(glo $end | head -$arbitrary | grep -B $arbitrary $start | tac | cut -f 1 -d ' ')
    if [[ $? -ne 0 ]]; then
        printf "Did not find $start in git log\n"
        return 1
    fi
    commits=(${commits//:/ })

    gg autotest
    git reset --hard $end

    for i in "${commits[@]}"; do
        local commit=$(gwo $i)
        git reset --hard $i

        ret=$?
        if [[ $ret -ne 0 ]]; then
            printf "\n$REDFailed to reset to commit ${cyan}$commit$NC\n\n"
            break
        fi

        for target in "${targets[@]}"; do
            printf "\n\n$target\n\n"
            EXTRA_CFLAGS="$cflags" $target

            ret=$?
            if [[ $ret -ne 0 ]]; then
                printf "\n${RED}Commit ${cyan}$commit${RED} failed to build with '$target'.${NOF}\n\n"
                break
            fi
        done
        if [[ $ret -ne 0 ]]; then
            break
        fi
    done

    gg $branch
}
alias mkc='make-kernel-branch clang make'
alias mkcc='make-kernel-branch clang make'
alias mkv='make-kernel-branch vm make'
alias mkvc='make-kernel-branch vm make clean'
alias mkx='make-kernel-branch x86 make'
alias mkxc='make-kernel-branch x86 clean'
alias mkg='make-kernel-branch gpu make'
alias mkgc='make-kernel-branch gpu clean'
alias mka='make-kernel-branch all make'
alias mkac='make-kernel-branch all clean'
alias mkt='make-kernel-branch tests-x86 ign'
alias mat='make-kernel-branch tests-arm ign'
alias mrt='make-kernel-branch tests-riscv ign'
alias mst='make-kernel-branch tests-s390 ign'
alias mut='make-kernel-branch kut ign'

alias mkb='TARGET=bzImage make-kernel make'

function clean-modules() {
    local dirs=( $(/bin/ls -1 $HOME/build/kernel) )
    local i

    for i in "${dirs[@]}"; do
        rm -rf "$HOME/build/kernel/$i/lib/modules"
    done
}
alias cmod=clean-modules

# time kernel
function time-kernel() {
    if [[ $# -ne 1 ]]; then
        printf "Must specify the target kernel name\n"
        return 1
    fi
    make O=~/build/kernel/$1 clean
    sleep .25
    ftime -o ~/build/kernel/$1/tk_time.log make -j$(get-nr-cpus) O=~/build/kernel/$1 > ~/build/kernel/$1/tk_build.log 2>&1
}
alias tik='time-kernel'

function system-info() {
    printf "IP Address:\t       $(ipa)\n"
    printf "Kernel:\t\t       $(uname -r)\n"
}
alias ii='system-info'

function system-info-verbose() {
    printf "IP Address:\t       $(ipa)\n"
    printf "Kernel:\t\t       $(uname -r)\n"
    printf "Date:\t\t       $(date)\n"
    printf "Uptime:\t\t      $(uptime)\n"
    lscpu | grep -v Architecture | grep -v "Byte Order" | grep -v op-mode | grep -v BogoMIPS | grep -v Virtualization | grep -v Flags | grep -v On-line
}
alias siv='system-info-verbose'

function make-qemu() {
    make -j$(get-nr-cpus)
}
alias mq='make-qemu'

function make-ovmf() {
    build -n $(get-nr-cpus) -a X64 -a IA32 -t GCC5 -p OvmfPkg/OvmfPkgIa32X64.dsc
}
alias maf=make-ovmf

function prep-kut32() {
    # ./configure --erratatxt="" --disable-pretty-print-stacks --arch=i386 --processor=i386
    qemu=stable probe_modules
    cd ~/go/src/kernel.org/kut-32
    return 0
}

function prep-kut() {
    # ./configure --erratatxt="" --disable-pretty-print-stacks
    qemu=stable probe_modules
    cd ~/go/src/kernel.org/kvm-unit-tests
    return 0
}

function prep-kut-efi() {
    # ./configure --erratatxt="" --disable-pretty-print-stacks --enable-efi
    qemu=stable probe_modules
    cd ~/go/src/kernel.org/kut-efi
    return 0
}

alias rkt='prep-kut && QEMU=~/build/qemu/stable EFI_UEFI=~/build/ovmf/OVMF.fd'
alias rku='rkt ./run_tests.sh -v'
alias rkt32='prep-kut32 && QEMU=~/build/qemu/stable'
alias rku32='rkt32 ./run_tests.sh -v'
alias rkte='prep-kut-efi && QEMU=~/build/qemu/stable'
alias rkue='rkte ./run_tests.sh -v'
alias rkv='rkt TESTNAME=vmx TIMEOUT=90s ACCEL= ./x86/run x86/vmx.flat -smp 1 -cpu host,+vmx -append'
alias rkc='rkt TESTNAME=vmx_controls TIMEOUT=90s ACCEL= ./x86/run x86/vmx.flat -smp 1 -cpu host,+vmx -m 2560 -append vmx_controls_test'

function really-run-all-tests() {
    run-selftests

    cd ~/go/src/kernel.org/kvm-unit-tests
    QEMU=~/build/qemu/stable EFI_UEFI=~/build/ovmf/OVMF.fd ./run_tests.sh -v
    QEMU=~/build/qemu/stable EFI_UEFI=~/build/ovmf/OVMF.fd ./run_tests.sh -v -g nodefault

    cd ~/go/src/kernel.org/kut-efi
    QEMU=~/build/qemu/stable EFI_UEFI=~/build/ovmf/OVMF.fd ./run_tests.sh -v
    QEMU=~/build/qemu/stable EFI_UEFI=~/build/ovmf/OVMF.fd ./run_tests.sh -v -g nodefault

    cd ~/go/src/kernel.org/kut-32
    QEMU=~/build/qemu/stable EFI_UEFI=~/build/ovmf/OVMF.fd ./run_tests.sh -v
    QEMU=~/build/qemu/stable EFI_UEFI=~/build/ovmf/OVMF.fd ./run_tests.sh -v -g nodefault
}
function run-all-tests() {
    local paging_param

    rmmod-kvm kvm
    qemu=stable probe_modules
    really-run-all-tests

    rmmod-kvm
    grep vendor_id "/proc/cpuinfo" | grep -q AuthenticAMD
    if [[ $? -eq 0 ]]; then
        psudo modprobe kvm_amd npt=0
    else
        psudo modprobe kvm_intel ept=0
    fi
    really-run-all-tests
}
alias ra='run-all-tests'

function run-memslot-test() {
    if [[ $(id -u) -ne 0 ]]; then
        printf "Must be run as root\n"
        return 1
    fi
    if [[ $# -ne 0 && $# -ne 2 ]]; then
        printf "Usage for memslot test: 'rms [threads] [mem in gb]'\n"
        return 2
    fi
    if [[ ! -f /sys/bus/pci/devices/0000:00:01.0/rom ]]; then
        printf "No ROM at /sys/bus/pci/devices/0000:00:01.0, try vga=1\n"
        return 3
    fi

    local nr_threads=8
    local nr_gigabytes=1
    if [[ $# -eq 2 ]]; then
        nr_threads=$1
        nr_gigabytes=$2
    fi

    $SETTINGS/bin/memslot_test -c $nr_threads -m $nr_gigabytes -e $SETTINGS/lib/memslot_test/rom.sh
}
alias rms='run-memslot-test'

# -----------------------------------------------------------------------------
# KVM tracing
# -----------------------------------------------------------------------------
alias kt='kvm_trace'
alias lt='less /sys/kernel/debug/tracing/trace'
alias ct='echo 0 > /sys/kernel/debug/tracing/trace'
alias ton='echo 1 > /sys/kernel/debug/tracing/tracing_on'
alias toff='echo 0 > /sys/kernel/debug/tracing/tracing_on'

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
