## install
sai xubuntu-desktop
sai xdotool
sai fd-find
sai wmctrl

## git
git_conf () { git config --global $1 $2; }
git_conf core.editor "emacsclient"
git_conf autocrlf "input"
git_conf alias.st "status"
git_conf alias.ci "commit"
git_conf alias.co "checkout"
git_conf alias.br "branch"
git_conf alias.hist "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short"
