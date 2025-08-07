SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. $SCRIPT_DIR/ej-env.sh
[ -z "$PS1" ] && return # return if not interactive
function rel () { . "$HOME/.bashrc"; echo 'Config reloaded!'; }
function load_script() { . $SCRIPT_DIR/$1; }

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
function set_prompt() { PS1="\n$(date +%H:%M); $(__git_ps1)$(hg_ps1)\n\u@$HOSTNAME_PRETTY:\w \\$ "; }
PROMPT_COMMAND='history -a; history -c; history -r; set_prompt'
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then debian_chroot=$(cat /etc/debian_chroot); fi
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac
if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then color_prompt=yes; else color_prompt=; fi
fi

## env vars
export LS_COLORS="no=00:fi=00:di=00;36:ln=00;36:pi=40;33:so=00;35:bd=40;33;01:ex=00;35"
export RIPGREP_CONFIG_PATH="$SCRIPT_DIR/.ripgreprc"

## modules
load_script ej-functions-aliases.sh
load_script ej-git.sh
load_script ej-python.sh
load_if_exist $LOCAL_SCRIPT_PATH

## completions
if ! shopt -oq posix; then load_if_exist /etc/bash_completion; fi


## paths
if test -d "$HOME/.local/bin"; then export PATH="$HOME/.local/bin:$PATH"; fi
source "$HOME/.venv/bin/activate"
