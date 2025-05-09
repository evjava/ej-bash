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
function get_hostname_pretty() {
    local res=$(hostnamectl --pretty);
    # set pretty hostname with `sudo hostnamectl set-hostname --pretty "<pretty-hostname>"`
    if [[ -z $res ]]; then
        res=$(hostname)
    fi
    echo $res
}
HOSTNAME_PRETTY=$(get_hostname_pretty)
function hg_ps1() { hg identify -b 2>/dev/null; }
function set_prompt() {
    dt=`date +%H:%M`
    PS1="\n$dt; $(__git_ps1)$(hg_ps1)\n\u@$HOSTNAME_PRETTY:\w \\$ "
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
    module="${1//-/_}"
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

function dot-png() {
    local dot_path="$1"
    local extra="$2"
    local png_path="${dot_path%.dot}.png"
    local tmp_png_path="/tmp/$(basename "${png_path}")"

    if [[ ! -f "$dot_path" ]]; then
        echo "DOT file '$dot_path' not found."
        return 1
    fi
    if [ "$extra" != "--cycle" ]; then
        dot -Tpng "$dot_path" -o "$tmp_png_path"
        cp "$tmp_png_path" "$png_path"
        echo "Generated $png_path"
        return 0
    fi
    echo "Running in cycle-mode"
    last_modified_dot=""
    while true; do
        sleep 1
        current_modified_dot=$(stat -c %Y "$dot_path")
        if [[ "$current_modified_dot" != "$last_modified_dot" ]]; then
            echo "File changed at $(date), regenerating PNG: $png_path"
            dot -Tpng "$dot_path" -o "$tmp_png_path"
            cp "$tmp_png_path" "$png_path"
            last_modified_dot=$current_modified_dot
        else
            echo "No changes detected."
        fi
    done
}

function wait-until-changed () {
    cmd="$1"
    echo "cmd: $cmd"
    val=$(eval "$cmd")
    echo "Value: $val"
    while true; do
        sleep 3
        val_upd=$(eval "$cmd")
        if [ "$val" != "$val_upd" ]; then
            echo "Value changed: $val -> $val_upd"
            return 0
        fi
        echo "Value still $val"
    done
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
alias fd='fdfind --follow'

## git
alias gd='git diff'
alias gds='git diff --staged'
alias gde='git diff | ema'
alias grh='git diff > ~/trash/backup_diff.diff && git reset --hard'
alias gst='git status -s'
alias gsti='gst --ignore-submodules'
alias gull='git pull'
alias gush='git push'
alias sth='git stash'
alias pop='git stash pop'
alias gmlb='git merge @{-1} --no-edit'
alias grlb='git rebase @{-1}'
alias glo='git log --oneline -n'
alias glod='git log -n'
alias glp="git log --date=format:'%Y-%m-%d' -60 --pretty='%h %ad %ae %s' -n"
alias gb='git branch'
alias gbr='git branch --remote'
alias gcb='git co -b'
alias gc-='git co -'
alias grh1='git reset HEAD~1'
alias grh2='git reset HEAD~2'
alias grh3='git reset HEAD~3'
function gl () {
    cnt="$1"
    branch="$2"
    if [ -z "$cnt" ]; then
        cnt=10
    fi
    git log --pretty=format:"%ad %C(auto)%h <%ce> %s" --date="format:%Y-%m-%d--%H-%M" -n "$cnt" $branch
}

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
alias fdn='fd --no-ignore-vcs --hidden'
alias jn='jupyter notebook'
alias flake8_files='flake8 --format="%(path)s" | group_count'
alias flake8_keys='flake8 . | grep -oP "(?<=: )[A-Z]+\d+" | group_count'
alias hi="history"
alias m='make'
alias rg='/usr/bin/rg --max-columns=500 --no-heading'
alias rgn='/usr/bin/rg --max-columns=500 --no-heading --no-ignore-vcs --hidden'
alias jsonp='python -m json.tool --no-ensure-ascii'
alias doc='docker compose'
alias summate='paste -sd+ | bc'
alias dps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"'
function docker-stop-rm() { cid=$1; docker stop $cid; docker rm $cid; }
alias reversed='tac'
alias bat='batcat --theme="Monokai Extended Light" --style="header,grid"'
alias c1='piep "p.split()[0]"'
alias c2='piep "p.split()[1]"'
function port() { port=$1; sudo netstat --all --program | grep ":$port"; }

## paths
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
export RIPGREP_CONFIG_PATH="$SCRIPT_DIR/.ripgreprc"

## loading config with paths
load_if_exist $LOCAL_SCRIPT_PATH
