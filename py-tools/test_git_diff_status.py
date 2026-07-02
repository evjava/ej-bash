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
    gds.USE_COLOR = False
    gds.COUNTS_FIRST = False  # test default inline mode

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
    gds.COUNTS_FIRST = False  # test default inline mode

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
    assert gds.parse_stat_short(" | 10 --", 0, 0) == " |   -2"  # padded to align with minus column
    assert gds.parse_stat_short(" | 0", 0, 0) == " | 0"
    assert gds.parse_stat_short(" | Bin 0 -> 123 bytes", 0, 0) == " | Bin 0 -> 123 bytes"
    print("parse_stat_short: OK")

    # Unit: parse_stat_short with rjust widths
    # pw=2 means +N is right-justified to 3 chars (sign + 2 digits)
    assert gds.parse_stat_short(" | 11 ++", 2, 2) == " |  +2"     # ' +2' rjust 3
    assert gds.parse_stat_short(" | 157 " + "+" * 97, 2, 2) == " | +97"
    assert gds.parse_stat_short(" | 60 --", 2, 2) == " |      -2"  # padded to align minus column
    assert gds.parse_stat_short(" | 60 " + "-" * 10, 2, 2) == " |     -10"
    assert gds.parse_stat_short(" | 11 +++++--", 2, 2) == " |  +5  -2"  # both aligned
    print("parse_stat_short rjust: OK")

    # Unit: alignment — only-minus minus column matches both-present minus column
    both  = gds.parse_stat_short(" | 11 +++++--", 2, 2)
    minus = gds.parse_stat_short(" | 60 --", 2, 2)
    assert both.index("-") == minus.index("-"), f"minus misaligned: {both!r} vs {minus!r}"
    print("alignment minus: OK")
    plus  = gds.parse_stat_short(" | 11 ++", 2, 2)
    both2 = gds.parse_stat_short(" | 11 +++++--", 2, 2)
    assert plus.index("+") == both2.index("+"), f"plus misaligned: {plus!r} vs {both2!r}"
    print("alignment plus: OK")

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


def test_counts_first_mode():
    """Test COUNTS_FIRST mode: counts | status filename with aligned columns."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import git_diff_status as gds

    gds.USE_COLOR = False
    gds.SHORT = True
    gds.COUNTS_FIRST = True

    # Unit: format_counts without prefix (for COUNTS_FIRST)
    assert gds.format_counts(" | 157 +++++----", 2, 2, prefix="") == "  +5  -4"
    assert gds.format_counts(" | 88 ++", 2, 2, prefix="") == "  +2"
    assert gds.format_counts(" | 10 --", 2, 2, prefix="") == "      -2"  # padded
    assert gds.format_counts(" | 0", 0, 0, prefix="") == " 0"
    print("format_counts: OK")

    # Unit: _counts_width
    assert gds._counts_width(2, 2) == 1 + 3 + 1 + 3  # leading space + plus + space + minus = 8
    assert gds._counts_width(2, 0) == 1 + 3  # leading space + plus = 4
    assert gds._counts_width(0, 2) == 1 + 2 + 3  # leading space + pad(pw+2) + minus = 6
    assert gds._counts_width(0, 0) == 0
    print("_counts_width: OK")

    # Unit: alignment — minus in only-minus matches minus in both-present
    both  = gds.format_counts(" | 11 +++++--", 2, 2, prefix="")
    minus = gds.format_counts(" | 10 --", 2, 2, prefix="")
    assert both.index("-") == minus.index("-"), f"minus misaligned: {both!r} vs {minus!r}"
    print("counts-first alignment: OK")

    # Integration: full COUNTS_FIRST output with divider
    with tempfile.TemporaryDirectory() as tmpdir:
        repo_dir = create_test_repo(tmpdir)
        import git
        repo = git.Repo(repo_dir)
        diff_stats, _summary = gds.get_diff_stats(repo)
        status_items = gds.get_status_items(repo)
        max_len = gds.get_max_filename_length(diff_stats)

        lines = gds.get_merged_output_lines(status_items, diff_stats.copy(), max_len)
        assert len(lines) == len(status_items)

        # Every line should have " | " divider between counts and status
        for line in lines:
            assert " | " in line, f"missing divider in: {line!r}"
            # No bar graphs
            assert "+++" not in line, f"bar graph in: {line}"
            assert "---" not in line, f"bar graph in: {line}"

        # All lines should have the same prefix length before " | "
        divider_positions = [line.index(" | ") for line in lines]
        assert len(set(divider_positions)) == 1, \
            f"Misaligned dividers: {divider_positions}"
        print(f"COUNTS_FIRST integration: {len(lines)} lines, all aligned — OK")

    print("\n=== COUNTS_FIRST mode tests passed ===")


def create_rename_repo(base_dir):
    """Create a git repo with a renamed+modified file (RM status).

    Produces RM by: 1) staging a rename, 2) making an unstaged modification.
    """
    repo_dir = os.path.join(base_dir, "rename-repo")
    os.makedirs(repo_dir, exist_ok=True)

    subprocess.run(["git", "init"], cwd=repo_dir, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=repo_dir, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.name", "Test User"], cwd=repo_dir, capture_output=True, check=True)

    # Create a file with enough content for git to detect as rename
    old_path = os.path.join(repo_dir, "original_name.py")
    with open(old_path, "w") as f:
        f.write("def foo():\n    return 42\n\ndef bar():\n    return 99\n\n# end\n")

    subprocess.run(["git", "add", "."], cwd=repo_dir, capture_output=True, check=True)
    subprocess.run(["git", "commit", "-m", "initial"], cwd=repo_dir, capture_output=True, check=True)

    # Stage the rename (but don't commit)
    new_path = os.path.join(repo_dir, "renamed_name.py")
    os.rename(old_path, new_path)
    subprocess.run(["git", "add", "-A"], cwd=repo_dir, capture_output=True, check=True)

    # Now make an unstaged modification -> produces RM status
    with open(new_path, "a") as f:
        f.write("# unstaged change\n")

    # Verify git detected it as RM
    st = subprocess.run(["git", "status", "--short"], cwd=repo_dir, capture_output=True, text=True, check=True)
    status_lines = [l for l in st.stdout.strip().split("\n") if l]
    assert any("RM" in l for l in status_lines), f"Expected RM status, got: {status_lines}"
    print(f"Rename repo status: {status_lines}")

    return repo_dir


def test_rename_shows_divider():
    """Test that renamed files (RM/R) get the | divider — diff stat filename uses => but status uses ->."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import git_diff_status as gds

    gds.USE_COLOR = False
    gds.SHORT = True
    gds.COUNTS_FIRST = True

    with tempfile.TemporaryDirectory() as tmpdir:
        repo_dir = create_rename_repo(tmpdir)

        import git
        repo = git.Repo(repo_dir)

        # Get raw git diff --stat output to confirm the format difference
        diff_raw = repo.git.diff("--stat=9999,999", "HEAD")
        print(f"Raw diff --stat:\n{diff_raw}")

        status_raw = repo.git.status("--short")
        print(f"Raw status --short:\n{status_raw}")

        diff_stats, _summary = gds.get_diff_stats(repo)
        status_items = gds.get_status_items(repo)

        print(f"diff_stats keys: {list(diff_stats.keys())}")
        print(f"status_items: {status_items}")

        # The renamed file must be in both diff_stats and status_items
        # and must show the | divider
        max_len = gds.get_max_filename_length(diff_stats)
        lines = gds.get_merged_output_lines(status_items, diff_stats.copy(), max_len)

        print(f"Output lines ({len(lines)}):")
        for line in lines:
            print(f"  [{line}]")

        # Check that RM (or R) status file is matched and gets |
        for code, fname in status_items:
            if code[0] == 'R':  # RM, R, RD
                assert fname in diff_stats, \
                    f"Renamed file '{fname}' (code={code}) NOT found in diff_stats! " \
                    f"diff_stats keys: {list(diff_stats.keys())}"
                print(f"OK: renamed file '{fname}' (code={code}) matched in diff_stats")

                # Also check the output line contains |
                matching_lines = [l for l in lines if fname in l]
                assert len(matching_lines) == 1, f"Expected 1 line for {fname}, got {len(matching_lines)}"
                assert " | " in matching_lines[0], \
                    f"RM file missing | divider: {matching_lines[0]!r}"
                print(f"OK: RM file has | divider: {matching_lines[0]}")

        # Verify at least one renamed file was tested
        renamed_codes = [c for c, _ in status_items if c[0] == 'R']
        assert renamed_codes, "Test MUST have at least one renamed (R/RM) file"

    print("\n=== RENAME test passed ===")


def test_counts_first_alignment_with_color():
    """COUNTS_FIRST mode: | divider visually aligned even when ANSI colors are on.

    When color is enabled, ANSI codes inflate raw string length.  ljust()
    would skip padding (raw_len > target), breaking alignment.  _visual_ljust()
    must correct this.
    """
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import git_diff_status as gds

    gds.USE_COLOR = True   # colour ON – the bug only bites with ANSI codes present
    gds.SHORT = True
    gds.COUNTS_FIRST = True

    # Unit: _visual_ljust
    plain = "  +1"                         # visual 4, no ANSI → trivial
    ansi  = " \033[32m +1\033[0m"          # visual 4, raw 13  (as from format_counts)
    assert gds._visual_len(plain) == 4
    assert gds._visual_len(ansi) == 4, f"expected 4, got {gds._visual_len(ansi)}"
    assert len(ansi) == 13  # raw contains codes

    padded = gds._visual_ljust(ansi, 9)
    assert gds._visual_len(padded) == 9, f"_visual_ljust should pad to visual 9, got {gds._visual_len(padded)}"
    # Must end with spaces (padding appended, not eaten by ANSI)
    assert padded.endswith("     ") or padded.rstrip() != padded, \
        f"expected trailing spaces, got {padded!r}"
    print("_visual_ljust: OK")

    # Integration: repo with files that produce different visual stat widths
    with tempfile.TemporaryDirectory() as tmpdir:
        repo_dir = os.path.join(tmpdir, "align-repo")
        os.makedirs(repo_dir)
        subprocess.run(["git", "init"], cwd=repo_dir, capture_output=True, check=True)
        subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=repo_dir, capture_output=True, check=True)
        subprocess.run(["git", "config", "user.name", "Test"], cwd=repo_dir, capture_output=True, check=True)

        # File A: small change (1 line added)  → visual counts " +1"  (short)
        with open(os.path.join(repo_dir, "a_small.kt"), "w") as f:
            f.write("// base\n")
        subprocess.run(["git", "add", "."], cwd=repo_dir, capture_output=True, check=True)
        subprocess.run(["git", "commit", "-m", "init"], cwd=repo_dir, capture_output=True, check=True)
        with open(os.path.join(repo_dir, "a_small.kt"), "a") as f:
            f.write("// added\n")

        # File B: large change (+90/-127)  → visual counts "+90 -127"  (wide)
        large_path = os.path.join(repo_dir, "b_large.kt")
        with open(large_path, "w") as f:
            f.write("line\n" * 200)
        subprocess.run(["git", "add", b_large_path if 'b_large_path' in dir() else large_path], cwd=repo_dir, capture_output=True, check=True)

        subprocess.run(["git", "add", "b_large.kt"], cwd=repo_dir, capture_output=True, check=True)
        subprocess.run(["git", "commit", "-m", "add large"], cwd=repo_dir, capture_output=True, check=True)
        with open(large_path, "w") as f:
            f.write("MODIFIED\n" * 90 + "line\n" * 127)

        # Untracked file (no stat)
        with open(os.path.join(repo_dir, "c_untracked.txt"), "w") as f:
            f.write("untracked\n")

        import git
        repo = git.Repo(repo_dir)
        diff_stats, _summary = gds.get_diff_stats(repo)
        status_items = gds.get_status_items(repo)

        max_len = gds.get_max_filename_length(diff_stats)
        lines = gds.get_merged_output_lines(status_items, diff_stats.copy(), max_len)

        print(f"Output ({len(lines)} lines):")
        for l in lines:
            # Show both raw and visual
            print(f"  visual=[{gds._ANSI_RE.sub('', l)}]")

        # Strip ANSI to compare visual alignment of the | divider
        visual_lines = [gds._ANSI_RE.sub('', l) for l in lines]

        # Collect visual positions of " | " divider
        divider_positions = []
        for vl in visual_lines:
            idx = vl.find(" | ")
            if idx >= 0:
                divider_positions.append(idx)
                print(f"  | at visual pos {idx}: {vl[:idx+3]!r}")

        if divider_positions:
            unique = set(divider_positions)
            assert len(unique) == 1, \
                f"Misaligned | dividers! Positions: {divider_positions}"
            print(f"All | dividers at visual position {divider_positions[0]} — aligned!")

        # Also check untracked status aligns with stats status
        status_positions = []
        for vl in visual_lines:
            # Status is 2 chars: " M", "A ", "??", "RM"
            for st in [" M", "A ", "??", "RM", "R ", " D"]:
                idx = vl.find(st)
                if idx >= 0:
                    status_positions.append(idx)
                    print(f"  status '{st}' at visual pos {idx}")
                    break

        if status_positions:
            unique = set(status_positions)
            assert len(unique) == 1, \
                f"Status codes not aligned! Positions: {status_positions}\nLines:\n" + \
                "\n".join(f"  {vl!r}" for vl in visual_lines)
            print(f"All status codes at visual position {status_positions[0]} — aligned!")

    print("\n=== COUNTS_FIRST alignment with colors test passed ===")


if __name__ == "__main__":
    test_diff_stat_no_truncation()
    test_short_mode()
    test_counts_first_mode()
    test_rename_shows_divider()
