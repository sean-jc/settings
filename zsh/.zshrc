export SETTINGS=$HOME/go/src/github.com/sean-jc/settings

setopt PROMPT_SUBST

# Append to the history file rather than overwriting it
setopt APPEND_HISTORY
# Share history across all open terminal windows immediately
setopt SHARE_HISTORY

HISTFILE=~/.zsh_history
# How many commands to keep in active memory
HISTSIZE=10000
# How many commands to save to the persistent file
SAVEHIST=10000
# history -r (because of course it's different)
fc -R

. $SETTINGS/shell/main

PROMPT="%F{yellow}%*${HOSTDISPLAY}%(?.%F{green} ✔ .%F{red} ✘ )%B%(!.%F{red}.%F{cyan})%~ %b%(!.%F{red}#.%F{cyan}\$) %f"
