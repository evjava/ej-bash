SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

function rel () { . "$HOME/.bashrc"; echo 'Config reloaded!'; }
function ej-bash-gull () { git -C $SCRIPT_DIR pull; }

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

function hig() {
    if [[ $# == 0 ]]; then
        echo "Usage: hig <pattern1> [<pattern2> ...]" >&2
        return 1
    fi
    local cmd="HISTTIMEFORMAT='' history"
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

function greps() {
    local cmd="cat"
    for pattern in "$@"; do
        if [[ $pattern == -* ]]; then
            cmd="$cmd | grep -v '${pattern:1}'"
        else
            cmd="$cmd | grep '$pattern'"
        fi
    done
    eval "$cmd"
}

function greps-in() {
    local patterns=()
    local exclude_patterns=()

    # Separate positive and negative patterns
    for arg in "$@"; do
        if [[ $arg == -* ]]; then
            exclude_patterns+=("${arg:1}")
        else
            patterns+=("$arg")
        fi
    done

    # Process each file from stdin
    while read -r file; do
        [[ -f "$file" ]] || continue

        local match=true

        # Check all positive patterns must match
        for pattern in "${patterns[@]}"; do
            if ! grep -q "$pattern" "$file"; then
                match=false
                break
            fi
        done

        # Check no exclude patterns match
        if [[ $match == true ]]; then
            for pattern in "${exclude_patterns[@]}"; do
                if grep -q "$pattern" "$file"; then
                    match=false
                    break
                fi
            done
        fi

        # Output file if all conditions satisfied
        [[ $match == true ]] && echo "$file"
    done
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

function make_red() {
    echo -e "\033[31m$@\033[0m"
}


function hosts-names() {
    awk '/^Host / && $2 != "*" { print $2 }' $HOME/.ssh/config
}

function hosts() {
    if [[ "$1" == "--names" ]]; then
        hosts-names
        return
    fi

    # deepseek
    # Print the header
    echo "| host       | IP             |"
    echo "|------------+----------------|"

    # Parse the SSH config file
    awk '
    BEGIN {
        host = ""; hostname = ""
    }
    /^Host / {
        # Skip wildcard host entries
        if ($2 == "*") {
            host = ""
            next
        }
        # If we have a previous host to print, do it before starting new one
        if (host != "") {
            printf "| %-10s | %s\n", host, hostname
        }
        host = $2
        hostname = ""
    }
    /^  HostName / {
        hostname = $2
    }
    END {
        # Print the last host if there was one
        if (host != "" && host != "*") {
            printf "| %-10s | %s\n", host, hostname
        }
    }
    ' $HOME/.ssh/config
}

function tramp() {
    if [ -z "$1" ]; then
        echo "Usage: tramp <file-path>"
        return 1
    fi

    local file_path=$(realpath "$1")
    local pretty_host=$(hostnamectl --pretty | tr '[:upper:]' '[:lower:]')

    echo "(find-file \"/ssh:$pretty_host:$file_path\")"
}

function fmt-eval() {
    # e.g. command `fmt-eval 'echo 1 {} 2' a` acts like `echo 1 a 2`
    # `fmt-eval 'echo 1 {} 4' 2 3` acts like `echo 1 2 3 4`
    if [[ $# -lt 1 ]]; then
        echo "Usage: fmt-eval <format-string-with-maybe-{}> [args...]" >&2
        return 1
    fi

    local fmt="$1"
    shift
    args=$*

    if [[ "$fmt" == *"{}"* ]]; then
        cmd="${fmt//\{\}/$args}"
    else
        # No placeholder, append all args
        cmd="$fmt $args"
    fi
    eval "$cmd"
}

function link-here () {
    local target="$1"
    local linkname
    linkname=$(basename "$target")

    if [ -e "$linkname" ] || [ -L "$linkname" ]; then
        read -p "Override existing '$linkname'? [y/N] " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            return 1
        fi
        rm -f "$linkname"
    fi

    ln -s "$target" "$linkname"
}

function docx-to-md() {
    if [ $# -ne 1 ]; then
        echo "Usage: docx-to-md <input.docx>"
        return 1
    fi
    input="$1"
    output="${input%.docx}.md"
    pandoc "$input" -t markdown -o "$output" --wrap=none
    echo "Converted to $output"
}

function switch-theme() {
    local theme_dir="/usr/share/xfce4/terminal/colorschemes"
    local dark_bg="#131926"
    local light_bg="#f1f1f1"
    local theme_file new_theme bg fg palette

    # Get current background color
    local current_bg
    current_bg=$(xfconf-query -c xfce4-terminal -p /color-background 2>/dev/null)

    if [ "$current_bg" = "$dark_bg" ]; then
        # Currently dark, switch to light
        theme_file="$theme_dir/xubuntu-light.theme"
        new_theme="light"
    else
        # Currently light (or unknown), switch to dark
        theme_file="$theme_dir/xubuntu-dark.theme"
        new_theme="dark"
    fi

    # Extract colors from theme file
    bg=$(grep "^ColorBackground=" "$theme_file" | cut -d= -f2)
    fg=$(grep "^ColorForeground=" "$theme_file" | cut -d= -f2)
    palette=$(grep "^ColorPalette=" "$theme_file" | cut -d= -f2)

    # Apply all color settings
    xfconf-query -c xfce4-terminal -p /color-background -s "$bg"
    xfconf-query -c xfce4-terminal -p /color-foreground -s "$fg"
    xfconf-query -c xfce4-terminal -p /color-palette -s "$palette"

    echo "Switched to $new_theme theme"
}

## functions: oneliners
function klr () {  kill -9 `ps -e | grep $@ | tr -s ' ' | sed -n 1p | awk '{ print $1; }'`; }
function fix-caps() { setxkbmap -option ctrl:nocaps; }
function addr() { ifconfig | grep -Po '(?<=inet )[\d\.]+'; }
function fh() { free -h; }
function restart-wifi() { nmcli radio wifi off && nmcli radio wifi on; }
function size() { du -sc $1 | awk '$2 == "total" {total += $1} END {print total}'; }
function logout () { xfce4-session-logout --logout; }
function docker-stop-rm() { cid=$1; docker stop $cid; docker rm $cid; }
function port() { port=$1; sudo netstat --all --program | grep ":$port"; }
function parse-is-dry () { [[ "${dry:-${DRY:-}}" =~ ^(1|yes|true)$ ]] && echo true || echo; }
function parse-is-debug () { [[ "${dry:-${DRY:-}}" =~ ^(1|yes|true)$ ]] && echo true || echo; }

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
alias freh='free -h'
alias wcl='wc -l'
alias fdn='fd --no-ignore-vcs --hidden'
alias jn='jupyter notebook'
alias hi="history"
alias m='make'
alias ml='awk -F: '\''/^[a-zA-Z0-9_-]+:/ && !seen[$1]++ {print $1}'\'' Makefile'
alias rg='/usr/bin/rg --glob ''!uv.lock'' --glob ''!poetry.lock'' --max-columns=500 --no-heading --follow --unrestricted --sort=path'
alias rgn='/usr/bin/rg --max-columns=500 --no-heading --follow --unrestricted --no-ignore-vcs --hidden'
alias rgp='/usr/bin/rg --max-columns=500 --no-heading --follow --unrestricted --sort=path -t py'
alias jsonp='python -m json.tool --no-ensure-ascii'
alias doc='docker compose --progress=plain'
alias summate='paste -sd+ | bc'
alias dps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"'
alias reversed='tac'
alias bat='batcat --theme="Monokai Extended Light" --style="header,grid"'
alias c1='piep "p.split()[0]"'
alias c2='piep "p.split()[1]"'
alias c3='piep "p.split()[2]"'

alias dive="docker run -ti --rm  -v /var/run/docker.sock:/var/run/docker.sock docker.io/wagoodman/dive"
alias convert-doc="python $SCRIPT_DIR/py-tools/convert_doc.py"
