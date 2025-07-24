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

function pipcd() {
    module="${1//-/_}"
    init_path_cmd="import $module; print(${module}.__file__)"
    init_path=$(python -c "$init_path_cmd")
    if [ ! -z $init_path ]; then
        cd $(dirname $init_path)
    fi
}

function hig() {
    if [[ $# == 0 ]]; then
        echo "Usage: hig <pattern1> [<pattern2> ...]" >&2
        return 1
    fi
    local cmd="history"
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

function gl() {
    cnt="$1"
    branch="$2"
    if [ -z "$cnt" ]; then
        cnt=10
    fi

    last_unpushed=$(git cherry origin/dev dev | head -n 1 | cut -d' ' -f 2)~1

    date_arg="format:%Y-%m-%d--%H-%M"
    fmt="%ad %C(auto)%h <%ce> %s"

    if [ -z "$commit_first_unpushed" ]; then
        git log --pretty=format:"$fmt" --date="$date_arg" -n "$cnt" $branch
    else
        unpushed=$(make_red '/ UNPUSHED')
        git log --date="$date_arg" --pretty=format:"$fmt $unpushed" $branch $last_unpushed..
        echo
        git log --date="$date_arg" --pretty=format:"$fmt" -n "$cnt" $branch $last_unpushed
    fi
}

function fixpy() {
    # deepseek, prompt:
    # Write bash function which will do batch changes in python files.
    # This is naked core: `fd -e py -x sed -i "s/$pattern/$sub/g"`
    # You should:
    # - check that pattern and sub passed ( empty sub is allowed )
    # - run sed firstly in dry-run
    # - then run `fd -e` only on files which can be really changed
    if [[ -z "$1" ]]; then
        echo "Error: Pattern argument is required."
        return 1
    fi

    local pattern="$1"
    local sub="${2:-}"  # Set sub to empty string if not provided
    local dry_run_files=()
    local changed_files=()

    echo "=== DRY RUN ==="
    # First pass: dry run to find affected files
    while IFS= read -r file; do
        if grep -q "$pattern" "$file"; then
            dry_run_files+=("$file")
            echo "Would change: $file"
            # Show sample changes
            grep -n "$pattern" "$file" | head -3 | while read -r line; do
                echo "  Line $line"
                echo "    Old: $(echo "$line" | sed -n "s/.*\($pattern\).*/    \1/p")"
                echo "    New: $(echo "$line" | sed -n "s/$pattern/$sub/gp")"
            done
        fi
    done < <(fd -e py)

    if [[ ${#dry_run_files[@]} -eq 0 ]]; then
        echo "No files would be modified."
        return 0
    fi

    # Ask for confirmation
    echo -e "\n=== SUMMARY ==="
    echo "Pattern:    '$pattern'"
    echo "Replacement: '$sub'"
    echo "Files to modify:"
    for file in "${dry_run_files[@]}"; do
        echo "- $file"
    done
    read -rp "Proceed with changes? (y/N) " confirm

    if [[ "$confirm" != [yY] ]]; then
        echo "Aborted."
        return 0
    fi

    echo -e "\n=== MAKING CHANGES ==="

    # Second pass: actual changes only on files that need modification
    for file in "${dry_run_files[@]}"; do
        if sed -i "s/$pattern/$sub/g" "$file"; then
            changed_files+=("$file")
            echo "Changed: $file"
        else
            echo "Error changing: $file" >&2
        fi
    done

    echo -e "\n=== DONE ==="
    echo "Files changed: ${#changed_files[@]}"
}

function hosts() {
    # deepseek
    # Print the header
    echo "| host     | IP             |"
    echo "|----------+----------------|"

    # Parse the SSH config file
    awk '
    BEGIN {
        host = ""; hostname = ""
    }
    /^Host / {
        # If we have a previous host to print, do it before starting new one
        if (host != "") {
            printf "| %-8s | %s\n", host, hostname
        }
        host = $2
        hostname = ""
    }
    /^  HostName / {
        hostname = $2
    }
    END {
        # Print the last host if there was one
        if (host != "") {
            printf "| %-8s | %s\n", host, hostname
        }
    }
    ' $HOME/.ssh/config
    echo $HOME/.ssh/config
}

function logout() {
    read -p "$1 ( yes ( default ) / no ): " answer
    if [[ $answer != "no" ]]; then
        xfce4-session-logout --logout
    fi
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
