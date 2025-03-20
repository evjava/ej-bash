SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. $SCRIPT_DIR/ej-env.sh
[ -z "$PS1" ] && return # return if not interactive
function rel () { . "$HOME/.bashrc"; echo 'Config reloaded!'; }

## history
HISTCONTROL=ignoredups:ignorespace # no dups in history
shopt -s histappend # append to history, not overwrite
HISTSIZE=-1; HISTFILESIZE=-1 # unlimited history
shopt -s checkwinsize # check window size after each cmd
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)" # friendly less

## prompt
# http://stackoverflow.com/questions/4133904/ps1-line-with-git-current-branch-and-colors
# https://askubuntu.com/questions/67283/is-it-possible-to-make-writing-to-bash-history-immediate
# https://stackoverflow.com/questions/34484582/how-to-check-which-branch-you-are-on-with-mercurial
function hg_ps1() { hg identify -b 2>/dev/null; }
function set_prompt() {
    dt=`date +%H:%M`
    PS1="\n$dt; $(__git_ps1)$(hg_ps1)\n\u@\h:\w \\$ "
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
if test -f /etc/bash_completion && ! shopt -oq posix; then
    . /etc/bash_completion
fi

## some functions
function klr () {  kill -9 `ps -e | grep $@ | tr -s ' ' | sed -n 1p | awk '{ print $1; }'`; }
function fix_caps() { setxkbmap -option ctrl:nocaps; }
function addr() { ifconfig | grep -Po '(?<=inet )[\d\.]+'; }
function fh() { free -h; }
function restart-wifi() { nmcli radio wifi off && nmcli radio wifi on; }
function size() { du -sc $1 | awk '$2 == "total" {total += $1} END {print total}'; }
function sizes() {
    dir=$1
    if [ -z "$dir" ]; then
        dir='.';
    fi
    du -d 1 -h -a "$dir" 2>/dev/null | sort -h
}
function load_if_exist() {
    script_path=$1
    if test -f $script_path; then
        . $script_path
    else
        echo 'Not found:' $script_path
    fi
}
function pipcd() {
    module=$1
    init_path_cmd="import $module; print(${module}.__file__)"
    init_path=$(python -c "$init_path_cmd")
    if [ ! -z $init_path ]; then
        cd $(dirname $init_path)
    fi
}

function hig() {
    if [[ $# == 0 ]]; then
        echo "Usage: hig <pattern1> [<pattern2> ...]" >&2
        return 1
    fi
    local cmd="history"
    local cnt="10"
    while (( "$#" )); do
        case $1 in
            -n)
                shift;
                cnt="$1"
                ;;
            *)
                pattern=$(echo "$1" | sed 's/\W/\\&/g')
                cmd="$cmd | grep '$pattern'"
                ;;
        esac
        shift
    done
    cmd="$cmd | awk '!seen[substr(\$0, index(\$0, \$2))]++' | tail -n $cnt"
    eval "$cmd"
}
function logout () {
    xfce4-session-logout --logout
}

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
alias sth='git stash'
alias pop='git stash pop'
alias gmlb='git merge @{-1}'
alias grlb='git rebase @{-1}'
alias gl='git log -n'
alias glo='git log --oneline -n'
alias glod='git log --pretty=format:"%ad %C(auto)%h <%ce> %s" --date="format:%Y-%m-%d--%H-%M" -n'
alias glp="git log --date=format:'%Y-%m-%d' -60 --pretty='%h %ad %ae %s' -n"
alias gb='git branch'
alias gcb='git co -b'

## emacs
alias ema='cat > /tmp/fi.diff && emacsclient -e "(progn (other-window 1) (find-file-read-only \"/tmp/fi.diff\"))"'
alias E="SUDO_EDITOR=\"emacsclient\" sudo -e"
export SVN_EDITOR=emacsclient
export EDITOR='emacsclient'

## etc
alias pya='ping ya.ru'
alias count_group='sort | uniq -c | sort -n'
alias group_count='sort | uniq -c | sort -n'
alias sz='du -sch'
alias pin='pip install'
alias freh='free -h'
alias wcl='wc -l'
alias fdn='fd --no-ignore-vcs'
alias jn='jupyter notebook'
alias flake8_files='flake8 --format="%(path)s" | group_count'
alias flake8_keys='flake8 . | grep -oP "(?<=: )[A-Z]+\d+" | group_count'
alias hi="history"
alias m='make'
alias rg='/usr/bin/rg --max-columns=500 --no-heading'
alias rgn='/usr/bin/rg --max-columns=500 --no-heading --no-ignore-vcs'
alias jsonp='python -m json.tool --no-ensure-ascii'
alias doc='docker compose'
alias c1='piep "p.split()[0]"'
alias summate='paste -sd+ | bc'
alias dps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}"'
alias reversed='tac'
alias bat='batcat --theme="Monokai Extended Light" --style="header,grid"'

## paths
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
export RIPGREP_CONFIG_PATH="$SCRIPT_DIR/.ripgreprc"

## paths
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

## loading config with paths
load_if_exist $local_script_path

## loading tools depending on paths
eval "$(thefuck --alias)"
