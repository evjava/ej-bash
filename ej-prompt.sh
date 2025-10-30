## prompt
# http://stackoverflow.com/questions/4133904/ps1-line-with-git-current-branch-and-colors
# https://askubuntu.com/questions/67283/is-it-possible-to-make-writing-to-bash-history-immediate
# https://stackoverflow.com/questions/34484582/how-to-check-which-branch-you-are-on-with-mercurial
function get-hostname-pretty() {
    local res=$(hostnamectl --pretty);
    # set pretty hostname with `sudo hostnamectl set-hostname --pretty "<pretty-hostname>"`
    if [[ -z $res ]]; then
        res=$(hostname)
    fi
    echo $res
}
HOSTNAME_PRETTY=$(get-hostname-pretty)
function hg-ps1() { hg identify -b 2>/dev/null; }
function set-prompt() { PS1="\n$(date +%H:%M); $(__git_ps1)$(hg-ps1)\n\u@$HOSTNAME_PRETTY:\w \\$ "; }
function set-minimal-prompt() { PS1="$ "; }
PROMPT_COMMAND='history -a; history -c; history -r; set-prompt'
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then debian_chroot=$(cat /etc/debian_chroot); fi
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac
if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then color_prompt=yes; else color_prompt=; fi
fi
