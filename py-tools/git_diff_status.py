#!/usr/bin/env python3
"""
Merge git status --short with git diff --stat HEAD

Usage:
    git_diff_status.py [--color] [directory]

Options:
    --color    Force color output (like git --color=always)

If a directory is provided, shows status only for files in that directory.
"""

import re
import os
import sys

try:
    import git
except ImportError:
    print("GitPython not installed. Install with: pip install GitPython", file=sys.stderr)
    sys.exit(1)

# Color mode: None = auto (tty-based), True = always, False = never
USE_COLOR = None

# Short mode: replace stat bar ("157 +++++----") with compact numbers ("157 +5 -4")
def _is_yes(key: str, default: str = "") -> bool:
    return os.environ.get(key, default).lower() in ("1", "yes", "true")

SHORT = _is_yes("GIT_DIFF_STATUS_SHORT", "1")

# ANSI color codes
class Colors:
    RESET = "\033[0m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    GRAY = "\033[90m"


def colorize(text: str, color: str) -> str:
    """Apply color to text if color output is enabled."""
    if USE_COLOR or (USE_COLOR is None and sys.stdout.isatty()):
        return f"{color}{text}{Colors.RESET}"
    return text


def colorize_stat(stat: str) -> str:
    """Colorize the stat string - additions in green, deletions in red."""
    if not (USE_COLOR or (USE_COLOR is None and sys.stdout.isatty())):
        return stat

    # Match additions (+) and deletions (-)
    result = []
    i = 0
    while i < len(stat):
        if stat[i] == "|" or stat[i] == " " or stat[i : i + 2] == "  ":
            result.append(stat[i])
            i += 1
        elif stat[i] == "+":
            # Count consecutive +
            count = 0
            while i < len(stat) and stat[i] == "+":
                count += 1
                i += 1
            result.append(colorize("+" * count, Colors.GREEN))
        elif stat[i] == "-":
            # Count consecutive -
            count = 0
            while i < len(stat) and stat[i] == "-":
                count += 1
                i += 1
            result.append(colorize("-" * count, Colors.RED))
        else:
            result.append(stat[i])
            i += 1

    return "".join(result)


def get_status_color(staged: str, unstaged: str) -> str:
    """Get color for a status character."""
    # Untracked
    if staged == "?" or unstaged == "?":
        return Colors.RED

    # Staged changes (green)
    if staged == "A":
        return Colors.GREEN
    elif staged == "M":
        return Colors.GREEN
    elif staged == "D":
        return Colors.GREEN
    elif staged == "R":
        return Colors.GREEN

    # Unstaged changes (red)
    if unstaged == "M":
        return Colors.RED
    elif unstaged == "D":
        return Colors.RED

    return Colors.RESET


def format_status_code(status_code: str) -> str:
    """Format status code with each character colored separately."""
    staged = status_code[0] if status_code else " "
    unstaged = status_code[1] if len(status_code) > 1 else " "

    # Color each character based on its meaning
    staged_color = get_status_color(staged, " ")
    unstaged_color = get_status_color(" ", unstaged)

    return f"{colorize(staged, staged_color)}{colorize(unstaged, unstaged_color)}"


def get_diff_stats(repo) -> tuple[dict, str]:
    """Parse git diff --stat HEAD and return {filename: stat_str} dict and summary line."""
    diff_output = repo.git.diff("--stat=9999,999", "HEAD")

    diff_stats = {}
    summary_line = None

    for line in diff_output.split("\n"):
        if not line:
            continue

        # Check for summary line (e.g., "2 files changed, 19 insertions(+), 2 deletions(-)")
        if "files changed" in line or "file changed" in line:
            summary_line = f" {line}"
            continue

        # Parse lines like: " log.org      | 2 --"
        pattern_match = re.match(r"^\s*(.+?)\s*\|\s*(.+)$", line)
        if pattern_match:
            filename = pattern_match.group(1).rstrip()
            stat = f" | {pattern_match.group(2)}"
            diff_stats[filename] = stat

    return diff_stats, summary_line


def get_status_items(repo, target_dir=None, relpath_converter=None):
    """Parse git status --short and return list of (status_code, filename) tuples.

    Args:
        repo: GitPython Repo object
        target_dir: If provided, only return items in this directory
        relpath_converter: Function to convert repo-relative paths to cwd-relative paths
    """
    status_output = repo.git.status("--short", porcelain=True)

    # Convert target_dir to relative path for comparison
    target_rel = None
    if target_dir:
        target_rel = os.path.relpath(target_dir, repo.working_dir)
        # If target_dir is the repo root, show all files
        if target_rel == ".":
            target_rel = None

    items = []
    for line in status_output.split("\n"):
        if not line:
            continue
        # Format: XY filename (where X is staged, Y is unstaged)
        # Extract first 2 chars as status, rest as filename
        status_code = line[:2]
        filename = line[3:] if len(line) > 3 else line[2:]

        if target_rel:
            # Check if file is in target directory
            if not filename.startswith(target_rel):
                continue

        # Convert to cwd-relative path
        if relpath_converter:
            filename = relpath_converter(filename)

        items.append((status_code, filename))

    return items


def get_max_filename_length(diff_stats):
    """Find max filename length for alignment (only files with diffs)."""
    return max((len(fname) for fname in diff_stats.keys()), default=0)


def _count_stat_changes(stat_str: str) -> tuple[int, int]:
    """Extract (pluses, minuses) counts from a stat string."""
    inner = stat_str[3:]  # strip " | "
    if inner.startswith("Bin"):
        return 0, 0
    parts = inner.split(" ", 1)
    graph = parts[1] if len(parts) > 1 else ""
    return graph.count("+"), graph.count("-")


def parse_stat_short(stat_str: str, pw: int = 0, mw: int = 0) -> str:
    """Convert stat bar (" | 157 +++++----") to compact format (" |  +5  -4").

    pw, mw: rjust widths for the +N and -N numbers.
    """
    pluses, minuses = _count_stat_changes(stat_str)

    # Binary files: return as-is
    if stat_str[3:].startswith("Bin"):
        return stat_str

    result = " |"
    if pluses > 0:
        result += f" {colorize(f'+{pluses}'.rjust(pw + 1), Colors.GREEN)}"
    if minuses > 0:
        result += f" {colorize(f'-{minuses}'.rjust(mw + 1), Colors.RED)}"
    if pluses == 0 and minuses == 0:
        total = stat_str[3:].split(" ", 1)[0]
        result += f" {colorize(total, Colors.GRAY)}"
    return result


def get_merged_output_lines(status_items, diff_stats, max_len):
    """Return merged status and diff stats lines, removing matched files from diff_stats."""
    # Pre-compute rjust widths for SHORT mode
    pw = mw = 0
    if SHORT:
        for _code, filename in status_items:
            if filename in diff_stats:
                p, m = _count_stat_changes(diff_stats[filename])
                if p > 0:
                    pw = max(pw, len(str(p)))
                if m > 0:
                    mw = max(mw, len(str(m)))

    lines = []
    for status_code, filename in status_items:
        status_colored = format_status_code(status_code)

        if filename in diff_stats:
            padding = " " * (max_len - len(filename))
            stat = diff_stats[filename]
            stat_colored = parse_stat_short(stat, pw, mw) if SHORT else colorize_stat(stat)
            lines.append(f"{status_colored} {filename}{padding}{stat_colored}")
            del diff_stats[filename]
        else:
            lines.append(f"{status_colored} {filename}")
    return lines


def colorize_summary_line(summary_line: str) -> str:
    """Colorize summary line with gray base, green for insertions, red for deletions."""
    insertion_pattern = re.compile(r"\d+ insertions?\(\+\)")
    deletion_pattern = re.compile(r"\d+ deletions?\(-\)")

    matches = []
    for m in insertion_pattern.finditer(summary_line):
        matches.append((m.start(), m.end(), Colors.GREEN))
    for m in deletion_pattern.finditer(summary_line):
        matches.append((m.start(), m.end(), Colors.RED))

    matches.sort(key=lambda x: x[0])

    result = []
    last_end = 0
    for start, end, color in matches:
        if start > last_end:
            result.append(colorize(summary_line[last_end:start], Colors.GRAY))
        result.append(colorize(summary_line[start:end], color))
        last_end = end

    if last_end < len(summary_line):
        result.append(colorize(summary_line[last_end:], Colors.GRAY))

    return f"#{''.join(result)}"


def parse_args():
    """Parse command line arguments."""
    global USE_COLOR
    args = sys.argv[1:]
    color_always = "--color" in args
    if color_always:
        USE_COLOR = True
        args = [a for a in args if a != "--color"]
    target_dir = args[0] if args else None
    return target_dir


def main():
    target_dir = parse_args()

    try:
        if target_dir:
            repo = git.Repo(target_dir)
        else:
            repo = git.Repo(search_parent_directories=True)
    except git.InvalidGitRepositoryError:
        print("Not a git repository", file=sys.stderr)
        sys.exit(1)

    # Get current working directory
    cwd = os.getcwd()

    # Function to convert repo-relative path to cwd-relative path
    def relpath(repo_path):
        """Convert repo-relative path to cwd-relative path."""
        repo_abs = os.path.join(repo.working_dir, repo_path)
        return os.path.relpath(repo_abs, cwd)

    # Print header with directory if specified
    if target_dir:
        header = f"Status for: {colorize(target_dir, Colors.GREEN)} "
        print(colorize(header, Colors.GRAY))

    try:
        diff_stats, summary_line = get_diff_stats(repo)
        # Filter diff_stats to target_dir if specified
        if target_dir:
            # Git filenames are relative to repo root, convert target_dir to match
            target_rel = os.path.relpath(target_dir, repo.working_dir)
            # If target_dir is the repo root, show all files
            if target_rel != ".":
                diff_stats = {k: v for k, v in diff_stats.items() if k.startswith(target_rel)}
    except Exception:
        print("Empty repository: can not call 'diff'")
        diff_stats, summary_line = {}, None
    status_items = get_status_items(repo, target_dir, relpath)

    # Convert diff_stats keys to cwd-relative paths
    diff_stats = {relpath(k): v for k, v in diff_stats.items()}

    max_len = get_max_filename_length(diff_stats)
    for line in get_merged_output_lines(status_items, diff_stats, max_len):
        print(line)

    if summary_line:
        print(colorize_summary_line(summary_line))


if __name__ == "__main__":
    main()
