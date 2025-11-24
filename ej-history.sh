HISTCONTROL=ignoredups:ignorespace # no dups in history
shopt -s histappend # append to history, not overwrite
HISTSIZE=-1; HISTFILESIZE=-1 # unlimited history
HISTTIMEFORMAT='%F--%H:%M ' # history format as `76216  2025-11-24--12:58 history`
shopt -s checkwinsize # check window size after each cmd
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)" # friendly less

