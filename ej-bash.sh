[ -z "$PS1" ] && return # return if not interactive
function rel () { . ~/.bashrc; echo 'Config reloaded!'; }

## history
HISTCONTROL=ignoredups:ignorespace # no dups in history
shopt -s histappend # append to history, not overwrite
HISTSIZE=-1; HISTFILESIZE=-1 # unlimited history
shopt -s checkwinsize # check window size after each cmd
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)" # friendly less
alias hi="history"
alias hig='history | grep'

## prompt
# http://stackoverflow.com/questions/4133904/ps1-line-with-git-current-branch-and-colors
# https://askubuntu.com/questions/67283/is-it-possible-to-make-writing-to-bash-history-immediate
# https://stackoverflow.com/questions/34484582/how-to-check-which-branch-you-are-on-with-mercurial
hg_ps1() { hg identify -b 2>/dev/null; }
set_prompt() {
    if [ "`git rev-parse --is-inside-work-tree 2>/dev/null`" = "true" ]; then
        PS1="\n$(__git_ps1 ' (%s)')\n"
    else
        PS1="\n ($(hg_ps1))\n"
    fi
    PS1+="\u@\h:\w \\$ "
}
shopt -s histappend
PROMPT_COMMAND='history -a; history -c; history -r; set_prompt'
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac
if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	color_prompt=yes
    else
	color_prompt=
    fi
fi

## ls color
export LS_COLORS="no=00:fi=00:di=00;36:ln=00;36:pi=40;33:so=00;35:bd=40;33;01:ex=00;35"

## completions
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

## apt aliases
alias ase="apt-cache search"
alias sai="sudo apt install -y"
alias sau="sudo apt-get update -y"
alias sar="sudo apt-get remove"

## ls and dirs
alias l="ls -agGp --color --time-style=long-iso"
alias rm='rm -i'
alias mk='mkdir'
alias fd='fdfind'

## git
alias gde='git diff | ema'
alias grh='git diff > ~/trash/backup_diff.diff && git reset --hard'
alias gst='git status -s' 
alias gull='git pull'
alias gush='git push'
alias sth="git stash"
alias gmlb='git merge @{-1}'
function gl () { git log -n $1 | cat; }

## emacs
alias ema='cat > /tmp/fi.diff && emacsclient -e "(progn (other-window 1) (g \"/tmp/fi.diff\"))"'
alias E="SUDO_EDITOR=\"emacsclient\" sudo -e"
export SVN_EDITOR=emacsclient
export EDITOR='emacsclient'

## some functions
klr () {  kill -9 `ps -e | grep $@ | tr -s ' ' | sed -n 1p | awk '{ print $1; }'`; }
fix_caps() { setxkbmap -option ctrl:nocaps; }
addr() { ifconfig | grep -Po '(?<=inet )[\d\.]+'; }
fh() { free -h; }
restart-wifi() { nmcli radio wifi off && nmcli radio wifi on; }

## etc
alias pya='ping ya.ru'
alias count_group='sort | uniq -c | sort -n'
alias group_count='sort | uniq -c | sort -n'
alias sz='du -sch'
alias pin='pip install'
