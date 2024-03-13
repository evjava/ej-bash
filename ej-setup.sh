. ej-bash.sh
echo ". ~/ej-bash/ej-bash.sh" > ~/.bashrc

if [ ! -f ~/ej-bash/ej-bash-private.sh ]; then
    touch ~/ej-bash/ej-bash-private.sh
fi

setup_arg=$1

function ask_yes_no() {
    if [[ $setup_arg == "yes" ]]; then
        return 0
    fi

    read -p "$1 (yes/no (default)): " answer
    if [[ $answer == "yes" ]]; then
        return 0  # "yes" response
    else
        return 1  # "no" response
    fi
}

. ej-bash.sh

echo 'Installing programs...'
function sai-if-not () {
    program=$1;
    if [[ -z $(dpkg -s "$program")  ]]; then
        sudo apt -y install $program
    else
        echo '    ' Program '<' $program '>' already installed!
    fi
}
function snap-if-not () {
    program=$1;
    if [[ -z $(snap list "$program")  ]]; then
        sudo snap install $program
    else
        echo '    ' Program '<' $program '>' already installed!
    fi
}

# todo fix, use it
function is-installed () {
    program=$1;
    if [[ -z $(snap list "$program" 2>/dev/null) && -z $(dpkg -s "$program" 2>/dev/null) ]]; then
        return 0
    else
        return 1
    fi
}

if ask_yes_no 'Install some important dependencies?'; then
    sai-if-not fd-find
    sai-if-not htop
    sai-if-not ripgrep
    sai-if-not net-tools
    # snap-if-not chromium
    # sai-if-not syncthing
    # sai-if-not wmctrl
    # sai-if-not xdotool
    # sai-if-not ffmpeg
fi

echo 'Installing links...'
function link-if-no () {
    from=$1
    to=$2

    if [ ! -f $to ]; then
        echo '    Running: $' sudo ln -s $from $to 
        sudo ln -s $from $to 
    else
        echo '    ' link '<' $to '>' already exists!
    fi
}
function snap-link-if-no () {
    from=$1
    to=$2

    if [ -z $(which $to) ]; then
        echo 'Running: $' sudo snap alias $1 $2
        sudo snap alias $1 $2
    else
        echo '    ' link '<' $to '>' already exists!
    fi
}
if ask_yes_no 'Install links?'; then
    link-if-no /usr/bin/xfce4-keyboard-settings /usr/bin/kbs
    link-if-no /usr/bin/firefox                 /usr/bin/ffox
    snap-link-if-no chromium chr
fi

if ask_yes_no 'Update xdg-user-dirs?'; then
    echo 'Fixing xfce user dirs...'
    xdg-user-dirs-update --set DESKTOP     "$HOME/desktop"
    xdg-user-dirs-update --set DOWNLOAD    "$HOME/edownloads"
    xdg-user-dirs-update --set TEMPLATES   "$HOME/templates"
    xdg-user-dirs-update --set PUBLICSHARE "$HOME/public"
    xdg-user-dirs-update --set DOCUMENTS   "$HOME/docs"
    xdg-user-dirs-update --set MUSIC       "$HOME/music"
    xdg-user-dirs-update --set PICTURES    "$HOME/images"
    xdg-user-dirs-update --set VIDEOS      "$HOME/videos"
fi

if ask_yes_no 'Update ~/.gitconfig?'; then
    echo 'Updating ~/.gitconfig...'
    git_conf () { git config --global $1 $2; }
    git_conf core.editor "emacsclient"
    git_conf alias.st "status"
    git_conf alias.ci "commit"
    git_conf alias.co "checkout"
    git_conf alias.br "branch"
    # git_conf alias.hist 'log --pretty=format:"%h %ad | %s%d [%an]" --graph --date=short'
fi

if ask_yes_no 'Fix ctrl:nocaps?'; then
    echo 'Fixing ctrl:nocaps...'
    if [ -z $(cat /etc/default/keyboard | grep 'XKBOPTIONS' | grep 'ctrl:nocaps') ]; then
        echo '    Updating...'
        sudo sed -i 's/XKBOPTIONS="[^"]*"/XKBOPTIONS="ctrl:nocaps"/' /etc/default/keyboard
        echo '    Done!'
    else
        echo '    Already installed!'
    fi
fi

if ask_yes_no 'Fix keys?'; then
    . ej-setup-keys.sh
fi

echo 'Done!'
