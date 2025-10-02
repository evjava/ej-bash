SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
[ -z "$PS1" ] && return # return if not interactive
function load_script() { . $SCRIPT_DIR/$1; }

load_script ej-env.sh
load_script ej-history.sh
load_script ej-prompt.sh
load_script ej-functions-aliases.sh
load_script ej-git.sh
load_script ej-python.sh
load_if_exist $LOCAL_SCRIPT_PATH

## completions
if ! shopt -oq posix; then load_if_exist /etc/bash_completion; fi

## paths
export RIPGREP_CONFIG_PATH="$SCRIPT_DIR/.ripgreprc"
if test -d "$HOME/.local/bin"; then export PATH="$HOME/.local/bin:$PATH"; fi
source "$HOME/.venv/bin/activate"
