SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
MAIN_SCRIPT_PATH=$SCRIPT_DIR/ej-bash.sh
LOCAL_SCRIPT_PATH=$SCRIPT_DIR/ej-bash-local.sh

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
