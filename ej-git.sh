## aliases
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
alias glod='git log -n'
alias glp="git log --date=format:'%Y-%m-%d' -60 --pretty='%h %ad %ae %s' -n"
alias gb='git branch'
alias gbr='git branch --remote'
alias gcb='git co -b'
alias gc-='git co -'
alias grh1='git reset HEAD~1'
alias grh2='git reset HEAD~2'
alias grh3='git reset HEAD~3'
alias grh4='git reset HEAD~4'
alias gdh1='git diff HEAD~1'

alias git-authors='fd -e py -x git blame --line-porcelain | grep -oP "(?<=author-mail <).*(?=>)" | group_count'

function gl() {
    cnt="$1"
    branch="$2"
    if [ -z "$cnt" ]; then
        cnt=10
    fi

    if [ -z "$branch"]; then
        branch=$(git branch --show-current)
    fi

    last_unpushed=$(git cherry origin/$branch $branch | head -n 1 | cut -d' ' -f 2)

    date_arg="format:%Y-%m-%d--%H-%M"
    fmt="%ad %C(auto)%h <%ce> %s"

    if [ -z "$last_unpushed" ]; then
        git log --pretty=format:"$fmt" --date="$date_arg" -n "$cnt" $branch
    else
        unpushed=$(make_red '/ UNPUSHED')
        git log --date="$date_arg" --pretty=format:"$fmt $unpushed" $last_unpushed~1..
        echo
        git log --date="$date_arg" --pretty=format:"$fmt" -n "$cnt" $last_unpushed~1
    fi
}

