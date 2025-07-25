. ej-bash.sh
. ej-env.sh
echo ". $SCRIPT_DIR/ej-bash.sh" > ~/.bashrc
if ! test -f $LOCAL_SCRIPT_PATH; then touch $LOCAL_SCRIPT_PATH; fi

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
function setup-dependencies () {
    echo 'Installing programs...'
    sai-if-not fd-find
    sai-if-not htop
    sai-if-not ripgrep
    sai-if-not net-tools
}    

function setup-links-1 () {
    echo 'Installing links-1...'
    ln -s "$SCRIPT_DIR/.ripgreprc" "$HOME/.ripgreprc"
}

function setup-links-2 () {
    link-if-no /usr/bin/xfce4-keyboard-settings /usr/bin/kbs
    link-if-no /usr/bin/firefox                 /usr/bin/ffox
    snap-link-if-no chromium chr
}

function update-xdg () {
    echo 'Fixing xfce user dirs...'
    xdg-user-dirs-update --set DESKTOP     "$HOME/desktop"
    xdg-user-dirs-update --set DOWNLOAD    "$HOME/edownloads"
    xdg-user-dirs-update --set TEMPLATES   "$HOME/templates"
    xdg-user-dirs-update --set PUBLICSHARE "$HOME/public"
    xdg-user-dirs-update --set DOCUMENTS   "$HOME/docs"
    xdg-user-dirs-update --set MUSIC       "$HOME/music"
    xdg-user-dirs-update --set PICTURES    "$HOME/images"
    xdg-user-dirs-update --set VIDEOS      "$HOME/videos"
}

function setup-git () {
    echo 'Updating ~/.gitconfig...'
    git_conf () { git config --global $1 "$2"; }
    git_conf core.editor "emacsclient"
    git_conf alias.st "status"
    git_conf alias.ci "commit"
    git_conf alias.co "checkout"
    git_conf alias.br "branch"
    git_conf credential.helper "cache --timeout=36000"
    # git_conf alias.hist 'log --pretty=format:"%h %ad | %s%d [%an]" --graph --date=short'
}

function setup-nocaps () {
    echo 'Fixing ctrl:nocaps...'
    if [ -z $(cat /etc/default/keyboard | grep 'XKBOPTIONS' | grep 'ctrl:nocaps') ]; then
        echo '    Updating...'
        sudo sed -i 's/XKBOPTIONS="[^"]*"/XKBOPTIONS="ctrl:nocaps"/' /etc/default/keyboard
        echo '    Done!'
    else
        echo '    Already installed!'
    fi
}

function setup-keys () {
    . ej-setup-keys.sh
}
