#!/usr/bin/env python3
"""
Merge git status --short with git diff --stat HEAD
"""

import re
import sys

try:
    import git
except ImportError:
    print("GitPython not installed. Install with: pip install GitPython", file=sys.stderr)
    sys.exit(1)


# ANSI color codes
class Colors:
    RESET = "\033[0m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    GRAY = "\033[90m"


def colorize(text: str, color: str) -> str:
    """Apply color to text if output is a terminal."""
    if sys.stdout.isatty():
        return f"{color}{text}{Colors.RESET}"
    return text


def colorize_stat(stat: str) -> str:
    """Colorize the stat string - additions in green, deletions in red."""
    if not sys.stdout.isatty():
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


def get_diff_stats(repo):
    """Parse git diff --stat HEAD and return {filename: stat_str} dict and summary line."""
    diff_output = repo.git.diff("--stat", "HEAD")

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


def get_status_items(repo):
    """Parse git status --short and return list of (status_code, filename) tuples."""
    status_output = repo.git.status("--short", porcelain=True)

    items = []
    for line in status_output.split("\n"):
        if not line:
            continue
        # Format: XY filename (where X is staged, Y is unstaged)
        # Extract first 2 chars as status, rest as filename
        status_code = line[:2]
        filename = line[3:] if len(line) > 3 else line[2:]
        items.append((status_code, filename))

    return items


def get_max_filename_length(diff_stats):
    """Find max filename length for alignment (only files with diffs)."""
    return max((len(fname) for fname in diff_stats.keys()), default=0)


def print_merged_output(status_items, diff_stats, max_len):
    """Print merged status and diff stats, removing matched files from diff_stats."""
    for status_code, filename in status_items:
        status_colored = format_status_code(status_code)

        if filename in diff_stats:
            padding = " " * (max_len - len(filename))
            stat_colored = colorize_stat(diff_stats[filename])
            print(f"{status_colored} {filename}{padding}{stat_colored}")
            del diff_stats[filename]
        else:
            print(f"{status_colored} {filename}")


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


def main():
    try:
        repo = git.Repo(search_parent_directories=True)
    except git.InvalidGitRepositoryError:
        print("Not a git repository", file=sys.stderr)
        sys.exit(1)

    diff_stats, summary_line = get_diff_stats(repo)
    status_items = get_status_items(repo)

    max_len = get_max_filename_length(diff_stats)
    print_merged_output(status_items, diff_stats, max_len)

    if summary_line:
        print(colorize_summary_line(summary_line))


if __name__ == "__main__":
    main()
