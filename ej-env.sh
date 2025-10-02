SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
MAIN_SCRIPT_PATH=$SCRIPT_DIR/ej-bash.sh
LOCAL_SCRIPT_PATH=$SCRIPT_DIR/ej-bash-local.sh

export LS_COLORS="no=00:fi=00:di=00;36:ln=00;36:pi=40;33:so=00;35:bd=40;33;01:ex=00;35"


function ask_yes_no() {
    msg=$1
    force_arg=$2
    if [[ $force_arg == "--force" ]]; then
        return 0  # "yes" resposne
    fi

    read -p "$msg (yes/no (default)): " answer
    if [[ $answer == "yes" ]]; then
        return 0  # "yes" response
    else
        return 1  # "no" response
    fi
}
