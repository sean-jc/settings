export SETTINGS=$HOME/go/src/github.com/sean-jc/settings

setopt PROMPT_SUBST

# Append to the history file rather than overwriting it
setopt APPEND_HISTORY
# Share history across all open terminal windows immediately
# setopt SHARE_HISTORY

HISTFILE=~/.zsh_history
# How many commands to keep in active memory
HISTSIZE=10000
# How many commands to save to the persistent file
SAVEHIST=10000
# history -r (because of course it's different)
fc -R

# Bind Home/End to beginning/end of line
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
# Bind Cmd+Home escape sequence to jump to the beginning of the file/command buffer
bindkey "\e[1;8H" beginning-of-buffer-or-history
bindkey "\e[1;8F" end-of-buffer-or-history

autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z} r:|=*' 'm:{a-zA-Z}={A-Za-z} l:|=* r:|=*'

setopt AUTO_MENU
setopt ALWAYS_TO_END

. $SETTINGS/shell/main

PROMPT="%F{yellow}%*${HOSTDISPLAY}%(?.%F{green} ✔ .%F{red} ✘ )%B%(!.%F{red}.%F{cyan})%~ %b%(!.%F{red}#.%F{cyan}\$) %f"
