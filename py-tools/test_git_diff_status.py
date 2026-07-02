"""Tests for git_diff_status.py"""

import os
import sys
import tempfile
import subprocess


def create_test_repo(base_dir):
    """Create a git repo with files that have paths long enough to trigger git diff --stat truncation."""
    repo_dir = os.path.join(base_dir, "test-repo")
    os.makedirs(repo_dir, exist_ok=True)

    subprocess.run(["git", "init"], cwd=repo_dir, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=repo_dir, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.name", "Test User"], cwd=repo_dir, capture_output=True, check=True)

    # Deeply nested paths to trigger git diff --stat truncation
    files = [
        "app/src/main/java/com/example/module/data/Entity.kt",
        "app/src/main/java/com/example/module/data/Mapper.kt",
        "app/src/main/java/com/example/module/impl/Controller.kt",
        "app/src/main/java/com/example/module/impl/Service.kt",
        "app/src/main/java/com/example/module/impl/Repository.kt",
        "app/src/main/java/com/example/module/impl/Handler.kt",
        "app/src/main/java/com/example/module/impl/Factory.kt",
        "app/src/main/java/com/example/module/impl/Provider.kt",
        "app/src/main/java/com/example/module/ui/Adapter.kt",
        "app/src/main/java/com/example/module/Loader.kt",
    ]

    for i, f in enumerate(files):
        full_path = os.path.join(repo_dir, f)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        content = (f"// {f}\n" * (1 + i % 10)) + "abstract\n"
        with open(full_path, "w") as fh:
            fh.write(content)

    subprocess.run(["git", "add", "."], cwd=repo_dir, capture_output=True, check=True)
    subprocess.run(["git", "commit", "-m", "initial commit"], cwd=repo_dir, capture_output=True, check=True)

    # Modify files to create diffs with varying sizes
    for i, f in enumerate(files):
        full_path = os.path.join(repo_dir, f)
        with open(full_path, "a") as fh:
            fh.write("\n" * (i % 5 + 1))  # add 1-5 blank lines
            fh.write("// modified\n" * (i % 10 + 1))

    return repo_dir


def test_diff_stat_no_truncation():
    """Test that git diff --stat=9999,999 prevents path truncation."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import git_diff_status as gds

    with tempfile.TemporaryDirectory() as tmpdir:
        repo_dir = create_test_repo(tmpdir)

        # Verify that narrow --stat DOES truncate (confirming the bug can happen)
        narrow_output = subprocess.run(
            ["git", "-c", "diff.statGraphWidth=10", "diff", "--stat=50", "HEAD"],
            cwd=repo_dir, capture_output=True, text=True, check=True,
        ).stdout
        truncated = [l for l in narrow_output.split("\n") if ".../" in l and "|" in l]
        assert truncated, f"Expected truncation with --stat=50 but got none:\n{narrow_output}"
        print(f"Confirmed: narrow --stat=50 truncates {len(truncated)} paths")

        # Now test the script's actual logic with --stat=9999,999 (the fix)
        import git
        repo = git.Repo(repo_dir)
        diff_stats, summary_line = gds.get_diff_stats(repo)

        # Verify no truncated paths in diff_stats
        truncated_keys = [k for k in diff_stats if k.startswith("...")]
        assert not truncated_keys, f"Found {len(truncated_keys)} truncated keys after fix: {truncated_keys}"
        print(f"No truncated paths in diff_stats with --stat=9999,999 (fix works)")

        # Verify all status items match diff_stats
        status_items = gds.get_status_items(repo)

        unmatched = []
        for code, fname in status_items:
            if fname not in diff_stats:
                unmatched.append(fname)

        if unmatched:
            print(f"FAIL: {len(unmatched)} unmatched files:")
            for f in unmatched:
                print(f"  {f}")
            print("\ndiff_stats keys:")
            for k in sorted(diff_stats.keys()):
                print(f"  '{k}'")
        assert not unmatched, f"Found {len(unmatched)} unmatched files"

        # Test get_merged_output_lines
        max_len = gds.get_max_filename_length(diff_stats)
        lines = gds.get_merged_output_lines(status_items, diff_stats.copy(), max_len)
        assert len(lines) == len(status_items), f"Expected {len(status_items)} lines, got {len(lines)}"

        # Every line for a file with a stat should contain "|"
        files_with_stat = [f for code, f in status_items if f in diff_stats]
        stat_lines = [l for l in lines if "|" in l]
        assert len(stat_lines) == len(files_with_stat), \
            f"Expected {len(files_with_stat)} lines with stats, got {len(stat_lines)}"

        # Print the output
        print(f"\nOutput ({len(lines)} lines):")
        for line in lines:
            print(line)

    print("\n=== ALL TESTS PASSED ===")


def test_short_mode():
    """Test SHORT mode: compact +N/-M output with right-aligned numbers."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import git_diff_status as gds

    gds.USE_COLOR = False
    gds.SHORT = True

    # Unit: _count_stat_changes
    assert gds._count_stat_changes(" | 157 +++++----") == (5, 4)
    assert gds._count_stat_changes(" | 88 ++") == (2, 0)
    assert gds._count_stat_changes(" | 10 --") == (0, 2)
    assert gds._count_stat_changes(" | 0") == (0, 0)
    assert gds._count_stat_changes(" | Bin 0 -> 123 bytes") == (0, 0)
    print("_count_stat_changes: OK")

    # Unit: parse_stat_short — no bar graphs, just +N/-M
    assert gds.parse_stat_short(" | 157 +++++----", 0, 0) == " | +5 -4"
    assert gds.parse_stat_short(" | 88 ++", 0, 0) == " | +2"
    assert gds.parse_stat_short(" | 10 --", 0, 0) == " | -2"
    assert gds.parse_stat_short(" | 0", 0, 0) == " | 0"
    assert gds.parse_stat_short(" | Bin 0 -> 123 bytes", 0, 0) == " | Bin 0 -> 123 bytes"
    print("parse_stat_short: OK")

    # Unit: parse_stat_short with rjust widths
    # pw=2 means +N is right-justified to 3 chars (sign + 2 digits)
    assert gds.parse_stat_short(" | 11 ++", 2, 2) == " |  +2"     # ' +2' rjust 3
    assert gds.parse_stat_short(" | 157 " + "+" * 97, 2, 2) == " | +97"
    assert gds.parse_stat_short(" | 60 --", 2, 2) == " |  -2"     # ' -2' rjust 3
    assert gds.parse_stat_short(" | 60 " + "-" * 10, 2, 2) == " | -10"
    assert gds.parse_stat_short(" | 11 +++++--", 2, 2) == " |  +5  -2"  # both aligned
    print("parse_stat_short rjust: OK")

    # Integration: full SHORT output, no bar graphs, all stats present
    with tempfile.TemporaryDirectory() as tmpdir:
        repo_dir = create_test_repo(tmpdir)
        import git
        repo = git.Repo(repo_dir)
        diff_stats, _summary = gds.get_diff_stats(repo)
        status_items = gds.get_status_items(repo)
        max_len = gds.get_max_filename_length(diff_stats)

        lines = gds.get_merged_output_lines(status_items, diff_stats.copy(), max_len)
        assert len(lines) == len(status_items)

        stat_lines = [l for l in lines if "|" in l]
        assert len(stat_lines) == len(status_items), \
            f"Expected all {len(status_items)} lines to have stats, got {len(stat_lines)}"

        # No bar graphs leak into SHORT mode
        for line in stat_lines:
            stat_part = line.split("|", 1)[1]
            assert "+++" not in stat_part, f"bar graph in SHORT: {line}"
            assert "---" not in stat_part, f"bar graph in SHORT: {line}"
        print(f"SHORT integration: {len(stat_lines)} lines, no bar graphs — OK")

    print("\n=== SHORT mode tests passed ===")


if __name__ == "__main__":
    test_diff_stat_no_truncation()
    test_short_mode()
