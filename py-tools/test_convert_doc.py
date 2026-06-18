#!/usr/bin/env python3
"""Tests for convert_doc.make_pandoc_command."""

import os
import sys

# Allow importing convert_doc from the same directory
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from convert_doc import make_pandoc_command, ConvertError, ALLOWED_FORMATS


# ------------------------------------------------------------------ helpers --

class TestFailure(Exception):
    """Raised when a test assertion fails."""


def assert_eq(actual, expected, msg=""):
    if actual != expected:
        raise TestFailure(
            f"{msg}\n     expected: {expected!r}\n       actual: {actual!r}"
        )


def assert_raises(exc_class, fn, *args, **kwargs):
    try:
        fn(*args, **kwargs)
    except exc_class:
        return  # expected
    except Exception as e:
        raise TestFailure(
            f"expected {exc_class.__name__}, got {type(e).__name__}: {e}"
        ) from e
    raise TestFailure(f"expected {exc_class.__name__}, but no exception was raised")


def fake_isfile(*present):
    """Return a callable that returns True only for names in *present*."""
    def _isfile(path):
        return path in present
    return _isfile


# ------------------------------------------------------------ format + file --

def test_fmt_then_file():
    cmd = make_pandoc_command("org", "fp.md", isfile=fake_isfile("fp.md"))
    assert_eq(cmd, ["pandoc", "fp.md", "-o", "fp.org"])


def test_fmt_then_file_deep_path():
    cmd = make_pandoc_command("pdf", "a/b/c/report.md", isfile=fake_isfile("a/b/c/report.md"))
    assert_eq(cmd, ["pandoc", "a/b/c/report.md", "-o", "a/b/c/report.pdf"])


def test_fmt_with_dotted_filename():
    cmd = make_pandoc_command("docx", "my.file.name.md", isfile=fake_isfile("my.file.name.md"))
    assert_eq(cmd, ["pandoc", "my.file.name.md", "-o", "my.file.name.docx"])


# ------------------------------------------------------------ file + format --

def test_file_then_fmt():
    cmd = make_pandoc_command("file.docx", "md", isfile=fake_isfile("file.docx"))
    assert_eq(cmd, ["pandoc", "file.docx", "-o", "file.md"])


def test_file_then_fmt_pdf():
    cmd = make_pandoc_command("notes.tex", "pdf", isfile=fake_isfile("notes.tex"))
    assert_eq(cmd, ["pandoc", "notes.tex", "-o", "notes.pdf"])


# ----------------------------------------------------- both look like files --

def test_two_files_first_exists():
    cmd = make_pandoc_command("a.docx", "a.md", isfile=fake_isfile("a.docx"))
    assert_eq(cmd, ["pandoc", "a.docx", "-o", "a.md"])


def test_two_files_second_exists():
    cmd = make_pandoc_command("a.docx", "a.md", isfile=fake_isfile("a.md"))
    assert_eq(cmd, ["pandoc", "a.md", "-o", "a.docx"])


def test_two_files_different_basenames():
    cmd = make_pandoc_command("src.docx", "dst.md", isfile=fake_isfile("src.docx"))
    assert_eq(cmd, ["pandoc", "src.docx", "-o", "dst.md"])


# ------------------------------------------------------------- error cases --

def test_source_not_found_fmt_first():
    assert_raises(ConvertError, make_pandoc_command, "org", "nope.md", isfile=fake_isfile())


def test_source_not_found_fmt_second():
    assert_raises(ConvertError, make_pandoc_command, "nope.docx", "md", isfile=fake_isfile())


def test_both_files_exist():
    assert_raises(
        ConvertError,
        make_pandoc_command, "a.docx", "a.md",
        isfile=fake_isfile("a.docx", "a.md"),
    )


def test_neither_file_exists():
    assert_raises(ConvertError, make_pandoc_command, "a.docx", "a.md", isfile=fake_isfile())


def test_target_already_exists_format_first():
    assert_raises(
        ConvertError,
        make_pandoc_command, "md", "src.docx",
        isfile=fake_isfile("src.docx", "src.md"),
    )


def test_target_already_exists_format_second():
    assert_raises(
        ConvertError,
        make_pandoc_command, "src.md", "docx",
        isfile=fake_isfile("src.md", "src.docx"),
    )


def test_target_already_exists_two_files():
    # Only source exists – should succeed, target taken verbatim
    cmd = make_pandoc_command(
        "report.docx", "report.md",
        isfile=fake_isfile("report.docx"),
    )
    assert_eq(cmd, ["pandoc", "report.docx", "-o", "report.md"])

    # Both exist – error
    assert_raises(
        ConvertError,
        make_pandoc_command, "x.docx", "x.md",
        isfile=fake_isfile("x.docx", "x.md"),
    )


def test_unsupported_format_in_file_pair():
    assert_raises(
        ConvertError,
        make_pandoc_command, "a.docx", "a.xyz",
        isfile=fake_isfile("a.docx"),
    )


def test_invalid_bare_format():
    # "foo" is not in ALLOWED_FORMATS and doesn't look like a file extension
    assert_raises(ConvertError, make_pandoc_command, "foo", "bar", isfile=fake_isfile())


# --------------------------------------------------------------------- main --

def run_tests():
    g = globals()
    tests = [(k, v) for k, v in g.items() if k.startswith("test_") and callable(v)]

    failed = 0
    for name, fn in tests:
        try:
            fn()
            print(f"  OK  {name}")
        except TestFailure as e:
            print(f" FAIL {name}: {e}")
            failed += 1
        except Exception as e:
            print(f" FAIL {name}: unexpected {type(e).__name__}: {e}")
            failed += 1

    print(f"\n{len(tests)} tests, {failed} failed")
    return failed


if __name__ == "__main__":
    sys.exit(run_tests())
