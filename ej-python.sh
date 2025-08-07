alias pytest='uv run pytest'
alias py='python'
alias pin='uv pip install --extra-index-url=https://pypi.tuna.tsinghua.edu.cn/simple'
alias pinu='pin --upgrade'

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

function imports () {
    target_dir=$([ -d "src" ] && echo "src" || echo "package/src")
    for fp in $(fd -e py . $target_dir); do
        pm=$(echo $fp | sed -e "s/\//./g" -e "s/.py//g")
        echo $pm
        python -c "import $pm" >/dev/null
    done
}

function py-and-dirs () {
    fdfind -e py; fdfind -e py -x echo {//} | sed 's/\.\///g' | sort -u
}

function count_slashes() {
    local fpath="$1"
    # Remove trailing slash if present to avoid counting it
    fpath="${fpath%/}"
    # Count the number of forward slashes
    local count="${fpath//[^\/]/}"
    echo "${#count}"
}

function ishift() {
    local spaces=${1:-4}  # Default to 4 spaces if no argument given
    local indent=$(printf "%${spaces}s" "")  # Create a string of N spaces

    # Process each line of input
    while IFS= read -r line; do
        printf "%s%s\n" "$indent" "$line"
    done
}

function pys () {
    level_size=4
    for fp in $(py-and-dirs | sort); do
        # echo $fp
        depth=$(($(count_slashes $fp)*$level_size))
        echo "📍 $fp" | ishift $depth;
        if test -f $fp; then
            depth1=$(($depth+$level_size))
            rg '^\s*(def |class )' $fp | ishift $depth1
        fi
    done
}

function pyd() {
    # Check if argument is provided
    if [ -z "$1" ]; then
        echo "Usage: pyd <module>[.<function>]"
        echo "Example: pyd os.system"
        return 1
    fi

    # Split the argument into module and function parts
    IFS='.' read -r module_name function_name <<< "$1"

    # Python command to get help
    if [ -z "$function_name" ]; then
        python -c "import $module_name; help($module_name)"
    else
        python -c "from $module_name import $function_name; help($function_name)"
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

function rfix() {
    target_dir=$([ -d "src" ] && echo "src" || echo "package/src")
    ruff check --fix $target_dir
    ruff format $target_dir
}

